
#include <core.p4>
#include <dpdk/pna.p4>

header ethernet_t {
	bit<48> dst_addr;
	bit<48> src_addr;
	bit<16> ether_type;
}

struct headers_t {
    ethernet_t ethernet;
}

//
// Packet metadata.
//
struct metadata_t {
}

//
// Parser.
//
parser MainParserImpl(
	packet_in pkt,
	out   headers_t hdrs,
	inout metadata_t meta,
	in    pna_main_parser_input_metadata_t istd)
{

	state start {
		transition parse_ethernet;
	}

    state parse_ethernet {
        pkt.extract(hdrs.ethernet);
        transition accept;
    }
}

control PreControlImpl(
    in    headers_t  hdr,
    inout metadata_t meta,
    in    pna_pre_input_metadata_t  istd,
    inout pna_pre_output_metadata_t ostd)
{
    apply {
    }
}

//
// Control block.
//
control MainControlImpl(
	inout headers_t hdrs,
	inout metadata_t meta,
	in    pna_main_input_metadata_t  istd,
	inout pna_main_output_metadata_t ostd)
{

    /* send packet to the port which it came from, and the other port.
        In our case, there are only two ports, 0 and 1. For example, if miss matched, the packet coming from port 0
        will be send back to port 0, and mirror (clone) to port 1.
     */
    action multicast() {
        send_to_port((PortId_t) 0);
        mirror_packet((MirrorSlotId_t) 0, (MirrorSessionId_t) 1); // session 1 -> port 1

/*
        if (istd.input_port == (PortId_t) 0) {
            send_to_port((PortId_t) 0);
            mirror_packet((MirrorSlotId_t) 0, (MirrorSessionId_t) 1); // session 1 -> port 1
        }
        else {
            send_to_port((PortId_t) 1);
            mirror_packet((MirrorSlotId_t) 0, (MirrorSessionId_t) 2); // session 2 -> port 0
        }
*/
    }

    action l2_fwd(PortId_t port_out) {
        send_to_port(port_out);
    }

    table l2_fwd_table {
        key = { hdrs.ethernet.dst_addr : exact; }

        actions = {
            l2_fwd;
            multicast;
        }

        default_action = multicast;
        size = 1024;
    }

	apply {
         if (istd.direction == PNA_Direction_t.NET_TO_HOST) {
            l2_fwd_table.apply();
         }
	}
}

//
// Deparser.
//
control MainDeparserImpl(
	packet_out pkt,
	in    headers_t hdrs,
	in    metadata_t meta,
	in    pna_main_output_metadata_t ostd)
{
	apply {
        pkt.emit(hdrs.ethernet);
	}
}

//
// Package.
//
PNA_NIC(MainParserImpl(), PreControlImpl(), MainControlImpl(), MainDeparserImpl()) main;