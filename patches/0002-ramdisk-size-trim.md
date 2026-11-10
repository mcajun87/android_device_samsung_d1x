# recovery.img 体积控制（构建时必须做的两件事）

## 背景

d1x 的 recovery 分区上限为 **67,633,152 字节**，而本配置首次成功编译出的
`recovery.img` 达到 **67,811,328 字节**（超限 178,176），`mkbootimg` 之后
的尺寸校验会直接让构建失败：

```
error: recovery.img too large (67811328 > 67633152)
```

体积构成（内核用 CI 版 45,537,304）：

```
boot header                     2,048
内核对齐                   45,539,328
ramdisk（LZMA）            20,603,513   ← 从这里省
内嵌 dtbo                     974,848
──────────────────────────────────────
```

## 必须做的两件事

### 1) 精简语言（改上游 `bootable/recovery`）

只保留 英文 / 简体中文 / 繁体中文：

```bash
cd bootable/recovery/gui/theme

# common/languages 只留 en.xml（其余 27 个删除）
mkdir -p ~/lang_backup && cd common/languages
for f in *.xml; do [ "$f" = "en.xml" ] || mv "$f" ~/lang_backup/; done

# extra-languages/languages 只留 zh_CN.xml / zh_TW.xml
cd ../../extra-languages/languages
for f in *.xml; do case "$f" in zh_CN.xml|zh_TW.xml) ;; *) mv "$f" ~/lang_backup/;; esac; done
```

效果：`common/languages` 2.4 MB → 76 KB，
`extra-languages/languages` 328 KB → 164 KB。

> `TW_DEFAULT_LANGUAGE := zh_CN` 与 `TW_EXTRA_LANGUAGES := true` 保持不变，
> 简体中文仍是默认语言。

### 2) 改动 ramdisk 内容后必须清空暂存区 ⚠️

**这是踩过的坑**：AOSP/OrangeFox 组装 recovery ramdisk 时
`out/target/product/d1x/recovery/root/` 是**叠加拷贝、从不清理**的。
所以删掉源文件后，旧文件仍留在暂存区并被重新打包，症状是
"删了 2.4 MB 语言，镜像反而大了 21 KB"。

```bash
mv out/target/product/d1x/recovery/root ~/staging_backup_$(date +%s)
mka adbd recoveryimage -j4
```

清空后暂存区从 98 MB 降到 83 MB，`recovery.img` 降到
**67,121,152 字节**（余量 512,000），构建通过。

## 已关闭的功能（`exynos9820-common/BoardConfigCommon.mk`）

```makefile
TW_INCLUDE_LPDUMP      := false
TW_INCLUDE_LPTOOLS     := false
TW_INCLUDE_REPACKTOOLS := false
TW_INCLUDE_FASTBOOTD   := false
```

注意 `fastbootd` 是否进包还受 `PRODUCT_USE_DYNAMIC_PARTITIONS` 影响
（`bootable/recovery/prebuilt/Android.mk:45` 的条件是二者取或），
本设备为动态分区设备，因此 `fastbootd` 仍会进包。

## 不要动的东西

以下配置与功能**不能为了省空间而删**：

- `TW_INCLUDE_CRYPTO` / `TW_INCLUDE_CRYPTO_FBE` / `TW_INCLUDE_FBE_METADATA_DECRYPT`（解密）
- `OF_FL_PATH1 := /dev/fox_flash` 与 `exynos9820-common.rc` 里的 flash 软链（手电筒）
- `twres/fonts/wqy-microhei.ttf`（中文显示字体，5.2 MB）
- `TW_DEFAULT_LANGUAGE` / `TW_EXTRA_LANGUAGES` / `OF_DEFAULT_TIMEZONE`
- `OF_SCREEN_H := 2280`（Note10 官方分辨率 1080×2280）

## 若还需要更多空间

按收益顺序：

| 顺序 | 项目 | 预估 |
|---|---|---|
| 1 | `twres` 多余主题（Cream/Gray/Light/Dark/Black 只留一个） | 数 MB 原始 |
| 2 | `TWRP_INCLUDE_LOGCAT := false` + `TARGET_USES_LOGD := false` | ~800 KB |
| 3 | 换更小的内核（会失去 `camera_class`，手电筒路径需重配） | 3+ MB |
