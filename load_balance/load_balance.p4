#include <core.p4>
#include <dpdk/pna.p4>

header ethernet_t {
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ether_type;
}

header ipv4_t {
    bit<8> ver_ihl;
    bit<8> diffserv;
    bit<16> total_len;
    bit<16> identification;
    bit<16> flags_offset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdr_checksum;
    bit<32> src_addr;
    bit<32> dst_addr;
}

struct headers_t {
    ethernet_t ethernet;
    ipv4_t ipv4;
}

//
// Packet metadata.
//
struct metadata_t {
    bit<32> hash_value;
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
        transition select(hdrs.ethernet.ether_type) {
            0x800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        pkt.extract(hdrs.ipv4);
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
    Hash<bit<32>>(PNA_HashAlgorithm_t.ONES_COMPLEMENT16) hash;

    action drop () {
        drop_packet();
    }

    /* only two possible hash values, 0 and 1. */
    action compute_hash() {
        meta.hash_value = hash.get_hash(
            (bit<32>) 0,
            {   hdrs.ipv4.src_addr,
                hdrs.ipv4.dst_addr,
                hdrs.ipv4.protocol,
                hdrs.ethernet.src_addr,
                hdrs.ethernet.dst_addr },
            (bit<32>) 2
        );
    }

    action fwd (
        bit<48> ethernet_dst_addr,
        bit<48> ethernet_src_addr,
        bit<32> ipv4_dst_addr,
        PortId_t port_out
    ) {
        // hdrs.ipv4.ttl = hdrs.ipv4.ttl - 1;
        hdrs.ipv4.dst_addr = ipv4_dst_addr;
        hdrs.ethernet.dst_addr = ethernet_dst_addr;
        hdrs.ethernet.src_addr = ethernet_src_addr;
        send_to_port(port_out);
    }

    table hash_table {
        key = {
            hdrs.ipv4.dst_addr : exact;
        }

        actions = {
            compute_hash;
            drop;
        }

        default_action = drop;
        size = 1024;
    }

    table fwd_table {
        key = {
            meta.hash_value : exact;
        }

        actions = {
            fwd;
            drop;
        }

        default_action = drop;
        size = 2;
    }

	apply {
         if (istd.direction == PNA_Direction_t.NET_TO_HOST) {
            hash_table.apply();
            fwd_table.apply();
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
        pkt.emit(hdrs.ipv4);
	}
}

//
// Package.
//
PNA_NIC(MainParserImpl(), PreControlImpl(), MainControlImpl(), MainDeparserImpl()) main;
