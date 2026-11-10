# patches/

这里的补丁针对**编译树**（AOSP 项目），**不是**本设备树自身的补丁，不要误用。

## 0001-clang-prebuilts-missing-modules.md

适用症状（`prebuilts/clang/host/linux-x86` 未完整 sync 时）：

- `ninja: '.../libclang_rt.ubsan_minimal_intermediates/libclang_rt.ubsan_minimal.a', missing and no known rule to make it`
- `module libc missing dependencies: libunwind-exported`
- `module <x> missing dependencies: libunwind`

根因：该项目的上游 `Android.bp` 声明了 49 个模块（含自定义 soong 插件类型），
若项目未成功 `repo sync`，这些声明全部缺失；用 `cc_prebuilt_*` 手写 stub 只能逐个补齐。

根治：`repo sync -c --no-tags --no-clone-bundle -j4 prebuilts/clang/host/linux-x86`

临时对策：把该 md 里的片段追加到 `prebuilts/clang/host/linux-x86/Android.bp` 末尾。

## 0002-ramdisk-size-trim.md

recovery.img 超过 67,633,152 分区上限时的解决办法：精简语言（英文/简体/繁体）、
以及**改动 ramdisk 内容后必须清空 `out/target/product/d1x/recovery/root` 暂存区**
（不清空则改动不生效，这是踩过的坑）。同时列出"不能为了省空间而删"的配置项。
