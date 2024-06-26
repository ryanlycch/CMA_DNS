#!/bin/bash

# Parameter
OWNER="hezhijie0327"
REPO="gost"
TAG="latest"

RUNNING_MODE="" # client, server

GOST_HOST="" # demo.zhijie.online
GOST_IP=() # ("1.0.0.1" "1.1.1.1")
GOST_DYNAMIC_IP="" # cdn.jsdelivr.net.cdn.cloudflare.net,127.0.0.1 | production.cloudflare.docker.com,127.0.0.1 | cdn.cloudflare.steamstatic.com,127.0.0.1
GOST_PORT="" # 8443

GOST_KNOCK="" # demo.zhijie.online
GOST_PROBERESISTANCE="" # code:403, web:demo.zhijie.online/page.html, host:demo.zhijie.online:443, file:/send/to/client/file.txt

GRPC_USERNAME="" # 99235a6e-05d4-2afe-2990-5bc5cf1f5c52
GRPC_PASSWORD="" # $(echo "${GRPC_USERNAME:-99235a6e-05d4-2afe-2990-5bc5cf1f5c52}" | base64)

HTTP_SOCKS5_FORWARD="" # 127.0.0.1:40000

WG_LOCAL_PORT="" # 51821
WG_REMOTE_PORT="" # 51820

SSL_CERT="" # fullchain.cer
SSL_KEY="" # zhijie.online.key

## Function
# Get Latest Image
function GetLatestImage() {
    docker pull ${OWNER}/${REPO}:${TAG} && IMAGES=$(docker images -f "dangling=true" -q)
}
# Cleanup Current Container
function CleanupCurrentContainer() {
    if [ $(docker ps -a --format "table {{.Names}}" | grep -E "^${REPO}$") ]; then
        docker stop ${REPO} && docker rm ${REPO}
    fi
}
# Create New Container
function CreateNewContainer() {
    if [ "${GOST_PROBERESISTANCE}" != "" ]; then
        GOST_ADDITIONAL_PARAMETERS="?probeResistance=${GOST_PROBERESISTANCE}"

        if [ "${GOST_KNOCK}" != "" ]; then
            GOST_ADDITIONAL_PARAMETERS="${GOST_ADDITIONAL_PARAMETERS}&knock=${GOST_KNOCK}"
        fi
    fi

    if [ "${HTTP_SOCKS5_FORWARD}" != "" ]; then
        HTTP_SOCKS5_FORWARD="/${HTTP_SOCKS5_FORWARD}"
    fi

    if [ "${RUNNING_MODE:-server}" == "server" ]; then
        docker run --name ${REPO} --net host --restart=always \
            -v /docker/ssl/${SSL_CERT:-fullchain.cer}:/cert.pem:ro \
            -v /docker/ssl/${SSL_KEY:-zhijie.online.key}:/key.pem:ro \
            -d ${OWNER}/${REPO}:${TAG} \
            -L "http://:7890${HTTP_SOCKS5_FORWARD}" \
            -L "socks5://:7891${HTTP_SOCKS5_FORWARD}" \
            -L "relay+grpc://${GRPC_USERNAME:-99235a6e-05d4-2afe-2990-5bc5cf1f5c52}:${GRPC_PASSWORD:-$(echo ${GRPC_USERNAME:-99235a6e-05d4-2afe-2990-5bc5cf1f5c52} | base64)}@:${GOST_PORT:-8443}${GOST_ADDITIONAL_PARAMETERS}"
    else
        if [ "${GOST_DYNAMIC_IP}" != "" ]; then
            GOST_IP=(
                $(dig @$(echo ${GOST_DYNAMIC_IP} | cut -d ',' -f 2) +short A $(echo ${GOST_DYNAMIC_IP} | cut -d ',' -f 1) | grep -E "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$" | sort -n | uniq | awk "{ print $2 }")
                $(dig @$(echo ${GOST_DYNAMIC_IP} | cut -d ',' -f 2) +short AAAA $(echo ${GOST_DYNAMIC_IP} | cut -d ',' -f 1) | grep -E "^(([0-9a-f]{1,4}:){7,7}[0-9a-f]{1,4}|([0-9a-f]{1,4}:){1,7}:|([0-9a-f]{1,4}:){1,6}:[0-9a-f]{1,4}|([0-9a-f]{1,4}:){1,5}(:[0-9a-f]{1,4}){1,2}|([0-9a-f]{1,4}:){1,4}(:[0-9a-f]{1,4}){1,3}|([0-9a-f]{1,4}:){1,3}(:[0-9a-f]{1,4}){1,4}|([0-9a-f]{1,4}:){1,2}(:[0-9a-f]{1,4}){1,5}|[0-9a-f]{1,4}:((:[0-9a-f]{1,4}){1,6})|:((:[0-9a-f]{1,4}){1,7}|:)|fe80:(:[0-9a-f]{0,4}){0,4}%[0-9a-z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-f]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$" | sort -n | uniq | awk "{ print $2 }")
                ${GOST_IP[@]}
            )
        fi

        if [ "${GOST_IP[*]}" != "" ]; then
            GOST_HOSTS_LIST="" && for GOST_IP_TASK in "${!GOST_IP[@]}"; do
                GOST_HOSTS_LIST="${GOST_HOSTS_LIST} ${GOST_HOST}:${GOST_IP[$GOST_IP_TASK]},"
                GOST_HOSTS_LIST=$(echo "${GOST_HOSTS_LIST}" | sed "s/^\ //g")
            done && GOST_HOSTS_LIST="?hosts=$(echo ${GOST_HOSTS_LIST} | sed 's/\ //g;s/,$//g')"
        fi

        docker run --name ${REPO} --net host --restart=always \
            -d ${OWNER}/${REPO}:${TAG} \
            -L "socks5://:40000${HTTP_SOCKS5_FORWARD}" \
            -L "udp://:${WG_LOCAL_PORT:-51821}/127.0.0.1:${WG_REMOTE_PORT:-51820}?keepAlive=true&ttl=1s" \
            -F "relay+grpc://${GRPC_USERNAME:-99235a6e-05d4-2afe-2990-5bc5cf1f5c52}:${GRPC_PASSWORD:-$(echo ${GRPC_USERNAME:-99235a6e-05d4-2afe-2990-5bc5cf1f5c52} | base64)}@${GOST_HOST:-demo.zhijie.online}:${GOST_PORT:-8443}${GOST_HOSTS_LIST}"
    fi
}
# Cleanup Expired Image
function CleanupExpiredImage() {
    if [ "${IMAGES}" != "" ]; then
        docker rmi ${IMAGES}
    fi
}

## Process
# Call GetLatestImage
GetLatestImage
# Call CleanupCurrentContainer
CleanupCurrentContainer
# Call CreateNewContainer
CreateNewContainer
# Call CleanupExpiredImage
CleanupExpiredImage
