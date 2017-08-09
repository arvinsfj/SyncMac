//

//gcc -framework Cocoa -framework MultipeerConnectivity -o p2p main.m PeersDataService.m
//clang -framework Cocoa -framework MultipeerConnectivity -o p2p main.m PeersDataService.m

#import <Cocoa/Cocoa.h>

#import "PeersDataService.h"

int main(int argc, const char * argv[]) {
    
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        PeersDataService* delegate = [[PeersDataService alloc] init];
        if (argc == 1) {
            delegate.service_id = @"";
        }
        if (argc == 2) {
            delegate.service_id = [NSString stringWithCString:argv[1] encoding:NSASCIIStringEncoding];
        }
        app.delegate = delegate;
        return NSApplicationMain(argc, (const char**)argv);
    }
}
