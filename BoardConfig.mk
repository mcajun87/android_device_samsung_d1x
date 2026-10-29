#
# Copyright (C) 2026 The OrangeFox Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/samsung/d1x

# 引入公共树配置（必须放在最前面，以便下面覆盖它）
include device/samsung/exynos9820-common/BoardConfigCommon.mk

# 修正上游的拼写，与 crDroid 13 保持一致
TARGET_BOOTLOADER_BOARD_NAME := universal9825
TARGET_BOARD_PLATFORM := universal9825

# 屏幕状态栏高度（保留原版设定）
OF_STATUS_H := 90

# =========================================================
# 以下为追加的覆盖项，用于适配 fox_16.0 和 crDroid 13
# =========================================================

# 强制平台版本为 16（OrangeFox fox_16.0）
PLATFORM_VERSION := 16
PLATFORM_SECURITY_PATCH := 2099-12-31

# 明确预编译内核路径
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/Image
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
BOARD_INCLUDE_RECOVERY_DTBO := true

# 确保 boot header 版本为 1（d1x 必须）
BOARD_MKBOOTIMG_ARGS += --header_version 1

# 强制覆盖 retrofit 动态分区核心参数（防止公共树里没写对）
BOARD_SUPER_PARTITION_SIZE := 6480199680
BOARD_SUPER_PARTITION_METADATA_DEVICE := system
BOARD_SAMSUNG_DYNAMIC_PARTITIONS_SIZE := 6476005376
BOARD_USES_METADATA_PARTITION := true

# 必须开启 LZMA 压缩，否则内核+ramdisk 会超出 recovery 分区大小
LZMA_RAMDISK_TARGETS := recovery