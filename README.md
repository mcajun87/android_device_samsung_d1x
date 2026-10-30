# OrangeFox Recovery device tree for the Samsung Galaxy Note10 5G (d1x)

| Device | Samsung Galaxy Note10 5G |
| :-- | :-- |
| Codename | d1x |
| Models | SM-N971N |
| SoC | Exynos 9825 |

Common tree: [android_device_samsung_exynos9820-common](https://github.com/Exynos982x-OrangeFox/android_device_samsung_exynos9820-common)

## Kernel

The prebuilt `Image` and `dtbo.img` are extracted from the official LineageOS 23.2 `recovery.img` of
2026-10-22 (sha256 `6ca10bea598f55fc1a07bdc2ae3a185386f5dbe34e924156a31b1c90765086ea`), built from
[android_kernel_samsung_exynos9820](https://github.com/LineageOS/android_kernel_samsung_exynos9820/tree/a412cfaf86b980ce35cae96a35f678c8ea551575)
with `exynos9820-d1x_defconfig`.

## Building

```sh
git clone https://gitlab.com/OrangeFox/sync.git
cd sync
./orangefox_sync.sh --branch 12.1 --path ~/fox_12.1

cd ~/fox_12.1
git clone -b fox_12.1 https://github.com/Exynos982x-OrangeFox/android_device_samsung_d1x device/samsung/d1x
git clone -b fox_12.1 https://github.com/Exynos982x-OrangeFox/android_device_samsung_exynos9820-common device/samsung/exynos9820-common

export FOX_BUILD_DEVICE=d1x
source build/envsetup.sh
lunch twrp_d1x-eng
mka adbd recoveryimage
```

The recovery image is written to `out/target/product/d1x/`, along with an Odin-flashable `.tar`.
