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
- (NSMutableArray*)fetchFileArr
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
        [fileArr addObject:fileUrl];
    }
    return fileArr;
}

//处理airdrop文件或者文件夹保存逻辑
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
}
//业务逻辑结束
static int snum = 0;
static int scount = 0;
- (void)sendFileArr:(MCPeerID*)peer
{
    NSMutableArray* fileArr = [self fetchFileArr];
    snum = fileArr.count;
    scount = 0;
    for (NSURL* fileUrl in fileArr) {
        [self sendResource:peer andFile:fileUrl];
    }
}

//服务器发送资源
- (void)sendResource:(MCPeerID*)peer andFile:(NSURL*)fileURL
{
    [server_session sendResourceAtURL:fileURL withName:[fileURL lastPathComponent] toPeer:peer withCompletionHandler:^(NSError * _Nullable error) {
        scount++;
        if (!error) {
            NSLog(@"发送成功：%@", [fileURL lastPathComponent]);
        }else{
            NSLog(@"发送失败：%@--%@", [fileURL lastPathComponent], error);
        }
        if (scount == snum) {
            NSLog(@"%@", @"全部传输完毕!!!");
        }
    }];
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
        //服务器端
        localPeerID_s = [[MCPeerID alloc] initWithDisplayName:NSUserName()];
        advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:localPeerID_s discoveryInfo:nil serviceType:XXServiceType];
        advertiser.delegate = self;
        cur_service_id = [NSString stringWithFormat:@"%@", localPeerID_s.displayName];
        NSLog(@"service_id>>>\n%@", cur_service_id);
        //客户端
        localPeerID_c = [[MCPeerID alloc] initWithDisplayName:NSUserName()];
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
    return cur_service_id;
}

- (void)stopAdvertising
{
    [advertiser stopAdvertisingPeer];
    NSLog(@"%@", @"关闭服务器!!!");
}

//服务器代理
- (void)            advertiser:(MCNearbyServiceAdvertiser *)advertiser
  didReceiveInvitationFromPeer:(MCPeerID *)peerID
                   withContext:(NSData *)context
             invitationHandler:(void (^)(BOOL accept, MCSession * __nullable session))invitationHandler
{
    //有客户端连接
    NSString* client_id = [[NSString alloc] initWithData:context encoding:NSUTF8StringEncoding];
    if ([client_id isEqualToString:cur_service_id]) {
        NSLog(@"%@", @"接收到客户端连接!!!!");
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
}
//客户端代理
// Found a nearby advertising peer.
- (void)        browser:(MCNearbyServiceBrowser *)brwser
              foundPeer:(MCPeerID *)peerID
      withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info
{
    //找到了服务器端，可能会找到多个
    if ([cur_client_id isEqualToString:peerID.displayName]) {
        client_session = [[MCSession alloc] initWithPeer:localPeerID_c];
        client_session.delegate = self;
        [browser invitePeer:peerID toSession:client_session withContext:[cur_client_id dataUsingEncoding:NSUTF8StringEncoding] timeout:0];
        NSLog(@"%@", @"开始连接服务器!!!!");
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
            if ([session isEqual:server_session]) {
                [self sendFileArr:peerID];//开始传送数据给客户端
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
        NSLog(@">> %@", info);
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
        [self handleClientData:localURL andName:resourceName];
        NSLog(@"recv>>>\n%@", resourceName);
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
