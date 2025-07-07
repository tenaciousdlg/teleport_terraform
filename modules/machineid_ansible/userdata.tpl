#!/bin/bash
#cloud-config
set -euo pipefail
bash -x 

hostnamectl set-hostname "${env}-ansible"

yum update -y
yum install -y jq python3 python3-pip git

# Install Ansible
pip3 install ansible

# Install Teleport
curl https://goteleport.com/static/install.sh | bash -s "${teleport_version}" "enterprise"
echo "${node_token}" > /tmp/token

# Write teleport.yaml
cat <<-EOF > /etc/teleport.yaml
version: v3
teleport:
  data_dir: "/var/lib/teleport"
  proxy_server: "${proxy_address}:443"
  auth_token: "/tmp/token"
  log:
    output: stderr
    severity: INFO
    format:
      output: text
ssh_service:
  enabled: true
  labels:
    tier: ${env}
    team: engineering
auth_service:
  enabled: false
proxy_service:
  enabled: false
db_service:
  enabled: false
EOF

systemctl enable teleport
systemctl restart teleport

# Configure Machine ID (tbot)
cat <<-EOF > /etc/tbot.yaml
version: v2
proxy_server: ${proxy_address}:443
onboarding:
  join_method: token
  token: ${bot_token}
storage:
  type: directory
  path: /var/lib/teleport/bot
outputs:
- type: identity
  destination:
    type: directory
    # For this guide, /opt/machine-id is used as the destination directory.
    # You may wish to customize this. Multiple outputs cannot share the same
    # destination.
    path: /opt/machine-id
EOF
# creates a data directory for machineid services
mkdir -p /var/lib/teleport/bot
# adds a OS user called teleport that registers as a system user 
useradd --system teleport
# gives the system user teleport ownership of the teleport data dir (which includes the bot subdirectory)
chown -R teleport:teleport /var/lib/teleport/
# creates the output dir for machineid(tbot)
mkdir -p /opt/machine-id
# gives the teleport user ownership of the machineid output dir
chown -R teleport:teleport /opt/machine-id
# adds the ec2-user user to the teleport group
usermod -aG teleport ec2-user
# Create tbot systemd service
cat <<-EOF > /etc/systemd/system/tbot.service
[Unit]
Description=tbot - Teleport Machine ID Service
After=network.target

[Service]
Type=simple
User=teleport
Group=teleport
Restart=always
RestartSec=5
Environment="TELEPORT_ANONYMOUS_TELEMETRY=1"
ExecStart=/usr/local/bin/tbot start -c /etc/tbot.yaml
ExecReload=/bin/kill -HUP $$MAINPID
PIDFile=/run/tbot.pid
LimitNOFILE=524288

[Install]
WantedBy=multi-user.target
EOF

#brings the service up
systemctl daemon-reload

# Configure Ansible
mkdir -p /home/ec2-user/ansible
cat <<EOF > /home/ec2-user/ansible/ansible.cfg
[defaults]
host_key_checking = False
inventory = ./hosts
remote_tmp = /tmp
stdout_callback = yaml

[ssh_connection]
scp_if_ssh = True
ssh_args = -F /opt/machine-id/ssh_config -o CanonicalizeHostname=yes -o CanonicalizeMaxDots=10 -o CanonicalDomains=${proxy_address}
EOF

cat <<-EOF > /home/ec2-user/ansible/playbook.yaml
---
- name: Check Teleport and SSHD status
  hosts: all
  remote_user: ec2-user
  become: true
  gather_facts: true
  tasks:
    - name: Check Teleport and SSHD service status
      ansible.builtin.systemd:
        name: "{{ item }}"
      register: service_status
      loop:
        - teleport
        - sshd
      failed_when: false

    - name: Get Teleport version if running
      command: teleport version
      register: teleport_version
      when: service_status.results[0].status.ActiveState == "active"
      changed_when: false
      failed_when: false

    - name: Stop SSHD if running
      ansible.builtin.systemd:
        name: sshd
        state: stopped
      when: service_status.results[1].status.ActiveState == "active"

    - name: Display results
      debug:
        msg:
          - "hostname: {{ ansible_facts['hostname'] }}"
          - "Teleport is {{ 'running' if service_status.results[0].status.ActiveState == 'active' else 'not running' }}"
          - "Teleport Version: {{ teleport_version.stdout_lines[0] if teleport_version.stdout is defined else 'N/A' }}"
          - "SSHD was {{ 'running and stopped' if service_status.results[1].status.ActiveState == 'active' else 'not running' }}"
EOF

chown -R ec2-user:ec2-user /home/ec2-user/ansible
# update perissions for teleport group
chmod 750 -R /opt/machine-id/
systemctl enable tbot
systemctl restart tbot
