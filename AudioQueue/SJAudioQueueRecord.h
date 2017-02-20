//
//  SJAudioQueueRecord.h
//  AudioDemo
//
//  Created by king on 2017/2/20.
//  Copyright © 2017年 king. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;
@import AudioToolbox;

#define kNumberAudioQueueBuffers 3
#define kBufferDurationSeconds 0.1279





@interface SJAudioQueueRecordDesc : NSObject
{
    @public
    AudioStreamBasicDescription         mFormat;
    AudioQueueRef                       mQueue;
    AudioQueueBufferRef                 mBufferRef[kNumberAudioQueueBuffers];
    CFStringRef                         mFileName;
    AudioFileID                         mRecordFile;
    SInt64                              mRecordPacket;
}
@end


@interface SJAudioQueueRecord : NSObject
@property (nonatomic, assign, readonly) BOOL isRecording;
@property (nonatomic, strong, readonly)  SJAudioQueueRecordDesc  *recordDesc;
@property (nonatomic, strong, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) int audioBufferSize;
@property (nonatomic, assign, readonly) int mSampleRate;
- (void)startRecord:(NSString *)inRecordFile;
- (void)startRecord:(NSString *)inRecordFile SyncPlay:(BOOL)syncPlay;
- (void)stopRecord;
@end
