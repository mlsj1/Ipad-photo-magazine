#import "PhotoViewController.h"
#import "ImageScrollView.h"

@implementation PhotoViewController

#pragma mark - View loading and unloading

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Step 1: make the outer paging scroll view
    CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    self.pagingScrollView = [[UIScrollView alloc] initWithFrame:pagingScrollViewFrame];
    self.pagingScrollView.pagingEnabled = YES;
    self.pagingScrollView.backgroundColor = [UIColor blackColor];
    self.pagingScrollView.showsVerticalScrollIndicator = NO;
    self.pagingScrollView.showsHorizontalScrollIndicator = NO;
    self.pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
    self.pagingScrollView.delegate = self;
    self.view = self.pagingScrollView;
	
    // Step 2: prepare to tile content
    self.recycledPages = [[NSMutableSet alloc] init];
    self.visiblePages  = [[NSMutableSet alloc] init];
    [self tilePages];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.pagingScrollView = nil;
    self.recycledPages = nil;
    self.visiblePages = nil;
}

#pragma mark - Tiling and page configuration

- (void)tilePages {
    // Calculate which pages are visible
    CGRect visibleBounds = self.pagingScrollView.bounds;
    int firstNeededPageIndex = floorf(CGRectGetMinX(visibleBounds) / CGRectGetWidth(visibleBounds));
    int lastNeededPageIndex  = floorf((CGRectGetMaxX(visibleBounds)-1) / CGRectGetWidth(visibleBounds));
    firstNeededPageIndex = MAX(firstNeededPageIndex, 0);
    lastNeededPageIndex  = MIN(lastNeededPageIndex, [self imageCount] - 1);
    
    // Recycle no-longer-visible pages 
    for (ImageScrollView *page in self.visiblePages) {
        if (page.index < firstNeededPageIndex || page.index > lastNeededPageIndex) {
            [self.recycledPages addObject:page];
            [page removeFromSuperview];
        }
    }
    [self.visiblePages minusSet:self.recycledPages];
    
    // add missing pages
    for (int index = firstNeededPageIndex; index <= lastNeededPageIndex; index++) {
        if (![self isDisplayingPageForIndex:index]) {
            ImageScrollView *page = [self dequeueRecycledPage];
            if (page == nil) {
                page = [[ImageScrollView alloc] init];
            }
            [self configurePage:page forIndex:index];
            [self.pagingScrollView addSubview:page];
            [self.visiblePages addObject:page];
        }
    }    
}

- (ImageScrollView *)dequeueRecycledPage {
    ImageScrollView *page = [self.recycledPages anyObject];
    if (page) {
        [self.recycledPages removeObject:page];
    }
    return page;
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index {
    BOOL foundPage = NO;
    for (ImageScrollView *page in self.visiblePages) {
        if (page.index == index) {
            foundPage = YES;
            break;
        }
    }
    return foundPage;
}

- (void)configurePage:(ImageScrollView *)page forIndex:(NSUInteger)index {
    page.index = index;
    page.frame = [self frameForPageAtIndex:index];
    
    // Use tiled images
    //[page displayTiledImageNamed:[self imageNameAtIndex:index] size:[self imageSizeAtIndex:index]];
    
    // use full images 
	[page displayImage:[self imageAtIndex:index]];
}

#pragma mark - ScrollView delegate methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self tilePages];
}

#pragma mark - View controller rotation methods

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    // Store current state before rotation
    CGFloat offset = self.pagingScrollView.contentOffset.x;
    CGFloat pageWidth = self.pagingScrollView.bounds.size.width;
    
    if (offset >= 0) {
        self.firstVisiblePageIndexBeforeRotation = floorf(offset / pageWidth);
        self.percentScrolledIntoFirstVisiblePage = (offset - (self.firstVisiblePageIndexBeforeRotation * pageWidth)) / pageWidth;
    } else {
        self.firstVisiblePageIndexBeforeRotation = 0;
        self.percentScrolledIntoFirstVisiblePage = offset / pageWidth;
    }
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // Update during rotation animation
        self.pagingScrollView.frame = [self frameForPagingScrollView];
        self.pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
        
        // adjust frames and configuration of each visible page
        for (ImageScrollView *page in self.visiblePages) {
            CGPoint restorePoint = [page pointToCenterAfterRotation];
            CGFloat restoreScale = [page scaleToRestoreAfterRotation];
            page.frame = [self frameForPageAtIndex:page.index];
            [page setMaxMinZoomScalesForCurrentBounds];
            [page restoreCenterPoint:restorePoint scale:restoreScale];
        }
        
        // adjust contentOffset to preserve page location
        CGFloat newPageWidth = size.width;
        CGFloat newOffset = (self.firstVisiblePageIndexBeforeRotation * newPageWidth) + (self.percentScrolledIntoFirstVisiblePage * newPageWidth);
        self.pagingScrollView.contentOffset = CGPointMake(newOffset, 0);
        
    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        // Ensure everything is properly laid out after rotation
        [self tilePages];
    }];
}

#pragma mark - Frame calculations
#define PADDING  0

- (CGRect)frameForPagingScrollView {
    CGRect frame = [[UIScreen mainScreen] bounds];
  //refactored to remove padding
    //  frame.origin.x -= PADDING;
  //  frame.size.width += (2 * PADDING);
    return frame;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index {
    // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
    // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
    // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
    // because it has a rotation transform applied.
    CGRect bounds = self.pagingScrollView.bounds;
    CGRect pageFrame = bounds;
   // pageFrame.size.width -= (2 * PADDING);
    pageFrame.origin.x = (bounds.size.width * index); // + PADDING;
    return pageFrame;
}

- (CGSize)contentSizeForPagingScrollView {
    // We have to use the paging scroll view's bounds to calculate the contentSize, for the same reason outlined above.
    CGRect bounds = self.pagingScrollView.bounds;
    return CGSizeMake(bounds.size.width * [self imageCount], bounds.size.height);
}

#pragma mark - Image wrangling

- (NSArray *)imageData {
    static NSArray *__imageData = nil; // only load the imageData array once
    if (__imageData == nil) {
        // read the filenames/sizes out of a plist in the app bundle
        NSString *path = [[NSBundle mainBundle] pathForResource:@"ImageData" ofType:@"plist"];
        __imageData = [NSArray arrayWithContentsOfFile:path];
        if (!__imageData) {
            NSLog(@"Failed to read image names from: %@", path);
        }
    }
    return __imageData;
}

- (UIImage *)imageAtIndex:(NSUInteger)index {
    // use "imageWithContentsOfFile:" instead of "imageNamed:" here to avoid caching our images
    NSString *imageName = [self imageNameAtIndex:index];
    NSString *path = [[NSBundle mainBundle] pathForResource:imageName ofType:@"jpg"];
    return [UIImage imageWithContentsOfFile:path];    
}

- (NSString *)imageNameAtIndex:(NSUInteger)index {
    NSString *name = nil;
    if (index < [self imageCount]) {
        NSDictionary *data = [[self imageData] objectAtIndex:index];
        name = [data valueForKey:@"name"];
    }
    return name;
}

- (CGSize)imageSizeAtIndex:(NSUInteger)index {
    CGSize size = CGSizeZero;
    if (index < [self imageCount]) {
        NSDictionary *data = [[self imageData] objectAtIndex:index];
        size.width = [[data valueForKey:@"width"] floatValue];
        size.height = [[data valueForKey:@"height"] floatValue];
    }
    return size;
}

- (NSUInteger)imageCount {
    static NSUInteger __count = NSNotFound;  // only count the images once
    if (__count == NSNotFound) {
        __count = [[self imageData] count];
    }
    return __count;
}

@end
