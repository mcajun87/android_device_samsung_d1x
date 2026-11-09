#
# Copyright (C) 2026 The OrangeFox Recovery Project
#
# SPDX-License-Identifier: Apache-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, device/samsung/d1x/device.mk)

PRODUCT_DEVICE := d1x
PRODUCT_NAME := twrp_d1x
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-N971N
PRODUCT_MANUFACTURER := samsung

# 让刷机包校验设备代号（与 vendorsetup.sh 的 FOX_TARGET_DEVICES 保持一致）
TARGET_OTA_ASSERT_DEVICE := d1x,d1xks
