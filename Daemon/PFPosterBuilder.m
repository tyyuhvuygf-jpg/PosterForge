#import "PFPosterBuilder.h"
#import "../Shared/PFShared.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <unistd.h>
extern char **environ;

static NSError *PFError(NSString *message) {
    return [NSError errorWithDomain:@"com.posterforge" code:1 userInfo:@{NSLocalizedDescriptionKey:message ?: @"Unknown error"}];
}

static NSString *PFTool(NSString *name) {
    for(NSString *base in @[@"/var/jb/usr/bin",@"/usr/bin",@"/bin"]) { NSString *path=[base stringByAppendingPathComponent:name]; if([NSFileManager.defaultManager isExecutableFileAtPath:path])return path; }
    return [@"/usr/bin" stringByAppendingPathComponent:name];
}

static NSString *PFRun(NSArray<NSString *> *arguments, int *status) {
    int pipes[2]; if (pipe(pipes) != 0) return nil;
    char **argv = calloc(arguments.count + 1, sizeof(char *));
    for (NSUInteger i=0; i<arguments.count; i++) argv[i]=(char *)arguments[i].UTF8String;
    posix_spawn_file_actions_t actions; posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, pipes[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, pipes[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipes[0]);
    pid_t pid=0; int rc=posix_spawn(&pid, argv[0], &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions); close(pipes[1]); free(argv);
    if (rc != 0) { close(pipes[0]); if(status)*status=rc; return nil; }
    NSMutableData *out=[NSMutableData data]; uint8_t buf[4096]; ssize_t n;
    while ((n=read(pipes[0],buf,sizeof(buf)))>0) [out appendBytes:buf length:(NSUInteger)n];
    close(pipes[0]); int st=0; waitpid(pid,&st,0); if(status)*status=WIFEXITED(st)?WEXITSTATUS(st):-1;
    return [[NSString alloc] initWithData:out encoding:NSUTF8StringEncoding];
}

static BOOL PFWritePlist(id object, NSString *path, NSError **error) {
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:object format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    return data && [data writeToFile:path options:NSDataWritingAtomic error:error];
}

@implementation PFPosterBuilder

- (NSString *)descriptorRoot:(NSError **)error {
    NSString *container=PFPosterBoardContainer();
    if (!container) { if(error)*error=PFError(@"PosterBoard container was not found"); return nil; }
    NSString *root=[container stringByAppendingPathComponent:@"Library/Application Support/PRBPosterExtensionDataStore/59/Extensions/com.apple.WallpaperKit.CollectionsPoster/descriptors"];
    if (![NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0775} error:error]) return nil;
    return root;
}

- (BOOL)installItem:(NSDictionary *)item error:(NSError **)error {
    NSString *uuid=item[@"identifier"];
    NSString *source=item[@"sourcePath"];
    if (!uuid.length || !source.length) { if(error)*error=PFError(@"Invalid manifest"); return NO; }
    NSString *root=[self descriptorRoot:error]; if(!root)return NO;
    NSString *destination=[root stringByAppendingPathComponent:uuid];
    [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
    NSString *content=[destination stringByAppendingPathComponent:@"versions/1/contents"];
    NSString *wallpaperName=[NSString stringWithFormat:@"%@.Custom.wallpaper",uuid];
    NSString *wallpaper=[content stringByAppendingPathComponent:wallpaperName];
    NSString *background=[wallpaper stringByAppendingPathComponent:@"PF_Background.ca"];
    NSString *floating=[wallpaper stringByAppendingPathComponent:@"PF_Floating.ca"];
    for(NSString *dir in @[background,floating]) if(![NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:error])return NO;

    NSInteger wallpaperID=10000+arc4random_uniform(89999);
    [[NSString stringWithFormat:@"%ld",(long)wallpaperID] writeToFile:[destination stringByAppendingPathComponent:@"com.apple.posterkit.provider.descriptor.identifier"] atomically:YES encoding:NSUTF8StringEncoding error:error];
    [@"PRPosterRoleLockScreen" writeToFile:[destination stringByAppendingPathComponent:@"com.apple.posterkit.role.identifier"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSData *provider=[NSKeyedArchiver archivedDataWithRootObject:@{@"kConfigurationLastUseDateKey":NSDate.date} requiringSecureCoding:NO error:nil];
    [provider writeToFile:[destination stringByAppendingPathComponent:@"providerInfo.plist"] options:NSDataWritingAtomic error:nil];

    NSDictionary *userInfo=@{@"posterEnvironmentOverrides":[@"{}" dataUsingEncoding:NSUTF8StringEncoding],@"wallpaperRepresentingFileName":wallpaperName,@"wallpaperRepresentingIdentifier":[NSString stringWithFormat:@"%ld",(long)wallpaperID]};
    if(!PFWritePlist(userInfo,[content stringByAppendingPathComponent:@"com.apple.posterkit.provider.contents.userInfo"],error))return NO;

    NSString *title=item[@"title"] ?: @"PosterForge";
    NSDictionary *wp=@{@"appearanceAware":@YES,@"assets":@{@"lockAndHome":@{@"default":@{@"backgroundAnimationFileName":@"PF_Background.ca",@"floatingAnimationFileNameKey":@"PF_Floating.ca",@"identifier":@(wallpaperID),@"name":title,@"type":@"LayeredAnimation"}}},@"contentVersion":@2.01,@"family":@"Marble",@"identifier":@(wallpaperID),@"logicalScreenClass":@"375w-812h@3x~iphone",@"name":title,@"preferredProminentColor":@{@"dark":@"#000000",@"default":@"#FFFFFF"},@"version":@1};
    if(!PFWritePlist(wp,[wallpaper stringByAppendingPathComponent:@"Wallpaper.plist"],error))return NO;

    BOOL homeBlur=[item[@"homeBlur"] boolValue] && [item[@"kind"] isEqual:@"image"];
    if(![self buildAnimationAt:background source:source kind:item[@"kind"] ?: @"image" maxFPS:[item[@"fps"] integerValue] blurred:homeBlur error:error])return NO;
    if(homeBlur) { if(![self buildAnimationAt:floating source:source kind:@"image" maxFPS:1 blurred:NO error:error])return NO; }
    else if(![self writeEmptyLayerAt:floating error:error])return NO;
    chmod(destination.fileSystemRepresentation,0775);
    [self refreshPosterBoard];
    return YES;
}

- (BOOL)writeIndexAt:(NSString *)dir width:(NSInteger)width height:(NSInteger)height error:(NSError **)error {
    NSDictionary *index=@{@"assetManifest":@"assetManifest.caml",@"documentHeight":@(height),@"documentResizesToView":@YES,@"documentWidth":@(width),@"geometryFlipped":@NO,@"rootDocument":@"main.caml",@"scalesToFitInPlayer":@YES,@"unitsInPixelsInPlayer":@YES};
    return PFWritePlist(index,[dir stringByAppendingPathComponent:@"index.xml"],error);
}

- (BOOL)writeEmptyLayerAt:(NSString *)dir error:(NSError **)error {
    NSString *caml=@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><caml xmlns=\"http://www.apple.com/CoreAnimation/1.0\"><CALayer bounds=\"0 0 1 1\" hidden=\"0\" name=\"_FLOATING\" position=\"0.5 0.5\"><sublayers/></CALayer></caml>";
    if(![caml writeToFile:[dir stringByAppendingPathComponent:@"main.caml"] atomically:YES encoding:NSUTF8StringEncoding error:error])return NO;
    return [self writeIndexAt:dir width:1 height:1 error:error];
}

- (UIImage *)processedImage:(UIImage *)image blurred:(BOOL)blurred {
    if(!blurred)return image; CIImage *input=[[CIImage alloc]initWithImage:image]; CIFilter *filter=[CIFilter filterWithName:@"CIGaussianBlur"]; [filter setValue:input forKey:kCIInputImageKey]; [filter setValue:@28 forKey:kCIInputRadiusKey];
    CIContext *context=[CIContext contextWithOptions:nil]; CGImageRef cg=[context createCGImage:filter.outputImage fromRect:input.extent]; UIImage *result=[UIImage imageWithCGImage:cg];CGImageRelease(cg);return result;
}

- (BOOL)buildAnimationAt:(NSString *)dir source:(NSString *)source kind:(NSString *)kind maxFPS:(NSInteger)requestedFPS blurred:(BOOL)blurred error:(NSError **)error {
    NSString *assets=[dir stringByAppendingPathComponent:@"assets"];
    if(![NSFileManager.defaultManager createDirectoryAtPath:assets withIntermediateDirectories:YES attributes:nil error:error])return NO;
    NSMutableArray<NSString *> *names=[NSMutableArray array]; NSInteger width=1179,height=2556; double duration=1.0;
    if([kind isEqual:@"video"]) {
        AVURLAsset *asset=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:source] options:nil];
        duration=CMTimeGetSeconds(asset.duration); if(!isfinite(duration)||duration<=0){if(error)*error=PFError(@"Unreadable video");return NO;}
        NSInteger fps=MAX(1,MIN(requestedFPS ?: 15,30)); NSInteger frames=MIN(400,MAX(2,(NSInteger)ceil(duration*fps)));
        duration=(double)frames/fps;
        AVAssetImageGenerator *gen=[[AVAssetImageGenerator alloc]initWithAsset:asset]; gen.appliesPreferredTrackTransform=YES; gen.maximumSize=CGSizeMake(1290,2796);
        for(NSInteger i=0;i<frames;i++)@autoreleasepool {
            CMTime t=CMTimeMakeWithSeconds((double)i/fps,600); CGImageRef cg=[gen copyCGImageAtTime:t actualTime:NULL error:error]; if(!cg)return NO;
            width=CGImageGetWidth(cg); height=CGImageGetHeight(cg); UIImage *image=[self processedImage:[UIImage imageWithCGImage:cg] blurred:blurred]; CGImageRelease(cg);
            NSString *name=[NSString stringWithFormat:@"%ld.jpg",(long)i]; NSData *jpeg=UIImageJPEGRepresentation(image,0.82);
            if(![jpeg writeToFile:[assets stringByAppendingPathComponent:name] options:NSDataWritingAtomic error:error])return NO; [names addObject:name];
        }
    } else {
        UIImage *image=[UIImage imageWithContentsOfFile:source]; if(!image){if(error)*error=PFError(@"Unreadable image");return NO;} image=[self processedImage:image blurred:blurred];
        width=CGImageGetWidth(image.CGImage); height=CGImageGetHeight(image.CGImage); NSData *jpeg=UIImageJPEGRepresentation(image,0.94);
        if(![jpeg writeToFile:[assets stringByAppendingPathComponent:@"0.jpg"] options:NSDataWritingAtomic error:error])return NO; [names addObject:@"0.jpg"];
    }
    NSMutableString *values=[NSMutableString string]; for(NSString *name in names)[values appendFormat:@"<CGImage src=\"assets/%@\"/>",name];
    NSString *animation=names.count>1?[NSString stringWithFormat:@"<animations><animation type=\"CAKeyframeAnimation\" calculationMode=\"linear\" keyPath=\"contents\" beginTime=\"1e-100\" duration=\"%.4f\" removedOnCompletion=\"0\" repeatCount=\"inf\"><values>%@</values></animation></animations>",duration,values]:@"";
    NSString *caml=[NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><caml xmlns=\"http://www.apple.com/CoreAnimation/1.0\"><CALayer bounds=\"0 0 %ld %ld\" contentsFormat=\"RGBA8\" name=\"_BACKGROUND\" position=\"%g %g\"><sublayers><CALayer bounds=\"0 0 %ld %ld\" contentsFormat=\"RGBA8\" position=\"%g %g\"><contents type=\"CGImage\" src=\"assets/0.jpg\"/>%@</CALayer></sublayers><states><LKState name=\"Locked\"><elements/></LKState><LKState name=\"Unlock\"><elements/></LKState><LKState name=\"Sleep\"><elements/></LKState></states></CALayer></caml>",(long)width,(long)height,width/2.0,height/2.0,(long)width,(long)height,width/2.0,height/2.0,animation];
    if(![caml writeToFile:[dir stringByAppendingPathComponent:@"main.caml"] atomically:YES encoding:NSUTF8StringEncoding error:error])return NO;
    return [self writeIndexAt:dir width:width height:height error:error];
}

- (BOOL)removeIdentifier:(NSString *)identifier error:(NSError **)error {
    NSString *root=[self descriptorRoot:error]; if(!root)return NO;
    NSString *path=[root stringByAppendingPathComponent:identifier];
    if([NSFileManager.defaultManager fileExistsAtPath:path] && ![NSFileManager.defaultManager removeItemAtPath:path error:error])return NO;
    [self refreshPosterBoard]; return YES;
}

- (BOOL)importTendiesAtPath:(NSString *)path error:(NSError **)error {
    NSString *unzip=PFTool(@"unzip"); int status=0; NSString *list=PFRun(@[unzip,@"-Z1",path],&status);
    if(status!=0||!list.length){if(error)*error=PFError(@"Cannot inspect Tendies archive");return NO;}
    for(NSString *entry in [list componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        if([entry hasPrefix:@"/"]||[entry containsString:@"\\"]||[[entry pathComponents] containsObject:@".."]) { if(error)*error=PFError(@"Unsafe path in Tendies archive"); return NO; }
    }
    NSString *tmp=[@"/var/tmp" stringByAppendingPathComponent:[@"PosterForge-" stringByAppendingString:PFNewIdentifier()]];
    [NSFileManager.defaultManager createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:error];
    PFRun(@[unzip,@"-qq",path,@"-d",tmp],&status); if(status!=0){if(error)*error=PFError(@"Cannot extract Tendies archive");return NO;}
    NSString *root=[self descriptorRoot:error]; if(!root)return NO; BOOL imported=NO;
    NSDirectoryEnumerator *en=[NSFileManager.defaultManager enumeratorAtPath:tmp]; NSString *relative;
    while((relative=en.nextObject)) {
        NSString *lower=relative.lastPathComponent.lowercaseString;
        if(![lower containsString:@"descriptor"] )continue;
        NSString *descriptorGroup=[tmp stringByAppendingPathComponent:relative]; BOOL isDir=NO;
        if(![NSFileManager.defaultManager fileExistsAtPath:descriptorGroup isDirectory:&isDir]||!isDir)continue;
        for(NSString *child in [NSFileManager.defaultManager contentsOfDirectoryAtPath:descriptorGroup error:nil]) {
            NSString *src=[descriptorGroup stringByAppendingPathComponent:child]; BOOL childDir=NO; if(![NSFileManager.defaultManager fileExistsAtPath:src isDirectory:&childDir]||!childDir)continue;
            NSString *uuid=PFNewIdentifier(); NSString *dst=[root stringByAppendingPathComponent:uuid];
            if([NSFileManager.defaultManager copyItemAtPath:src toPath:dst error:nil]) { [self randomizeDescriptorAtPath:dst]; imported=YES; }
        }
        [en skipDescendants];
    }
    [NSFileManager.defaultManager removeItemAtPath:tmp error:nil];
    if(!imported){if(error)*error=PFError(@"No descriptor folder found in Tendies archive");return NO;}
    [self refreshPosterBoard]; return YES;
}

- (void)randomizeDescriptorAtPath:(NSString *)path {
    NSInteger newID=10000+arc4random_uniform(89999);
    [[NSString stringWithFormat:@"%ld",(long)newID] writeToFile:[path stringByAppendingPathComponent:@"com.apple.posterkit.provider.descriptor.identifier"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSDirectoryEnumerator *en=[NSFileManager.defaultManager enumeratorAtPath:path]; NSString *rel;
    while((rel=en.nextObject)) {
        NSString *full=[path stringByAppendingPathComponent:rel];
        if([rel.lastPathComponent isEqual:@"com.apple.posterkit.provider.contents.userInfo"]) { NSMutableDictionary *p=[NSDictionary dictionaryWithContentsOfFile:full].mutableCopy; if(p){p[@"wallpaperRepresentingIdentifier"]=[NSString stringWithFormat:@"%ld",(long)newID];PFWritePlist(p,full,NULL);} }
        else if([rel.lastPathComponent isEqual:@"Wallpaper.plist"]) { NSMutableDictionary *p=[NSDictionary dictionaryWithContentsOfFile:full].mutableCopy; if(p){p[@"identifier"]=@(newID);NSMutableDictionary *assets=[p[@"assets"] mutableCopy];NSMutableDictionary *lh=[assets[@"lockAndHome"] mutableCopy];NSMutableDictionary *def=[lh[@"default"] mutableCopy];if(def){def[@"identifier"]=@(newID);lh[@"default"]=def;assets[@"lockAndHome"]=lh;p[@"assets"]=assets;}PFWritePlist(p,full,NULL);} }
    }
}

- (void)refreshPosterBoard {
    NSString *container=PFPosterBoardContainer();
    if(container){ NSString *prefs=[container stringByAppendingPathComponent:@"Library/Preferences/com.apple.PosterBoard.unprotectedUserDefaults.plist"]; PFWritePlist(@{@"PBF_LOCALE_DID_CHANGE":@NO,@"PBF_RESET_FILE_PROTECTIONS":@YES},prefs,NULL); }
    int status=0; PFRun(@[PFTool(@"killall"),@"-9",@"PosterBoard"],&status);
}
@end
