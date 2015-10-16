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

// LiveView
@property EAGLContext           *glContext;
@property CIContext             *ciContext;

// Manuly EV
@property float maxEV;
@property float minEV;
@property float currentEV;

// Manuly Scale
@property float currentScale;
@property float pastPinchScaleValue;

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
    
    // defult scale
    _currentScale = 1.0f;
}

- (void)initDeviceWithAutoMode
{
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


# pragma mark Gesture Touch Delegate
- (void)gestureEventReciver:(id)sender
{
    // tap = 對焦
    if ([sender isKindOfClass:[UITapGestureRecognizer class]]) {
        [self focusWithLocationFromSender:sender];
    }
    
    // 曝光
    if ([sender isKindOfClass:[UIPanGestureRecognizer class]]) {
        [self exposeAdjustWithLocationFromSender:sender];
    }
    
    // Scale
    if ([sender isKindOfClass:[UIPinchGestureRecognizer class]]) {
        [self scaleWithLocationFromSender:sender];
    }
}

#pragma mark - config utility
/*
 * 透過connection讓畫面轉正
 */
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

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
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

#pragma mark - Focus, Expose Method
- (void)focusWithLocationFromSender:(id)sender
{
    UITapGestureRecognizer *tap = sender;
    if (tap.state == UIGestureRecognizerStateRecognized) {
        CGPoint point = [sender locationInView:_liveView];
        
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        CGPoint pointOfInterest = CGPointZero;
        CGSize frameSize = _liveView.bounds.size;
        
        pointOfInterest = CGPointMake(point.y / frameSize.height, 1.f - (point.x / frameSize.width));
        NSLog(@"%f,%f",pointOfInterest.x,pointOfInterest.y);
        if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            
            //Lock camera for configuration if possible
            NSError *error;
            if ([device lockForConfiguration:&error]) {
                
                if ([device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
                    [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
                }
                
                if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                    [device setFocusMode:AVCaptureFocusModeAutoFocus];
                    [device setFocusPointOfInterest:pointOfInterest];
                }
                
                if([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                    [device setExposureTargetBias:0 completionHandler:^(CMTime syncTime) {
                        
                    }];
                    [device setExposurePointOfInterest:pointOfInterest];
                    [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
                }
                
                [device unlockForConfiguration];
            }
        }
    }
}

- (void)exposeAdjustWithLocationFromSender:(id)sender
{
    if([sender isKindOfClass:[UIPanGestureRecognizer class]]){
        UIPanGestureRecognizer *recognizer = sender;
        
        if(recognizer.state == UIGestureRecognizerStateEnded){
            [_device unlockForConfiguration];
        }
        
        CGPoint vel = [recognizer velocityInView:_liveView];
        
        if([_device lockForConfiguration:nil]){
            if (vel.y <0)   // panning down
            {
                if (_currentEV + 0.06 < _maxEV) {
                    _currentEV  = _currentEV + 0.06;
                    NSLog(@"%f",_currentEV);
                    [_device setExposureTargetBias:_currentEV completionHandler:^(CMTime syncTime) {
                        
                    }];
                }
            }else{
                if (_currentEV - 0.06 > _minEV) {
                    _currentEV  = _currentEV - 0.06;
                    NSLog(@"%f",_currentEV);
                    [_device setExposureTargetBias:_currentEV completionHandler:^(CMTime syncTime) {
                        
                    }];
                }
            }
        }
    }
}

- (void)scaleWithLocationFromSender:(id)sender
{
    int     scale_max   = 5;
    int     scale_mini  = 1;
    float   adjust_unit = 0.03;
    
    UIPinchGestureRecognizer *recognizer = sender;
    if ([_device lockForConfiguration:nil]) {
        if (!_pastPinchScaleValue) {
            _pastPinchScaleValue = 1;
        }
        if (recognizer.scale > _pastPinchScaleValue) {//手指拉 _pastPinchScaleValue呈現下降趨勢
            if (_currentScale + adjust_unit < scale_max) {
                _currentScale = _currentScale + adjust_unit;
            }
        }else if (recognizer.scale < _pastPinchScaleValue){//手指縮
            if (_currentScale - adjust_unit > scale_mini) {
                _currentScale = _currentScale - adjust_unit;
            }
        }
        _pastPinchScaleValue = recognizer.scale;
        [_device rampToVideoZoomFactor:_currentScale withRate:2];
    }
}
@end
