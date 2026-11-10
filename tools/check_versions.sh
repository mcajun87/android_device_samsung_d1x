#!/usr/bin/env bash
# 核对"镜像配置"与"当前 ROM / 内核 / 设备树"是否一致，只读，不改任何东西。
# 用法：device/samsung/d1x/tools/check_versions.sh [源码树路径]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="$(cd "$HERE/.." && pwd)"
FOX_DIR="${1:-$(cd "$DEVICE_DIR/../../.." && pwd)}"
COMMON="$FOX_DIR/device/samsung/exynos9820-common"
KERNEL_TREE="$FOX_DIR/kernel/samsung/exynos9820"
PART=67633152
FAIL=0

say() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
ok()  { printf '  \033[1;32mOK\033[0m   %s\n' "$*"; }
bad() { printf '  \033[1;31mFAIL\033[0m %s\n' "$*"; FAIL=1; }
warn(){ printf '  \033[1;33mWARN\033[0m %s\n' "$*"; }

say "1. 镜像配置里的 os_version / os_patch_level"
CFG=$(grep -m1 'BOARD_MKBOOTIMG_ARGS += --os_version' "$COMMON/BoardConfigCommon.mk" 2>/dev/null || true)
if [ -n "$CFG" ]; then
    WANT_OS=$(sed -n 's/.*--os_version *\([0-9]*\).*/\1/p' <<<"$CFG")
    WANT_PATCH=$(sed -n 's/.*--os_patch_level *\([0-9-]*\).*/\1/p' <<<"$CFG")
    echo "  配置: os_version=$WANT_OS  patch=$WANT_PATCH"
else
    bad "BoardConfigCommon.mk 里没有 --os_version（解密会失败）"
    WANT_OS=""; WANT_PATCH=""
fi

say "2. 设备当前 ROM 的版本（需 adb 且设备在运行状态，可跳过）"
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
    ROM_OS=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
    ROM_PATCH=$(adb shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r')
    echo "  ROM : os_version=$ROM_OS  patch=$ROM_PATCH"
    if [ -n "$WANT_OS" ] && [ -n "$ROM_OS" ]; then
        [ "$WANT_OS" = "$ROM_OS" ] && ok "os_version 与 ROM 一致" \
            || bad "os_version 不一致（配置 $WANT_OS / ROM $ROM_OS）→ 解密会失败"
    fi
    if [ -n "$WANT_PATCH" ] && [ -n "$ROM_PATCH" ]; then
        [ "$WANT_PATCH" = "$ROM_PATCH" ] && ok "patch level 与 ROM 一致" \
            || warn "patch level 不一致（配置 $WANT_PATCH / ROM $ROM_PATCH），可能导致密钥被拒"
    fi
else
    warn "没有可用的 adb 设备，跳过 ROM 对比（步骤 2）"
fi

say "3. 内核与设备树版本"
if [ -d "$KERNEL_TREE/.git" ]; then
    echo "  kernel HEAD : $(git -C "$KERNEL_TREE" log -1 --format='%h %s' 2>/dev/null)"
    LOCAL=$(git -C "$KERNEL_TREE" rev-parse HEAD 2>/dev/null)
    REMOTE=$(git -C "$KERNEL_TREE" rev-parse origin/lineage-24.0 2>/dev/null)
    if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        warn "内核落后远端 $(( $(git -C "$KERNEL_TREE" rev-list --count HEAD..origin/lineage-24.0) )) 个提交（git fetch 后再看一次）"
    else
        ok "内核仓库与远端一致（或尚未 fetch）"
    fi
else
    warn "源码树里没有 kernel/samsung/exynos9820"
fi
for r in d1x exynos9820-common; do
    d="$FOX_DIR/device/samsung/$r"
    [ -d "$d/.git" ] && echo "  $r : $(git -C "$d" log -1 --format='%h %s' 2>/dev/null)"
done

say "4. 关键文件与体积预算"
K="$DEVICE_DIR/prebuilt/Image"; DT="$DEVICE_DIR/prebuilt/dtbo.img"
RD="$FOX_DIR/out/target/product/d1x/ramdisk-recovery.img"
[ -f "$K" ]  || bad "缺少 prebuilt/Image"
[ -f "$DT" ] || bad "缺少 prebuilt/dtbo.img"
if [ -f "$K" ] && [ -f "$DT" ]; then
    echo "  Image : $(stat -c%s "$K") 字节  sha256=$(sha256sum "$K" | cut -d' ' -f1)"
    echo "  dtbo  : $(stat -c%s "$DT") 字节"
fi
if [ -f "$RD" ] && command -v xz >/dev/null 2>&1; then
    RD9=$(xz --format=lzma -9 -c < "$RD" | wc -c)
    TOTAL=$((2048 + $(stat -c%s "$K") + RD9 + $(stat -c%s "$DT")))
    LIMIT=$((PART - 69632))
    echo "  ramdisk(lzma -9) = $RD9 字节"
    echo "  合计 $TOTAL / 上限 $LIMIT"
    [ "$TOTAL" -le "$LIMIT" ] && ok "体积放得下（余 $((LIMIT - TOTAL)) 字节）" \
        || bad "超限 $((TOTAL - LIMIT)) 字节"
else
    warn "没有 ramdisk-recovery.img 或 xz，跳过体积预算"
fi

say "5. 手电筒配置"
RC="$COMMON/recovery/root/system/etc/init/exynos9820-common.rc"
grep -q 'rear_flash' "$RC" 2>/dev/null && ok "brightness 指向 rear_flash" \
    || bad "rc 里没有指向 rear_flash（手电筒会失效）"
grep -q 'max_brightness 100' "$RC" 2>/dev/null && ok "max_brightness=100 已写入" \
    || bad "缺 max_brightness（会退化成 60mA，几乎看不见）"

say "结论"
[ "$FAIL" -eq 0 ] && echo "  全部通过" || echo "  有 FAIL 项，先修再编"
exit "$FAIL"
