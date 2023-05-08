//
//  EADevice.h
//  HMPBleSDK
//
//  Created by Eaglenos on 2023/4/11.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#ifdef DEBUG
    #define DLog( s, ... ) NSLog( @"<%@,(line=%d)> %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
    #define DLog( s, ... )
#endif
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    EADeviceType_Lac = 0,
    EADeviceType_Uric,
    EADeviceType_Ket,
    EADeviceType_Other,
} EADeviceType;

@interface EGDevice : NSObject
@property (nonatomic, strong) CBPeripheral *rawPeripheral;
@property (nonatomic, assign) EADeviceType deviceType;
@property (nonatomic, copy) NSString *advName;
@property (nonatomic, copy) NSString *sn;
- (instancetype)initWithPeripheral:(CBPeripheral *)peripheral adv:(NSDictionary *)advDic sn:(NSString *)sn deviceType:(EADeviceType)type;
@end

NS_ASSUME_NONNULL_END
