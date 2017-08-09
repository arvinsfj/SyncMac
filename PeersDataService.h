//
//  PeersDataService.h
//  CyclingProject
//
//  Created by arvin on 2017/8/7.
//  Copyright © 2017年 com.fuwo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <MultipeerConnectivity/MultipeerConnectivity.h>

#define SyncFileDir_S @"SyncFileDirS"
#define SyncFileDir_C @"SyncFileDirC"

@interface PeersDataService : NSObject <NSApplicationDelegate, MCNearbyServiceAdvertiserDelegate,MCSessionDelegate,MCNearbyServiceBrowserDelegate>
{
    MCPeerID *localPeerID_s;
    MCNearbyServiceAdvertiser *advertiser;
    MCPeerID *localPeerID_c;
    MCNearbyServiceBrowser *browser;
    //
    MCSession *server_session;
    MCSession *client_session;
    //
    NSString* cur_service_id;//name
    NSString* cur_client_id;
    //
}

@property (strong, nonatomic) NSString* service_id;

//+ (instancetype)sharePToP;

- (NSString*)startAdvertising;
- (void)stopAdvertising;
- (void)startBrowser:(NSString*)service_id;
- (void)stopBrowser;

@end

