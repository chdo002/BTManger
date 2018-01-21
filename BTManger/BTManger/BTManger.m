//
//  BTManger.m
//  Health
//
//  Created by chdo on 2018/1/17.
//  Copyright © 2018年 aat. All rights reserved.
//

#import "BTManger.h"


@interface BTManger()<CBCentralManagerDelegate,CBPeripheralDelegate>
{
    CBCentralManager *manager;
    CBPeripheral *target_peripheral;
    CBCharacteristic *writeCharacter;
    CBCharacteristic *readCharacter;
    NSMutableData *unfinishedData;
}
@end

@implementation BTManger

+(instancetype)share{
    
    static dispatch_once_t onceToken;
    static BTManger *single;
    
    dispatch_once(&onceToken, ^{
        single = [[BTManger alloc] init];
    });
    return single;
}

#pragma mark 启动蓝牙    有设备保存则，直接连，没有设备，则弹出选择框
-(void)startBluetooth{
    
    // 检查是否已经连接
    if (manager && target_peripheral && writeCharacter && readCharacter) {
        if (target_peripheral.state == CBPeripheralStateConnected) {
            return;
        }
    }
    
    manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

-(void)restartBluetooth{
    target_peripheral = nil;
    writeCharacter = nil;
    readCharacter = nil;
    [self startBluetooth];
}
#pragma mark 手机蓝牙状态更新
-(void)centralManagerDidUpdateState:(CBCentralManager *)central{
    
    if (central.state != CBCentralManagerStatePoweredOn) {
        NSString *info;
        if (central.state == CBCentralManagerStatePoweredOff) {
            info = @"请打开蓝牙";
        }
        if (central.state == CBCentralManagerStateUnauthorized) {
            info = @"未获取蓝牙权限，请在设置中打开";
        }
        
        if (central.state == CBCentralManagerStateUnsupported) {
            info = @"该设备不支持蓝牙";
        }
        if (central.state == CBCentralManagerStateResetting) {
            info = @"蓝牙启动中";
        }
        if (central.state == CBCentralManagerStateUnknown) {
            info = @"出现未知错误";
        }

        return;
    }
    
    [manager scanForPeripheralsWithServices:nil options:nil];
}

#pragma mark 发现了设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI{
    target_peripheral = peripheral;
    [manager connectPeripheral:target_peripheral options:nil];
    [manager stopScan];
}

#pragma mark 连上了设备
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    [target_peripheral setDelegate:self];
    // 开始寻找服务
    [target_peripheral discoverServices: nil];
}
#pragma mark 没连上设备，或者失去连接
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{
    [manager connectPeripheral:target_peripheral options:nil];
}
#pragma mark  寻找特定服务
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error{
    for (CBService *service in peripheral.services) {
        //发现特定服务
        if ([service.UUID.UUIDString isEqualToString:@"6E400001-B5A3-F393-E0A9-E50E24DCCA9E"]) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

#pragma mark 寻找到写或读的特征值
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error{
    if (error) {
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        //        写的特征值
        if ([characteristic.UUID.UUIDString isEqualToString:@"6E400002-B5A3-F393-E0A9-E50E24DCCA9E"]) {
            writeCharacter = characteristic;
        }
        
        //        读的特征值
        if ([characteristic.UUID.UUIDString isEqualToString:@"6E400003-B5A3-F393-E0A9-E50E24DCCA9E"]) {
            readCharacter = characteristic;
            [target_peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    
    if (writeCharacter && readCharacter) {
        [self.delegate btMangerReadyToInteraction];
    }
}

#pragma mark  收消息部分

// 监听了某个特征值之后，会回调这个方法
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        return;
    }
    if ([characteristic.UUID.UUIDString isEqualToString:@"6E400003-B5A3-F393-E0A9-E50E24DCCA9E"]) {
        NSString * str  =[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"监听了特征值%@  %@",str,characteristic.UUID.UUIDString);
    }
}

// 收到设备发出消息的时，走这个方法
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        return;
    }
    if (self.willOnlySendData) {
        [self.delegate btMangerReceivedMessageData:characteristic.value];
        return;
    }
    NSString * str = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    if (str) {
        [self.delegate btMangerReceivedMessageString:[str copy]];
    } else {
        [self.delegate btMangerReceivedMessageData:characteristic.value];
    }
}


#pragma mark  发消息部分
-(void)sendCommand:(NSString *)str info:(NSString *)info{
    if (target_peripheral && writeCharacter) {
        NSLog(@"发送字符串命令\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  %@: %@",info,str);
        NSData *data =[str dataUsingEncoding:NSUTF8StringEncoding];
        [target_peripheral writeValue:data forCharacteristic:writeCharacter type:CBCharacteristicWriteWithoutResponse];
    }else {
        NSLog(@"文本发送终止 %@%@",target_peripheral,writeCharacter);
    }
}

-(void)sendDataCommand:(NSData *)data info:(NSString *)info{
    if (target_peripheral && writeCharacter) {
        NSLog(@"发送字节命令\n>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  %@",info);
        [target_peripheral writeValue:data forCharacteristic:writeCharacter type:CBCharacteristicWriteWithoutResponse];
    } else {
        NSLog(@"data发送终止 %@%@",target_peripheral,writeCharacter);
    }
}

// 据说发送命令 特征值会回调这个方法
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        return;
    }
    if ([characteristic.UUID.UUIDString isEqualToString:@"6E400003-B5A3-F393-E0A9-E50E24DCCA9E"]) {
        NSString * str  =[[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        NSLog(@"发送命令 特征值回调 %@     %@",str,characteristic.UUID.UUIDString);
    }
}

/*  不能删
 //    int length = 1095;
 //    NSLog(@"字节数 %d",length);
 //    Byte reg[4];
 //    reg[0] = (Byte)(length >> 24);
 //    reg[1] = (Byte)(length >> 16);
 //    reg[2] = (Byte)(length >> 8);
 //    reg[3] = (Byte)(length);
 //
 //    int bb1 = reg[0] & 0xff;
 //    int bb2 = reg[1] & 0xff;
 //    int bb3 = reg[2] & 0xff;
 //    int bb4 = reg[3] & 0xff;
 //
 //    bb1 = bb1 << 24;
 //    bb2 = bb2 << 16;
 //    bb3 = bb3 << 8;
 //    bb4 = bb4;
 //    uint res = bb1 | bb2 | bb3 | bb4;
 //    NSLog(@"计算后的字长 %u", res);
 */


//uint FourToOne(Byte b1, Byte b2, Byte b3, Byte b4){
//    int bb1 = b1 & 0xff;
//    int bb2 = b2 & 0xff;
//    int bb3 = b3 & 0xff;
//    int bb4 = b4 & 0xff;
//
//    bb1 = bb1 << 24;
//    bb2 = bb2 << 16;
//    bb3 = bb3 << 8;
//    bb4 = bb4;
//
//    uint res = bb1 | bb2 | bb3 | bb4;
//    return res;
//}
//
//void OneToFour(int number, Byte *container){
//    container[0] = (Byte)(number >> 24);
//    container[1] = (Byte)(number >> 16);
//    container[2] = (Byte)(number >> 8);
//    container[3] = (Byte)(number);
//}

//uint bytesToOne(Byte *byteArr, int length){
//    uint res = 0;
//    for (int i = length; i > 0; i--) {
//        int bbb = byteArr[length - i] & 0xff;
//        res = res | (bbb << ((length - 1) * 8));
//    }
//    return res;
//}
//
//void oneToBytes(int number, Byte *container, int length){
//    for (int i = 0; i < length; i++) {
//        container[i] = (Byte)(number >> ((length - 1 - i) * 8));
//    }
//}

@end

