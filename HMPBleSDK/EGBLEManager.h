//
//  EABLEManager.h
//  HMPBleSDK
//
//  Created by Lee on 2023/4/7.
//

#import <Foundation/Foundation.h>
#import <BabyBluetooth/BabyBluetooth.h>
#import "EGDevice.h"
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, EGDeviceConnectStatus) {
    EGDeviceDisConnected = 0,
    EGDeviceConnecting,
    EGDeviceConnected,
};
typedef NS_ENUM(NSInteger, EGDeviceValueType) {
    EGDeviceValueType_GLU = 0x02,//血糖
    EGDeviceValueType_KET = 0x03,//血酮
    EGDeviceValueType_URI = 0x04,//尿酸
    EGDeviceValueType_HB = 0x05,//尿酸
    EGDeviceValueType_TC = 0x06,//总胆固醇
    EGDeviceValueType_LAC = 0x07,//乳酸
};
#define kPreName @"Eaglenos"
@protocol EGBLEDeviceDelegate <NSObject>
/// 发现设备
- (void)didDiscoverDevice:(EGDevice *)device;
///连接成功
/// - Parameter device: device
- (void)didConnectedDevice:(EGDevice *)device;
///连接断开
- (void)didDisconnectedDevice:(EGDevice *)device andError:(NSError *)error;
@end
typedef void (^connectedReslut)(BOOL isSuccess, NSError * _Nullable error);
@interface EGBLEManager : NSObject

@property (nonatomic, assign) EGDeviceConnectStatus conntectStatus;
@property (nonatomic, assign) EGDeviceValueType valueType;
@property (nonatomic, assign) id <EGBLEDeviceDelegate> deviceDeleagte;
/// 是否自动重连
@property (nonatomic, assign) BOOL isAutoReconnect;
/// 单例
+ (instancetype)sharedInstance;


/// 连接设备
/// - Parameter device: device
- (void)connectToDevice:(EGDevice *)device;


/// 开始扫描
- (void)startScan;

/// 断开连接
- (void)stopConnect;


/// 发送连接指令
- (void)sendBlueConnectionCmd;

/// 主动上报指令
/// @param type 类型
///             0x02    血糖值
///             0x03    血酮
///             0x04    尿酸
///             0x05    HB
///             0x06    总胆固醇
///             0x07    乳酸值
- (void)sendInfoCmd:(Byte)type;

/// 上报血糖数据
- (void)sendReportCmd;

/// 设置设备数据命令（设置硬件版本号）
- (void)sendSettingCmd;

///获取血糖最新的数据记录的id值
- (void)sendGluLastedIdCmd;

///获取尿酸最新的数据记录的id值
- (void)sendUricLastedIdCmd;

///获取乳酸最新的数据记录的id值
- (void)sendLacLastedIdCmd;

///获取血酮最新的数据记录的id值
- (void)sendKetLastedIdCmd;

///查询最新的血糖值
- (void)sendLastedGluCmd;

///查询最新的尿酸值
- (void)sendLastedUricCmd;

///查询指定id的血糖数据
- (void)sendIdGluCmd;

///查询指定id的尿酸数据
- (void)sendIdUricCmd;

///查询指定区间的血糖数据
- (void)sendIntervalGluCmd;

///查询指定区间的尿酸数据
- (void)sendIntervalUricCmd;

///查询指定区间的血糖数据批量
- (void)sendIntervalGluBatchCmd;

///查询指定区间的尿酸数据批量
- (void)sendIntervalUricBatchCmd;

///打开通知命令
- (void)sendNotifyCmd;
@end

NS_ASSUME_NONNULL_END
