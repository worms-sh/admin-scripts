#! /bin/sh
#
# This script sets up the home directory for a new user.
# Usage: doas ./new_user.sh <username>
# TODO:
#   - split out sections into individual scripts
#   - handle partial failures (currently aborts on any non-zero exit)
#   - setup ssh key with a file input
#   - move into ansible role

set -o nounset
set -o errexit

if [ "$(id -u)" -ne 0 ]; then
    echo "Need to run as UID=0!"
    exit 1
fi

username=$1
userhome="/home/${username}"

SCRIPT_DIR=$(dirname -- "$( readlink -f -- "$0"; )")
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

### BEGIN PRE-SCRIPT CHECKS ###
# check that user exists
if id "$1" >/dev/null 2>&1; then
    continue
else
    echo "Error: ${username} doesn't exist."
    exit 1
fi

# check that user has home dir
if [ -d ${userhome} ]; then
    echo "Setting up home directory for ${username}"
else
    echo "Error: ${username} doesn't have a home directory."
    exit 1
fi
### END PRE-SCRIPT CHECKS ###


### BEGIN ZSH CONFIG ###
# check if ~/.zshrc already exists
if [ -f ${userhome}/.zshrc ]; then
    echo ".zshrc already exists!"
    exit 1
else
    echo "Setting up zshrc"
fi
sed "s|USERHOME|${userhome}|" "${TEMPLATES_DIR}/zshrc.tmpl" > "${userhome}/.zshrc"
### END ZSH CONFIG ###


### BEGIN HTTP CONFIG ###
# setup ~/public_html/index.html
HTML_DIR="${userhome}/public_html"
echo "Creating ${HTML_DIR}"
mkdir -p "${HTML_DIR}"

echo "Creating index.html"
if [ -f ${HTML_DIR}/index.html ]; then
    echo "index.html already exists! Exiting..."
    exit 1
else
    sed "s/USER/${username}/" "${TEMPLATES_DIR}/index.html.tmpl" > "${HTML_DIR}/index.html"
fi

# configure lighttpd
echo "Adding ${username} to lighttpd config"
httpd_user_conf=/usr/local/etc/lighttpd/conf.d/userdir.conf

# check is user public_html is already configured
if grep "userdir\.include-user.*\"${username}\"" "${httpd_user_conf}" >/dev/null 2>&1; then
    echo "${username} is already in lighttpd config! Exiting..."
    exit 1
else
    sed -i ".old" "/userdir.include-user/{s/\")/\", \"$username\")/;}" "${httpd_user_conf}"
    restart_lighttpd=true
fi

if [ -n ${restart_lighttpd+x} ]; then
    echo "Restarting lighttpd"
    service lighttpd restart
fi
### END HTTP CONFIG ###


### BEGIN SET UP PERMISSIONS ###
echo "Setting ownership and permissions"
chown -R "${username}:${username}" "${userhome}"
chmod 755 "${HTML_DIR}"
chmod 644 "${HTML_DIR}/index.html"
chmod 644 "${userhome}/.zshrc"
### END SET UP PERMISSIONS ###


exit 0
