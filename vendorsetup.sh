export FOX_BUILD_DEVICE=d1x
export FOX_VARIANT=A16
export FOX_TARGET_DEVICES=d1x,d1xks
export FOX_BUILD_TYPE=Unofficial
export OF_MAINTAINER=mcajun87

# 使用 LZMA 压缩
export OF_USE_LZMA_COMPRESSION=1

# 跳过 FBE 解密 (因为无 keymaster blob)
export OF_SKIP_FBE_DECRYPTION=1
export OF_SKIP_DECRYPTED_ADOPTED_STORAGE=1