# Start day

* Download virtual box
* Install ubuntu
* [Install docker](https://docs.docker.com/engine/install/ubuntu/)
* Install wireshark - `sudo apt install wireshark`


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
    * remember the `-n` argument.
    * remember display filters and capture filters
