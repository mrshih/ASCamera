//
//  ASCamera.m
//  ASCamera
//
//  Created by 施安宏 on 2015/10/14.
//
//

#import "ASCamera.h"

@interface ASCamera()

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

// LiveView
@property EAGLContext           *glContext;
@property CIContext             *ciContext;

@end

@implementation ASCamera

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

#pragma mark - setter and getter
- (void)setLiveView:(GLKView *)liveView
{
    _liveView = liveView;
    
    /* OpenGL */
    // 創建OpenGLES渲染環境
    _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    // GLKView指定OpenGLES渲染環境+綁定
    [_liveView setContext:_glContext];
    _liveView.enableSetNeedsDisplay = NO;
    [_liveView bindDrawable];
    // 創建CIContext環境
    _ciContext = [CIContext contextWithEAGLContext:_glContext options:@{ kCIContextWorkingColorSpace : [NSNull null],kCIContextUseSoftwareRenderer : @(NO)}];
}

#pragma mark - init and config device

- (void)initCamera
{
    /* Config device */
    [self initDeviceWithAutoMode];
    [self initInput];
    [self initOutput];
    [self initSession];
}

- (void)initDeviceWithAutoMode
{
//    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
//    
//    /* Setup FOCUS with auto mode */
//    if ([_device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
//    {
//        [_device lockForConfiguration:nil];
//        [_device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
//        [_device unlockForConfiguration];
//    }
//    
//    /* Setup EXPOSE with auto mode */
//    if ([_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
//    {
//        [_device lockForConfiguration: nil];
//        [_device setExposureMode:AVCaptureExposureModeAutoExpose];
//        [_device unlockForConfiguration];
//    }
//    
//    /* Setup WHITE BALANCE auto mode*/
//    if ([_device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
//        [_device lockForConfiguration: nil];
//        [_device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
//        [_device unlockForConfiguration];
//    }
//    
//    // Setup EV value for manuly Expose adjust
//    _maxEV = [_device maxExposureTargetBias]/4;
//    _minEV = [_device minExposureTargetBias]/4;
//    // Get EV value for current device
//    _currentEV = 0;
    
    /* Device */
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // 給調整曝光用的計算
    _maxEV = [_device maxExposureTargetBias]/4;
    _minEV = [_device minExposureTargetBias]/4;
    _currentEV = 0;
    
    if ([_device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
    {
        [_device lockForConfiguration:nil];
        [_device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
        [_device unlockForConfiguration];
    }

}

- (void)initInput
{
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:nil];
}

- (void)initOutput
{
    /* Video frame Output */
    _videoFrameOutput = [[AVCaptureVideoDataOutput alloc]init];
    [_videoFrameOutput setAlwaysDiscardsLateVideoFrames:YES];
    [_videoFrameOutput setSampleBufferDelegate:self queue:dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL)];
    
    /* Still image Output (take picture) */
    _stillImageOutput = [AVCaptureStillImageOutput new];
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [_stillImageOutput setOutputSettings:outputSettings];
}

- (void)initSession
{
    _session = [[AVCaptureSession alloc] init];
    [_session beginConfiguration];
    [_session setSessionPreset:AVCaptureSessionPresetPhoto];
    
    /* Session and Input Output*/
    [_session addInput:_input];
    [_session addOutput:_videoFrameOutput];
    [_session addOutput:_stillImageOutput];
    [_session commitConfiguration];
    
    [self configSessionConnectionToPortrait:_videoFrameOutput];
    [self configSessionConnectionToPortrait:_stillImageOutput];
}

#pragma mark - play & stop
- (void)startStream
{
    [_session startRunning];
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

#pragma mark - call back from data out put
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [[CIImage alloc] initWithCVImageBuffer:pixelBuffer];
    // 這個地方到時候要建立工廠
    if (_glContext && _ciContext) {
        if (_glContext != [EAGLContext currentContext])
        {
            [EAGLContext setCurrentContext:_glContext];
        }
        
        [_ciContext drawImage:ciImage inRect:CGRectMake(0, 0, _liveView.drawableWidth, _liveView.drawableHeight) fromRect:ciImage.extent];
        [_liveView display];
    }
}
@end
