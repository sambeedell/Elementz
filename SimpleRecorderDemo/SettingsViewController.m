//
//  SettingsViewController.m
//  SimpleRecorderDemo
//
//  Created by Sam Beedell on 07/04/2015.
//

#import "SettingsViewController.h"

@implementation SettingsViewController

//=============================================================================
// INITIALISE FUNCTION
//=============================================================================
- (void)viewDidLoad {
    [super viewDidLoad];
    
    fft = FourierTransform.sharedInstance;
    
    // Initialize Picker Data with FFT sizes
    pickerData = @[@"512", @"2048", @"4096", @"8192", @"16384"];
    // Connect Data to UIPickerView
    self.fftSizePicker.dataSource = self;
    self.fftSizePicker.delegate = self;
    int index;
    for (int i = 0; i < pickerData.count; i++) {
        BOOL check = [pickerData[i] isEqualToString:[NSString stringWithFormat:@"%zu",fft._fftSize]];
        if (check) {
            index = i;
        }}
    [_fftSizePicker selectRow:index inComponent:0 animated:YES];
}

//=============================================================================
// PICKERVIEW DELEGATE FUNCTIONS
//=============================================================================
// The number of columns of data
- (int)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// The number of rows of data
- (int)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return pickerData.count;
}

// The data to return for the row and component (column) that's being passed in
- (NSString*)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return pickerData[row];
}

// Make the text colour white
- (NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    NSAttributedString *attString = [[NSAttributedString alloc] initWithString:pickerData[row] attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
    
    return attString;
    
}

// Catpure the picker view selection
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    // This method is triggered whenever the user makes a change to the picker selection.
    // The parameter named row and component represents what was selected.
    // ---------------------------------------------------------------------------------
    // Update Fourier Transform
    fft._fftSize = [pickerData[row] integerValue];
    [fft initFFT];
}

//=============================================================================
// RETURN TO VIEW FUNCTION
//=============================================================================
- (IBAction)returnToView{
    //return the the view controller with same animation
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
