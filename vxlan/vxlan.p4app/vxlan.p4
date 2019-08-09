#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "parser.p4"

#define ETH_HDR_SIZE 14
#define IPV4_HDR_SIZE 20
#define UDP_HDR_SIZE 8
#define VXLAN_HDR_SIZE 8
#define IP_VERSION_4 4
#define IPV4_MIN_IHL 5

control vxlan_ingress_upstream(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {

    action vxlan_decap() {
        // as simple as set outer headers as invalid
        hdr.ethernet.setInvalid();
        hdr.ipv4.setInvalid();
        hdr.udp.setInvalid();
        hdr.vxlan.setInvalid();
    }

    table t_vxlan_term {
        key = {
            // Inner Ethernet desintation MAC address of target VM
            hdr.inner_ethernet.dstAddr : exact;
        }

        actions = {
            @defaultonly NoAction;
            vxlan_decap();
        }

    }

    action forward(bit<9> port) {
        standard_metadata.egress_spec = port;
    }

    table t_forward_l2 {
        key = {
            hdr.inner_ethernet.dstAddr : exact;
        }

        actions = {
            forward;
        }
    }

    apply {
        if (hdr.ipv4.isValid()) {
            if (t_vxlan_term.apply().hit) {
                t_forward_l2.apply();
            }
        }
    }
}

control vxlan_egress_upstream(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {

    apply {

    }

}

control vxlan_ingress_downstream(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {

    action set_vni(bit<24> vni) {
        meta.vxlan_vni = vni;
    }

    action set_ipv4_nexthop(bit<32> nexthop) {
        meta.nexthop = nexthop;
    }

    table t_vxlan_segment {

        key = {
            hdr.ipv4.dstAddr : lpm;
        }

        actions = {
            @defaultonly NoAction;
            set_vni;
        }

    }

    table t_vxlan_nexthop {

        key = {
            hdr.ethernet.dstAddr : exact;
        }

        actions = {
            set_ipv4_nexthop;
        }
    }

    action set_vtep_ip(bit<32> vtep_ip) {
        meta.vtepIP = vtep_ip;
    }

    table t_vtep {
        key = {
            hdr.ethernet.srcAddr : exact;
        }

        actions = {
            set_vtep_ip;
        }

    }

    action route(bit<9> port) {
        standard_metadata.egress_spec = port;
    }

    table t_vxlan_routing {

        key = {
            meta.nexthop : exact;
        }

        actions = {
            route;
        }
    }

    apply {
        if (hdr.ipv4.isValid()) {
            t_vtep.apply();
            if(t_vxlan_segment.apply().hit) {
                if(t_vxlan_nexthop.apply().hit) {
                    t_vxlan_routing.apply();
                }
            }
        }
    }

}

control vxlan_egress_downstream(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {

    action rewrite_macs(bit<48> smac, bit<48> dmac) {
        hdr.ethernet.srcAddr = smac;
        hdr.ethernet.dstAddr = dmac;
    }

    table t_send_frame {

            key = {
                hdr.ipv4.dstAddr : exact;
            }

            actions = {
                rewrite_macs;
            }
        }

    action vxlan_encap() {

        hdr.inner_ethernet = hdr.ethernet;
        hdr.inner_ipv4 = hdr.ipv4;

        hdr.ethernet.setValid();

        hdr.ipv4.setValid();
        hdr.ipv4.version = IP_VERSION_4;
        hdr.ipv4.ihl = IPV4_MIN_IHL;
        hdr.ipv4.diffserv = 0;
        hdr.ipv4.totalLen = hdr.ipv4.totalLen
                            + (ETH_HDR_SIZE + IPV4_HDR_SIZE + UDP_HDR_SIZE + VXLAN_HDR_SIZE);
        hdr.ipv4.identification = 0x1513; /* From NGIC */
        hdr.ipv4.flags = 0;
        hdr.ipv4.fragOffset = 0;
        hdr.ipv4.ttl = 64;
        hdr.ipv4.protocol = UDP_PROTO;
        hdr.ipv4.dstAddr = meta.nexthop;
        hdr.ipv4.srcAddr = meta.vtepIP;
        hdr.ipv4.hdrChecksum = 0;

        hdr.udp.setValid();
        // The VTEP calculates the source port by performing the hash of the inner Ethernet frame's header.
        hash(hdr.udp.srcPort, HashAlgorithm.crc16, (bit<13>)0, { hdr.inner_ethernet }, (bit<32>)65536);
        hdr.udp.dstPort = UDP_PORT_VXLAN;
        hdr.udp.length = hdr.ipv4.totalLen + (UDP_HDR_SIZE + VXLAN_HDR_SIZE);
        hdr.udp.checksum = 0;

        hdr.vxlan.setValid();
        hdr.vxlan.reserved = 0;
        hdr.vxlan.reserved_2 = 0;
        hdr.vxlan.flags = 0;
        hdr.vxlan.vni = meta.vxlan_vni;

    }

    apply {
        if (meta.vxlan_vni != 0) {
            vxlan_encap();
            if (hdr.vxlan.isValid()) {
                t_send_frame.apply();
            }
        }
    }

}

control vxlan_egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {

    vxlan_egress_downstream()  downstream;

    apply {
        if (!hdr.vxlan.isValid()) {
            downstream.apply(hdr, meta, standard_metadata);
        }
    }
}



control vxlan_ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {

    vxlan_ingress_downstream()  downstream;
    vxlan_ingress_upstream()    upstream;

    apply {
        if (hdr.vxlan.isValid()) {
            upstream.apply(hdr, meta, standard_metadata);
        } else {
            downstream.apply(hdr, meta, standard_metadata);
        }
    }
}

V1Switch(ParserImpl(), verifyChecksum(), vxlan_ingress(), vxlan_egress(), computeChecksum(), DeparserImpl()) main;