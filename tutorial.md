# Networking Tutorial

[[_TOC_]]

# Introduction

We will go over the following topics

* Ethernet
* IP
* ARP
* Wireshark/tcpdump
* Routing in IP
* ICMP
* Traceroute, ping
* Host, Switch, Routers
* Interfaces in linux
* vlans
* DHCP
* DNS
* TCP / UDP
* OS, kernel-mode/user-mode, system-calls, linux commands
* Capturing packets
* nc, lsof, iperf
* NAT, private/public ips, firewalls
* routing in linux
* iptables/nftables, firewalls
* containers, namespaces
* bridges, veth, tun, tap
* ssh
* pki infrastructure
* tunneling - gre
* ipsec, ssl/tls

From here, on your own:

* ovs
* socket programming

# General Guidelines

* Have a good notes taking system. You will come across a lot of commands.
  It is not possible to remember them all in memory. It is usually much quicker
  to refer to your own notes in your own words, than refer to a stack-overflow
  answer every time. Have links to your sources in your notes, in case you
  need to reverify them.

* Have notes of often used args for commands in your own words. Reading man page
  every time is not convenient. Also we dont want to keep building the argument
  set for common invocations everytime.

* Your notes taking system should be
    * Accessible from anywhere - not tied to one laptop/server
    * Easy to search
    * Easy to copy from, and to paste elsewhere

* Some notes taking system, I have observed:
    * Txt files in notepad/word-edit
    * Txt files in your IDE.
    * Google docs

* My favourite:
    * markdown-files controlled in git, pushed to github.
    * vim editor that can render markdown nicely,
    * syntax highlighting shell, python, cpp snippets.

# Ethernet

* Link Layer
* Each host has one or more physical device that connects itself to
  rest of network.
* By far, ethernet devices are the most common. There are other devices
  (eg: co-ax, twisted pair) that are point-to-point links. These are
  found in the ISP to our house/office. But within a branch/house,
  ethernet is the way to go.
* Ethernet flavours
    * Twisted pair - RJ45
    * Fibre
    * Wifi
* Speeds
    * 10/100 (very old)
    * 1Gbps (de-facto)
    * 10Gbps (on high-end servers)
* Characteristics of ethernet networks
    * Each particpant has a MAC address - 6 byte address, hard-wired into their
      device.
        * https://en.wikipedia.org/wiki/MAC_address
    * It is a broadcast network.

Typically how hosts are shown on a ethernet network

That line is in reality a Ethernet Switch.

```

A ethernet network on paper:

        +-+-+           +-+-+            +-+-+
        | A |           | C |            | E |
        +-+-+           +-+-+            +-+-+
          |               |                |
  --------+------+--------+--------+-------+-------  <-- the line is typically a switch
                 |                 |
               +-+-+             +-+-+
               | B |             | D |
               +-+-+             +-+-+

```

* A host's packet are received by all other hosts on the network.
* Broadcast packets are consumed by everybody
* Unicast packets are consumed only by the recipient.
* Switches are auto-learning -- they dont forward a unicast pkt on all ports
  if they are sure a destination is available on a select port.
* There is a Spanning Tree Protocol that is run by switches to
  detect loops so that the same packet is not forwarded back and forth

* Ethernet header - https://en.wikipedia.org/wiki/Ethernet_frame
    * src, dst, protocol
* Protocol numbers - https://www.iana.org/assignments/ieee-802-numbers/ieee-802-numbers.xhtml
    * Popular - IPv4, IPv6, ARP, PTP, 802.1Q(vlan)

# IP

* IP is the workhorse protocol of the TCP/IP protocol suite.
* The most ubiquitous networking protocol in the world.
* While ethernet's job is to deliver a packet from a host to another host
  within the same L2 domain, IP on the other hand can deliver a packet
  from a host in one end of the world to another host in the other end of
  the world. (Link Layer vs Network Layer)
* A fact that amazes many newcomers to TCP/IP, especially those from an X.25 or
  SNA background, is that IP provides an unreliable, connectionless datagram
  delivery service.
* We will restrict to IPv4 in our discussion.
* IP Header - https://en.wikipedia.org/wiki/Internet_Protocol_version_4
* Each field here needs attention. We can revisit these later. The important
  fields for now are
  * Source/Destination
  * Protocol - https://en.wikipedia.org/wiki/List_of_IP_protocol_numbers
    * popular - ICMP, UDP, TCP, SCTP
* IP Address - https://en.wikipedia.org/wiki/IP_address
  * Network part/Host part
  * Netmask, all host address, broad-cast address

# ICMP

* We will not spend much time here - just go over the most popular types
* ICMP itself is a protocol on top of IP - is a companion protocol to help IP
  working. (Not really a transport protocol)
* https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml
* Popular ones:
    * Type 8 / Type 0 - Echo Request / Reply
    * Type 3 - Destination Unreachable
        * Code 0 - Network Unreachable
        * Code 1 - Host Unreachable
        * Code 3 - Port Unreachable
        * Code 4 - Fragmentation Needed
    * Type 11 - Time exceeded
        * Code 0 - TTL exceeded
        * Code 1 - Frag Resassembly time exceeded

# ARP

* Glues the IP layer and Ethernet layer together.
* https://en.wikipedia.org/wiki/IP_address
* Who-has-this-ip .. ip-is-at-xxxx
* regular arp, gratuitous arp, proxy-arp, probe-arp

# Tooling

* Wireshark
* tcpdump

# Routing in IP

* Its actually pretty simple - and that simplicity is its power.
    * If the destination is directly connected to the host (a point-to-point link)
      or on a shared network (Ethernet), then the IP datagram is sent directly to
      the destination. Otherwise the host sends the datagram to a default router,
      and lets the router deliver the datagram to its destination. This simple
      scheme handles most host configurations

    * The ability to specify a route to a network, and not have to specify a
      route to every host, is another fundamental feature of IP routing.

* IP routing is done on a hop-by-hop basis. IP does not know the complete route
  to any destination (except, of course, those destinations that are directly
  connected to the sending host). All that IP routing provides is the IP
  address of the nexthop router to which the datagram is sent. It is assumed
  that
    * the next-hop router is really "closer" to the destination than the
      sending host is, and that
    * the next-hop router is directly connected to the sending host.

* Route-lookup:
    * Longest prefix match, and send to that next-hop
    * Default route, when none matches

* No route:
    * Send a ICMP(host-unreachable/network-unreachable) back to the host

* Static routes
    * Explicitly configured
    * Okay for small network, but a pain for big networks

* Dynamic routes
    * Local broadcast routes - auto-added when IP is added.
    * Routing protocols
        * RIP
        * OSPF
        * BGP (very popular)

# Ping and Traceroute

* Ping - simple ICMP echo-request and reply!

* Traceroute
    * Incrementally set TTL from 1 to 64 and capture the TTL-Exceeded replies and build the route.

# Host, Switch, Routers

* Host
    * Loose term to refer to any participant on the internet.
    * Has atleast one interface that connects with the rest of the network.
    * Each interface has atleast one IP and a mac.
    * Usually plain hosts don't forward packets across interfaces.
    * Implement applications

* Switch
    * L2 device. Has no IP for itself or mac for itself.
    * Has multiple ports, to which each device is connected
    * On each port, there are one or more mac-addresses which it typically auto-learns
    * When a pkt comes on one port, depending on destiation-mac it is forward to another port.
        * If the mac is unknown, it is broadcasted to all ports.

* Router
    * L3 device. It has one or more interfaces. It has a IP/mac on each interface
    * It "forwards" packets across these interfaces. Each fwded pkt has its TTL reduced by 1.

# Interfaces in linux

* On a linux machine every networking connection is referred as a interface
* Ethernet interfaces
    * Real - fiber/copper
    * Virtual
* L3 only interfaces
    * Point-to-point links
* Loop back interface (true loopback)
    * Not to be confused with a loopback interface in cisco routers
* Commands.
    * old/deprecated - `ifconfig`, `route -n`, `netstat -nr`
    * new - `ip link show`, `ip addr show`
    * routes - `ip route show`

# Vlans

* Segregration of L2 networks.
* Uses the Ethernet 801.Q extension that calls out the vlan tag.
    * Absence of the 801.Q hdr is referred as native vlan, vlan-0 or untagged pkt
* Trunk port vs access port.
    * Trunk port - understands vlan headers. Handles both tagged and untagged pkts
    * Access port - Only handles untagged pkts.
* Only the L3 layer can forward pkts across vlans (with a TTL decrement)
* On a linux host, we just create tagged interfaces on top of the base interface.

# DHCP

* Helps a new machine to get a IP from the network
* A DHCP server runs on the same L2 broadcast domain.
* The other options is static - where a machine is manually assigned a fixed ip
* DHCP is more or less the defato
* Remember DORA - Discover, Offer, Request, Ack
* The DHCP server maintains a map of MAC to IP -address given. This is referred as lease.
* Before the lease expiry, the client, renews its leases and retains the IP

# DNS

* Makes the internet human-friendly
* It is not possible to remember IPs of all hosts. Instead it is easy to remember "google.com"
* There are DNS servers that help us resolve the name to the IP.
* Each local network has a local DNS-resolver, that caches results and reaches
  out to the public DNS-resolver when its needs to.
* Popular commands - `dig name`, `dig @server name`
* `/etc/resolv.conf` in linux typically contains the dns-resolver to use.

# TCP, UDP

* The transport protocols
* TCP - Connection-oriented, stream-based, reliable
* UDP - Connection-less,     datagram-based, unreliable
* Connection
    * Each pkt is associated with a connection / independant
* Stream/datagram based
    * Is the upper-layer at receiver notified of reads in exact same way as it was done at sender
* reliable/unreliable
    * Acks/Retransmissions

* Port-numbers - helps to multiplex many applications on the same host to avail the server
* the (Src-IP, Src-Port, Dst-IP, Dst-Port) Uniquely identifies a TCP/UDP connection.
    * Even if any one changes, the connection is different.
* Servers listen
* Clients connect
* Servier listen at a well-known port
* Clients typically use a ephemeral port.

* SCTP - relatively newer transport protocol.

# OS

* Usually all of Ethernet(L2), IP(L3), TCP/UDP/SCTP (L4) are all implemented by the OS.
* The OS exposes API's - called system calls that applications use to avail the services
* Socket APIs
    * sockets is an abstraction to refer to one connection or one listening endpoint
* Kernel-mode / user-mode.
    * systemcalls

# Capturing Packets

Time to get into action

## popular tools

* nc, lsof, iperf


# NAT

* IPv4 has only 4 octets for its addressing.
* That is only `2*32 == 4Billion`. But a lot of them are unusable - all-hosts and all-zeros.
  So, that leaves a lot less usable addresses which is not sufficient for every host in the
  world
* So, we have private IP space and public IP space.
* Private IP ranges
    * 10.0.0.0/8
    * 172.16-32.0.0/16
    * 192.168.0.0/16
    * 169.254.0.0/16
* The private IP ranges are never assigned to any public host. Thus any public router when it sees these addresses just drains the packets.
* The private IP are used within a network that is isolated from the public internet.
* So, how do private hosts reach the public hosts - NAT.
* NAT typically means modifying the pkts in some way. The most popular NAT is the port-SNAT where the source-IP is replaced.
* The NAT'ing router, maintains a table of (SIP,SPort) and maps to a (Public-IP,New-SPort). The reply pkts are reverse mapped.
* This scheme works amazingly well. The Router can map upto 64K individual tcp/udp connections across any number of hosts on its private side.

## firewalls

* NAT'ing makes it possible that only the inside-hosts and reach outside.
    * The connection is always initiated from the inside.
* This is both good and bad.
    * Bad because its now likely a one-way street.
    * Good because it prevents unauthorized access from outside to inside.
* Firewall'ing is policing this ourside access and selectively opening access to inside hosts
    * Opening a hole.

# Routing in linux

* Typically routing is always DIP based.
* Linux offers much more than that - it does this by way of having rules and route-tables.
* `ip rule show` and `ip route show table <n>`
* rules are done via - src-ip, src-ifc, pkt-marks (These are stamped using iptables) or just all
* rules have a priority order
* local table is special
    * Always at priority 0
    * Has routes to all local ips.
        * NEVER mess with this table.
        * Or we will stop getting pkts.

# iptables

* iptables
    * A Swiss-army knife to do almost anything with the pkt

# Containers and Namespaces

* Linux has this awesome feature called namespaces which are seperate networking jails. (And namespaces exist for mnt,pid,user and others)
* Each net-ns has its own private set of interfaces, L2 addresses, L3 addresses, Route tables..
* Docker is a nifty tool, that creates what are called containers which run in their own namespace. A container is a collection of processes that are running in their own shared name-space

# Bridges, veth, tun, tap

* Bridges emulate an external switch
* veth is a combination of 2 ethernet interfaces.
    * Most popular use are:
        * send pkts from one namespace to another
        * add a bump in wire effect
* tun/tap
    * L2/L3 devices respectively
    * The other end of these interfaces is user-space.
        * One process owns these devices and gets pkts to itself.
* dummy interface

# ssh

* One of the most underutilized programs
* ssh is the popular way to connect to another machine
* It also supports scp, which copies files over ssh
* Password-less ssh. Always prefer this
* Jumper hosts
* ssh config - use this and not write your own aliases
* Tunnels - Forward tunnel and reverse tunnel

# pki infrastructure

* Shared key vs public/private key
* Certificate
* Trust chain
* ssl commands

# Tunneling - Gre

* overlay between 2 networks.

# ipsec


