//
//  AudioTools.h
//  AudioDemo
//
//  Created by king on 2017/2/19.
//  Copyright © 2017年 king. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioPlay.h"

@import AVFoundation;
@import AudioToolbox;
@import CoreAudio;

#define kNumberAudioQueueBuffers 3  //定义了三个缓冲区
#define kDefaultBufferDurationSeconds 0.1279   //调整这个值使得录音的缓冲区大小为2048bytes
#define kDefaultSampleRate 8000.0   //定义采样率为8000

@interface AudioTools : NSObject
{
    @package
    BOOL isRecording;
    AudioStreamBasicDescription recordFormat;
    AudioQueueRef recordQueue;
    AudioQueueBufferRef recordBufferRef[kNumberAudioQueueBuffers];
    NSFileHandle *handle;
    AudioPlay *play;
}

- (void)startRecording;
- (void)stopRecording;
- (void)writeDataWitnBufferRef:(AudioQueueBufferRef)buffer withQueue:(AudioQueueRef)queue;
@end
