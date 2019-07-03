#include <core.p4>
#include <v1model.p4>

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

typedef bit<32> saddr;
typedef bit<32> daddr;
typedef bit<32> srcport;
typedef bit<32> dstport;

typedef bit<9> egressSpec_t;

struct ConnectionInfo_t {
    bit<8> s;
    bit<32> srv_addr;
}

struct ConnectionId_t {
    bit<32> saddr;
    bit<32> daddr;
    bit<16> srcport;
    bit<16> dstport;
}

struct metadata_t {
    ConnectionInfo_t connInfo;
    bit<32> conn_id;
}


parser ParserImpl(packet_in packet,
                  out headers_t hdr,
                  inout metadata_t meta,
                  inout standard_metadata_t stdmeta)
{
    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x0800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition parse_tcp;
    }
    state parse_tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }
}

control ingress(inout headers_t hdr,
                inout metadata_t meta,
                inout standard_metadata_t stdmeta) {

    register<bit<8>>(65536) conn_state;
    register<bit<32>>(65536) conn_srv_addr;

    action update_conn_state(bit<8> s) {
        conn_state.write(meta.conn_id, s);
    }

    action update_conn_info(bit<8> s, bit<32> addr) {
        conn_state.write(meta.conn_id, s);
        conn_srv_addr.write(meta.conn_id, addr);
    }

    action drop() {
        mark_to_drop(stdmeta);
    }

    action forward(bit<48> dmac, egressSpec_t intf) {
        hdr.ethernet.dstAddr = dmac;
        stdmeta.egress_spec = intf;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ipv4_da_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            forward;
            drop;
        }
    }


    apply {
        if (hdr.ipv4.isValid()) {
            @atomic {
                hash(meta.conn_id, HashAlgorithm.crc16, (bit<13>)0, { hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.ipv4.protocol, hdr.tcp.srcPort, hdr.tcp.dstPort }, (bit<32>)65536);
                conn_state.read(meta.connInfo.s, meta.conn_id);
                conn_srv_addr.read(meta.connInfo.srv_addr, meta.conn_id);
                if (meta.connInfo.s == 0 || meta.connInfo.srv_addr == 0) {
                    if (hdr.tcp.syn == 1 && hdr.tcp.ack == 0) {
                        // It's a SYN
                        update_conn_info((bit<8>) State.SYNSENT, hdr.ipv4.dstAddr);
                    }
                } else if (meta.connInfo.srv_addr == hdr.ipv4.srcAddr) {
                    if (meta.connInfo.s == (bit<8>) State.SYNSENT) {
                        if (hdr.tcp.syn == 1 && hdr.tcp.ack == 1) {
                            // It's a SYN-ACK
                            update_conn_state((bit<8>) State.SYNACKED);
                        }
                        drop();
                    } else if (meta.connInfo.s == (bit<8>) State.SYNACKED) {
                        drop();
                    } else if (meta.connInfo.s == (bit<8>) State.ESTABLISHED) {
                        if (hdr.tcp.fin == 1 && hdr.tcp.ack == 1) {
                            update_conn_info(0, 0); // clear register entry
                        }
                    }
                } else {
                    if (meta.connInfo.s == (bit<8>) State.SYNSENT) {
                        drop();
                    } else if (meta.connInfo.s == (bit<8>) State.SYNACKED) {
                        if (hdr.tcp.syn == 0 && hdr.tcp.ack == 1) {
                            // It's a ACK
                            update_conn_state((bit<8>) State.ESTABLISHED);
                        }
                    } else if (meta.connInfo.s == (bit<8>) State.ESTABLISHED) {
                        if (hdr.tcp.fin == 1 && hdr.tcp.ack == 1) {
                            update_conn_info(0, 0); // clear register entry
                        }
                    }
                }
            }
            ipv4_da_lpm.apply();
        }
    }

}

control egress(inout headers_t hdr,
               inout metadata_t meta,
               inout standard_metadata_t stdmeta) {

    action my_drop() {
        mark_to_drop(stdmeta);
    }
    action rewrite_mac(bit<48> smac) {
        hdr.ethernet.srcAddr = smac;
    }
    table send_frame {
        key = {
            stdmeta.egress_port: exact;
        }
        actions = {
            NoAction;
            rewrite_mac;
            my_drop;
        }
        default_action = NoAction();
    }

    apply {
        send_frame.apply();
    }

}

control DeparserImpl(packet_out packet,
                           in headers_t hdr)
{
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}


control updateChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply {
        update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	      hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

control verifyChecksum(inout headers_t hdr, inout metadata_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(),
         verifyChecksum(),
         ingress(),
         egress(),
         updateChecksum(),
         DeparserImpl()) main;