#!/bin/bash

# Created by Avimanyu Bandyopadhyay for Linux Handbook (avimanyu@gizmoquest.com)
# Code fine-tuned by Debdut Chakraborty for Linux Handbook (andanotheremailid@gmail.com)
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Let's log all the errors to a standard file
exec 2>/var/log/stack-init.log

#allocate an extra 2G swapfile
dd if=/dev/zero of=/swapfile bs=1M count=2048 && \
  chmod 600 /swapfile && \
  mkswap /swapfile && \
  echo "/swapfile   none    swap    sw    0   2" >> /etc/fstab

#upgrade all existing packages
apt update && {
  apt upgrade -y || apt upgrade -y # Sometimes the upgrade process fails because of some network issues, retrying in such cases completes the upgrade.
  apt -y install docker-compose auditd jq
}

#update auditd rules
cat <<EOF >> /etc/audit/rules.d/audit.rules
-w /usr/bin/docker -p wa
-w /var/lib/docker -p wa
-w /etc/docker -p wa
-w /lib/systemd/system/docker.service -p wa
-w /lib/systemd/system/docker.socket -p wa
-w /usr/bin/containerd -p wa
-w /etc/docker/daemon.json -p wa
EOF

#minimal docker daemon config
cat <<EOF > /etc/docker/daemon.json
{
  "icc": false,
  "live-restore": true,
  "no-new-privileges": true
}
EOF

systemctl enable --now docker # required for nginx-letsencrypt deployment
systemctl enable auditd

#create a user called tux with sudo privileges, save ssh public keys and harden sshd(make sure to change credentials after completing deployment)
useradd -mG sudo -s /bin/bash -p `mkpasswd KJHkkjsf4iu3ubHJHAajh` tux

#for the cp command to work, make sure to enable ssh key addition(assumed to be already existing on your linode profile) when creating the linode
mkdir /home/tux/.ssh
chmod 700 /home/tux/.ssh && chown tux:tux /home/tux/.ssh
cp ~/.ssh/authorized_keys /home/tux/.ssh/authorized_keys
chmod 600 /home/tux/.ssh/authorized_keys && chown tux:tux /home/tux/.ssh/authorized_keys

sed -i -E -e 's/#Port 22/Port 4566/g' \
  -e 's/(PermitRootLogin) yes/\1 no/g' \
  -e 's/#(PubkeyAuthentication yes)/\1/g' \
  -e 's/#(PasswordAuthentication) yes/\1 no/g' \
  -e 's/#(PermitEmptyPasswords no)/\1/g' \
  -e 's/(X11Forwarding) yes/\1 no/g' \
  -e 's/#(ClientAliveInterval) 0/\1 300/g' \
  -e 's/#(ClientAliveCountMax) 3/\1 2/g' \
  /etc/ssh/sshd_config
echo 'Protocol 2' >> /etc/ssh/sshd_config

#enable automatic security and recommended updates
sed -i /etc/apt/apt.conf.d/50unattended-upgrades -Ee 's/\/\/([[:space:]]+"\$\{distro_id\}:\$\{distro_codename\}-updates";)/\1/g'
cat <<EOF >>/etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF

#install jwilder nginx with ssl on docker(remember to change default email in let's encrypt config after finishing deployment.
#also update your DNS record with this server's IP
#redirections- rename the file www.domain.com to your own and edit it as well accordingly(required if using a root domain and not necessary for subdomains)
#after doing the above 2 changes you would require running `sudo docker-compose up -d` from the jwilder nginx directory as tux after finishing this deployment
sudo -u tux bash << EOF
mkdir /home/tux/jwilder-nginx-with-ssl
wget https://raw.githubusercontent.com/avimanyu786/Jwilder-Nginx-With-LetsEncrypt/main/docker-compose.yml -O /home/tux/jwilder-nginx-with-ssl/docker-compose.yml
echo 'client_max_body_size 1G;' >> /home/tux/jwilder-nginx-with-ssl/client_max_upload_size.conf
echo 'DEFAULT_EMAIL=changeme@domain.com' >> /home/tux/jwilder-nginx-with-ssl/letsencrypt.env
EOF
docker network create net
docker-compose -f /home/tux/jwilder-nginx-with-ssl/docker-compose.yml up -d

#Reboot to finish updates
sleep 6
reboot
