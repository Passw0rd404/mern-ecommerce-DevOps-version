#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

echo "--- Starting AMI Build ---"

echo "SECRET_NAME=ecommerce/prod/backend" | sudo tee /etc/environment

# 1. Update the OS
sudo dnf update -y

# 2. Install essential system tools (including jq)
# These will now be "baked in" and available in your private subnet
sudo dnf install -y jq ruby wget git tar

# 3. Install Node.js 20 (LTS)
# Using NodeSource to ensure we get a specific version
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs

# 4. Install PM2 globally
# This ensures 'pm2' is in the PATH for the ec2-user later
sudo npm install -g pm2

# 5. Install the CodeDeploy Agent
# Note: We use the bucket for the specific region where the AMI is built
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
cd /home/ec2-user
wget https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto

# 6. Verify Installations
echo "Verifying versions..."
node -v
npm -v
pm2 -v
jq --version
sudo service codedeploy-agent status

# 7. Enable CodeDeploy Agent to start on every boot
sudo systemctl enable codedeploy-agent

echo "--- AMI Build Complete ---"