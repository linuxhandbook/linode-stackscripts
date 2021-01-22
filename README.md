This repository contains various scripts (StackScripts) that are used to make Linode deployments much easier and secure. There will be multiple scripts, intended for different purposes. Each script is going to be under the appropriate subdirectory and can be found directly from your Linode Dashboard under community StackScripts.

# 1. deploy-essentials

This script doesn't do much. It is currently tested under Ubuntu 20.04 LTS but *should* work with other Ubuntu flavours as well. The short list of things that this script does are as follows

- Asks for a non-root user name and password.
- Change many SSH daemon configuration parameters (like disabling password authentication if public keys are found on the filesystem).
- Optionally updates the whole server (this is optional because in certain situations like small tests updating may not be very necessary).
- Locks the root user altogether.

## TODO

- Make the script compatible with all flavours of Alpine, Debian, Arch, OpenSUSE, Fedora.
- Optionally add automatic upgrades for certain distributions.
