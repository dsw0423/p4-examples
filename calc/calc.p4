#include <core.p4>
#include <psa.p4>

struct empty_metadata_t {
}

struct local_metadata_t {
}

header ethernet_t {
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ether_type;
}

const bit<16> P4CALC_ETYPE = 0x1234;
const bit<8>  P4CALC_P     = 0x50;   // 'P'
const bit<8>  P4CALC_4     = 0x34;   // '4'
const bit<8>  P4CALC_VER   = 0x01;   // v0.1
const bit<8>  P4CALC_PLUS  = 0x2b;   // '+'
const bit<8>  P4CALC_MINUS = 0x2d;   // '-'
const bit<8>  P4CALC_AND   = 0x26;   // '&'
const bit<8>  P4CALC_OR    = 0x7c;   // '|'
const bit<8>  P4CALC_CARET = 0x5e;   // '^'

header p4calc_t {
    bit<8>  p;
    bit<8>  four;
    bit<8>  ver;
    bit<8>  op;
    bit<32> operand_a;
    bit<32> operand_b;
    bit<32> res;
}

struct headers_t {
    ethernet_t   ethernet;
    p4calc_t     p4calc;
}

parser packet_parser(packet_in packet,
                    out headers_t headers,
                    inout local_metadata_t local_metadata,
                    in psa_ingress_parser_input_metadata_t standard_metadata,
                    in empty_metadata_t resub_meta,
                    in empty_metadata_t recirc_meta) {
    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        packet.extract(headers.ethernet);
        transition parser_p4calc;
    }
    state parser_p4calc {
        packet.extract(headers.p4calc);
        transition accept;
    }
}

control ingress(inout headers_t hdr,
                inout local_metadata_t local_metadata1,
                in psa_ingress_input_metadata_t istd,
                inout psa_ingress_output_metadata_t ostd) {
    action drop(){
        ingress_drop(ostd);
    }

    action send_back(bit<32> result) {
        bit<48> tmp;

        /* Put the result back in */
        hdr.p4calc.res = result;

        /* Swap the MAC addresses */
        tmp = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = tmp;

        /* Send the packet back to the port it came from */
        send_to_port(ostd, istd.ingress_port);
    }

    action operation_add() {
        send_back(hdr.p4calc.operand_a + hdr.p4calc.operand_b);
    }

    action operation_sub() {
        send_back(hdr.p4calc.operand_a - hdr.p4calc.operand_b);
    }

    action operation_and() {
        send_back(hdr.p4calc.operand_a & hdr.p4calc.operand_b);
    }

    action operation_or() {
        send_back(hdr.p4calc.operand_a | hdr.p4calc.operand_b);
    }

    action operation_xor() {
        send_back(hdr.p4calc.operand_a ^ hdr.p4calc.operand_b);
    }

    table calculate {
        key = {
            hdr.p4calc.op        : exact;
        }
        actions = {
            operation_add;
            operation_sub;
            operation_and;
            operation_or;
            operation_xor;
            drop;
        }
        const default_action = drop();
        const entries = {
            P4CALC_PLUS : operation_add();
            P4CALC_MINUS: operation_sub();
            P4CALC_AND  : operation_and();
            P4CALC_OR   : operation_or();
            P4CALC_CARET: operation_xor();
        }
        size =  1024 * 1024;
    }

    apply {
        if (hdr.p4calc.isValid()) {
            calculate.apply();
        } else {
            drop();
        }
    }
}

control packet_deparser(packet_out packet, out empty_metadata_t clone_i2e_meta, out empty_metadata_t resubmit_meta, out empty_metadata_t normal_meta, inout headers_t headers, in local_metadata_t local_metadata, in psa_ingress_output_metadata_t istd) {
    apply {
        packet.emit(headers.ethernet);
        packet.emit(headers.p4calc);
    }
}

control egress(inout headers_t headers, inout local_metadata_t local_metadata, in psa_egress_input_metadata_t istd, inout psa_egress_output_metadata_t ostd) {
    apply {
    }
}

parser egress_parser(packet_in buffer, out headers_t headers, inout local_metadata_t local_metadata, in psa_egress_parser_input_metadata_t istd, in empty_metadata_t normal_meta, in empty_metadata_t clone_i2e_meta, in empty_metadata_t clone_e2e_meta) {
    state start {
        transition accept;
    }
}

control egress_deparser(packet_out packet, out empty_metadata_t clone_e2e_meta, out empty_metadata_t recirculate_meta, inout headers_t headers, in local_metadata_t local_metadata, in psa_egress_output_metadata_t istd, in psa_egress_deparser_input_metadata_t edstd) {
    apply {
    }
}

IngressPipeline(packet_parser(), ingress(), packet_deparser()) ip;
EgressPipeline(egress_parser(), egress(), egress_deparser()) ep;

PSA_Switch(ip, PacketReplicationEngine(), ep, BufferingQueueingEngine()) main;
