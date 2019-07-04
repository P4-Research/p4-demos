#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "parser.p4"

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

    action _drop() {
        mark_to_drop(stdmeta);
    }

    action set_nhop(bit<32> nhop_ipv4, bit<9> port) {
        meta.ingress_metadata.nhop_ipv4 = nhop_ipv4;
        stdmeta.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
    }
    action set_dmac(bit<48> dmac) {
        hdr.ethernet.dstAddr = dmac;
    }
    table ipv4_lpm {
        actions = {
            _drop;
            set_nhop;
            NoAction;
        }
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        size = 1024;
        default_action = NoAction();
    }
    table forward {
        actions = {
            set_dmac;
            _drop;
            NoAction;
        }
        key = {
            meta.ingress_metadata.nhop_ipv4: exact;
        }
        size = 512;
        default_action = NoAction();
    }

    apply {
        if (hdr.tcp.isValid()) {
            @atomic {
                if (hdr.ipv4.srcAddr < hdr.ipv4.dstAddr) {
                    hash(meta.conn_id, HashAlgorithm.crc16, (bit<13>)0, { hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.ipv4.protocol, hdr.tcp.srcPort, hdr.tcp.dstPort }, (bit<32>)65536);
                } else {
                    hash(meta.conn_id, HashAlgorithm.crc16, (bit<13>)0, { hdr.ipv4.dstAddr, hdr.ipv4.srcAddr, hdr.ipv4.protocol, hdr.tcp.dstPort, hdr.tcp.srcPort }, (bit<32>)65536);
                }
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
                    } else if (meta.connInfo.s == (bit<8>) State.SYNACKED) {
                        _drop();
                        return;
                    } else if (meta.connInfo.s == (bit<8>) State.ESTABLISHED) {
                        if (hdr.tcp.fin == 1 && hdr.tcp.ack == 1) {
                            update_conn_info(0, 0); // clear register entry
                        }
                    }
                } else {
                    if (meta.connInfo.s == (bit<8>) State.SYNSENT) {
                        _drop();
                        return;
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
        }
        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
            forward.apply();
        }
    }

}

control egress(inout headers_t hdr, inout metadata_t meta, inout standard_metadata_t standard_metadata) {
    action rewrite_mac(bit<48> smac) {
        hdr.ethernet.srcAddr = smac;
    }
    action _drop() {
        mark_to_drop(standard_metadata);
    }
    table send_frame {
        actions = {
            rewrite_mac;
            _drop;
            NoAction;
        }
        key = {
            standard_metadata.egress_port: exact;
        }
        size = 256;
        default_action = NoAction();
    }
    apply {
        if (hdr.ipv4.isValid()) {
          send_frame.apply();
        }
    }
}

V1Switch(ParserImpl(),
         verifyChecksum(),
         ingress(),
         egress(),
         updateChecksum(),
         DeparserImpl()) main;