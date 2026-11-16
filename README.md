# LeEco Max2 (x2) — MoKee 10 内核 · BakaSU + Droidspaces

在 LeEco Max2（`le_x2` / `le_x2_whole_netcom` / msm8996）的 **MoKee 10（mkq-mr1，Linux 3.18.140）** 内核上，干净集成 **BakaSU**（KernelSU 下游，Manual Hook）与 **Droidspaces**（LXC 风格容器运行时）所需的全部内核能力。

> Kernel for LeEco Max2 (msm8996) on MoKee 10, with BakaSU (KernelSU downstream, manual hook) and the kernel configuration Droidspaces requires. Verified on real hardware: boots, root works, `droidspaces check` passes all MUST-HAVE items, an Alpine container runs with its own init as PID 1.

---

## 基线

| 项 | 值 |
|---|---|
| 上游仓库 | `https://github.com/MoKee/android_kernel_leeco_msm8996` |
| 分支 / 基线提交 | `mkq-mr1` @ `d8cee24531677a12bc5d2285f55f1bae2cbc227d` |
| 内核版本 | 3.18.140 |
| 设备 | LeEco Max2（x2，msm8996，`mokee_x2_defconfig`） |
| BakaSU | `https://github.com/Baka-SU/BakaSU` @ `5d6d1843c8937f5ff2a145dc89a0cf46030ae6f8`（`v4.2.0-rc3`，作为 git submodule） |

本分支只有**一个自建分支** `mokee10-bakasu-droidspaces`；`mkn-mr1` / `mko-mr1` / `mkp` / `mkq-mr1` / `mkr-mr1` 五个分支保持与 MoKee 上游完全一致，未做任何改动。

---

## 已集成内容

### 1. BakaSU（root）

集成方式遵循 BakaSU 官方布局（它的 `Kbuild` 会校验 `KernelSU/.git` 是否存在，直接拷贝源码会被拒绝）：

- `KernelSU/`：BakaSU 仓库，以 **git submodule** 形式引入
- `drivers/kernelsu` → `../KernelSU/kernel`（软链）
- `drivers/Makefile`：`obj-$(CONFIG_KSU) += kernelsu/`
- `drivers/Kconfig`：`source "drivers/kernelsu/Kconfig"`

Manual Hook 插在 4 个文件里（setuid / initrc / input 由 BakaSU 的 LSM 自动钩子负责）：

| 文件 | 钩子 |
|---|---|
| `fs/exec.c` | `ksu_handle_execveat`（`do_execve_common` 入口）+ `ksu_handle_post_execveat`（`out_ret`） |
| `fs/open.c` | `ksu_handle_faccessat` |
| `fs/stat.c` | `ksu_handle_stat`（`newfstatat` / `fstatat64`）、`ksu_handle_newfstat_ret`、`ksu_handle_fstat64_ret` |
| `kernel/reboot.c` | `ksu_handle_sys_reboot` |

> **3.18 注意**：本内核的 `do_execve_common()` 只有 `struct filename *` 参数，没有 `fd` / `flags`，因此钩子传 `(int *)AT_FDCWD` 与 `NULL`。这正好命中 BakaSU 内部 `fd == (int *)AT_FDCWD && flags == 0` 的短路分支；若传 `NULL/NULL` 会走到 `*fd` 解引用。

### 2. Droidspaces（容器）

defconfig 新增（官方 non-GKI 清单）：

```
CONFIG_SYSVIPC=y  CONFIG_POSIX_MQUEUE=y  CONFIG_PID_NS=y  CONFIG_UTS_NS=y  CONFIG_IPC_NS=y
CONFIG_CGROUP_DEVICE=y  CONFIG_CGROUP_NET_PRIO=y  CONFIG_MEMCG=y  CONFIG_MEMCG_SWAP=y
CONFIG_CFS_BANDWIDTH=y  CONFIG_DEVTMPFS=y  CONFIG_VETH=y  CONFIG_NF_TABLES=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y  CONFIG_IP6_NF_NAT=y  CONFIG_IP6_NF_TARGET_MASQUERADE=y
CONFIG_MACVLAN=y  CONFIG_USER_NS=y
# CONFIG_ANDROID_PARANOID_NETWORK is not set
```

并打入官方补丁 `01.fix_kernel_panic_in_xt_qtaguid.patch`（修 `dev_get_stats()` 访问 inactive 接口的空指针）。
官方 `02.fix_restore cgroup file prefix handling .patch` **未打**：它改的是 4.4+ 的 `kernel/cgroup/cgroup.c`，本内核是 3.18 的 `kernel/cgroup.c`（cgroup v1），文件不存在。

---

## 实机验证结果

| 阶段 | 版本串 | 结果 |
|---|---|---|
| 干净基线 | `3.18.140-mokee-gd8cee2453` | 正常开机 |
| BakaSU | `3.18.140-mokee-gd8cee2453-dirty` | `su -c id` → `uid=0(root) ... context=u:r:ksu:s0` |
| + Droidspaces | `3.18.140-mokee-g40e326934-dirty` | root 保持，`droidspaces check` MUST HAVE 全绿 |

`droidspaces check` 摘要：

```
[MUST HAVE]   Root ✓  Linux version ✓  PID ns ✓  Mount ns ✓  UTS ns ✓  IPC ns ✓
              pivot_root ✓  /proc ✓  /sys ✓  Seccomp ✓
[RECOMMENDED] epoll ✓ signalfd ✓ PTY ✓ devpts ✓ Loop ✓ ext4 ✓ devtmpfs ✓
              Cgroup v2 ✗  Cgroup namespace ✗  New mount API ✗
[OPTIONAL]    FUSE ✓ OverlayFS ✓ Net ns ✓ Bridge ✓ Veth ✓ Macvlan ✓ IPv6 NAT ✓
              Memory limit ✓ Swap limit ✓ CPU limit ✓ CPU accounting ✓ Sandboxing ✓
              TUN/TAP ✗  Process limit ✗
Summary: [✓] All required features found!
```

容器 smoke test（Alpine minirootfs，未做任何模拟）：

```
Container: alpine (RUNNING)   PID 4595   Alpine Linux v3.20   NAT 172.28.195.3
--- 容器内 ---
Linux alpine 3.18.140-mokee-g40e326934-dirty #3 SMP PREEMPT aarch64 Linux
uid=0(root)
PID   PPID  COMMAND
    1     0 init        ← 容器自带 init 作为 PID 1
   17     1 getty
```

---

## 构建

依赖：AArch64 GCC 4.9 工具链（`aarch64-linux-android-gcc 4.9.x`）。

```bash
git clone -b mokee10-bakasu-droidspaces \
  https://github.com/minghao680/android_kernel_leeco_msm8996-mokee-bakasu-droidspaces.git
cd android_kernel_leeco_msm8996-mokee-bakasu-droidspaces
git submodule update --init --recursive        # 必须，否则 drivers/kernelsu 为空

export ARCH=arm64 SUBARCH=arm64 CROSS_COMPILE=aarch64-linux-android-
make O=out mokee_x2_defconfig
make O=out olddefconfig
make O=out HOSTCFLAGS="-Wall -Wmissing-prototypes -Wstrict-prototypes -O2 -fomit-frame-pointer -fcommon" -j$(nproc)
```

产物：`out/arch/arm64/boot/Image.gz-dtb`（`Image.gz` + 23 个 dtb 组成的 QCDT blob）。
改了 `drivers/kernelsu` 之后建议 `rm -rf out/drivers/kernelsu out/drivers/built-in.o` 再做增量。

## 刷入

用 AnyKernel3 打包成 zip，在 TWRP 里 `twrp install` 刷入 boot 分区。

> 打包必须用 Python 的 `zipfile` 以 `/` 作条目分隔符；PowerShell 的 `Compress-Archive` / .NET `ZipFile` 会写成 `\`，TWRP 会报“无效的 Zip 文件格式”。

建议流程：刷入 → 重启 → 检查 `uname -a` 与 `getprop sys.boot_completed` → `su -c id` → `droidspaces check`。

---

## 已知限制（3.18 结构性，非配置漏项）

| 项 | 原因 | 影响 |
|---|---|---|
| Cgroup v2 / Cgroup namespace | 3.18 只有 cgroup v1，`CGROUP_NS` 是 4.6+ | systemd 容器可能行为异常；Droidspaces 自动回退 v1 |
| New mount API（`fsopen`） | 5.2+ | systemd 259+ 部分功能降级，Droidspaces 有 seccomp 兜底 |
| `--pids-limit` | `CONFIG_CGROUP_PIDS` 是 4.3+ | 该限制被跳过 |
| `TUN/TAP` 检测 | 探针读 `/dev/net/tun`，本机是 `/dev/tun` | 实际可用，仅检测显示 ✗ |
| SUSFS | BakaSU 只 backport 到 4.3+；且 `CONFIG_KSU_SUSFS` 依赖 `THREAD_INFO_IN_TASK`（3.18 无此符号） | 本分支显式 `# CONFIG_KSU_SUSFS is not set` |
| KPM（KernelPatch Module） | BakaSU 不提供；源码仅有 `deprecated` 的 `ENABLE_KPM` / `MANAGE_KPM` 枚举和对 KernelPatch 的冲突检测 | 不可用 |

---

## 提交记录

| 提交 | 内容 |
|---|---|
| `40e326934` | stage1: BakaSU manual-hook 集成（实机开机 + root 验证） |
| `2d00d29fa` | stage2: Droidspaces non-GKI 配置 + `xt_qtaguid` 补丁（requirements 全绿） |
| `69b0f5f80` | build: KernelSU(BakaSU `5d6d1843`) 声明为 submodule + `drivers/kernelsu` 软链 |

历史实验分支（已被本分支取代）留了备份 tag：

```
backup/mokee10-bakasu-droidspaces-32960308
backup/mokee10-bakasu-plain-1e07bede
backup/mokee10-droidspaces-0fa52be5
backup/mokee10-bakasu-debug-e5a39ba3
```

---

## 许可与致谢

- 内核代码：GPL-2.0（见仓库根目录 `COPYING` 与 `README`）
- BakaSU 的 `kernel/` 目录：GPL-2.0-only；其余部分 GPL-3.0-or-later
- [KernelSU](https://github.com/tiann/KernelSU)（上游）、[SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)（BakaSU 的直接上游）
- [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) 提供的内核配置清单与 non-GKI 补丁
- [MoKee](https://github.com/MoKee/android_kernel_leeco_msm8996) 维护的 msm8996 内核基线
