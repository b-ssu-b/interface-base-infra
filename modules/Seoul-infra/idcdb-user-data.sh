#!/bin/bash
echo "root:1234" | chpasswd
sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin yes/PermitRootLogin yes/g" /etc/ssh/sshd_config
systemctl restart sshd
hostnamectl --static set-hostname IDC-DB
yum install -y mariadb-server mariadb lynx
systemctl enable --now mariadb
echo -e "\n\nqwe123\nqwe123\ny\ny\ny\ny\n" | /usr/bin/mysql_secure_installation
mysql -uroot -pqwe123 -e "CREATE USER 'user1'@'localhost' IDENTIFIED BY 'qwe123';"
mysql -uroot -pqwe123 -e "GRANT ALL PRIVILEGES ON  *.* TO 'user1'@'%' IDENTIFIED BY 'qwe123' WITH GRANT OPTION;"
mysql -uroot -pqwe123 -e "CREATE DATABASE userinfo; GRANT ALL PRIVILEGES ON *.* TO 'user1'@'%' IDENTIFIED BY 'qwe123';"
[client]
default-character-set = utf8mb4
[mysql]
default-character-set = utf8mb4
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-bin=mysql-bin
general_log=ON
# character-set-server=utf8
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
symbolic-links=0
server-id=1
[mysqld_safe]
log-error=/var/log/mariadb/mariadb.log
pid-file=/var/run/mariadb/mariadb.pid
!includedir /etc/my.cnf.d
EOF
systemctl restart mariadb
mysql -uroot -pqwe123 -e "use userinfo;CREATE TABLE userinfo (username CHAR(8),password NVARCHAR(10),name NVARCHAR(10),phone CHAR(11) NOT NULL,address NVARCHAR(90),email CHAR(25),birthdate NVARCHAR(15));"
mysql -uroot -pqwe123 -e "CREATE DATABASE products;"
mysql -uroot -pqwe123 -e "CREATE TABLE products(id CHAR(8),name NVARCHAR(15),store NVARCHAR(20),storeId CHAR(8),price CHAR(10),img NVARCHAR(90));"
mysql -uroot -pqwe123 -e "USE idc_db;CREATE TABLE userinfo (userID VARCHAR(11) NOT NULL,NAME NVARCHAR(45) NOT NULL,mobile1 CHAR(11) NOT NULL,email VARCHAR(40) NOT NULL,ADDRESS NVARCHAR(90)NOT NULL);"
mysql -uroot -pqwe123 -e "USE idc_db;INSERT INTO userinfo VALUES ('YSH', '유상훈', '01039410716','markshyou90@gmail.com','서울시 은평구');"
mysql -uroot -pqwe123 -e "USE idc_db;INSERT INTO userinfo VALUES ('AMK', '안민기', '01080248726','amk1700@gmail.com','서울시 용산구');"
mysql -uroot -pqwe123 -e "USE idc_db;INSERT INTO userinfo VALUES ('SHS', '서희수', '01092564107','bluevie98@gmail.com','서울시 성동구');"
mysql -uroot -pqwe123 -e "USE idc_db;INSERT INTO userinfo VALUES ('LDE', '이다은', '01026299811','sarah4666656@gmail.com','서울시 중랑구');"
