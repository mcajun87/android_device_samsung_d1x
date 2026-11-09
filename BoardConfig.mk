#
# Copyright (C) 2026 The OrangeFox Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/samsung/d1x

# 公共树必须最先引入，下面的设备专属项才会覆盖它
include device/samsung/exynos9820-common/BoardConfigCommon.mk

# =========================================================
# d1x = Galaxy Note10 5G（SM-N971N）
# 注意：本机 SoC 是 Exynos 9825，不是 9820；common 树沿用
# exynos9820 家族命名（S10 = 9820 / Note10 = 9825 共用）
# =========================================================
TARGET_BOOTLOADER_BOARD_NAME := universal9825
TARGET_BOARD_PLATFORM := universal9825

# 屏幕 1080x2280，状态栏高度
OF_STATUS_H := 90

# =========================================================
# super 分区（retrofit 布局：元数据落在 system 上）
# 数值沿用原树，仅 super 镜像构建时才被消费；recovery 单镜像构建不依赖
# =========================================================
BOARD_SUPER_PARTITION_SIZE := 6480199680
BOARD_SUPER_PARTITION_METADATA_DEVICE := system

# =========================================================
# 以下全部由 exynos9820-common/BoardConfigCommon.mk 统一提供，此处不再重复：
#   内核与 dtb : TARGET_PREBUILT_KERNEL / BOARD_PREBUILT_DTBOIMAGE
#                BOARD_INCLUDE_RECOVERY_DTBO / BOARD_BOOTIMG_HEADER_VERSION
#                BOARD_BOOT_HEADER_VERSION / BOARD_MKBOOTIMG_ARGS
#   分区大小   : BOARD_RECOVERYIMAGE_PARTITION_SIZE / BOARD_DTBOIMG_PARTITION_SIZE
#   压缩       : LZMA_RAMDISK_TARGETS / OF_USE_LZMA_COMPRESSION
#   加密       : TW_INCLUDE_CRYPTO / *_FBE / TW_USE_FSCRYPT_POLICY
#   语言       : TW_DEFAULT_LANGUAGE=zh_CN / TW_EXTRA_LANGUAGES
#   其余       : BOARD_USES_METADATA_PARTITION / PLATFORM_SECURITY_PATCH
# 原先这里重复定义会造成"双份真相"，改一处漏一处。
# =========================================================
