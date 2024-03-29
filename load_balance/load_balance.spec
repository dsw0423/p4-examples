

struct ethernet_t {
	bit<48> dst_addr
	bit<48> src_addr
	bit<16> ether_type
}

struct ipv4_t {
	bit<8> ver_ihl
	bit<8> diffserv
	bit<16> total_len
	bit<16> identification
	bit<16> flags_offset
	bit<8> ttl
	bit<8> protocol
	bit<16> hdr_checksum
	bit<32> src_addr
	bit<32> dst_addr
}

struct fwd_arg_t {
	bit<48> ethernet_dst_addr
	bit<48> ethernet_src_addr
	bit<32> ipv4_dst_addr
	bit<32> port_out
}

header ethernet instanceof ethernet_t
header ipv4 instanceof ipv4_t

struct metadata_t {
	bit<32> pna_main_input_metadata_direction
	bit<32> pna_main_input_metadata_input_port
	bit<32> local_metadata_hash_value
	bit<32> pna_main_output_metadata_output_port
	bit<32> MainControlT_tmp
	bit<32> MainControlT_tmp_0
	bit<8> MainControlT_tmp_1
	bit<48> MainControlT_tmp_2
	bit<48> MainControlT_tmp_3
}
metadata instanceof metadata_t

regarray direction size 0x100 initval 0
action drop args none {
	drop
	return
}

action drop_1 args none {
	drop
	return
}

action compute_hash args none {
	mov m.MainControlT_tmp h.ipv4.src_addr
	mov m.MainControlT_tmp_0 h.ipv4.dst_addr
	mov m.MainControlT_tmp_1 h.ipv4.protocol
	mov m.MainControlT_tmp_2 h.ethernet.src_addr
	mov m.MainControlT_tmp_3 h.ethernet.dst_addr
	hash jhash m.local_metadata_hash_value  m.MainControlT_tmp m.MainControlT_tmp_3
	and m.local_metadata_hash_value 0x1
	add m.local_metadata_hash_value 0x0
	return
}

action fwd args instanceof fwd_arg_t {
	add h.ipv4.ttl 0xFF
	mov h.ipv4.dst_addr t.ipv4_dst_addr
	mov h.ethernet.dst_addr t.ethernet_dst_addr
	mov h.ethernet.src_addr t.ethernet_src_addr
	mov m.pna_main_output_metadata_output_port t.port_out
	return
}

table hash_table {
	key {
		h.ipv4.dst_addr exact
	}
	actions {
		compute_hash
		drop
	}
	default_action drop args none 
	size 0x400
}


table fwd_table {
	key {
		m.local_metadata_hash_value exact
	}
	actions {
		fwd
		drop_1
	}
	default_action drop_1 args none 
	size 0x2
}


apply {
	rx m.pna_main_input_metadata_input_port
	regrd m.pna_main_input_metadata_direction direction m.pna_main_input_metadata_input_port
	extract h.ethernet
	jmpeq MAINPARSERIMPL_PARSE_IPV4 h.ethernet.ether_type 0x800
	jmp MAINPARSERIMPL_ACCEPT
	MAINPARSERIMPL_PARSE_IPV4 :	extract h.ipv4
	MAINPARSERIMPL_ACCEPT :	jmpneq LABEL_END m.pna_main_input_metadata_direction 0x0
	table hash_table
	table fwd_table
	LABEL_END :	emit h.ethernet
	emit h.ipv4
	tx m.pna_main_output_metadata_output_port
}


