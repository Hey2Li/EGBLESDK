//
//  EADevice.m
//  HMPBleSDK
//
//  Created by Lee on 2023/4/11.
//

#import "EGDevice.h"

@implementation EGDevice
- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral adv:(NSDictionary *)advDic sn:(NSString *)sn deviceType:(EADeviceType)deviceType{
    self = [super init];
    if (self) {
        self.sn = sn;
        self.deviceType = deviceType;
        self.advName = [advDic objectForKey:@"kCBAdvDataLocalName"];
        if (![self.advName isKindOfClass:[NSNull class]] &&
            ![self.advName isEqualToString:@""] &&
            self.advName != nil &&
            ![peripheral.name isEqualToString:self.advName]) {
            [peripheral setValue:self.advName forKey:@"name"];
        }
        self.rawPeripheral = peripheral;
        if (![peripheral.name hasPrefix:@"Eaglenos"]) {
            return nil;
        }else{
            DLog(@"搜索到了设备:%@, 类型:%lu, SN:%@",peripheral.name, (unsigned long)deviceType, sn);
        }
    }
    return self;
}
@end
