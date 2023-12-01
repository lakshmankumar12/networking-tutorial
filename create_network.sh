#!/bin/bash

# exit script as soon as a command fails
set -e

DATA_DIR=$HOME/nw_tutorial
IMAGE=lakshmankumar/simple-routerish-docker

NRTH="192.168.159"
NRTHSTH="192.168.160"
STH="192.168.161"
STHWST="192.168.162"
ALLSTH="192.168.160.0/22"

if [ ! -d $DATA_DIR ] ; then
    echo "DATA_DIR: $DATA_DIR doesnt exist. Please create this directory"
    exit 1
fi

create_networks() {
    docker network create north      --driver=bridge --subnet=${NRTH}.0/24    --gateway ${NRTH}.100
    docker network create northsouth --driver=bridge --subnet=${NRTHSTH}.0/24 --gateway ${NRTHSTH}.100
    docker network create south      --driver=bridge --subnet=${STH}.0/24     --gateway ${STH}.100
    docker network create southwest  --driver=bridge --subnet=${STHWST}.0/24  --gateway ${STHWST}.100
}

create_container() {
    contname=$1
    net=${2:-default}
    ip=$3
    IP_ARG=""
    if [ "x$net" != "xnone" -a -n "$ip" ] ; then
        IP_ARG="--ip $ip"
    fi
    eval docker run --privileged -v $DATA_DIR:/data -v $DATA_DIR/init.d:/etc/my_init.d --rm --name $contname --hostname $contname --net $net $IP_ARG -d $IMAGE /sbin/my_init
}

attach_to_net() {
    cont=$1
    net=$2
    ip=$3
    docker network connect --ip $ip $net $cont
}

set_def_route() {
    cont=$1
    dest=$2
    docker exec -it $cont ip route replace default via $dest
}

add_route() {
    cont=$1
    nw=$2
    via=$3
    ifc=$4
    src=$5
    docker exec -it $cont ip route replace $nw via $via dev $ifc src $src
}

add_masq_to_edge() {
    docker exec -it edgertr iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
}

fireup() {
    create_networks
    create_container nrtr     north      ${NRTH}.1
    attach_to_net    nrtr     northsouth ${NRTHSTH}.1
    create_container edgertr
    attach_to_net    edgertr  north      ${NRTH}.2
    create_container nhost1   north      ${NRTH}.3
    create_container nhost2   north      ${NRTH}.4
    create_container nhost3   north      ${NRTH}.5
    create_container srtr     south      ${STH}.1
    attach_to_net    srtr     northsouth ${NRTHSTH}.2
    create_container shost1   south      ${STH}.2
    create_container shost2   south      ${STH}.3
    create_container shost3   south      ${STH}.4
    create_container swhost1  southwest  ${STHWST}.1
    attach_to_net    shost1   southwest  ${STHWST}.2

    add_masq_to_edge
    set_def_route nhost1 ${NRTH}.2
    set_def_route nhost2 ${NRTH}.2
    set_def_route nhost3 ${NRTH}.2
    set_def_route nrtr ${NRTH}.2

    add_route nhost1  ${ALLSTH} ${NRTH}.1    eth0 ${NRTH}.3
    add_route nhost2  ${ALLSTH} ${NRTH}.1    eth0 ${NRTH}.4
    add_route nhost3  ${ALLSTH} ${NRTH}.1    eth0 ${NRTH}.5
    add_route nrtr    ${ALLSTH} ${NRTHSTH}.2 eth1 ${NRTHSTH}.1
    add_route edgertr ${ALLSTH} ${NRTH}.1    eth1 ${NRTH}.2

    set_def_route srtr ${NRTHSTH}.1
    add_route     srtr ${STHWST}.0/24 ${STH}.2 eth0 ${STH}.1

    set_def_route shost1 ${STH}.1
    set_def_route shost2 ${STH}.1
    set_def_route shost3 ${STH}.1

    set_def_route swhost1 ${STHWST}.2
}

destroyall() {
    docker kill swhost1 2> /dev/null || true
    docker kill shost3 2> /dev/null || true
    docker kill shost2 2> /dev/null || true
    docker kill shost1 2> /dev/null || true
    docker kill srtr 2> /dev/null || true
    docker kill nhost3 2> /dev/null || true
    docker kill nhost2 2> /dev/null || true
    docker kill nhost1 2> /dev/null || true
    docker kill edgertr 2> /dev/null || true
    docker kill nrtr 2> /dev/null || true

    docker network rm southwest 2> /dev/null || true
    docker network rm south 2> /dev/null || true
    docker network rm northsouth 2> /dev/null || true
    docker network rm north 2> /dev/null || true
}

destroyall
fireup
