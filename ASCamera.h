//
//  ASCamera.h
//  ASCamera
//
//  Created by 施安宏 on 2015/10/14.
//
//

@import Foundation;
@import AVFoundation;
@import GLKit;
#import <AVFoundation/AVCaptureSession.h>

@interface ASCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

- (instancetype)init;

@end
