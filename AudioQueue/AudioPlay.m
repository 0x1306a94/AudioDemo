//
//  AudioPlay.m
//  AudioDemo
//
//  Created by king on 2017/2/19.
//  Copyright © 2017年 king. All rights reserved.
//

#import "AudioPlay.h"

const AudioStreamBasicDescription asbd = {MAX_BUFFER_SIZE, kAudioFormatLinearPCM, kLinearPCMFormatFlagIsSignedInteger, (16 / 8), 1, (16 / 8), 1, 16, 0};

static void sAudioQueueOutputCallback(void *                  inUserData,
                                       AudioQueueRef           inAQ,
                                       AudioQueueBufferRef     inBuffer);

@implementation AudioPlay
{
    NSCondition *mAudioLock;
    AudioStreamBasicDescription playFormat;
    AudioQueueRef mAudioPlayer;
    AudioQueueBufferRef mAudioBufferRef[QUEUE_BUFFER_SIZE];
    void *mPCMData;
    int mDataLen;
}

- (void)setupAudioFormat:(UInt32) inFormatID SampleRate:(Float64)sampeleRate {
    
    memset((void *)&playFormat, 0, sizeof(playFormat));
    playFormat.mSampleRate = sampeleRate;
    playFormat.mChannelsPerFrame = 1;
    playFormat.mFormatID = inFormatID;
    
    if (inFormatID == kAudioFormatLinearPCM) {
        playFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
        playFormat.mBitsPerChannel = 16;
        playFormat.mBytesPerPacket = playFormat.mBytesPerFrame = (playFormat.mBitsPerChannel / 8) * playFormat.mChannelsPerFrame;
        playFormat.mFramesPerPacket = 1;
    }
}

-(BOOL)start{
    
    mPCMData = malloc(MAX_BUFFER_SIZE);
    mAudioLock = [[NSCondition alloc]init];
    
    AudioQueueNewOutput(&asbd, sAudioQueueOutputCallback, (__bridge void *)(self), nil, nil, 0, &mAudioPlayer);
    
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        
        AudioQueueAllocateBuffer(mAudioPlayer, AUDIO_BUFFER_SIZE, &mAudioBufferRef[i]);
        memset(mAudioBufferRef[i]->mAudioData, 0, AUDIO_BUFFER_SIZE);
        mAudioBufferRef[i]->mAudioDataByteSize = AUDIO_BUFFER_SIZE;
        AudioQueueEnqueueBuffer(mAudioPlayer, mAudioBufferRef[i], 0, NULL);
    }
    
    AudioQueueSetParameter(mAudioPlayer, kAudioQueueParam_Volume, 0.85);
    AudioQueueStart(mAudioPlayer, NULL);
    return YES;
}

-(void)play:(NSData *)data{
    [mAudioLock lock];
    int len = (int)[data length];
    if (len > 0 && len + mDataLen < MAX_BUFFER_SIZE) {
        memcpy(mPCMData+mDataLen, [data bytes],[data length]);
        mDataLen += AUDIO_BUFFER_SIZE;
    }
    [mAudioLock unlock];
}


-(void)stop{
    
    AudioQueueStop(mAudioPlayer, YES);
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        AudioQueueFreeBuffer(mAudioPlayer, mAudioBufferRef[i]);
    }
    AudioQueueDispose(mAudioPlayer, YES);
    
    free(mPCMData);
    mPCMData = nil;
    mAudioPlayer = nil;
    mAudioLock = nil;
    
}

-(void)handlerOutputAudioQueue:(AudioQueueRef)inAQ inBuffer:(AudioQueueBufferRef)inBuffer
{
    BOOL isFull = NO;
    if( mDataLen >=  AUDIO_BUFFER_SIZE)
    {
        [mAudioLock lock];
        memcpy(inBuffer->mAudioData, mPCMData, AUDIO_BUFFER_SIZE);
        mDataLen -= AUDIO_BUFFER_SIZE;
        memmove(mPCMData, mPCMData+AUDIO_BUFFER_SIZE, mDataLen);
        [mAudioLock unlock];
        isFull = YES;
    }
    
    if (!isFull) {
        memset(inBuffer->mAudioData, 0, AUDIO_BUFFER_SIZE);
    }
    
    inBuffer->mAudioDataByteSize = AUDIO_BUFFER_SIZE;
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    
}
@end

static void sAudioQueueOutputCallback(void *                  inUserData,
                                       AudioQueueRef           inAQ,
                                       AudioQueueBufferRef     inBuffer) {
    
    
    AudioPlay *player = (__bridge AudioPlay *)(inUserData);
    [player handlerOutputAudioQueue:inAQ inBuffer:inBuffer];
    
}
