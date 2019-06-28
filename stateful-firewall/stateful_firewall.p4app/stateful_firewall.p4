#include <core.p4>
#include <psa.p4>

enum State { SYNSENT, SYNACKED, ESTABLISHED }

typedef bit<48>  EthernetAddress;

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

struct headers {
    ethernet_t       ethernet;
    ipv4_t           ipv4;
}

typedef bit<32> saddr;
typedef bit<32> daddr;
typedef bit<32> srcport;
typedef bit<32> dstport;

struct ConnectionInfo_t {
    State s;
    bit<32> srv_addr;
}

struct ConnectionId_t {
    bit<32> saddr;
    bit<32> daddr;
    bit<16> srcport;
    bit<16> dstport;
}

parser IngressParserImpl(packet_in buffer,
                  out headers parsed_hdr)
{
    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        buffer.extract(parsed_hdr.ethernet);
        transition select(parsed_hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        buffer.extract(parsed_hdr.ipv4);
        transition accept;
    }
}

control ingress(inout headers hdr) {

    Register<ConnectionInfo_t, bit<32>>(20) info;

    apply {
        if (hdr.ipv4.isValid()) {
            @atomic {
                ConnectionInfo_t tmp;
                tmp = info.read(hdr.ipv4.srcAddr);

            }
        }
    }

}

control egress(inout headers hdr) {

    apply {}

}

control CommonDeparserImpl(packet_out packet,
                           in headers hdr)
{
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

control IngressDeparserImpl(packet_out buffer, in headers hdr)
{
    CommonDeparserImpl() cp;
    apply {
        cp.apply(buffer, hdr);
    }
}

control EgressDeparserImpl(packet_out buffer, in headers hdr)
{
    CommonDeparserImpl() cp;
    apply {
        cp.apply(buffer, hdr);
    }
}

parser EgressParserImpl(packet_in buffer,
                        out headers parsed_hdr)
{
    state start {
        transition accept;
    }
}

IngressPipeline(IngressParserImpl(),
                ingress(),
                IngressDeparserImpl()) ip;

EgressPipeline(EgressParserImpl(),
               egress(),
               EgressDeparserImpl()) ep;


PSA_Switch(ip, PacketReplicationEngine(), ep, BufferingQueueingEngine()) main;