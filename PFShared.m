#import "PFShared.h"
#import <CoreFoundation/CoreFoundation.h>

NSString * const PFRootDirectory = @"/var/mobile/Library/Application Support/PosterForge";
NSString * const PFLibraryDirectory = @"/var/mobile/Library/Application Support/PosterForge/Library";
NSString * const PFRequestsDirectory = @"/var/mobile/Library/Application Support/PosterForge/Requests";
NSString * const PFCompletedDirectory = @"/var/mobile/Library/Application Support/PosterForge/Completed";
NSString * const PFReloadNotification = @"com.posterforge.reload";

BOOL PFEnsureDirectories(NSError **error) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *path in @[PFRootDirectory, PFLibraryDirectory, PFRequestsDirectory, PFCompletedDirectory]) {
        if (![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0775} error:error]) return NO;
    }
    return YES;
}

NSString *PFNewIdentifier(void) { return NSUUID.UUID.UUIDString.uppercaseString; }

NSArray<NSDictionary *> *PFLoadItems(void) {
    PFEnsureDirectories(NULL);
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *entry in [NSFileManager.defaultManager contentsOfDirectoryAtPath:PFLibraryDirectory error:nil]) {
        NSString *manifest = [[PFLibraryDirectory stringByAppendingPathComponent:entry] stringByAppendingPathComponent:@"manifest.plist"];
        NSDictionary *item = [NSDictionary dictionaryWithContentsOfFile:manifest];
        if (item) [result addObject:item];
    }
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"created"] compare:a[@"created"]];
    }];
    return result;
}

BOOL PFSaveItem(NSDictionary *item, NSError **error) {
    NSString *identifier = item[@"identifier"];
    if (!identifier.length || !PFEnsureDirectories(error)) return NO;
    NSString *dir = [PFLibraryDirectory stringByAppendingPathComponent:identifier];
    if (![NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0775} error:error]) return NO;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:item format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    return data && [data writeToFile:[dir stringByAppendingPathComponent:@"manifest.plist"] options:NSDataWritingAtomic error:error];
}

BOOL PFDeleteItem(NSString *identifier, NSError **error) {
    BOOL ok = [NSFileManager.defaultManager removeItemAtPath:[PFLibraryDirectory stringByAppendingPathComponent:identifier] error:error];
    PFQueueRequest(@{@"action":@"remove", @"identifier":identifier}, NULL);
    return ok;
}

BOOL PFQueueRequest(NSDictionary *request, NSError **error) {
    if (!PFEnsureDirectories(error)) return NO;
    NSMutableDictionary *payload = request.mutableCopy;
    payload[@"requestID"] = PFNewIdentifier();
    payload[@"created"] = NSDate.date;
    NSString *path = [PFRequestsDirectory stringByAppendingPathComponent:[payload[@"requestID"] stringByAppendingString:@".plist"]];
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:payload format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    if (!data || ![data writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)PFReloadNotification, NULL, NULL, true);
    return YES;
}

NSString *PFPosterBoardContainer(void) {
    NSString *base = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *uuid in [fm contentsOfDirectoryAtPath:base error:nil]) {
        NSString *root = [base stringByAppendingPathComponent:uuid];
        NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:[root stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"]];
        if ([meta[@"MCMMetadataIdentifier"] isEqual:@"com.apple.PosterBoard"]) return root;
    }
    return nil;
}
