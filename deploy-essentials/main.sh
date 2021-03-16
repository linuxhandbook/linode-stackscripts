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

logfile="/var/log/stackscript.log"

error(){
    for x in "$@"; do
		test -n "$x" && \
			printf "[ERROR] ($(date '+%y-%m-%d %H:%M:%S')) %s\n" "$x" >> $logfile
    done
}

info(){
    for x in "$@"; do
		test -n "$x" && \
			printf "[INFO] ($(date '+%y-%m-%d %H:%M:%S')) %s\n" "$x" >> $logfile
    done
}

log(){
    # log command error info
    local msg
	msg="$(2>&1 eval \"$1\")"
    [ $? -ne 0 ] && \
        error "$msg" "$2" || \
            info "$msg" "$3"
}

## User creation ##
user_create() {
    # user_create user [password]
    local ret=0
    [ -z "$USER_PASSWORD" ] && \
		USER_PASSWORD=$(awk -F: '$1 ~ /^root$/ { print $2 }' /etc/shadow) \
		|| USER_PASSWORD=$(openssl passwd -6 $USER_PASSWORD)
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
    local ret=0
    local sedopts="-i -E /etc/ssh/sshd_config -e 's/.*Port 22/Port $SSH_PORT/' \
                    -e 's/.*(PermitEmptyPasswords) .+/\1 no/' \
                    -e 's/.*(X11Forwarding) .+/\1 no/' \
                    -e 's/.*(ClientAliveInterval) .+/\1 300/' \
                    -e 's/.*(ClientAliveCountMax) .+/\1 2/' \
                    -e 's/.*(PubkeyAuthentication) .+/\1 yes/'"

    if [ -d /root/.ssh ]; then
        
        if [ "$USER" ]; then
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

debian_upgrade(){
	export DEBIAN_FRONTEND="noninteractive"
	>/dev/null 2>&1 apt update -qq && \
		>/dev/null 2>&1 apt upgrade -qqy
}

log "user_create" \
    "$USER creation failed." "$USER creation successful."
log "ssh_config" \
    "SSH configuration failed." "SSH configuration successful."

[ "$ROOT_LOCK" = "yes" ] && {
    log "passwd -l root" \
        "root lock failed." "root locked successfully."
}

[ "$UPGRADE" = "yes" ] && {
    log "upgrade" \
        "System upgrade failed." "System upgrade completed successfully."
}
