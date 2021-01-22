#! /bin/sh

# Copyight 2020 Debdut Chakraborty
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

## User creation ##
user_create() {
    # user_create user [password]
    [ -z "$USER_PASSWORD" ] && \
        USER_PASSWORD=`perl -n -e 'print/root:([^:]+):\d+:[\w\W]+/?$1:""' /etc/shadow` \
        || USER_PASSWORD=`openssl passwd -6 $USER_PASSWORD`
    
    useradd -mG sudo \
        -s `realpath /bin/sh` \
        -p $USER_PASSWORD \
        $USER
}

ssh_config(){
    # ssh_config ...
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
        else
            sedopts="$sedopts -e 's/.*(PermitRootLogin) .+/\1 yes/'"
        fi
        
        sedopts="$sedopts -e 's/.*(PasswordAuthentication) .+/\1 no/'"

    else

        sedopts="$sedopts -e 's/.*(PasswordAuthentication) .+/\1 yes/'"
    fi
        
    eval sed $sedopts
    systemctl restart ssh
}

user_create
ssh_config

[ "$ROOT_LOCK" = "yes" ] && {
    usermod -s /bin/nologin root
}

[ "$UPGRADE" = "yes" ] && {
    apt update && apt upgrade -y
}