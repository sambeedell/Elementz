//
//  SettingsViewController.h
//  SimpleRecorderDemo
//
//  Created by Sam Beedell on 07/04/2015.
//  Copyright (c) 2015 audioteka. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ViewController.h"
#import "FourierTransform.h"

@interface SettingsViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate>
{
    FourierTransform *fft;
    NSArray *pickerData;
}

//properties requires for settingsViewController user interface
@property (strong, nonatomic) IBOutlet UIPickerView *fftSizePicker;

@end
