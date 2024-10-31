#!/bin/bash

# Запитуємо у користувача SSID та пароль для хотспота
read -p "Введіть назву мережі (SSID): " SSID
read -s -p "Введіть пароль для мережі (не менше 8 символів): " PASSWORD
echo

# Перевірка довжини пароля
if [ ${#PASSWORD} -lt 8 ]; then
    echo "Пароль повинен бути не менше 8 символів!"
    exit 1
fi

# Підготовка системи та встановлення необхідних пакетів
apt update
apt install -y hostapd dnsmasq iptables

# Зупиняємо сервіси, щоб налаштувати їх з нуля
systemctl stop hostapd
systemctl stop dnsmasq

# Створення інтерфейсу wlan0_ap та призначення IP
echo "Налаштування інтерфейсу wlan0_ap..."
iw dev wlan0 interface add wlan0_ap type __ap
ip addr add 192.168.10.1/24 dev wlan0_ap
ip link set wlan0_ap up

# Налаштування hostapd
cat <<EOF > /etc/hostapd/hostapd.conf
interface=wlan0_ap
driver=nl80211
ssid=$SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF


sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Налаштування dnsmasq для DHCP
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
cat <<EOF > /etc/dnsmasq.conf
interface=wlan0_ap
dhcp-range=192.168.10.50,192.168.10.150,12h
server=8.8.8.8
server=8.8.4.4
EOF

# Увімкнення форвардингу IP
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Налаштування iptables для NAT
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sh -c "iptables-save > /etc/iptables.ipv4.nat"

# Запуск та увімкнення сервісів
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
systemctl start hostapd
systemctl start dnsmasq

echo "Налаштування завершено. Хотспот повинен працювати."
