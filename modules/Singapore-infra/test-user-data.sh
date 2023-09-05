#!/bin/bash
echo "root:1234" | chpasswd
sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/g" /etc/ssh/sshd_config
systemctl restart sshd
hostnamectl --static set-hostname Singapore-AWS-NAT
yum install -y httpd lynx
systemctl start httpd && systemctl enable httpd
rm -rf /var/www/html/index.html
echo "<h1>CloudNet@ FullLab - SingaporeRegion - NAT</h1>" > /var/www/html/index.html