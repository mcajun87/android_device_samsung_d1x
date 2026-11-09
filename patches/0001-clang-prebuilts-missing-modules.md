# 临时补齐 prebuilts/clang 缺失模块

将以下内容追加到 `prebuilts/clang/host/linux-x86/Android.bp` 末尾。

前提：本地已有 `clang-r547379`（或其实际版本），且
`<VERSION>/lib/clang/20/lib/linux/{aarch64,arm,i386,x86_64}/` 下有对应 `.a`。
把 `<VERSION>` 换成实际目录名。

```bp
cc_defaults {
    name: "clang_stub_defaults",
    host_supported: true,
    device_supported: true,
    compile_multilib: "both",
    ramdisk_available: true,
    vendor_ramdisk_available: true,
    recovery_available: true,
    vendor_available: true,
    product_available: true,
    apex_available: ["//apex_available:platform", "//apex_available:anyapex"],
    stl: "none",
    system_shared_libs: [],
    strip: { none: true },
}

cc_prebuilt_library_static {
    name: "libclang_rt.ubsan_minimal",
    defaults: ["clang_stub_defaults"],
    no_libcrt: true,
    arch: {
        arm64:  { srcs: ["<VERSION>/runtimes_ndk_cxx/libclang_rt.ubsan_minimal-aarch64-android.a"] },
        arm:    { srcs: ["<VERSION>/runtimes_ndk_cxx/libclang_rt.ubsan_minimal-arm-android.a"] },
        x86:    { srcs: ["<VERSION>/runtimes_ndk_cxx/libclang_rt.ubsan_minimal-i686-android.a"] },
        x86_64: { srcs: ["<VERSION>/runtimes_ndk_cxx/libclang_rt.ubsan_minimal-x86_64-android.a"] },
    },
}

cc_prebuilt_library_static {
    name: "libunwind",
    defaults: ["clang_stub_defaults"],
    no_libcrt: true,
    arch: {
        arm64:  { srcs: ["<VERSION>/lib/clang/20/lib/linux/aarch64/libunwind.a"] },
        arm:    { srcs: ["<VERSION>/lib/clang/20/lib/linux/arm/libunwind.a"] },
        x86:    { srcs: ["<VERSION>/lib/clang/20/lib/linux/i386/libunwind.a"] },
        x86_64: { srcs: ["<VERSION>/lib/clang/20/lib/linux/x86_64/libunwind.a"] },
    },
}

cc_prebuilt_library_static {
    name: "libunwind-exported",
    defaults: ["clang_stub_defaults"],
    no_libcrt: true,
    arch: {
        arm64:  { srcs: ["<VERSION>/lib/clang/20/lib/linux/aarch64/libunwind-exported.a"] },
        arm:    { srcs: ["<VERSION>/lib/clang/20/lib/linux/arm/libunwind-exported.a"] },
        x86_64: { srcs: ["<VERSION>/lib/clang/20/lib/linux/x86_64/libunwind-exported.a"] },
        // 注意：本工具链 i386 目录未提供 libunwind-exported.a，故不声明 x86
    },
}
```
