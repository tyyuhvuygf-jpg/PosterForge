#import <UIKit/UIKit.h>
@interface PFCropViewController : UIViewController
- (instancetype)initWithImage:(UIImage *)image completion:(void (^)(UIImage *cropped, BOOL homeBlur))completion;
@end
