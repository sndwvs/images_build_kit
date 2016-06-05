#!/bin/bash


dirs=("config/board/cubietruck/*.conf" "config/board/firefly/*.conf")

get_config() {
#    local dirs=("$@")
    dirs=("config/board/cubietruck/*.conf" "config/board/firefly/*.conf")
    for file in "${dirs[@]}"; do
        echo $file
        echo $ROOT_DISK
        source $file
        echo $ROOT_DISK
    done
}

#get_config "${dirs[@]}"