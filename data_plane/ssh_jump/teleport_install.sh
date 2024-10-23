#!/bin/bash
TELEPORT_VERSION="15.3.0"
curl https://goteleport.com/static/install.sh | bash -s ${TELEPORT_VERSION} enterprise

echo '680502499c56efa4ff635b25ce6390e6' > /tmp/token

# Verify installation
sudo teleport node configure \
   --output=file:///etc/teleport.yaml \
   --token=/tmp/token \
   --proxy=teleport.chrisdlg.com:443

sudo systemctl enable teleport
sudo systemctl start teleport