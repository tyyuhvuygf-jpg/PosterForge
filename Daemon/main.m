#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import "../Shared/PFShared.h"
#import "PFPosterBuilder.h"

static void ProcessRequests(void) {
    @synchronized(PFPosterBuilder.class) {
    PFEnsureDirectories(NULL); PFPosterBuilder *builder=[PFPosterBuilder new]; NSFileManager *fm=NSFileManager.defaultManager;
    for(NSString *name in [fm contentsOfDirectoryAtPath:PFRequestsDirectory error:nil]) @autoreleasepool {
        if(![name.pathExtension isEqual:@"plist"])continue;
        NSString *path=[PFRequestsDirectory stringByAppendingPathComponent:name]; NSDictionary *request=[NSDictionary dictionaryWithContentsOfFile:path]; if(!request)continue;
        NSError *error=nil; BOOL ok=NO; NSString *action=request[@"action"];
        if([action isEqual:@"install"]) { NSString *identifier=request[@"identifier"]; NSDictionary *item=[NSDictionary dictionaryWithContentsOfFile:[[PFLibraryDirectory stringByAppendingPathComponent:identifier] stringByAppendingPathComponent:@"manifest.plist"]]; ok=item&&[builder installItem:item error:&error]; }
        else if([action isEqual:@"remove"]) ok=[builder removeIdentifier:request[@"identifier"] error:&error];
        else if([action isEqual:@"tendies"]) ok=[builder importTendiesAtPath:request[@"path"] error:&error];
        NSMutableDictionary *result=request.mutableCopy; result[@"success"]=@(ok); result[@"finished"]=NSDate.date; if(error)result[@"error"]=error.localizedDescription;
        [result writeToFile:[PFCompletedDirectory stringByAppendingPathComponent:name] atomically:YES]; [fm removeItemAtPath:path error:nil];
    }
    }
}

static void NotificationCallback(CFNotificationCenterRef c,void *o,CFStringRef n,const void *obj,CFDictionaryRef info){ ProcessRequests(); }

int main(int argc,char **argv){ @autoreleasepool {
    NSLog(@"PosterForge daemon started"); ProcessRequests();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,NotificationCallback,(__bridge CFStringRef)PFReloadNotification,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    NSTimer *timer=[NSTimer timerWithTimeInterval:3 repeats:YES block:^(NSTimer *t){ProcessRequests();}]; [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes]; [NSRunLoop.mainRunLoop run];
} return 0; }
