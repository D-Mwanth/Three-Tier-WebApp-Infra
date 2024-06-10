#!/bin/bash

# define user variable
USER=ubuntu

## update the package manager
sudo apt update -y

# Install aws cli
sudo apt install unzip -y

# Download and install AWS CLI
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo unzip awscliv2.zip
sudo ./aws/install
sudo rm awscliv2.zip

## Install Node.js and npm using package manager, needed as they are dependacies for running our js backend
cd ~
sudo curl -sL https://deb.nodesource.com/setup_18.x -o /tmp/nodesource_setup.sh
sudo bash /tmp/nodesource_setup.sh
sudo apt-get install nodejs -y

# Download the application code from the S3 bucket, assuming this backet is already created
# add the application is loaded there
cd ~/
aws s3 cp s3://3-tier-app-hosting-bk/application-code/web-tier/ /home/"$USER"/web_tier --recursive

# Install dependacies and start web application
cd /home/"$USER"/web_tier
npm install 
npm run build

# install nginx
sudo apt install nginx -y

# configure nginx
cd /etc/nginx
# delete default nginx.conf file from Nginx installation
sudo rm nginx.conf

# value is assigned using terraform template file as store as a system variable: we will use this to set elb dns name in the nginx config file in the next step
export ELB_DNS_NAME=${ELB_DNS_NAME}

# set user as enviroment variable
export MY_USER=ubuntu

# download nginx config template from s3
sudo aws s3 cp s3://3-tier-app-hosting-bk/application-code/nginx.conf /etc/nginx/nginx.conf.template

# render the template file by substituting env variable with the required values and write output to nginx.config file
sudo -E bash -c 'envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf'

# delete the template file
sudo rm /etc/nginx/nginx.conf.template

# create a system user named `nginx` for nginx service.
sudo adduser --system --no-create-home --disabled-login --group nginx
sudo chmod -R 755 /home/$USER

# restart nginx
sudo systemctl restart nginx

# enable nginx to start on boot
sudo systemctl enable nginx