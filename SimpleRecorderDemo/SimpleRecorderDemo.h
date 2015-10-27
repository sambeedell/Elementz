//
//  SimpleRecorderDemo.h
//  SimpleRecorderDemo
//
//  Created by audioteka on 11/11/2013.
//  Copyright (c) 2013 audioteka. All rights reserved.
//  Adapted by Sam Beedell

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import "FourierTransform.h"

#define kStereoBus (2)
#define kMonoBus (1)
#define kInputBus (1)
#define kOutputBus (0)

@interface SimpleRecorderDemo : NSObject{
    
    AVAudioSession *_AudioSession;
    
    BOOL        _playing;
    BOOL        _recording;
    
    //Set to public because class is passed as user data in the render callback.
@public
    
    //USING FS
    Float64     _samplingRate;
    Float64     _msPerSample;

    //USING  BPM
    Float64     _beatsPerMinute;
    Float64     _msPerBeat;
    
    //USING LOOPS & BARS
    Float64     _msPerBar;
    uint64_t    _smpPerBar;
    Float64     _msPerLoop;
    Float64     _secPerLoop;
    uint64_t    _smpPerLoop;
    uint64_t    _barsPerLoop;
    uint64_t    _beatsPerBar;
    
    Float64                     _hardwareSampleRate;
    AudioStreamBasicDescription _clientStereoASBD;
    AudioUnit                   _rioAU;
    AudioBufferList             *_ioBuffer;
    uint64_t                    _sampleIntoLoop;
    uint64_t                    _sampleStoppedRecording;
    
    NSFileManager *_FileManager;
    NSURL *_audioDirURL;
    
    NSArray *_ringBuffers;
}

// Ring buffer array.
@property (nonatomic, readonly) NSArray *ringBuffers;

//Public interface
-(OSStatus)startRecording;
-(OSStatus)startPlayback;
-(OSStatus)stop;
-(BOOL)isPlaying;
-(BOOL)isRecording;

- (void) checkErr: (OSStatus) error
      withMessage:(const char *) message;
@end
