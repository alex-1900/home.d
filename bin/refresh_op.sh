#!/usr/bin/env bash

if [ -f ~/.op_session ]; then
    export OP_SESSION=$(cat ~/.op_session)
fi

if ! op whoami > /dev/null 2>&1; then
    export OP_SESSION=$(op signin --raw)
    echo "$OP_SESSION" > ~/.op_session
fi

op vault list
