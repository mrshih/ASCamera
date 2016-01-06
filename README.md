##Installation
```
pod 'ASCamera', :git => 'https://github.com/mrshih/ASCamera'
```

##Usage
```objective-c

@property (strong, nonatomic) IBOutlet UIView *cameraView;
@property (nonatomic) ASCamera *camrea;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.camrea = [ASCamera cameraSingletons];
}

- (void)viewDidLayoutSubviews {
    [self.camrea attachOnLifeView:_cameraView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.camrea start];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.camrea stop];
}
```
