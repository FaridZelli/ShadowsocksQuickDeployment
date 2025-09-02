# 🌍 Shadowsocks Quick Deployment
Get [shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust) up and running on your server in less than 60 seconds.
   
ⓘ This script must be run as **root**.
   
  ```
  curl -o ~/shadowsocks_deploy.sh https://raw.githubusercontent.com/FaridZelli/ShadowsocksQuickDeployment/refs/heads/main/shadowsocks_deploy.sh && chmod a+x ~/shadowsocks_deploy.sh && ~/shadowsocks_deploy.sh ; rm -f ~/shadowsocks_deploy.sh
  ```
> Run the script with the `-u` parameter to uninstall.

## 📝 What does this script do?
1. Fetches the latest Shadowsocks release for your hardware
2. Installs Shadowsocks as a service and provides an optimized default environment for ssserver

## 💡 Features

- [X] System architecture and C Library detection
- [X] SSH hardening
- [X] Network optimization via sysctl
- [X] Service unit as non-root user
- [X] Interactive Shadowsocks configuration
- [X] Password generation

## 🐧 Supported Distributions
While this script has only been tested on **Ubuntu 24.04**, it should work on most Ubuntu/Debian-based distros.

## 🧑‍💻 Raspberry Pi Passwall2 Gateway
To setup Shadowsocks on your home network, you'll need:
- A device running [OpenWrt](https://openwrt.org/) (in this example, a Raspberry Pi)
- [Passwall2](https://github.com/xiaorouji/openwrt-passwall2)

There are generally two ways to approach this:

<details><summary><b>Modem-Router <> Pi</b><br>ⓘ Simple, half-bandwidth, no dongle required<br>(click to expand)</summary>

---

1. Install the latest [OpenWrt release](https://openwrt.org/toh/raspberry_pi_foundation/raspberry_pi#installation) on your Raspberry Pi using [Raspberry Pi Imager](https://github.com/raspberrypi/rpi-imager/releases)
- If you're on Linux, resize the root filesystem:
```
# Identify the block device and partition number; e.g. /dev/sdxN
lsblk

# Resize the root partition
cfdisk /dev/sdx

# Update the filesystem
e2fsck -f /dev/sdxN
resize2fs /dev/sdxN
```
2. Directly connect to your Pi using an ethernet cable and login to LuCI at 192.168.1.1
3. Configure the LAN Interface to obtain an IP Address from the primary router
- Network > Interfaces > Lan > Edit > Choose "Static Address"
- Change the device to "eth0"
- Set a valid static IPv4 address and your router's IP as the gateway / DNS
4. Apply changes and connect the Pi to your router  
- If OpenWrt's repositories are blocked, switch to a [mirror](https://openwrt.org/downloads#mirrors) via:  
- System > Software > Configure opkg
5. SSH into your Pi as root using the static IP address:
```
ssh root@192.168.X.X
```
6. Run the following commands:
> Replace `netcologne` with your desired mirror
```
read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF
for feed in passwall_packages passwall_luci passwall2; do
echo "src/gz $feed https://netcologne.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done
```
```
wget -O passwall.pub https://netcologne.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub && opkg-key add passwall.pub
```
```
opkg update && opkg remove dnsmasq && opkg install dnsmasq-full kmod-nft-tproxy kmod-nft-socket luci-app-passwall2
```
7. Reboot your Pi, configure Shadowsocks and DoH via Services > Passwall2
8. Configure the Raspberry Pi as the default gateway and LAN DNS provider on your router

---

</details>

<details><summary><b>Modem-Router > Pi > Router</b><br>ⓘ More flexible, full-bandwidth, harder to setup<br>(click to expand)</summary>

---

Note: You'll need a USB 3.0 to gigabit ethernet adapter  
[AX88179 adapters](https://openwrt.org/toh/raspberry_pi_foundation/raspberry_pi#adding_a_usb_to_ethernet_adapter) such as the TP-Link UE306 are known to work well

1. Install the latest [OpenWrt release](https://openwrt.org/toh/raspberry_pi_foundation/raspberry_pi#installation) on your Raspberry Pi using [Raspberry Pi Imager](https://github.com/raspberrypi/rpi-imager/releases)
- If you're on Linux, resize the root filesystem:
```
# Identify the block device and partition number; e.g. /dev/sdxN
lsblk

# Resize the root partition
cfdisk /dev/sdx

# Update the filesystem
e2fsck -f /dev/sdxN
resize2fs /dev/sdxN
```
2. Directly connect to your Pi using an ethernet cable and login to LuCI at 192.168.1.1
3. Configure the LAN Interface to obtain an IP Address from the modem-router
- Network > Interfaces > Lan > Edit > Choose "Static Address"
- Change the device to "eth0"
- Set a valid static IPv4 address and your modem-router's IP as the gateway / DNS
4. Apply changes and connect the Pi to your modem-router  
- If OpenWrt's repositories are blocked, switch to a [mirror](https://openwrt.org/downloads#mirrors) via:  
- System > Software > Configure opkg
5. SSH into your Pi as root using the static IP address:
```
ssh root@192.168.X.X
```
6. Run the following commands:
> Replace `netcologne` with your desired mirror
```
read release arch << EOF
$(. /etc/openwrt_release ; echo ${DISTRIB_RELEASE%.*} $DISTRIB_ARCH)
EOF
for feed in passwall_packages passwall_luci passwall2; do
echo "src/gz $feed https://netcologne.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-$release/$arch/$feed" >> /etc/opkg/customfeeds.conf
done
```
```
wget -O passwall.pub https://netcologne.dl.sourceforge.net/project/openwrt-passwall-build/passwall.pub && opkg-key add passwall.pub
```
```
opkg update && opkg remove dnsmasq && opkg install dnsmasq-full kmod-nft-tproxy kmod-nft-socket luci-app-passwall2
```
- Install the appropiate [kernel module](https://openwrt.org/toh/raspberry_pi_foundation/raspberry_pi#adding_a_usb_to_ethernet_adapter) for your ethernet adapter  
- For example:
```
opkg install kmod-usb-net-asix-ax88179
```
7. Reboot your Pi, configure Shadowsocks and DoH via Services > Passwall2
8. Head back over to Network > Interfaces and create a new interface:
- Name: wan
- Device: eth0
- Type: DHCP Client
9. Verify that everything is detected and working properly. Now, it's time to make the switch:
- Change the "lan" interface device from "eth0" to "eth1", leaving the gateway blank
- Change the "wan" interface device from "eth1" to "eth0"
  
> If you've done everything correctly, you should be able to save and apply the changes without any warnings
10. Connect the dongle to your router

---

</details>
