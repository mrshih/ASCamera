//
//  ViewController.m
//  ASCamera
//
//  Created by 施安宏 on 2015/10/14.
//
//

#import "ViewController.h"

@interface ViewController ()

@property ASCamera *camera;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void) viewDidLayoutSubviews
{
    _camera = [[ASCamera alloc]init];
    [_camera setLiveView:_liveView];
    [_camera startStream];
}
- (IBAction)anyGesture:(id)sender{
    [_camera gestureEventReciver:sender];
}

- (IBAction)shot:(id)sender {
    //[_camera shotPhoto];
    [_camera flipCameras];
}
@end
