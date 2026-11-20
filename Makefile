TARGET := iphone:clang:latest:14.0
ARCHS = arm64
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = TradingView
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = TradingViewFix
TradingViewFix_FILES = Tweak.x
TradingViewFix_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
include $(THEOS_MAKE_PATH)/tweak.mk
