#import <UIKit/UIKit.h>
static const CGFloat kMaxTop = 20.0;
static inline UIEdgeInsets ClampInsets(UIEdgeInsets i) {
    if (i.top > kMaxTop) i.top = kMaxTop;
    return i;
}
%hook UIView
- (UIEdgeInsets)safeAreaInsets { return ClampInsets(%orig); }
%end
%hook UIWindow
- (UIEdgeInsets)safeAreaInsets { return ClampInsets(%orig); }
%end
%hook UIApplication
- (CGRect)statusBarFrame {
    CGRect r = %orig;
    if (r.size.height > kMaxTop) r.size.height = kMaxTop;
    return r;
}
%end
