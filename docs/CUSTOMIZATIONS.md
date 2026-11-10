# ⚠️ 本仓库的个人定制项（使用前必读）

这套配置是**为一台特定的机器**调好的。其中几项和出厂状态不同，
**如果你用的是原装硬件 / 别的 ROM 版本，请按每一条的「恢复方法」改回去。**

| # | 定制项 | 只影响 | 影响谁 |
| :-- | :-- | :-- | :-- |
| 1 | 电池容量 3500 → **5000 mAh** | 内核 DTS | 所有用这块电池的人 |
| 2 | boot 头部 `os_version` 绑定 ROM 版本 | 设备树 | 换 ROM 版本的人 |
| 3 | 手电筒走三星私有节点 `rear_flash` | 设备树 | 想改成标准 LED class 的人 |
| 4 | `prebuilt/Image` 用 crDroid 官方内核 | 设备树 | 想用自编内核的人 |

---

## 1. 电池容量：5000 mAh（自制电芯）

### 背景

本机是**「原装电池保护板 + 自制 5000 mAh 电芯」**，出厂规格是 **3500 mAh**。
电量计的满电容量、系统显示的设计容量都会影响 SOC 百分比，所以必须改成实际容量，
否则会出现"3.9 V 却显示 0%"这种读数（3.9 V 实际约 40~60%）。

### 改在哪里

**内核仓库** `Rocky7842_android_kernel_samsung_exynos9820`

文件：`arch/arm64/boot/dts/samsung/battery_data_d1x_common.dtsi`

| 属性 | 本机（5000 mAh） | 原装（3500 mAh） | 作用 |
| :-- | :-- | :-- | :-- |
| `battery,battery_full_capacity` | `<5000>` | `<3500>` | 上报给系统的设计容量（设置里显示的那个） |
| `fuelgauge,capacity` | `<0x1388>` | `<0x0CE2>` | 电量计的满电容量，SOC 百分比的分母 |
| `fuelgauge,fg_reset_wa_data` 的第一个值 | `0x1388` | `0xCE2` | 电量计复位时写入的同一个容量 |

**三处必须一起改**：

- 只改第 1 处 → 设置里显示 5000，但百分比照旧算错
- 只改后两处 → 百分比按 5000 算，但设置里仍显示 3500
- 换算：`3500` 对应 `0x0CE2`（=3298，含原厂折损），`5000` 对应 `0x1388`（=5000）

**不要动**这几项：

| 属性 | 原因 |
| :-- | :-- |
| `fuelgauge,cv_data` | 电芯的电压↔SOC 标定曲线 |
| `fuelgauge,v_empty` / `v_empty_origin` | 空电电压阈值 |
| `battery,age_data` | 按循环数衰减的容量表 |

这几项描述的是**电芯化学特性**，你只换容量不换体系就不该改；
没有实测数据去改反而会算得更歪。

### 生效条件

| 场景 | 说明 |
| :-- | :-- |
| ROM | 改完要**重新编 ROM**（Kernel / dtbo 会带上新值） |
| OrangeFox recovery | recovery 的 DTB 来自镜像内嵌的 `recovery_dtbo`。要让 recovery 也显示新容量，需要用改后的 DTS 重新生成 `dtbo.img`，替换 `device/samsung/d1x/prebuilt/dtbo.img` 后重新打包 |
| 电量计 NVM | 内部还存着旧值，需要一次完整充放循环，或用 Samsung 服务菜单里的电池校准让它重新学习 |

### 恢复方法（如果你用的是原装 3500 mAh 电池）

```diff
- battery,battery_full_capacity = <5000>;
+ battery,battery_full_capacity = <3500>;

- fuelgauge,capacity = <0x1388>;
+ fuelgauge,capacity = <0x0CE2>;

- fuelgauge,fg_reset_wa_data = <0x1388 0x3200 0x338 0x36 0x151F>;
+ fuelgauge,fg_reset_wa_data = <0xCE2 0x3200 0x338 0x36 0x151F>;
```

然后重编内核 / ROM。或者直接改用**未打这个补丁的内核**（本补丁之前的提交）。

---

## 2. boot 头部 `os_version` 绑定 ROM 版本

**位置**：`device/samsung/exynos9820-common/BoardConfigCommon.mk`

```makefile
BOARD_MKBOOTIMG_ARGS += --os_version 17 --os_patch_level 2026-10-01
```

**为什么要写死**：S-Boot 把 boot 镜像头部的 `os_version` 直接交给 TEE 的 keymaster。
如果它低于 ROM 生成密钥时的版本，keymaster 会拒绝解封 `/metadata` 里的密钥，
表现就是 `Unable to decrypt metadata encryption` → `/data` 挂不上 → MTP 也没了。
`resetprop` 改属性**完全无效**，因为这个值来自镜像头，不是属性。

**你必须做的事**：换成别的 ROM / 别的安全补丁后，把这两个值改成**新 ROM 的实际值**。

```sh
# 查 ROM 的实际值
adb shell getprop ro.build.version.release        # → 填进 --os_version
adb shell getprop ro.build.version.security_patch # → 填进 --os_patch_level
```

已知对照：

| ROM | `--os_version` | `--os_patch_level` |
| :-- | :-- | :-- |
| crDroid 17 (2026-10-25) | `17` | `2026-10-01` |
| Evolution X 17 (cnb, 12.4) | `17` | `2026-11-01` |

`tools/check_versions.sh` 会自动比对并在不一致时报 FAIL。

---

## 3. 手电筒：走三星私有节点

**位置**：`recovery/root/system/etc/init/exynos9820-common.rc`

```
mkdir /dev/fox_flash 0755 root root
symlink /sys/class/camera/flash/rear_flash /dev/fox_flash/brightness
write /dev/fox_flash/max_brightness 100
```

**为什么不用标准 LED class 节点**：本机实测 `/sys/class/leds/torch-sec1/brightness`
读写一致（0~15）但**写进去不会点亮闪光灯**；能亮的只有三星私有的
`/sys/class/camera/flash/rear_flash`，它只认 `0/1/100/1001~1010/2000~2015`，
且读值恒为 15。

**想换成 LED class 的人**：把 `OF_FL_PATH1 := /dev/fox_flash` 改成
`/sys/class/leds/<你的节点>`，并删掉上面三行（`max_brightness` 由 LED class 自带）。
**前提是你的机器上那个节点真的能点亮**——先用 `echo 15 > .../brightness` 实测。

**`100` 的含义**：工厂手电档 240 mA。若这一行缺失，OrangeFox 会退化写 `1`（60 mA，几乎看不见）。

---

## 4. `prebuilt/Image` 的来源

当前用的是**crDroid 17 官方 d1x recovery 里的内核**（`4.14.357-openela-ga0e2ad468dd5`），
因为它在本机实测能启动并完成解密。

**想用自编内核的人**：内核仓库 `lineage-24.0` 已经带着三处必需补丁
（`gpu_dvfs_get_step()` NULL 保护、`camera_class` 恢复、LED 解析加固），
按 `docs/UPDATE.md` 第四节编译，然后替换 `prebuilt/Image` 即可。
注意体积：自编 `-Os` 约 47.6 MB，官方约 49.5 MB，配合 `lzma -9` 的 ramdisk 都能放下。
