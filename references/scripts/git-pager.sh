#!/bin/sh
if [ "$(tput cols)" -gt 160 ]; then
    delta --side-by-side
else
    delta
fi
