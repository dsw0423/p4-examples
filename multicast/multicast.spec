
struct ethernet_t {
	bit<48> dst_addr
	bit<48> src_addr
	bit<16> ether_type
}

struct l2_fwd_arg_t {
	bit<32> port_out
}

header ethernet instanceof ethernet_t

struct metadata_t {
	bit<32> pna_main_input_metadata_direction
	bit<32> pna_main_input_metadata_input_port
	bit<32> pna_main_output_metadata_output_port
	bit<8> mirrorSlot
	bit<16> mirrorSession
	bit<8> mirrorSlot_0
	bit<16> mirrorSession_0
}
metadata instanceof metadata_t

regarray direction size 0x100 initval 0
action multicast args none {
	jmpneq LABEL_FALSE_0 m.pna_main_input_metadata_input_port 0x0
	mov m.pna_main_output_metadata_output_port 0x0
	mov m.mirrorSlot 0x0
	mov m.mirrorSession 0x1
	mirror m.mirrorSlot m.mirrorSession
	jmp LABEL_END_0
	LABEL_FALSE_0 :	mov m.pna_main_output_metadata_output_port 0x1
	mov m.mirrorSlot_0 0x0
	mov m.mirrorSession_0 0x2
	mirror m.mirrorSlot_0 m.mirrorSession_0
	LABEL_END_0 :	return
}

action l2_fwd args instanceof l2_fwd_arg_t {
	mov m.pna_main_output_metadata_output_port t.port_out
	return
}

table l2_fwd_table {
	key {
		h.ethernet.dst_addr exact
	}
	actions {
		l2_fwd
		multicast
	}
	default_action multicast args none 
	size 0x400
}


apply {
	rx m.pna_main_input_metadata_input_port
	regrd m.pna_main_input_metadata_direction direction m.pna_main_input_metadata_input_port
	extract h.ethernet
	jmpneq LABEL_END m.pna_main_input_metadata_direction 0x0
	table l2_fwd_table
	LABEL_END :	emit h.ethernet
	tx m.pna_main_output_metadata_output_port
}


