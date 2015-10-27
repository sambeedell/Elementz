//
//  ViewController.m
//  MPAS
//
//  Created by Sam Beedell on 11/02/2015.
//

#import "ViewController.h"
#import "AudioRingBuffer.h"
#import "SettingsViewController.h"

@implementation ViewController

//-----------------------------------------------------------------------------
//	Init functions
//-----------------------------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];
	
    //Create a shared instance of SimpleRecorderDemo class and allocate the object.
    SimpleRecorderDemo *newSRObj = [[SimpleRecorderDemo alloc] init];
    _SRObj=newSRObj; //Assign (point) the newly created instance to _SRObj.
    
    //Create a new instance of the Fourier Transform class and allocate the object, thus allowing access from the ViewController (current class)
    _analyzer = FourierTransform.sharedInstance;
    
    //Add the relevant interface graphics
    [self addOscilloscope];
    [self addCircle];
    
    [_SRObj startRecording];
    timer = [NSTimer scheduledTimerWithTimeInterval:(1.0f / 60) target:self selector:@selector(refreshView) userInfo:nil repeats:YES];
}

- (void)addOscilloscope{
    self.waveform = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.bounds.origin.x, self.view.bounds.origin.y + (self.view.bounds.size.height/4), self.view.bounds.size.width, self.view.bounds.size.height/2)];
    self.waveform.userInteractionEnabled = NO;
    self.waveform.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:self.waveform];
}

- (void)addCircle{
    self.circle = [CAShapeLayer layer];
    self.circle.position = CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2);
    self.circle.strokeColor = [UIColor whiteColor].CGColor;
    _lineWidth = 2;
    _radius = 100;
    _fillColor = [UIColor whiteColor];
    self.circle.hidden = NO;
    [self.view.layer addSublayer:self.circle];
}

//-----------------------------------------------------------------------------
//	Setter functions
//-----------------------------------------------------------------------------
- (void)setRadius:(CGFloat)radius {
    _radius = radius;
    self.circle.bounds = CGRectMake(0, 0, radius, radius);
    self.circle.path = [UIBezierPath bezierPathWithOvalInRect:self.circle.bounds].CGPath;
}

- (void)setFillColor:(UIColor *)fillColor{
    _fillColor = fillColor;
    self.circle.fillColor = fillColor.CGColor;
//    self.circle.opacity = 0.9;
}

- (void)setLineWidth:(CGFloat)lineWidth{
    _lineWidth = lineWidth;
    self.circle.lineWidth = lineWidth;
}

//-----------------------------------------------------------------------------
//	Updating UI functions
//-----------------------------------------------------------------------------
- (void)refreshView{

    // Get the size of the UIImageView used to hold the waveform
    CGSize size = self.waveform.bounds.size;
    
    // Initialize the bitmap-based graphics bounds for the current context
    UIGraphicsBeginImageContext(size);
    
    // Create a path to map the data points to
    UIBezierPath *waveformPath = [UIBezierPath bezierPath];
    
    // Perform FFT on the microphone data
    [_analyzer forwardFFT:_SRObj->_ringBuffers smpRate:_SRObj->_samplingRate];
    
    // Draw the input waveform graph.
    {
        // Length of buffer
        NSUInteger waveformLength = _analyzer._fftSize;
        
        // Create an array of size waveforLength
        float waveform[waveformLength];
        
        // Copy ringbuffer array into waveform array
        [_SRObj->_ringBuffers.firstObject copyTo:waveform length:waveformLength];
        
        // Scale the x-axis to the size of the UIImageView with the lenght of buffer points.
        float xScale = size.width / waveformLength;
        
        // Loop around all sample values in the buffer
        for (int i = 0; i < waveformLength; i++) {
            float x = xScale * i;
            float y = waveform[i] * size.height + (size.height/2);
            if (i == 0) { // Give instruction to the CGContext
                [waveformPath moveToPoint:CGPointMake(x, y)];
            } else {
                [waveformPath addLineToPoint:CGPointMake(x, y)];
            }
        }
        waveformPath.lineWidth = 0.5f;
        [[UIColor whiteColor] setStroke]; //colour of the path
        [waveformPath stroke]; //draw the path
    }
    
    // Calculate the pitch
    {
        // Create a refernce pointer the the spectrum data
        SpectrumDataRef spectrum = _analyzer.rawSpectrumData;
        _freq1.text = [[NSString alloc] initWithFormat:@"%.3f Hz", spectrum->magnitude];
        
    }
    // Get the CGContext and assign it the UIImageView
    self.waveform.image = UIGraphicsGetImageFromCurrentImageContext();
    // Remove the bitmap-based graphics from the current CGContext
    UIGraphicsEndImageContext();
    
    // Update the Circle visualization
    [self updateCircle];
}

- (void)updateCircle{
    
    //RMS value
    int sampleCount = _SRObj->_samplingRate / 60; // 60 fps
    float rms = [_SRObj->_ringBuffers[0] calculateRMS:sampleCount];
    [CATransaction begin]; {
        [CATransaction setDisableActions:YES];
        [CATransaction setAnimationDuration:2];
        self.radius = rms*500 + 100;
    } [CATransaction commit];
    
    //Centroid Value
    SpectrumDataRef spectrum = _analyzer.rawSpectrumData;
    Float32 centroid = spectrum->centroid[0];
    
    //Optional other colours
    //self.fillColor = [UIColor colorWithRed:(centroid/6000) green:84.0/255.0 blue:142.0/255.0 alpha:1.0]; //blue is soft, pink is harsh
    //self.fillColor = [UIColor colorWithRed:0.0/255.0 green:14.0/255.0 blue:(centroid/6000) alpha:1.0]; //black is soft, dark blue is harsh
    
    //Default colour theme
    float red   = centroid/5000;
    //Range of spectral centroid is approx 1kHz - 4kHz
    if (red <= 0.1 ) {
        red = 0;
    } else if (red >= 1)
        red = 1;
    
    float blue  = red;
    float green = red;
    
    self.fillColor = [UIColor colorWithRed:red green:green blue:blue alpha:1.0]; //black is soft, white is harsh
    
    // Update line width of circle
    self.lineWidth = spectrum->flux / 400;
}

//-----------------------------------------------------------------------------
//	Action Buttons
//-----------------------------------------------------------------------------
- (IBAction)startRecording:(UIButton *)sender {
    //Start recording
    [_SRObj startRecording];
    
    // Refresh 60 times in a second.
    timer = [NSTimer scheduledTimerWithTimeInterval:(1.0f / 60) target:self selector:@selector(refreshView) userInfo:nil repeats:YES];
}

- (IBAction)stop:(UIButton *)sender {
    //Stop all updates
    [_SRObj stop];
    [timer invalidate];
}

@end
