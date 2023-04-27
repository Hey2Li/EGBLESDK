//
//  EABLEManager.m
//  HMPBleSDK
//
//  Created by Lee on 2023/4/7.
//

#ifdef DEBUG
    #define DLog( s, ... ) NSLog( @"<%@,(line=%d)> %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
    #define DLog( s, ... )
#endif

#import "EGBLEManager.h"
#import <UIKit/UIKit.h>
#import "DataOutputStream.h"
#import "DataInputStream.h"

@interface EGBLEManager()
@property (nonatomic, strong) BabyBluetooth *ble;
/// 蓝牙设备
@property (nonatomic, strong) CBPeripheral *periphearal;
/// 写特征
@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;
/// 订阅特征
@property (nonatomic, strong) CBCharacteristic *notifyCharacteristic;

/// 当前连接的设备
@property (nonatomic, strong) EGDevice *currentDevice;
/// 最近50条数据
@property (nonatomic, strong) NSMutableArray *latestData;

/// 最新的数据ID
@property (nonatomic, assign) int lastId;
@end

@implementation EGBLEManager
static EGBLEManager *_shared = nil;
const NSTimeInterval oneYearInSeconds = 365 * 24 * 60 * 60;
+ (instancetype)sharedInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.ble = [BabyBluetooth shareBabyBluetooth];
        [self babyDelegate];
        self.conntectStatus = EGDeviceDisConnected;
        self.lastId = -1;
    }
    return self;
}

- (NSMutableArray *)latestData {
    if (!_latestData) {
        _latestData = [NSMutableArray array];
    }
    return _latestData;
}

- (void)setIsAutoReconnect:(BOOL)isAutoReconnect{
    _isAutoReconnect = isAutoReconnect;
}


/// NSData转数组
/// - Parameter data: 蓝牙data
- (NSArray<NSString *> *)dataToDecimalStringArray:(NSData *)data {
    const unsigned char *bytes = [data bytes];
    NSUInteger length = [data length];
    NSMutableArray<NSString *> *decimalStrings = [NSMutableArray arrayWithCapacity:length];
    for (NSUInteger i = 0; i < length; i++) {
        unsigned char byte = bytes[i];
        NSString *decimalString = [NSString stringWithFormat:@"%d", byte];
        [decimalStrings addObject:decimalString];
    }
    if ([decimalStrings count] == 7) {
        NSArray *lastFiveElements = [decimalStrings subarrayWithRange:NSMakeRange(2, 5)];
        return lastFiveElements;
    } else {
        // 数组不是7个元素，执行适当的错误处理或返回 nil
        return @[];
    }
}

/// 设备型号转换
/// - Parameter num: num
- (NSString *)number2Mtype:(NSInteger )num {
    NSString *type = @"";
    switch (num) {
        case 1:
            type = @"M221";
            break;
        case 2:
            type = @"M222";
            break;
        case 3:
            type = @"M212";
            break;
        case 4:
            type = @"BTM230";
            break;
        case 5:
            type = @"BTM231";
            break;
        case 6:
            type = @"EN310";
            break;
        case 7:
            type = @"EN311";
            break;
        case 8:
            type = @"EN312";
            break;
        case 9:
            type = @"EN313";
            break;
        case 10:
            type = @"EN510";
            break;
        case 11:
            type = @"EN511";
            break;
        case 12:
            type = @"EN512";
            break;
        case 13:
            type = @"EN513";
            break;
        case 14:
            type = @"EN410";
            break;
        case 15:
            type = @"EN411";
            break;
        case 16:
            type = @"EN412";
            break;
        case 17:
            type = @"EN413";
            break;
        case 18:
            type = @"EN300";
            break;
        case 19:
            type = @"EN301";
            break;
        case 20:
            type = @"EN302";
            break;
        case 21:
            type = @"EN303";
            break;
        case 22:
            type = @"EN500";
            break;
        case 23:
            type = @"EN501";
            break;
        case 24:
            type = @"EN502";
            break;
        case 25:
            type = @"EN503";
            break;
        case 26:
            type = @"EN400";
            break;
        case 27:
            type = @"EN401";
            break;
        case 28:
            type = @"EN402";
            break;
        case 29:
            type = @"EN403";
            break;
        case 30:
            type = @"M211";
            break;
    }
    return type;
}
- (NSString *)translateSN:(NSArray<NSString *> *)oriSN {
    NSMutableString *sn = [NSMutableString string];
    NSInteger mType = strtol([oriSN[0] UTF8String], NULL, 10);
    [sn appendString:[self number2Mtype:mType]];
    NSString *year = [NSString stringWithFormat:@"%02ld", (long)strtol([oriSN[1] UTF8String], NULL, 10)];
    [sn appendString:year];
    NSString *month = [NSString stringWithFormat:@"%02ld", (long)strtol([oriSN[2] UTF8String], NULL, 10)];
    [sn appendString:month];
    NSString *subSn = [NSString stringWithFormat:@"%ld",  (long)strtol([oriSN[3] UTF8String], NULL, 10) + (long)strtol([oriSN[4] UTF8String], NULL, 10)];
    [sn appendString:subSn];
    return [sn copy];
}
//蓝牙网关初始化和委托方法设置
-(void)babyDelegate{
    __weak __typeof(self) weakSelf = self;
    //过滤器
    //设置查找设备的过滤器
    [self.ble setFilterOnDiscoverPeripherals:^BOOL(NSString *peripheralName, NSDictionary *advertisementData, NSNumber *RSSI) {
        return [peripheralName hasPrefix:kPreName];
    }];
    //链接设备的过滤器
    [self.ble setFilterOnConnectToPeripherals:^BOOL(NSString *peripheralName, NSDictionary *advertisementData, NSNumber *RSSI) {
        return [peripheralName hasPrefix:kPreName];
    }];
    
    //设置扫描到设备的委托
    [self.ble setBlockOnDiscoverToPeripherals:^(CBCentralManager *central, CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI) {
        if ([advertisementData.allKeys containsObject:@"kCBAdvDataManufacturerData"]) {
            EADeviceType deviceType;
            NSString *SN  = @"";
            if ([peripheral.name isEqualToString: @"Eaglenos-011"]){
                deviceType = EADeviceType_Lac;
                DLog(@"血糖乳酸仪");
            }else if ([peripheral.name isEqualToString:@"Eaglenos-012"]) {
                deviceType = EADeviceType_Uric;
                DLog(@"血糖尿酸仪");
            }else if ([peripheral.name isEqualToString:@"Eaglenos-013"]) {
                deviceType = EADeviceType_Ket;
                DLog(@"血糖血酮仪");
            }else{
                deviceType = EADeviceType_Other;
                DLog(@"其他设备");
            }
            NSData *data = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
            SN = [weakSelf translateSN:[weakSelf dataToDecimalStringArray:data]];
            EGDevice *device = [[EGDevice alloc]initWithPeripheral:peripheral adv:advertisementData sn:SN deviceType:deviceType];
            if (weakSelf.deviceDeleagte && [weakSelf.deviceDeleagte respondsToSelector:@selector(didDiscoverDevice:)]) {
                [weakSelf.deviceDeleagte didDiscoverDevice:device];
            }
        }
//
    }];

    //断开连接
    [self.ble setBlockOnDisconnect:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
        weakSelf.conntectStatus = EGDeviceDisConnected;
        if (weakSelf.deviceDeleagte && [weakSelf.deviceDeleagte respondsToSelector:@selector(didDisconnectedDevice:andError:)]) {
            [weakSelf.deviceDeleagte didDisconnectedDevice:weakSelf.currentDevice andError:error];
        }
        if (error) {
            DLog(@"failed to connect : %@, (%@)", peripheral, error.localizedDescription);
            if (weakSelf.isAutoReconnect){
                [weakSelf connectToDevice:weakSelf.currentDevice];
            }
        }
    }];
    //设置发现设备的Services的委托
    [self.ble setBlockOnDiscoverServices:^(CBPeripheral *peripheral, NSError *error) {
        for (CBService *service in peripheral.services) {
            NSLog(@"搜索到%@设备的服务:%@",peripheral.name, service.UUID.UUIDString);
        }
    }];
    //设置发现设service的Characteristics的委托
    [self.ble setBlockOnDiscoverCharacteristics:^(CBPeripheral *peripheral, CBService *service, NSError *error) {
        NSLog(@"=== %@设备的 service name:%@",peripheral.name,service.UUID);
        if ([service.UUID.UUIDString.uppercaseString containsString:@"8653000A"]) {
            for (CBCharacteristic *c in service.characteristics) {
                NSLog(@"=== charateristic name is :%@",c.UUID.UUIDString);
                if (c.properties == CBCharacteristicPropertyWrite) {
                    weakSelf.writeCharacteristic = c;
                }
                if (c.properties == CBCharacteristicPropertyNotify) {
                    weakSelf.notifyCharacteristic = c;
                }
            }
        }
    }];
    //设置读取characteristics的委托
    [self.ble setBlockOnReadValueForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
        if ([characteristics.UUID.UUIDString hasPrefix:@"8653000C"] && !weakSelf.writeCharacteristic) {
            weakSelf.writeCharacteristic = characteristics;
        } else if ([characteristics.UUID.UUIDString hasPrefix:@"8653000B"] && !characteristics.isNotifying) {
            [peripheral setNotifyValue:true forCharacteristic:characteristics];
            weakSelf.notifyCharacteristic = characteristics;
        }
        [peripheral setNotifyValue:true forCharacteristic:characteristics];
        NSLog(@"=== characteristic name:%@ value is:%@",characteristics.UUID,characteristics.value);
        [weakSelf.ble notify:weakSelf.periphearal characteristic:weakSelf.notifyCharacteristic block:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
            DLog(@"订阅收到的值：%@",characteristics.value);
            [weakSelf parseData:characteristics.value];
        }];
    }];
    // 写Characteristic成功后的block
    [self.ble setBlockOnDidWriteValueForCharacteristic:^(CBCharacteristic *characteristic, NSError *error) {
        DLog(@"写Characteristic成功:characteristic:%@ //value:%@", characteristic.UUID,characteristic.value);
    }];
   
    //设置读取Descriptor的委托
    [self.ble setBlockOnReadValueForDescriptors:^(CBPeripheral *peripheral, CBDescriptor *descriptor, NSError *error) {
        NSLog(@"%@设备的  Descriptor name:%@ value is:%@",peripheral.name, descriptor.characteristic.UUID, descriptor.value);
    }];

    
    [self.ble setBlockOnDidWriteValueForCharacteristic:^(CBCharacteristic *characteristic, NSError *error) {
        NSLog(@"setBlockOnDidWriteValueForCharacteristicAtChannel characteristic:%@ and new value:%@",characteristic.UUID, characteristic.value);
    }];
    
}
#pragma mark 开始连接
- (void)connectToDevice:(EGDevice *)device{
    if (device) {
        self.conntectStatus = EGDeviceConnecting;
        CBPeripheral *per = device.rawPeripheral;
        [self.ble cancelScan];
        self.ble.having(per).connectToPeripherals().discoverServices().discoverCharacteristics().readValueForCharacteristic().discoverDescriptorsForCharacteristic().readValueForDescriptors().begin();
        self.periphearal = per;
        __weak __typeof(self) weakSelf = self;
        //设置设备连接成功的委托
        [self.ble setBlockOnConnected:^(CBCentralManager *central, CBPeripheral *peripheral) {
            NSLog(@"设备：%@--连接成功",peripheral.name);
            weakSelf.conntectStatus = EGDeviceConnected;
            if(weakSelf.deviceDeleagte && [weakSelf.deviceDeleagte respondsToSelector:@selector(didConnectedDevice:)]) {
                [weakSelf.deviceDeleagte didConnectedDevice:device];
                weakSelf.currentDevice = device;
            }
        }];
        //连接失败
        [self.ble setBlockOnFailToConnect:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
            NSLog(@"设备：%@--连接失败",peripheral.name);
            weakSelf.conntectStatus = EGDeviceDisConnected;
            if(weakSelf.deviceDeleagte && [weakSelf.deviceDeleagte respondsToSelector:@selector(didDisconnectedDevice:andError:)]) {
                [weakSelf.deviceDeleagte didDisconnectedDevice:device andError:error];
            }
        }];
    }
}
#pragma mark 开始扫描
/// 开始扫描
- (void)startScan {
    self.ble.scanForPeripherals().begin();
}
#pragma mark 断开连接
/// 断开链接
- (void)stopConnect {
    self.ble.stop(0);
}

#pragma mark 发送指令
/// 3.1 3.2 3.5 3.8 3.9

/// 对应3.1指令
/// 发送连接指令
- (void)sendBlueConnectionCmd {
    // EB90000900010101860D0A
    DataOutputStream *stream = [[DataOutputStream alloc] init];
//    45 39 4A 49 4E 47 4A 49
    // 起始位
    short pre1 = 0xEB;
    short pre2 = 0x90;
    // 长度
    short len = 0x09;
    // 命令格式
    Byte cmd = 0x00;
    // 数据
    Byte dat = 0x01;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + dat + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 数据
    [stream writeChar:dat];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送连接指令: %@",data);
    [self sendCmd:data];
}


/// 主动上报指令
/// @param type 类型
///             0x02    血糖值
///             0x03    血酮
///             0x04    尿酸
///             0x05    HB
///             0x06    总胆固醇
///             0x07    乳酸值
- (void)sendInfoCmd:(Byte)type {
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0B;
    // 命令格式
    Byte cmd = 0x02;
    // ID信息
    Byte idInfo1 = 0x00;
    Byte idInfo2 = 0x00;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + idInfo1 + idInfo2 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 检测项命令
    [stream writeChar:type];
    // Id信息
    [stream writeChar:idInfo1];
    [stream writeChar:idInfo2];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送查询尿酸最新ID指令：%@",data);
    [self sendCmd:data];
    
}


/// 上报血糖数据
/// EB 90
/// 00 14
/// 06
/// 02
/// 00 0B
/// 07 E5 /05 /15 /15 /11 /00
/// 45 00
/// 00
/// 03 13
/// 0D 0A
///
- (void)sendReportCmd {
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x14;
    // 命令格式
    Byte cmd = 0x06;
    // 项目命令字（血糖）
    Byte type = 0x02;
    // 检测id
    Byte id1 = 0x00;
    Byte id2 = 0x01;
    // 时间戳
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:[NSDate now]];
    int32_t year = (int32_t)components.year;
    Byte year1 = year >> 8;
    Byte year2 = year & 0x00ff;
    Byte month = components.month;
    Byte day = components.day;
    Byte hour = components.hour;
    Byte min = components.minute;
    Byte second = components.second;
    // 结果 （同步更新完成：0x0001 未同步更新:0x0000）
    Byte result1 = 0x00;
    Byte result2 = 0x01;
    // 餐前餐后 （0x00 空腹 0x01 餐前 0x02 餐后）
    Byte time = 0x01;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + year1 + year2 + month + day + hour + min + second + result1 + result2 + time + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    // 时间
    [stream writeChar:year1];
    [stream writeChar:year2];
    [stream writeChar:month];
    [stream writeChar:day];
    [stream writeChar:hour];
    [stream writeChar:min];
    [stream writeChar:second];
    // 结果
    [stream writeChar:result1];
    [stream writeChar:result2];
    // 餐前餐后
    [stream writeChar:time];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}





/// 设置设备数据命令（设置硬件版本号）
/// @param type 0x50    设备地址
///             0x51    硬件版本号
///             0x52    软件版本号
///             0x60    设备时间
- (void)sendSettingCmd  {
    
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0F;
    // 命令格式
    Byte cmd = 0x07;
    // 指标命令格式
    Byte type = 0x60;
//    // 具体数据
//    Byte version1 = 0x00;
//    Byte version2 = 0x03;
    
    // 时间戳
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:[NSDate now]];
    int32_t year = (int32_t)components.year;
    Byte year1 = year >> 8;
    Byte year2 = year & 0x00ff;
    Byte month = components.month;
    Byte day = components.day;
    Byte hour = components.hour;
    Byte min = components.minute;
    Byte second = components.second;
    
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + year1 + year2 + month + day + hour + min + second + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 指标命令格式
    [stream writeChar:type];
    // 时间
    [stream writeChar:year1];
    [stream writeChar:year2];
    [stream writeChar:month];
    [stream writeChar:day];
    [stream writeChar:hour];
    [stream writeChar:min];
    [stream writeChar:second];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送设置硬件版本号指令：%@",data);
    [self sendCmd:data];
}

- (void)sendCmd:(NSData *)data {
    if (!data || !self.periphearal || !self.writeCharacteristic) {
        return;
    }
    [self.periphearal writeValue:data forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
}


#pragma mark 接收指令
- (NSArray *)convertNSDataToDecimalArray:(NSData *)data {
    NSMutableArray *array = [NSMutableArray array];
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSUInteger length = [data length];
    for (NSUInteger i = 0; i < length; i++) {
        [array addObject:@(bytes[i])];
    }
    return [NSArray arrayWithArray:array];
}
- (void)parseData:(NSData *)data {
    NSArray *result = [self convertNSDataToDecimalArray:data];
//    NSLog(@"收到指令：%@, 原始值：%@", data,result);
//    NSLog(@"收到指令：%@", data);
    if (!data || data.length < 10) {
        return;
    }
    NSData *preData = [data subdataWithRange:NSMakeRange(0, 2)];
    DataInputStream *preStream = [[DataInputStream alloc] initWithData:preData];
    uint16_t pre = preStream.readShort;
//    if (pre != 0xEB90) {
//        return;
//    }
    //type
    NSData *typeData = [data subdataWithRange:NSMakeRange(5, 1)];
    DataInputStream *typeStream = [[DataInputStream alloc] initWithData:typeData];
    EGDeviceValueType type = typeStream.readChar;
    
    NSData *cmdData = [data subdataWithRange:NSMakeRange(4, 1)];
    DataInputStream *cmdStream = [[DataInputStream alloc] initWithData:cmdData];
    Byte cmd = cmdStream.readChar;
    switch (cmd) {
        case 0x01:
            [self parseConnectCallbackInfo:data];
            break;
        case 0x03: // 设备数据导入上报
            if (data.length > 10) {
                [self parseInfoCallbackInfo:data];
            }
        case 0x06:
            // 设备检测数据上报
            NSLog(@"监听的转换值：%@", [self convertNSDataToDecimalArray:data]);
        case 0x08:
            [self parseSettingCallbackInfo:data];
        default:
            if ([result[4] intValue] == 20 && [result[0] intValue] == 235 && [result[1] intValue] == 144) {
                //判断开头
                [self.latestData addObjectsFromArray:result];
            }else if ([result[0]intValue] != 235 && [result[1]intValue] != 144) {
                [self.latestData addObjectsFromArray:result];
                NSData *typeData = [data subdataWithRange:NSMakeRange(5, 1)];
                DataInputStream *typeStream = [[DataInputStream alloc] initWithData:typeData];
                type = typeStream.readChar;
            }
            BOOL isPackpageOK = false;
            if(self.latestData.count > 12){
                if ([self.latestData[5]intValue] == 2 && (self.latestData.count - 12) % 11 == 0) {
                    isPackpageOK = true;
                }else if ([self.latestData[5] intValue] != 02 && (self.latestData.count - 12) % 10 == 0) {
                    isPackpageOK = true;
                }
            }
            if (self.latestData.count > 2 && [self.latestData[self.latestData.count - 2] intValue] == 13
                && [self.latestData.lastObject intValue] == 10 && isPackpageOK) {
                // 翻译
                [self convertDataToArray:self.latestData type:type];
//                NSLog(@"最近50条数据为：%@", self.latestData);
                [self.latestData removeAllObjects];
            }

            break;
    }
}

/// 解析为数据数组
/// - Parameters:
///   - data: 蓝牙二进制
///   - type: 数据类型
- (NSArray *)convertDataToArray:(NSArray *)data type:(EGDeviceValueType)type{
    NSMutableArray *rs = [NSMutableArray array];
    switch (type) {
            //血糖
        case EGDeviceValueType_GLU:
            if ([data[0] shortValue] == 0xEB && [data[1] shortValue] == 0x90 && [data[4] shortValue] == 0x14 && [data[5] shortValue] == 0x02) {
                int num = [data[6] intValue];
                int start = 7;
                if (num > 0) {
                    for (int i = 1; i <= num; i++) {
                        int end = start + 11;
                        NSArray *tmpArray = [data subarrayWithRange:NSMakeRange(start, 11)];
                        [rs addObject:[self parseDataWithArray:tmpArray]];
                        start = end;
                    }
                }
            }
            break;
        case  EGDeviceValueType_LAC:
            //乳酸
            if ([data[0] shortValue] == 0xEB && [data[1] shortValue] == 0x90 && [data[4] shortValue] == 0x14 && ([data[5] shortValue] == 0x03 || [data[5] shortValue] == 0x04 || [data[5] shortValue] == 0x07)) {
                int num = [data[6] intValue];
                int start = 7;
                if (num > 0) {
                    for (int i = 1; i <= num; i++) {
                        int end = start + 10;
                        NSArray *tmpArray = [data subarrayWithRange:NSMakeRange(start, 11)];
                        [rs addObject:[self parseDataWithArray:tmpArray]];
                        start = end;
                    }
                }
            }
        default:
            break;
    }
    return rs;
}
- (NSString *)parseDataWithArray:(NSArray *)tmpBean{
    int Id = [tmpBean[0] shortValue] * 256 + [tmpBean[1] shortValue];
    int year = [tmpBean[2]shortValue] * 256 + [tmpBean[3] shortValue];
    int month = [tmpBean[4] shortValue];
    int day = [tmpBean[5] shortValue];
    int hour = [tmpBean[6] shortValue];
    int minute = [tmpBean[7] shortValue];
    NSString *time = [NSString stringWithFormat:@"%04d-%02d-%02d %02d:%02d", year, month, day, hour, minute];
    int result = [tmpBean[8] shortValue] * 256 + [tmpBean[9] shortValue];
    int testMethodValue = [tmpBean[10] shortValue];

    //拼接字符串并打印出来
    NSString *resultStr = [NSString stringWithFormat:@"id:%d, time:%@, result:%.2f, testMethodValue:%d", Id, time, (float)result/10, testMethodValue];
    NSLog(@"%@", resultStr);
    return  resultStr;
}
/// 对应3.2指令
/// 查询连接返回命令
/// @param oriData 数据
-(void)parseConnectCallbackInfo:(NSData *)oriData {
    /// 起始位
    // 0xEB90
    NSData *preData = [oriData subdataWithRange:NSMakeRange(0, 2)];
    DataInputStream *preStream = [[DataInputStream alloc] initWithData:preData];
    uint16_t pre = preStream.readShort;
    // 长度
    NSData *lenData = [oriData subdataWithRange:NSMakeRange(2, 2)];
    DataInputStream *lenStream = [[DataInputStream alloc] initWithData:lenData];
    uint16_t len = lenStream.readShort;
    // 命令格式 0x01
    NSData *cmdData = [oriData subdataWithRange:NSMakeRange(4, 1)];
    DataInputStream *cmdStream = [[DataInputStream alloc] initWithData:cmdData];
    Byte cmd = cmdStream.readChar;
    // 设备类型
    NSData *deviceTypeData = [oriData subdataWithRange:NSMakeRange(5, 1)];
    DataInputStream *deviceTypeStream = [[DataInputStream alloc] initWithData:deviceTypeData];
    Byte deviceType = deviceTypeStream.readChar;
    NSString *deviceTypeName = @"";
    // 设备类型名称
    switch (deviceType) {
        case 0x01: deviceTypeName = @"血糖血酮"; break;
        case 0x02: deviceTypeName = @"血糖乳酸"; break;
        case 0x03: deviceTypeName = @"血糖尿酸"; break;
        case 0x04: deviceTypeName = @"血酮-英文版"; break;
        case 0x05: deviceTypeName = @"乳酸-英文版"; break;
        case 0x06: deviceTypeName = @"尿酸-英文版"; break;
        case 0x07: deviceTypeName = @"尿酸-英文版"; break;
        default:
            break;
    }
    // 设备地址长度
    NSData *deviceMacLengthData = [oriData subdataWithRange:NSMakeRange(6, 1)];
    DataInputStream *deviceMacLengthStream = [[DataInputStream alloc] initWithData:deviceMacLengthData];
    Byte deviceMacLength = deviceMacLengthStream.readChar;
    // 设备地址
    NSData *deviceMacData = [oriData subdataWithRange:NSMakeRange(7, deviceMacLength)];
    NSString *mac = [[NSString alloc] initWithData:deviceMacData encoding:NSUTF8StringEncoding];
    // 软件版本号
    NSData *softVersionData = [oriData subdataWithRange:NSMakeRange(oriData.length - 9, 2)];
    DataInputStream *softVersionStream = [[DataInputStream alloc] initWithData:softVersionData];
    uint16_t softVersion = softVersionStream.readShort;
    // 硬件版本号
    NSData *hardVersionData = [oriData subdataWithRange:NSMakeRange(oriData.length - 7, 2)];
    DataInputStream *hardVersionStream = [[DataInputStream alloc] initWithData:hardVersionData];
    uint16_t hardVersion = hardVersionStream.readShort;
    // ack
    NSData *ackData = [oriData subdataWithRange:NSMakeRange(oriData.length - 5, 1)];
    DataInputStream *ackStream = [[DataInputStream alloc] initWithData:ackData];
    Byte ack = ackStream.readChar;
    // 校验位
    NSData *xorData = [oriData subdataWithRange:NSMakeRange(oriData.length - 4, 2)];
    DataInputStream *xorStream = [[DataInputStream alloc] initWithData:xorData];
    uint16_t xor = xorStream.readShort;
    // 结束位
    NSData *endData = [oriData subdataWithRange:NSMakeRange(oriData.length - 2, 2)];
    DataInputStream *endStream = [[DataInputStream alloc] initWithData:endData];
    uint16_t end = endStream.readShort;
    
    NSLog(@"收到设备上报指令：\n起始位: %d \n长度:%d \n命令格式:%d \n设备类型:%@ \n设备地址长度:%d \n设备地址:%@ \n软件版本号:%d \n硬件版本号:%d \nack:%d \n校验位:%d \n结束位:%d",pre, len, cmd, deviceTypeName, deviceMacLength, mac, softVersion, hardVersion, ack, xor, end);
    
    UIAlertController *alert  = [UIAlertController alertControllerWithTitle:@"提示" message:[NSString stringWithFormat:@"收到设备上报指令：\n起始位: %d \n长度:%d \n命令格式:%d \n设备类型:%@ \n设备地址长度:%d \n设备地址:%@ \n软件版本号:%d \n硬件版本号:%d \nack:%d \n校验位:%d \n结束位:%d",pre, len, cmd, deviceTypeName, deviceMacLength, mac, softVersion, hardVersion, ack, xor, end] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleCancel handler:nil]];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}


/// 查询信息返回命令(只实现尿酸)
/// @param data 数据
-(void)parseInfoCallbackInfo:(NSData *)data {
    /// 起始位
    // 0xEB90
    NSData *preData = [data subdataWithRange:NSMakeRange(0, 2)];
    DataInputStream *preStream = [[DataInputStream alloc] initWithData:preData];
    uint16_t pre = preStream.readShort;
    // 长度
    NSData *lenData = [data subdataWithRange:NSMakeRange(2, 2)];
    DataInputStream *lenStream = [[DataInputStream alloc] initWithData:lenData];
    uint16_t len = lenStream.readShort;
    // 命令格式 0x03
    NSData *cmdData = [data subdataWithRange:NSMakeRange(4, 1)];
    DataInputStream *cmdStream = [[DataInputStream alloc] initWithData:cmdData];
    Byte cmd = cmdStream.readChar;
    // 数据命令格式
    NSData *dataCmdData = [data subdataWithRange:NSMakeRange(5, 1)];
    DataInputStream *dataCmdStream = [[DataInputStream alloc] initWithData:dataCmdData];
    Byte dataCmd = dataCmdStream.readChar;
    // 具体的数据
    NSString *content = @"";
    NSString *cmdType = @"尿酸";
    switch (dataCmd) {
        case 0x50:{
            // 设备地址
            NSData *macData = [data subdataWithRange:NSMakeRange(6, 8)];
            NSString *mac = [[NSString alloc] initWithData:macData encoding:NSUTF8StringEncoding];
        }break;
        case 0x51:{
            // 硬件版本号
            
        }break;
        case 0x52:{
            // 软件版本号
        }break;
        case 0x02: {
            // 血糖值
            cmdType = @"血糖";
            if (len == 0x16) {
                // 查询血糖指定记录id值 eb 90 00 16 03 02 (00 03 00 01 07 e6 07 1d 12 3a 00 3d 00) 00 03 34 0d 0a
                content = [content stringByAppendingFormat:@"查询血糖指定记录id：%@", [self parseId:[data  subdataWithRange:NSMakeRange(6, 13)]]];
            } else if (len == 0x0d) {
                content = @"查询血糖最新记录:";
                // 指标个数
                NSData *countData = [data subdataWithRange:NSMakeRange(6, 2)];
                DataInputStream *countStream = [[DataInputStream alloc] initWithData:countData];
                uint16_t count = countStream.readShort;
                content = [content stringByAppendingFormat:@"\n指标个数:%d",count];
                // 最新id信息
                NSData *lastIdData = [data subdataWithRange:NSMakeRange(8, 2)];
                DataInputStream *lastIdStream = [[DataInputStream alloc] initWithData:lastIdData];
                uint16_t lastId = lastIdStream.readShort;
                content = [content stringByAppendingFormat:@"\n最新id信息:%d",lastId];
                
                //查询最近50条数据
                int total = 0;
                if (lastId < 50) {
                    total = lastId;
                }
                if (lastId == 0) {
                    NSLog(@"无数据");
                }
                [self.latestData removeAllObjects];
                [self queryLasted50Value:EGDeviceValueType_GLU lastId:lastId];
            }
        }break;
        case 0x03: {
            // 血酮
            cmdType = @"血酮";
        }break;
        case 0x04: {
            // 尿酸 eb 90 00 15 03 04 00 05 00 01 07 e6 07 1d 0a 27 0b 8f 00 03 79 0d 0a
            cmdType = @"尿酸";
            if (len == 0x15) {
                // 查询尿酸指定记录id值
                content = [content stringByAppendingFormat:@"查询尿酸指定记录id：%@", [self parseUricId:[data subdataWithRange:NSMakeRange(6, 12)]]];
            } else if (len == 0x0d){
                content = @"查询尿酸最新记录:";
                // 指标个数
                NSData *countData = [data subdataWithRange:NSMakeRange(6, 2)];
                DataInputStream *countStream = [[DataInputStream alloc] initWithData:countData];
                uint16_t count = countStream.readShort;
                content = [content stringByAppendingFormat:@"\n指标个数:%d",count];
                // 最新id信息
                NSData *lastIdData = [data subdataWithRange:NSMakeRange(8, 2)];
                DataInputStream *lastIdStream = [[DataInputStream alloc] initWithData:lastIdData];
                uint16_t lastId = lastIdStream.readShort;
                content = [content stringByAppendingFormat:@"\n最新id信息:%d",lastId];
            }
        }
            break;
        case EGDeviceValueType_LAC:{
            cmdType = @"乳酸";
            if (len == 0x15) {
                // 查询乳酸指定记录id值
                content = [content stringByAppendingFormat:@"查询乳酸指定记录id：%@", [self parseUricId:[data subdataWithRange:NSMakeRange(6, 12)]]];
            } else if (len == 0x0d){
                content = @"查询尿酸最新记录:";
                // 指标个数
                NSData *countData = [data subdataWithRange:NSMakeRange(6, 2)];
                DataInputStream *countStream = [[DataInputStream alloc] initWithData:countData];
                uint16_t count = countStream.readShort;
                content = [content stringByAppendingFormat:@"\n指标个数:%d",count];
                // 最新id信息
                NSData *lastIdData = [data subdataWithRange:NSMakeRange(8, 2)];
                DataInputStream *lastIdStream = [[DataInputStream alloc] initWithData:lastIdData];
                uint16_t lastId = lastIdStream.readShort;
                content = [content stringByAppendingFormat:@"\n最新id信息:%d",lastId];
                
                //查询最近50条数据
                int total = 0;
                if (lastId < 50) {
                    total = lastId;
                }
                if (lastId == 0) {
                    NSLog(@"无数据");
                }
                [self.latestData removeAllObjects];
                [self queryLasted50Value:EGDeviceValueType_LAC lastId:lastId];
            }
        }
        default:
            break;
    }
    // ack
    NSData *ackData = [data subdataWithRange:NSMakeRange(data.length - 5, 1)];
    DataInputStream *ackStream = [[DataInputStream alloc] initWithData:ackData];
    Byte ack = ackStream.readChar;
    // 校验位
    NSData *xorData = [data subdataWithRange:NSMakeRange(data.length - 4, 2)];
    DataInputStream *xorStream = [[DataInputStream alloc] initWithData:xorData];
    uint16_t xor = xorStream.readShort;
    // 结束位
    NSData *endData = [data subdataWithRange:NSMakeRange(data.length - 2, 2)];
    DataInputStream *endStream = [[DataInputStream alloc] initWithData:endData];
    uint16_t end = endStream.readShort;
    
    NSLog(@"收到%@指令：\n起始位: %d \n长度:%d \n命令格式:%d \n数据命令格式:%d \n具体数据:%@ \nack:%d \n校验位:%d \n结束位:%d",cmdType,pre, len, cmd, dataCmd, content, ack, xor, end);
}
- (void)queryLasted50Value:(EGDeviceValueType)valueType lastId:(int)lastId {
    
    int firstId = 1;
    if (lastId > 50) {
        firstId = lastId - 49;
    }
//    int id1 = firstId >> 8; // 取高位
//    int id2 = firstId & 0xff; // 取低位
//    int id3 = lastId >> 8; // 取高位
//    int id4 = lastId & 0xff; // 取低位
    //sendCmd
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0A;
    // 命令格式
    Byte cmd = 0x13;
    // 项目命令字（血糖）
    Byte type = valueType;
    // 检测id 0x0000表示最新
    Byte id1 = 0x00;
    Byte id2 = 0x01;

    //
    Byte id3 = 0x00;
    Byte id4 = 0x1A;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + id3 + id4 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];//eb900a1304
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    [stream writeChar:id3];
    [stream writeChar:id4];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"获取最近50条数据：%@",data);
    [self sendCmd:data];
}
///获取血糖最新的数据记录的id值
///app---dev
///EB 90 00 0B 02 02 00 00 01 01 8B 0D 0A
///dev---app
///EB 90 00 0B 03 02 00 0A 00 0A 00 01 9F 0D 0A
///eb 90 00 0d 03 02 00 03 00 03 00 01 93 0d 0a
///eb 90 00 0d 03 02 01 8d 01 90 00 02 ac 0d 0a
- (void)sendGluLastedIdCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0B;
    // 命令格式
    Byte cmd = 0x02;
    // 项目命令字（血糖）
    Byte type = 0x02;
    // 检测id
    Byte id1 = 0x00;
    Byte id2 = 0x00;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
//    EB90000B0202000001018b0D0A
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}

///获取尿酸最新的数据记录的id值
//////app---dev
///EB 90 00 0B 02 04 00 00 01 01 8B 0D 0A
///dev---app
///EB 90 00 0B 03 04 00 0A 00 0A 00 01 9F 0D 0A
///eb 90 00 0d 03 04 00 05 00 05 00 01 99 0d 0a
- (void)sendUricLastedIdCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0B;
    // 命令格式
    Byte cmd = 0x02;
    // 项目命令字（尿酸）
    Byte type = 0x04;
    // 检测id
    Byte id1 = 0x00;
    Byte id2 = 0x00;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}

///获取乳酸最新的数据记录的id值
//////app---dev
///EB 90 00 0B 02 07 00 00 01 01 8B 0D 0A
///dev---app
///eb 90 00 0d 03 07 01 93 01 93 00 02 ba 0d 0a
- (void)sendLacLastedIdCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0B;
    // 命令格式
    Byte cmd = 0x02;
    // 项目命令字（乳酸）
    Byte type = 0x07;
    // 检测id
    Byte id1 = 0x00;
    Byte id2 = 0x00;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}
///获取血酮最新的数据记录的id值
//////app---dev
///EB 90 00 0B 02 03 00 00 01 01 8B 0D 0A
///dev---app
///EB 90 00 0B 03 03 00 0A 00 0A 00 01 9F 0D 0A
- (void)sendKetLastedIdCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0B;
    // 命令格式
    Byte cmd = 0x02;
    // 项目命令字（血酮）
    Byte type = 0x03;
    // 检测id
    Byte id1 = 0x00;
    Byte id2 = 0x00;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}
///查询最新的血糖值
- (void)sendLastedGluCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x09;
    // 命令格式
    Byte cmd = 0x02;
    // 项目命令字（血糖）
    Byte type = 0x02;
    // 检测id 0x0000表示最新
    Byte id1 = 0x00;
    Byte id2 = 0x00;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + ack;
    // 结束
    short end = 0x0D0A;

    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];

    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}

///查询最新的尿酸值
- (void)sendLastedUricCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x09;
    // 命令格式
    Byte cmd = 0x02;
    // 项目命令字（血糖）
    Byte type = 0x04;
    // 检测id 0x0000表示最新
    Byte id1 = 0x00;
    Byte id2 = 0x00;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + ack;
    // 结束
    short end = 0x0D0A;

    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];

    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}

///查询指定id的血糖数据
///app---dev
///EB 90 00 09 02 02 00 01 01 01 8A 0D 0A
///dev---app
///0xEB 90 00 14 03 02 00 01 00 01 07 E5 02 04 03 05 00 41 00 00 02 D0 0D 0A

///0xeb  90 00 15 03 04 00 05 00 01 07 e6 07 1d 0a 27 0b 8f 00 03 79 0d 0a
///EB 90 00 0x 04 02 00 01 00 04 01 01 8b 0d 0a
- (void)sendIdGluCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x09;
    // 命令格式
    Byte cmd = 0x02;
    // 项目命令字（血糖）
    Byte type = 0x02;
    // 检测id 0x0000表示最新
    Byte id1 = 0x00;
    Byte id2 = 0x01;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}

///查询指定Id的尿酸数据
- (void)sendIdUricCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x09;
    // 命令格式
    Byte cmd = 0x02;
    // 项目命令字（尿酸）
    Byte type = 0x04;
    // 检测id 0x0000表示最新
    Byte id1 = 0x00;
    Byte id2 = 0x01;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}

///查询指定区间的血糖数据 多次返回
///app---dev
///EB 90 00 09 02 02 00 01 01 01 8A 0D 0A
///dev---app
///0xEB 90 00 14 03 02 00 01 00 01 07 E5 02 04 03 05 00 41 00 00 02 D0 0D 0A
- (void)sendIntervalGluCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0A;
    // 命令格式
    Byte cmd = 0x04;
    // 项目命令字（血糖）
    Byte type = 0x04;
    // 检测id 0x0000表示最新
    Byte id1 = 0x00;
    Byte id2 = 0x01;
    
    //
    Byte id3 = 0x00;
    Byte id4 = 0x03;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + id3 + id4 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    [stream writeChar:id3];
    [stream writeChar:id4];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}
///查询指定区间的尿酸数据
- (void)sendIntervalUricCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0A;
    // 命令格式
    Byte cmd = 0x04;
    // 项目命令字（尿酸）
    Byte type = 0x04;
    // 检测id 开始id
    Byte id1 = 0x00;
    Byte id2 = 0x01;
    // 检测id 结束id
    Byte id3 = 0x00;
    Byte id4 = 0x03;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + id3 + id4 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    [stream writeChar:id3];
    [stream writeChar:id4];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}

///查询指定区间的血糖数据批量 一次返回
///app---dev
///EB 90 00 09 02 02 00 01 01 01 8A 0D 0A
///dev---app
///0xEB 90 00 14 03 02 00 01 00 01 07 E5 02 04 03 05 00 41 00 00 02 D0 0D 0A
- (void)sendIntervalGluBatchCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0A;
    // 命令格式
    Byte cmd = 0x13;
    // 项目命令字（血糖）
    Byte type = 0x04;
    // 检测id 0x0000表示最新
    Byte id1 = 0x00;
    Byte id2 = 0x01;
    
    //
    Byte id3 = 0x00;
    Byte id4 = 0x03;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + id3 + id4 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];//eb900a1304
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    [stream writeChar:id3];
    [stream writeChar:id4];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}

///查询指定区间的尿酸数据批量
- (void)sendIntervalUricBatchCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0A;
    // 命令格式
    Byte cmd = 0x13;
    // 项目命令字（尿酸）
    Byte type = 0x04;
    // 检测id 开始id
    Byte id1 = 0x00;
    Byte id2 = 0x01;
    // 检测id 结束id
    Byte id3 = 0x00;
    Byte id4 = 0x03;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + id3 + id4 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    [stream writeChar:id3];
    [stream writeChar:id4];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}
///打开通知命令
- (void)sendNotifyCmd{
    DataOutputStream *stream = [[DataOutputStream alloc] init];
    // 起始位
    Byte pre1 = 0xEB;
    Byte pre2 = 0x90;
    // 长度
    short len = 0x0A;
    // 命令格式
    Byte cmd = 0x04;
    // 项目命令字（尿酸）
    Byte type = 0x04;
    // 检测id 开始id
    Byte id1 = 0x00;
    Byte id2 = 0x01;
    // 检测id 结束id
    Byte id3 = 0x00;
    Byte id4 = 0x03;
    // ack
    Byte ack = 0x01;
    // 校验码
    short xor = pre1 + pre2 + len + cmd + type + id1 + id2 + id3 + id4 + ack;
    // 结束
    short end = 0x0D0A;
    
    // 起始位
    [stream writeChar:pre1];
    [stream writeChar:pre2];
    // 长度
    [stream writeShort:len];
    // 命令格式
    [stream writeChar:cmd];
    // 项目命令字（血糖）
    [stream writeChar:type];
    // 检测id
    [stream writeChar:id1];
    [stream writeChar:id2];
    [stream writeChar:id3];
    [stream writeChar:id4];
    // ack
    [stream writeChar:ack];
    // 校验码
    [stream writeShort:xor];
    // 结束
    [stream writeShort:end];
    
    NSData *data = [stream toByteArray];
    NSLog(@"发送数据上报指令：%@",data);
    [self sendCmd:data];
}
#pragma  mark -解析获取指定id血糖值
/// 解析获取指定id血糖值
/// @param data 00 03 00 01 07 e6 07 1d 12 3a 00 3d 00 00
/// 尿酸                  00 05 00 01 07 e6 07 1d 0a 27 0b 8f 00
- (NSString *)parseId:(NSData *)data {
    NSMutableString *content = [@"" mutableCopy] ;
    // 指标个数
    NSData *countData = [data subdataWithRange:NSMakeRange(0, 2)];
    DataInputStream *countStream = [[DataInputStream alloc] initWithData:countData];
    uint16_t count = countStream.readShort;
    [content appendFormat:@"\n指标个数:%d",count];
    // id信息
    NSData *lastIdData = [data subdataWithRange:NSMakeRange(2, 2)];
    DataInputStream *lastIdStream = [[DataInputStream alloc] initWithData:lastIdData];
    uint16_t lastId = lastIdStream.readShort;
    [content appendFormat:@"\nid信息:%d",lastId];
    // 时间信息
    NSData *yearData = [data subdataWithRange:NSMakeRange(4, 2)];
    DataInputStream *yearStream = [[DataInputStream alloc] initWithData:yearData];
    uint16_t year = yearStream.readShort;
    NSData *monthData = [data subdataWithRange:NSMakeRange(6, 1)];
    DataInputStream *monthStream = [[DataInputStream alloc] initWithData:monthData];
    Byte month = monthStream.readChar;
    NSData *dayData = [data subdataWithRange:NSMakeRange(7, 1)];
    DataInputStream *dayStream = [[DataInputStream alloc] initWithData:dayData];
    Byte day = dayStream.readChar;
    NSData *hourData = [data subdataWithRange:NSMakeRange(8, 1)];
    DataInputStream *hourStream = [[DataInputStream alloc] initWithData:hourData];
    Byte hour = hourStream.readChar;
    NSData *minData = [data subdataWithRange:NSMakeRange(9, 1)];
    DataInputStream *minStream = [[DataInputStream alloc] initWithData:minData];
    Byte min = minStream.readChar;
    [content appendFormat:@"\n时间信息:%d年%d月%d日 %d时%d分",year, month, day, hour, min];
    // 结果
    NSData *resultData = [data subdataWithRange:NSMakeRange(10, 2)];
    DataInputStream *resultStream = [[DataInputStream alloc] initWithData:resultData];
    uint16_t result = resultStream.readShort;
    [content appendFormat:@"\n结果：(做除以10) %.1f",(float)result / 10];
    // 餐前餐后
    NSData *timeData = [data subdataWithRange:NSMakeRange(12, 1)];
    DataInputStream *timeStream = [[DataInputStream alloc] initWithData:timeData];
    Byte time = timeStream.readChar;
    switch (time) {
        case 0x00:
            [content appendFormat:@"\n餐前餐后: %@",@"空腹"];
            break;
        case 0x01:
            [content appendFormat:@"\n餐前餐后: %@",@"餐前"];
            break;
        case 0x02:
            [content appendFormat:@"\n餐前餐后: %@",@"餐后"];
            break;
        case 0x03:
            [content appendFormat:@"\n餐前餐后: %@",@"QC"];
            break;
        default:
            break;
    }
    return content;
}
#pragma mark -解析获取指定id尿酸值
/// 解析获取指定id尿酸值
/// @param data   00 05 00 01 07 e6 07 1d 0a 27 0b 8f 00
- (NSString *)parseUricId:(NSData *)data {
    NSMutableString *content = [@"" mutableCopy] ;
    // 指标个数
    NSData *countData = [data subdataWithRange:NSMakeRange(0, 2)];
    DataInputStream *countStream = [[DataInputStream alloc] initWithData:countData];
    uint16_t count = countStream.readShort;
    [content appendFormat:@"\n指标个数:%d",count];
    // id信息
    NSData *lastIdData = [data subdataWithRange:NSMakeRange(2, 2)];
    DataInputStream *lastIdStream = [[DataInputStream alloc] initWithData:lastIdData];
    uint16_t lastId = lastIdStream.readShort;
    [content appendFormat:@"\nid信息:%d",lastId];
    // 时间信息
    NSData *yearData = [data subdataWithRange:NSMakeRange(4, 2)];
    DataInputStream *yearStream = [[DataInputStream alloc] initWithData:yearData];
    uint16_t year = yearStream.readShort;
    NSData *monthData = [data subdataWithRange:NSMakeRange(6, 1)];
    DataInputStream *monthStream = [[DataInputStream alloc] initWithData:monthData];
    Byte month = monthStream.readChar;
    NSData *dayData = [data subdataWithRange:NSMakeRange(7, 1)];
    DataInputStream *dayStream = [[DataInputStream alloc] initWithData:dayData];
    Byte day = dayStream.readChar;
    NSData *hourData = [data subdataWithRange:NSMakeRange(8, 1)];
    DataInputStream *hourStream = [[DataInputStream alloc] initWithData:hourData];
    Byte hour = hourStream.readChar;
    NSData *minData = [data subdataWithRange:NSMakeRange(9, 1)];
    DataInputStream *minStream = [[DataInputStream alloc] initWithData:minData];
    Byte min = minStream.readChar;
    [content appendFormat:@"\n时间信息:%d年%d月%d日 %d时%d分",year, month, day, hour, min];
    // 结果
    NSData *resultData = [data subdataWithRange:NSMakeRange(10, 2)];
    DataInputStream *resultStream = [[DataInputStream alloc] initWithData:resultData];
    uint16_t result = resultStream.readShort;
    [content appendFormat:@"\n结果：(做除以10) %.0f",(float)result / 10];

    return content;
}

- (void)parseSettingCallbackInfo:(NSData *)data {
    /// 起始位
    // 0xEB90
    NSData *preData = [data subdataWithRange:NSMakeRange(0, 2)];
    DataInputStream *preStream = [[DataInputStream alloc] initWithData:preData];
    uint16_t pre = preStream.readShort;
    // 长度
    NSData *lenData = [data subdataWithRange:NSMakeRange(2, 2)];
    DataInputStream *lenStream = [[DataInputStream alloc] initWithData:lenData];
    uint16_t len = lenStream.readShort;
    // 命令格式 0x08
    NSData *cmdData = [data subdataWithRange:NSMakeRange(4, 1)];
    DataInputStream *cmdStream = [[DataInputStream alloc] initWithData:cmdData];
    Byte cmd = cmdStream.readChar;
    // 指标命令格式
    NSData *dataCmdData = [data subdataWithRange:NSMakeRange(5, 1)];
    DataInputStream *dataCmdStream = [[DataInputStream alloc] initWithData:dataCmdData];
    Byte dataCmd = dataCmdStream.readChar;
    // 数据格式
    NSData *dataCmdResultData = [data subdataWithRange:NSMakeRange(6, 1)];
    DataInputStream *dataCmdResultStream = [[DataInputStream alloc] initWithData:dataCmdResultData];
    Byte dataCmdResult = dataCmdResultStream.readChar;
    // ack
    NSData *ackData = [data subdataWithRange:NSMakeRange(data.length - 5, 1)];
    DataInputStream *ackStream = [[DataInputStream alloc] initWithData:ackData];
    Byte ack = ackStream.readChar;
    // 校验位
    NSData *xorData = [data subdataWithRange:NSMakeRange(data.length - 4, 2)];
    DataInputStream *xorStream = [[DataInputStream alloc] initWithData:xorData];
    uint16_t xor = xorStream.readShort;
    // 结束位
    NSData *endData = [data subdataWithRange:NSMakeRange(data.length - 2, 2)];
    DataInputStream *endStream = [[DataInputStream alloc] initWithData:endData];
    uint16_t end = endStream.readShort;
    
    NSLog(@"收到设备设置指令：\n起始位: %d \n长度:%d \n命令格式:%d \n指标命令格式:%d \n数据格式:%d  \nack:%d \n校验位:%d \n结束位:%d",pre, len, cmd, dataCmd, dataCmdResult,ack, xor, end);
    
//    UIAlertController *alert  = [UIAlertController alertControllerWithTitle:@"提示" message:[NSString stringWithFormat:@"修改设备时间%@", dataCmdResult == 0x01 ? @"成功" : @"失败"] preferredStyle:UIAlertControllerStyleAlert];
//    UIAlertController *alert  = [UIAlertController alertControllerWithTitle:@"提示" message:[NSString stringWithFormat:@"收到设备设置指令：\n起始位: %d \n长度:%d \n命令格式:%d \n指标命令格式:%d \n数据格式:%d  \nack:%d \n校验位:%d \n结束位:%d",pre, len, cmd, dataCmd, dataCmdResult,ack, xor, end] preferredStyle:UIAlertControllerStyleAlert];
//    [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleCancel handler:nil]];
//    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

@end
