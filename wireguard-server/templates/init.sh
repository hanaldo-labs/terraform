#!/bin/bash
set -euo pipefail

dnf update -y
dnf remove -y docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-engine \
  podman \
  runc || true

dnf install -y docker iptables
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/v2.39.4/docker-compose-linux-aarch64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

systemctl enable --now docker
usermod -aG docker ec2-user

cat >/etc/sysctl.d/99-wireguard-nat.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.src_valid_mark=1
EOF
sysctl --system

mkdir -p /etc/docker/containers/wg-easy
cat >/etc/docker/containers/wg-easy/docker-compose.yml <<'EOF'
${docker_compose}
EOF

cat >/usr/local/sbin/wireguard-nat-rules.sh <<'EOF'
#!/bin/bash
set -euo pipefail

iptables -t nat -C POSTROUTING -o eth0 -s ${vpc_cidr} -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o eth0 -s ${vpc_cidr} -j MASQUERADE
iptables -t nat -C POSTROUTING -o eth0 -s ${wireguard_ipv4_cidr} -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o eth0 -s ${wireguard_ipv4_cidr} -j MASQUERADE
iptables -C FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -C FORWARD -i eth0 -o eth0 -s ${vpc_cidr} -j ACCEPT 2>/dev/null || \
  iptables -A FORWARD -i eth0 -o eth0 -s ${vpc_cidr} -j ACCEPT
if ip link show wg0 >/dev/null 2>&1; then
  iptables -C FORWARD -i wg0 -o eth0 -s ${wireguard_ipv4_cidr} -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i wg0 -o eth0 -s ${wireguard_ipv4_cidr} -j ACCEPT
fi
EOF
chmod +x /usr/local/sbin/wireguard-nat-rules.sh

cat >/etc/systemd/system/wireguard-nat-rules.service <<'EOF'
[Unit]
Description=WireGuard NAT iptables rules
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/wireguard-nat-rules.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now wireguard-nat-rules.service

cd /etc/docker/containers/wg-easy
docker compose up -d
