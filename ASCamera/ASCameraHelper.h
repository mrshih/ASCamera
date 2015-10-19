//
//  ASCameraHelper.h
//  ASCamera
//
//  Created by 施安宏 on 2015/10/19.
//
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface ASCameraHelper : NSObject

+ (BOOL)isFrontCameraAvailable;
+ (AVCaptureDevice *)frontCamera;
+ (AVCaptureDevice *)backCamera;

@end
