#!/usr/bin/env bash
# Script to wake up servers on a scheduled basis using WoL (Wake on Lan) to power on servers in the morning,
# while the servers themselves have a cron task that shutdown themselves at midnight (5 minutes after midnight to be more precise)
#
# Servers from the homelab are not running 24/7, so from a cost/power point of view.
# this runs once a day
# run
# crontab -e
# 0 9 * * * bash /home/pi/raspberry-pi-server-essentials/power-on-servers.sh > power-on-servers.log
# e.g:
# export SERVER_HOSTS=(192.168.0.1 192.168.0.2 192.168.0.3)
# export SERVER_MACADDRS=(mac.address.1 mac.address.2 mac.address.3)


./wol-servers.sh \
                <( (( ${#SERVER_HOSTS[@]} )) && printf '%s\0' "${SERVER_HOSTS[@]}") \
                <( (( ${#SERVER_MACADDRS[@]} )) && printf '%s\0' "${SERVER_MACADDRS[@]}")
