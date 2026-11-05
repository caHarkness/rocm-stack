#!/bin/bash

check_pm2() {
    pm2 --version || (
        echo "PM2 not detected, installing..."
        apt install nodejs npm
        npm install -g n
        n latest
        npm install -g pm2
        pm2 startup
        pm2 save --force
    )
}

if [[ "$@" =~ "--start" ]]
then
    check_pm2
    pm2 start "$0" --name "${APP_NAME}"
    pm2 logs "${APP_NAME}"
    exit 0
fi

if [[ "$@" =~ "--stop" ]]
then
    check_pm2
    pm2 stop "${APP_NAME}"
    exit 0
fi

if [[ "$@" =~ "--logs" ]]
then
    check_pm2
    pm2 logs "${APP_NAME}"
    exit 0
fi
