# d1x 版本升级 / 重新编译流程

本树有三条独立的更新源，任何一条动了都需要重新编译一次。
**最容易忘记、后果最严重的是 ROM 升级后 `os_version` 没跟着改**——那会让
`/data` 解密和 MTP 直接失效，而现象只是"挂载不了 data"，很难联想到镜像头部。

---

## 一、什么时候需要重新编译

| 触发 | 检查方式 | 是否需要改动配置 |
| :-- | :-- | :-- |
| OrangeFox 上游 `fox_16.0` 更新 | `cd ~/fox && repo sync -c -j8` 后 `repo diffmanifests` | 一般不需要 |
| 本设备树/公共树更新 | `git -C device/samsung/d1x pull --ff-only` 等 | 看提交内容 |
| 内核源码更新 | `git -C kernel/samsung/exynos9820 fetch origin` 后看 `HEAD..origin/lineage-24.0` | 需要重新编译内核 |
| **ROM 升级（换版本/换安全补丁）** | 见第二节 | **必须改 `--os_version` / `--os_patch_level`** |

---

## 二、ROM 升级后必须同步的两个值

`/data` 是元数据加密，密钥由 TEE 的 keymaster 解封。S-Boot 会把 **boot 镜像头部**
的 `os_version` 字段交给 TEE，keymaster 会拿它和密钥里记录的版本比较：

```
tz_init_bootloader_info: os_version : 160000        <- 来自镜像头
swd_configure: invalid os_version or os_patchlevel
km_check_key_os_version_patchlevels: key_os_version(170000) > _os_version(160000)
-> Unable to decrypt metadata encryption            <- /data 挂不上
```

密钥里的版本来自 ROM，所以镜像头的版本必须**等于当前装的 ROM**。
这两条定义在公共树 `BoardConfigCommon.mk`：

```makefile
BOARD_MKBOOTIMG_ARGS += --os_version 17 --os_patch_level 2026-10-01
```

### 怎么查 ROM 的真实值

方法 A（推荐，直接读 ROM 的 build.prop）：

```sh
# 假设 ROM zip 里的 system 已解出，或直接看已装 ROM 的路径
unzip -p ROM.zip system/build.prop | grep -E 'ro.build.version.(release|security_patch)'
unzip -p ROM.zip vendor/build.prop | grep -E 'ro.vendor.build.security_patch'
```

方法 B（设备能开机时）：

```sh
adb shell getprop ro.build.version.release        # 例如 17
adb shell getprop ro.build.version.security_patch # 例如 2026-10-01
adb shell getprop ro.vendor.build.security_patch
```

然后把 `--os_version` 改成 release 的整数部分，`--os_patch_level` 改成
`YYYY-MM-DD` 形式的安全补丁。`tools/check_versions.sh` 会自动比对并告警。

> `prepdecrypt.sh` 还会在运行时把 `ro.system.build.*` / `ro.product.build.*` /
> `ro.odm.build.*` 同步成 ROM 的值，但**它管不到镜像头**，所以上面这条手工同步不能省。

---

## 三、标准重编流程

```sh
# 1) 同步源码
cd ~/fox
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
git -C device/samsung/d1x pull --ff-only
git -C device/samsung/exynos9820-common pull --ff-only

# 2) 编译（ramdisk 末尾的尺寸检查失败是预期行为，见 README）
export ALLOW_MISSING_DEPENDENCIES=true FOX_BUILD_DEVICE=d1x
set +u; source build/envsetup.sh; lunch twrp_d1x-bp2a-eng; set -u
export TARGET_PRODUCT=twrp_d1x TARGET_RELEASE=bp2a TARGET_BUILD_VARIANT=eng
mka adbd recoveryimage -j4

# 3) 重压 + 重打包 + 签名 + 校验
device/samsung/d1x/tools/make_recovery_image.sh ~/fox

# 4) 核对产物（脚本最后会打印 PASS/FAIL）
ls -l out/target/product/d1x/dist/
```

---

## 四、内核更新流程

内核源码一直在更新，本树用 `prebuilt/Image` 方式集成。
自编内核需带三处补丁（见 `patches/0003`），步骤：

```sh
cd ~/fox/kernel/samsung/exynos9820
git fetch origin lineage-24.0
git log --oneline HEAD..origin/lineage-24.0     # 有没有新提交

# 有更新就把本地补丁 rebase 到新上游
git rebase origin/lineage-24.0

# 编译（-Os 是为了体积，见 README 预算）
export PATH=~/fox/prebuilts/clang/host/linux-x86/clang-r547379/bin:$PATH
make -j4 O=out ARCH=arm64 CC=clang LLVM=1 LLVM_IAS=1 KCFLAGS=-Wno-error

# 装进设备树（必须 touch，否则 ninja 认为没变）
cp -f out/arch/arm64/boot/Image ~/fox/device/samsung/d1x/prebuilt/Image
touch ~/fox/device/samsung/d1x/prebuilt/Image

# 重新打包（会重新计算体积预算）
~/fox/device/samsung/d1x/tools/make_recovery_image.sh ~/fox
```

### 内核体积与压缩预设

| 内核大小 | ramdisk（`lzma -9`） | 合计（含 dtbo 与头部） | 结论 |
| --: | --: | --: | :-- |
| 47,601,688（自编 `-Os`） | 16,600,000 | ≈65.2 MB | ✅ 余量约 2.4 MB |
| 49,455,128（crDroid 官方） | 16,600,000 | ≈67.0 MB | ✅ 余量约 0.53 MB |
| 49,059,864（自编 `-O2`） | 16,600,000 | ≈66.6 MB | ✅ 余量约 0.9 MB |

上限固定 `67,633,152 − 69,632 = 67,563,520`。**换更大的内核前先跑一次打包脚本看预算**。

---

## 五、升级后必做的验收

| 项 | 怎么验 | 失败说明 |
| :-- | :-- | :-- |
| 能进 OrangeFox | 冷启动进 GUI | 内核或分区问题 |
| 语言 | 默认简体中文，可切繁中/English | 语言文件缺失 |
| 时区 | `getprop persist.sys.timezone` 为 `CST-8`，`date` 是北京时间 | `OF_DEFAULT_TIMEZONE` 丢了 |
| **解密** | `getprop twrp.decrypt.done` 为 `true`，`mount | grep ' /data '` 可见 | **`os_version` 与 ROM 不一致** |
| MTP | 插电脑能看到内部存储并写文件 | 通常随解密一起失效 |
| 手电筒 | 点开关能亮 | `rear_flash` 链接或 `max_brightness` 丢失 |
| 备份 | 备份 Boot 成功 | 分区标志表损坏 |

命令行一次性核对：

```sh
device/samsung/d1x/tools/check_versions.sh
```
