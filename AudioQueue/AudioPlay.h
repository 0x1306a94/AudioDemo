//
//  AudioPlay.h
//  AudioDemo
//
//  Created by king on 2017/2/19.
//  Copyright © 2017年 king. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;
@import AudioToolbox;
@import CoreAudio;
#define QUEUE_BUFFER_SIZE 3   //队列缓冲个数
#define AUDIO_BUFFER_SIZE 2048 //
#define MAX_BUFFER_SIZE 8000 //

@interface AudioPlay : NSObject
-(BOOL)start;
-(void)play:(NSData *)data;
-(void)stop;
@end
