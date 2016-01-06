//
//  ASCamera.h
//  TideCamera
//
//  Created by 施安宏 on 2015/10/15.
//  Copyright © 2015年 tid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@import AVFoundation;
@import Photos;

typedef void (^shotCompleteHandler)(UIImage *photo, BOOL successful);

@interface ASCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

+ (instancetype)cameraSingletons;
- (void)attachOnLifeView:(UIView*)view;
- (void)start;
- (void)stop;
- (void)shotPhoto:(shotCompleteHandler)handler;
- (void)recordMovie;
- (void)flipCameras;
- (AVCaptureFlashMode)autoPollingFlashMode;

- (void)gestureEventReciver:(id)sender;

// UI是否要顯示
- (void) isFlashAvailable;

// UI是否要hight light
- (void) isFlashActive;
@end
