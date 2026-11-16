#!/system/bin/sh
# WiFi 不休眠：开机后固定 wifi_sleep_policy=2，并持续关闭 wlan0 的 802.11 省电。
# 适用于 Android 10 / MoKee 10，iw 位于 /system/bin/iw。

MODDIR=${0%/*}
LOG=/data/local/tmp/wifi_nosleep.log

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

# 等系统启动完成，Settings Provider 可用
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
  sleep 2
done
sleep 3

settings put global wifi_sleep_policy 2 2>/dev/null
log "boot_completed; wifi_sleep_policy=$(settings get global wifi_sleep_policy 2>/dev/null)"

# WiFi 重连、息屏、驱动重置都可能把 power_save 重新打开，每 30 秒校正一次
while true; do
  if [ -e /sys/class/net/wlan0 ]; then
    state=$(iw dev wlan0 get power_save 2>/dev/null)
    case "$state" in
      *"Power save: on"*)
        iw dev wlan0 set power_save off 2>/dev/null
        log "wlan0 power_save on -> off (rc=$?)"
        ;;
    esac
  fi
  sleep 30
done
