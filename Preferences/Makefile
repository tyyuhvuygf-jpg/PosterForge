include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = PosterForgePrefs
PosterForgePrefs_FILES = PFRootListController.m PFCropViewController.m ../Shared/PFShared.m
PosterForgePrefs_FRAMEWORKS = UIKit Photos PhotosUI AVFoundation CoreImage CoreGraphics UniformTypeIdentifiers
PosterForgePrefs_INSTALL_PATH = /Library/PreferenceBundles
PosterForgePrefs_CFLAGS = -fobjc-arc
PosterForgePrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
