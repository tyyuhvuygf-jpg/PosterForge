#import <Foundation/Foundation.h>
@interface PFPosterBuilder : NSObject
- (BOOL)installItem:(NSDictionary *)item error:(NSError **)error;
- (BOOL)removeIdentifier:(NSString *)identifier error:(NSError **)error;
- (BOOL)importTendiesAtPath:(NSString *)path error:(NSError **)error;
- (void)refreshPosterBoard;
@end
