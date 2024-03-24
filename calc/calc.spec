
struct ethernet_t {
	bit<48> dst_addr
	bit<48> src_addr
	bit<16> ether_type
}

struct p4calc_t {
	bit<8> p
	bit<8> four
	bit<8> ver
	bit<8> op
	bit<32> operand_a
	bit<32> operand_b
	bit<32> res
}

struct psa_ingress_output_metadata_t {
	bit<8> class_of_service
	bit<8> clone
	bit<16> clone_session_id
	bit<8> drop
	bit<8> resubmit
	bit<32> multicast_group
	bit<32> egress_port
}

struct psa_egress_output_metadata_t {
	bit<8> clone
	bit<16> clone_session_id
	bit<8> drop
}

struct psa_egress_deparser_input_metadata_t {
	bit<32> egress_port
}

struct local_metadata_t {
	bit<32> psa_ingress_input_metadata_ingress_port
	bit<8> psa_ingress_output_metadata_drop
	bit<32> psa_ingress_output_metadata_multicast_group
	bit<32> psa_ingress_output_metadata_egress_port
	bit<48> Ingress_tmp
}
metadata instanceof local_metadata_t

header ethernet instanceof ethernet_t
header p4calc instanceof p4calc_t

action drop_1 args none {
	mov m.psa_ingress_output_metadata_drop 1
	return
}

action operation_add args none {
	mov h.p4calc.res h.p4calc.operand_a
	add h.p4calc.res h.p4calc.operand_b
	mov m.Ingress_tmp h.ethernet.dst_addr
	mov h.ethernet.dst_addr h.ethernet.src_addr
	mov h.ethernet.src_addr m.Ingress_tmp
	mov m.psa_ingress_output_metadata_drop 0
	mov m.psa_ingress_output_metadata_multicast_group 0x0
	mov m.psa_ingress_output_metadata_egress_port m.psa_ingress_input_metadata_ingress_port
	return
}

action operation_sub args none {
	mov h.p4calc.res h.p4calc.operand_a
	sub h.p4calc.res h.p4calc.operand_b
	mov m.Ingress_tmp h.ethernet.dst_addr
	mov h.ethernet.dst_addr h.ethernet.src_addr
	mov h.ethernet.src_addr m.Ingress_tmp
	mov m.psa_ingress_output_metadata_drop 0
	mov m.psa_ingress_output_metadata_multicast_group 0x0
	mov m.psa_ingress_output_metadata_egress_port m.psa_ingress_input_metadata_ingress_port
	return
}

action operation_and args none {
	mov h.p4calc.res h.p4calc.operand_a
	and h.p4calc.res h.p4calc.operand_b
	mov m.Ingress_tmp h.ethernet.dst_addr
	mov h.ethernet.dst_addr h.ethernet.src_addr
	mov h.ethernet.src_addr m.Ingress_tmp
	mov m.psa_ingress_output_metadata_drop 0
	mov m.psa_ingress_output_metadata_multicast_group 0x0
	mov m.psa_ingress_output_metadata_egress_port m.psa_ingress_input_metadata_ingress_port
	return
}

action operation_or args none {
	mov h.p4calc.res h.p4calc.operand_a
	or h.p4calc.res h.p4calc.operand_b
	mov m.Ingress_tmp h.ethernet.dst_addr
	mov h.ethernet.dst_addr h.ethernet.src_addr
	mov h.ethernet.src_addr m.Ingress_tmp
	mov m.psa_ingress_output_metadata_drop 0
	mov m.psa_ingress_output_metadata_multicast_group 0x0
	mov m.psa_ingress_output_metadata_egress_port m.psa_ingress_input_metadata_ingress_port
	return
}

action operation_xor args none {
	mov h.p4calc.res h.p4calc.operand_a
	xor h.p4calc.res h.p4calc.operand_b
	mov m.Ingress_tmp h.ethernet.dst_addr
	mov h.ethernet.dst_addr h.ethernet.src_addr
	mov h.ethernet.src_addr m.Ingress_tmp
	mov m.psa_ingress_output_metadata_drop 0
	mov m.psa_ingress_output_metadata_multicast_group 0x0
	mov m.psa_ingress_output_metadata_egress_port m.psa_ingress_input_metadata_ingress_port
	return
}

table calculate {
	key {
		h.p4calc.op exact
	}
	actions {
		operation_add
		operation_sub
		operation_and
		operation_or
		operation_xor
		drop_1
	}
	default_action drop_1 args none const
	size 0x100000
}


apply {
	rx m.psa_ingress_input_metadata_ingress_port
	mov m.psa_ingress_output_metadata_drop 0x1
	extract h.ethernet
	extract h.p4calc
	jmpnv LABEL_FALSE h.p4calc
	table calculate
	jmp LABEL_END
	LABEL_FALSE :	mov m.psa_ingress_output_metadata_drop 1
	LABEL_END :	jmpneq LABEL_DROP m.psa_ingress_output_metadata_drop 0x0
	emit h.ethernet
	emit h.p4calc
	tx m.psa_ingress_output_metadata_egress_port
	LABEL_DROP :	drop
}


