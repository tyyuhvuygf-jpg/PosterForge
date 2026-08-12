#import "PFRootListController.h"
#import "PFCropViewController.h"
#import "../Shared/PFShared.h"
#import <PhotosUI/PhotosUI.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface PFRootListController () <UITableViewDataSource,UITableViewDelegate,PHPickerViewControllerDelegate,UIDocumentPickerDelegate>
@property UITableView *table;
@property NSArray<NSDictionary *> *items;
@property UILabel *emptyLabel;
@end

@implementation PFRootListController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"PosterForge"; self.view.backgroundColor=UIColor.systemGroupedBackgroundColor; PFEnsureDirectories(NULL);
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showAddMenu:)];
    _table=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped]; _table.translatesAutoresizingMaskIntoConstraints=NO; _table.dataSource=self; _table.delegate=self; _table.rowHeight=82; [self.view addSubview:_table];
    [NSLayoutConstraint activateConstraints:@[[_table.topAnchor constraintEqualToAnchor:self.view.topAnchor],[_table.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[_table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[_table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];
    _emptyLabel=[UILabel new]; _emptyLabel.text=@"No wallpapers yet\nTap + to add a photo, video, or .tendies package."; _emptyLabel.numberOfLines=0; _emptyLabel.textAlignment=NSTextAlignmentCenter; _emptyLabel.textColor=UIColor.secondaryLabelColor; _table.backgroundView=_emptyLabel; [self reload];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self reload];}
- (void)reload{_items=PFLoadItems();_emptyLabel.hidden=_items.count>0;[_table reloadData];}
- (void)showAddMenu:(UIBarButtonItem *)sender {
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"Add wallpaper" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Photo or video" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self pickMedia];}]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Import .tendies" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){[self pickTendies];}]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]]; menu.popoverPresentationController.barButtonItem=sender; [self presentViewController:menu animated:YES completion:nil];
}
- (void)pickMedia {
    PHPickerConfiguration *config=[[PHPickerConfiguration alloc]initWithPhotoLibrary:PHPhotoLibrary.sharedPhotoLibrary]; config.filter=[PHPickerFilter anyFilterMatchingSubfilters:@[PHPickerFilter.imagesFilter,PHPickerFilter.videosFilter]]; config.selectionLimit=1;
    PHPickerViewController *picker=[[PHPickerViewController alloc]initWithConfiguration:config]; picker.delegate=self; [self presentViewController:picker animated:YES completion:nil];
}
- (void)pickTendies {
    UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initWithDocumentTypes:@[@"public.archive",@"public.data"] inMode:UIDocumentPickerModeImport]; picker.delegate=self; picker.allowsMultipleSelection=NO; [self presentViewController:picker animated:YES completion:nil];
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil]; PHPickerResult *result=results.firstObject; if(!result)return; NSItemProvider *p=result.itemProvider;
    if([p canLoadObjectOfClass:UIImage.class]) [p loadObjectOfClass:UIImage.class completionHandler:^(UIImage *image,NSError *e){dispatch_async(dispatch_get_main_queue(),^{if(image)[self editImage:image];});}];
    else {
        NSString *type=[p hasItemConformingToTypeIdentifier:@"public.movie"]?@"public.movie":@"public.video";
        [p loadFileRepresentationForTypeIdentifier:type completionHandler:^(NSURL *url,NSError *e){if(!url)return; NSString *tmp=[NSTemporaryDirectory() stringByAppendingPathComponent:[PFNewIdentifier() stringByAppendingPathExtension:url.pathExtension ?: @"mov"]]; [[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:tmp] error:nil]; dispatch_async(dispatch_get_main_queue(),^{[self saveVideoAt:tmp];});}];
    }
}
- (void)editImage:(UIImage *)image {
    __weak typeof(self) weak=self; PFCropViewController *crop=[[PFCropViewController alloc]initWithImage:image completion:^(UIImage *output,BOOL blur){[weak saveImage:output blur:blur];}];
    UINavigationController *nav=[[UINavigationController alloc]initWithRootViewController:crop]; nav.modalPresentationStyle=UIModalPresentationFullScreen; [self presentViewController:nav animated:YES completion:nil];
}
- (NSString *)askTitleDefault:(NSString *)fallback { return fallback; }
- (void)saveImage:(UIImage *)image blur:(BOOL)blur {
    NSString *uuid=PFNewIdentifier(); NSString *dir=[PFLibraryDirectory stringByAppendingPathComponent:uuid]; [[NSFileManager defaultManager]createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *source=[dir stringByAppendingPathComponent:@"source.jpg"]; [UIImageJPEGRepresentation(image,0.94) writeToFile:source atomically:YES]; [self saveThumbnail:image directory:dir];
    NSDictionary *item=@{@"identifier":uuid,@"title":[NSString stringWithFormat:@"Photo %@",[uuid substringToIndex:4]],@"kind":@"image",@"sourcePath":source,@"thumbnailPath":[dir stringByAppendingPathComponent:@"thumbnail.jpg"],@"homeBlur":@(blur),@"created":NSDate.date,@"fps":@1}; [self finishItem:item];
}
- (void)saveVideoAt:(NSString *)temporary {
    AVURLAsset *asset=[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:temporary] options:nil]; double seconds=CMTimeGetSeconds(asset.duration);
    if(!isfinite(seconds)||seconds<=0){[self alert:@"The selected video cannot be read."];return;}
    if(seconds>27){[self alert:@"Videos are limited to roughly 27 seconds / 400 frames for PosterBoard stability. Trim this video first."];return;}
    NSString *uuid=PFNewIdentifier(); NSString *dir=[PFLibraryDirectory stringByAppendingPathComponent:uuid]; [[NSFileManager defaultManager]createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *source=[dir stringByAppendingPathComponent:[@"source" stringByAppendingPathExtension:temporary.pathExtension ?: @"mov"]]; [[NSFileManager defaultManager]moveItemAtPath:temporary toPath:source error:nil];
    AVAssetImageGenerator *gen=[[AVAssetImageGenerator alloc]initWithAsset:asset]; gen.appliesPreferredTrackTransform=YES; CGImageRef cg=[gen copyCGImageAtTime:kCMTimeZero actualTime:nil error:nil]; if(cg){[self saveThumbnail:[UIImage imageWithCGImage:cg] directory:dir];CGImageRelease(cg);}
    NSDictionary *item=@{@"identifier":uuid,@"title":[NSString stringWithFormat:@"Video %@",[uuid substringToIndex:4]],@"kind":@"video",@"sourcePath":source,@"thumbnailPath":[dir stringByAppendingPathComponent:@"thumbnail.jpg"],@"homeBlur":@NO,@"created":NSDate.date,@"fps":@15}; [self finishItem:item];
}
- (void)saveThumbnail:(UIImage *)image directory:(NSString *)dir { CGSize s=CGSizeMake(160,347); UIGraphicsImageRenderer *r=[[UIGraphicsImageRenderer alloc]initWithSize:s]; UIImage *thumb=[r imageWithActions:^(UIGraphicsImageRendererContext *c){CGFloat scale=MAX(s.width/image.size.width,s.height/image.size.height);CGSize d=CGSizeMake(image.size.width*scale,image.size.height*scale);[image drawInRect:CGRectMake((s.width-d.width)/2,(s.height-d.height)/2,d.width,d.height)];}];[UIImageJPEGRepresentation(thumb,0.8)writeToFile:[dir stringByAppendingPathComponent:@"thumbnail.jpg"] atomically:YES]; }
- (void)finishItem:(NSDictionary *)item {
    UIAlertController *name=[UIAlertController alertControllerWithTitle:@"Wallpaper name" message:@"This name is shown in PosterForge." preferredStyle:UIAlertControllerStyleAlert];
    [name addTextFieldWithConfigurationHandler:^(UITextField *field){field.text=item[@"title"];field.clearButtonMode=UITextFieldViewModeWhileEditing;}];
    [name addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a){[[NSFileManager defaultManager]removeItemAtPath:[PFLibraryDirectory stringByAppendingPathComponent:item[@"identifier"]] error:nil];}]];
    [name addAction:[UIAlertAction actionWithTitle:@"Add" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){NSMutableDictionary *named=item.mutableCopy;NSString *value=name.textFields.firstObject.text;if(value.length)named[@"title"]=value;NSError *e=nil;if(PFSaveItem(named,&e)&&PFQueueRequest(@{@"action":@"install",@"identifier":named[@"identifier"]},&e)){[self reload];[self alert:@"Wallpaper is being generated. It will appear in Add Wallpaper → Collections after PosterBoard refreshes."];}else [self alert:e.localizedDescription];}]];
    [self presentViewController:name animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url=urls.firstObject;if(!url)return; if(![url.pathExtension.lowercaseString isEqual:@"tendies"]){[self alert:@"Choose a .tendies package."];return;}
    NSString *copy=[PFRootDirectory stringByAppendingPathComponent:[PFNewIdentifier() stringByAppendingPathExtension:@"tendies"]]; NSError *e=nil;[[NSFileManager defaultManager]copyItemAtURL:url toURL:[NSURL fileURLWithPath:copy] error:&e]; if(!e)PFQueueRequest(@{@"action":@"tendies",@"path":copy},&e); [self alert:e?e.localizedDescription:@"Tendies package queued for import."];
}
- (void)alert:(NSString *)message { UIAlertController *a=[UIAlertController alertControllerWithTitle:@"PosterForge" message:message preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:a animated:YES completion:nil]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{return _items.count;}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{return 1;}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{return @"My wallpapers";}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{return @"Video is decoded on-device to a looping PosterBoard animation. Longer or high-frame-rate clips use substantial storage.";}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"wallpaper"];if(!cell)cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"wallpaper"];
    NSDictionary *item=_items[indexPath.row];cell.textLabel.text=item[@"title"];cell.detailTextLabel.text=[item[@"kind"] isEqual:@"video"]?@"Looping video • 15 fps":([item[@"homeBlur"]boolValue]?@"Photo • Home blur prepared":@"Photo");cell.imageView.image=[UIImage imageWithContentsOfFile:item[@"thumbnailPath"]];cell.imageView.layer.cornerRadius=8;cell.imageView.clipsToBounds=YES;cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {if(style!=UITableViewCellEditingStyleDelete)return;NSDictionary *item=_items[indexPath.row];PFDeleteItem(item[@"identifier"],nil);[self reload];}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath { [tableView deselectRowAtIndexPath:indexPath animated:YES]; NSDictionary *item=_items[indexPath.row]; UIImage *thumb=[UIImage imageWithContentsOfFile:item[@"thumbnailPath"]]; UIViewController *preview=[UIViewController new];preview.title=item[@"title"];preview.view.backgroundColor=UIColor.blackColor;UIImageView *iv=[[UIImageView alloc]initWithImage:thumb];iv.contentMode=UIViewContentModeScaleAspectFill;iv.clipsToBounds=YES;iv.translatesAutoresizingMaskIntoConstraints=NO;[preview.view addSubview:iv];[NSLayoutConstraint activateConstraints:@[[iv.centerXAnchor constraintEqualToAnchor:preview.view.centerXAnchor],[iv.centerYAnchor constraintEqualToAnchor:preview.view.centerYAnchor],[iv.widthAnchor constraintEqualToAnchor:preview.view.widthAnchor constant:-70],[iv.heightAnchor constraintEqualToAnchor:iv.widthAnchor multiplier:UIScreen.mainScreen.bounds.size.height/UIScreen.mainScreen.bounds.size.width]]];[self.navigationController pushViewController:preview animated:YES];}
@end
