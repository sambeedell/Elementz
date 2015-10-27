//
//  ViewController.h
//  MPAS
//
//  Created by Sam Beedell on 11/02/2015.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "SimpleRecorderDemo.h"
#import "FourierTransform.h"

@interface ViewController : UIViewController{
    SimpleRecorderDemo  *_SRObj;
    FourierTransform    *_analyzer;
    NSTimer *timer;
    
    NSMutableDictionary *keyMapping;
    NSMutableDictionary *frequencyMapping;
}

@property (strong, nonatomic) UIImageView   *waveform;
@property (strong, nonatomic) UIImageView   *levelMeter;
@property (weak, nonatomic)   UILabel       *freq1;

@property (nonatomic, strong) CAShapeLayer *circle;
@property (nonatomic) CGFloat radius;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) UIColor *fillColor;

@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;

- (IBAction)startRecording:(UIButton *)sender;
- (IBAction)stop:(UIButton *)sender;

@end
