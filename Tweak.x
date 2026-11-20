#import <UIKit/UIKit.h>

// ===== Pengaturan (ubah angka kalau perlu) =====
static const CGFloat kMaxTop = 0.0;       // gap atas: 0 = full
static const CGFloat kMaxBottom = 0.0;    // gap bawah: 0 = full
static const CGFloat kMenuScale = 0.85;   // ukuran menu bawah (1.0 = normal)
static const CGFloat kMenuDown = 4.0;     // turunkan menu (pt)
static const BOOL kHideTabBlur = YES;     // hilangkan strip blur di belakang menu
static const BOOL kHideStatusBar = YES;   // sembunyikan status bar di TradingView
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

%group TV

%hook UIView
- (UIEdgeInsets)safeAreaInsets {
    return ClampInsets(%orig);
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

%hook UIViewController
- (BOOL)prefersStatusBarHidden {
    return kHideStatusBar ? YES : %orig;
}
%end

%hook UITabBar

// UITabBarController mengatur frame; kembalikan transform sebentar supaya frame tidak kacau
- (void)setFrame:(CGRect)frame {
    CGAffineTransform t = self.transform;
    self.transform = CGAffineTransformIdentity;
    %orig(frame);
    self.transform = t;
}

- (void)layoutSubviews {
    %orig;
    CGFloat s = kMenuScale;
    CGFloat h = self.bounds.size.height;
    if (h < 1) return;
    CGAffineTransform t = CGAffineTransformMakeTranslation(0, h * (1.0 - s) / 2.0 + kMenuDown);
    t = CGAffineTransformScale(t, s, s);
    if (!CGAffineTransformEqualToTransform(self.transform, t)) {
        self.transform = t;
        TVLog(@"tabbar transform applied h=%.0f scale=%.2f", h, s);
    }
    if (kHideTabBlur) {
        for (UIView *sib in self.superview.subviews) {
            if (sib != self && [NSStringFromClass([sib class]) isEqualToString:@"TVBlurEffectView"]) {
                sib.alpha = 0.0;
            }
        }
    }
}
%end

%end

%ctor {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        if (![bid isEqualToString:@"com.tradingview.tradingviewapp"]) return;
        TVLog(@"loaded bid=%@ os=%@", bid, [UIDevice currentDevice].systemVersion);
        %init(TV);
    }
}
