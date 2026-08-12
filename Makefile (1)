ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TOOL_NAME = posterforged
posterforged_FILES = Daemon/main.m Shared/PFShared.m Daemon/PFPosterBuilder.m
posterforged_CFLAGS = -fobjc-arc
posterforged_FRAMEWORKS = Foundation UIKit AVFoundation CoreImage CoreGraphics
posterforged_CODESIGN_FLAGS = -Sentitlements.plist
posterforged_INSTALL_PATH = /usr/libexec
include $(THEOS_MAKE_PATH)/tool.mk

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	chmod 0755 $(THEOS_PROJECT_DIR)/layout/DEBIAN/postinst $(THEOS_PROJECT_DIR)/layout/DEBIAN/prerm

after-install::
	install.exec "launchctl kickstart -k system/com.posterforge.daemon || true; killall -9 Preferences PosterBoard 2>/dev/null || true"
