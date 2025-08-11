#! /bin/bash

# Script by Farid Zellipour
# https://github.com/FaridZelli
# Last updated 2025-08-11 6:04 AM

# Check the current user
USER=$(whoami)
if [ "$USER" == "root" ]; then
  # Welcome text
  echo -e "
--------------------------------------------------
\033[32mYou are logged in as root.\033[0m
--------------------------------------------------"
else
  # Non-root user detected
  echo -e "
--------------------------------------------------
\033[31mWARNING: You do not seem to be logged in as root!\033[0m
--------------------------------------------------"
fi

# Uninstall section
if [[ "$1" == "-u" ]]; then
echo -e "
This script will reconfigure your environment and install shadowsocks on your server.
I am not responsible for any damages or data loss that may occur.

\033[33mAre you sure you want to remove all files previously created by this script? (Y/N)\033[0m
"
# User input
read -p "Your choice:" ANSWER
# Read input
case $ANSWER in
  [Yy]* )
    # Proceed to uninstall
    echo "Uninstalling..."
    systemctl stop shadowsocks.service
    systemctl disable shadowsocks.service
    rm -rf ~/shadowsocks-tmp
    rm -rf /etc/ssh/sshd_config.d/01-ssh-hardening.conf
    rm -rf /etc/sysctl.d/01-shadowsocks-optimizer.conf
    rm -rf /etc/systemd/system/shadowsocks.service
    rm -rf /home/ssuser/shadowsocks-server.json
    systemctl daemon-reload
    sysctl --system
    setcap -r /usr/local/bin/ssserver
    rm -rf /usr/local/bin/sslocal
    rm -rf /usr/local/bin/ssmanager
    rm -rf /usr/local/bin/ssserver
    rm -rf /usr/local/bin/ssservice
    rm -rf /usr/local/bin/ssurl
    echo "Done!"
    exit 1
    ;;
  * )
    # Stop the script for any other input
    echo "Stopping the script..."
    exit 1
    ;;
esac
fi

# Ask whether to proceed
echo -e "
This script will reconfigure your environment and install shadowsocks on your server.
I am not responsible for any damages or data loss that may occur.

\033[33mDo you wish to continue? (Y/N)\033[0m
"
# User input
read -p "Your choice:" ANSWER
# Read input
case $ANSWER in
  [Yy]* )
    # Proceed with the rest of the script
    ;;
  * )
    # Stop the script for any other input
    echo "Stopping the script..."
    exit 1
    ;;
esac

# -----
# get shadowsocks
# -----

LATEST_VERSION=$(curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest | grep -Po '"tag_name":\s*"\K.*?(?=")')

if [ -z "$LATEST_VERSION" ]; then
    echo "Could not get the latest version of shadowsocks-rust. Stopping the script..."
    exit 1
fi

mkdir ~/shadowsocks-tmp
mkdir ~/shadowsocks-tmp/bin

cd ~/shadowsocks-tmp

curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest \
  | grep -Po '"tag_name":\s*"\K.*?(?=")' \
  | xargs -I % curl -L -O https://github.com/shadowsocks/shadowsocks-rust/releases/download/%/shadowsocks-%.x86_64-unknown-linux-gnu.tar.xz

tar -xf shadowsocks-*.x86_64-unknown-linux-gnu.tar.xz -C ~/shadowsocks-tmp/bin

mv ~/shadowsocks-tmp/bin/* /usr/local/bin/

rm -rf ~/shadowsocks-tmp

echo "Installed Shadowsocks to /usr/local/bin"

# -----
# sshd_config
# -----

echo -e "
\033[33mWould you like to disable SSH password authentication? (Recommended)\033[0m

--------------------------------------------------
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PermitEmptyPasswords no
--------------------------------------------------

1) Yes, disable SSH password authentication
2) No, skip this step
0) Exit
"
# User input
read -p "Your choice:" ANSWER
# Read input
case $ANSWER in
  1 ) 
mkdir -p /etc/ssh/sshd_config.d
if [ ! -e /etc/ssh/sshd_config.d/01-ssh-hardening.conf ]; then
  cat <<EOF > /etc/ssh/sshd_config.d/01-ssh-hardening.conf
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PermitEmptyPasswords no
EOF
  echo "Created /etc/ssh/sshd_config.d/01-ssh-hardening.conf"
else
  echo "/etc/ssh/sshd_config.d/01-ssh-hardening.conf already exists! Skipping..."
fi
    ;;
  2 ) 
    # Proceed with the rest of the script
    echo "Skipping..."
    ;;
  0 ) 
    # Exit the script
    echo "Stopping the script..."
    exit 1
    ;;
  * )
    # Stop the script for any other input
    echo "Invalid input, stopping the script..."
    exit 1
    ;;
esac

# -----
# sysctl
# -----

mkdir -p /etc/sysctl.d

if [ ! -e /etc/sysctl.d/01-shadowsocks-optimizer.conf ]; then
  cat <<EOF > /etc/sysctl.d/01-shadowsocks-optimizer.conf
# max open files
fs.file-max = 51200
# max read buffer
net.core.rmem_max = 67108864
# max write buffer
net.core.wmem_max = 67108864
# default read buffer
net.core.rmem_default = 65536
# default write buffer
net.core.wmem_default = 65536
# max processor input queue
net.core.netdev_max_backlog = 4096
# max backlog
net.core.somaxconn = 4096

# resist SYN flood attacks
net.ipv4.tcp_syncookies = 1
# reuse timewait sockets when safe
net.ipv4.tcp_tw_reuse = 1
# turn off fast timewait sockets recycling
net.ipv4.tcp_tw_recycle = 0
# short FIN timeout
net.ipv4.tcp_fin_timeout = 30
# short keepalive time
net.ipv4.tcp_keepalive_time = 1200
# outbound port range
net.ipv4.ip_local_port_range = 10000 65000
# max SYN backlog
net.ipv4.tcp_max_syn_backlog = 4096
# max timewait sockets held by system simultaneously
net.ipv4.tcp_max_tw_buckets = 5000
# turn on TCP Fast Open on both client and server side
net.ipv4.tcp_fastopen = 3
# TCP receive buffer
net.ipv4.tcp_rmem = 4096 87380 67108864
# TCP write buffer
net.ipv4.tcp_wmem = 4096 65536 67108864
# turn on path MTU discovery
net.ipv4.tcp_mtu_probing = 1

# for high-latency network
net.ipv4.tcp_congestion_control = hybla

# for low-latency network, use cubic instead
# net.ipv4.tcp_congestion_control = cubic
EOF
  echo "Created /etc/sysctl.d/01-shadowsocks-optimizer.conf"
else
  echo "/etc/sysctl.d/01-shadowsocks-optimizer.conf already exists! Skipping..."
fi

sysctl --system

# -----
# shadowsocks startup
# -----

mkdir -p /etc/systemd/system

if [ ! -e /etc/systemd/system/shadowsocks.service ]; then
  cat <<EOF > /etc/systemd/system/shadowsocks.service
[Unit]
Description=Shadowsocks Service
After=network.target

[Service]
Type=simple
User=ssuser
Group=ssuser
ExecStart=ssserver -c /home/ssuser/shadowsocks-server.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  echo "Created /etc/systemd/system/shadowsocks.service"
else
  echo "/etc/systemd/system/shadowsocks.service already exists! Skipping..."
fi

# -----
# shadowsocks permissions
# -----

setcap 'CAP_NET_BIND_SERVICE+ep' /usr/local/bin/ssserver

# this is so the non-root user can access ports below 1024
# routing perms can be acquired through 'CAP_NET_BIND_SERVICE,CAP_NET_ADMIN+ep'

# -----
# create ssuser (non-root user for shadowsocks)
# -----

if id "ssuser" &>/dev/null; then
  echo "User 'ssuser' already exists! Skipping..."
else
  useradd -m "ssuser"
  echo "User 'ssuser' created."
fi

# Prompt for and set the user's password
echo "Please enter a password for 'ssuser':"
passwd "ssuser"

# -----
# shadowsocks configuration file
# -----

if [ ! -e /home/ssuser/shadowsocks-server.json ]; then
  cat <<EOF > /home/ssuser/shadowsocks-server.json
{
  "server": "your_server_ip",
  "server_port": 8388,
  "password": "your_secure_password",
  "method": "chacha20-ietf-poly1305",
  "mode": "tcp_and_udp",
  "no_delay": true,
  "fast_open": true,
  "ipv6_first": false,
  // "timeout": 300,
  // "udp_timeout": 300,
  // "keep_alive": 60
}
EOF
  echo "Created /home/ssuser/shadowsocks-server.json"
else
  echo "/home/ssuser/shadowsocks-server.json Opening..."
fi

nano /home/ssuser/shadowsocks-server.json

systemctl daemon-reload
systemctl enable shadowsocks.service

# End of script
echo -e "
--------------------------------------------------
\033[32mIt's time to reboot!\033[0m
Shadowsocks configuration location: /home/ssuser/shadowsocks-server.json
--------------------------------------------------"
