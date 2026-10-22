#import &lt;Foundation/Foundation.h&gt;
#import &lt;CoreFoundation/CoreFoundation.h&gt;
#import &quot;../Shared/PFShared.h&quot;
#import &quot;PFPosterBuilder.h&quot;

static void ProcessRequests(void) {
 @synchronized(PFPosterBuilder.class) {
        NSError *directoryError = nil;
        if (!PFEnsureDirectories(&amp;directoryError)) {
            NSLog(@&quot;PosterForge: cannot prepare storage: %@&quot;, directoryError.localizedDescription ?: @&quot;unknown error&quot;);
            return;
        }

        PFPosterBuilder *builder = [PFPosterBuilder new];
        NSFileManager *fm = NSFileManager.defaultManager;
        NSError *listingError = nil;
        NSArray&lt;NSString *&gt; *requests = [fm contentsOfDirectoryAtPath:PFRequestsDirectory error:&amp;listingError];
        if (!requests) {
            NSLog(@&quot;PosterForge: cannot list requests at %@: %@&quot;, PFRequestsDirectory, listingError.localizedDescription ?: @&quot;unknown error&quot;);
            return;
        }

        for (NSString *name in requests) @autoreleasepool {
            if (![name.pathExtension isEqualToString:@&quot;plist&quot;]) continue;
            NSString *path = [PFRequestsDirectory stringByAppendingPathComponent:name];
            NSDictionary *request = [NSDictionary dictionaryWithContentsOfFile:path];
            if (!request) {
                NSLog(@&quot;PosterForge: cannot read request %@&quot;, path);
                continue;
            }

            NSError *error = nil;
            BOOL ok = NO;
            NSString *action = request[@&quot;action&quot;];
            NSString *requestID = request[@&quot;requestID&quot;] ?: name;
            NSLog(@&quot;PosterForge: processing request %@ action=%@&quot;, requestID, action ?: @&quot;(missing)&quot;);

            if ([action isEqualToString:@&quot;install&quot;]) {
                NSString *identifier = request[@&quot;identifier&quot;];
                NSString *manifestPath = [[PFLibraryDirectory stringByAppendingPathComponent:identifier ?: @&quot;&quot;] stringByAppendingPathComponent:@&quot;manifest.plist&quot;];
                NSDictionary *item = [NSDictionary dictionaryWithContentsOfFile:manifestPath];
                if (!item) {
                    error = [NSError errorWithDomain:@&quot;com.posterforge&quot; code:2 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@&quot;Wallpaper manifest not found at %@&quot;, manifestPath]}];
                } else {
                    ok = [builder installItem:item error:&amp;error];
                }
            } else if ([action isEqualToString:@&quot;remove&quot;]) {
                ok = [builder removeIdentifier:request[@&quot;identifier&quot;] error:&amp;error];
            } else if ([action isEqualToString:@&quot;tendies&quot;]) {
                ok = [builder importTendiesAtPath:request[@&quot;path&quot;] error:&amp;error];
            } else {
                error = [NSError errorWithDomain:@&quot;com.posterforge&quot; code:3 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@&quot;Unknown request action: %@&quot;, action ?: @&quot;(missing)&quot;]}];
            }

            NSMutableDictionary *result = request.mutableCopy;
            result[@&quot;success&quot;] = @(ok);
            result[@&quot;finished&quot;] = NSDate.date;
            if (error) result[@&quot;error&quot;] = error.localizedDescription ?: @&quot;Unknown error&quot;;

            NSString *resultPath = [PFCompletedDirectory stringByAppendingPathComponent:name];
            BOOL wroteResult = [result writeToFile:resultPath atomically:YES];
            if (!wroteResult) NSLog(@&quot;PosterForge: FAILED to write result for %@ to %@&quot;, requestID, resultPath);

            NSError *removeError = nil;
            if (![fm removeItemAtPath:path error:&amp;removeError]) NSLog(@&quot;PosterForge: cannot remove request %@: %@&quot;, requestID, removeError.localizedDescription ?: @&quot;unknown error&quot;);
            NSLog(@&quot;PosterForge: request %@ finished success=%@ error=%@ resultWritten=%@&quot;, requestID, ok ? @&quot;YES&quot; : @&quot;NO&quot;, error.localizedDescription ?: @&quot;none&quot;, wroteResult ? @&quot;YES&quot; : @&quot;NO&quot;);
        }
    }
}

static void NotificationCallback(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef info) { ProcessRequests(); }

int main(int argc, char **argv) {
 @autoreleasepool {
        NSLog(@&quot;PosterForge daemon started&quot;);
        ProcessRequests();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, NotificationCallback, (__bridge CFStringRef)PFReloadNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        NSTimer *timer = [NSTimer timerWithTimeInterval:3 repeats:YES block:^(NSTimer *t) { ProcessRequests(); }];
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
        [NSRunLoop.mainRunLoop run];
    }
    return 0;
}
