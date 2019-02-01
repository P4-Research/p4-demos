#define ETHERTYPE_IPV4 0x0800
#define ETHERTYPE_MPLS 0x8847
#define IPV4_UDP       0x11

header_type ethernet_t {
    fields {
        dstAddr : 48;
        srcAddr : 48;
        etherType : 16;
    }
}

header_type mpls_t {
    fields {
        label : 20;
        tc : 3; // traffic class field
        bos : 1; // indicates if it's bottom of MPLS label's stack
        ttl: 8;
    }
}

header_type ipv4_t {
    fields {
        version : 4;
        ihl : 4;
        diffserv : 8;
        totalLen : 16;
        identification : 16;
        flags : 3;
        fragOffset : 13;
        ttl : 8;
        protocol : 8;
        hdrChecksum : 16;
        srcAddr : 32;
        dstAddr: 32;
    }
}

header_type udp_t {
    fields {
        srcPort : 16;
        dstPort : 16;
        length_ : 16;
        checksum : 16;
    }
}

header ethernet_t ethernet;
header ipv4_t ipv4;
header mpls_t mpls;
header udp_t udp;

/** PARSERS **/

parser start {
    return parse_ethernet;
}

parser parse_ethernet {
    extract(ethernet);
    return select(latest.etherType) {
        ETHERTYPE_IPV4 : parse_ipv4;
        ETHERTYPE_MPLS : parse_mpls;
        default: ingress;
    }
}

parser parse_ipv4 {
    extract(ipv4);
    return select(latest.protocol) {
        IPV4_UDP : parse_udp;
        default: ingress;
    }
}

parser parse_mpls {
    extract(mpls);
    //return select(latest.bos) {
    //    0 : parse_mpls; // parse MPLS header recursively.
    //    1 : parse_mpls_bos; // parse the last MPLS header in stack
    //    default: ingress;
    //}
    return parse_ipv4;
}

parser parse_udp {
    extract(udp);
    return ingress;
}

action _drop() {
    drop();
}

action push_mpls(label) {
    add_header(mpls);
    modify_field(mpls.label, label);
    modify_field(mpls.tc, 7);
    modify_field(mpls.bos, 0x1);
    modify_field(mpls.ttl, 32);
    modify_field(ethernet.etherType, ETHERTYPE_MPLS);
}

action pop_mpls() {
    remove_header(mpls);
}

action swap_mpls(label) {
   modify_field(mpls.label, label);
   subtract_from_field(mpls.ttl, 1);
}

table fec_table {

    reads {
        ipv4.dstAddr : exact;
    }

    actions {
        push_mpls;
        pop_mpls;
        _drop;
    }

    size: 1024;
}

table mpls_table {

    reads {
        mpls.label : exact;
    }

    actions {
        swap_mpls;
        _drop;
    }

    size: 1024;
}

action forward(intf) {
    modify_field(standard_metadata.egress_spec, intf);
}

table forwarding_table {

    reads {
        mpls.label : exact;
    }

    actions {
        forward;
        _drop;
    }

    size: 1024;

}

control ingress {
    apply(fec_table);
    apply(mpls_table);
    apply(forwarding_table);
}










