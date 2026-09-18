TARGET := appletv:clang:latest:17.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := infuse

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := InfuseBypassAppleTV

InfuseBypassAppleTV_FILES := InfuseBypass/InfuseBypass.mm
InfuseBypassAppleTV_USE_MODULES := 0
InfuseBypassAppleTV_CFLAGS := -fobjc-arc -Wno-deprecated-declarations
InfuseBypassAppleTV_FRAMEWORKS := Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
