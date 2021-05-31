#!/bin/bash
#
# original script
# https://archlinuxarm.org/packages/any/fake-hwclock/files/fake-hwclock.sh
#

THISFILE=$0
STATEFILE=$0

save_timestamp=$(stat -c %Y "$STATEFILE")

if [ $(date +%s) -lt $save_timestamp ]; then
    echo "Restoring saved system time"
    date -s @$save_timestamp
else
    echo "Saving current time."
    touch "$STATEFILE"
fi

unset save_timestamp
