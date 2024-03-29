#include <core.p4>
#include <dpdk/pna.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<8>  TYPE_TCP  = 6;

// packet incoming into internal network which needs to be protected by firewall.
const bit<8> DIRECTION_IN = 1;

// packet outcoming to outer network
const bit<8> DIRECTION_OUT = 0;

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

header tcp_t{
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<1>  cwr;
    bit<1>  ece;
    bit<1>  urg;
    bit<1>  ack;
    bit<1>  psh;
    bit<1>  rst;
    bit<1>  syn;
    bit<1>  fin;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct metadata_t {
}

struct headers_t {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    tcp_t        tcp;
}

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
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        pkt.extract(hdrs.ipv4);
        transition select(hdrs.ipv4.protocol){
            TYPE_TCP: parse_tcp;
            default: accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdrs.tcp);
        transition accept;
    }
}

control PreControlImpl(
    in    headers_t  hdr,
    inout metadata_t meta,
    in    pna_pre_input_metadata_t  istd,
    inout pna_pre_output_metadata_t ostd)
{
    apply {}
}

control MainControlImpl(
	inout headers_t hdrs,
	inout metadata_t meta,
	in    pna_main_input_metadata_t  istd,
	inout pna_main_output_metadata_t ostd)
{
    Hash<bit<32>>(PNA_HashAlgorithm_t.ONES_COMPLEMENT16) hash_jhash;
    Hash<bit<32>>(PNA_HashAlgorithm_t.CRC32) hash_crc32;
    Register<bit<8>, bit<32>>((bit<32>) 4096, (bit<8>) 0) bloom_filter_1;
    Register<bit<8>, bit<32>>((bit<32>) 4096, (bit<8>) 0) bloom_filter_2;
    bit<32> reg_pos_one; bit<32> reg_pos_two;
    bit<8> reg_val_one; bit<8> reg_val_two;
    bit<8> direction;

    action drop() {
        drop_packet();
    }

    action compute_hashes(bit<32> ip_addr1, bit<32> ip_addr2, bit<16> port1, bit<16> port2) {
        reg_pos_one = hash_jhash.get_hash(
            (bit<32>) 0,
            {
                ip_addr1,
                ip_addr2,
                port1,
                port2,
                hdrs.ipv4.protocol
            },
            (bit<32>) 4096
        );

        reg_pos_two = hash_crc32.get_hash(
            (bit<32>) 0,
            {
                ip_addr1,
                ip_addr2,
                port1,
                port2,
                hdrs.ipv4.protocol
            },
            (bit<32>) 4096
        );
    }

    action ipv4_fwd(
        bit<48> ethernet_dst_addr,
        bit<48> ethernet_src_addr,
        bit<32> port_out
    ) {
        hdrs.ethernet.src_addr = ethernet_src_addr;
        hdrs.ethernet.dst_addr = ethernet_dst_addr;
        hdrs.ipv4.ttl = hdrs.ipv4.ttl - 1;
        send_to_port((PortId_t) port_out);
    }

    table ipv4_table {
        key = {
            hdrs.ipv4.dst_addr : exact;
        }
        actions = {
            ipv4_fwd;
            drop;
        }
        const default_action = drop;
        size =  1024;
    }

    action set_direction(bit<8> dir) {
        direction = dir;
    }

    table check_ports {
        key = {
            istd.input_port : exact;
        }

        actions = {
            set_direction;
            drop;
        }

        default_action = drop;
        size = 1024;
    }

    apply {
        if (istd.direction == PNA_Direction_t.NET_TO_HOST) {
            ipv4_table.apply();
            if (hdrs.tcp.isValid()) {
                direction =  DIRECTION_OUT;
                check_ports.apply();
                if (direction == DIRECTION_IN) {
                    compute_hashes(hdrs.ipv4.src_addr, hdrs.ipv4.dst_addr, hdrs.tcp.srcPort, hdrs.tcp.dstPort);
                    reg_val_one = bloom_filter_1.read(reg_pos_one);
                    reg_val_two = bloom_filter_2.read(reg_pos_two);
                    if (reg_val_one != 1 || reg_val_two != 1) {
                        drop();
                    }
                } else if (direction == DIRECTION_OUT && hdrs.tcp.syn == 1) {
                    compute_hashes(hdrs.ipv4.dst_addr, hdrs.ipv4.src_addr, hdrs.tcp.dstPort, hdrs.tcp.srcPort);
                    bloom_filter_1.write(reg_pos_one, 1);
                    bloom_filter_2.write(reg_pos_two, 1);
                }
            }
        }
    }
}

control MainDeparserImpl(
	packet_out pkt,
	in    headers_t hdrs,
	in    metadata_t meta,
	in    pna_main_output_metadata_t ostd)
{
	apply {
        pkt.emit(hdrs.ethernet);
        pkt.emit(hdrs.ipv4);
        if (hdrs.tcp.isValid())
            pkt.emit(hdrs.tcp);
	}
}

PNA_NIC(MainParserImpl(), PreControlImpl(), MainControlImpl(), MainDeparserImpl()) main;
