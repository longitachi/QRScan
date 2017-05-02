# QRScan
二维码/条形码扫描

### 效果图

![image](https://github.com/longitachi/QRScan/blob/master/qrScan.gif)

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
