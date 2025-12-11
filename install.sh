#!/usr/bin/env bash
set -euo pipefail

host=""
port=""
user=""
password=""
trusted_cert=""
autostart="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --host)
      host="$2"
      shift 2
      ;;
    --port)
      port="$2"
      shift 2
      ;;
    --user)
      user="$2"
      shift 2
      ;;
    --password)
      password="$2"
      shift 2
      ;;
    --trusted-cert)
      trusted_cert="$2"
      shift 2
      ;;
    --autostart)
      autostart="true"
      shift 1
      ;;
    --prompt-password)
      read -rsp "Password: " password
      echo
      shift 1
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [ -z "$host" ] || [ -z "$port" ] || [ -z "$user" ]; then
  echo "Missing required options: --host, --port, --user"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openfortivpn

mkdir -p /etc/openfortivpn
tmp_config="/etc/openfortivpn/config"
{
  echo "host = $host"
  echo "port = $port"
  echo "username = $user"
  if [ -n "$password" ]; then echo "password = $password"; fi
  if [ -n "$trusted_cert" ]; then echo "trusted-cert = $trusted_cert"; fi
} > "$tmp_config"
chmod 600 "$tmp_config"
chown root:root "$tmp_config"

if [ "$autostart" = "true" ]; then
  unit_path="/etc/systemd/system/openfortivpn.service"
  cat > "$unit_path" <<EOF
[Unit]
Description=OpenFortiVPN
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/openfortivpn --config /etc/openfortivpn/config
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable openfortivpn.service
  systemctl start openfortivpn.service
fi

echo "Installed openfortivpn and wrote /etc/openfortivpn/config"
if [ "$autostart" = "true" ]; then
  echo "Enabled systemd service openfortivpn.service"
fi
echo "Connect manually with: sudo openfortivpn --config /etc/openfortivpn/config"
