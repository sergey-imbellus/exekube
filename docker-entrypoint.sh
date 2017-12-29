#!/bin/bash

if [ "$1" = 'apply' ] || [ "$1" = 'init' ] || [ "$1" = 'destroy' ]; then
        if [ -z "$2" ]; then
                cd $XK_WORKDIR && terraform $1
        else
                cd $2 && terraform $1
        fi
else
        $@
fi
