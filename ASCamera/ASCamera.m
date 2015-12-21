//
//  ASCamera.m
//  ASCamera
//
//  Created by 施安宏 on 2015/10/14.
//
//

#import "ASCamera.h"
#import "ASCameraHelper.h"
#import <pop/POP.h>

@interface ASCamera(){
    UIImageView *focusImage;
}
//@property (strong, nonatomic) GLKView *liveView;
@property (strong, nonatomic)UIView *liveView;

@property AVCaptureDevice       *device;
@property AVCaptureInput        *input;
@property AVCaptureSession      *session;

@property AVCaptureConnection   *videoConnection;
@property AVCaptureConnection   *stillImageConnection;

//@property AVCaptureVideoDataOutput  *videoFrameOutput;
@property AVCaptureStillImageOutput *stillImageOutput;
@property AVCaptureMovieFileOutput  *movieFileOutput;

@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

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

// Manuly 16:9, 4:3
@property NSLayoutConstraint *sixnightRatio;
@property BOOL isFullScreenMode;
@end

@implementation ASCamera

- (instancetype)initWithLifeView:(UIView*)view
{
    self = [super init];
    if (self) {
        _liveView = view;
        /* Config device */
        [self initDeviceWithAutoMode];
        [self initInput];
        [self initOutput];
        [self initSession];
        [self initLiveView];
        
        // defult scale
        _currentScale = 1.0f;
    }
    return self;
}

#pragma mark - Setter And Getter
- (void)setLiveView:(GLKView *)liveView
{
    //    _liveView = liveView;
    //
    //    // add 16:9 constrants
    //    _sixnightRatio = [NSLayoutConstraint constraintWithItem:_liveView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:_liveView attribute:NSLayoutAttributeWidth multiplier:1.3f constant:0.0f];
    //    _sixnightRatio.active = NO;
    //    [liveView addConstraint:_sixnightRatio];
    //
    //    /* OpenGL */
    //    // 創建OpenGLES渲染環境
    //    _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    //    // GLKView指定OpenGLES渲染環境+綁定
    //    [_liveView setContext:_glContext];
    //    _liveView.enableSetNeedsDisplay = NO;
    //    [_liveView bindDrawable];
    //    // 創建CIContext環境
    //    _ciContext = [CIContext contextWithEAGLContext:_glContext options:@{ kCIContextWorkingColorSpace : [NSNull null],kCIContextUseSoftwareRenderer : @(NO)}];
}

- (void)initLiveView {
    // preview layer
    CGRect bounds = self.liveView.layer.bounds;
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _captureVideoPreviewLayer.bounds = bounds;
    _captureVideoPreviewLayer.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    [self.liveView.layer addSublayer:_captureVideoPreviewLayer];
}

#pragma mark - Camera Init and Config Device
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
        [_device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        [_device unlockForConfiguration];
    }
    
    /* Setup WHITE BALANCE auto mode*/
    if ([_device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
        [_device lockForConfiguration: nil];
        [_device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
        [_device unlockForConfiguration];
    }
    
    /* Auto Flash Mode */
    if ([_device isFlashModeSupported:AVCaptureFlashModeAuto]) {
        [_device lockForConfiguration: nil];
        [_device setFlashMode:AVCaptureFlashModeAuto];
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
    //    _videoFrameOutput = [[AVCaptureVideoDataOutput alloc]init];
    //    [_videoFrameOutput setAlwaysDiscardsLateVideoFrames:YES];
    //    [_videoFrameOutput setSampleBufferDelegate:self queue:dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL)];
    
    /* Still image Output (take picture) */
    _stillImageOutput = [AVCaptureStillImageOutput new];
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [_stillImageOutput setOutputSettings:outputSettings];
    
    _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [_movieFileOutput setMovieFragmentInterval:kCMTimeInvalid];
}

- (void)initSession
{
    _session = [[AVCaptureSession alloc] init];
    [_session beginConfiguration];
    [_session setSessionPreset:AVCaptureSessionPresetPhoto];
    
    /* Session and Input Output*/
    [_session addInput:_input];
    //    [_session addOutput:_videoFrameOutput];
    [_session addOutput:_stillImageOutput];
    [_session commitConfiguration];
    
    //    [self configSessionConnectionToPortrait:_videoFrameOutput];
    [self configSessionConnectionToPortrait:_stillImageOutput];
}

/*
 * 根據鏡頭設定connection，這個方法通常在seeion被change之後需要被呼叫，因為connection某西設定如鏡像需要設定。
 */
- (void)configSessionConnectionToPortrait:(AVCaptureOutput *)output
{
    for (AVCaptureConnection *connection in output.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                if ([connection isVideoOrientationSupported])
                {
                    if ([output isKindOfClass:[AVCaptureVideoDataOutput class]]) {
                        _videoConnection = connection;
                    }else if ([output isKindOfClass:[AVCaptureStillImageOutput class]]){
                        _stillImageConnection = connection;
                    }
                    
                    /* For ALL */
                    // Set Portrait
                    [_videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
                    
                    /* For Front Camera only */
                    if (_device == [ASCameraHelper frontCamera]) {
                        [_videoConnection setVideoMirrored:YES];
                    }
                }
                break;
            }
        }
    }
}


#pragma mark - Change Front And Back Camera
- (void)flipCameras
{
    [_session beginConfiguration];
    [_session removeInput:_input];
    if (_device != [ASCameraHelper frontCamera]) {
        _device = [ASCameraHelper frontCamera];
    }else if(_device == [ASCameraHelper frontCamera]){
        _device = [ASCameraHelper backCamera];
    }
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:nil];
    [_session addInput:_input];
    [_session commitConfiguration];
    
    //    [self configSessionConnectionToPortrait:_videoFrameOutput];
    [self configSessionConnectionToPortrait:_stillImageOutput];
}

#pragma mark - Flash Control
- (AVCaptureFlashMode)autoPollingFlashMode {
    [_device lockForConfiguration:nil];
    switch ([_device flashMode]) {
        case AVCaptureFlashModeOff:
            if ([_device isFlashModeSupported:AVCaptureFlashModeAuto]) {
                [_device setFlashMode:AVCaptureFlashModeAuto];
            }
            break;
            
        case AVCaptureFlashModeOn:
            if ([_device isFlashModeSupported:AVCaptureFlashModeOff]) {
                [_device setFlashMode:AVCaptureFlashModeOff];
            }
            break;
            
        case AVCaptureFlashModeAuto:
            if ([_device isFlashModeSupported:AVCaptureFlashModeOn]) {
                [_device setFlashMode:AVCaptureFlashModeOn];
            }
            break;
            
        default:
            break;
    }
    [_device unlockForConfiguration];
    return [_device flashMode];
}

#pragma mark - Live View play & stop
- (void)startStream
{
    [_session startRunning];
}

- (void)stopStream
{
    [_session stopRunning];
}

# pragma mark - Live View Gesture Touch Delegate
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

#pragma mark - Live View Ration Change
- (void) liveViewRationChange
{
    //    if ([_glViewRatio isActive]) {
    //        [_glViewRatio setActive:NO];
    //        [_sixnightRatio setActive:YES];
    //        [_glViewBottomSpace setActive:NO];
    //    }else{
    //        [_glViewRatio setActive:YES];
    //        [_sixnightRatio setActive:NO];
    //        [_glViewBottomSpace setActive:YES];
    //    }
    //
    //    [UIView animateWithDuration:0.5 animations:^{
    //        [self.view layoutIfNeeded];
    //    }];
}

//#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
//- (void)captureOutput:(AVCaptureOutput *)captureOutput
//didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
//       fromConnection:(AVCaptureConnection *)connection
//{
//    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    CIImage *ciImage = [[CIImage alloc] initWithCVImageBuffer:pixelBuffer];
//    // 這個地方到時候要建立工廠
//    if (_glContext && _ciContext) {
//        if (_glContext != [EAGLContext currentContext])
//        {
//            [EAGLContext setCurrentContext:_glContext];
//        }
//
//        [_ciContext drawImage:ciImage inRect:CGRectMake(0, 0, _liveView.drawableWidth, _liveView.drawableHeight) fromRect:ciImage.extent];
//        [_liveView display];
//    }
//}

#pragma mark - Managing Focus Setting
- (void)focusWithLocationFromSender:(id)sender
{
    UITapGestureRecognizer *tap = sender;
    if (tap.state == UIGestureRecognizerStateRecognized) {
        CGPoint point = [sender locationInView:_liveView];
        
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        CGPoint pointOfInterest = CGPointZero;
        CGSize frameSize = _liveView.bounds.size;
        
        pointOfInterest = CGPointMake(point.y / frameSize.height, 1.f - (point.x / frameSize.width));
        
        [self showFocusAnimationWithPoint:point];
        
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

#pragma mark - Managing Expose Setting
- (void)exposeAdjustWithLocationFromSender:(id)sender
{
    float   adjust_unit = 0.06;
    
    if([sender isKindOfClass:[UIPanGestureRecognizer class]]){
        UIPanGestureRecognizer *recognizer = sender;
        
        if(recognizer.state == UIGestureRecognizerStateEnded){
            [_device unlockForConfiguration];
        }
        
        CGPoint vel = [recognizer velocityInView:_liveView];
        
        if([_device lockForConfiguration:nil]){
            if (vel.y <0)   // panning down
            {
                if (_currentEV + adjust_unit < _maxEV) {
                    _currentEV  = _currentEV + adjust_unit;
                    NSLog(@"%f",_currentEV);
                    [_device setExposureTargetBias:_currentEV completionHandler:^(CMTime syncTime) {
                        
                    }];
                }
            }else{
                if (_currentEV - adjust_unit > _minEV) {
                    _currentEV  = _currentEV - adjust_unit;
                    NSLog(@"%f",_currentEV);
                    [_device setExposureTargetBias:_currentEV completionHandler:^(CMTime syncTime) {
                        
                    }];
                }
            }
        }
    }
}

#pragma mark - Managing Scale Setting
- (void)scaleWithLocationFromSender:(id)sender
{
    int     scale_max   = _device.activeFormat.videoMaxZoomFactor;
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

#pragma mark - Managing Flash Setting
- (void) isFlashAvailable
{
    [_device isFlashAvailable];
}

- (void) isFlashActive
{
    [_device isFlashActive];
}

- (void) setFlashMode:(AVCaptureFlashMode)mode
{
    if (![_device isFlashModeSupported:mode]) {
        return;
    }
    [_device lockForConfiguration:nil];
    [_device setFlashMode:AVCaptureFlashModeOn];
    [_device unlockForConfiguration];
}

#pragma mark - Take Picture
- (void)shotPhoto:(shotCompleteHandler)handler {
    
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    AVCaptureVideoOrientation videoOrientation = [self videoOrientationForDeviceOrientation:deviceOrientation];
    [_stillImageConnection setVideoOrientation:videoOrientation];
    
    //__weak __typeof(self)weakself = self;
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection:_stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        //__strong __typeof(self)strongself = weakself;
        
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image = [[UIImage alloc] initWithData:imageData];
        if (_isFullScreenMode) {
            //            UIImage *crop_image =[strongself cropImage:image withCropSize:CGSizeMake(1836, 3264)];
            //
            //            CFDictionaryRef metadata = CMCopyDictionaryOfAttachments(NULL, imageDataSampleBuffer, kCMAttachmentMode_ShouldPropagate);
            //            NSDictionary *meta = [[NSDictionary alloc] initWithDictionary:(__bridge NSDictionary *)(metadata)];
            //            CFRelease(metadata);
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                //NSLog(@"Finished adding asset. %@", (success ? @"SUCCESSFUL" : error));
            }
            handler(image, success);
        }];
    }];
}

- (AVCaptureVideoOrientation)videoOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    AVCaptureVideoOrientation result = (AVCaptureVideoOrientation) deviceOrientation;
    
    switch (deviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            result = AVCaptureVideoOrientationLandscapeRight;
            break;
            
        case UIDeviceOrientationLandscapeRight:
            result = AVCaptureVideoOrientationLandscapeLeft;
            break;
            
        default:
            break;
    }
    
    return result;
}

#pragma mark - For 16:9 Picture Crop
- (UIImage *)cropImage:(UIImage *)image withCropSize:(CGSize)cropSize
{
    UIImage *newImage = nil;
    
    CGSize imageSize = image.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    
    CGFloat targetWidth = cropSize.width;
    CGFloat targetHeight = cropSize.height;
    
    CGFloat scaleFactor = 0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    
    CGPoint thumbnailPoint = CGPointMake(0, 0);
    
    if (CGSizeEqualToSize(imageSize, cropSize) == NO) {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        
        if (widthFactor > heightFactor) {
            scaleFactor = widthFactor;
        } else {
            scaleFactor = heightFactor;
        }
        
        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        
        
        if (widthFactor > heightFactor) {
            thumbnailPoint.y = (targetHeight - scaledHeight) * .5f;
        } else {
            if (widthFactor < heightFactor) {
                thumbnailPoint.x = (targetWidth - scaledWidth) * .5f;
            }
        }
    }
    
    UIGraphicsBeginImageContextWithOptions(cropSize, YES, 0);
    
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    
    [image drawInRect:thumbnailRect];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

#pragma mark - Pop animation related
- (void)showFocusAnimationWithPoint:(CGPoint)point {
    if (focusImage) {
        [focusImage pop_removeAllAnimations];
        [focusImage removeFromSuperview];
        focusImage = nil;
    }
    CGFloat imageWidth = 80;
    focusImage = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"cam_focus"]];
    [_liveView addSubview:focusImage];
    
    // ADD Focus animation
    POPSpringAnimation *springAnimation = [POPSpringAnimation animation];
    [springAnimation setProperty:[POPAnimatableProperty propertyWithName:kPOPViewAlpha]];
    springAnimation.velocity=@(1000);
    [springAnimation setFromValue:@(0.4f)];
    [springAnimation setToValue:@(1.0f)];
    springAnimation.springBounciness = 4.0f;
    springAnimation.springSpeed = 4.0f;
    
    //__weak POPSpringAnimation *weakAnimaton = springAnimation;
    springAnimation.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        //__strong POPSpringAnimation *animaton = weakAnimaton;
        [focusImage setImage:[UIImage imageNamed:@"cam_focus_good"]];
        //        [animaton pop_removeAllAnimations];
        //        animaton.beginTime = 1.3f;
        //        animaton.toValue = @(0.35f);
        
        [UIView animateWithDuration:0.0f delay:1.3f options:UIViewAnimationOptionCurveLinear animations:^{
            focusImage.alpha = 0.35f;
        } completion:^(BOOL finished) {
            
        }];
    };
    [focusImage pop_addAnimation:springAnimation forKey:@"focusImageIn"];
    [focusImage setFrame:CGRectMake(point.x-imageWidth/2, point.y-imageWidth/2, imageWidth, imageWidth)];
}
@end
