//######################### P4_14 #########################


/*#########################################################
######################## CONSTANTS ########################
#########################################################*/

#define TYPE_IPV4 0x0800
#define TYPE_UDP 0x11
#define TYPE_UDP_GTP_PORT 2152

/*#########################################################
######################### HEADERS #########################
#########################################################*/

header_type ethernet_t  {
    fields {
        srcMacAddr      :48;
        dstMacAddr      :48;
        etherType       :16;
    }
}
header ethernet_t ethernet;

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
    }
}
header ipv4_t ipv4;

header_type udp_t {
    fields {
        srcPort         :16;
        dstPort         :16;
        len             :16;
        checksum        :16;
    }
}
header udp_t udp;

header_type tcp_t {
    fields {
        srcPort         :16;
        dstPort         :16;
        seqNumber       :32;
        ackNumber       :32;
        dataOffset      :4;
        reserved        :6;
        ctrl            :6;
        window          :16;
        checksum        :16;
        urgentPointer   :16;
    }
}
header tcp_t tcp;

header_type gtp_t {
    fields {
        version         :3;
        ptFlag          :1; //protocol type - 1 when GTP and 0 when GTP'
        spare           :1; //shall be set to 0
        extHdrFlag      :1;
        seqNumberFlag   :1;
        npduFlag        :1;
        msgType         :8;
        len             :16;
        tunnelEndID     :32;
    }
}
header gtp_t gtp;

/*#########################################################
######################### PARSER ##########################
#########################################################*/

parser start {
    return parse_ethernet;
    }

parser parse_ethernet {
    extract(ethernet);
        return select(latest.etherType) {
            0x0800:  parse_ipv4;
            default:    ingress;
    }
}

parser parse_ipv4 {
    extract(ipv4);
        return select(latest.protocol) {
            TYPE_UDP:   parse_udp;
            default:    ingress;
        }
}

parser parse_udp {
    extract(udp);
        return select(latest.dstPort) {
            TYPE_UDP_GTP_PORT:  parse_gtp;
            default:            ingress;
        }
}

parser parse_gtp {
    extract(gtp);
        return ingress;
}