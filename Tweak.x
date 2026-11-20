#import <UIKit/UIKit.h>

static const CGFloat kMaxTop = 20.0;

static void TVLog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1,2);
static void TVLog(NSString *fmt, ...) {
    static NSMutableSet *seen;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seen = [NSMutableSet set]; });
    va_list ap;
    va_start(ap, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    @synchronized(seen) {
        if ([seen containsObject:line] || seen.count > 300) return;
        [seen addObject:line];
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tvfix.log"];
    NSString *out = [line stringByAppendingString:@"\n"];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [out writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [fh seekToEndOfFile];
    [fh writeData:[out dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

static inline UIEdgeInsets ClampInsets(UIEdgeInsets i) {
    if (i.top > kMaxTop) i.top = kMaxTop;
    return i;
}

%group TV

%hook UIView
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets o = %orig;
    if (o.top > kMaxTop) TVLog(@"UIView.safeAreaInsets %@ top=%.1f", NSStringFromClass([self class]), o.top);
    return ClampInsets(o);
}
%end

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets o = %orig;
    if (o.top > kMaxTop) TVLog(@"UIWindow.safeAreaInsets top=%.1f", o.top);
    return ClampInsets(o);
}
%end

%hook UIStatusBarManager
- (CGRect)statusBarFrame {
    CGRect r = %orig;
    if (r.size.height > kMaxTop) {
        TVLog(@"UIStatusBarManager.statusBarFrame h=%.1f", r.size.height);
        r.size.height = kMaxTop;
    }
    return r;
}
%end

%hook UIApplication
- (CGRect)statusBarFrame {
    CGRect r = %orig;
    if (r.size.height > kMaxTop) {
        TVLog(@"UIApplication.statusBarFrame h=%.1f", r.size.height);
        r.size.height = kMaxTop;
    }
    return r;
}
%end

%hook UIScrollView
- (UIEdgeInsets)adjustedContentInset {
    UIEdgeInsets o = %orig;
    if (o.top > kMaxTop) TVLog(@"UIScrollView.adjustedContentInset %@ top=%.1f", NSStringFromClass([self class]), o.top);
    return o;
}
%end

%end

%ctor {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        NSString *exe = [[[NSBundle mainBundle] executablePath] lastPathComponent] ?: @"";
        if ([bid rangeOfString:@"tradingview" options:NSCaseInsensitiveSearch].location == NSNotFound &&
            [exe rangeOfString:@"tradingview" options:NSCaseInsensitiveSearch].location == NSNotFound) return;
        TVLog(@"loaded bid=%@ exe=%@ os=%@", bid, exe, [UIDevice currentDevice].systemVersion);
        %init(TV);
    }
}
