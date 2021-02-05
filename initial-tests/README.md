## A StackScript for Docker with SSH Rules and other extras

This is the first complete test script we first developed and tested at Linux Handbook to keep deployment times at an absolute minimum. Please note that this script is for educational purposes only.
Better used as a reference, it is recommended that you refer to the other stackscript folders in this repository for more specific scripts derived from this one. That would help you stay focused only on your bare-minimum requirements and specific necessities.

The script performs the following steps post a fresh deployment of an Ubuntu 20.04 based Linode. You can test it on other cloud servers as well but step 6 would require the root user to already have an SSH public key.

### 1. Allocates extra 2G swap

Considering the server usually has 1-2GB of RAM, this can be an essential requirement.

### 2. Upgrades default packages

Takes care of all the bundled Ubuntu packages so you won't have to after the server is deployed.

### 3. Installs essential packages to be production ready

Docker Compose package provided by the Ubuntu repositories(includes Docker). 
Auditd tool is installed for setting audit rules for Docker.
jq for docker network monitoring.

### 4. Updates auditd rules for docker

Uses the `cat` command to update various auditing rules for Docker located in different files.

### 5. Creates a new user "tux" with sudo privileges*

This particular step can be a temporary one after you have just deployed your server. *So please be cautious with this one. Make sure to create your own new user with or without sudo privileges and then remove the tux user.
The password set for tux here is `KJHkkjsf4iu3ubHJHAajh`.

### 6. Saves SSH public keys for tux from Linode profile

Copies the SSH public key from the root user before disabling the latter in the next step.

### 7. Hardens SSH rules

Hardens the following SSH settings:

- Changes the default port to 4566
- Disables Root Login
- Enables Public key authentication
- Disables Password Authentication
- Disallows Empty Passwords 
- Disables X11 Forwarding
- Sets Client Alive Interval to 300 seconds
- Sets Client Alive Maximum Count to 2

### 8. Enables automatic security and recommended updates

By reconfiguring `unattended-upgrades`, this step enables automatic security updates alongwith the recommended updates as well. You can also enable live patching after deployment if required.

### 9. Installs Nginx with SSL support on Docker

Since we use Jwilder Nginx with its Let's Encrypt Companion as a standard framework throughout our application deployment and testing, we included this as well. All you would now be needing is the application's Docker Compose configuration.
So, this allows testing and deploying apps even faster!
