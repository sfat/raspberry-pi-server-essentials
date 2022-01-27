#!/usr/bin/env bash
#
# Script to wake up servers on a scheduled basis using WoL (Wake on Lan) to power on servers in the morning,
# while the servers themselves have a cron task that shutdown themselves at midnight (5 minutes after midnight to be more precise)
#
# Servers from the homelab are not running 24/7, so from a cost/power point of view.
# this runs once a day
# run
# crontab -e
# 0 9 * * * bash /home/pi/wol-servers.sh \
#                                        <( (( ${#SERVER_HOSTS[@]} )) && printf '%s\0' "${SERVER_HOSTS[@]}") \
#                                        <( (( ${#SERVER_MACADDRS[@]} )) && printf '%s\0' "${SERVER_MACADDRS[@]}") > wol-servers.log
# e.g:
# SERVER_HOSTS=(192.168.0.1 192.168.0.2 192.168.0.3)
# SERVER_MACADDRS=(mac.address.1 mac.address.2 mac.address.3)
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

# bash 4.4 or newer
mapfile -d '' HOSTS <"$1"
mapfile -d '' MACADDRS <"$2"

HOSTNUM=0
HOSTSDOWN=0
PING="/bin/ping -q -c1"

### functions

function wake_up() {
  echo ${MACADDRS[@]}
  echo wakeonlan ${MACADDRS[${HOSTNUM}]}
  echo wakeonlan -p 9 ${MACADDRS[${HOSTNUM}]}
  echo sudo etherwake ${MACADDRS[${HOSTNUM}]}
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
