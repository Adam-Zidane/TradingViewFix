#import <UIKit/UIKit.h>

// ===== Pengaturan (ubah angka kalau perlu) =====
static const CGFloat kMaxTop = 12.0;     // gap atas (header naik kalau makin kecil)
static const CGFloat kMaxBottom = 0.0;   // gap bawah
static const CGFloat kMenuScale = 0.85;  // ukuran menu bawah (1.0 = normal)
// ===============================================

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
    if (i.bottom > kMaxBottom) i.bottom = kMaxBottom;
    return i;
}

static __weak UIView *gPill;

// Cari "pil" menu bawah: view terluar yang ukurannya seperti pil, di atas label "Watchlist"
static UIView *TVFindPill(UIView *root, CGFloat W, int depth) {
    if (depth > 30) return nil;
    if ([root isKindOfClass:[UILabel class]] &&
        [((UILabel *)root).text isEqualToString:@"Watchlist"]) {
        UIView *best = nil;
        UIView *v = root;
        while (v && ![v isKindOfClass:[UIWindow class]]) {
            CGSize sz = v.bounds.size;
            if (sz.width >= W * 0.6 && sz.width <= W * 0.95 && sz.height >= 44 && sz.height <= 110) {
                best = v;
            } else if (sz.width > W * 0.95 || sz.height > 110) {
                if (best) break;
            }
            v = v.superview;
        }
        return best;
    }
    for (UIView *s in root.subviews) {
        UIView *r = TVFindPill(s, W, depth + 1);
        if (r) return r;
    }
    return nil;
}

static void TVApplyMenu(void) {
    if (kMenuScale >= 0.999) return;
    UIWindow *win = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (!w.hidden && w.isKeyWindow) win = w;
    }
    if (!win) return;
    if (!gPill || gPill.window == nil) {
        gPill = TVFindPill(win, win.bounds.size.width, 0);
        if (gPill) TVLog(@"pill found %@ %.0fx%.0f", NSStringFromClass([gPill class]),
                         gPill.bounds.size.width, gPill.bounds.size.height);
    }
    if (!gPill) return;
    CGFloat s = kMenuScale;
    CGFloat h = gPill.bounds.size.height;
    CGAffineTransform t = CGAffineTransformMakeTranslation(0, h * (1.0 - s) / 2.0);
    t = CGAffineTransformScale(t, s, s);
    if (!CGAffineTransformEqualToTransform(gPill.transform, t)) gPill.transform = t;
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
    return ClampInsets(%orig);
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
            static NSTimer *timer;
            if (!timer) {
                timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
                    TVApplyMenu();
                }];
            }
        }];
    }
}
