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

typedef enum {
    CameraTypePhoto,
    CameraTypeVideo
} CameraType;

typedef void (^shotCompleteHandler)(UIImage *photo, BOOL successful);

@protocol ASCameraDelegate <NSObject>
@required
- (void)outputVideoToURL:(NSURL*)url;
@end

@interface ASCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate>

@property (nonatomic) id delegate;

+ (instancetype)cameraSingletons;
- (void)attachOnLifeView:(UIView*)view witMode:(CameraType)type;
- (void)start;
- (void)stop;
- (void)shotPhotoAndSetSaveToSystemAblum:(BOOL)flag :(shotCompleteHandler)handler;
- (void)recordVideo:(NSString *)path;
- (void)stopRecordVideo;
- (BOOL)isRecording;
- (void)flipCameras;
- (AVCaptureFlashMode)autoPollingFlashMode;
- (void)changeRecordMode:(CameraType)type;

- (void)gestureEventReciver:(id)sender;

// UI是否要顯示
- (void) isFlashAvailable;

// UI是否要hight light
- (void) isFlashActive;
@end
