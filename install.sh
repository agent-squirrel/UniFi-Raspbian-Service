#!/bin/bash

#Check for super user
if [ "$EUID" -ne 0 ]
  then echo 'This script can only be run as the super user.
Try rerunning with sudo.'
echo
[[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

#Begin environment setup
distro=""
hostname=unifi
ipaddr=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')


clear
release=$(cat /etc/*release | grep NAME)
if [[ $release == *Raspbian* ]]; then
  distro=Raspbian
else
  distro=Other
fi
echo
echo -e "\e[0m#########################################################################
#                                                                       \e[0m#
#                  \e[94mKM                       \e[90m,ok0KNWW                    \e[0m#
#                        \e[94mKM               \e[90m:NMMMMMMMM                    \e[0m#
#                       \e[94mKM  ..             \e[90mWMMMMMMMMM                   \e[0m#
#                   \e[94mKM      KM             \e[90mWMMMMMMMMM                   \e[0m#
#                   \e[94mKM    KM               \e[90mWMMMMMMMMM                   \e[0m#
#                   \e[94mKM  KM  ..             \e[90mWMMMMMMMMM                   \e[0m#
#                   \e[94mKM  ..  KM             \e[90mWMMMMMMMMM                   \e[0m#
#                   \e[94mKM  KM  KM             \e[90mWMMMMMMMMM                   \e[0m#
#                   \e[94mKMNXWM  KM             \e[90mWMMMMMMMMK                   \e[0m#
#                   \e[94mKMMMMMKONM             \e[90mWMMMMMMMW                    \e[0m#
#                   \e[94mKMMMMMMMMM             \e[90mWMMMMMMM x                   \e[0m#
#                   \e[94mlMMMMMMMMM             \e[90mWMMMMMN xK                   \e[0m#
#                    \e[94mMMMMMMMMMl           \e[34m,WMMMP dXM:                   \e[0m#
#                    \e[94mlMMMMMMMMx .        \e[34m,,,aaadXMMd                    \e[0m#
#                     \e[94mlNMMMMMMW: \e[34mXOxolcclodOKMMMMWc                     \e[0m#
#                       \e[94mlXMMMMMNc \e[34mlMMMMMMMMMMMMNo.                      \e[0m#
#                         \e[94mllONMMM0c \e[34mlMMMMMMNOo'                         \e[0m#
#                              \e[94m'lMN;. \e[34mlMWl'                             \e[0m#
#                                                                       \e[0m#
#             \e[0mUniFi Controller as a Linux Service Installer             \e[0m#
\e[0m#########################################################################"
echo
echo "                        Operating System: $distro"
echo "                        IP Address: $ipaddr      "
echo
if [[ $distro != Raspbian ]]; then
  echo "This script can only currently run on Raspbian."
  echo "Please download it here https://downloads.raspberrypi.org/raspbian_lite_latest"
  echo
  [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi
echo
echo "This script sets up the Ubiquiti UniFi controller on Raspberry Pi as a service.
This is in place of an Ubiquiti UniFi Cloud Key.
The script also creates a reverse proxy so navigating to the controller can be done without port numbers."
echo
read -p "Begin Unifi Install? [Y/N]" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  echo
  [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi
echo
echo "Setting GPU Memory Split"
sed -i.bak '/gpu_mem/d' /boot/config.txt
echo "gpu_mem=16" >> /boot/config.txt
echo
echo "Resizing ROOT File System"
/usr/bin/raspi-config --expand-rootfs
echo
echo "Setting Hostname"
echo
read -p "Please enter a hostname [unifi]: " hostname
if [[ -z "$hostname" ]];
then
  hostname=unifi
fi
echo
echo "Updating System"
apt-get update && apt-get upgrade -y && apt-get install raspi-config -y
echo
echo "Configuring SSH"
apt-get install ssh -y && systemctl start ssh && systemctl enable ssh
echo
echo "Updating Raspberry Pi Firmware"
apt-get install rpi-update && echo Y | rpi-update
echo
echo "Adding UniFi Repository"
apt-get update && apt-get install dirmngr -y
echo 'deb http://www.ubnt.com/downloads/unifi/debian stable ubiquiti' | tee -a /etc/apt/sources.list.d/ubnt.list > /dev/null
apt-key adv --keyserver keyserver.ubuntu.com --recv C0A52C50
apt-get update
echo
echo "Installing UniFi"
apt-get install unifi oracle-java8-jdk -y
systemctl disable mongodb && systemctl stop mongodb
systemctl enable unifi
echo
echo "Configuring Reverse Proxy"
apt-get install nginx -y
rm /etc/nginx/sites-enabled/default
touch /etc/nginx/sites-available/unifi
cat <<EOT >> /etc/nginx/sites-available/unifi
server  {
        listen 80 default_server;
        location / {
                proxy_pass https://localhost:8443;
                proxy_buffering off;
                proxy_http_version 1.1;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection $http_connection;
                access_log off;
                }

        }
EOT
ln -s /etc/nginx/sites-available/unifi /etc/nginx/sites-enabled/unifi
systemctl restart nginx && systemctl enable nginx
echo
echo
echo "Setup Complete."
echo "After rebooting, the controller will be available at http://$ipaddr"
echo
read -p "Reboot Now? [Y/N]" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
  echo
  [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi
reboot
