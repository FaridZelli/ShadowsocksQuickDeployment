# 🌍 Shadowsocks Quick Deployment
Get [shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust) up and running on your server in less than a minute.
   
ⓘ This script must be run as **root**.
   
  ```
  curl -o ~/shadowsocks_deploy.sh https://raw.githubusercontent.com/FaridZelli/ShadowsocksQuickDeployment/refs/heads/main/shadowsocks_deploy.sh && chmod a+x ~/shadowsocks_deploy.sh && ~/shadowsocks_deploy.sh ; rm -f ~/shadowsocks_deploy.sh
  ```
> Run the script with the `-u` parameter to uninstall.

## 💡 Features:
- Interactive installer
- Architecture auto-detection
- Performance optimization
- Shadowsocks service run by unprivileged user
- Access to privileged network ports (<1024)

## 🛣️ Future Roadmap
- [ ] Security audit
- [ ] WARP deployment
