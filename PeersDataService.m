//
//  PeersDataService.m
//  CyclingProject
//
//  Created by arvin on 2017/8/7.
//  Copyright © 2017年 com.fuwo. All rights reserved.
//

#import "PeersDataService.h"

@implementation PeersDataService

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSLog(@"%@", @"loaded!");
    if (_service_id.length) {
        [self startBrowser:_service_id];
    }else{
        _service_id = [self startAdvertising];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

//业务逻辑
- (NSMutableArray*)fetchClientFileArr
{
    NSMutableArray* fileArr = [[NSMutableArray alloc] init];
    NSFileManager* fmgr = [NSFileManager defaultManager];
    NSString *fileDir = [NSHomeDirectory() stringByAppendingPathComponent:SyncFileDir_C];
    if (![fmgr fileExistsAtPath:fileDir]) {
        [fmgr createDirectoryAtPath:fileDir withIntermediateDirectories:YES attributes:nil error:nil];
        return fileArr;
    }
    NSDirectoryEnumerator *femun = [fmgr enumeratorAtURL:[NSURL fileURLWithPath:fileDir] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    for (NSURL *fileUrl in femun) {
        [fileArr addObject:[fileUrl lastPathComponent]];
    }
    return fileArr;//name arr
}

- (NSMutableArray*)fetchServiceFileArrWith:(NSMutableArray*)clientArr;
{
    NSMutableArray* fileArr = [[NSMutableArray alloc] init];
    NSFileManager* fmgr = [NSFileManager defaultManager];
    NSString *fileDir = [NSHomeDirectory() stringByAppendingPathComponent:SyncFileDir_S];
    if (![fmgr fileExistsAtPath:fileDir]) {
        [fmgr createDirectoryAtPath:fileDir withIntermediateDirectories:YES attributes:nil error:nil];
        return fileArr;
    }
    NSDirectoryEnumerator *femun = [fmgr enumeratorAtURL:[NSURL fileURLWithPath:fileDir] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    for (NSURL *fileUrl in femun) {
        if (![clientArr containsObject:[fileUrl lastPathComponent]]) {
            [fileArr addObject:fileUrl];
        }
    }
    return fileArr;
}

//客户端处理文件
- (void)handleClientData:(NSURL*)url andName:(NSString*)name
{
    NSFileManager* fmgr = [NSFileManager defaultManager];
    NSString *fileDir = [NSHomeDirectory() stringByAppendingPathComponent:SyncFileDir_C];
    if (![fmgr fileExistsAtPath:fileDir]) {
        [fmgr createDirectoryAtPath:fileDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSData* recvData = [NSData dataWithContentsOfURL:url];
    NSString* filePath = [fileDir stringByAppendingPathComponent:name];
    if ([fmgr fileExistsAtPath:filePath isDirectory:nil]) {
        [fmgr removeItemAtPath:filePath error:nil];
    }
    [recvData writeToFile:filePath atomically:YES];
    NSLog(@"成功接收: %@", name);
}
//业务逻辑结束

//客户端发送同步消息
- (void)sendSyncMsg:(MCPeerID*)peer andMsgArr:(NSMutableArray*)msgArr
{
    NSString* msgStr = @"empty";
    if (msgArr&&msgArr.count) {
        msgStr = [msgArr componentsJoinedByString:@"||"];
    }
    NSError* error;
    [client_session sendData:[msgStr dataUsingEncoding:NSUTF8StringEncoding] toPeers:@[peer] withMode:MCSessionSendDataReliable error:&error];
    NSLog(@"%@", @"发送同步消息...");
}

//服务端发送资源
- (void)sendFileArr:(MCPeerID*)peer andArr:(NSMutableArray*)clientArr
{
    NSMutableArray* fileArr = [self fetchServiceFileArrWith:clientArr];
    __block int snum = (int)fileArr.count;
    __block int scount = 0;
    __block MCSession* service_session = server_session;
    if (snum == 0) {
        NSLog(@"%@: 数据全部传输完毕!!!", peer.displayName);
        NSError* error;
        [service_session sendData:[@"filesync_end" dataUsingEncoding:NSUTF8StringEncoding] toPeers:@[peer] withMode:MCSessionSendDataReliable error:&error];
    }
    for (NSURL* fileUrl in fileArr) {
        [server_session sendResourceAtURL:fileUrl withName:[fileUrl lastPathComponent] toPeer:peer withCompletionHandler:^(NSError * _Nullable error) {
            scount++;
            if (!error) {
                NSLog(@"发送成功：%@", [fileUrl lastPathComponent]);
            }else{
                NSLog(@"发送失败：%@--%@", [fileUrl lastPathComponent], error);
            }
            if (scount == snum) {
                NSLog(@"%@: 数据全部传输完毕!!!", peer.displayName);
                NSError* error;
                [service_session sendData:[@"filesync_end" dataUsingEncoding:NSUTF8StringEncoding] toPeers:@[peer] withMode:MCSessionSendDataReliable error:&error];
            }
        }];
    }
}

//p2p机制
static NSString * const XXServiceType = @"filesync";

static PeersDataService* instance;
+ (instancetype)sharePToP
{
    // 也可以使用一次性代码
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (instance == nil) {
            instance = [[PeersDataService alloc] init];
        }
    });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        //服务端
        localPeerID_s = [[MCPeerID alloc] initWithDisplayName:NSUserName()];
        advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:localPeerID_s discoveryInfo:nil serviceType:XXServiceType];
        advertiser.delegate = self;
        cur_service_id = [NSString stringWithFormat:@"%@", localPeerID_s.displayName];
        //客户端
        localPeerID_c = [[MCPeerID alloc] initWithDisplayName:[NSUserName() stringByAppendingString:@"_client"]];
        browser = [[MCNearbyServiceBrowser alloc] initWithPeer:localPeerID_c serviceType:XXServiceType];
        browser.delegate = self;
        //
    }
    return self;
}

//
- (NSString*)startAdvertising
{
    [advertiser startAdvertisingPeer];
    NSLog(@"%@", @"开启服务器!!!");
    NSLog(@"服务号: %@", cur_service_id);
    return cur_service_id;
}

- (void)stopAdvertising
{
    [advertiser stopAdvertisingPeer];
    NSLog(@"%@", @"关闭服务器!!!");
}

//服务端回调代理
- (void)            advertiser:(MCNearbyServiceAdvertiser *)advertiser
  didReceiveInvitationFromPeer:(MCPeerID *)peerID
                   withContext:(NSData *)context
             invitationHandler:(void (^)(BOOL accept, MCSession * __nullable session))invitationHandler
{
    //有客户端连接
    NSString* client_id = [[NSString alloc] initWithData:context encoding:NSUTF8StringEncoding];
    if ([client_id isEqualToString:cur_service_id]) {
        NSLog(@"%@", @"接收到客户端连接!!!!");
        NSLog(@"客户端：%@", peerID.displayName);
        server_session = [[MCSession alloc] initWithPeer:localPeerID_s];
        server_session.delegate = self;
        invitationHandler(YES, server_session);
    }else{
        invitationHandler(NO, nil);
    }
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    //失败，没有启动
    NSLog(@"advertiser>>>>>\n%@", error);
}


//////////////////////////////////////////////////////
- (void)startBrowser:(NSString*)service_id
{
    cur_client_id = service_id;
    [browser startBrowsingForPeers];
    NSLog(@"%@", @"开启客户端搜索!!!");
}

- (void)stopBrowser
{
    [browser stopBrowsingForPeers];
    NSLog(@"%@", @"关闭客户端搜索!!!");
    exit(0);
}
//客户端代理
- (void)        browser:(MCNearbyServiceBrowser *)brwser
              foundPeer:(MCPeerID *)peerID
      withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info
{
    //找到了服务端，可能会找到多个
    if ([cur_client_id isEqualToString:peerID.displayName]) {
        client_session = [[MCSession alloc] initWithPeer:localPeerID_c];
        client_session.delegate = self;
        [browser invitePeer:peerID toSession:client_session withContext:[cur_client_id dataUsingEncoding:NSUTF8StringEncoding] timeout:0];
        NSLog(@"开始连接服务端: %@", peerID.displayName);
        //[self stopBrowser];
    }
}

// A nearby peer has stopped advertising.
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    //服务器端停止服务，客户端也停止寻找服务器
    [self stopBrowser];
}

// Browsing did not start due to an error.
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    //没有开始寻找服务器端，出错
    NSLog(@"browser>>>>>\n%@", error);
}


//////////////////////////////////////////////////////
//session 代理
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    switch(state){
        case MCSessionStateConnected:{
            NSLog(@"连接成功.");
            if ([session isEqual:client_session]) {
                [self sendSyncMsg:peerID andMsgArr:[self fetchClientFileArr]];
            }
            break;
        }
        case MCSessionStateConnecting:
            NSLog(@"正在连接...");
            break;
        default:
            NSLog(@"连接失败.");
            break;
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    NSString* info = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (info) {
        //NSLog(@">> %@", info);
        if ([session isEqual:server_session]) {
            if ([info isEqualToString:@"empty"]) {
                [self sendFileArr:peerID andArr:[NSMutableArray new]];
            }else{
                NSArray* clientArr = [info componentsSeparatedByString:@"||"];
                [self sendFileArr:peerID andArr:[[NSMutableArray alloc] initWithArray:clientArr]];
            }
        }
        if ([session isEqual:client_session]) {
            if ([info isEqualToString:@"filesync_end"]) {
                [self stopBrowser];
            }
        }
    }
}

- (void)    session:(MCSession *)session
   didReceiveStream:(NSInputStream *)stream
           withName:(NSString *)streamName
           fromPeer:(MCPeerID *)peerID
{
    
}

- (void)                    session:(MCSession *)session
  didStartReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                       withProgress:(NSProgress *)progress
{
    
}

- (void)                    session:(MCSession *)session
 didFinishReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                              atURL:(NSURL *)localURL
                          withError:(NSError *)error
{
    if (!error) {
        if ([session isEqual:client_session]) {
            [self handleClientData:localURL andName:resourceName];
        }
    }else{
        NSLog(@"%@", error);
    }
}

- (void)        session:(MCSession *)session
  didReceiveCertificate:(NSArray *)certificate
               fromPeer:(MCPeerID *)peerID
     certificateHandler:(void (^)(BOOL accept))certificateHandler
{
    certificateHandler(YES);
}

@end
