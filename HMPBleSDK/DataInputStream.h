//
//  DataInputStream.h
//  readFileWriteFile
//
//  Created by 花田半亩 on 2017/8/8.
//  Copyright © 2017年 花田半亩. All rights reserved.
//

#import <Foundation/Foundation.h>

// 从输入流读取基本数据类型的方法，以便解组自定义值类型
@interface DataInputStream : NSObject {
    NSData *data;
    NSInteger length;
}

//
- (id)initWithData:(NSData *)data;

//
+ (id)dataInputStreamWithData:(NSData *)aData;

// 从输入流读取 char 值。
- (uint8_t)readChar;

//从输入流读取 short 值。
- (uint16_t)readShort;

//从输入流读取 int 值。
- (uint32_t)readInt;

//从输入流读取 long 值。
- (uint64_t)readLong;

//从输入流读取 NSString 字符串。
- (NSString *)readUTF;
@end
