//
//  QRScanViewController.m
//  系统二维码扫描
//
//  Created by long on 17/4/29.
//  Copyright © 2017年 long. All rights reserved.
//

#import "QRScanViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>

#define Width [UIScreen mainScreen].bounds.size.width
#define Height [UIScreen mainScreen].bounds.size.height

@interface QRScanViewController () <AVCaptureMetadataOutputObjectsDelegate, CAAnimationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession *_session;//输入输出中间桥梁
    AVCaptureVideoPreviewLayer *_layer;
    UIView *_maskView;
    UIImageView *_scanLineView;
    
    UIStatusBarStyle _orginalStyle;
    
    ProgressView *_hud;
    
    BOOL _isFirstAppear;
    
    //提示将二维码放入框内label
    UILabel *_textLabel;
    
    //手电筒按钮
    UIButton *_torchBtn;
    //轻触照亮/关闭
    UILabel *_tipLabel;
    //光线第一次变暗
    BOOL _isFirstBecomeDark;
    
    float _lastBrightnessValue;
}

@end

@implementation QRScanViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_session stopRunning];
    [self switchTorch:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    _isFirstAppear = YES;
    _isFirstBecomeDark = YES;
    _hud = [[ProgressView alloc] init];
    [_hud show:self.view];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initScanUI) name:UIApplicationWillEnterForegroundNotification object:nil];
    [self initBaseUI];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (_scanLineView) {
        [_scanLineView removeFromSuperview];
        _scanLineView = nil;
    }
    _orginalStyle = [UIApplication sharedApplication].statusBarStyle;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    if (self.navigationController) {
        self.navigationController.navigationBar.hidden = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!_isFirstAppear) {
        [self initScanLineView];
        [_session startRunning];
        return;
    }
    [self initScanUI];
    [self initScan];
    [_hud hide];
    _isFirstAppear = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [UIApplication sharedApplication].statusBarStyle = _orginalStyle;
    if (self.navigationController) {
        self.navigationController.navigationBar.hidden = NO;
    }
}

- (void)initBaseUI
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(15, 27, 30, 30);
    [btn setImage:[UIImage imageNamed:@"ic_back.png"] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(btnBack) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(Width/2-30, 27, 60, 30)];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:18];
    label.text = @"扫一扫";
    [self.view addSubview:label];
    
    CGFloat pathWidth = Width-100;
    CGFloat orginY = (Height-pathWidth)/2-50+pathWidth;
    
    _textLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, orginY+15, pathWidth, 20)];
    _textLabel.text = @"将二维码放入框内，即可自动扫描";
    _textLabel.textAlignment = NSTextAlignmentCenter;
    _textLabel.font = [UIFont systemFontOfSize:14];
    _textLabel.textColor = [UIColor colorWithWhite:.7 alpha:1];
    [self.view addSubview:_textLabel];
    
    _torchBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _torchBtn.frame = CGRectMake(Width/2-15, orginY+40, 30, 30);
    _torchBtn.hidden = YES;
    [_torchBtn setImage:[UIImage imageNamed:@"torch_n"] forState:UIControlStateNormal];
    [_torchBtn setImage:[UIImage imageNamed:@"torch_s"] forState:UIControlStateSelected];
    [_torchBtn addTarget:self action:@selector(switchTorchClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_torchBtn];
    
    _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(Width/2-50, orginY+75, 100, 30)];
    _tipLabel.hidden = YES;
    _tipLabel.text = @"轻触照亮";
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.font = [UIFont systemFontOfSize:14];
    _tipLabel.textColor = [UIColor whiteColor];
    [self.view addSubview:_tipLabel];
}

- (void)initScanUI
{
    _maskView = [[UIView alloc] initWithFrame:self.view.bounds];
    _maskView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.4];
    [self.view addSubview:_maskView];
    [self.view sendSubviewToBack:_maskView];
    
    
    CGFloat pathWidth = Width-100;
    CGFloat orginY = (Height-pathWidth)/2-50;
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ic_scanBg.png"]];
    imageView.frame = CGRectMake(50, orginY, pathWidth, pathWidth);
    [self.view addSubview:imageView];
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    animation.duration = 0.25;
    animation.fromValue = @(0);
    animation.toValue = @(1);
    animation.delegate = self;
    [imageView.layer addAnimation:animation forKey:nil];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    
    CGMutablePathRef path = CGPathCreateMutable();
    
    CGFloat pathWidth = Width-100;
    CGFloat orginY = (Height-pathWidth)/2-50;
    //内部方框path
    CGPathAddRect(path, nil, CGRectMake(50, orginY, pathWidth, pathWidth));
    //外部大框path
    CGPathAddRect(path, nil, _maskView.bounds);
    //两个path取差集，即去除差集部分
    maskLayer.fillRule = kCAFillRuleEvenOdd;
    maskLayer.path = path;
    
    _maskView.layer.mask = maskLayer;
    
    [self initScanLineView];
}

- (void)initScanLineView
{
    CGFloat pathWidth = Width-100;
    CGFloat orginY = (Height-pathWidth)/2-50;
    
    if (_scanLineView) {
        [_scanLineView removeFromSuperview];
        _scanLineView = nil;
    }
    
    _scanLineView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ic_scanLine.png"]];
    
    CGRect frame = CGRectMake(55, orginY, pathWidth-10, 5);
    _scanLineView.frame = frame;
    
    frame.origin.y += pathWidth-5;
    [UIView animateWithDuration:4.0 delay:0.2 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear animations:^{
        _scanLineView.frame = frame;
    } completion:nil];
    [self.view addSubview:_scanLineView];
}

- (void)btnBack
{
    UIViewController *vc = [self.navigationController popViewControllerAnimated:YES];
    if (!vc) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - scan
- (BOOL)requestAuth
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    NSLog(@"status is:%ld", (long)status);
    
    if (status == AVAuthorizationStatusDenied) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:@"请在设置->隐私中允许该软件访问摄像头" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        [alert show];
        return NO;
    }
    if (status == AVAuthorizationStatusRestricted) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:@"设备不支持" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        [alert show];
        return NO;
    }
    
    if (![UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:@"模拟器不支持该功能" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"确定", nil];
        [alert show];
        return NO;
    }
    return YES;
}

- (void)initScan
{
    BOOL canInit = [self requestAuth];
    if (!canInit) {
        return;
    }
    
    //获取摄像设备
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    //创建输入流
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    //创建输出流
    AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
    //设置扫描有效区域
    /*
     1、这个CGRect参数和普通的Rect范围不太一样，它的四个值的范围都是0-1，表示比例。
     2、经过测试发现，这个参数里面的x对应的恰恰是距离左上角的垂直距离，y对应的是距离左上角的水平距离。
     3、宽度和高度设置的情况也是类似。
     3、举个例子如果我们想让扫描的处理区域是屏幕的下半部分，我们这样设置
     output.rectOfInterest = CGRectMake(0.5, 0, 0.5, 1);
     */
    
    output.rectOfInterest = CGRectMake(0.1, 0.2, 0.5, 0.5);
    //设置代理 在主线程里刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    
    //设置光感代理输出
    AVCaptureVideoDataOutput *respondOutput = [[AVCaptureVideoDataOutput alloc] init];
    [respondOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    
    //初始化链接对象
    if (_session) {
        [_session stopRunning];
    }
    _session = [[AVCaptureSession alloc] init];
    //高质量采集率
    [_session setSessionPreset:AVCaptureSessionPresetHigh];
    
    if ([_session canAddInput:input]) [_session addInput:input];
    if ([_session canAddOutput:output]) [_session addOutput:output];
    if ([_session canAddOutput:respondOutput]) [_session addOutput:respondOutput];
    
    //设置扫码支持的编码格式
    output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    
    _layer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _layer.frame = self.view.frame;
    [self.view.layer insertSublayer:_layer atIndex:0];
    //开始捕获
    [_session startRunning];
}

#pragma mark - 光感回调
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CFDictionaryRef metadataDict = CMCopyDictionaryOfAttachments(NULL,sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *metadata = [[NSMutableDictionary alloc] initWithDictionary:(__bridge NSDictionary*)metadataDict];
    CFRelease(metadataDict);
    NSDictionary *exifMetadata = [[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary] mutableCopy];
    // 该值在 -5~12 之间
    float brightnessValue = [[exifMetadata objectForKey:(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    if ((_lastBrightnessValue>0 && brightnessValue>0) ||
        (_lastBrightnessValue<=0 && brightnessValue<=0)) {
        return;
    }
    _lastBrightnessValue = brightnessValue;
    [self switchTorchBtnState:brightnessValue<=0];
}

#pragma mark - 扫描结果回调
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects.count > 0) {
        [_session stopRunning];
        AVMetadataMachineReadableCodeObject *metaDataObject = [metadataObjects objectAtIndex:0];
        
        [self switchTorch:NO];
        
        if ([self.delegate respondsToSelector:@selector(qrScanResult:viewController:)]) {
            [self.delegate performSelector:@selector(qrScanResult:viewController:) withObject:metaDataObject.stringValue withObject:self];
        }
    }
}

- (void)switchTorchClick:(UIButton *)btn
{
    [self switchTorch:!btn.isSelected];
}

- (void)switchTorch:(BOOL)on
{
    //更换按钮状态
    _torchBtn.selected = on;
    _tipLabel.text = [NSString stringWithFormat:@"轻触%@", on?@"关闭":@"照亮"];
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if ([device hasTorch]) {
        if (on) {
            //调用led闪光灯
            [device lockForConfiguration:nil];
            [device setTorchMode: AVCaptureTorchModeOn];
        } else {
            //关闭闪光灯
            if (device.torchMode == AVCaptureTorchModeOn) {
                [device setTorchMode: AVCaptureTorchModeOff];
            }
        }
    }
}

- (void)switchTorchBtnState:(BOOL)show
{
    _torchBtn.hidden = !show && !_torchBtn.isSelected;
    _tipLabel.hidden = !show && !_torchBtn.isSelected;
    _textLabel.hidden = show;
    if (show) {
        [_scanLineView removeFromSuperview];
        if (_isFirstBecomeDark) {
            CABasicAnimation *animate = [CABasicAnimation animationWithKeyPath:@"opacity"];
            animate.fromValue = @(1);
            animate.toValue = @(0);
            animate.duration = .6;
            animate.repeatCount = 2;
            [_torchBtn.layer addAnimation:animate forKey:nil];
            _isFirstBecomeDark = NO;
        }
    } else {
        [self initScanLineView];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end


@interface ProgressView ()
{
    UIActivityIndicatorView *_indictor;
    UILabel *_textLabel;
}

@end

@implementation ProgressView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initUI];
    }
    return self;
}


- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initUI];
    }
    return self;
}

- (void)initUI
{
    self.frame = CGRectMake([UIScreen mainScreen].bounds.size.width/2-50, [UIScreen mainScreen].bounds.size.height/2-50, 100, 100);
    
    _indictor = [[UIActivityIndicatorView alloc] init];
    _indictor.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    _indictor.center = CGPointMake(50, 50);
    [_indictor hidesWhenStopped];
    [self addSubview:_indictor];
    
    _textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.frame.size.height-20, self.frame.size.width, 20)];
    _textLabel.text = @"正在加载...";
    _textLabel.font = [UIFont systemFontOfSize:14];
    _textLabel.textAlignment = NSTextAlignmentCenter;
    _textLabel.textColor = [UIColor whiteColor];
    [self addSubview:_textLabel];
}

- (void)show:(UIView *)view
{
    [_indictor startAnimating];
    [view addSubview:self];
}

- (void)hide
{
    [_indictor stopAnimating];
    [self removeFromSuperview];
}

@end
