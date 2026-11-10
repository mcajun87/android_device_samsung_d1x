#!/usr/bin/env bash
# ============================================================================
# d1x (Galaxy Note10 5G / SM-N971N) —— OrangeFox recovery.img 打包流水线
#
# 为什么需要这个脚本：
#   AOSP 构建系统把 recovery ramdisk 固定用 `lzma -f -c`（默认预设 6）压缩，
#   产出约 18.45 MB。本机 recovery 分区只有 67,633,152 B，而 prebuilt/Image
#   是 49.46 MB，两者相加会超出上限，`mka recoveryimage` 会在最后一步报：
#       error: ... recovery.img too large (68229120 > 67563520)
#   但这时的 ramdisk-recovery.img 已经生成好了，所以本脚本：
#     1. 用 `lzma -9` 重新压缩 ramdisk（18.45 MB -> 16.60 MB，省 1.85 MB）
#     2. 自己调 mkbootimg 重建镜像，并把 boot 头部 os_version 写成 17
#        （Android 17 ROM 的解密必需，见 README）
#     3. 用 avbtool 重新做 AVB 签名（testkey_rsa4096，与官方一致）
#     4. 校验尺寸 / 头部 / AVB / 内核哈希，产出 dist/
#
# 用法：
#   device/samsung/d1x/tools/make_recovery_image.sh [源码树路径]
# 环境变量：
#   FOX_DIR       源码树根（默认从脚本位置推断）
#   PRODUCT_OUT   产物目录（默认 $FOX_DIR/out/target/product/d1x）
#   OS_VERSION    boot 头部 os_version（默认 17）
#   OS_PATCH      boot 头部 patch level（默认 2026-10-01）
# ============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="$(cd "$HERE/.." && pwd)"
FOX_DIR="${FOX_DIR:-${1:-$(cd "$DEVICE_DIR/../../.." && pwd)}}"
PRODUCT_OUT="${PRODUCT_OUT:-$FOX_DIR/out/target/product/d1x}"
OS_VERSION="${OS_VERSION:-17}"
OS_PATCH="${OS_PATCH:-2026-10-01}"
PART_SIZE=67633152
AVB_FOOTER=69632
DTBO="$DEVICE_DIR/prebuilt/dtbo.img"
KERNEL="$DEVICE_DIR/prebuilt/Image"

MKBOOTIMG="$FOX_DIR/out/host/linux-x86/bin/mkbootimg"
AVBTOOL="$FOX_DIR/external/avb/avbtool.py"
AVBKEY="$FOX_DIR/external/avb/test/data/testkey_rsa4096.pem"
RAMDISK_IN="$PRODUCT_OUT/ramdisk-recovery.img"
DIST="$PRODUCT_OUT/dist"

say() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

say "0. 环境检查"
for f in "$KERNEL" "$DTBO" "$RAMDISK_IN" "$MKBOOTIMG" "$AVBTOOL" "$AVBKEY"; do
    [ -f "$f" ] || die "缺少文件: $f"
done
command -v python3 >/dev/null || die "缺少 python3"
if command -v xz >/dev/null 2>&1; then
    LZ_DEC=("xz" "--format=lzma" "-dc"); LZ_ENC=("xz" "--format=lzma" "-9" "-c")
elif command -v lzma >/dev/null 2>&1; then
    LZ_DEC=("lzma" "-dc");                LZ_ENC=("lzma" "-9" "-c")
else
    die "需要 xz 或 lzma"
fi
printf '  源码树      : %s\n  Product out : %s\n  内核        : %s\n' \
    "$FOX_DIR" "$PRODUCT_OUT" "$(stat -c%s "$KERNEL") 字节"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say "1. 解压 ramdisk 并用 -9 重新压缩"
"${LZ_DEC[@]}" < "$RAMDISK_IN" > "$WORK/rd.cpio"
CPIO_BYTES=$(stat -c%s "$WORK/rd.cpio")
"${LZ_ENC[@]}" < "$WORK/rd.cpio" > "$WORK/rd9.lzma"
NEW_RD=$(stat -c%s "$WORK/rd9.lzma")
OLD_RD=$(stat -c%s "$RAMDISK_IN")
printf '  cpio %s 字节；ramdisk %s -> %s 字节（省 %s）\n' \
    "$CPIO_BYTES" "$OLD_RD" "$NEW_RD" "$((OLD_RD - NEW_RD))"

say "2. 体积预算"
K_BYTES=$(stat -c%s "$KERNEL"); D_BYTES=$(stat -c%s "$DTBO")
TOTAL=$((2048 + K_BYTES + NEW_RD + D_BYTES))
LIMIT=$((PART_SIZE - AVB_FOOTER))
printf '  kernel %s + ramdisk %s + dtbo %s + 头部 2048 = %s\n  上限 %s，余量 %s\n' \
    "$K_BYTES" "$NEW_RD" "$D_BYTES" "$TOTAL" "$LIMIT" "$((LIMIT - TOTAL))"
[ "$TOTAL" -le "$LIMIT" ] || die "仍然超出分区上限 $((TOTAL - LIMIT)) 字节"

say "3. mkbootimg（boot 头部 os_version = $OS_VERSION，patch = $OS_PATCH）"
IMG="$WORK/recovery.img"
"$MKBOOTIMG" \
    --kernel "$KERNEL" --ramdisk "$WORK/rd9.lzma" \
    --cmdline "androidboot.super_partition=system" \
    --base 0x10000000 --pagesize 2048 \
    --recovery_dtbo "$DTBO" \
    --os_version "$OS_VERSION" --os_patch_level "$OS_PATCH" \
    --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 \
    --tags_offset 0x00000100 --header_version 1 \
    --output "$IMG"

say "4. AVB 签名（SHA256_RSA4096 / testkey_rsa4096 / rollback 1 @ 0）"
FP=""
[ -f "$PRODUCT_OUT/build_fingerprint.txt" ] && FP="$(cat "$PRODUCT_OUT/build_fingerprint.txt")"
[ -n "$FP" ] || FP="samsung/twrp_d1x/d1x:16/$(date -u +%Y%m%d)/eng/test-keys"
python3 "$AVBTOOL" add_hash_footer \
    --image "$IMG" \
    --partition_size "$PART_SIZE" --partition_name recovery \
    --algorithm SHA256_RSA4096 --key "$AVBKEY" \
    --prop "com.android.build.recovery.fingerprint:$FP" \
    --prop "com.android.build.boot.os_version:$OS_VERSION" \
    --prop "com.android.build.boot.security_patch:$OS_PATCH" \
    --rollback_index 1 >/dev/null
echo "  OK"

say "5. 校验"
python3 - "$IMG" "$KERNEL" "$OS_VERSION" "$PART_SIZE" <<'PY'
import sys, struct, hashlib
img, kern, want_major, part = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
d = open(img, 'rb').read()
ks, ka, rs, ra, ss_, sa, tags, page, hv, osv = struct.unpack('<10I', d[8:48])
dtbo_sz, dtbo_off = struct.unpack('<IQ', d[1632:1644])
major = (osv >> 25) & 0x7f
y = ((osv >> 4) & 0x7f) + 2000
m = osv & 0xf
kh = hashlib.sha256(d[page:page+ks]).hexdigest()
ekh = hashlib.sha256(open(kern, 'rb').read()).hexdigest()
ok = True
print(f"  总大小         : {len(d)} (分区 {part})")
print(f"  kernel_size    : {ks}")
print(f"  ramdisk_size   : {rs}")
print(f"  header_version : {hv}")
print(f"  os_version     : major {major}, patch {y}-{m:02d}")
print(f"  recovery_dtbo  : {dtbo_sz} @ {dtbo_off}")
print(f"  内核哈希匹配   : {'YES' if kh == ekh else 'NO'}")
print(f"  AVB 尾部魔数   : {d[-64:-60]!r}")
if len(d) != part: ok = False
if major != want_major: ok = False
if kh != ekh: ok = False
if d[-64:-60] != b'AVBf': ok = False
print("  结论           :", "PASS" if ok else "FAIL")
sys.exit(0 if ok else 1)
PY

say "6. 产出 dist/"
mkdir -p "$DIST"
rm -f "$DIST"/recovery.img "$DIST"/recovery.tar* "$DIST"/recovery.img.*
cp -f "$IMG" "$DIST/recovery.img"
( cd "$DIST" && tar -H ustar -cf recovery.tar recovery.img )
( cd "$DIST" && sha256sum recovery.img > recovery.img.sha256 \
             && md5sum recovery.tar > recovery.tar.md5 )
ls -l "$DIST"
say "完成：$DIST/recovery.tar"
