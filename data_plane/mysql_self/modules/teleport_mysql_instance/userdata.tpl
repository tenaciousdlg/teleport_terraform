#!/bin/bash
set -e

# Set hostname
sudo hostnamectl set-hostname "${env}-mysql"

# System prep
sudo apt update && sudo apt upgrade -y
sudo apt install -y mariadb-server mariadb-client jq

sudo systemctl enable mariadb
sudo systemctl start mariadb

# Secure installation (default answers piped in)
sudo mysql_secure_installation <<EOF

y
n
y
y
y
y
EOF

# Install Teleport
curl https://goteleport.com/static/install.sh | bash -s "${major}" "enterprise"

# Write teleport.yaml
sudo tee /etc/teleport.yaml > /dev/null <<EOF
version: v3
teleport:
  data_dir: "/var/lib/teleport"
  proxy_server: "${domain}:443"
  auth_token: "${token}"
  log:
    output: stderr
    severity: INFO
    format:
      output: text
db_service:
  enabled: true
  resources:
    - labels:
        match:
          - tier=${env}
auth_service:
  enabled: "no"
ssh_service:
  enabled: "yes"
  labels:
    tier: ${env}
proxy_service:
  enabled: "no"
app_service:
  enabled: "no"
EOF

# TLS setup for MySQL
sudo mkdir -p /etc/mysql/ssl
echo "${ca}"      | sudo tee /etc/mysql/ssl/server.cas > /dev/null
echo "${tele_ca}" | sudo tee -a /etc/mysql/ssl/server.cas > /dev/null
echo "${cert}"    | sudo tee /etc/mysql/ssl/server.crt > /dev/null
echo "${key}"     | sudo tee /etc/mysql/ssl/server.key > /dev/null

# MySQL TLS config
sudo tee /etc/mysql/conf.d/mysql.cnf > /dev/null <<EOF
[mariadb]
require_secure_transport=ON
ssl-ca=/etc/mysql/ssl/server.cas
ssl-cert=/etc/mysql/ssl/server.crt
ssl-key=/etc/mysql/ssl/server.key
log_error=/var/log/mysql/mysqld.log
EOF

# Create cert-authenticated users
sudo mysql -u root -e "CREATE USER 'writer'@'%' REQUIRE SUBJECT '/CN=writer';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'writer'@'%';"
sudo mysql -u root -e "CREATE USER 'reader'@'%' REQUIRE SUBJECT '/CN=reader';"
sudo mysql -u root -e "GRANT SELECT, SHOW VIEW ON *.* TO 'reader'@'%';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

# Restart services
sudo systemctl restart mariadb
sudo systemctl enable teleport
sudo systemctl restart teleport
