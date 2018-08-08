#!/bin/bash
if [ "$(whoami)" != 'root' ]
then
	echo -e "\033[31mВы не root. сделайте sudo su\n\033[0m"
	exit 0;
fi
sleep 2
echo -e "\033[33mЭтот скрипт запустит деплой:\033[0m"
sleep 1
echo -e "\033[33mСервер 1С со всеми компонентами\033[0m"
sleep 1
echo -e "\033[33mPostgreSQL9.6(postgrespro)\033[0m"
sleep 1
echo -e "\033[33mВеб сервер Apache\033[0m"
sleep 3
echo -e "\033[33mСкрипт заточен под сервер 28CPU,32RAM,SSD\033[0m"

################################################################
sleep 2
echo -e "\033[33mПоехали?...yes/no\033[0m"
read vopros
if [ "$vopros" = 'no' ]
then
	exit 0;
fi 
################################################################
rm -rf /var/log/deploy-1c.log
echo -e '\033[33mВведите префикс клуба (eg. avm, prk...)\033[0m:'
read prefix
hostnamectl set-hostname $prefix-1c.contoso.local &&
echo -e "\033[32mИмя хоста установлено '$prefix-1c.contoso.local'\n\033[0m" 
echo -e "\033[33mОбновляется Linux...\n\033[0m"
yum upgrade -y &> /var/log/deploy-1c.log
sleep 2
timedatectl list-timezones | grep Europe
timedatectl list-timezones | grep Asia
echo -e "\033[33mУстановите таймзону, введите например Eupore/Moscow:\n\033[0m"
read timezone
timedatectl set-timezone $timezone
echo -e '\033[32mОК текущее время:\033[0m \033[34m'$(date)'\033[0m'
echo -e "\033[33mУстанавливаются доп пакеты...\n\033[0m"
yum install epel-release -y &>>/var/log/deploy-1c.log &&
yum install mlocate httpd -y &>>/var/log/deploy-1c.log &&
curl -O http://li.nux.ro/download/nux/dextop/el7/x86_64/msttcore-fonts-installer-2.6-1.noarch.rpm &>>/var/log/deploy-1c.log &&
yum install ImageMagick msttcore-fonts-installer-2.6-1.noarch.rpm -y &>>/var/log/deploy-1c.log
echo -e "\033[32mУспех\n\033[0m"
echo -e "\033[33mВыключаем файрвол и SELinux...\n\033[0m"
sleep 1
systemctl stop firewalld && systemctl disable firewalld & >>/var/log/deploy-1c.log
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
echo -e "\033[32mУспех\n\033[0m"
echo -e "\033[33mУстанавливаем postgreSQL-9.6...\n\033[0m"
rpm -ivh http://ansible.contoso.ru/postgrespro-1c-centos96.noarch.rpm &>>/var/log/deploy-1c.log 
yum install postgresql-pro-1c-9.6 -y &>>/var/log/deploy-1c.log &&
systemctl start postgresql-9.6 &>>/var/log/deploy-1c.log
pgver=$(yum list installed | grep postgrespro-1c-cent)
if [ -n "$pgver" ]
then
       echo -e "\033[32mУспех\n\033[0m"
else 
       echo -e "\033[31mНе удалось установить postgreSQL\n\033[0m"
fi
echo -e "\033[33mСкачиваем и устанавливаем 1С сервер...\n\033[0m"
curl -O http://ansible.contoso.ru/rpm.tar.gz &>>/var/log/deploy-1c.log
tar zxvf rpm.tar.gz &>>/var/log/deploy-1c.log 
rpm -ivh 1C_Ent* &>>/var/log/deploy-1c.log

server=$(yum list installed| grep server-nls)
if [ -n "$server" ]
then
       echo -e "\033[32mУспех\n\033[0m"
else 
       echo -e "\033[31mНе удалось установить сервер 1С\n\033[0m"
fi
curl -O http://ansible.contoso.ru/srv1cv83 &>/dev/null
mv srv1cv83 /etc/init.d/
chmod 755 /etc/init.d/srv1cv83
echo -e "\033[33mНастраиваем postgresql...\033[0m"
sleep 2
echo -e "\033[33mВведите пароль для 1c_connect...\033[0m:"
read pgpass
cd /var/lib/pgsql
sudo -u postgres /usr/pgsql-9.6/bin/initdb -D /var/lib/pgsql/9.6/data --locale=ru_RU.UTF-8 &>>/var/log/deploy-1c.log
sudo -u postgres /usr/pgsql-9.6/bin/pg_ctl -D /var/lib/pgsql/9.6/data -l logfile start &>>/var/log/deploy-1c.log
sudo -u postgres psql -U postgres -c 'CREATE ROLE "1c_connect" with SUPERUSER;' &>>/var/log/deploy-1c.log
sudo -u postgres psql -U postgres -c 'ALTER ROLE "1c_connect" with LOGIN;' &>>/var/log/deploy-1c.log
sudo -u postgres psql -U postgres -c 'ALTER USER "1c_connect" WITH PASSWORD '$pgpass';' &>>/var/log/deploy-1c.log
cd -
mv /var/lib/pgsql/9.6/data/pg_hba.conf /var/lib/pgsql/9.6/data/pg_hba.conf_original 
curl -O http://ansible.contoso.ru/pg_hba.conf &>>/dev/null
mv pg_hba.conf /var/lib/pgsql/9.6/data/
chmod 600 /var/lib/pgsql/9.6/data/pg_hba.conf
chown postgres:postgres /var/lib/pgsql/9.6/data/pg_hba.conf
rm -rf  /var/lib/pgsql/9.6/data/postgresql.conf
curl -O http://ansible.contoso.ru/postgresql.conf &>/dev/null
mv postgresql.conf /var/lib/pgsql/9.6/data/
chmod 600 /var/lib/pgsql/9.6/data/postgresql.conf && chown postgres:postgres /var/lib/pgsql/9.6/data/postgresql.conf
echo -e "\033[32mУспех\n\033[0m"

echo -e "\033[33mСтартуем службы\033[0m:"
systemctl daemon-reload &>>/var/log/deploy-1c.log
systemctl enable postgresql-9.6 &>>/var/log/deploy-1c.log
systemctl restart postgresql-9.6 &>>/var/log/deploy-1c.log
systemctl enable srv1cv83 &>>/var/log/deploy-1c.log
systemctl start srv1cv83 &>>/var/log/deploy-1c.log
systemctl enable httpd &>>/var/log/deploy-1c.log
systemctl start httpd &>>/var/log/deploy-1c.log
statuspg=$(systemctl status postgresql-9.6 | grep 'failed state')
statusserver=$(systemctl status srv1cv83 | grep 'failed state')
statusapache=$(systemctl status httpd | grep 'failed state')
##############################################################
sleep 2
if [ -n "$statuspg" ] 
then
        echo -e "\033[31mСервер postgeSQL не стартанул\n\033[0m"
else
	echo -e "\033[32mСервер postgreSQL стартанул\n\033[0m"	
fi
##############################################################
sleep 2
if [ -n "$statusserver" ]
then
        echo -e "\033[31mСервер 1С не стартанул\n\033[0m"
else
        echo -e "\033[32mСервер 1С стартанул\n\033[0m"
fi
##############################################################
sleep 2
if [ -n "$statusapache" ]
then
        echo -e "\033[31mСервер Apache не стартанул\n\033[0m"
else
        echo -e "\033[32mСервер Apache стартанул\n\033[0m"
fi
##############################################################
sleep 2
ip=$(hostname -i | cut -c 30-50)
echo -e '\033[33mДобавьте А запись на DNS сервере в зоне contoso.local: \033[32m'$prefix-1c' -> '$ip' \n\033[0m'
echo -e "\033[32mНа этом установка закончена, добавьте инфу в CONFLUENCE\n\033[0m"
echo -e "\033[34mЛоги установки var/log/deploy-1c.log\n\033[0m"
