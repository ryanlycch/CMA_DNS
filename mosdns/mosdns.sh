#!/bin/bash

# Parameter
OWNER="hezhijie0327"
REPO="mosdns"
TAG="latest"
DOCKER_PATH="/docker/mosdns"

CURL_OPTION=""
DOWNLOAD_CONFIG="" # false, true
USE_CDN="true"

CNIPDB_SOURCE="" # bgp, dbip, geolite2, iana, ip2location, ipipdotnet, iptoasn, vxlink, zjdb

ENABLE_ALWAYS_STANDBY="true"
ENABLE_HTTP3_UPSTREAM="true"
ENABLE_PIPELINE="true"
SET_CONCURRENT="1" # 1, 2, 3 (MAX)

PREFER_NO_ECS_UPSTREAM="false" # false, true, ecs, noecs
PREFER_REMOTE_UPSTREAM="false"

ENABLE_LOCAL_UPSTREAM="ipv64" # false, ipv4, ipv6, ipv64
ENABLE_REMOTE_UPSTREAM="ipv64" # false, ipv4, ipv6, ipv64

ENABLE_LOCAL_UPSTREAM_PROXY="false" # false, 127.0.0.1:7891
ENABLE_REMOTE_UPSTREAM_PROXY="false" # false, 127.0.0.1:7891

ENABLE_CACHE="false"
ENABLE_LAZY_CACHE="false"
CACHE_DUMP="false"
CACHE_DUMP_INTERVAL="" # 300, 600, 900
CACHE_SIZE="" # 4096

HTTPS_PORT="" # 5553
TLS_PORT="" # 5535
UNENCRYPTED_PORT="" # 5533

ENABLE_HTTPS="false"
ENABLE_TLS="false"
ENABLE_UNENCRYPTED_DNS="true"

SSL_CERT="fullchain.cer"
SSL_KEY="zhijie.online.key"

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
# Download Configuration
function DownloadConfiguration() {
    if [ "${USE_CDN}" == "true" ]; then
        CDN_PATH="source.zhijie.online"
    else
        CDN_PATH="raw.githubusercontent.com/hezhijie0327"
    fi

    if [ ! -d "${DOCKER_PATH}/conf" ]; then
        mkdir -p "${DOCKER_PATH}/conf"
    fi

    if [ "${DOWNLOAD_CONFIG:-true}" == "true" ]; then
        curl ${CURL_OPTION:--4 -s --connect-timeout 15} "https://${CDN_PATH}/CMA_DNS/main/mosdns/config.yaml" > "${DOCKER_PATH}/conf/config.yaml"

        if [ "${ENABLE_ALWAYS_STANDBY}" == "false" ]; then
            sed -i 's/always_standby: true/always_standby: false/g' "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_HTTP3_UPSTREAM}" == "false" ] || [ "${ENABLE_LOCAL_UPSTREAM_PROXY}" != "false" ] || [ "${ENABLE_REMOTE_UPSTREAM_PROXY}" != "false" ]; then
            sed -i "s/enable_http3: true/enable_http3: false/g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_PIPELINE}" == "false" ]; then
            sed -i "s/enable_pipeline: true/enable_pipeline: false/g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${SET_CONCURRENT}" != "1" ]; then
            sed -i "s/concurrent: 1/concurrent: ${SET_CONCURRENT}/g" "${DOCKER_PATH}/conf/config.yaml"
        fi

        if [ "${PREFER_REMOTE_UPSTREAM}" == "true" ]; then
            sed -i 's/#(    - exec: $fallback_forward_query_to_local_ecs_ipv64/##)   - exec: $fallback_forward_query_to_remote_ecs_ipv64/g;s/#)    - exec: $fallback_forward_query_to_remote_ecs_ipv64/##(   - exec: $fallback_forward_query_to_local_ecs_ipv64/g;s/#(    - exec: $fallback_forward_query_to_local_no_ecs_ipv64/##)   - exec: $fallback_forward_query_to_remote_no_ecs_ipv64/g;s/#)    - exec: $fallback_forward_query_to_remote_no_ecs_ipv64/##(   - exec: $fallback_forward_query_to_local_no_ecs_ipv64/g;s/!resp_ip $ip_set_cnipdb/resp_ip $ip_set_cnipdb/g;/jump sequence_check_response_has_reserved_answer/d;/jump sequence_check_response_has_invalid_answer/d' "${DOCKER_PATH}/conf/config.yaml"
        fi

        if [ "${ENABLE_LOCAL_UPSTREAM}" != "false" ]; then
            sed -i "s/\$fallback_forward_query_to_local_ecs_ipv64/\$fallback_forward_query_to_local_ecs_${ENABLE_LOCAL_UPSTREAM}/g;s/\$fallback_forward_query_to_local_no_ecs_ipv64/\$fallback_forward_query_to_local_no_ecs_${ENABLE_LOCAL_UPSTREAM}/g;s/##(/#( /g;s/#(/  /g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_REMOTE_UPSTREAM}" != "false" ]; then
            sed -i "s/\$fallback_forward_query_to_remote_ecs_ipv64/\$fallback_forward_query_to_remote_ecs_${ENABLE_REMOTE_UPSTREAM}/g;s/\$fallback_forward_query_to_remote_no_ecs_ipv64/\$fallback_forward_query_to_remote_no_ecs_${ENABLE_REMOTE_UPSTREAM}/g;s/##)/#) /g;s/#)/  /g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_LOCAL_UPSTREAM}" != "false" ] && [ "${ENABLE_REMOTE_UPSTREAM}" != "false" ]; then
            sed -i "s/#@/  /g" "${DOCKER_PATH}/conf/config.yaml"
        fi

        if [ "${ENABLE_LOCAL_UPSTREAM_PROXY}" != "false" ] && [ "${ENABLE_LOCAL_UPSTREAM}" != "false" ]; then
            if [ "${ENABLE_LOCAL_UPSTREAM_PROXY}" != "false" ]; then
                sed -i "s/#+        socks5: '127.0.0.1:7891'/          socks5: '${ENABLE_LOCAL_UPSTREAM_PROXY}'/g" "${DOCKER_PATH}/conf/config.yaml"
            else
                sed -i "s/#+/  /g" "${DOCKER_PATH}/conf/config.yaml"
            fi
        fi
        if [ "${ENABLE_REMOTE_UPSTREAM_PROXY}" != "false" ] && [ "${ENABLE_REMOTE_UPSTREAM}" != "false" ]; then
            if [ "${ENABLE_REMOTE_UPSTREAM_PROXY}" != "false" ]; then
                sed -i "s/#-        socks5: '127.0.0.1:7891'/          socks5: '${ENABLE_REMOTE_UPSTREAM_PROXY}'/g" "${DOCKER_PATH}/conf/config.yaml"
            else
                sed -i "s/#-/  /g" "${DOCKER_PATH}/conf/config.yaml"
            fi
        fi

        if [ "${ENABLE_CACHE}" == "true" ]; then
            sed -i "s/##/  /g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_LAZY_CACHE}" == "false" ]; then
            sed -i "s/lazy_cache_ttl: 259200/lazy_cache_ttl: 0/g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${CACHE_DUMP}" == "true" ]; then
            sed -i "s/#=/  /g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${CACHE_DUMP_INTERVAL}" != "" ]; then
            sed -i "s/dump_interval: 300/dump_interval: ${CACHE_DUMP_INTERVAL}/g" "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${CACHE_SIZE}" != "" ]; then
            sed -i "s/size: 4096/size: ${CACHE_SIZE}/g" "${DOCKER_PATH}/conf/config.yaml"
        fi

        if [ "${ENABLE_UNENCRYPTED_DNS}" == "false" ]; then
            if [ "${ENABLE_HTTPS}" == "true" ] || [ "${ENABLE_TLS}" == "true" ]; then
                for i in $(seq 1 10); do
                    sed -i '$d' "${DOCKER_PATH}/conf/config.yaml"
                done
            fi
        else
            if [ "${UNENCRYPTED_PORT:-5533}" != "5533" ]; then
                sed -i "s/listen: :5533/listen: :${UNENCRYPTED_PORT}/g" "${DOCKER_PATH}/conf/config.yaml"
            fi
        fi
        if [ "${ENABLE_HTTPS}" == "true" ]; then
            echo -e "  - tag: create_https_server\n    type: tcp_server\n    args:\n      entries:\n        - path: '/dns-query'\n          exec: fallback_sequence_forward_query_to_prefer_ecs\n      cert: '/etc/mosdns/cert/${SSL_CERT}'\n      key: '/etc/mosdns/cert/${SSL_KEY}'\n      listen: :${HTTPS_PORT:-5553}" >> "${DOCKER_PATH}/conf/config.yaml"
        fi
        if [ "${ENABLE_TLS}" == "true" ]; then
            echo -e "  - tag: create_tls_server\n    type: tcp_server\n    args:\n      entry: fallback_sequence_forward_query_to_prefer_ecs\n      cert: '/etc/mosdns/cert/${SSL_CERT}'\n      key: '/etc/mosdns/cert/${SSL_KEY}'\n      listen: :${TLS_PORT:-5535}" >> "${DOCKER_PATH}/conf/config.yaml"
        fi

        if [ "${PREFER_NO_ECS_UPSTREAM}" == "true" ]; then
            sed -i "s/entry: fallback_sequence_forward_query_to_prefer_ecs/entry: fallback_sequence_forward_query_to_prefer_no_ecs/g" "${DOCKER_PATH}/conf/config.yaml"
        elif [ "${PREFER_NO_ECS_UPSTREAM}" == "ecs" ]; then
            sed -i "s/entry: fallback_sequence_forward_query_to_prefer_ecs/entry: sequence_forward_query_to_ecs/g" "${DOCKER_PATH}/conf/config.yaml"
        elif [ "${PREFER_NO_ECS_UPSTREAM}" == "noecs" ]; then
            sed -i "s/entry: fallback_sequence_forward_query_to_prefer_ecs/entry: sequence_forward_query_to_no_ecs/g" "${DOCKER_PATH}/conf/config.yaml"
        fi

        if [ -f "${DOCKER_PATH}/conf/config.yaml" ]; then
            sed -i "/#/d" "${DOCKER_PATH}/conf/config.yaml"
        fi
    fi

    if [ ! -d "${DOCKER_PATH}/data" ]; then
        mkdir -p "${DOCKER_PATH}/data"
    fi && curl ${CURL_OPTION:--4 -s --connect-timeout 15} "https://${CDN_PATH}/CNIPDb/main/cnipdb_${CNIPDB_SOURCE:-geolite2}/country_ipv4_6.txt" > "${DOCKER_PATH}/data/GeoIP_CNIPDb.txt"
}
# Create New Container
function CreateNewContainer() {
    docker run --name ${REPO} --net host --restart=always \
        -v /docker/ssl:/etc/mosdns/cert:ro \
        -v ${DOCKER_PATH}/conf:/etc/mosdns/conf \
        -v ${DOCKER_PATH}/data:/etc/mosdns/data \
        -v ${DOCKER_PATH}/work:/etc/mosdns/work \
        -d ${OWNER}/${REPO}:${TAG} \
        start \
        -c "/etc/mosdns/conf/config.yaml" \
        -d "/etc/mosdns/data"
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
# Call DownloadConfiguration
DownloadConfiguration
# Call CreateNewContainer
CreateNewContainer
# Call CleanupExpiredImage
CleanupExpiredImage
