#!/bin/bash
#
# Script to wake up servers on a scheduled basis using WoL (Wake on Lan) to power on servers in the morning,
# while the servers themselves have a cron task that shutdown themselves at midnight (5 minutes after midnight to be more precise)
#
# Servers from the homelab are not running 24/7, so from a cost/power point of view.
# this runs once a day
# run
# crontab -e
# 0 9 * * * . /root/.bashrc; bash /home/pi/raspberry-pi-server-essentials/wol-servers.sh -s $SERVER_HOSTS -m $SERVER_MACADDRS >> /var/log/wol-servers.log 2>&1
# where -s represents the server ips and the -m represents the server mac addresses (used by the WoL utilities)
#
# e.g:
# in /root/.bashrc
# export SERVER_HOSTS="192.168.0.1 192.168.0.2 192.168.0.3"
# export SERVER_MACADDRS="mac.address.1 mac.address.2 mac.address.3"
#
# Note: when setting SERVER_HOSTS and SERVER_MACADDRS variables, order matters. each ip address corresponds to the same position in the mac address variable
# 
# You can set these env variables in `/root/.bashrc`
# Make sure to set the variables as root and also to edit the crontab for root because of some commands that require sudo access
#
# requires etherwake and wakeonlan (apt-get) - this script will try to install them if they do not exist
# installed etherwake and wakeonlan beacuse I had some issues with one or the other between updates, so I added both

# check if required packages exist
REQUIRED_PKG="etherwake wakeonlan"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
  echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
  sudo apt-get --yes install $REQUIRED_PKG
fi

function getopts-extra () {
    declare i=1
    # if the next argument is not an option, then append it to array OPTARG
    while [[ ${OPTIND} -le $# && ${!OPTIND:0:1} != '-' ]]; do
        OPTARG[i]=${!OPTIND}
        let i++ OPTIND++
    done
}

while getopts ":s:m:" opt; do
    case $opt in
        s) getopts-extra "$@"
           HOSTS=( "${OPTARG[@]}" )
	   ;;
        m) getopts-extra "$@"
           MACADDRS=( "${OPTARG[@]}" )
	   ;;
    esac
done

echo "hosts: ${HOSTS[@]}"
echo "mac addresses: ${MACADDRS[@]}"

HOSTNUM=0
HOSTSDOWN=0
PING="/bin/ping -q -c1"

### functions

function wake_up() {
  wakeonlan ${MACADDRS[${HOSTNUM}]}
  wakeonlan -p 9 ${MACADDRS[${HOSTNUM}]}
  sudo etherwake ${MACADDRS[${HOSTNUM}]}
}

# first sleep to allow system to connect to network and time to break out if needed
#sleep 60

for HOST in ${HOSTS[*]}; do
  if ! ${PING} ${HOST} > /dev/null
  then
    HOSTSDOWN=$((${HOSTSDOWN}+1))
    echo "${HOST} is down $(date)"
    # try to wake
    wake_up ${HOSTNUM}
    sleep 10
    wake_up ${HOSTNUM}
    sleep 10
    wake_up ${HOSTNUM}
    sleep 10
    wake_up ${HOSTNUM}
    sleep 10
    #restart networking
    /etc/init.d/networking reload
    sleep 15
    # try to wake
    wake_up ${HOSTNUM}
    sleep 2
    wake_up ${HOSTNUM}
    sleep 2
    HOSTNUM=$(($HOSTNUM+1))
  else
    echo "${HOST} was up at $(date)"
    HOSTNUM=$(($HOSTNUM+1))
  fi
done

# reboot
if [ ${HOSTSDOWN} -eq ${#HOSTS[@]} ]; then
  echo "Pi is rebooting"
  /sbin/shutdown -r now
fi
