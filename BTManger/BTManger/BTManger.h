//
//  BTManger.h
//  Health
//
//  Created by chdo on 2018/1/17.
//  Copyright © 2018年 aat. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
typedef enum : NSUInteger {
    BTStateUnConnected,
    BTStateConnectig,
    BTStatefailed,
    BTStateConnected
} BTState;


@protocol BTMangerDelegate

/**
 蓝牙启动完毕
 */
-(void)btMangerReadyToInteraction;
//
///**
// 收到字符串消息
// */
-(void)btMangerReceivedMessageString:(NSString *)str;

/**
 收到字节消息
 */
-(void)btMangerReceivedMessageData:(NSData *)data;


-(void)sendBTState:(BTState)state info:(NSString *)info;
@end

@interface BTManger : NSObject

@property(weak,nonatomic) id<BTMangerDelegate>delegate;
@property(nonatomic, assign) BOOL willOnlySendData;
+(instancetype)share;
/**
 启动蓝牙 ，链接上设备后，会自动开始 同步时间 -> 同步记录 -> 监听剂量
 */
-(void)startBluetooth;
-(void)restartBluetooth;
-(void)sendCommand:(NSString *)str info:(NSString *)info;
-(void)sendDataCommand:(NSData *)data info:(NSString *)info;

#pragma mark tool


//uint FourToOne(Byte b1, Byte b2, Byte b3, Byte b4);
//void OneToFour(int number, Byte *container);
///**
// 多个字节转为一个uint
//
// @param byteArr 字节数组
// @param length 数组长度
// @return 结果
// */
//uint bytesToOne(Byte *byteArr, int length);
//
///**
// 一个uint转为字节数组
//
// @param number 输入
// @param container 结果数组
// @param length 数组长度
// */
//void oneToBytes(int number, Byte *container, int length);

@end

