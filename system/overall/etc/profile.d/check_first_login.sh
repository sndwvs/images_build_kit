#!/bin/bash
# only do this for interactive shells
if [ "$-" != "${-#*i}" ]; then
    if [ -f "$HOME/.never_logged" ]; then
        echo -e "\n\e[0;36mSupport: \e[1m\e[39mslarm64.org\x1B[0m\n"
        echo -e "Creating new account. Please provide a username (eg. your forename): \c"
        read username
        RealUserName="$(echo "${username}" | tr '[:upper:]' '[:lower:]' | tr -d -c '[:alpha:]')"
        adduser ${RealUserName} || reboot
        for additionalgroup in netdev audio video dialout plugdev ; do
            usermod -aG ${additionalgroup} ${RealUserName}
        done
        # fix for gksu in Xenial
        touch /home/$RealUserName/.Xauthority
        chown $RealUserName:users /home/$RealUserName/.Xauthority
        rm -f "$HOME/.never_logged"
        RealName="$(awk -F":" "/^${RealUserName}:/ {print \$5}" </etc/passwd | cut -d',' -f1)"
        echo -e "\nDear \e[1m\e[39m${RealName}\x1B[0m, your account \e[1m\e[39m${RealUserName}\x1B[0m has been created."
        echo -e "Please use this account for your daily work from now on.\n"
    fi
fi
