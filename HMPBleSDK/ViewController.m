//
//  ViewController.m
//  HMPBleSDK
//
//  Created by Lee on 2023/4/7.
//
#define KScreenWidth     [UIApplication sharedApplication].keyWindow.bounds.size.width
#define KScreenHeight    [UIApplication sharedApplication].keyWindow.bounds.size.height
#define KStatusbarHeight [[UIApplication sharedApplication] statusBarFrame].size.height
#define KNaviBarHeight   44
#define KNaviHeight      KNaviBarHeight + KStatusbarHeight

#import "ViewController.h"
#import "EGBLEManager.h"
#import "EGBleCMDVC.h"
@interface ViewController ()<UITableViewDelegate, UITableViewDataSource, EGBleManagerDelegate>
/// 列表视图
@property (nonatomic, strong) UITableView *tableView;
/// 数据源
@property (nonatomic, strong) NSArray *dataSource;
@property (nonatomic, strong) NSMutableArray *deviceArray;
@end

@implementation ViewController
- (NSMutableArray *)deviceArray{
    if (!_deviceArray) {
        _deviceArray = [NSMutableArray array];
    }
    return _deviceArray;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"蓝牙调试";
    [EGBLEManager sharedInstance].deleagte = self;
    self.dataSource = @[
        @[@"开始扫描",@"断开连接"],
//        @[@"发送连接指令",@"发送打开通知指令",@"查询信息指令（尿酸）",@"上报血糖数据",@"设置数据命令",@"查询血糖最新记录id值",@"查询尿酸最新记录id值",@"查询乳酸最新记录id值",@"查询血酮最新记录id值",@"查询最新的血糖数据",@"查询最新的尿酸数据",@"查询指定id的血糖数据",@"查询指定id的尿酸数据",@"查询指定区间的血糖数据",@"查询指定区间的尿酸数据",@"查询指定区间的血糖数据批量",@"查询指定区间的尿酸数据批量"]
        self.deviceArray
    ];
    
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    tableView.delegate = self;
    tableView.dataSource = self;
    self.tableView = tableView;
    [self.view addSubview:tableView];
    [self.tableView reloadData];
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}
- (void)didDiscoverDevice:(EGDevice *)device{
    [self.deviceArray addObject:device];
    [self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    if (indexPath.section > 0 && self.deviceArray.count > indexPath.row) {
        EGDevice *device = self.deviceArray[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@", device.sn];
        return  cell;
    }
    NSArray *child = self.dataSource[indexPath.section];
    cell.textLabel.text = [NSString stringWithFormat:@"%@", child[indexPath.row]];
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataSource.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *child = self.dataSource[section];
    return child.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    if (indexPath.section > 0) {
        EGDevice *device = self.deviceArray[indexPath.row];
        __weak __typeof(self) weakSelf = self;
        [[EGBLEManager sharedInstance]connectToDevice:device Result:^(BOOL isSuccess, NSError * _Nullable error) {
            [weakSelf.deviceArray removeAllObjects];
                DLog(@"连接状态：%d",isSuccess);
            EGBleCMDVC *vc = [[EGBleCMDVC alloc]init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
//            vc.modalPresentationStyle = UIModalPresentationFullScreen;
//            [weakSelf presentViewController:vc animated:YES completion:nil];
        }];
        return;
    }
    NSArray *child = self.dataSource[indexPath.section];
    NSString *title = child[indexPath.row];
    if ([title isEqualToString:@"开始扫描"]) {
        [[EGBLEManager sharedInstance] startScan];
    } else if ([title isEqualToString:@"断开连接"]) {
        [[EGBLEManager sharedInstance] stopConnect];
    } else if ([title isEqualToString:@"发送连接指令"]) {
        [[EGBLEManager sharedInstance] sendBlueConnectionCmd];
    } else if ([title isEqualToString:@"发送打开通知指令"]) {
        [[EGBLEManager sharedInstance] sendNotifyCmd];
    } else if ([title isEqualToString:@"查询信息指令（尿酸）"]) {
        [[EGBLEManager sharedInstance] sendInfoCmd:0x04];
    } else if ([title isEqualToString:@"上报血糖数据"]) {
        [[EGBLEManager sharedInstance] sendReportCmd];
    } else if ([title isEqualToString:@"设置数据命令"]) {
        [[EGBLEManager sharedInstance] sendSettingCmd];
    } else if ([title isEqualToString:@"查询血糖最新记录id值"]) {
        [[EGBLEManager sharedInstance] sendGluLastedIdCmd];
    } else if ([title isEqualToString:@"查询尿酸最新记录id值"]) {
        [[EGBLEManager sharedInstance] sendUricLastedIdCmd];
    } else if ([title isEqualToString:@"查询乳酸最新记录id值"]) {
        [[EGBLEManager sharedInstance] sendLacLastedIdCmd];
    } else if ([title isEqualToString:@"查询血酮酸最新记录id值"]) {
        [[EGBLEManager sharedInstance] sendKetLastedIdCmd];
    } else if ([title isEqualToString:@"查询最新的血糖数据"]) {
        [[EGBLEManager sharedInstance] sendLastedGluCmd];
    } else if ([title isEqualToString:@"查询最新的尿酸数据"]) {
        [[EGBLEManager sharedInstance] sendLastedUricCmd];
    } else if ([title isEqualToString:@"查询指定id的血糖数据"]) {
        [[EGBLEManager sharedInstance] sendIdGluCmd];
    } else if ([title isEqualToString:@"查询指定id的尿酸数据"]) {
        [[EGBLEManager sharedInstance] sendIdUricCmd];
    } else if ([title isEqualToString:@"查询指定区间的血糖数据"]) {
        [[EGBLEManager sharedInstance] sendIntervalGluCmd];
    } else if ([title isEqualToString:@"查询指定区间的尿酸数据"]) {
        [[EGBLEManager sharedInstance] sendIntervalUricCmd];
    } else if ([title isEqualToString:@"查询指定区间的血糖数据批量"]) {
        [[EGBLEManager sharedInstance] sendIntervalGluBatchCmd];
    } else if ([title isEqualToString:@"查询指定区间的尿酸数据批量"]) {
        [[EGBLEManager sharedInstance] sendIntervalUricBatchCmd];
    }else{

    }
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 10.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.0f;
}

@end
