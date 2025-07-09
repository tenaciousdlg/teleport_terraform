#!/bin/bash
set -euxo pipefail

# Set hostname
hostnamectl set-hostname "${env}-rds-mysql-agent"

# Update system and install dependencies
dnf update -y
dnf install -y mariadb105 jq

########################################################
# Teleport Installation 
########################################################
curl https://goteleport.com/static/install.sh | bash -s "${teleport_version}" enterprise

#########################################################
# Wait for RDS to be available and configure MySQL
#########################################################
echo "Waiting for RDS instance to be available..."

# Wait for RDS instance to be ready
echo "Checking RDS instance status..."
RDS_INSTANCE_ID="${rds_instance_id}"
for i in {1..30}; do
    echo "Status check attempt $i/30..."
    STATUS=$(aws rds describe-db-instances --db-instance-identifier "$RDS_INSTANCE_ID" --region "${region}" --query 'DBInstances[0].DBInstanceStatus' --output text)
    if [ "$STATUS" = "available" ]; then
        echo "✓ RDS instance is available"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "✗ RDS instance not available after 30 attempts"
        exit 1
    fi
    sleep 30
done

# Extract hostname without port
RDS_HOSTNAME=$(echo "${rds_endpoint}" | cut -d':' -f1)

# Test direct connection with password first
echo "Testing direct RDS connection with password..."
for i in {1..10}; do
    echo "Connection attempt $i/10..."
    if mysql -h "$RDS_HOSTNAME" -u admin -p"${rds_password}" -e "SELECT 1;" 2>/dev/null; then
        echo "✓ Direct RDS connection successful"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "✗ Failed to connect to RDS after 10 attempts"
        exit 1
    fi
    sleep 15
done

echo "Configuring MySQL for Teleport auto user provisioning..."

# Configure MySQL for auto user provisioning with direct RDS access
mysql -h "$RDS_HOSTNAME" -u admin -p"${rds_password}" << 'SQLEOF'
-- Create teleport-admin user with AWS IAM authentication
CREATE USER 'teleport-admin' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS';

-- Grant required permissions for auto user provisioning
GRANT SELECT ON mysql.role_edges TO 'teleport-admin';
GRANT PROCESS, ROLE_ADMIN, CREATE USER ON *.* TO 'teleport-admin';

-- Create teleport database/schema (if not exists)
CREATE DATABASE IF NOT EXISTS `teleport`;

-- Grant routine permissions for stored procedures
GRANT ALTER ROUTINE, CREATE ROUTINE, EXECUTE ON `teleport`.* TO 'teleport-admin';

-- Flush privileges to apply changes
FLUSH PRIVILEGES;

-- Verify the user was created
SELECT user, host, plugin FROM mysql.user WHERE user = 'teleport-admin';
SQLEOF

if [ $? -eq 0 ]; then
    echo "✓ MySQL auto user provisioning configuration completed successfully"
else
    echo "✗ MySQL configuration failed"
    exit 1
fi

#########################################################
# Teleport Configuration
#########################################################
cat <<EOF > /etc/teleport.yaml
version: v3
teleport:
  data_dir: "/var/lib/teleport"
  proxy_server: "${proxy_address}:443"
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
       "tier": "${env}"

auth_service:
  enabled: "no"

ssh_service:
  enabled: "yes"
  labels:
    tier: "${env}"
    os: amzn23

proxy_service:
  enabled: "no"

app_service:
  enabled: "no"
EOF

systemctl enable teleport
systemctl restart teleport