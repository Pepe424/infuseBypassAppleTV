TARGET := appletv:clang:latest:17.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := InfuseAttackSimulation

InfuseAttackSimulation_FILES := InfuseAttackSimulation.mm
InfuseAttackSimulation_USE_MODULES := 0
InfuseAttackSimulation_CFLAGS := -fobjc-arc -Wno-deprecated-declarations
InfuseAttackSimulation_FRAMEWORKS := Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
