#!/bin/bash
apt-get update -y
apt-get install -y apache2 vim
echo "root:1234" | chpasswd
sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/g" /etc/ssh/sshd_config
systemctl restart sshd
hostnamectl --static set-hostname Seoul-IDC-Web
