//
//  ViewController.h
//  ASCamera
//
//  Created by 施安宏 on 2015/10/14.
//
//

#import <UIKit/UIKit.h>
#import "ASCamera.h"

@interface ViewController : UIViewController

@property (strong, nonatomic) IBOutlet GLKView *liveView;
- (IBAction)anyGesture:(id)sender;
- (IBAction)shot:(id)sender;

@end

