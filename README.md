# QRScan
二维码/条形码扫描

简书：http://www.jianshu.com/p/7af1c18c32e4

### 效果图

图是用itool实施桌面录制的，看起来会很卡顿
![image](https://github.com/longitachi/QRScan/blob/master/scan.gif)

### 使用方法
```objc
- (IBAction)btnScanClick:(id)sender {
    QRScanViewController *vc = [[QRScanViewController alloc] init];
    vc.delegate = self;
    vc.hidesBottomBarWhenPushed = YES;
    [self showViewController:vc sender:nil];
}

//扫描结果回调
- (void)qrScanResult:(NSString *)result viewController:(QRScanViewController *)qrScanVC
{
    
}
```
