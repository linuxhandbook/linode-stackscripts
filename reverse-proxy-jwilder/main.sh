#! /bin/sh


#! /bin/sh

# Created by Debdut Chakraborty for Linux Handbook (andanotheremailid@gmail.com)
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


# UDF variables
# <UDF name="USER" label="Create a non-root user" example="Using root user directly is not recommended" default=""/>
# <UDF name="USER_PASSWORD" label="Create a non-root user password" example="Example: mo7adL*^*3MD$QJcQYLcKLPrLx" default=""/>
# <UDF name="UPGRADE" label="Upgrade the system automatically ?" oneof="yes,no" default="yes" />
# <UDF name="SSH_PORT" label="Set SSH server port" example="This won't be reflected in your Linode Dashboard" default="22" />
# <UDF name="ROOT_LOCK" label="Lock the root account ?" oneof="yes,no" default="yes" />
# <UDF name="DOCKER_GROUP" label="Add the non-root user to the docker group?" oneof="yes,no" default="no" />

logfile="/var/log/stackscript.log"

export DEBIAN_FRONTEND=noninteractive

error(){
    for x in "$@"; do
        test -n "$x" && printf "[ERROR] (`date '+%y-%m-%d %H:%M:%S'`) %s\n" "$x" >> $logfile
    done
}

info(){
    for x in "$@"; do
        test -n "$x" && printf "[INFO] (`date '+%y-%m-%d %H:%M:%S'`) %s\n" "$x" >> $logfile
    done
}

log(){
    # log command-msg user-msg
    local msg
    msg="`eval $1`"
    [ $? -ne 0 ] && \
        error "$msg" "$2" || \
            info "$msg" "$3"
}

## User creation ##
user_create() {
    # user_create user [password]
    local ret=0
    [ -z "$USER_PASSWORD" ] && \
        USER_PASSWORD=`perl -n -e 'print/root:([^:]+):\d+:[\w\W]+/?$1:""' /etc/shadow` \
        || USER_PASSWORD=`openssl passwd -6 $USER_PASSWORD`
    ret=$?
    
    useradd -mG sudo \
        -s /bin/bash \
        -p $USER_PASSWORD \
        $USER
    ret=$((ret+$?))
    return $ret
}

ssh_config(){
    # ssh_config ...
    local ret
    local sedopts="-i -E /etc/ssh/sshd_config -e 's/.*Port 22/Port $SSH_PORT/' \
                    -e 's/.*(PermitEmptyPasswords) .+/\1 no/' \
                    -e 's/.*(X11Forwarding) .+/\1 no/' \
                    -e 's/.*(ClientAliveInterval) .+/\1 300/' \
                    -e 's/.*(ClientAliveCountMax) .+/\1 2/' \
                    -e 's/.*(PubkeyAuthentication) .+/\1 yes/'"

    if test -d /root/.ssh; then
        
        if [ -n "$USER" ]; then
            sedopts="$sedopts -e 's/.*(PermitRootLogin) .+/\1 no/'"
            cp -r /root/.ssh /home/$USER && \
                chown -R $USER:$USER /home/$USER/.ssh && \
                chmod 700 /home/$USER/.ssh
                ret=$?
        else
            sedopts="$sedopts -e 's/.*(PermitRootLogin) .+/\1 yes/'"
        fi
        
        sedopts="$sedopts -e 's/.*(PasswordAuthentication) .+/\1 no/'"

    else

        sedopts="$sedopts -e 's/.*(PasswordAuthentication) .+/\1 yes/'"
    fi
        
    eval sed $sedopts
    ret=$((ret+$?))
    systemctl restart ssh
    ret=$((ret+$?))
    return $ret
}

install_docker(){
    apt install \
        apt-transport-https ca-certificates \
        curl gnupg-agent software-properties-common -y >/dev/null || return
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - >/dev/null || return
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >/dev/null || return
    apt update >/dev/null && \
        apt install \
            docker-ce docker-ce-cli \
            containerd.io auditd jq docker-compose -y >/dev/null || return
}

docker_post_install(){

    [ "$DOCKER_GROUP" = "yes" ] && usermod -aG docker $USER

    cat <EOF >> /etc/audit/rules.d/audit.rules
-w /usr/bin/docker -p wa
-w /var/lib/docker -p wa
-w /etc/docker -p wa
-w /lib/systemd/system/docker.service -p wa
-w /lib/systemd/system/docker.socket -p wa
-w /usr/bin/containerd -p wa
-w /etc/docker/daemon.json -p wa
EOF

    cat <EOF > /etc/docker/daemon.json
{
  "icc": false,
  "live-restore": true,
  "no-new-privileges": true
}
EOF

    systemctl enable --now docker >/dev/null
    systemctl enable --now auditd >/dev/null
}


jwilder_nginx_jrcs_letsencrypt(){
    local tmpdir=`mktemp -d`
    (
        cd $tmpdir
        for file in docker-compose.yaml max_upload_size.conf; do
            curl -O \
                https://raw.githubusercontent.com/linuxhandbook/linode-stackscripts/main/reverse-proxy-jwilder/$file
        done
    )
    local compose_dir
    [ "$USER" ] && compose_dir=/home/$USER/reverse-proxy || compose_dir=/root/reverse-proxy

    mv $tmpdir $compose_dir
    (cd $compose_dir; docker-compose up -d)
    [ "$USER" ] && chown -R $USER:$USER $compose_dir
}


user_create
ssh_config

[ "$ROOT_LOCK" = "yes" ] && {
    passwd -l root >/dev/null
}

[ "$UPGRADE" = "yes" ] && {
    apt update -qq >/dev/null && \
        apt upgrade -y >/dev/null
}

install_docker
docker_post_install
jwilder_nginx_jrcs_letsencrypt