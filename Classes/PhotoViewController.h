#import <UIKit/UIKit.h>

@class ImageScrollView;

@interface PhotoViewController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, strong) UIScrollView *pagingScrollView;
@property (nonatomic, strong) NSMutableSet *recycledPages;
@property (nonatomic, strong) NSMutableSet *visiblePages;

// these values are stored off before we start rotation so we adjust our content offset appropriately during rotation
@property (nonatomic, assign) int firstVisiblePageIndexBeforeRotation;
@property (nonatomic, assign) CGFloat percentScrolledIntoFirstVisiblePage;

- (void)configurePage:(ImageScrollView *)page forIndex:(NSUInteger)index;
- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;

- (CGRect)frameForPagingScrollView;
- (CGRect)frameForPageAtIndex:(NSUInteger)index;
- (CGSize)contentSizeForPagingScrollView;

- (void)tilePages;
- (ImageScrollView *)dequeueRecycledPage;

- (NSUInteger)imageCount;
- (NSString *)imageNameAtIndex:(NSUInteger)index;
- (CGSize)imageSizeAtIndex:(NSUInteger)index;
- (UIImage *)imageAtIndex:(NSUInteger)index;

@end

