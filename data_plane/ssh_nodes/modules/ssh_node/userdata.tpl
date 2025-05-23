#!/bin/bash
sudo hostnamectl set-hostname ${hostname}
curl https://goteleport.com/static/install.sh | bash -s ${teleport_version} enterprise

echo ${token} > /tmp/token
cat<<EOF >/etc/teleport.yaml
version: v3
teleport:
  auth_token: /tmp/token
  proxy_server: ${proxy_address}:443
  data_dir: /var/lib/teleport
  log:
    output: stderr
    severity: INFO
    format:
      output: text
ssh_service:
  enabled: true
  labels:
    env: ${hostname}
    os: linux
  commands:
    - name: "hostname"
      command: ["/bin/hostname"]
      period: "1m0s"
    - name: "uptime"
      command: ["uptime"]
      period: "1m0s"
proxy_service:
  enabled: false
auth_service:
  enabled: false
EOF

systemctl enable teleport
systemctl start teleport
