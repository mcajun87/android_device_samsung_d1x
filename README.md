# OrangeFox Recovery device tree for the Samsung Galaxy Note10 5G (d1x)

**[🇨🇳 中文说明](#-中文说明) | [🇺🇸 English Version](#-english-version)**

---

## 🇨🇳 中文说明

本仓库为三星 Galaxy Note10 5G (SM-N971N，代号 d1x) 的 OrangeFox Recovery 设备树。

| 设备 | Samsung Galaxy Note10 5G |
| :-- | :-- |
| 代号 | d1x |
| 型号 | SM-N971N |
| 处理器 (SoC) | Exynos 9825 |

### 📜 项目来源与声明

*   **原始出处**: 本设备树基于 [Exynos982x-OrangeFox](https://github.com/Exynos982x-OrangeFox/android_device_samsung_d1x) 官方仓库修改而来。公共树基于 [android_device_samsung_exynos9820-common](https://github.com/Exynos982x-OrangeFox/android_device_samsung_exynos9820-common)。
*   **修改版作者**: 本仓库为个人修改版 (Fork)，由 [mcajun87](https://github.com/mcajun87) 维护。适配了最新的构建环境与 crDroid 13 (Android 17) 系统。
*   **我的仓库地址**: [mcajun87/android_device_samsung_d1x](https://github.com/mcajun87/android_device_samsung_d1x)
*   **ROM 来源**: 本 Recovery 专为 **crDroid 13 (Android 17)** 适配。ROM 下载地址：[crDroidAndroid-13.0-d1x](https://github.com/Rocky7842/OTA_provider/releases) (基于 Rocky7842 的构建)。

### 💻 内核说明 (Kernel)

`prebuilt/` 目录下的预编译 `Image` 和 `dtbo.img` 提取自 **crDroid 13 的官方 recovery.img** 及对应的 ROM 包。这确保了内核、DTBO 与手机当前系统版本的 100% 硬件匹配，避免因版本错位导致的黑屏或无法挂载分区问题。

### 🛠️ 编译指南 (基于 fox_16.0 分支)

```sh
# 1. 同步 OrangeFox 最新源码
mkdir -p ~/fox_16.0
cd ~/fox_16.0
repo init -u https://gitlab.com/OrangeFox/Manifest.git -b fox_16.0 --depth=1
repo sync -c -j$(nproc) --no-clone-bundle --no-tags

# 2. 拉取设备树和公共树 (确保分支为 fox_16.0)
mkdir -p device/samsung
git clone -b fox_16.0 https://github.com/mcajun87/android_device_samsung_d1x device/samsung/d1x
git clone -b fox_16.0 https://github.com/mcajun87/android_device_samsung_exynos9820-common device/samsung/exynos9820-common

# 3. 开始编译 (使用 Android 16 规范的 lunch 目标)
export FOX_BUILD_DEVICE=d1x
source build/envsetup.sh
lunch twrp_d1x-trunk_staging-eng
mka recoveryimage -j$(nproc)