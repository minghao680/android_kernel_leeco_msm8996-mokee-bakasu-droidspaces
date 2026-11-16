# 辅助模块（BakaSU / KernelSU）

本目录是配合 `mokee10-bakasu-droidspaces` 内核使用的辅助模块源码。模块只改运行时状态或覆盖文件，不参与内核构建。

| 目录 | 模块 ID | 作用 | 依赖 / 状态 |
|---|---|---|---|
| `treble_off` | `treble_off` | 开机设置 `ro.treble.enabled=false`，让 `Build.isBuildConsistent()` 跳过 VINTF 校验，消除“您的设备内部出现了问题”弹窗 | 需要 BakaSU/KernelSU 的 `ksud resetprop`；当前启用 |
| `devnet_tun` | `devnet_tun` | 创建 `/dev/net/tun -> /dev/tun`，让 TUN/TAP 检测与容器网络可用 | 依赖内核把 TUN 节点放在 `/dev/tun`；当前启用 |
| `vintf_sysvipc` | `vintf_sysvipc` | 覆盖 `system/etc/vintf/` 下 5 个兼容矩阵，从根上绕过 `CONFIG_SYSVIPC=y` 的 VINTF 校验 | 需要能正常挂载/覆盖 `system/` 的元模块；当前保留未启用 |
| `wifi_nosleep` | `wifi_nosleep` | 固定 `wifi_sleep_policy=2`，每 30 秒检查并关闭 `wlan0` 的 802.11 省电 | 需要 `/system/bin/iw`；当前已安装，重启后自动生效 |

> `treble_off` 与 `vintf_sysvipc` 是两条互斥路线：前者是运行时改 prop 的兜底方案，后者是正统覆盖矩阵方案。启用 `vintf_sysvipc` 时请同时停用 `treble_off`；如果元模块不能正常覆盖 `system/`，继续用 `treble_off`。

## 打包

在 Linux/WSL 或 Git Bash 中，从仓库根目录执行：

```sh
cd modules/treble_off
zip -r ../treble_off.zip module.prop post-fs-data.sh

cd ../devnet_tun
zip -r ../devnet_tun.zip module.prop post-fs-data.sh

cd ../vintf_sysvipc
zip -r ../vintf_sysvipc.zip module.prop system

cd ../wifi_nosleep
zip -r ../wifi_nosleep.zip module.prop service.sh
```

或统一打包：

```sh
cd modules
for m in treble_off devnet_tun vintf_sysvipc wifi_nosleep; do
  rm -f "$m.zip"
  (cd "$m" && zip -r "../$m.zip" .)
done
```

注意：设备上的 `disable`、`update` 是运行时标记，不要打进 zip。

## 安装

- BakaSU / KernelSU 模块页刷入对应 zip，重启生效。
- 也可以命令行安装：

```sh
su -c 'ksud module install /data/local/tmp/wifi_nosleep.zip'
```

## 说明

- `wifi_nosleep` 日志：`/data/local/tmp/wifi_nosleep.log`。
- `vintf_sysvipc` 的矩阵文件较大，直接查看 diff 即可确认改了哪些 `<kernel version>` 条目；不要手工改设备上的 `/system`。
- 这些模块只针对本项目的 MoKee 10 / msm8996 设备；换 ROM 或换内核后请重新核对路径与 SELinux 策略。
