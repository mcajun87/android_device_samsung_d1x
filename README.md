# OrangeFox Recovery device tree for the Samsung Galaxy Note10 5G (d1x)

| Device | Samsung Galaxy Note10 5G |
| :-- | :-- |
| Codename | d1x |
| Models | SM-N971N（韩版单卡，dtbo 内标识 `D1X KOR SINGLE`） |
| SoC | Exynos 9825（universal9825） |
| Display | 1080 × 2280 |
| Branch | fox_16.0（AOSP 16 底座，lunch 目标 `twrp_d1x-bp2a-eng`） |

Common tree: [android_device_samsung_exynos9820-common](https://github.com/mcajun87/android_device_samsung_exynos9820-common)

## 预编译内核与 dtbo

| 文件 | 大小 | sha256 |
| :-- | --: | :-- |
| `prebuilt/Image` | 49,455,128 | `8c4a3ca76afb333a9971f7b7ee048d920468d1f8063268112f8d5314e501a57d` |
| `prebuilt/dtbo.img` | 974,848 | `7496fa80666c656dea105a6e72782e05b8fd3998f042bed2489c8789b5ea254d` |

内核版本串（实测自 Image）：

    Linux version 4.14.357-openela-ga0e2ad468dd5
    #39 SMP PREEMPT Sun Oct 25 18:36:26 CST 2026
    来源：从 crDroid 17 官方 d1x recovery.img 中提取（该内核在本机实测可正常启动、
          可完成 /data 元数据解密）。自编内核（lineage-24.0 + patches/0003）仍在
          修三星专有驱动，暂不作为默认。

`dtbo.img` 与 crDroid 17 官方 d1x recovery 内嵌的 recovery_dtbo **前 974,848 字节完全一致**，
内含 5 个 DTB，首项为 `samsung,D1X KOR SINGLE 18` / `samsung,EXYNOS9825`。

## 内核源码与必需补丁

`prebuilt/Image` 由
[Rocky7842_android_kernel_samsung_exynos9820](https://github.com/mcajun87/Rocky7842_android_kernel_samsung_exynos9820)
（分支 `lineage-24.0`，clang r547379，`-Os`）编译，**必须同时带上 `patches/0003` 的两处修复**，
否则镜像能刷进去但进不了 recovery：

| 修复 | 不修的后果 |
| :-- | :-- |
| `gpu_dvfs_get_step()` NULL 保护 | 开机 `Kernel panic`，卡 SAMSUNG logo 无限重启 |
| `leds-s2mpb02.c` 恢复 `camera_class` | `/sys/class/camera/flash` 不存在，手电筒失效 |

详细取证与 patch 内容见 `patches/0003-kernel-gpu-dvfs-null-guard.md`。


## boot 头部 os_version 必须与 ROM 一致（解密关键）

S-Boot 会把 boot 镜像头部的 `os_version` 字段**直接交给 TEE 的 keymaster**
（`tz_init_bootloader_info`），`resetprop` 改属性完全无效。ROM 是 Android 17
而镜像头写 16 时，日志会是：

```
tz_init_bootloader_info:1066  os_version : 160000
swd_configure:106           invalid os_version or os_patchlevel
km_check_key_os_version_patchlevels  key_os_version(170000) > _os_version(160000)
-> I:Unable to decrypt metadata encryption -> /data 挂不上
```

本树通过 `BOARD_MKBOOTIMG_ARGS += --os_version 17 --os_patch_level 2026-10-01`
（追加在构建系统默认的 16 之后，mkbootimg 取最后一次的值）修正。

## 与其他 known-good 镜像的一致性（已实测比对）

以 crDroid 17（`crDroidAndroid-17.0-20261025-recovery.img`，67,633,152 字节）为标尺：

| 项目 | 参考镜像 | 本树配置 |
| :-- | :-- | :-- |
| boot header version | 1 | `BOARD_BOOTIMG_HEADER_VERSION ?= 1` / `BOARD_BOOT_HEADER_VERSION := 1` |
| page size | 2048 | `BOARD_KERNEL_PAGESIZE := 2048` |
| base / kernel offset | `0x10000000` / `0x8000` | 同 |
| ramdisk offset / tags offset | `0x01000000` / `0x100` | 同 |
| cmdline | `androidboot.super_partition=system` | `BOARD_KERNEL_CMDLINE ?= androidboot.super_partition=system` |
| 分区大小 | 67,633,152 | `BOARD_RECOVERYIMAGE_PARTITION_SIZE ?= 67633152` |
| AVB | 有 AVB footer；公钥 sha1 `2597c218aae470a130f61162feaae70afd97f011`、SHA256_RSA4096、rollback 1 @ 0、footer 1.0 | 同（`BOARD_AVB_*` 在 common 树） |

## 关键特性配置

| 特性 | 配置 | 说明 |
| :-- | :-- | :-- |
| 解密（FBE + metadata） | `TW_INCLUDE_CRYPTO` / `TW_INCLUDE_CRYPTO_FBE` / `TW_INCLUDE_FBE_METADATA_DECRYPT` / `TW_USE_FSCRYPT_POLICY := 2` | Keymaster 版本 `OF_DEFAULT_KEYMASTER_VERSION := 4.0`；解密失败可依次试 4.1 → `TW_FORCE_KEYMASTER_VER := true` → `OF_NO_KEYMASTER_VER_4X := 1` |
| 手电筒 | `OF_FLASHLIGHT_ENABLE := 1` + `OF_FL_PATH1 := /dev/fox_flash`（**目录**，不是节点） | rc 里建 `symlink /sys/class/camera/flash/rear_flash /dev/fox_flash/brightness`；内核的 `camera_class` 必须有效，见 `patches/0003` |
| 时区 | `OF_DEFAULT_TIMEZONE := CST-8` | OrangeFox 用 POSIX TZ 串（不是 `Asia/Shanghai`）；源码默认是中欧时间，不覆盖会变欧洲时区 |
| 语言 | `TW_DEFAULT_LANGUAGE := zh_CN` + `TW_EXTRA_LANGUAGES := true` | 默认简体中文；英文来自 `common/languages/en.xml`，繁体在 `extra-languages/` |
| 分辨率 | `OF_SCREEN_H := 2280` + `TW_THEME := portrait_hdpi` | OrangeFox 只读高度；默认值是 1920，必须覆盖 |

## Building

```sh
git clone https://gitlab.com/OrangeFox/sync.git
cd sync
./orangefox_sync.sh --branch 16.0 --path ~/fox_16.0   # 需要 sync 脚本 v030+

cd ~/fox_16.0
git clone -b fox_16.0 https://github.com/mcajun87/android_device_samsung_d1x device/samsung/d1x
git clone -b fox_16.0 https://github.com/mcajun87/android_device_samsung_exynos9820-common device/samsung/exynos9820-common

export FOX_BUILD_DEVICE=d1x
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch twrp_d1x-bp2a-eng

# A16 必须显式导出，否则 make 会回落到 trunk_staging 兜底值并报
# "release-config failed to run"
export TARGET_PRODUCT=twrp_d1x
export TARGET_RELEASE=bp2a
export TARGET_BUILD_VARIANT=eng

mka adbd recoveryimage
```

产物在 `out/target/product/d1x/`，其中 `recovery.img` 可打包成 Odin 可刷的 `.tar`。

## 已知问题

- 若在**不完整同步**的树里构建（`prebuilts/clang/host/linux-x86` 未成功 sync），
  该项目的上游 `Android.bp` 会缺失，导致形如
  `module libc missing dependencies: libunwind-exported` 或
  `missing and no known rule: libclang_rt.ubsan_minimal.a` 的报错。
  临时补丁见 `patches/`；根治办法是 `repo sync prebuilts/clang/host/linux-x86`。
