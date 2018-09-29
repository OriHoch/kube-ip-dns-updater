#!/usr/bin/env bash

[ "${1}" == "" ] && echo ERROR! Missing version label &&\
                    echo current VERSION.txt = $(cat VERSION.txt) && exit 1

echo "${1}" > VERSION.txt
docker build -t orihoch/kube-ip-dns-updater:v${1} . && docker push orihoch/kube-ip-dns-updater:v${1} &&\
    echo Successfully released orihoch/kube-ip-dns-updater:v${1} && exit 0

echo Failed to build / push
exit 1
