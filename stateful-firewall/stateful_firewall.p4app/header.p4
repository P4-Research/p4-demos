#ifndef __HEADER_P4__
#define __HEADER_P4__ 1

enum bit<8> State { SYNSENT = 1, SYNACKED = 2, ESTABLISHED = 3 }

typedef bit<48>  EthernetAddress;
typedef bit<9> egressSpec_t;

header ethernet_t {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    bit<16>         etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    //bit<6>  ctrl;
    bit<1> urgent;
    bit<1> ack;
    bit<1> psh;
    bit<1> rst;
    bit<1> syn;
    bit<1> fin;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct headers_t {
    ethernet_t       ethernet;
    ipv4_t           ipv4;
    tcp_t            tcp;
}

struct ingress_metadata_t {
    bit<32> nhop_ipv4;
}

struct ConnectionInfo_t {
    bit<8> s;
    bit<32> srv_addr;
}

struct metadata_t {
    ConnectionInfo_t connInfo;
    bit<32> conn_id;
    @name("ingress_metadata")
    ingress_metadata_t   ingress_metadata;
}



#endif // __HEADER_P4__
