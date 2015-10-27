//
//  FourierTransform.h
//  MPAS
//
//  Created by Sam Beedell on 11/02/2015.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

//@class SimpleRecorderDemo;

// Data structure for spectrum data.
struct SpectrumData
{
    NSUInteger  length;
    Float32     data[0];
    Float32     magnitude;
    float       centroid[0];
    Float32     flux;
};
typedef struct SpectrumData SpectrumData;
typedef const struct SpectrumData *SpectrumDataRef;

@interface FourierTransform : NSObject{
    
    // Spectrum data.
    SpectrumData *_rawSpectrum;
    
@private
    size_t          fftSize,
                    fftSizeOver2,
                    log2n,
                    log2nOver2,
                    windowSize;
    
    Float32         *in_real,
                    *out_real,
                    *window;
    
    float           scale,
                    stride;
    
    FFTSetup        fftSetup;
    COMPLEX_SPLIT   split_data;
    
    Float32         *prevRawMagnitude;
    
}

// Retrieve the shared instance.
+ (FourierTransform *)sharedInstance;

// Public Methods
- (void)initFFT;
- (void)forwardFFT:(NSArray *)buffer smpRate:(Float64)samplingRate;
//- (void)inverseFFT:(int) start buffer:(float *)buffer window:(BOOL)dowindow;

//Configurations
@property (nonatomic, assign) size_t _fftSize;

// Spectrum data accessors.
@property (nonatomic, readonly) SpectrumDataRef rawSpectrumData;

@end
