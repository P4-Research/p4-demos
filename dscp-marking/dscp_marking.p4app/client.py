#!/usr/bin/env python
import argparse
import sys
import socket
import random
import struct

from scapy.all import sendp, send, get_if_list, get_if_hwaddr
from scapy.all import Packet
from scapy.all import Ether, IP, UDP, TCP

def get_if():
    ifs=get_if_list()
    iface=None
    for i in get_if_list():
        if "h1-eth0" in i:
            iface=i
            break;
    if not iface:
        print "Cannot find eth1 interface"
        exit(1)
    return iface

def main():
    iface = get_if()
    print "sending on interface %s" % iface
    pkt =  Ether(src=get_if_hwaddr(iface), dst='00:04:00:00:02:01')
    pkt = pkt /IP(dst="10.0.2.101", tos=0x0c)
    pkt.show2()
    sendp(pkt, iface=iface, verbose=False)


if __name__ == '__main__':
    main()
