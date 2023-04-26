//
//  DataInputStream.m
//  readFileWriteFile
//
//  Created by 花田半亩 on 2017/8/8.
//  Copyright © 2017年 花田半亩. All rights reserved.
//

#import "DataInputStream.h"
@interface DataInputStream (PrivateMethods)
- (uint32_t)read;
@end
@implementation DataInputStream
- (id)initWithData:(NSData *)aData {
    self = [self init];
    if(self != nil){
        data = [[NSData alloc] initWithData:aData];
    }
    return self;
}

- (id)init{
    self = [super init];
    if(self != nil){
        length = 0;
    }
    return self;
}

+ (id)dataInputStreamWithData:(NSData *)aData {
    DataInputStream *dataInputStream = [[self alloc] initWithData:aData];
    return dataInputStream;
}

- (uint32_t)read{
    uint8_t v;
    [data getBytes:&v range:NSMakeRange(length,1)];
    length++;
    return ((uint32_t)v & 0x0ff);
}

- (uint8_t)readChar {
    uint8_t v;
    [data getBytes:&v range:NSMakeRange(length,1)];
    length++;
    return (v & 0x0ff);
}

- (uint16_t)readShort {
    uint32_t ch1 = [self read];
    uint32_t ch2 = [self read];
    if ((ch1 | ch2) < 0){
        @throw [NSException exceptionWithName:@"Exception" reason:@"EOFException" userInfo:nil];
    }
    return (uint16_t)((ch1 << 8) + (ch2 << 0));
    
}

- (uint32_t)readuint {
    uint32_t ch1 = [self read];
    uint32_t ch2 = [self read];
    uint32_t ch3 = [self read];
    uint32_t ch4 = [self read];
    if ((ch1 | ch2 | ch3 | ch4) < 0){
        @throw [NSException exceptionWithName:@"Exception" reason:@"EOFException" userInfo:nil];
    }
    return ((ch1 << 24) + (ch2 << 16) + (ch3 << 8) + (ch4 << 0));
}

- (uint64_t)readLong {
    uint8_t ch[8];
    [data getBytes:&ch range:NSMakeRange(length,8)];
    length = length + 8;
    
    return (((uint64_t)ch[0] << 56) +
            ((uint64_t)(ch[1] & 255) << 48) +
            ((uint64_t)(ch[2] & 255) << 40) +
            ((uint64_t)(ch[3] & 255) << 32) +
            ((uint64_t)(ch[4] & 255) << 24) +
            ((ch[5] & 255) << 16) +
            ((ch[6] & 255) <<  8) +
            ((ch[7] & 255) <<  0));
    
}

- (NSString *)readUTF {
    short utfLength = [self readShort];
    NSData *d = [data subdataWithRange:NSMakeRange(length,utfLength)];
    NSString *str = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    length = length + utfLength;
    return str;
}

- (void)dealloc{
}
@end
