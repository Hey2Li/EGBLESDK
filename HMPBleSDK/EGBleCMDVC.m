//
//  EGBleCMDVC.m
//  HMPBleSDK
//
//  Created by Lee on 2023/4/20.
//

#import "EGBleCMDVC.h"
#import <EGTestStripBleSDK/EGTestStripBleSDK.h>

@interface EGBleCMDVC ()<UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/// 数据源
@property (nonatomic, strong) NSArray *dataSource;
@end

@implementation EGBleCMDVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.dataSource = @[@"发送连接指令",@"发送打开通知指令",@"查询信息指令（尿酸）",@"上报血糖数据",@"设置数据命令",@"查询血糖最新记录id值",@"查询尿酸最新记录id值",@"查询乳酸最新记录id值",@"查询血酮最新记录id值",@"查询最新的血糖数据",@"查询最新的尿酸数据",@"查询指定id的血糖数据",@"查询指定id的尿酸数据",@"查询指定区间的血糖数据",@"查询指定区间的尿酸数据",@"查询指定区间的血糖数据批量",@"查询指定区间的尿酸数据批量"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    [self.tableView reloadData];
    // Do any additional setup after loading the view from its nib.
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSString *child = self.dataSource[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@", child];
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return  self.dataSource.count;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
  
    NSString *title = self.dataSource[indexPath.row];
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
