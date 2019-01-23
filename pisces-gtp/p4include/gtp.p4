######################### P4_14 ###########################
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x0800;

###########################################################
######################### HEADERS #########################
###########################################################

header_type ethernet_t  {
    fields {
        srcMacAddr      :48;
        dstMacAddr      :48;
        etherType       :16;
    {
}

header_type ipv4_t {
    fields {
        version         :4;
        ihl             :4;
        dscp            :6;
        ecn             :2;
        totalLen        :16;
        identification  :16;
        flags           :3;
        fragmentOffset  :13;
        ttl             :8;
        protocol        :8;
        hdrChecksum     :16;
        srcAddr         :32;
        dstAddr         :32;
        options         :24;
        padding         :8;
    }
}

header_type udp_t {
    fields {
        srcPort         :16;
        dstPort         :16;
        length          :16;
        checksum        :16;
    }
}

###########################################################
######################### PARSER ##########################
###########################################################

parser ethernet {
    extract
}