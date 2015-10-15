//
//  ASCamera.m
//  ASCamera
//
//  Created by 施安宏 on 2015/10/14.
//
//

#import "ASCamera.h"

@interface ASCamera()

@property GLKView               *livePreviewView;
@property AVCaptureDevice       *device;
@property AVCaptureInput        *input;
@property AVCaptureSession      *session;
@property AVCaptureConnection   *videoConnection;
@property AVCaptureConnection   *stillImageConnection;
@property AVCaptureVideoDataOutput  *videoFrameOutput;
@property AVCaptureStillImageOutput *stillImageOutput;

// Manuly EV
@property float maxEV;
@property float minEV;
@property float currentEV;

@end

@implementation ASCamera

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        /* Config device */
        [self configDeviceWithAutoMode];
        [self configInput];
        [self configOutput];
        [self configSession];
    }
    return self;
}

- (void)configDeviceWithAutoMode
{
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    /* Setup FOCUS with auto mode */
    if ([_device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        [_device lockForConfiguration:nil];
        [_device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        [_device unlockForConfiguration];
    }
    
    /* Setup EXPOSE with auto mode */
    if ([_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
    {
        [_device lockForConfiguration: nil];
        [_device setExposureMode:AVCaptureExposureModeAutoExpose];
        [_device unlockForConfiguration];
    }
    
    /* Setup WHITE BALANCE auto mode*/
    if ([_device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
        [_device lockForConfiguration: nil];
        [_device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
        [_device unlockForConfiguration];
    }
    
    // Setup EV value for manuly Expose adjust
    _maxEV = [_device maxExposureTargetBias]/4;
    _minEV = [_device minExposureTargetBias]/4;
    // Get EV value for current device
    _currentEV = 0;
}

- (void)configInput
{
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:nil];
}

- (void)configOutput
{
    /* Video frame Output (show live preview) */
    _videoFrameOutput = [[AVCaptureVideoDataOutput alloc]init];
    [_videoFrameOutput setAlwaysDiscardsLateVideoFrames:YES];
    [_videoFrameOutput setSampleBufferDelegate:self queue:dispatch_queue_create("video frame buffer delegate", DISPATCH_QUEUE_SERIAL)];
    
    /* Still image Output (take picture) */
    _stillImageOutput = [AVCaptureStillImageOutput new];
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [_stillImageOutput setOutputSettings:outputSettings];
}

- (void)configSession
{
    /* Session and Input Output*/
    [_session addInput:_input];
    [_session addOutput:_videoFrameOutput];
    [_session addOutput:_stillImageOutput];
    
    [self configSessionConnectionToPortrait:_videoFrameOutput];
    [self configSessionConnectionToPortrait:_stillImageOutput];
}

#pragma mark - config utility
- (void)configSessionConnectionToPortrait:(AVCaptureOutput *)output
{
    for (AVCaptureConnection *connection in output.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                if ([connection isVideoOrientationSupported])
                {
                    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
                }
                break;
            }
        }
    }
}
@end
