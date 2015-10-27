//
//  FourierTransform.m
//  MPAS
//
//  Created by Sam Beedell on 11/02/2015.
//

#import "FourierTransform.h"
#import "AudioRingBuffer.h"

#define size  1024 * 2

@implementation FourierTransform

#pragma mark Static method

+ (FourierTransform *)sharedInstance
{
    //Ensures there is only ever one instatiation of this class
    static FourierTransform *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FourierTransform alloc] init];
    });
    return instance;
}

#pragma mark Constructor / Destructor

- (id)init
{
    if (self = [super init])
    {
        self._fftSize = size;
        [self initFFT];
    }
    return self;
}

- (void)initFFT{
    fprintf(stdout,"FFT Size = %zu ... Setting up...", self._fftSize);

    //Init varibales
    fftSize          = self._fftSize;
    fftSizeOver2     = fftSize / 2;
    log2n            = round(log2f(fftSize));
    log2nOver2       = log2n / 2;
    stride           = 1;
    scale            = 1.0f/(Float32)(4.0f*fftSize);
    
    // Init data arrays
    in_real          = (Float32 *) malloc(fftSize * sizeof(Float32));
    out_real         = (Float32 *) malloc(fftSize * sizeof(Float32));
    split_data.realp = (Float32 *) malloc(fftSizeOver2 * sizeof(Float32));
    split_data.imagp = (Float32 *) malloc(fftSizeOver2 * sizeof(Float32));
    prevRawMagnitude = (Float32 *) malloc(fftSizeOver2 * sizeof(Float32));
    
    // Init window
    windowSize       = self._fftSize;
    window           = (Float32 *) malloc(sizeof(Float32) * windowSize);
    memset(window, 0, sizeof(Float32) * windowSize);
    vDSP_hann_window(window, windowSize, vDSP_HANN_DENORM);
//    vDSP_blkman_window(window, size, 0);
    
    //initialize structure variables
    _rawSpectrum         = calloc(sizeof(SpectrumData) + sizeof(Float32) * fftSizeOver2, 1);
    _rawSpectrum->length = fftSizeOver2;
    _rawSpectrum->magnitude = 0.0f;
    _rawSpectrum->flux      = 0.0f;
    
    // allocate the fft object once
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
    
    // Check for error
    if (fftSetup == NULL) {
        fprintf(stdout,"FFT_Setup failed to allocate enough memory.");
    }
    fprintf(stdout,"OK! \n");
}


- (void)freeFFT{ //free all initialized variables
    free(in_real);
    free(out_real);
    free(split_data.realp);
    free(split_data.imagp);
    free(window);
    free(_rawSpectrum);
    
    vDSP_destroy_fftsetup(fftSetup);
}

- (SpectrumDataRef)rawSpectrumData
{
    return _rawSpectrum; //Get Data
}


- (void)forwardFFT:(NSArray *)buffer smpRate:(Float64)samplingRate {

    // Retrieve waveforms from channels and average these to Float32. STEREO->MONO
    [buffer.firstObject copyTo:in_real length:fftSize];
    for (NSUInteger i = 1; i < 2; i++){
        [[buffer objectAtIndex:i] vectorAverageWith:in_real index:i length:size];
    }
    
    // convert to split complex format with evens in real and odds in imag
    vDSP_ctoz((COMPLEX *) in_real, 2, &split_data, 1, fftSizeOver2);
    
    // Apply the window function.
    vDSP_vmul(split_data.realp, 1, window, 2, split_data.realp, 1, fftSizeOver2);
    vDSP_vmul(split_data.imagp, 1, window + 1, 2, split_data.imagp, 1, fftSizeOver2);
    
    // perform fft
    vDSP_fft_zrip(fftSetup, &split_data, 1, log2n, FFT_FORWARD);
    
    // Zero out the nyquist value
    split_data.imagp[0] = 0.0;
    
    //scale fft
    vDSP_vsmul(split_data.realp, 1, &scale, split_data.realp, 1, fftSizeOver2);
    vDSP_vsmul(split_data.imagp, 1, &scale, split_data.imagp, 1, fftSizeOver2);

    //-----------------------
    //-- SPECTRUM ANALYZER --
    //-----------------------
    Float32 *rawSpectrum = _rawSpectrum->data;
    // Calculate power spectrum.
    vDSP_zvmags(&split_data, 1, rawSpectrum, 1, fftSizeOver2);
    
    // Add -128db offset to avoid log(0).
    float kZeroOffset = 1.5849e-13;
    vDSP_vsadd(rawSpectrum, 1, &kZeroOffset, rawSpectrum, 1, fftSizeOver2);

    // Convert power to decibel.
    float kZeroDB = 0.70710678118f; // 1/sqrt(2)
    vDSP_vdbcon(rawSpectrum, 1, &kZeroDB, rawSpectrum, 1, fftSizeOver2, 0);

    //Process strongest freq in Hz
    Float32 maxValue;
    unsigned long maxIndex = 0;
    
    //maximum value in vector
    vDSP_maxvi(rawSpectrum, 1, &maxValue, &maxIndex, fftSizeOver2);
    Float32 HZ = ((Float32)maxIndex / (Float32)fftSizeOver2) * (samplingRate/2.0);
//    NSLog(@"f0 : %.3fHz", HZ);
    _rawSpectrum->magnitude = HZ;
    
    //-----------------------
    //-- SPECTRAL CENTROID --
    //-----------------------
    Float32 denominator = 0.0;
    Float32 *rawMagnitude = (Float32 *) malloc(fftSizeOver2 * sizeof(Float32));
    Float32 *centroid = _rawSpectrum->centroid;
    
    // Calculate absolute values of spectrum (all frequency bins).
    // Not the power (rawSpectrum - vDSP_zvmags), this would not model psycho-acoustic loudness measure, thus taking into account masking and other perceptual effects. This non-linear human frequency perception is modelled using the 'bark scale'
    vDSP_zvabs(&split_data, 1, rawMagnitude, 1, fftSizeOver2);
    
    // Calculate the vector sum of the total freq bins
    vDSP_sve(rawMagnitude, 1, &denominator, fftSizeOver2);
    
    //Sum the frequency weighted amplitudes of the spectrum
    Float32 numerator = 0;
    for (int i = 0; i < fftSizeOver2; i++) {
        numerator += i * rawMagnitude[i];
    }
    
    // Calculate average frequency weighted by amplitudes, divided by the sum of the amplitudes
    //centroid = (numerator / denominator); //centroid in index form
    centroid[0] = ((numerator / denominator) / fftSizeOver2) * (samplingRate / 2); //centroid in Hz
    if (centroid[0] == NAN) { centroid = 0; } //avoid NaN
//    NSLog(@"centroid: %f", centroid[0]);
    
    //-----------------------
    //---- SPECTRAL FLUX ----
    //-----------------------
    Float32 flux = _rawSpectrum->flux;
        for (int i = 0; i < fftSizeOver2; i++) {
        flux += powf(rawMagnitude[i] - prevRawMagnitude[i], 2);
    }
    flux = (sqrtf(flux) / fftSizeOver2) * (samplingRate/2);
    memcpy(prevRawMagnitude, rawMagnitude, (fftSizeOver2 * sizeof(Float32)));
//    NSLog(@"flux: %f", flux);
    
    free(rawMagnitude);

}
// Used to test the forward fourier transform. If the data going into the forward FT comes out the same as coming out of the inverse FT after going through the forward FT, then it all works perfectly.
- (void)inverseFFT:(int) start buffer:(float *)buffer window:(BOOL)dowindow{
    
    // Inverse FFT
    vDSP_fft_zrip(fftSetup, &split_data, 1, log2n, FFT_INVERSE);
    
    // The output signal is now in a split real form. Use the vDSP_ztoc to get
    // an interleaved complex vector.
    vDSP_ztoc(&split_data, 1, (COMPLEX*) out_real, 2, fftSizeOver2);
    
    // The output signal is also much louder than before so we must scale it back to the original volume
    vDSP_vsmul(out_real, 1, &scale, out_real, 1, fftSize);
    
    // multiply by window w/ overlap-add ?
}


@end
