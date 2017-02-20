//
//  SJAudioQueueRecord.m
//  AudioDemo
//
//  Created by king on 2017/2/20.
//  Copyright © 2017年 king. All rights reserved.
//

#import "SJAudioQueueRecord.h"
//#import "AudioPlay.h"

// 输出回调
void audioQueueOutputHandler(void * __nullable       inUserData,
      AudioQueueRef           inAQ,
      AudioQueueBufferRef     inBuffer);
// 输入回调
void audioQueueInputHandler(void * __nullable               inUserData,
                            AudioQueueRef                   inAQ,
                            AudioQueueBufferRef             inBuffer,
                            const AudioTimeStamp *          inStartTime,
                            UInt32                          inNumberPacketDescriptions,
                            const AudioStreamPacketDescription * __nullable inPacketDescs);

@implementation SJAudioQueueRecordDesc

@end

@interface  SJAudioQueueRecord ()
@property (nonatomic, strong)  SJAudioQueueRecordDesc  *recordDesc;
@property (nonatomic, assign) BOOL isRecording;
@property (nonatomic, assign) BOOL syncPlay;
//@property (nonatomic, strong) AudioPlay *play;
@end


@implementation SJAudioQueueRecord
{
    NSCondition *mAudioLock;
    AudioStreamBasicDescription playFormat;
    AudioQueueRef mAudioPlayerQueue;
    AudioQueueBufferRef mAudioBufferRef[kNumberAudioQueueBuffers];
    void *mPCMData;
    int mDataLen;
    int AUDIO_BUFFER_SIZE;
    int MAX_BUFFER_SIZE;
    
}
- (void)startRecord:(NSString *)inRecordFile {
    [self startRecord:inRecordFile SyncPlay:NO];
}

- (void)startRecord:(NSString *)inRecordFile SyncPlay:(BOOL)syncPlay {
    self.syncPlay = syncPlay;
    
    if (inRecordFile.length == 0) {
        return;
    }
    
    int bufferByteSize;
    UInt32 size;
    CFURLRef url = nil;
    self.recordDesc = [[SJAudioQueueRecordDesc alloc] init];
    self.recordDesc->mFileName = CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)inRecordFile);
    if (![self setupAuidoInputFormat:kAudioFormatLinearPCM]) {
        return;
    }
    
    OSStatus error = AudioQueueNewInput(&self.recordDesc->mFormat,
                                        audioQueueInputHandler,
                                        (__bridge void *)self, NULL, NULL,
                                        0, &self.recordDesc->mQueue);
    
    if (error != noErr) {
        NSLog(@"添加 AudioQueueNewInput 失败");
        return;
    }
    
    self.recordDesc->mRecordPacket = 0;
    
    size = sizeof(self.recordDesc->mFormat);
    error = AudioQueueGetProperty(self.recordDesc->mQueue,
                                  kAudioQueueProperty_StreamDescription,
                                  &self.recordDesc->mFormat, &size);
    if (error != noErr) {
        NSLog(@"找不到队列格式");
        return;
    }
    
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Caches"] stringByAppendingPathComponent:inRecordFile];
    self->_filePath = path;
    // 创建文件
    url = CFURLCreateWithString(kCFAllocatorDefault, (__bridge CFStringRef)path, NULL);
    error = AudioFileCreateWithURL(url, kAudioFileCAFType, &self.recordDesc->mFormat, kAudioFileFlags_EraseFile, &self.recordDesc->mRecordFile);
    if (url) {
        CFRelease(url);
    }
    
    if (error != noErr) {
        NSLog(@"创建文件失败");
        return;
    }
    
    [self copyEncoderCookieToFile];
    
    bufferByteSize = [self computeRecordBufferSize:self.recordDesc->mQueue format:self.recordDesc->mFormat seconds:kBufferDurationSeconds];
    self->_audioBufferSize = bufferByteSize;
    self->_mSampleRate = (int)self.recordDesc->mFormat.mSampleRate;
    AUDIO_BUFFER_SIZE = bufferByteSize;
    MAX_BUFFER_SIZE = self.recordDesc->mFormat.mSampleRate;
    NSLog(@"AUDIO_BUFFER_SIZE: %d", bufferByteSize);
    NSLog(@"MAX_BUFFER_SIZE: %d", MAX_BUFFER_SIZE);
    for (int i = 0; i < kNumberAudioQueueBuffers; i++) {
        AudioQueueAllocateBuffer(self.recordDesc->mQueue, bufferByteSize, &self.recordDesc->mBufferRef[i]);
        AudioQueueEnqueueBuffer(self.recordDesc->mQueue, self.recordDesc->mBufferRef[i], 0, NULL);
    }
    self.isRecording = YES;
    AudioQueueStart(self.recordDesc->mQueue, NULL);
    if (syncPlay) {
        
        [self setupPlay];
    }
    NSLog(@"文件路径: %@",path);
}
- (void)stopRecord {
    if (self.recordDesc) {
    
    if (self.recordDesc->mQueue) {
        AudioQueueStop(self.recordDesc->mQueue, true);
        AudioQueueDispose(self.recordDesc->mQueue, true);
        if (self.recordDesc->mBufferRef) {
            for (int i = 0; i < kNumberAudioQueueBuffers; i++) {
                AudioQueueFreeBuffer(self.recordDesc->mQueue, self.recordDesc->mBufferRef[i]);
            }
        }
        self.recordDesc->mQueue = NULL;
    }
    
    if (self.recordDesc->mRecordFile) {
        AudioFileClose(self.recordDesc->mRecordFile);
        self.recordDesc->mRecordFile = NULL;
    }
    if (self.recordDesc->mFileName) {
        CFRelease(self.recordDesc->mFileName);
        self.recordDesc->mFileName = NULL;
    }
    
        self.recordDesc = nil;
    }
    
    if (self.syncPlay) {
        
        if (mAudioPlayerQueue) {
            
            AudioQueueStop(mAudioPlayerQueue, true);
            AudioQueueDispose(mAudioPlayerQueue, true);
            if (mAudioBufferRef) {
                for (int i = 0; i < kNumberAudioQueueBuffers; i++) {
                    AudioQueueFreeBuffer(mAudioPlayerQueue, mAudioBufferRef[i]);
                }
            }
            mAudioPlayerQueue = NULL;
        }
        
        if (mPCMData) {
            free(mPCMData);
            mPCMData = nil;
        }
        
        if (mAudioLock) {
            mAudioLock = nil;
        }
    }
}

#pragma mark -private method
- (BOOL)setupAuidoInputFormat:(UInt32)inFormatID {
    
    memset((void *)&self.recordDesc->mFormat, 0, sizeof(self.recordDesc->mFormat));
    
    UInt32 size = sizeof(self.recordDesc->mFormat.mSampleRate);
    
    OSStatus error = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                                             &size,
                                             &self.recordDesc->mFormat.mSampleRate);
    
    if (error != noErr) {
        NSLog(@"找不到硬件采样率");
        return NO;
    }
    
    size = sizeof(self.recordDesc->mFormat.mChannelsPerFrame);
    error = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareInputNumberChannels,
                                    &size,
                                    &self.recordDesc->mFormat.mChannelsPerFrame);
    
    if (error != noErr) {
        NSLog(@"找不到输入通道数");
        return NO;
    }
    
    self.recordDesc->mFormat.mFormatID = inFormatID;
    if (inFormatID == kAudioFormatLinearPCM) {
    
        self.recordDesc->mFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        self.recordDesc->mFormat.mBitsPerChannel = 16;
        self.recordDesc->mFormat.mBytesPerPacket = self.recordDesc->mFormat.mBytesPerFrame = ((self.recordDesc->mFormat.mBitsPerChannel / 8) * self.recordDesc->mFormat.mChannelsPerFrame);
        self.recordDesc->mFormat.mFramesPerPacket = 1;
    }
    
    return YES;
}
- (BOOL)setupAuidoOutFormat:(UInt32)inFormatID {
    
    memset((void *)&playFormat, 0, sizeof(playFormat));
    
    UInt32 size = sizeof(playFormat.mSampleRate);
    
    OSStatus error = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                                             &size,
                                             &playFormat.mSampleRate);
    
    if (error != noErr) {
        NSLog(@"找不到硬件采样率");
        return NO;
    }
    
    size = sizeof(playFormat.mChannelsPerFrame);
    error = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputNumberChannels,
                                    &size,
                                    &playFormat.mChannelsPerFrame);
    
    if (error != noErr) {
        NSLog(@"找不到输入通道数");
        return NO;
    }
    
    playFormat.mFormatID = inFormatID;
    if (inFormatID == kAudioFormatLinearPCM) {
        
        playFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        playFormat.mBitsPerChannel = 16;
        playFormat.mBytesPerPacket = playFormat.mBytesPerFrame = ((playFormat.mBitsPerChannel / 8) * playFormat.mChannelsPerFrame);
        playFormat.mFramesPerPacket = 1;
    }

    return YES;
}
- (BOOL)copyEncoderCookieToFile {
    
    UInt32 propertySize;
    OSStatus error = AudioQueueGetPropertySize(self.recordDesc->mQueue, kAudioQueueProperty_MagicCookie, &propertySize);
    if (error == noErr && propertySize > 0) {
        Byte *magicCookie[propertySize];
        UInt32 magicCookieSize;
        
        
        error = AudioQueueGetProperty(self.recordDesc->mQueue, kAudioQueueProperty_MagicCookie, magicCookie, &propertySize);
        if (error != noErr) {
            NSLog(@"The get audio converter 's magic cookies failed");
            return NO;
        }
        magicCookieSize = propertySize;
        UInt32 willEatTheCookie = false;
        
        error = AudioFileGetPropertyInfo(self.recordDesc->mRecordFile, kAudioFilePropertyMagicCookieData, NULL, &willEatTheCookie);
        
        if (error == noErr && willEatTheCookie) {
            error = AudioFileSetProperty(self.recordDesc->mRecordFile, kAudioFilePropertyMagicCookieData, magicCookieSize, magicCookie);
        }
        
        free(magicCookie);
    }
    return YES;
}
- (int)computeRecordBufferSize:(AudioQueueRef)queue
                        format:(AudioStreamBasicDescription)format
                       seconds:(float)seconds {
    
    int packets, frames, bytes = 0;
    
    frames = (int)ceil(seconds * format.mSampleRate);
    if (format.mBytesPerFrame > 0) {
        bytes = frames * format.mBytesPerFrame;
    } else {
        UInt32 maxPacketSize;
        if (format.mBytesPerPacket > 0) {
            maxPacketSize = format.mBytesPerPacket;
        } else {
            UInt32 propertySize = sizeof(maxPacketSize);
            OSStatus error = AudioQueueGetProperty(queue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &propertySize);
            if (error != noErr) {
                return 0;
            }
        }
        
        if (format.mFramesPerPacket > 0) {
            packets = frames / format.mFramesPerPacket;
        } else {
            packets = frames;
        }
        
        if (packets == 0) {
            packets = 1;
        }
        bytes = packets * maxPacketSize;
    }
    
    return bytes;
}

- (BOOL)setupPlay {
    [self setupAuidoOutFormat:kAudioFormatLinearPCM];
    mPCMData = malloc(MAX_BUFFER_SIZE);
    mAudioLock = [[NSConditionLock alloc] init];
    // 创建输出队列
    AudioQueueNewOutput(&playFormat,
                        audioQueueOutputHandler,
                        (__bridge void *)self, NULL, NULL,
                        0, &mAudioPlayerQueue);
    
    for (int i = 0; i <kNumberAudioQueueBuffers ; i++) {
        
        AudioQueueAllocateBuffer(mAudioPlayerQueue, AUDIO_BUFFER_SIZE, &mAudioBufferRef[i]);
        memset(mAudioBufferRef[i]->mAudioData, 0, AUDIO_BUFFER_SIZE);
        mAudioBufferRef[i]->mAudioDataByteSize = AUDIO_BUFFER_SIZE;
        AudioQueueEnqueueBuffer(mAudioPlayerQueue, mAudioBufferRef[i], 0, NULL);
    }
    
    
    AudioQueueSetParameter(mAudioPlayerQueue, kAudioQueueParam_Volume, 0.85);
    AudioQueueStart(mAudioPlayerQueue, NULL);
    
    return YES;
}
- (void)play:(NSData *)data {
    
    [mAudioLock lock];
    int len = (int)[data length];
    if (len > 0 && len + mDataLen < MAX_BUFFER_SIZE) {
        memcpy(mPCMData+mDataLen, [data bytes],[data length]);
        mDataLen += AUDIO_BUFFER_SIZE;
    }
    [mAudioLock unlock];
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

void audioQueueOutputHandler(void * __nullable       inUserData,
                             AudioQueueRef           inAQ,
                             AudioQueueBufferRef     inBuffer) {
    
    SJAudioQueueRecord *record = (__bridge SJAudioQueueRecord *)inUserData;
    [record handlerOutputAudioQueue:inAQ inBuffer:inBuffer];
}

void audioQueueInputHandler(void * __nullable               inUserData,
                            AudioQueueRef                   inAQ,
                            AudioQueueBufferRef             inBuffer,
                            const AudioTimeStamp *          inStartTime,
                            UInt32                          inNumberPacketDescriptions,
                            const AudioStreamPacketDescription * __nullable inPacketDescs) {
    
    SJAudioQueueRecord *record = (__bridge SJAudioQueueRecord *)inUserData;
    
    if (inNumberPacketDescriptions > 0) {
        AudioFileWritePackets(record.recordDesc->mRecordFile,
                              false,
                              inBuffer->mAudioDataByteSize,
                              inPacketDescs,
                              record.recordDesc->mRecordPacket,
                              &inNumberPacketDescriptions,
                              inBuffer->mAudioData);
        record.recordDesc->mRecordPacket += inNumberPacketDescriptions;
        
        if (record.syncPlay) {
            @autoreleasepool {

                NSData *data = [NSData dataWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
                [record play:data];
            }
        }
        
    }
    
    if (record.isRecording) {
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
    
}
