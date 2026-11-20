#import <UIKit/UIKit.h>

static const CGFloat kMaxTop = 16.0;
static const CGFloat kMaxBottom = 8.0;

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
        if ([seen containsObject:line] || seen.count > 600) return;
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
    if (i.bottom > kMaxBottom) i.bottom = kMaxBottom;
    return i;
}

static void TVWalk(UIView *v, int depth, CGFloat H) {
    if (depth > 8) return;
    CGRect f = [v convertRect:v.bounds toView:nil];
    if (CGRectGetMaxY(f) > H * 0.78 && f.size.height < H * 0.3 && f.size.height > 1) {
        TVLog(@"VIEW d%d %@ y=%.0f h=%.0f w=%.0f", depth, NSStringFromClass([v class]), f.origin.y, f.size.height, f.size.width);
    }
    for (UIView *s in v.subviews) TVWalk(s, depth + 1, H);
}

static void TVDump(void) {
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.hidden) continue;
        TVLog(@"WINDOW %@ h=%.0f", NSStringFromClass([w class]), w.bounds.size.height);
        TVWalk(w, 0, w.bounds.size.height);
    }
}

%group TV

%hook UIView
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets o = %orig;
    if (o.top > kMaxTop || o.bottom > kMaxBottom)
        TVLog(@"UIView.safeAreaInsets %@ top=%.1f bottom=%.1f", NSStringFromClass([self class]), o.top, o.bottom);
    return ClampInsets(o);
}
%end

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets o = %orig;
    if (o.top > kMaxTop || o.bottom > kMaxBottom)
        TVLog(@"UIWindow.safeAreaInsets top=%.1f bottom=%.1f", o.top, o.bottom);
    return ClampInsets(o);
}
%end

%hook UIStatusBarManager
- (CGRect)statusBarFrame {
    CGRect r = %orig;
    if (r.size.height > kMaxTop) r.size.height = kMaxTop;
    return r;
}
%end

%hook UIApplication
- (CGRect)statusBarFrame {
    CGRect r = %orig;
    if (r.size.height > kMaxTop) r.size.height = kMaxTop;
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
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *n) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ TVDump(); });
        }];
    }
}
