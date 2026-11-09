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
