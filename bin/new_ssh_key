#!/usr/bin/env bash

if [ $# -lt 1 ]; then
    echo "error params"
    exit
fi

SCRIPT_DIR=$(dirname "$(realpath "$BASH_SOURCE")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")

priv_key_path="$PROJECT_DIR"/configs/ssh/certs/id_"$1"_ed25519
ssh-keygen -t ed25519 -f "$priv_key_path" -N "" -C "$USER_EMAIL"

chmod 600 "$priv_key_path"
chmod 644 "$priv_key_path".pub
