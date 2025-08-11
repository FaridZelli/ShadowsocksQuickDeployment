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
https://github.com/FaridZelli/ShadowsocksQuickDeployment

This script installs Shadowsocks on your \033[33mUbuntu 24.04\033[0m server.

By typing Y and pressing Enter, you agree that the author
bears no liability for any loss, damage or data corruption,
whether direct, indirect, incidental, consequential or punitive,
that may result from its use.

Continued use assumes your acceptance of these terms.

\033[33mAre you sure you want to remove all files previously created by this script? (Y/N)\033[0m
"
# User input
read -p "Your choice:" ANSWER
# Read input
case $ANSWER in
  [Yy]* )
    # Proceed to uninstall
    echo -e "
--------------------------------------------------
\033[31mUninstalling...\033[0m
--------------------------------------------------"
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
    echo -e "
--------------------------------------------------
Done!
--------------------------------------------------"
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
https://github.com/FaridZelli/ShadowsocksQuickDeployment

This script installs Shadowsocks on your \033[33mUbuntu 24.04\033[0m server.

By typing Y and pressing Enter, you agree that the author
bears no liability for any loss, damage or data corruption,
whether direct, indirect, incidental, consequential or punitive,
that may result from its use.

Continued use assumes your acceptance of these terms.

\033[33mDo you wish to continue? (Y/N)\033[0m
"
# User input
read -p "Your choice:" ANSWER
# Read input
case $ANSWER in
  [Yy]* )
    # Proceed with the rest of the script
    echo -e "
--------------------------------------------------
Starting...
--------------------------------------------------"
    ;;
  * )
    # Stop the script for any other input
    echo "Stopping the script..."
    exit 1
    ;;
esac

# -----
# sshd_config
# -----

echo -e "
\033[33mWould you like to disable SSH password authentication?
This step is only recommended if you have already setup your public key.\033[0m

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
  echo "
  Created /etc/ssh/sshd_config.d/01-ssh-hardening.conf"
else
  echo "
  /etc/ssh/sshd_config.d/01-ssh-hardening.conf already exists! Skipping..."
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
# detect environment
# -----

# Function to detect system architecture
detect_arch() {
    local machine=$(uname -m)
    case "$machine" in
        aarch64|arm64) ARCH="aarch64" ;;
        arm) ARCH="arm" ;;
        armv7l) ARCH="armv7" ;;
        i686|x86) ARCH="i686" ;;
        loongarch64) ARCH="loongarch64" ;;
        mips) ARCH="mips" ;;
        mips64el) ARCH="mips64el" ;;
        mipsel) ARCH="mipsel" ;;
        riscv64) ARCH="riscv64gc" ;;
        x86_64) ARCH="x86_64" ;;
        *) ARCH="unknown" ;;
    esac
}

# Function to detect C library type
detect_libc() {
    # Check for musl first
    if ldd --version 2>&1 | grep -q "musl"; then
        # Determine specific musl variant
        local libc=$(ldd --version 2>&1)
        if [[ "$libc" == *"musleabi"* ]]; then
            C_LIBRARY="musleabi"
        elif [[ "$libc" == *"musleabihf"* ]]; then
            C_LIBRARY="musleabihf"
        else
            C_LIBRARY="musl"
        fi
    else
        # If not musl, assume GNU
        local libc=$(ldd --version 2>&1)
        if [[ "$libc" == *"gnueabi"* ]]; then
            C_LIBRARY="gnueabi"
        elif [[ "$libc" == *"gnueabihf"* ]]; then
            C_LIBRARY="gnueabihf"
        elif [[ "$libc" == *"gnuabi64"* ]]; then
            C_LIBRARY="gnuabi64"
        else
            C_LIBRARY="gnu"
        fi
    fi
}

# Detect architecture and C library
detect_arch
detect_libc

# Print detected values (optional)
echo "
Detected System Architecture: $ARCH
Detected System C Library: $C_LIBRARY"

# -----
# get shadowsocks
# -----

LATEST_VERSION=$(curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest | grep -Po '"tag_name":\s*"\K.*?(?=")')

download_failed() {
    read -p "
We are unable to download the latest shadowsocks-rust release from GitHub at this time.
If you have already downloaded Shadowsocks binaries locally, please enter the directory in which they are stored: " dir

    # Check if directory exists
    if [[ ! -d "$dir" ]]; then
      echo "Error: Directory '$dir' does not exist, stopping the script..."
      exit 1
    fi

    # Get list of files
    files=("$dir"/*)
    if [[ ${#files[@]} -eq 0 ]]; then
      echo "Error: Directory '$dir' is empty, stopping the script..."
      exit 1
    fi

    echo "Select a file from the list below:"
    echo "0) Exit"
    index=1
    for filepath in "${files[@]}"; do
      echo "$index) $(basename "$filepath")"
      ((index++))
    done

    read -p "Enter your choice [0-${#files[@]}]: " choice

    if [[ "$choice" -eq 0 ]]; then
      echo "No archive selected, stopping the script..."
      exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 || choice > ${#files[@]} )); then
      echo "Invalid choice, stopping the script..."
      exit 1
    fi

    # Extract selected archive
    SHADOWSOCKS_LOCAL_ARCHIVE="${files[$((choice-1))]}"
    echo "
Selected archive: $SHADOWSOCKS_LOCAL_ARCHIVE"
    tar -xf $SHADOWSOCKS_LOCAL_ARCHIVE -C /usr/local/bin
    echo "
Installed Shadowsocks to /usr/local/bin"
}

if [ -z "$LATEST_VERSION" ]; then
    download_failed
else
    echo "Latest Shadowsocks release: $LATEST_VERSION
    "
    mkdir -p ~/shadowsocks-tmp
    curl -Lo ~/shadowsocks-tmp/shadowsocks-bin.tar.xz \
    https://github.com/shadowsocks/shadowsocks-rust/releases/download/${LATEST_VERSION}/shadowsocks-${LATEST_VERSION}.${ARCH}-unknown-linux-${C_LIBRARY}.tar.xz \
    && tar -xf ~/shadowsocks-tmp/shadowsocks-bin.tar.xz -C /usr/local/bin \
    || download_failed
    rm -rf ~/shadowsocks-tmp
    echo "
Installed Shadowsocks to /usr/local/bin"
fi

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
  echo "
Created /etc/sysctl.d/01-shadowsocks-optimizer.conf"
else
  echo "
/etc/sysctl.d/01-shadowsocks-optimizer.conf already exists! Skipping..."
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
  echo "
Created /etc/systemd/system/shadowsocks.service"
else
  echo "
/etc/systemd/system/shadowsocks.service already exists! Skipping..."
fi

# -----
# shadowsocks permissions
# -----

setcap 'CAP_NET_BIND_SERVICE+ep' /usr/local/bin/ssserver

echo "
Granted ssserver permission to bind to low-numbered (privileged) network ports."

# this is so the non-root user can access ports below 1024
# routing perms can be acquired through 'CAP_NET_BIND_SERVICE,CAP_NET_ADMIN+ep'

# -----
# create ssuser (non-root user for shadowsocks)
# -----

if id "ssuser" &>/dev/null; then
  echo "
User 'ssuser' already exists! Skipping..."
else
  useradd -m "ssuser"
  echo "
User 'ssuser' created."
fi

# Prompt for and set the user's password
echo "
Please enter a password for 'ssuser':"
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
  echo "
Created /home/ssuser/shadowsocks-server.json"
else
  echo "
Opening /home/ssuser/shadowsocks-server.json"
fi

nano /home/ssuser/shadowsocks-server.json

systemctl daemon-reload
systemctl enable shadowsocks.service

echo "
Started shadowsocks.service"

# End of script
echo -e "
--------------------------------------------------
\033[32mIt's time to reboot!\033[0m
Your Shadowsocks configuration is located at:
/home/ssuser/shadowsocks-server.json
--------------------------------------------------"
