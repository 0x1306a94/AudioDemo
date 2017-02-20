//
//  ViewController.m
//  AudioDemo
//
//  Created by king on 2017/2/19.
//  Copyright © 2017年 king. All rights reserved.
//

#import "ViewController.h"
#import "AudioTools.h"
#import "AudioPlay.h"
#import "SJAudioQueueRecord.h"

@interface ViewController ()
@property (nonatomic, strong) AudioTools *tools;
@property (nonatomic, strong) AudioPlay *play;
@property (nonatomic, strong) SJAudioQueueRecord *record;
@property (nonatomic, assign) BOOL b;
@property (weak, nonatomic) IBOutlet UIButton *btnOne;
@property (weak, nonatomic) IBOutlet UIButton *btnTow;
@property (weak, nonatomic) IBOutlet UILabel *tipsLabel;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.tools = [[AudioTools alloc] init];
    self.play = [[AudioPlay alloc] init];
    self.record = [[SJAudioQueueRecord alloc] init];
    
    
    
    
}

- (IBAction)recording:(UIButton *)sender {

    if (sender.selected) {
        [self.tools stopRecording];
        self.btnTow.enabled = YES;
        self.tipsLabel.text = @"";
    } else {
        [self.tools startRecording];
        self.btnTow.enabled = NO;
        self.tipsLabel.text = @"固定值:\n采样率: 8000\n缓冲区: 2048";
    }
    
    sender.selected = !sender.selected;

}

- (IBAction)recordingdynamic:(UIButton *)sender {
    
    self.b = NO;
    while (self.b) {
        NSError *error = nil;
        BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                                          error:&error];
        
        if (!ret) {
            NSLog(@"设置环境失败: %@", error);
            self.b = NO;
            return;
        }
        
        ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
        if (!ret) {
            NSLog(@"启动失败: %@", error);
            self.b = NO;
            return;
        }
        self.b = YES;
    }
    
    if (sender.selected) {
        [self.record stopRecord];
        [[AVAudioSession sharedInstance] setActive:NO error:NULL];
        self.b = NO;
        self.btnOne.enabled = YES;
        self.tipsLabel.text = @"";
    } else {
        
        [self.record startRecord:@"test.caf" SyncPlay:YES];
        self.btnOne.enabled = NO;
        NSString *str = [NSString stringWithFormat:@"动态计算:\n采样率: %d\n缓冲区: %d", (int)self.record.mSampleRate, self.record.audioBufferSize];
        self.tipsLabel.text = str;
    }
    
    sender.selected = !sender.selected;
}


@end
