#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "parser.p4"

#define BUCKET_SIZE 1000
#define GENERATION_RATE 10

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
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

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    register<bit<48>>(1) timestamp_r;
    register<bit<32>>(1) count_r;

    action _drop() {
        mark_to_drop(standard_metadata);
    }
    action set_nhop(bit<32> nhop_ipv4, bit<9> port) {
        meta.ingress_metadata.nhop_ipv4 = nhop_ipv4;
        standard_metadata.egress_spec = port;
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

        bit<32> last_count;
        bit<48> last_ts;
        count_r.read(last_count, 0);
        timestamp_r.read(last_ts, 0);

        bit<48> time_diff;
        time_diff = standard_metadata.ingress_global_timestamp - last_ts;

        if (time_diff > 10 * 1000000) {
            count_r.write(0, 0);
            //if (((bit<48>)BUCKET_SIZE) < ((bit<48>)last_count) + (GENERATION_RATE) * (time_diff)) {
            //    count_r.write(0, BUCKET_SIZE);
            //} else {
            //    count_r.write(0, (bit<32>)(((bit<48>)last_count) + ((bit<48>)GENERATION_RATE) * ((bit<48>)time_diff));
            //}
            timestamp_r.write(0, standard_metadata.ingress_global_timestamp);
        }

        if (last_count <= BUCKET_SIZE) {
            //count_r.write(0, last_count + standard_metadata.packet_length);
            count_r.write(0, last_count + 1);
        } else {
            mark_to_drop(standard_metadata);
            return;
        }

        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
            forward.apply();
        }
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
