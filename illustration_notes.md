# Start day

* Download virtual box
* Install ubuntu
* [Install docker](https://docs.docker.com/engine/install/ubuntu/)
* Install wireshark - `sudo apt install wireshark`
* Add `login_container` to your bashrc


# Ethernet

On a linux machine we can list all interfaces with
`ip link show`. You will see the ethernet interfaces
with the `link/ether` against them.

Do this on edgertr:

```sh
magma@magmalakshman:~/nw_tutorial$ login_container edgertr
root@edgertr:/# ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
844: eth0@if845: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default
    link/ether 02:42:ac:11:00:04 brd ff:ff:ff:ff:ff:ff link-netnsid 0
846: eth1@if847: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default
    link/ether 02:42:c0:a8:9f:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
root@edgertr:/#
```

The edgertr has 2 ethernet interfaces. So we see a `eth0` and `eth1`
This was a common naming convention. However, we will likely see
other naming schemes in other newer linux machines
* consistent naming - based on the pci address. Eg: `enp1s0`
* predictable naming - `enoXXXXXX` based on fireware provided in index

* Notice the `lo` interface. We will come to that later.

* login to swhost1. See that its not BROADCAST, but rather POINTTOPOINT.

# IP

* Again, go to edgertr and do `ip address show`
* You see the ip-address under the `inet` of each ifc.
* Notice the broadcast address, valid_lft

* Most time you want just the ip's on the macine
* Remember this - `ip -br -4 a`
    * brief
    * ipv4 only
    * a for address
    * show is the default
    * `ifaddr` alias has been setup to do this in all containers

* Go into each container explore ifaddr, and see if this matches the picture.

# ARP

* Time to capture packets on the wire.
* Install wireshark on your pc.
* ping from edgertr to nhost1
* tcpdump on eth1
* get comfortable with both terminal and wireshark
    * sometimes just terminal is super fast
    * remember the `-n` argument. Otherwise it may get stuck or be way too slow
    * remember display filters and capture filters
* type `ip neigh show` on edge-router/nhost1 before and after the ping.

* Note that ARP is only for ethernet interfaces. Go to swhost1 and see the NOARP

# Routing

* Understand route table in
    * edgertr
        * see 4 routes
            * 2 local routes added by kernel
            * 1 explicit route
            * 1 default route
    * nhost1
        * 3 routes
            * 1 local route
            * 1 explicit route
            * 1 default route
    * swhost1
        * only one route!
        * Observe that the absence of a via/gateway on this route
          as this is a point to point link.
        * for broadcast links the route should have a via and
          for p2p links the route has a device.
        * The device name(for broadcast) and src-ip are optional but
          is a good practice to give.

* Lets understand how a packet will flow from nhost1 to swhost1
    * nhost1 has a route to the `192.168.160.0/22` network. Note
      the `/22`. This includes all of `192.168.160.0/24` to
      `192.168.163.0/24` - all of northsouth, south and southwest.
    * Any of those packets are sent to nrtr.
    * nrtr then sends to srtr with a `192.168.162.0/23` route
        * this route is a l3-tun route - based on device
    * srtr calls a `192.168.163.0/24` route to shost1
    * for shost there is a direct route to its peer.

* Observe how the routing principles are at play. Each party only
  knows to a next-hop that is hopefully more aware of the destination.
  * Note that nhost does a apr for its gateway (and not destination)

* Try adding a next-hop that is not directly connected.
    nrtr: `ip route replace 192.168.160.0/22 via 192.168.165.1 dev eth0 src 192.168.158.3`

# Traceroute

* Traceroute swhost from nhost1

* Ping swhost from nhost. See what's happening

# Switch

* Picture of a switch

# Interfaces in linux

* List all interfaces in every container.

# vlans

* Simple vlans at the switch only.
* Vlans in which multiple hosts participate
* linux vlans.
    ```sh
    ip link add link eth0 name eth0.2 type vlan id 2
    ```
* Create a vlan on both nhost1 and nhost2 and ping each other over the vlan.


# tcp & udp

* udp header first
* `nc` -- very nifty tool
* run a udp server and a udp client. Capture pkts in tcpdump
* Notice the 5 tuple
* start a echo udp server. start multiple udp clients from different hosts
* Notice the same server can have multiple parallel udp clients
* lsof to study the output of the process.
* `/proc/net/udp`
* tcp
* explicit listen socket
* connected sockets - `/proc/net/tcp`
* udp to non-existent port -- icmp port unreachable

* tcp -- observe a simple connection
    * syn/syn-ack/ack
    * seq number moving in either direction
    * fin-ack
* Look at the state diagram
    * active-close/passive-close
    * Half-close
    * msl wait - drain the connection pkts
    * simultaneous close
    * rare - simultaneous open
* mss -- maximum segment size
* tcp to non-existent port.. rst
* abort a connection in between
* tcp options.. window size
* tcp backlog

* Retransmission
    * at srtr
        * `iptables -t mangle -A POSTROUTING -d 192.168.163.1/32 -p tcp -m tcp --dport 8000 -j DROP`


* RST in between.
    ```
    port=59947
    iptables -A INPUT -s 192.168.159.3 -p tcp --sport ${port} -j REJECT --reject-with tcp-reset
    iptables -D INPUT -s 192.168.159.3 -p tcp --sport ${port} -j REJECT --reject-with tcp-reset
    ```



* Congestion control at tcp

* interface stats
* bps script
* iperf

* Commands to rate limit at nrtr
  ```sh
  tc qdisc add dev ntun root handle 1: htb default 12
  tc class add dev ntun parent 1:1 classid 1:12 htb rate 15mbit ceil 15mbit
  ```
* Behavior of speed testing with tcp and udp

# dhcp

* Fire up a dhcpd server at nrtr
```sh
cat <<EOF | tee /etc/dhcp/dhcpd.conf > /dev/null
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 192.168.159.0 netmask 255.255.255.0 {
    range 192.168.159.100 192.168.159.200;
    option routers 192.168.159.1;
    option domain-name-servers 8.8.8.8;
}
EOF
touch /var/lib/dhcp/dhcpd.leases
mkdir /run/dhcp-server

#serve
dhcpd -f -4 -pf /run/dhcp-server/dhcpd.pid -cf /etc/dhcp/dhcpd.conf eth0
```

* Run a client at nhost1 and capture packets.

```sh
/data/dhtest -m '00:01:02:03:04:05' -i eth0 -h testhost
```


# dns

* setup a dns server

```sh

cat <<EOF | tee /tmp/dnsmasq.conf > /dev/null
local-ttl=
interface=eth1
no-dhcp-interface=eth1
EOF

dnsmasq -k --conf-file=/tmp/dnsmasq.conf
```
* now ping a dnsname from nhost1
* dig against any server.

* remember for a host to meaningfully partiicpate in internet, it needs its IP/netmask/DNS-server-ip

# OS

* strace

# NAT

```sh
wget -q -O- 'https://artifactory.gxc.io/repository/keys/public/gxc-3rdparty-apt.key'
```


# bridges

* agw.. brctl show
