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

# <ssinclude StackScriptID=737400>
. /root/ssinclude-737400

install_docker(){
	export DEBIAN_FRONTEND="noninteractive"

    apt install \
        apt-transport-https ca-certificates \
        curl gnupg-agent software-properties-common -qqy >/dev/null || return $?

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
		sudo apt-key add - >/dev/null || return $?

    >/dev/null add-apt-repository \
		"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
		|| return $?

    >/dev/null 2>&1 apt update -qq && \
        >/dev/null 2>&1 apt install \
            docker-ce docker-ce-cli \
            containerd.io auditd jq docker-compose -qqy || return $?
}

docker_post_install(){

    if [ "$DOCKER_GROUP" = "yes" ]; then
		usermod -aG docker $USER \
			&& error "$USER was'nt added to the docker group." \
			|| info "$USER was successfully added to the docker group."
	fi		

    cat <<EOF >> /etc/audit/rules.d/audit.rules
-w /usr/bin/docker -p wa
-w /var/lib/docker -p wa
-w /etc/docker -p wa
-w /lib/systemd/system/docker.service -p wa
-w /lib/systemd/system/docker.socket -p wa
-w /usr/bin/containerd -p wa
-w /etc/docker/daemon.json -p wa
EOF

    cat <<EOF > /etc/docker/daemon.json
{
  "icc": false,
  "live-restore": true,
  "no-new-privileges": true
}
EOF

	local ret=0

    systemctl enable docker
	ret=$(($ret+$?))
    systemctl enable auditd
	return $(($ret+$?))
}


log "install_docker" \
	"Docker install failed." "Docker install successful."

log "docker_post_install" \
	"Docker post install configuration failed." "Docker post install configuration successful."
