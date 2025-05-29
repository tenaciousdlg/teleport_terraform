#!/bin/bash
set -euxo pipefail
# updates ec2 hostname 
hostnamectl set-hostname "${name}"
# installs docker and jq used later in the script
dnf install -y docker jq
systemctl enable docker
systemctl start docker
# sets up grafana for jwt auth from teleport
mkdir -p /opt/grafana/{provisioning,dashboards,data}
cat <<EOT > /opt/grafana/grafana.ini
[paths]
provisioning = /etc/grafana/provisioning

[server]
enable_gzip = true
root_url = https://grafana.${env}.${proxy_address}

[security]
allow_embedding = true
admin_user = ${user}

[users]
default_theme = dark

[auth.basic]
enabled = false

[auth.jwt]
enabled = true
header_name = Teleport-Jwt-Assertion
email_claim = sub
username_claim = sub
jwk_set_url = https://${proxy_address}/.well-known/jwks.json
auto_sign_up = true
EOT

cd /opt/grafana
docker run -d \
  --name=grafana \
  -p 3000:3000 \
  --restart=always \
  -v /opt/grafana/grafana.ini:/etc/grafana/grafana.ini \
  -v /opt/grafana/provisioning:/etc/grafana/provisioning \
  -v /opt/grafana/dashboards:/etc/grafana/dashboards \
  -v /opt/grafana/data:/var/lib/grafana \
  grafana/grafana
# install teleport
curl https://goteleport.com/static/install.sh | bash -s ${teleport_version} enterprise

cat <<EOF > /etc/teleport.yaml
version: v3
teleport:
  data_dir: "/var/lib/teleport"
  auth_token: "/tmp/token"
  proxy_server: ${proxy_address}:443
  log:
    output: stderr
    severity: INFO
    format:
      output: text
app_service:
  enabled: true
  resources:
    - labels:
        "teleport.dev/app": "grafana"
  apps:
    - name: grafana
      uri: "http://localhost:3000"
      public_addr: grafana.${env}.${proxy_address}
      rewrite:
        headers:
        - "Host: grafana.${env}.${proxy_address}"
        - "Origin: https://grafana.${env}.${proxy_address}"
      insecure_skip_verify: true
ssh_service:
  enabled: true
  labels:
    tier: "${env}"
  commands:
    - name: "hostname"
      command: ["/bin/hostname"]
      period: "1m0s"
    - name: "uptime"
      command: ["/usr/bin/uptime"]
      period: "30s"
auth_service:
  enabled: false
proxy_service:
  enabled: false
EOF

echo "${token}" > /tmp/token
systemctl enable teleport
systemctl restart teleport