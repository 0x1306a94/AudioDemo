//
//  AudioTools.m
//  AudioDemo
//
//  Created by king on 2017/2/19.
//  Copyright © 2017年 king. All rights reserved.
//

#import "AudioTools.h"
#import <commoncrypto/CommonDigest.h>


void inputBufferHandler(void * __nullable               inUserData,
                        AudioQueueRef                   inAQ,
                        AudioQueueBufferRef             inBuffer,
                        const AudioTimeStamp *          inStartTime,
                        UInt32                          inNumberPacketDescriptions,
                        const AudioStreamPacketDescription * __nullable inPacketDescs) {
    
    AudioTools *tools = (__bridge AudioTools *)inUserData;
    if (inNumberPacketDescriptions > 0) {
        [tools writeDataWitnBufferRef:inBuffer withQueue:inAQ];
    }
    
    if (tools->isRecording) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    } else {
        AudioQueueFreeBuffer(inAQ, inBuffer);
    }
}

@implementation AudioTools

- (void)setupAudioFormat:(UInt32) inFormatID SampleRate:(Float64)sampeleRate {
    
    memset((void *)&recordFormat, 0, sizeof(recordFormat));
    recordFormat.mSampleRate = sampeleRate;
    recordFormat.mChannelsPerFrame = 1;
    recordFormat.mFormatID = inFormatID;
    
    if (inFormatID == kAudioFormatLinearPCM) {
        recordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
        recordFormat.mBitsPerChannel = 16;
        recordFormat.mBytesPerPacket = recordFormat.mBytesPerFrame = (recordFormat.mBitsPerChannel / 8) * recordFormat.mChannelsPerFrame;
        recordFormat.mFramesPerPacket = 1;
    }
}

- (void)startRecording {
    
    [self setupAudioFormat:kAudioFormatLinearPCM SampleRate:kDefaultSampleRate];
    
    NSError *error = nil;
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                                      error:&error];
    
    if (!ret) {
        NSLog(@"设置环境失败: %@", error);
        return;
    }
    
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret) {
        NSLog(@"启动失败: %@", error);
        return;
    }
    
    // 准备文件
    if (![self openFileHandle]) {
        return;
    }
    play = [[AudioPlay alloc] init];
    [play start];
    AudioQueueNewInput(&recordFormat,
                       &inputBufferHandler,
                       (__bridge void *)self,
                       NULL, NULL, 0, &recordQueue);
    
    
    int frames = (int)ceil(kDefaultBufferDurationSeconds * recordFormat.mSampleRate);
    int bufferByteSize = frames * recordFormat.mBytesPerFrame;
    NSLog(@"缓冲区大小: %d", bufferByteSize);
    
    for (int i = 0; i < kNumberAudioQueueBuffers; i++) {
        AudioQueueAllocateBuffer(recordQueue, bufferByteSize, &recordBufferRef[i]);
        AudioQueueEnqueueBuffer(recordQueue, recordBufferRef[i], 0, NULL);
    }

    AudioQueueStart(recordQueue, NULL);
    isRecording = YES;

}

- (void)stopRecording {
    [self closeFileHandle];
    if (play) {
        [play stop];
        play = nil;
    }
    if (isRecording) {
        isRecording = NO;
        AudioQueueStop(recordQueue, true);
        AudioQueueDispose(recordQueue, true);
        [[AVAudioSession sharedInstance] setActive:NO error:NULL];
    }
    
}

- (BOOL)openFileHandle {
    
    NSString *name = @([NSDate date].timeIntervalSince1970).stringValue;
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Caches"] stringByAppendingPathComponent:[[self md5:name] stringByAppendingString:@".pcm"]];
    NSLog(@"%@",path);
    if (![[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil]) {
        NSLog(@"创建文件失败");
        return NO;
    }
    handle = [NSFileHandle fileHandleForWritingAtPath:path];
    return YES;
}

- (void)closeFileHandle {
    if (handle) {
        [handle closeFile];
        handle = nil;
    }
    
}

- (void)writeDataWitnBufferRef:(AudioQueueBufferRef)buffer withQueue:(AudioQueueRef)queue {
    @autoreleasepool {
        
        NSData *data = [NSData dataWithBytes:buffer->mAudioData length:buffer->mAudioDataByteSize];
        if (handle) {
            [handle writeData:data];
            [handle seekToEndOfFile];
            if (play) {
                [play play:data];
            }
        }
    }
}

- (NSString *)md5:(NSString *)str {
    const char *cStr = [str UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
    
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}
@end
