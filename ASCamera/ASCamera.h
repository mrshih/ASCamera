//
//  ASCamera.h
//  TideCamera
//
//  Created by 施安宏 on 2015/10/15.
//  Copyright © 2015年 tid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
@import AVFoundation;

@interface ASCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (strong, nonatomic) GLKView *liveView;

- (instancetype)init;

- (void)startStream;
- (void)shotPhoto;
- (void)flipCameras;

- (void)gestureEventReciver:(id)sender;

// UI是否要顯示
- (void) isFlashAvailable;

// UI是否要hight light
- (void) isFlashActive;
@end
