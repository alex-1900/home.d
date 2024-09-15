#!/usr/bin/env bash

service ssh start

v2ray -c /etc/v2ray/config.json &
