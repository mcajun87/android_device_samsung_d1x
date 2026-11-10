# OrangeFox Recovery R12.0 — Samsung Galaxy Note10 5G (d1x)

| 项目 | 值 |
| :-- | :-- |
| 机型 | Samsung Galaxy Note10 5G（韩版 SM-N971N） |
| 代号 | `d1x`（ROM 指纹里也会出现 `d1xks`） |
| SoC | Exynos 9825（`universal9825` / `exynos9825`） |
| 屏幕 | 1080 × 2280 |
| 分支 | `fox_16.0`（AOSP 16 底座） |
| lunch 目标 | `twrp_d1x-bp2a-eng` |

> **本仓库只维护 d1x 一个型号。** 其他三星机型（beyond0lte / beyond1lte /
> beyond2lte / beyondx / d1 / d2s / d2x / f62 等）不在维护范围内，
> 相关配置与文档已全部移除。

公共配置树：[android_device_samsung_exynos9820-common](https://github.com/mcajun87/android_device_samsung_exynos9820-common)

---

## 当前状态（2026-11-10 真机实测通过）

| 功能 | 状态 | 备注 |
| :-- | :-- | :-- |
| 开机进入 OrangeFox | ✅ | 连续多次冷启动验证 |
| 界面 / 分辨率 | ✅ | 1080×2280 正确铺满 |
| 默认语言 | ✅ | 简体中文；可切繁体中文 / English |
| 时区 | ✅ | 默认 `CST-8`（北京时间） |
| 手电筒 | ✅ | 240 mA 工厂手电档 |
| `/data` 解密 | ✅ | 元数据加密，**无需输入密码**，开机自动挂载 |
| MTP（电脑访问存储） | ✅ | 随 `/data` 自动可用 |
| 刷入 zip / 备份 | ✅ | `magiskboot`、`unzip`、`make_f2fs` 等工具齐备 |
| AVB 签名 | ✅ | 与官方镜像同构（SHA256_RSA4096 / testkey_rsa4096） |
| 电量显示 | ⚠️ | 见下方「电量」一节（自换电芯，属硬件标定问题） |

### 已知的"看着像故障其实是正常"

| 现象 | 真相 |
| :-- | :-- |
| 进 recovery 后黑屏，按一下电源键才亮 | TWRP 把**电源键当屏幕开关**。开机时看到 OrangeFox 图标就松开电源键，之后别按它。放着 60 秒不动也会自动关屏（`tw_screen_timeout_secs` 默认 60） |
| 电量显示 0% | 见下方 |

---

## 关键事实（改动前必读）

| 项目 | 值 / 结论 |
| :-- | :-- |
| `prebuilt/Image` | 49,455,128 B，sha256 `8c4a3ca76afb333a9971f7b7ee048d920468d1f8063268112f8d5314e501a57d`<br>来源：crDroid 17 官方 d1x recovery 里的内核 `4.14.357-openela-ga0e2ad468dd5`（实测可启动、可解密） |
| `prebuilt/dtbo.img` | 974,848 B，sha256 `7496fa80666c656dea105a6e72782e05b8fd3998f042bed2489c8789b5ea254d`<br>与 crDroid 官方 recovery 内嵌的 `recovery_dtbo` 逐字节一致 |
| recovery 分区 | **67,633,152 B**（所有体积计算的天花板） |
| boot 头部 | header v1 / page 2048 / base `0x10000000` / kernel `+0x8000` / ramdisk `+0x01000000` / tags `+0x100` |
| **boot 头部 os_version** | **必须是 17（patch 2026-10-01）**，否则 TEE keymaster 拒绝解封 `/data` 的元数据密钥 → `/data` 与 MTP 全废。详见公共树 README |
| ramdisk 压缩 | 构建系统固定 `lzma -6`（≈18.45 MB），**必须用 `-9` 重压（≈16.60 MB）才塞得下** |
| 手电筒节点 | 用三星私有 `/sys/class/camera/flash/rear_flash`（写入 `100`），**不能用** `/sys/class/leds/torch-sec1`（写了不亮） |

### 体积预算

```
2048(页) + 49,455,128(内核) + 16,599,792(ramdisk, lzma -9) + 974,848(dtbo) = 67,031,816
上限 67,633,152 - 69,632(AVB footer) = 67,563,520    余量 531,704
```

---

## 构建

### 为什么不能只跑 `mka recoveryimage`

构建系统给 recovery ramdisk 固定用 `lzma -f -c`（预设 6），产出约 18.45 MB；
加上 49.46 MB 的内核会超出分区，构建在最后一步失败：

```
error: +.../recovery.img too large (68229120 > 67563520)
```

**但此时 `ramdisk-recovery.img` 已经生成好了。** 所以本仓库提供
[`tools/make_recovery_image.sh`](tools/make_recovery_image.sh) 完成收尾：

1. 解出 ramdisk 的 cpio，用 `lzma -9` 重压（18.45 MB → 16.60 MB）
2. 自己调 `mkbootimg`，把 boot 头部 `os_version` 写成 **17**（解密必需）
3. 用 `avbtool` 重新做 AVB 签名（`testkey_rsa4096`，rollback 1 @ 0）
4. 校验尺寸 / 头部版本 / 内核哈希 / AVB 尾部魔数，产出 `dist/`

### 命令

```sh
cd ~/fox
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_BUILD_DEVICE=d1x
set +u
source build/envsetup.sh
lunch twrp_d1x-bp2a-eng
set -u
# lunch 之后必须再导出一次，否则 release_config 找不到 bp2a 会
# panic: Missing config trunk_staging
export TARGET_PRODUCT=twrp_d1x TARGET_RELEASE=bp2a TARGET_BUILD_VARIANT=eng

# 1) 生成 ramdisk（末尾的尺寸检查失败是预期行为）
mka adbd recoveryimage -j4

# 2) 重压 + 重打包 + 签名 + 校验
device/samsung/d1x/tools/make_recovery_image.sh ~/fox
```

产物：`out/target/product/d1x/dist/`（`recovery.img`、`recovery.tar`、校验和）

### 构建环境坑位

| 现象 | 原因 / 处理 |
| :-- | :-- |
| `panic: Missing config trunk_staging` | `lunch` 后没显式 `export TARGET_RELEASE=bp2a` |
| `missing and no known rule: libclang_rt.ubsan_minimal.a` | `prebuilts/clang/host/linux-x86` 缺上游完整的 49 模块 `Android.bp` + `soong/` 插件 |
| ramdisk 里混进旧文件 | `out/target/product/d1x/recovery/root` 只增不减，改动 ramdisk 内容后要先把它移走 |
| 换了 `prebuilt/Image` 却没用上 | `cp -a` 会保留旧 mtime，ninja 认为没变；用 `cp -f` 并 `touch` |
| 一次构建约 33–50 分钟 | soong 分析阶段常驻内存可达 10.4 GB，本机 11.9 GB 内存下明显受 GC 影响 |

---

## 刷入（三星必须这样做）

1. Odin → `Options` → **取消勾选 `Auto Reboot`**
2. `AP` 槽选 `recovery.tar` → Start，等 **PASS**
3. 手机立即按住 `音量+` + `电源` + `Bixby`
4. **看到 OrangeFox 图标就松开电源键**（只留音量+），否则电源键会把屏幕关掉

> 三星有 recovery-from-boot 机制：只要系统成功启动过一次，刷进去的 recovery
> 就会被 ROM 还原。所以第 3 步必须抓住。

---

## 内核说明

`prebuilt/Image` 目前用的是 **crDroid 17 官方 d1x recovery 里的内核**
（`4.14.357-openela-ga0e2ad468dd5`），因为它在本机实测能正常启动并完成解密。

自编内核（[Rocky7842_android_kernel_samsung_exynos9820](https://github.com/mcajun87/Rocky7842_android_kernel_samsung_exynos9820)
`lineage-24.0`）已经修掉两个会让设备完全起不来的问题，但尚未真机验证通过：

| 补丁 | 问题 |
| :-- | :-- |
| `gpu_dvfs_get_step()` NULL 保护 | `exynos_gpu_cooling_init()` 早于 Mali probe 执行 → `Kernel panic`，卡 SAMSUNG logo |
| `leds-s2mpb02.c` 恢复 `camera_class` | `/sys/class/camera/flash` 节点不生成 → 手电筒失效 |

完整取证与 diff 见 [`patches/0003-kernel-gpu-dvfs-null-guard.md`](patches/0003-kernel-gpu-dvfs-null-guard.md)。

---

## CI

`.github/workflows/recovery-build.yml`：**self-hosted runner** 专用。
它执行的正是上面的两步流程（`mka adbd recoveryimage` + `tools/make_recovery_image.sh`），
并在构建前核对 `--os_version 17` 与 `max_brightness 100` 是否在位。

> 云端 runner 不可用：AOSP 16 完整 `repo sync` 超过 100 GB，GitHub 托管 runner
> 的磁盘装不下。原先的 `fox16.0.yml`（云端全量构建）与 `publish-bundle.yml`
> （依赖"内核单独发 Release"）都已删除，避免误用。
