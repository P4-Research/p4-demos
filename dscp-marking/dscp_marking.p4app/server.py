#!/usr/bin/env python

from scapy.all import sniff, sendp
from scapy.all import Packet
from scapy.all import ShortField, IntField, LongField, BitField

import sys
import struct

def handle_pkt(pkt):
    pkt.show2()

def main():
    #h2-eth0
    sniff(iface = "lo",
          prn = lambda x: handle_pkt(x))

if __name__ == '__main__':
    main()
