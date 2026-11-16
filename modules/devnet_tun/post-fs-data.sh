#!/system/bin/sh
mkdir -p /dev/net
if [ ! -e /dev/net/tun ]; then
  ln -s /dev/tun /dev/net/tun
fi
