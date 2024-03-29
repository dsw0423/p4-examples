#include <core.p4>
#include <psa.p4>

header ethernet_t {
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ether_type;
}

struct headers_t {
  ethernet_t ethernet;
}

struct empty_metadata_t {}

struct local_metadata_t {}

parser packet_parser(
  packet_in packet,
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
      transition accept;
    }
}

control packet_deparser(
    packet_out packet,
    out empty_metadata_t clone_i2e_meta,
    out empty_metadata_t resubmit_meta,
    out empty_metadata_t normal_meta,
    inout headers_t headers,
    in local_metadata_t local_metadata,
    in psa_ingress_output_metadata_t istd) {
    apply {
      packet.emit(headers.ethernet);
    }
}

control ingress(
  inout headers_t headers,
  inout local_metadata_t local_metadata1,
  in psa_ingress_input_metadata_t istd,
  inout psa_ingress_output_metadata_t ostd) 
{
    action l2fwd (bit<32> port_out) {
      send_to_port(ostd, (PortId_t) port_out);
    }

    action drop () {
      ingress_drop(ostd);
    }

/*     action not_matched() {
      if (headers.ethernet.dst_addr == 0xffffffffffff) {
        if (istd.ingress_port == (PortId_t) 0) {
          send_to_port(ostd, (PortId_t) 1);
        } else {
          send_to_port(ostd, (PortId_t) 0);
        }
      } else {
        drop();
      }
    } */

    table l2fwd_table {
      key = {
        headers.ethernet.dst_addr : exact;
      }

      actions = {
        l2fwd;
        // not_matched;
        drop;
      }

      // default_action = not_matched;
      default_action = drop;
      size = 1024;
    }

    apply {
      l2fwd_table.apply();
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
