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

# <ssinclude StackScriptID=759036>
# <ssinclude StackScriptID=737400>
. /root/ssinclude-759036

jwilder_nginx_jrcs_letsencrypt(){
    local compose_dir 
	local ret=0
    
	[ "$USER" ] && compose_dir=/home/$USER/reverse-proxy || compose_dir=/root/reverse-proxy

    (
		ret=0
        mkdir $compose_dir -p && cd $compose_dir
        for file in docker-compose.yaml max_upload_size.conf; do
            curl -sO \
                https://raw.githubusercontent.com/linuxhandbook/linode-stackscripts/main/reverse-proxy-jwilder/$file
				ret=$(($ret+$?))
        done
		docker network create net
		ret=$(($ret+$?))
		docker-compose up -d >/dev/null
		exit $(($ret+$?))
    )
	ret=$(($ret+$?))

	[ "$USER" ] && chown -R $USER:$USER $compose_dir
	
	return $ret
}

log "jwilder_nginx_jrcs_letsencrypt" \
	"Reverse proxy deployment failed." "Reverse proxy successfully deployed."
