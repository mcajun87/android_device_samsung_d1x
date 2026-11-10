# 0003 — 内核：修复 `gpu_dvfs_get_step()` NULL 解引用（卡 SAMSUNG logo 的真凶）

适用内核：`kernel/samsung/exynos9820`（分支 `lineage-24.0`），
`exynos9820-d1x_defconfig` + `CONFIG_CC_OPTIMIZE_FOR_SIZE=y`。

## 症状

刷入自制 recovery.img 后，设备停在开机第一屏（SAMSUNG logo），无限重启，
进不去 OrangeFox。AVB、boot header、分区大小全部校验通过。

## 证据

`/proc/last_kmsg`（需 `adb root`）：

```
Unable to handle kernel NULL pointer dereference at virtual address 0000000000000008
Kernel panic - not syncing: Fatal exception
PC is at gpu_dvfs_get_step+0x8/0x10
LR is at exynos_gpu_cooling_init+0x1c/0x1dc
```

故障指令 `(b9401900)` = `ldr w0, [x0, #8]`，`x0` 为 NULL。

## 根因

本内核只启用一个 Mali DDK（`CONFIG_MALI_BIFROST_R32P1=y`），
实际参与编译的是 `drivers/gpu/arm/exynos/frontend/gpex_dvfs_external.c`：

```c
static struct dvfs_info *dvfs;      /* BSS，初值 NULL */

int gpu_dvfs_get_step(void)
{
	return dvfs->table_size;        /* dvfs 尚未由 gpu_dvfs_init() 赋值 */
}
```

`exynos_gpu_cooling_init()` 是 `device_initcall`，会早于 Mali 平台驱动的
probe 执行，此时 `dvfs == NULL`。

> **注意**：`drivers/gpu/arm/b_r19p0/`、`b_r10p0/`、`b_r16p0/`、`b_r12p0/`、
> `b_r26p0/`、`b_r14p0/` 下的同名文件**没有编进本内核**，改它们无效。
> 判断方法：`ls -la out/drivers/gpu/arm/exynos/frontend/gpex_dvfs_external.o`
> 存在 `.o` 才是真的参与编译。

## 修复

```diff
 int gpu_dvfs_get_clock(int level)
 {
+	/* DSH: see gpu_dvfs_get_step() */
+	if (!dvfs)
+		return -1;
+
 	if ((level < 0) || (level >= dvfs->table_size))
 		return -1;

 	return dvfs->table[level].clock;
 }
@@
 int gpu_dvfs_get_step(void)
 {
+	/* dvfs is NULL until gpu_dvfs_init() runs. exynos_gpu_cooling_init()
+	 * is a device_initcall and can run before the Mali probe, which
+	 * panicked with a NULL deref at gpu_dvfs_get_step+0x8.
+	 */
+	if (!dvfs)
+		return 0;
+
 	return dvfs->table_size;
 }
```

## 为什么返回 0 是"正确语义"而不只是临时绕过

`drivers/thermal/gpu_cooling.c:1021` 本来就有：

```c
num_level = gpu_dvfs_get_step();

if (num_level == 0) {
	pr_err("Faile to get gpu_dvfs_get_step()\n");
	return -EINVAL;                 /* 干净失败 */
}
```

返回 0 后 `gpu_cooling_table_init()` 提前返回，
`gpu_dvfs_get_max_freq()` / `gpu_dvfs_get_voltage()` 等**未加保护**的调用
就不会被执行 —— init 路径上的全部风险被一次性封死。

代价：本次启动不注册 GPU 降温设备（recovery 场景 GPU 基本不用，可接受）。

## 同一次修复里的第二处：`camera_class`（手电筒）

`drivers/leds/leds-s2mpb02.c` 原先有过一处改动，把
`device_create(camera_class, ...)` 改成了 `device_create(NULL, ...)`。
`class` 为 NULL 时设备不会挂到 `/sys/class/camera` 下，于是：

```
/sys/class/camera/flash/rear_flash        ← 不存在
/dev/fox_flash/brightness                 ← symlink 目标失效
OF_FL_PATH1=/dev/fox_flash                ← OrangeFox 找不到文件
→ 手电筒无效
```

而且那个改动是多余的：`camera_class` 由 `fimc-is` 定义
（`CONFIG_VIDEO_EXYNOS_FIMC_IS2=y`），`System.map` 中可见
`ffffff800b382ab8 B camera_class`。

修复（与 `fimc-is` 侧 `if (camera_class == NULL) 才创建` 的逻辑兼容，顺序无关）：

```diff
+extern struct class *camera_class; /*sys/class/camera*/
 struct device *camera_flash_dev;
@@
-	camera_flash_dev = device_create(NULL, NULL, 3, NULL, "flash");
+	if (camera_class == NULL) {
+		struct class *cls = class_create(THIS_MODULE, "camera");
+
+		if (IS_ERR(cls))
+			pr_err("<%s> Failed to create camera class\n", __func__);
+		else
+			camera_class = cls;
+	}
+
+	camera_flash_dev = device_create(camera_class, NULL, 3, NULL, "flash");
@@
-	if (NULL && camera_flash_dev) {
-		device_destroy(NULL, camera_flash_dev->devt);
-	}
+	if (camera_class && camera_flash_dev) {
+		device_destroy(camera_class, camera_flash_dev->devt);
+	}
```

## 验证

```bash
# 目标文件必须引用这些符号
llvm-nm out/drivers/leds/leds-s2mpb02.o | grep -E 'camera_class|class_create|device_create'
#   U __class_create
#   U camera_class
#   U device_create
#   U device_create_file

grep ' camera_class$' out/System.map
#   ffffff800b382ab8 B camera_class

# 开机后
adb shell ls -l /sys/class/camera/flash/
```
