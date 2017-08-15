//
//  ViewController.m
//  QRScan
//
//  Created by long on 2017/5/2.
//  Copyright © 2017年 long. All rights reserved.
//

#import "ViewController.h"
#import "QRScanViewController.h"
#import "ResultViewController.h"

@interface ViewController () <QRScanDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)btnScanClick:(id)sender {
    QRScanViewController *vc = [[QRScanViewController alloc] init];
    vc.delegate = self;
    vc.hidesBottomBarWhenPushed = YES;
    [self showViewController:vc sender:nil];
}

- (void)qrScanResult:(NSString *)result viewController:(QRScanViewController *)qrScanVC
{
    [qrScanVC.navigationController popViewControllerAnimated:NO];
    ResultViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"ResultViewController"];
    vc.result = result;
    vc.hidesBottomBarWhenPushed = YES;
    [self showViewController:vc sender:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
