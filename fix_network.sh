#!/bin/bash

# 修复网络连接问题
echo "正在修复网络连接问题..."

# 禁用IPv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

# 修改DNS配置
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# 更新apt源为官方源
cp /etc/apt/sources.list /etc/apt/sources.list.bak
cat > /etc/apt/sources.list << 'EOL'
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
EOL

# 更新apt缓存
apt-get clean
apt-get update

echo "网络修复完成！"
