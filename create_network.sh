#!/bin/bash

# exit script as soon as a command fails
set -e

DATA_DIR=$HOME/nw_tutorial
IMAGE=lakshmankumar/simple-routerish-docker
VTUNPAIR=vtun/vtunpair

NRTH="192.168.159"
NRTHSTH="192.168.160"
STH="192.168.162"
STHWST="192.168.163"
ALLSTH="192.168.160.0/22"
JUSTSTH="192.168.162.0/23"

NTUN="ntun"
STUN="stun"
SWTUN="swtun"
WTUN="wtun"
NSTUNPID="/var/run/nstunpidfile"
SWTUNPID="/var/run/swtunpidfile"

if [ ! -d $DATA_DIR ] ; then
    echo "DATA_DIR: $DATA_DIR doesnt exist. Please create this directory"
    exit 1
fi

if [ ! -f $VTUNPAIR ] ; then
    echo "vtunpair not found in $VTUNPAIR"
    exit 1
fi

create_networks() {
    docker network create north      --driver=bridge --subnet=${NRTH}.0/24    --gateway ${NRTH}.100
    docker network create south      --driver=bridge --subnet=${STH}.0/24     --gateway ${STH}.100
}

create_tun_pair() {
    tun1=$1
    tun2=$2
    pidfile=$3
    sudo $VTUNPAIR -d -P $pidfile $tun1 $tun2
}

del_tun_pair() {
    pidfile=$1
    if [ -f $pidfile ] ; then
        pid=$(cat $pidfile)
        sudo kill -9 $pid || true
        sudo rm -f $pidfile
    fi
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
    echo "setting def route for container:$cont to dest: $dest"
    docker exec -it $cont ip route replace default via $dest
}
set_def_l3_route() {
    cont=$1
    ifc=$2
    echo "setting def route for container:$cont over ifc:$ifc"
    docker exec -it $cont ip route replace default dev $ifc
}
add_tun_ip() {
    cont=$1
    ifc=$2
    ip=$3
    docker exec -it $cont ip addr add ${ip}/32 dev ${ifc}
}

add_route() {
    cont=$1
    nw=$2
    via=$3
    ifc=$4
    src=$5
    echo "Adding route in container:$cont to nw:$nw via:$via over ifc:$ifc with src:$src"
    docker exec -it $cont ip route replace $nw via $via dev $ifc src $src
}

add_l3_route() {
    cont=$1
    nw=$2
    ifc=$3
    echo "Adding route in container:$cont to nw:$nw over ifc:$ifc"
    docker exec -it $cont ip route replace $nw dev $ifc
}

add_masq_to_edge() {
    docker exec -it edgertr iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
}

fireup() {
    create_networks
    create_container nrtr     north      ${NRTH}.1
    create_container edgertr
    attach_to_net    edgertr  north      ${NRTH}.2
    create_container nhost1   north      ${NRTH}.3
    create_container nhost2   north      ${NRTH}.4
    create_container nhost3   north      ${NRTH}.5
    create_container srtr     south      ${STH}.1
    create_container shost1   south      ${STH}.2
    create_container shost2   south      ${STH}.3
    create_container shost3   south      ${STH}.4
    create_container swhost1  none

    create_tun_pair $NTUN $STUN $NSTUNPID
    create_tun_pair $WTUN $SWTUN $SWTUNPID

    sudo ip link set $NTUN netns $(docker inspect --format '{{.State.Pid}}' nrtr)
    sudo nsenter -n -t $(docker inspect --format '{{.State.Pid}}' nrtr) ip link set $NTUN up
    sudo ip link set $STUN netns $(docker inspect --format '{{.State.Pid}}' srtr)
    sudo nsenter -n -t $(docker inspect --format '{{.State.Pid}}' srtr) ip link set $STUN up
    sudo ip link set $SWTUN netns $(docker inspect --format '{{.State.Pid}}' shost1)
    sudo nsenter -n -t $(docker inspect --format '{{.State.Pid}}' shost1) ip link set $SWTUN up
    sudo ip link set $WTUN netns $(docker inspect --format '{{.State.Pid}}' swhost1)
    sudo nsenter -n -t $(docker inspect --format '{{.State.Pid}}' swhost1) ip link set $WTUN up

    add_tun_ip nrtr     ${NTUN}  ${NRTHSTH}.1
    add_tun_ip srtr     ${STUN}  ${NRTHSTH}.2
    add_tun_ip shost1   ${SWTUN} ${STHWST}.2
    add_tun_ip swhost1  ${WTUN}  ${STHWST}.1

    add_masq_to_edge
    set_def_route nhost1 ${NRTH}.2
    set_def_route nhost2 ${NRTH}.2
    set_def_route nhost3 ${NRTH}.2
    set_def_route nrtr   ${NRTH}.2

    add_route nhost1  ${ALLSTH}  ${NRTH}.1    eth0    ${NRTH}.3
    add_route nhost2  ${ALLSTH}  ${NRTH}.1    eth0    ${NRTH}.4
    add_route nhost3  ${ALLSTH}  ${NRTH}.1    eth0    ${NRTH}.5
    add_route edgertr ${ALLSTH}  ${NRTH}.1    eth1    ${NRTH}.2
    add_l3_route nrtr ${JUSTSTH} ${NTUN}

    set_def_l3_route srtr ${STUN}
    add_route     srtr ${STHWST}.0/24 ${STH}.2 eth0 ${STH}.1

    set_def_route shost1 ${STH}.1
    set_def_route shost2 ${STH}.1
    set_def_route shost3 ${STH}.1

    add_l3_route shost1 ${STHWST}.1 ${SWTUN}
    set_def_l3_route swhost1 ${WTUN}
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

    del_tun_pair $NSTUNPID
    del_tun_pair $SWTUNPID

    docker network rm south 2> /dev/null || true
    docker network rm north 2> /dev/null || true
}

#ask sudo passwd once
sudo true
echo "Clearing up previous setup"
destroyall
fireup
