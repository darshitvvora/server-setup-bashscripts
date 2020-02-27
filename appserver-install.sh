#!/bin/bash
################################################################################
#                              New App Server Template                         #
#                                                                              #
# Use this template for configuring new CentOS 7/8 server                      #
# This script will help you to install and make Metabase server production     #
# ready. Ideal to take a CentOS 8 VM on Linode/DigitalOcean ssh into it        #
# and run script                                                               #
#                                                                              #
# Change History                                                               #
# 25/02/2020 Darshit Vora   Original code. This is a template for configuring  #
#                           new App Server with nginx                          #
#                           Add new history entries as needed.                 #
#                                                                              #
#                                                                              #
################################################################################
################################################################################
################################################################################
#                                                                              #
#  Copyright (C) 2020 Darshit Vora                                             #
#  darshitvvora@gmail.com                                                      #
#                                                                              #
#  This program is free software; you can redistribute it and/or modify        #
#  it under the terms of the GNU General Public License as published by        #
#  the Free Software Foundation; either version 2 of the License, or           #
#  (at your option) any later version.                                         #
#                                                                              #
#  This program is distributed in the hope that it will be useful,             #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of              #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
#  GNU General Public License for more details.                                #
#                                                                              #
#  You should have received a copy of the GNU General Public License           #
#  along with this program; if not, write to the Free Software                 #
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA   #
#                                                                              #
################################################################################
################################################################################
################################################################################
echo -e "
################################################################################
################################################################################
#                                                                              #
#                                                                              #
#                                                                              #
#                 \e[34mWelcome to Metabase App Installer\e[39m                            #
#                                                                              #
#                                                                              # 
#                                                                              #
#                                                                              #
################################################################################
################################################################################"

readUser(){
	echo "Type the username you would like to add, followed by [ENTER]:"
	read USERNAME
}

setDomainName(){
	echo "Type the Domain name you would like to configure, followed by [ENTER]:"
	read HOST
	
	if [ -n "$HOST" ]; then
		echo "Setting Hostname: $host"
		hostname $HOST
	else
		echo "Please enter valid domain name"
		setDomainName
	fi
}

addUser(){
	echo "Adding $USERNAME user"
	useradd $1
	passwd $1

	echo  "Adding user:$USERNAME to sudoers\n"
	usermod $USERNAME -aG wheel
}

installOSDependencies(){
	echo "Installing Repos\n"
	yum install epel-release -y

	echo "Updating repos\n"
	yum update -y

	echo "Installing git\n"
	yum install git -y
}

changeSELinuxSetting(){
	echo "Changing SELinux Settings\n"
	sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config

	echo "Enabling SELinux Disabled config\n"
	sestatus
}

disableRootSSH(){
	echo "Disabling root user login via ssh\n"
	sed -i '/^PermitRootLogin[ \t]\+\w\+$/{ s//PermitRootLogin no/g; }' /etc/ssh/sshd_config

	echo "Restarting ssh daemon\n"
	systemctl restart sshd	
}

setTimeZone(){
	echo "Type the timezone for server. Example of valid timezone Asia/Kolkata, followed by [ENTER]:"
	read TIMEZONE
	echo "Setting up timezone to $TIMEZONE\n"
	TIMEZONEPATH="/usr/share/zoneinfo/$TIMEZONE"
	rm /etc/localtime
	ln -s $TIMEZONEPATH /etc/localtime
}

removeFirewall(){
	echo "Removing firewall\n"
	systemctl mask firewalld
	systemctl stop firewalld
	yum remove firewalld -y
}

installAppDependencies(){
	echo "Installing nginx nodejs wget tar nano & iptables"
	yum install nginx nodejs iptables-services tar wget nano htop -y
	npm i -g n
	n lts
}

configureIPTables(){
	echo "Enabling Iptables unit to start on boot\n"
	systemctl enable iptables

	echo "Starting IPTables\n"
	systemctl start iptables

	echo "Adding IPTable Rules\n"
	iptables -P INPUT ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -F

	#keep established connections
	iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

	#ssh port for all
	iptables -A INPUT -p tcp --dport 22 -j ACCEPT

	iptables -A INPUT -p tcp --dport 80 -j ACCEPT
	iptables -A INPUT -p tcp --dport 443 -j ACCEPT

	iptables -I INPUT 1 -i lo -j ACCEPT
	iptables -A INPUT -j DROP

	echo "Saving Iptable rules"
	service iptables save

	service iptables restart

	echo "Listing IPTable Rules"
	iptables -L --line-numbers
}

configureSSL(){
	read -n1 -p "Would you like configure SSL certificate? [y,n]" doit 
	case $doit in  
	  y|Y) 
		echo "\nPaste value of SSL bundle cert file, followed by [ENTER]:\n"
		read SSLCert

		echo "Paste value of SSL private key, followed by [ENTER]:\n"
		read SSLKey

		mkdir /etc/nginx/ssl 


		SSLCertPath="/etc/nginx/ssl/star.$HOST.crt"
		SSLKeyPath="/etc/nginx/ssl/$HOST.key"

		rm $SSLCertPath
		rm $SSLKeyPath

		echo "$SSLCert" >> $SSLCertPath
		echo "$SSLKey" >> $SSLKeyPath
		echo "SSL configured with nginx successfully\n"
	  	 ;; 
	  n|N) echo "OK. Let continue\n" ;; 
	esac
}

installApplication(){

	echo "Oracle Java download successful\n"
	echo "Installing Java"
	yum install java-11-openjdk-devel

	echo "Java installed successfully\n"

	echo "Downloading Metabase. Please Wait...\n"

	echo "Please enter the version of Metabase you would like to install, followed by [ENTER]:"
	read METABASE_VERSION

	METABASE_DOWNLOAD_URL="http://downloads.metabase.com/v$METABASE_VERSION/metabase.jar"
	echo $METABASE_DOWNLOAD_URL

	wget $METABASE_DOWNLOAD_URL

	java -jar metabase.jar

	mv metabase.jar /var/metabase.jar

	echo "Creating metabase system service"

	rm /etc/systemd/system/metabase.service

	cat >> /etc/systemd/system/metabase.service <<EOL
[Unit]
Description=Metabase server
After=syslog.target
After=network.target
[Service]
User=root
Type=simple
ExecStart=/bin/java -jar /var/metabase.jar
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=metabase

[Install]
WantedBy=multi-user.target
EOL



	echo "Enabling metabase service to start on boot"
	systemctl enable metabase

	echo "Starting metabase service"
	systemctl start metabase


}

setupNginxConf(){
	echo "Please enter subdomain for application, default will be app followed by [ENTER]:"
	read SUBDOMAIN

	if [ -n "$SUBDOMAIN" ]; then
		echo "Storing subdomain"

	else
		SUBDOMAIN="app"
	fi

	echo "Please enter port for your application, default will be 3000 followed by [ENTER]:"
	read PORT_NUMBER


	if [ -n "$PORT_NUMBER" ]; then
		echo "Storing Port"

	else
		PORT_NUMBER="3000"
	fi

	NGINX_PATH="/etc/nginx/conf.d/$SUBDOMAIN.$HOST.conf"

	rm $NGINX_PATH

	echo "server {
	       listen         80;
	       server_name    $SUBDOMAIN.$HOST;
	       return         301 https://$server_name$request_uri;
	}
	server {
	    server_name  $SUBDOMAIN.$HOST;
	    listen 443 ssl;
	    ssl on;
	    ssl_certificate $SSLCert;
	    ssl_certificate_key $SSLKey;
	    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	        location / {
                #include cors_support;
    			proxy_send_timeout 1200s;
    			proxy_read_timeout 1200s;
    			fastcgi_send_timeout 1200s;
    			fastcgi_read_timeout 1200s;
                proxy_set_header X-Forwarded-Host $host;
                proxy_set_header X-Forwarded-Server $host;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_pass http://localhost:$PORT_NUMBER/;
	        }
	}" >> $NGINX_PATH

	systemctl start nginx 
	systemctl enable nginx

	echo "Please check application on $SUBDOMAIN.$HOST"

}

## Start of script
readUser

if [ -n "$USERNAME" ]; then
	addUser $USERNAME
else
	echo "Please enter valid username"
	readUser
fi

# Setting IP Address
IP=$(curl ipinfo.io/ip)
echo "Your IP address is $IP"

installOSDependencies

setDomainName

changeSELinuxSetting

setTimeZone

removeFirewall

installAppDependencies

configureIPTables

configureSSL

installApplication

setupNginxConf

disableRootSSH