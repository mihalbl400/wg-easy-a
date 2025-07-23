#!/bin/bash

apt update
apt install git curl wget -y

if [ -x "$(command -v docker)" ]; then
    echo "Docker installed"
    docker stop wg-easy
    docker rm wg-easy
    # command
else
    echo "Docker install"
    bash <(curl -sSL https://get.docker.com)
    # command
fi

rm -rf /opt/wg-easy/

cd /opt/

git clone https://github.com/wg-easy/wg-easy.git
cd ./wg-easy/

[ -f .env ] && rm .env
echo "PUID=1000" >> .env
echo "PGID=1000" >> .env
echo "TZ=Etc/UTC" >> .env
echo "WG_HOST=" >> .env
echo "WG_PORT=" >> .env
echo "PORT=" >> .env
echo "WG_CONFIG_PORT=" >> .env
echo "WG_PERSISTENT_KEEPALIVE=25" >> .env
echo "WG_DEFAULT_DNS=" >> .env
echo "WG_DEFAULT_ADDRESS=" >> .env
echo "LANG=en" >> .env


extaddr=$(curl -s https://checkip.amazonaws.com)

read -rp "External IP: " -e -i $extaddr WG_HOST
read -rp "WG port: " -e -i "61820" WG_PORT
read -rp "WG WebUI port: " -e -i "61821" WG_UI_PORT
read -rp "Password: " -e -i "foobar12345#" WG_UI_PASSWORD
read -rp "Default DNS: " -e -i "208.67.222.2, 208.67.220.2" WG_DEFAULT_DNS
read -rp "Default address: " -e -i "10.14.13.x" WG_DEFAULT_ADDRESS

sed -i 's:^WG_HOST=.*:WG_HOST='${WG_HOST}':' ./.env

sed -i 's:^WG_PORT=.*:WG_PORT='${WG_PORT}':' ./.env
sed -i 's:^WG_CONFIG_PORT=.*:WG_CONFIG_PORT='${WG_PORT}':' ./.env
sed -i 's:^PORT=.*:PORT='${WG_UI_PORT}':' ./.env


sed -i '/WG_DEFAULT_DNS/d' ./.env
echo "WG_DEFAULT_DNS=$WG_DEFAULT_DNS" >> ./.env

sed -i '/WG_DEFAULT_ADDRESS/d' ./.env
echo "WG_DEFAULT_ADDRESS=$WG_DEFAULT_ADDRESS" >> ./.env

docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$WG_UI_PASSWORD" >> ./.env

[ -f docker-compose.yml ] && rm docker-compose.yml

cat <<EOF > docker-compose.yml
volumes:
  etc_wireguard:

services:
  wg-easy:
    env_file: ./.env
    image: ghcr.io/wg-easy/wg-easy:nightly
    container_name: wg-easy
    volumes:
      - etc_wireguard:/etc/wireguard
    ports:
      - "\${WG_PORT}:\${WG_PORT}/udp"
      - "\${PORT}:\${PORT}/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
      # - NET_RAW # ⚠️ Uncomment if using Podman 
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
EOF

docker compose up -d --build

echo -e "Your VPN URL: http://$WG_HOST:$WG_UI_PORT"
echo -e "Password: $WG_UI_PASSWORD"
