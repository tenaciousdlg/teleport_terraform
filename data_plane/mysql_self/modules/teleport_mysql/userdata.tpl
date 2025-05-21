#!/bin/bash
#########################################################
# System Prep and MySQL Installation
#########################################################
sudo hostnamectl set-hostname "mysql"
sudo apt update && sudo apt upgrade -y
sudo apt install -y mariadb-server mariadb-client jq

sudo systemctl enable mariadb
sudo systemctl start mariadb

sudo mysql_secure_installation <<EOF
y
n
y
y
y
y
EOF

#########################################################
# Teleport Installation
#########################################################
curl https://goteleport.com/static/install.sh | bash -s "${major}" "enterprise"

#########################################################
# Teleport Configuration
#########################################################
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
    labels:
      match:
        - env=${env}

auth_service:
  enabled: "no"

ssh_service:
  enabled: "true"
  labels:
    env: ${env}
    tier: db

proxy_service:
  enabled: "no"
app_service:
  enabled: "no"
EOF

#########################################################
# SSL Certificate Installation for MySQL
#########################################################
sudo mkdir -p /etc/mysql/ssl
sudo tee /etc/mysql/ssl/server.cas > /dev/null <<EOF
${ca}
${tele_ca}
EOF

sudo tee /etc/mysql/ssl/server.crt > /dev/null <<EOF
${cert}
EOF

sudo tee /etc/mysql/ssl/server.key > /dev/null <<EOF
${key}
EOF

#########################################################
# MySQL Configuration for SSL + Teleport DB Users
#########################################################
sudo tee /etc/mysql/conf.d/mysql.cnf > /dev/null <<EOF
[mariadb]
require_secure_transport=ON
ssl-ca=/etc/mysql/ssl/server.cas
ssl-cert=/etc/mysql/ssl/server.crt
ssl-key=/etc/mysql/ssl/server.key

log_error=/var/log/mysql/mysqld.log
EOF

sudo mysql -u root -e "CREATE USER 'alice'@'%' REQUIRE SUBJECT '/CN=alice';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'alice'@'%';"
sudo mysql -u root -e "CREATE USER 'bob'@'%' REQUIRE SUBJECT '/CN=bob';"
sudo mysql -u root -e "GRANT SELECT, SHOW VIEW ON *.* TO 'bob'@'%';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb
sudo systemctl enable teleport
sudo systemctl restart teleport
