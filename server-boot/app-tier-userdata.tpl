#!/bin/bash

# Update system packages
sudo apt update -y

# Download and install AWS CLI
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
sudo unzip awscliv2.zip
sudo ./aws/install
sudo rm awscliv2.zip

# Install MySQL client and jq
sudo apt install mysql-client jq -y

# Retrieve database secret values from AWS Secrets Manager
secret_value=$(aws secretsmanager get-secret-value --secret-id "${SECRET_MANAGER_NAME}")

# Extract values using jq and assign them to variables
export DB_HOST=$(echo "$secret_value" | jq -r '.SecretString | fromjson | .endpoint | split(":")[0]')
export DB_USER=$(echo "$secret_value" | jq -r '.SecretString | fromjson | .username')
export DB_PASSWORD=$(echo "$secret_value" | jq -r '.SecretString | fromjson | .password')
export DB_NAME=$(echo "$secret_value" | jq -r '.SecretString | fromjson | .app_database')

# Connect to database, setup application database, and create a table for app data storage
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" -e "\
CREATE DATABASE IF NOT EXISTS $DB_NAME; \
USE $DB_NAME; \
CREATE TABLE IF NOT EXISTS transactions(id INT NOT NULL AUTO_INCREMENT, amount DECIMAL(10,2), description VARCHAR(100), PRIMARY KEY(id));
"

# Install Node.js and npm
sudo curl -sL https://deb.nodesource.com/setup_18.x -o /tmp/nodesource_setup.sh
sudo bash /tmp/nodesource_setup.sh
sudo apt-get install nodejs -y

# Download the application code from the S3 bucket
cd ~/
aws s3 cp s3://3-tier-app-hosting-bk/application-code/app-tier/ app-tier --recursive

# Install remaining dependencies
cd ~/app-tier
npm install

# Set secret manager name to env variable (used to replace DB_SECRET_MANAGER env var in Dbconfig.js with value)
export DB_SECRET_MANAGER="${SECRET_MANAGER_NAME}"

# Render Dbconf.js file to substitue the name of Secret Manger
sudo -E bash -c 'envsubst < DbConfig.js  > DbConfig.tmp && mv DbConfig.tmp DbConfig.js '

# Create a systemd service file for starting the application
sudo cat <<EOF > /etc/systemd/system/custom-nodejs.service
[Unit]
Description=Node.js Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/app-tier
ExecStart=/usr/bin/node /root/app-tier/index.js
Restart=always
RestartSec=5
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the systemd service
sudo systemctl enable custom-nodejs
sudo systemctl start custom-nodejs