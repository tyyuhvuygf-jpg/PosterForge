#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
extern NSString * const PFRootDirectory;
extern NSString * const PFLibraryDirectory;
extern NSString * const PFRequestsDirectory;
extern NSString * const PFCompletedDirectory;
extern NSString * const PFReloadNotification;

FOUNDATION_EXPORT BOOL PFEnsureDirectories(NSError **error);
FOUNDATION_EXPORT NSString *PFNewIdentifier(void);
FOUNDATION_EXPORT NSArray<NSDictionary *> *PFLoadItems(void);
FOUNDATION_EXPORT BOOL PFSaveItem(NSDictionary *item, NSError **error);
FOUNDATION_EXPORT BOOL PFDeleteItem(NSString *identifier, NSError **error);
FOUNDATION_EXPORT BOOL PFQueueRequest(NSDictionary *request, NSError **error);
FOUNDATION_EXPORT NSString *PFPosterBoardContainer(void);
NS_ASSUME_NONNULL_END
