#import "PFCropViewController.h"

@interface PFCropViewController () <UIScrollViewDelegate>
@property UIImage *image;
@property UIScrollView *scroll;
@property UIImageView *imageView;
@property UIView *frameView;
@property UISwitch *blurSwitch;
@property (copy) void (^completion)(UIImage *, BOOL);
@property BOOL zoomConfigured;
@end

@implementation PFCropViewController
- (instancetype)initWithImage:(UIImage *)image completion:(void (^)(UIImage *, BOOL))completion {
    if((self=[super init])){_image=[self normalized:image];_completion=[completion copy];self.title=@"Frame wallpaper";} return self;
}
- (UIImage *)normalized:(UIImage *)image {
    if(image.imageOrientation==UIImageOrientationUp && image.scale==1)return image;
    CGSize pixels=CGSizeMake(CGImageGetWidth(image.CGImage),CGImageGetHeight(image.CGImage)); UIGraphicsImageRendererFormat *format=[UIGraphicsImageRendererFormat defaultFormat];format.scale=1;
    UIGraphicsImageRenderer *r=[[UIGraphicsImageRenderer alloc]initWithSize:pixels format:format];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *c){[image drawInRect:(CGRect){CGPointZero,pixels}];}];
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=UIColor.blackColor;
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    _scroll=[UIScrollView new]; _scroll.delegate=self; _scroll.maximumZoomScale=8; _scroll.bouncesZoom=YES; _scroll.clipsToBounds=YES; _scroll.translatesAutoresizingMaskIntoConstraints=NO;
    _imageView=[[UIImageView alloc]initWithImage:_image]; _imageView.frame=(CGRect){CGPointZero,_image.size}; [_scroll addSubview:_imageView]; _scroll.contentSize=_image.size; [self.view addSubview:_scroll];
    UIStackView *options=[[UIStackView alloc]init]; options.axis=UILayoutConstraintAxisHorizontal; options.spacing=10; options.alignment=UIStackViewAlignmentCenter; options.translatesAutoresizingMaskIntoConstraints=NO;
    UILabel *label=[UILabel new]; label.text=@"Blur Home Screen"; label.textColor=UIColor.whiteColor; _blurSwitch=[UISwitch new]; _blurSwitch.on=YES; [options addArrangedSubview:label]; [options addArrangedSubview:_blurSwitch]; [self.view addSubview:options];
    UILabel *help=[UILabel new]; help.text=@"Pinch to zoom • drag to position"; help.textColor=UIColor.secondaryLabelColor; help.font=[UIFont systemFontOfSize:13]; help.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:help];
    CGFloat ratio=UIScreen.mainScreen.bounds.size.width/UIScreen.mainScreen.bounds.size.height;
    [NSLayoutConstraint activateConstraints:@[
        [_scroll.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[_scroll.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-22],
        [_scroll.widthAnchor constraintEqualToAnchor:self.view.widthAnchor constant:-48],[_scroll.heightAnchor constraintEqualToAnchor:_scroll.widthAnchor multiplier:1.0/ratio],
        [options.topAnchor constraintEqualToAnchor:_scroll.bottomAnchor constant:18],[options.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [help.topAnchor constraintEqualToAnchor:options.bottomAnchor constant:8],[help.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; if(_zoomConfigured)return; _zoomConfigured=YES;
    CGFloat min=MAX(_scroll.bounds.size.width/_image.size.width,_scroll.bounds.size.height/_image.size.height); _scroll.minimumZoomScale=min; _scroll.zoomScale=min;
    _scroll.contentOffset=CGPointMake((_image.size.width*min-_scroll.bounds.size.width)/2,(_image.size.height*min-_scroll.bounds.size.height)/2);
}
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView{return _imageView;}
- (void)cancel{[self dismissViewControllerAnimated:YES completion:nil];}
- (void)done {
    CGFloat z=_scroll.zoomScale; CGRect visible=CGRectMake(_scroll.contentOffset.x/z,_scroll.contentOffset.y/z,_scroll.bounds.size.width/z,_scroll.bounds.size.height/z);
    visible=CGRectIntersection(visible,(CGRect){CGPointZero,_image.size}); CGImageRef cg=CGImageCreateWithImageInRect(_image.CGImage,visible); UIImage *crop=[UIImage imageWithCGImage:cg]; CGImageRelease(cg);
    CGSize target=UIScreen.mainScreen.nativeBounds.size; if(target.width>target.height)target=CGSizeMake(target.height,target.width);
    UIGraphicsImageRendererFormat *fmt=[UIGraphicsImageRendererFormat defaultFormat]; fmt.scale=1;
    UIImage *output=[[[UIGraphicsImageRenderer alloc]initWithSize:target format:fmt] imageWithActions:^(UIGraphicsImageRendererContext *c){[crop drawInRect:(CGRect){CGPointZero,target}];}];
    if(_completion)_completion(output,_blurSwitch.on); [self dismissViewControllerAnimated:YES completion:nil];
}
@end
