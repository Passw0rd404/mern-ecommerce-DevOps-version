#!/bin/bash
set -euo pipefail

NODE_MAJOR=24

echo "--- Starting AMI Build ---"

test -f /tmp/config.alloy.tmpl || { echo "Alloy template was not uploaded"; exit 1; }

# 1. Update the OS
sudo dnf update -y

# 2. System tools (ruby and wget are needed by the CodeDeploy installer)
sudo dnf install -y jq ruby wget git tar

# 3. Node.js (fail the build if we do not get the version we asked for)
curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR}.x" | sudo bash -
sudo dnf install -y nodejs
node -v | grep -q "^v${NODE_MAJOR}\." || { echo "Wrong Node version: $(node -v)"; exit 1; }

# 4. PM2
sudo npm install -g pm2

# 5. CodeDeploy agent (IMDSv2: get a token first, then the region)
TOKEN=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
REGION=$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)

cd /tmp
wget "https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install"
chmod +x ./install
sudo ./install auto
rm -f ./install

# 6. Verify everything
echo "Verifying versions..."
node -v
npm -v
pm2 -v
jq --version
aws --version
sudo systemctl is-active codedeploy-agent

# 7. Start on boot, but do not bake a running agent into the image
sudo systemctl enable codedeploy-agent
sudo systemctl stop codedeploy-agent

# 7b. Grafana Alloy (config supplied at boot, binary baked in)
wget -q -O /tmp/grafana-gpg.key https://rpm.grafana.com/gpg.key
sudo rpm --import /tmp/grafana-gpg.key
rm -f /tmp/grafana-gpg.key

cat <<'EOF' | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

sudo dnf install -y alloy
sudo mv /tmp/config.alloy.tmpl /etc/alloy/config.alloy.tmpl
sudo systemctl enable alloy
sudo systemctl stop alloy   # started by the install; stop so it doesn't run unconfigured

# 8. Clean up
sudo dnf clean all

# NOTE: SECRET_NAME is not set here on purpose.
# Set it at launch (launch template user data) so this AMI stays environment-neutral.

echo "--- AMI Build Complete ---"
