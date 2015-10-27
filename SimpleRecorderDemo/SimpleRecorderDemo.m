//
//  SimpleRecorderDemo.m
//  SimpleRecorderDemo
//
//  Created by audioteka on 11/11/2013.
//  Copyright (c) 2013 audioteka. All rights reserved.
//  Adapted by Sam Beedell

#import "SimpleRecorderDemo.h"
#import "AudioRingBuffer.h"

#pragma mark Callback Functions

//-----------------------------------------------------------------------------
//	renderCallback function
//-----------------------------------------------------------------------------
static OSStatus renderCallback (void *inRefCon,
                                AudioUnitRenderActionFlags *ioActionFlags,
                                const AudioTimeStamp *inTimeStamp,
                                UInt32 inBusNumber,
                                UInt32 inNumberFrames,
                                AudioBufferList *ioData){
    OSStatus err=0;
    SimpleRecorderDemo *SRObj=(__bridge SimpleRecorderDemo*)inRefCon;
    NSArray *_ringBuffers = SRObj->_ringBuffers;
    
    if ([SRObj isRecording]) {
        //Call AudioUnitRender to get next frame of incoming audio samples.
        err=AudioUnitRender(SRObj->_rioAU,
                            ioActionFlags,
                            inTimeStamp,
                            1,
                            inNumberFrames,
                            ioData);
        
        for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
            AudioBuffer *input = &ioData->mBuffers[i]; //Stereo

            [[_ringBuffers objectAtIndex:i]  pushSamples:input->mData count:input->mDataByteSize / sizeof(Float32)];
        
        //Silence data so that we do not hear back the recorded data while recording! You could expand your code to include a monitor audio switch. You should modify the following line to achieve this.
        memset(ioData->mBuffers[i].mData, 0.0f, ioData->mBuffers[i].mDataByteSize);
       
        }
        
        //Update ringbuffer array for public use
        SRObj->_ringBuffers = _ringBuffers;
        
    }
    return err;
}

@implementation SimpleRecorderDemo

#pragma mark Initialisation Functions
//-----------------------------------------------------------------------------
//	init function
//-----------------------------------------------------------------------------
-(id)init{
    if(!(self=[super init])) return self;
    
    OSStatus err=0;
    
    //=============================================================================
    //STEP 1 - CONFIGURE AND INITIALISE AUDIO SESSION
    //=============================================================================
    err=[self initialiseAudioSession];
    [self checkErr:err withMessage:"Failed to configure and initialise Audio Session!"];
    
    //=============================================================================
    //STEP 2 - CONFIGURE CLIENT AUDIO STREAM BASIC DESCRIPTION
    //=============================================================================
    [self configureASBD];
    
    //=============================================================================
    //STEP 3 - SETUP THE REMOTEIO AUDIO UNIT FOR RECORDING AND PLAYBACK
    //=============================================================================
    err=[self setupRemoteIO];
    [self checkErr:err withMessage:"Failed to setup RemoteIO AU!"];
    
    //=============================================================================
    //STEP 4 - INITIALISATION OF TIME AND MUSICAL PARAMETERS
    //=============================================================================
    [self initialiseTimeParameters];
    
    //=============================================================================
    //STEP 5 - BUFFER ALLOCATIONS
    //=============================================================================
    [self bufferAllocations];
    
    //=============================================================================
    //STEP 6 - Initialise File Manager
    //=============================================================================
    [self initFileManager];
    
    //=============================================================================
    //STEP 7 - INITIALISE STATE
    //=============================================================================
    _playing=NO;
    _recording=NO;
    
    if(err){
        [self checkErr:err withMessage:"Failed to initialise SimpleRecorderDemo!"];
    }
    else{
        fprintf(stdout,"Simple Recorder initialised!\n");
    }
    return self;
}

//-----------------------------------------------------------------------------
//	initialiseAudioSession function
//-----------------------------------------------------------------------------
-(OSStatus)initialiseAudioSession{
    NSError *err=nil;
    BOOL success=FALSE;
    
    fprintf (stdout,"Configuring Audio Session...");
    
    //Implicit initialisation of audio session.
    _AudioSession=[AVAudioSession sharedInstance];
    
    success=[_AudioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                                 error:&err];
    if(!success){
        [self checkErr:[err code] withMessage:"Failed to set category for AVAudioSession"];
    }
    
    //Check for input availability
    BOOL hasInput=[_AudioSession isInputAvailable];
    if(!hasInput){
        UIAlertView *alert=[[UIAlertView alloc] initWithTitle:@"No audio input available"
                                                      message:@"The application cannot record because no audio input has been detected!"
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
        [alert show];
    }
    
    //Get hardware sample rate
    _hardwareSampleRate=[_AudioSession sampleRate];
    
    //Activate audio session
    success=[_AudioSession setActive:YES
                               error:&err];
    if(!success){
        [self checkErr:[err code] withMessage:"Failed to activate audio session"];
    }
    
    if(!err)
        fprintf(stdout,"OK\n");
    
    return [err code];
}

//-----------------------------------------------------------------------------
//	configureASBD function
//-----------------------------------------------------------------------------
-(void)configureASBD{
    
    fprintf(stdout,"Configuring client stream format...");
    //Initialise ASBD structure
    memset (&_clientStereoASBD, 0, sizeof (_clientStereoASBD));
    
    //Set up ASBD for stereo playback
    _clientStereoASBD.mFormatID = kAudioFormatLinearPCM;
    _clientStereoASBD.mFormatFlags =kAudioFormatFlagsNativeEndian|kAudioFormatFlagIsFloat|kAudioFormatFlagIsNonInterleaved;
    _clientStereoASBD.mSampleRate = _hardwareSampleRate;
    _clientStereoASBD.mChannelsPerFrame = 2;
    _clientStereoASBD.mBitsPerChannel = 32;
    _clientStereoASBD.mBytesPerPacket = 4;
    _clientStereoASBD.mFramesPerPacket = 1;
    _clientStereoASBD.mBytesPerFrame = 4;
    _clientStereoASBD.mReserved=0;
    
    fprintf(stdout,"OK\n");
    
}

//-----------------------------------------------------------------------------
//	setupRemoteIO function
//-----------------------------------------------------------------------------
-(OSStatus)setupRemoteIO{
    OSStatus err=0;
    UInt32 propsize=0;
    
    fprintf(stdout,"Configuring RemoteIO AU...");
    //.............................................................................
    //Get RemoteIO AU from Audio Unit Component Manager.
    //.............................................................................
    
    //Specify RemoteIO Audio Unit Component Desciption.
    AudioComponentDescription RIOUnitDescription;
    RIOUnitDescription.componentType          = kAudioUnitType_Output;
    RIOUnitDescription.componentSubType       = kAudioUnitSubType_RemoteIO;
    RIOUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    RIOUnitDescription.componentFlags         = 0;
    RIOUnitDescription.componentFlagsMask     = 0;
    
    //Get RemoteIO AU from AUdio Unit Component Manager
    AudioComponent rioComponent=AudioComponentFindNext(NULL, &RIOUnitDescription);
    
    err=AudioComponentInstanceNew(rioComponent, &_rioAU);
    [self checkErr:err withMessage:"Failed to create a new instance of RemoteIO AU!"];
    
    //.............................................................................
    //Set up the RemoteIO AU.
    //.............................................................................
    //Enable output bus of RemoteIO.
    UInt32 enableOutput        = 1; // to enable output (enabled by default).To disable set this to zero.
    AudioUnitElement outputBus = 0; //Bus 0 of RemoteIO AU is the hardware output.
    propsize=sizeof(enableOutput);
    
    err=AudioUnitSetProperty(_rioAU,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Output,
                             outputBus,
                             &enableOutput,
                             propsize);
    [self checkErr:err withMessage:"Failed to enable output bus of RemoteIO AU."];
    
    //Enable input bus of RemoteIO.
    UInt32 enableInput        = 1; // to disable input (disabled by default). To enable set this to one.
    AudioUnitElement inputBus = 1; //Bus 1 of RemoteIO AU is the hardware input.
    propsize=sizeof(enableInput);
    
    err=AudioUnitSetProperty(_rioAU,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input,
                             inputBus,
                             &enableInput,
                             propsize);
    [self checkErr:err withMessage:"Failed to disable input bus of RemoteIO AU."];
    
    //Set the stream format of the RemoteIO AU.
    propsize=sizeof(_clientStereoASBD);
    
    //Set format for output (outputBus/input scope).
    err=AudioUnitSetProperty(_rioAU,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             outputBus,
                             &_clientStereoASBD,
                             propsize);
    [self checkErr:err withMessage:"Failed to set StreamFormat property of RemoteIO AU (output bus/input scope)!"];
    
    //Set format for input (inputBus/output scope).
    err=AudioUnitSetProperty(_rioAU,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output,
                             inputBus,
                             &_clientStereoASBD,
                             propsize);
    [self checkErr:err withMessage:"Failed to set StreamFormat property of RemoteIO AU (input bus/output scope)!"];
    
    
    //Set up render callback function for the RemoteIO AU.
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProc=renderCallback;
    renderCallbackStruct.inputProcRefCon=(__bridge void *)(self);
    propsize=sizeof(renderCallbackStruct);
    
    err=AudioUnitSetProperty(_rioAU,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Global,
                             outputBus,
                             &renderCallbackStruct,
                             propsize);
    [self checkErr:err withMessage:"Failed to set SetRenderCallback property for RemoteIO AU!"];
    
    //.............................................................................
    //Initialise RemoteIO AU.
    //.............................................................................
    err=AudioUnitInitialize(_rioAU);
    [self checkErr:err withMessage:"Failed to initialise RemoteIO AU!"];
    
    if(!err)
        fprintf(stdout,"OK\n");
    
    return err;
}

//-----------------------------------------------------------------------------
//	initialiseTimeParameters function
//-----------------------------------------------------------------------------
-(void)initialiseTimeParameters{
    fprintf (stdout,"Calculating time variables...");
    //USING FS
    _samplingRate=_hardwareSampleRate;
    _msPerSample=(1.0e3/_samplingRate);
    
    //USING BPM
    _beatsPerMinute=120.0f; //Set by user
    _msPerBeat=6.0e4f/_beatsPerMinute;
    
    //USING BARS IN A LOOP
    _barsPerLoop=2; //Set by user
    _beatsPerBar=4; //Fixed in this implementation. Could be set by user if required.
    _msPerBar=_beatsPerBar*_msPerBeat;
    
    _smpPerLoop=_barsPerLoop*_beatsPerBar*_msPerBeat/_msPerSample;
    
    
    _msPerLoop=_smpPerLoop*_msPerSample;
    _secPerLoop=_msPerLoop/1.0e3;
    
    fprintf(stdout,"OK\n");
    
    
}

//-----------------------------------------------------------------------------
//	bufferAllocations function
//-----------------------------------------------------------------------------
-(OSStatus)bufferAllocations{
    OSStatus err=0;
    
    fprintf(stdout, "Allocating audio buffers...");
    
    //We want audio buffers big enough to hold several seconds of audio data. We prefer to do this allocation at this point
    // (and kind of have to) because this is a big memory allocation and has an unbounded time of execution. We have to
    //avoid such big allocations (and any allocation with malloc and family functions) in the render callbacks because
    //callbacks are critical functions operating in real-time and run on a high priority thread and any function call with
    //undbounded time of execution can cause the audio stream to halt resulting in clicks, pops and bad audio. Render
    //callbacks are time-critical and should not be delayed by function calls with an unknown time of execution.
    //In the particular case we take a software design decision and create a couple of AudioBuffers which serve the purpose
    //of storing incoming audio data and later saving this data in a file on disk. This is a simple approach and does not
    //account for cases such as what happens when the user needs to record more audio than these pre-allocated buffers
    //can hold. A full implementation should account for this and similar issues.
    
    _ioBuffer = (AudioBufferList *) malloc (sizeof (AudioBufferList) + sizeof (AudioBuffer) * (_clientStereoASBD.mChannelsPerFrame));
    if (NULL == _ioBuffer) {fprintf (stderr,"*** malloc failure for allocating bufferList memory.\n");
        return -1;}//Exiting with error code -1 is very crude. Need to handle such errors and exit clean.
    
    // initialize the mNumberBuffers member. We want mChannelsPerFrame mono (non-interleaved) buffers.
    _ioBuffer->mNumberBuffers =_clientStereoASBD.mChannelsPerFrame;
    
    //Allocate space for _ioBuffer.
    for (int i=0;i<_clientStereoASBD.mChannelsPerFrame;i++){
        //In the following code _smpPerLoop is fixed and is calculated in initialiseTimeParameters.
        //The resulting buffers, with current settings, are enough to hold 8 bars worth of audio data (at 120 bpm).
        //If the value changes dynamically we need to reallocate memory space.
        //One approach would to allocate a huge buffer now (for exmaple 64 bars long) and keep it around.
        //Another approach could be to lazily allocate the buffers maybe in
        //a separate thread (dispatch_async() and family functions) or an appropriate palce in the code (NOT in the render callbacks).
        
        //Each buffer correpsonds to a mono channel.
        _ioBuffer->mBuffers[i].mNumberChannels=1;
        _ioBuffer->mBuffers[i].mDataByteSize=_smpPerLoop*sizeof(Float32);
        _ioBuffer->mBuffers[i].mData=(Float32*)malloc(_smpPerLoop*sizeof(Float32));
        memset(_ioBuffer->mBuffers[i].mData, 0.0f, _ioBuffer->mBuffers[i].mDataByteSize);
    }
    
    //Allocate space for ring buffers
    AudioRingBuffer *buffers[_clientStereoASBD.mChannelsPerFrame];
    for (UInt32 i = 0; i < _clientStereoASBD.mChannelsPerFrame; i++) {
        buffers[i] = [[AudioRingBuffer alloc] init];
    }
    _ringBuffers = [NSArray arrayWithObjects:buffers count:_clientStereoASBD.mChannelsPerFrame];
    
    fprintf(stdout,"OK\n");
    return err;
}

//-----------------------------------------------------------------------------
//	initFileManager function
//-----------------------------------------------------------------------------
-(void)initFileManager{
    
    fprintf(stdout,"Initialising file manager...");
    NSError *err;
    //Get an instanse of the default file manager.
    _FileManager=[NSFileManager defaultManager];
    
    //Get documents directory in app space.
    NSArray *dirPaths=[_FileManager URLsForDirectory:NSDocumentDirectory
                                           inDomains:NSUserDomainMask];
    
    NSURL *_docsURL=[dirPaths objectAtIndex:0];
    
    //Create a directory where all exported audio files are saved.
    _audioDirURL =[NSURL URLWithString:@"audio" relativeToURL:_docsURL];
    
    
    [_FileManager createDirectoryAtURL:_audioDirURL
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:&err];
    [self checkErr:[err code] withMessage:"Failed to create audio directory"];
    
    if(!err)
        fprintf(stdout,"OK\n");
    
}

#pragma mark Playback Functions

//-----------------------------------------------------------------------------
//	startRecording function
//-----------------------------------------------------------------------------
-(OSStatus)startRecording{
    OSStatus err=0;
    
    //Reset samples into loop.
    _sampleIntoLoop=0;
    _recording=YES;
    _playing=NO; //unless monitor option is available.
    
    err=AudioOutputUnitStart(_rioAU);
    [self checkErr:err withMessage:"Failed to start RemoteIO AU!"];
    if(!err){
        fprintf(stdout,"Playing audio...\n");
    }
    
    return err;
}

//-----------------------------------------------------------------------------
//	stopRecording function
//-----------------------------------------------------------------------------
-(OSStatus)stopRecording{
    OSStatus err=0;
    
    err=AudioOutputUnitStop(_rioAU);
    [self checkErr:err withMessage:"Failed to stop RemoteIO AU!"];
    
    if(!err){
        fprintf(stdout, "Stopped audio.\n");
        _recording=NO;
        
        _sampleStoppedRecording=_sampleIntoLoop; //Keep this for playback and saving file purposes
        
        //Reset smaple into loop
        _sampleIntoLoop=0;
    }
    
    return err;
}

//-----------------------------------------------------------------------------
//	startPlayback function
//-----------------------------------------------------------------------------
-(OSStatus)startPlayback{
    OSStatus err=0;
    
    //Reset smaple into loop
    _sampleIntoLoop=0;
    _playing=YES;
    _recording=NO; //unless monitor option is avaliable.
    
    err=AudioOutputUnitStart(_rioAU);
    [self checkErr:err withMessage:"Failed to start RemoteIO AU!"];
    if(!err){
        fprintf(stdout,"Playing audio...\n");
    }
    
    return err;
}

//-----------------------------------------------------------------------------
//	stopPlayback function
//-----------------------------------------------------------------------------
-(OSStatus)stopPlayback{
    OSStatus err=0;
    
    _sampleStoppedRecording=_sampleIntoLoop; //Keep this for playback and saving file purposes
    
    //Reset smaple into loop
    _sampleIntoLoop=0;
    
    err=AudioOutputUnitStop(_rioAU);
    [self checkErr:err withMessage:"Failed to stop RemoteIO AU!"];
    
    if(!err){
        fprintf(stdout, "Stopped audio.\n");
        _playing=NO;
    }
    
    return err;
}

//-----------------------------------------------------------------------------
//	stop function
//-----------------------------------------------------------------------------
-(OSStatus)stop{
    OSStatus err=0;
    if (_playing) {
        err=[self stopPlayback];
    }
    if(_recording){
        err=[self stopRecording];
    }
    return err;
}

//-----------------------------------------------------------------------------
//	isPlaying function
//-----------------------------------------------------------------------------
-(BOOL)isPlaying{
    return _playing;
}

//-----------------------------------------------------------------------------
//	isPlaying function
//-----------------------------------------------------------------------------
-(BOOL)isRecording{
    return _recording;
}


#pragma mark Utility Functions
//-----------------------------------------------------------------------------
//	checkErr function
//-----------------------------------------------------------------------------
- (void) checkErr: (OSStatus) error
      withMessage:(const char *) message{
    
    if(error==noErr) return;
    
    char errorString[20];
    *(UInt32*)(errorString+1)=CFSwapInt32HostToBig(error);
    
    if(isprint(errorString[1]) && isprint(errorString[2])
       && isprint(errorString[3])&&isprint(errorString[4])) {
        errorString[0]=errorString[5]='\'';
        errorString[6]='\0';
    }
    else sprintf(errorString, "%d",(int)error);
    
    fprintf(stderr, "\nError: %s [Error code: %s]\n",message,errorString);
}

@end
