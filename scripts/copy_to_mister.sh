#!/bin/bash

set -e
cd "$(dirname "$0")/.."

if [ "$1" == "git" ]; then
    release_filename=CDi_$(git rev-parse --short HEAD).rbf
elif [ "$1" == "date" ]; then
    release_filename=CDi_$(date '+%Y%m%d').rbf
elif [ "${#1}" -gt 2 ]; then
    release_filename=CDi_$1.rbf
else
    echo "Usage: [git|date|<name>]"
    exit 0
fi

echo "Will be named $release_filename"
echo

scp output_files/CDi.rbf root@mister:/media/fat/$release_filename
echo "Created /media/fat/$release_filename on MiSTer !"
