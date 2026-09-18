TARGET := appletv:clang:latest:17.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := infuse

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := InfuseSecurityTest

InfuseSecurityTest_FILES := InfuseBypass/InfuseBypass.mm
InfuseSecurityTest_USE_MODULES := 0
InfuseSecurityTest_CFLAGS := -fobjc-arc -Wno-deprecated-declarations
InfuseSecurityTest_FRAMEWORKS := Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
