#include <core.p4>
#include <psa.p4>

enum bit<8> State { SYNSENT = 1, SYNACKED = 2, ESTABLISHED = 3 }

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

struct empty_metadata_t {
}

typedef bit<32> saddr;
typedef bit<32> daddr;
typedef bit<32> srcport;
typedef bit<32> dstport;

//struct ConnectionInfo_t {
//    State s;
//    bit<32> srv_addr;
//}

struct ConnectionId_t {
    bit<32> saddr;
    bit<32> daddr;
    bit<16> srcport;
    bit<16> dstport;
}

parser IngressParserImpl(packet_in buffer,
                         out headers parsed_hdr,
                         inout empty_metadata_t user_meta,
                         in psa_ingress_parser_input_metadata_t istd,
                         in empty_metadata_t resubmit_meta,
                         in empty_metadata_t recirculate_met)
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

control ingress(inout headers hdr,
                inout empty_metadata_t user_meta,
                in    psa_ingress_input_metadata_t  istd,
                inout psa_ingress_output_metadata_t ostd) {

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

control egress(inout headers hdr,
               inout empty_metadata_t user_meta,
               in    psa_egress_input_metadata_t  istd,
               inout psa_egress_output_metadata_t ostd) {

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

control IngressDeparserImpl(packet_out buffer,
                            out empty_metadata_t clone_i2e_meta,
                            out empty_metadata_t resubmit_meta,
                            out empty_metadata_t normal_meta,
                            inout headers hdr,
                            in empty_metadata_t meta,
                            in psa_ingress_output_metadata_t istd)
{
    CommonDeparserImpl() cp;
    apply {
        cp.apply(buffer, hdr);
    }
}

control EgressDeparserImpl(packet_out buffer,
                           out empty_metadata_t clone_e2e_meta,
                           out empty_metadata_t recirculate_meta,
                           inout headers hdr,
                           in empty_metadata_t meta,
                           in psa_egress_output_metadata_t istd,
                           in psa_egress_deparser_input_metadata_t edstd)
{
    CommonDeparserImpl() cp;
    apply {
        cp.apply(buffer, hdr);
    }
}

parser EgressParserImpl(packet_in buffer,
                        out headers parsed_hdr,
                        inout empty_metadata_t user_meta,
                        in psa_egress_parser_input_metadata_t istd,
                        in empty_metadata_t normal_meta,
                        in empty_metadata_t clone_i2e_meta,
                        in empty_metadata_t clone_e2e_meta)
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