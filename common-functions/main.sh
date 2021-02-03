#!/usr/bin/env bash
# StackScript Bash Library
#
# Copyright (c) 2010 Linode LLC / Christopher S. Aker <caker@linode.com>
# All rights reserved.
#
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# * Neither the name of Linode LLC nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific prior
# written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
# SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
# DAMAGE.
#
###########################################################
# System
###########################################################
function debian_upgrade {
    printf "Running initial updates - This will take a while...\n"
    DEBIAN_FRONTEND=noninteractive apt-get -y upgrade >/dev/null
}
function system_update {
    case "${detected_distro[family]}" in
        'debian')
            # Force IPv4 and noninteractive upgrade after script runs to prevent
            # breaking nf_conntrack
            echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
            # Run initial updates for Debian-based systems, and do it quietly
            printf "Checking for initial updates...\n"
            DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null
            ;;
        'redhat')
            # Run initial updates for RedHat-based systems, quietly
            # Also, add the 'epel-release' repository to yum
            printf "Running initial updates - This will take a while...\n"
            yum --quiet -y update >/dev/null
            yum --quiet -y install epel-release >/dev/null
            yum --quiet repolist
            ;;
    esac
}
function system_primary_ip {
    local ip_address="$(ip a | awk '/inet / {print $2}')"
    echo $ip_address | cut -d' ' -f 2 | cut -d/ -f 1
}
function system_primary_ipv6 {
    ip -6 a | grep inet6 | awk '/global/{print $2}' | cut -d/ -f1
}
function system_private_ip {
    local ip_address="$(ip a | awk '/inet 192.168/ {print $2}')"
    echo $ip_address | cut -d ' ' -f 2 | cut -d/ -f 1
}
function get_rdns {
    # $1 - The IP address to query
    [ ! -e /usr/bin/host ] && system_install_package dnsutils
    host "$1" | awk '/pointer/ {print $5}' | sed 's/\.$//'
}
function get_rdns_primary_ip {
    # returns the reverse dns of the primary IP assigned to this system
    get_rdns $(system_primary_ip)
}
function system_set_hostname {
    # Sets the system's hostname
    # $1 - The hostname to define
    local -r hostname="$1"
    [ -z "$hostname" ] && {
        printf "Hostname undefined\n"
        return 1;
    }
    hostnamectl set-hostname "$hostname"
}
function system_add_host_entry {
    # $1 - The IP address to set a hosts entry for
    # $2 - The fqdn to set to the IP
    # $3 - The Hostname to set a hosts entry for
    local -r ip_address="$1" fqdn="$2" hostname="$3"
    [ -z "$ip_address" -o -z "$fqdn" ] && {
        printf "IP address and/or fqdn undefined in system_add_host_entry()\n"
        return 1;
    }
    echo "$ip_address $fqdn $hostname" >> /etc/hosts
}
detect_distro() {
    # Determine which distribution is in use on the Linode
    # $1 - required - Which value to echo back to the calling function

    [ -z "$1" ] && {
        printf "detect_distro() requires which value to be returned as its only argument\n"
        return 1
    }
    
    local distro="`awk -F= '
        $1 ~ /ID/ {
            $2=gensub(/^"(.+)"/, "\\1", 1, $2);
            print $2
        }
    ' /etc/os-release`"

    local version="`awk -F= '
        $1 ~ /VERSION_ID/ {
            $2=gensub(/^"(.+)"/, "\\1", 1, $2);
            print $2
        }
    ' /etc/os-release`"
    
    [ -f /etc/debian_version ] && local family='debian'
    [ -f /etc/redhat-release ] && local family='redhat'

    # Determine what the calling function wants and provide it
    case "$1" in
        'distro') printf "%s\n" "$distro" ;;

        'family') printf "%s\n" "$family" ;;

        'version') printf "%s\n" "$version" ;;

        *)
            printf "This does not appear to be a supported distribution\n"
            return 1 ;;
    esac
}
system_set_timezone () {
    # Sets the timezone on the Linode
    # $1 - required - timezone to set on the system
    [ -z "$1" ] && {
         printf "system_set_timezone() requires the Linode's timezone as its only argument\n"
         return 1
    }
    timedatectl set-timezone "$1"
}
function system_install_package {
    # This function expands a bit on the old system_install_package() by allowing installation of a
    # list of packages, stored in an array, using a single command instead of requiring scripts
    # to call the function once for each package to be installed
    [ -z "$1" ] && {
        printf "system_install_package() requires the package(s) to be installed as its only argument\n"
        return 1;
    }
    local packages=("${@}")
    # Determine which package manager to use, and install the specified package
    case "${detected_distro['family']}" in
        'debian')
            DEBIAN_FRONTEND=noninteractive apt-get -y install "${packages[@]}" -qq >/dev/null || {
                printf "One of the packages could not be installed via apt-get\n"
                printf "Check out /var/log/stackscript.log for more details\n"
                return 1;
            }
            ;;
        'redhat')
            yum --quiet -y install "${packages[@]}" >/dev/null || {
                printf "One of the packages could not be installed via yum\n"
                printf "Check out /var/log/stackscript.log for more details\n"
                return 1;
            }
            ;;
    esac
}
function system_remove_package {
    # This function expands a bit on the system_remove_package() by allowing removal of a
    # list of packages, stored in an array, using a single command instead of requiring scripts
    # to call the function once for each package removed
    [ -z "$1" ] && {
        printf "system_remove_package() requires the package to be removed as its only argument\n"
        return 1;
    }
    local packages=("${@}")
    # Determine which package manager to use, and remove the specified package
    case "${detected_distro['family']}" in
        'debian')
            DEBIAN_FRONTEND=noninteractive apt-get -y purge "${packages[@]}" -qq >/dev/null || {
                printf "One of the packages could not be removed via apt-get\n"
                printf "Check out /var/log/stackscript.log for more details\n"
                return 1;
            }
            ;;
        'redhat')
            yum --quiet -y remove "${packages[@]}" >/dev/null || {
                printf "One of the packages could not be removed via yum\n"
                printf "Check out /var/log/stackscript.log for more details\n"
                return 1;
            }
            ;;
    esac
}
function system_configure_ntp {
    case "${detected_distro[distro]}" in
        'debian')
            if [ "$(echo "${detected_distro[version_major]}")" -ge 10 ]; then
                systemctl start systemd-timesyncd
            fi
            ;;
        'ubuntu')
            if [ "$(echo "${detected_distro[version_major]}")" -ge 20 ]; then
                systemctl start systemd-timesyncd
            fi
            ;;
        *)
            system_install_package ntp
            systemctl enable ntpd
            systemctl start ntpd
            ;;
    esac
}
###########################################################
# Users and Security
###########################################################
function user_add_sudo {
    # $1 - required - username
    # $2 - required - password
    [ -z "$1" -o -z "$2" ] && {
        printf "No new username and/or password entered\n"
        return 1;
    }
    local -r username="$1" userpass="$2"
    [ ! -x /usr/bin/sudo ] && system_install_package sudo
    case "${detected_distro[family]}" in
        'debian')
            # Add the user and set the password
            adduser "$username" --disabled-password --gecos ""
            echo "${username}:${userpass}" | chpasswd
            # Add the newly created user to the 'sudo' group
            adduser "$username" sudo >/dev/null
            ;;
        'redhat')
            # Add the user and set the password
            useradd "$username"
            echo "${username}:${userpass}" | chpasswd
            # Add the newly created user to the 'wheel' group
            usermod -aG wheel "$username" >/dev/null
            ;;
    esac
}
function user_add_pubkey {
    # Adds the users public key to authorized_keys for the specified user. Make sure you wrap
    # your input variables in "{double quotes and curly braces}", or the key may not load properly
    # $1 - Required - username
    # $2 - Required - public key
    [ -z "$1" -o -z "$2" ] && {
        printf "Must provide a username and a public key\n"
        return 1;
    }
    local -r username="$1" userpubkey="$2"
    case "$username" in
        'root')
            mkdir /root/.ssh
            echo "$userpubkey" >> /root/.ssh/authorized_keys
            return 1;
            ;;
        *)
            mkdir -p /home/"${username}"/.ssh
            chmod -R 700 /home/"${username}"/.ssh/
            echo "$userpubkey" >> /home/"${username}"/.ssh/authorized_keys
            chown -R "${username}":"${username}" /home/"${username}"/.ssh
            chmod 600 /home/"${username}"/.ssh/authorized_keys
            ;;
    esac
}
function ssh_disable_root {
    # Disable root SSH access
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i -e "s/#PermitRootLogin no/PermitRootLogin no/" /etc/ssh/sshd_config
    # Disable password authentication
    sed -i -e "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
    sed -i -e "s/#PasswordAuthentication no/PasswordAuthentication no/" /etc/ssh/sshd_config
    # Restart SSHd
    [ "${detected_distro[family]}" == 'debian' ] && systemctl restart ssh
    [ "${detected_distro[family]}" == 'redhat' ] && systemctl restart sshd
}
function configure_ufw_firewall {
    local -a ports=("$@")
    # Open the ports specified in "${@}"
    for i in "${ports[@]}"; do
        ufw allow "$i"
    done
    ufw reload
}
function configure_basic_firewall {
    case "${detected_distro[family]}" in
        'debian')
            iptables --policy INPUT DROP
            iptables --policy OUTPUT ACCEPT
            iptables --policy FORWARD DROP
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -i lo -m comment --comment "Allow loopback connections" -j ACCEPT
            iptables -A INPUT -p icmp -m comment --comment "Allow Ping to work as expected" -j ACCEPT
            ip6tables --policy INPUT DROP
            ip6tables --policy OUTPUT ACCEPT
            ip6tables --policy FORWARD DROP
            ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            ip6tables -A INPUT -i lo -m comment --comment "Allow loopback connections" -j ACCEPT
            ip6tables -A INPUT -p icmpv6 -m comment --comment "Allow Ping to work as expected" -j ACCEPT
            ;;
    esac
    # Open port 22 for SSH
    add_port 'ipv4' 22 'tcp'
    add_port 'ipv6' 22 'tcp'
    save_firewall
}
function add_port {
    # $1 - required - IP standard to use (IPv4 or IPv6)
    # $2  - Required - Port to open
    [ -z "$1" ] && {
        printf "add_port() requires the IP standard (IPv4/IPv6) as its first argument\n"
        return 1;
    }
    [ -z "$2" ] && {
        printf "add_port() requires the port number as its second argument\n"
        return 1;
    }
    [ -z "$3" ] && {
        printf "add_port() requires the protocol (TCP/UDP) as its third argument\n"
        return 1;
    }
    local -r standard="${1,,}" port="$2" protocol="${3,,}"
    case "${detected_distro[family]}" in
        'redhat')
            firewall-cmd --quiet --permanent --add-port="${port}/${protocol}"
            firewall-cmd --quiet --reload
            ;;
        *)
            if [ -x /usr/sbin/ufw ]; then
                ufw allow "$port/$protocol"
            else
                case "$standard" in
                    'ipv4')
                        iptables -A INPUT -p "$protocol" --dport "$port" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
                        ;;
                    'ipv6')
                        ip6tables -A INPUT -p "$protocol" --dport "$port" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
                        ;;
                esac
            fi
            ;;
    esac
}
function add_ports {
    # Opens a list of firewall ports for both IPv4 and IPv6
    local -a ports=("${@}")
    # Open the ports specified in "${@}"
    for i in "${ports[@]}"; do
        add_port 'ipv4' $i 'tcp'
        add_port 'ipv6' $i 'tcp'
    done
}
function save_firewall {
    case "${detected_distro[family]}" in
        'debian')
            # Save the IPv4 and IPv6 rulesets so that they will stick through a reboot
            printf "Saving firewall rules for IPv4 and IPv6...\n"
            echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
            echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
            system_install_package iptables-persistent
            ;;
        'redhat')
            firewall-cmd --quiet --reload
            ;;
    esac
}
function enable_fail2ban {
    # Install fail2ban using the appropriate package manager for your Linode's distribution
    system_install_package fail2ban
    # Configure fail2ban defaults
    cd /etc/fail2ban
    cp fail2ban.conf fail2ban.local
    cp jail.conf jail.local
    sed -i -e "s/backend = auto/backend = systemd/" /etc/fail2ban/jail.local
    systemctl enable fail2ban
    systemctl start fail2ban
    cd /root/
    # Start fail2ban and enable it as a system service
    systemctl start fail2ban
    systemctl enable fail2ban
}
function enable_passwordless_sudo {
    # $1 - required - Username to grant passwordless sudo access to
    [ -z "$1" ] && {
        printf "enable_passwordless_sudo() requires the username to grant passwordless sudo access to as its only argument\n"
        return 1;
    }
    local -r username="$1"
    echo "$username ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers
}
function automatic_security_updates {
    # Configure autmoatic security updates for Debian-based systems
    if [ "${detected_distro[family]}" == 'debian' ]; then
        system_install_package unattended-upgrades
        cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    # Configure automatic security updates for RedHat-based systems
    elif [ "${detected_distro[family]}" == 'redhat' ]; then
        system_install_package yum-cron
        sed -i 's/apply_updates = no/apply_updates = yes/g' /etc/yum/yum-cron.conf
    fi
}
###########################################################
# Apache
###########################################################
function apache_install {
    # Detects the installed distribution, and then installs the appropriate Apache version
    case "${detected_distro[family]}" in
        'debian')
            system_install_package apache2
            a2dissite 000-default.conf # disable the interfering default virtualhost
            # clean up, or add the NameVirtualHost line to ports.conf
            sed -i -e 's/^NameVirtualHost \*$/NameVirtualHost *:80/' /etc/apache2/ports.conf
            if ! grep -q NameVirtualHost /etc/apache2/ports.conf; then
                echo 'NameVirtualHost *:80' > /etc/apache2/ports.conf.tmp
                cat /etc/apache2/ports.conf >> /etc/apache2/ports.conf.tmp
                mv -f /etc/apache2/ports.conf.tmp /etc/apache2/ports.conf
            fi
            ;;
        'redhat')
            system_install_package httpd
            # Turn off KeepAlive and adjust the resource use settings. These settings
            # are a good starting point for a Linode 2GB
            echo "KeepAlive Off" >> /etc/httpd/conf/httpd.conf
            echo "" >> /etc/httpd/conf/httpd.conf
            echo "" >> /etc/httpd/conf/httpd.conf
            echo "<IfModule prefork.c>" >> /etc/httpd/conf/httpd.conf
            echo "    StartServers        4" >> /etc/httpd/conf/httpd.conf
            echo "    MinSpareServers     20" >> /etc/httpd/conf/httpd.conf
            echo "    MaxSpareServers     40" >> /etc/httpd/conf/httpd.conf
            echo "    MaxClients          200" >> /etc/httpd/conf/httpd.conf
            echo "    MaxRequestsPerChild 4500" >> /etc/httpd/conf/httpd.conf
            echo "</IfModule>" >> /etc/httpd/conf/httpd.conf
            # Enable and restart Apache
            systemctl enable httpd.service
            systemctl restart httpd.service
            ;;
    esac
    # Open TCP port 80 to allow Apache through the firewall
    add_port 'ipv4' 80 'tcp'
}
function apache_tune {
    # Tunes Apache's memory to use the percentage of RAM you specify, defaulting to 40%
    # $1 - the percent of system memory to allocate towards Apache
    if [ -z "$1" ];
        then local -r percent=40
        else local -r percent="$1"
    fi
    system_install_package apache2-mpm-prefork
    local -r perprocmem=10 # the amount of memory in MB each apache process is likely to utilize
    local -r mem="$(grep MemTotal /proc/meminfo | awk '{ print int($2/1024) }')" # how much memory in MB this system has
    local maxclients="$((mem*percent/100/perprocmem))" # calculate MaxClients
    maxclients="${maxclients/.*}" # cast to an integer
    sed -i -e "s/\(^[ \t]*MaxClients[ \t]*\)[0-9]*/\1$maxclients/" /etc/apache2/apache2.conf
    systemctl restart apache2
}
function apache_virtualhost {
    # $1 - required - the hostname of the virtualhost to create
    [ -z "$1" ] && {
        printf "apache_virtualhost() requires the hostname as the first argument\n"
        return 1;
    }
    local -r vhostname="$1"
    [ "${detected_distro[family]}" == 'debian' ] && \
        local -r vhostfile="/etc/apache2/sites-available/$vhostname.conf" \
    [ "${detected_distro[family]}" == 'redhat' ] && \
        local -r vhostfile="/etc/httpd/conf.d/vhost.conf"
    [ -e "$vhostfile" ] && {
        printf "$vhostfile already exists\n"
        return 1;
    }
    mkdir -p "/var/www/html/$vhostname/{public_html,logs}"
    # Configure the VirtualHost
    echo "<VirtualHost *:80>" > "$vhostfile"
    echo "    ServerName $vhostname" >> "$vhostfile"
    echo "    DocumentRoot /var/www/html/$vhostname/public_html/" >> "$vhostfile"
    echo "    ErrorLog /var/www/html/$vhostname/logs/error.log" >> "$vhostfile"
    echo "    CustomLog /var/www/html/$vhostname/logs/access.log combined" >> "$vhostfile"
    echo "</VirtualHost>" >> "$vhostfile"
    case "${detected_distro[family]}" in
        'debian')
            a2ensite "$vhostname"
            systemctl restart apache2
            ;;
        'redhat')
            # Allow Apache in SELinux
            chown apache:apache -R "/var/www/html/$vhostname"/
            find "/var/www/html/$vhostname"/ -type f -exec chmod 0644 {} \;
            find "/var/www/html/$vhostname"/ -type d -exec chmod 0755 {} \;
            chcon -t httpd_sys_content_t "/var/www/html/$vhostname" -R
            chcon -t httpd_sys_rw_content_t "/var/www/html/$vhostname" -R
            ;;
    esac
}
function apache_virtualhost_from_rdns {
    apache_virtualhost "$(get_rdns_primary_ip)"
}
function apache_virtualhost_get_docroot {
    # $1 - required - Hostname of the virtualhost being configured
    [ -z "$1" ] && {
        printf "apache_virtualhost_get_docroot() requires the hostname as the first argument\n"
        return 1;
    }
    local -r vhost="$1"
    # Determine distribution, and get the DocumentRoot out of the VirtualHost file
    case "${detected_distro[family]}" in
        'debian')
            [ -e /etc/apache2/sites-available/"$vhost.conf" ] && \
                echo "$(awk '/DocumentRoot/ {print $2}' /etc/apache2/sites-available/"$vhost".conf )"
            ;;
        'redhat')
            [ -e /etc/httpd/conf.d/vhost.conf ] && \
                echo "$(awk '/DocumentRoot/ {print $2}' /etc/httpd/conf.d/vhost.conf)"
            ;;
    esac
}
###########################################################
# mysql-server
###########################################################
function mysql_install {
    # $1 - the mysql root password
    [ -z "$1" ] && {
        printf "mysql_install() requires the root pass as its only argument\n"
        return 1;
    }
    local -r db_root_password="$1"
    case "${detected_distro[family]}" in
        'debian')
            echo "mysql-server mysql-server/root_password password ${db_root_password}" | debconf-set-selections
            echo "mysql-server mysql-server/root_password_again password ${db_root_password}" | debconf-set-selections
            case "${detected_distro[distro]}" in
                'debian')
                    if [ "${detected_distro[version]}" -ge 10 ];
                        then system_install_package mariadb-server
                        else system_install_package mysql-server mysql-client
                    fi
                    ;;
                'ubuntu')
                    system_install_package mysql-server mysql-client
                    ;;
            esac
            ;;
        'redhat')
            system_install_package mariadb-server
            systemctl enable mariadb.service
            systemctl start mariadb.service
            ;;
    esac
    mysql_secure_install "$db_root_password"
    printf "Sleeping while MySQL starts up for the first time...\n"
    sleep 5
}
function mysql_configure {
    local -r db_name="$1" db_root_password="$2" db_username="$3" db_user_password="$4"
    mysql_create_database "$db_root_password" "$db_name"
    mysql_create_user "$db_root_password" "$db_username" "$db_user_password"
    mysql_grant_user "$db_root_password" "$db_username" "$db_name"
}
function mysql_tune {
    # Tunes MySQL's memory usage to utilize the percentage of memory you specify, defaulting to 40%
    # $1 - the percent of system memory to allocate towards MySQL
    if [ -z "$1" ];
        then local -r percent=40
        else local -r percent="$1"
    fi
    case "${detected_distro[family]}" in
        'debian')
            [ ! -f /etc/mysql/my.cnf ] && touch /etc/mysql/my.cnf
            sed -i -e 's/^#skip-innodb/skip-innodb/' /etc/mysql/my.cnf # disable innodb - saves about 100M
            ;;
        'redhat')
            [ ! -f /etc/my.cnf ] && touch /etc/my.cnf
            sed -i -e 's/^#skip-innodb/skip-innodb/' /etc/my.cnf # disable innodb
            ;;
    esac
    local -r mem="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)" # how much memory in MB this system has
    local -r mymem="$((mem*percent/100))" # how much memory we'd like to tune mysql with
    local -r mymemchunks="$((mymem/4))" # how many 4MB chunks we have to play with
    # mysql config options we want to set to the percentages in the second list, respectively
    local optlist=(key_buffer sort_buffer_size read_buffer_size read_rnd_buffer_size myisam_sort_buffer_size query_cache_size)
    local distlist=(75 1 1 1 5 15)
    for opt in "${optlist[@]}"; do
        case "${detected_distro[family]}" in
            'debian')
                sed -i -e "/\[mysqld\]/,/\[.*\]/s/^${opt}/#${opt}/" /etc/mysql/my.cnf
                ;;
            'redhat')
                sed -i -e "/\[mysqld\]/,/\[.*\]/s/^${opt}/#${opt}/" /etc/my.cnf
                ;;
        esac
    done
    for i in "${!optlist[*]}"; do
        val="$(echo | awk "{print int((${distlist[$i]} * ${mymemchunks}/100))*4}")"
        [ $val -lt 4 ] && val=4
        config="${config}\n${optlist[$i]} = ${val}M"
    done
    case "${detected_distro[family]}" in
        'debian')
            sed -i -e "s/\(\[mysqld\]\)/\1\n${config}\n/" /etc/mysql/my.cnf
            systemctl restart mysql
            ;;
        'redhat')
            sed -i -e "s/\(\[mysqld\]\)/\1\n${config}\n/" /etc/my.cnf
            systemctl restart mariadb
            ;;
    esac
}
function mysql_create_database {
    # $1 - the mysql root password
    # $2 - Required - the db name to create
    [ -z "$1" ] && {
        printf "mysql_create_database() requires the root pass as its first argument\n"
        return 1;
    }
    [ -z "$2" ] && {
        printf "mysql_create_database() requires the name of the database as the second argument\n"
        return 1;
    }
    local -r db_root_password="$1" db_name="$2"
    echo "CREATE DATABASE $db_name;" | mysql -u root -p"$db_root_password"
}
function mysql_create_user {
    # $1 - required - the MySQL database's root password
    # $2 - required - the MySQL user to create
    # $3 - required - the MySQL user's password
    [ -z "$1" ] && {
        printf "mysql_create_user() requires the root password as its first argument\n"
        return 1;
    }
    [ -z "$2" ] && {
        printf "mysql_create_user() requires username as the second argument\n"
        return 1;
    }
    [ -z "$3" ] && {
        printf "mysql_create_user() requires a password as the third argument\n"
        return 1;
    }
    local -r db_root_password="$1" db_username="$2" db_user_password="$3"
    echo "CREATE USER '$db_username'@'localhost' IDENTIFIED BY '$db_user_password';" | mysql -u root -p"$db_root_password"
}
function mysql_grant_user {
    # $1 - required - The MySQL database's root password
    # $2 - required - The MySQL user on whom to bestow privileges
    # $3 - required - The MySQL database's name
    [ -z "$1" ] && {
        printf "mysql_create_user() requires the root password as its first argument\n"
        return 1;
    }
    [ -z "$2" ] && {
        printf "mysql_create_user() requires username as the second argument\n"
        return 1;
    }
    [ -z "$3" ] && {
        printf "mysql_create_user() requires a database as the third argument\n"
        return 1;
    }
    local -r db_root_password="$1" db_username="$2" db_user_password="$3"
    echo "GRANT ALL PRIVILEGES ON $db_user_password.* TO '$db_username'@'localhost';" | mysql -u root -p"$db_root_password"
    echo "FLUSH PRIVILEGES;" | mysql -u root -p"$db_root_password"
}
function mysql_secure_install {
    # $1 - required - Root password for the MySQL database
    [ -z "$1" ] && {
        printf "mysql_secure_install() requires the MySQL database root password as its only argument\n"
        return 1;
    }
    local -r db_root_password="$1"
    system_install_package expect
    local -r secure_mysql=$(
expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for ):\"
send \"$db_root_password\r\"
expect \"Change the root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")
    printf "$secure_mysql\n"
}
###########################################################
# PHP functions
###########################################################
function php_install_with_apache {
    # Install PHP
    case "${detected_distro[family]}" in
        'debian')
            case "${detected_distro[version]}" in
                '14.04' | '8')
                    system_install_package php5 php5-mysql libapache2-mod-php5
                    ;;
                *)
                    system_install_package php php-mysql libapache2-mod-php
                    ;;
            esac
            # Restart apache2
            systemctl restart apache2
            ;;
        'redhat')
            system_install_package php php-pear
            system_install_package php-mysqli
            # Restart httpd
            systemctl restart httpd
            ;;
    esac
}
function php_tune {
    # Tunes PHP to utilize up to 32M per process
    case "${detected_distro[family]}" in
        'debian')
            local -r PHPVER="$(php_detect_version)"
            sed -i'-orig' 's/memory_limit = [0-9]\+M/memory_limit = 32M/' /etc/php/"$PHPVER"/apache2/php.ini
            sed -i'-orig' 's/max_input_time = 60/max_input_time = 30/' /etc/php/"$PHPVER"/apache2/php.ini
            sed -i'-orig' 's/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_COMPILE_ERROR | E_RECOVERABLE_ERROR | E_ERROR | E_CORE_ERROR/' /etc/php/"$PHPVER"/apache2/php.ini
            sed -i'-orig' 's/;error_log = php_errors.log/error_log = \/var\/log\/php\/error.log/' /etc/php/"$PHPVER"/apache2/php.ini
            ;;
        'redhat')
            sed -i'-orig' 's/max_input_time = 60/max_input_time = 30/' /etc/php.ini
            sed -i'-orig' 's/error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT/error_reporting = E_COMPILE_ERROR | E_RECOVERABLE_ERROR | E_ERROR | E_CORE_ERROR/' /etc/php.ini
            sed -i'-orig' 's/;error_log = php_errors.log/error_log = \/var\/log\/php\/error.log/' /etc/php.ini
            ;;
    esac
    # Create the log directory for PHP and give ownership to the Apache system user
    # Also, restart Apache
    mkdir /var/log/php
    case "${detected_distro[family]}" in
        'debian')
            chown www-data /var/log/php
            systemctl restart apache2
            ;;
        'redhat')
            chown apache /var/log/php
            systemctl restart httpd
            ;;
    esac
}
function php_detect_version {
    local -r php_version="$(
        php -v | awk -F. '/built/{print $1 $2}' | awk '{print $2}'
    )"
    printf "${php_version:0:1}.${php_version:1:1}\n"
}
###########################################################
# Postfix
###########################################################
function postfix_install_loopback_only {
    # Installs postfix and configure to listen only on the local interface
    # Also allows for local mail delivery
    case "${detected_distro[family]}" in
        'debian')
            echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
            echo "postfix postfix/mailname string localhost" | debconf-set-selections
            echo "postfix postfix/destinations string localhost.localdomain, localhost" | debconf-set-selections
            system_install_package postfix
            /usr/sbin/postconf -e "inet_interfaces = loopback-only"
            ;;
    esac
    [ "${detected_distro[distro]}" == 'fedora' ] && system_install_package postfix
    # postfix was pre-installed and configured for local mail delivery in my
    # tests with CentOS 7, but still needed to be restarted or it produced
    # an error when sending mail
    systemctl restart postfix
}
function postfix_install_smtp_only {
    local -r fqdn="$1"
    echo "postfix postfix/mailname string $fqdn" | debconf-set-selections
    echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections
    system_install_package mailutils postfix
    sed -i 's/inet_interfaces = all/inet_interfaces = loopback-only/' /etc/postfix/main.cf
}
###########################################################
# Other niceties!
###########################################################
function goodstuff {
    # Removed the code to install wget, less, and vim, as they seem to be already installed
    # Will think of some things to add to this later
    # Enable the "ll" list long alias and colorful root Bash prompt
    sed -i -e 's/^#PS1=/PS1=/' /root/.bashrc
    sed -i -e "s/^#alias ll='ls -l'/alias ll='ls -al'/" /root/.bashrc
}
function all_set {
    [ "${detected_distro[family]}" == 'debian' ] && debian_upgrade
    printf "The StackScript has completed successfully.\n"
    touch "/root/.ss-complete"
}
###########################################################
# Utility functions
###########################################################
function restartServices {
    # restarts services that have a file in /tmp/restart-*
    for service in $(ls /tmp/ | grep 'restart-' | cut -d- -f2-10); do
        # Restart the services and delete the restart file from /tmp
        systemctl restart "$service"
        rm -f "/tmp/restart-${service}"
    done
}
function randomString {
    if [ -z "$1" ];
        then length=20
        else length="$1"
    fi
    # Generate a random string
    echo "$(</dev/urandom tr -dc A-Za-z0-9 | head -c $length)"
}
function certbot_ssl {
    # Installs a Certbot SSL cert with a basic HTTPS re-direct for
    # Apache or NGINX. Defaults to Apache if no webserver is specified
    local -r fqdn="$1" soa_email_address="$2" webserver="${3:-apache}"
    local -r ip_address="$(system_primary_ip)"
    [ ! "$(echo "$webserver" | egrep "^apache$|^nginx$")" ] && {
        printf "%s is not a valid option.\n" "$webserver"
        exit 1;
    }
    # Check for propagation and then get a certificate
    if [ "$fqdn" ]; then
        # Install Certbot
        system_install_package python-certbot-"${webserver}"
        check_dns_propagation "$fqdn" "$ip_address"
        sleep 5
        # Get a certificate and re-direct all traffic to HTTPS
        # In case of failure, try a few times, but not so many
        # that certbot imposes their rate limit (50/week)
        declare x=3
        while [ $x -gt 0 ]; do
            if ! certbot -n --"${webserver}" --agree-tos --redirect \
                       -d "$fqdn" -m "$soa_email_address"; then
                ((x-=1))
            else
                break;
            fi
        done
        # Configure auto-renewal for the certificate
        crontab -l > cron
        echo "* 1 * * 1 /etc/certbot/certbot renew" >> cron
        crontab cron
        rm cron
    fi
}
###########################################################
# OS Detection Stuff
###########################################################
# Store detected distribution information in a globally-scoped Associative Array
readonly dist="$(detect_distro 'distro')"
readonly fam="$(detect_distro 'family')"
readonly -A detected_distro="(
    [distro]="${dist,,}" \
    [family]="${fam,,}" \
    [version]="$(detect_distro 'version')"
    [version_major]="$(detect_distro 'version' | cut -d. -f1)"
    [version_minor]="$(detect_distro 'version' | cut -d. -f2)"
)"
###########################################################
# Other functions
###########################################################
function get_started {
    local -r subdomain="$1" domain="$2" ip="$3"
    if [ "$domain" ]; then
        if [ "$subdomain" ]; then
            local -r fqdn="${subdomain}.${domain}"
        else
            local -r fqdn="$domain"
        fi
        local -r hostname="$domain"
    else
        local -r hostname="$(dnsdomainname -A | awk '{print$1}')"
        local -r fqdn=$hostname
    fi
    # Set the hostname and Fully Qualified domain Name (fqdn) in the /etc/hosts file
    printf "Setting IP Address (%s), fqdn (%s), and hostname (%s) in /etc/hosts...\n" "$ip" "$fqdn" "$hostname"
    system_add_host_entry "$ip" "$fqdn" "$hostname"
    # Run initial updates
    system_update
    # Set the hostname
    system_set_hostname "$hostname"
}
function secure_server {
    # Performs basic security configurations for a new Linode
    # Follows the basic steps oulined in Linode's 'How to Secure Your Server' guide -
    #   https://www.linode.com/docs/security/securing-your-server
    #
    # $1 - The username for the limited sudo user
    # $2 - The password for the limited sudo user
    # $3 - Public Key to be used for SSH authentication
    [ -z "$1" ] && {
        printf "secure_server() requires the username for the limited sudo user as its first argument\n"
        return 1;
    }
    [ -z "$2" ] && {
        printf "secure_server() requires the password for the limited sudo user as its second argument\n"
        return 1;
    }
    [ -z "$3" ] && {
        printf "secure_server() requires the Public Key to be used for SSH authentication as its third argument\n"
        return 1;
    }
    local -r user="$1" password="$2" pubkey="$3"
    # Create the user and add give it 'sudo' privileges
    # This function needs updating for systems that use the 'wheel' group
    user_add_sudo "$user" "$password"
    # Configure Public Key Authentication, disable root, and restart SSHd
    user_add_pubkey "$user" "$pubkey"
    ssh_disable_root
    # Configure basic firewall rules
    configure_basic_firewall
    # Install and enable fail2ban
    enable_fail2ban
}
###########################################################
# LAMP Stack functions
###########################################################
function lamp_stack {
    # $1 - required - MySQL database name
    # $2 - required - MySQL database root password
    # $3 - required - MySQL database username
    # $4 - required - MySQL database user's password
    # $5 - optional - Hostname of the VirtualHost to configure
    [ -z "$1" ] && {
        printf "nc_lamp_stack() requires the MySQL database name as it's first argument\n"
    }
    [ -z "$2" ] && {
        printf "nc_lamp_stack() requires the MySQL database password as it's second argument\n"
        return 1;
    }
    [ -z "$3" ] && {
        printf "nc_lamp_stack() requires the MySQL database username as it's third argument\n"
        return 1;
    }
    [ -z "$4"} ] && {
        printf "nc_lamp_stack() requires the MySQL database user's password as it's fourth argument\n"
        return 1;
    }
    local -r db_name="$1" db_root_password="$2" db_username="$3" db_user_password="$4"
    [ "$5" ] && local -r vhost="$5"
    # Install Apache, MySQL, and PHP
    apache_install
    mysql_install "$db_root_password"
    php_install_with_apache
    # Configure the VirtualHost, if applicable
    [ "$vhost" ] && apache_virtualhost "$vhost"
    # Configure the MySQL database
    mysql_configure "$db_name" "$db_root_password" "$db_username" "$db_user_password"
}
###########################################################
# Wordpress functions
###########################################################
function wordpress_install {
    # Installs the latest wordpress tarball from wordpress.org
    # $1 - required - The existing virtualhost to install into
    # $2 - required - The MySQL database root password
    # $3 - required - The Wordpress password
    [ -z "$1" ] && {
        printf "wordpress_install() requires the vitualhost as its first argument\n"
        return 1;
    }
    [ -z "$2" ] && {
        printf "wordpress_install() requires the MySQL database root password as its second argument\n"
        return 1;
    }
    [ -z "$3" ] && {
        printf "wordpress_install() requires the Wordpress password as its third argument\n"
        return 1;
    }
    local -r vhost="$1" db_root_password="$2" wp_pass="$3"
    # We need wget for this. Check if its installed, and install it if not
    [ ! -e /usr/bin/wget ] && system_install_package wget
    # Determine the Document Root for the configured VirtualHost, and produce an
    # error if it can't be determined
    vpath="$(apache_virtualhost_get_docroot "$vhost")"
    [ -z "$vpath" ] && {
        printf "Could not determine DocumentRoot for %s\n" "$vhost"
        return 1;
    }
    local -r wp_path="${vpath}wordpress"
    # Download, extract, chown, and get our config file started
    cd "$vpath"
    wget http://wordpress.org/latest.tar.gz
    tar xfz latest.tar.gz
    cp "$wp_path"/wp-config-sample.php "$wp_path"/wp-config.php
    
    case "${detected_distro[family]}" in
        'debian')
            # Set appropriate permissions
            chown -R www-data: "${wp_path}"
            chown www-data "${wp_path}"/wp-config.php
            ;;
        'redhat')
            if [ "${detected_distro[distro]}" == 'centos' ]; then
                # CentOS 7's default repos contain an outdated PHP, but Wordpress
                # requires the newer versions, so wee need to add a repo and a tool
                system_install_package http://rpms.remirepo.net/enterprise/remi-release-7.rpm
                system_install_package yum-utils
                # Enable the repo which contains the latest PHP version
                yum-config-manager --enable remi-php73
                # Install PHP 7
                system_install_package php php-pear php-mysql
            fi
            # More permissions
            chown -R apache:apache "$wp_path"
            chown apache "$wp_path"/wp-config.php
            ;;
    esac
    # Even more permissions
    chmod 640 "$wp_path"/wp-config.php
    # Database configuration
    mysql_create_database "$db_root_password" wordpress
    mysql_create_user "$db_root_password" wordpress "$wp_pass"
    mysql_grant_user "$db_root_password" wordpress wordpress
    # Configuration file updates
    for i in {1..4}
        do sed -i "0,/put your unique phrase here/s/put your unique phrase here/$(randomString 50)/" "$wp_path"/wp-config.php
    done
    sed -i 's/database_name_here/wordpress/' "$wp_path"/wp-config.php
    sed -i 's/username_here/wordpress/' "$wp_path"/wp-config.php
    sed -i "s/password_here/$wp_pass/" "$wp_path"/wp-config.php
    # Update the VirtualHost file to point to the wordpress installation and restart apache2
    case "${detected_distro[family]}" in
        'debian')
            sed -i 's/public_html/public_html\/wordpress/' /etc/apache2/sites-available/"$vhost".conf
            systemctl restart apache2
            ;;
        'redhat')
            sed -i 's/public_html/public_html\/wordpress/' /etc/httpd/conf.d/vhost.conf
            systemctl restart httpd
            ;;
    esac
}
function ufw_install {
    # Install UFW and add basic rules
    system_install_package ufw
    ufw default allow outgoing
    ufw default deny incoming
    ufw allow ssh
    ufw enable
    systemctl enable ufw
    # Stop flooding Console with messages
    ufw logging off
}
function stackscript_cleanup {
    [ "${detected_distro[family]}" == 'debian' ] && debian_upgrade
    # Force IPv4 and noninteractive upgrade after script runs to prevent breaking nf_conntrack for UFW
    echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
    # Clean up
    rm /root/StackScript
    rm /root/ssinclude*
    echo "Installation complete!"
}