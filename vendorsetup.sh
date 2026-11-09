export FOX_BUILD_DEVICE=d1x
export FOX_VARIANT=A16
export FOX_TARGET_DEVICES=d1x,d1xks
export FOX_BUILD_TYPE=Unofficial
# OF_MAINTAINER 由 exynos9820-common/BoardConfigCommon.mk 统一提供，此处不再重复
# OF_USE_LZMA_COMPRESSION 与 LZMA_RAMDISK_TARGETS 均由 common 的
# BoardConfigCommon.mk 提供，此处不再重复（环境变量会被 makefile 同名赋值覆盖）

