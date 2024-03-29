




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

struct tcp_t {
	bit<16> srcPort
	bit<16> dstPort
	bit<32> seqNo
	bit<32> ackNo
	bit<8> dataOffset_res
	;oldname:cwr_ece_urg_ack_psh_rst_syn_fin
	bit<8> cwr_ece_urg_ack_psh_rst_syn_f0
	bit<16> window
	bit<16> checksum
	bit<16> urgentPtr
}

struct ipv4_fwd_arg_t {
	bit<48> ethernet_dst_addr
	bit<48> ethernet_src_addr
	bit<32> port_out
}

struct set_direction_arg_t {
	bit<8> dir
}

struct metadata_t {
	bit<32> pna_main_input_metadata_direction
	bit<32> pna_main_input_metadata_input_port
	bit<32> pna_main_output_metadata_output_port
	bit<8> MainControlT_tmp
	bit<8> MainControlT_tmp_0
	bit<8> MainControlT_tmp_1
	bit<32> MainControlT_tmp_3
	bit<32> MainControlT_tmp_4
	bit<16> MainControlT_tmp_5
	bit<16> MainControlT_tmp_6
	bit<8> MainControlT_tmp_7
	bit<32> MainControlT_tmp_8
	bit<32> MainControlT_tmp_9
	bit<16> MainControlT_tmp_10
	bit<16> MainControlT_tmp_11
	bit<8> MainControlT_tmp_12
	bit<32> MainControlT_tmp_13
	bit<32> MainControlT_tmp_14
	bit<16> MainControlT_tmp_15
	bit<16> MainControlT_tmp_16
	bit<8> MainControlT_tmp_17
	bit<32> MainControlT_tmp_18
	bit<32> MainControlT_tmp_19
	bit<16> MainControlT_tmp_20
	bit<16> MainControlT_tmp_21
	bit<8> MainControlT_tmp_22
	bit<32> MainControlT_reg_pos_one
	bit<32> MainControlT_reg_pos_two
	bit<8> MainControlT_reg_val_one
	bit<8> MainControlT_reg_val_two
	bit<8> MainControlT_direction
	bit<32> MainControlT_ip_addr1
	bit<32> MainControlT_ip_addr2
	bit<16> MainControlT_port1
	bit<16> MainControlT_port2
	bit<32> MainControlT_ip_addr1_0
	bit<32> MainControlT_ip_addr2_0
	bit<16> MainControlT_port1_0
	bit<16> MainControlT_port2_0
}
metadata instanceof metadata_t

header ethernet instanceof ethernet_t
header ipv4 instanceof ipv4_t
header tcp instanceof tcp_t

regarray bloom_filter size 0x1000 initval 0x0
regarray bloom_filter_0 size 0x1000 initval 0x0
regarray direction size 0x100 initval 0
action drop args none {
	drop
	return
}

action drop_1 args none {
	drop
	return
}

action ipv4_fwd args instanceof ipv4_fwd_arg_t {
	mov h.ethernet.src_addr t.ethernet_src_addr
	mov h.ethernet.dst_addr t.ethernet_dst_addr
	add h.ipv4.ttl 0xFF
	mov m.pna_main_output_metadata_output_port t.port_out
	return
}

action set_direction args instanceof set_direction_arg_t {
	mov m.MainControlT_direction t.dir
	return
}

table ipv4_table {
	key {
		h.ipv4.dst_addr exact
	}
	actions {
		ipv4_fwd
		drop
	}
	default_action drop args none const
	size 0x400
}


table check_ports {
	key {
		m.pna_main_input_metadata_input_port exact
	}
	actions {
		set_direction
		drop_1
	}
	default_action drop_1 args none 
	size 0x400
}


apply {
	rx m.pna_main_input_metadata_input_port
	regrd m.pna_main_input_metadata_direction direction m.pna_main_input_metadata_input_port
	extract h.ethernet
	jmpeq MAINPARSERIMPL_PARSE_IPV4 h.ethernet.ether_type 0x800
	jmp MAINPARSERIMPL_ACCEPT
	MAINPARSERIMPL_PARSE_IPV4 :	extract h.ipv4
	jmpeq MAINPARSERIMPL_PARSE_TCP h.ipv4.protocol 0x6
	jmp MAINPARSERIMPL_ACCEPT
	MAINPARSERIMPL_PARSE_TCP :	extract h.tcp
	MAINPARSERIMPL_ACCEPT :	jmpneq LABEL_END m.pna_main_input_metadata_direction 0x0
	table ipv4_table
	jmpnv LABEL_END h.tcp
	mov m.MainControlT_direction 0x0
	table check_ports
	jmpneq LABEL_FALSE_1 m.MainControlT_direction 0x1
	mov m.MainControlT_ip_addr1 h.ipv4.src_addr
	mov m.MainControlT_ip_addr2 h.ipv4.dst_addr
	mov m.MainControlT_port1 h.tcp.srcPort
	mov m.MainControlT_port2 h.tcp.dstPort
	mov m.MainControlT_tmp_3 m.MainControlT_ip_addr1
	mov m.MainControlT_tmp_4 m.MainControlT_ip_addr2
	mov m.MainControlT_tmp_5 m.MainControlT_port1
	mov m.MainControlT_tmp_6 m.MainControlT_port2
	mov m.MainControlT_tmp_7 h.ipv4.protocol
	hash jhash m.MainControlT_reg_pos_one  m.MainControlT_tmp_3 m.MainControlT_tmp_7
	and m.MainControlT_reg_pos_one 0xFFF
	add m.MainControlT_reg_pos_one 0x0
	mov m.MainControlT_tmp_8 m.MainControlT_ip_addr1
	mov m.MainControlT_tmp_9 m.MainControlT_ip_addr2
	mov m.MainControlT_tmp_10 m.MainControlT_port1
	mov m.MainControlT_tmp_11 m.MainControlT_port2
	mov m.MainControlT_tmp_12 h.ipv4.protocol
	hash crc32 m.MainControlT_reg_pos_two  m.MainControlT_tmp_8 m.MainControlT_tmp_12
	and m.MainControlT_reg_pos_two 0xFFF
	add m.MainControlT_reg_pos_two 0x0
	regrd m.MainControlT_reg_val_one bloom_filter m.MainControlT_reg_pos_one
	regrd m.MainControlT_reg_val_two bloom_filter_0 m.MainControlT_reg_pos_two
	jmpneq LABEL_TRUE_2 m.MainControlT_reg_val_one 0x1
	jmpneq LABEL_TRUE_2 m.MainControlT_reg_val_two 0x1
	jmp LABEL_END
	LABEL_TRUE_2 :	drop
	jmp LABEL_END
	LABEL_FALSE_1 :	mov m.MainControlT_tmp h.tcp.cwr_ece_urg_ack_psh_rst_syn_f0
	shr m.MainControlT_tmp 0x1
	mov m.MainControlT_tmp_0 m.MainControlT_tmp
	and m.MainControlT_tmp_0 0x1
	mov m.MainControlT_tmp_1 m.MainControlT_tmp_0
	and m.MainControlT_tmp_1 0x1
	jmpneq LABEL_END m.MainControlT_direction 0x0
	jmpneq LABEL_END m.MainControlT_tmp_1 0x1
	mov m.MainControlT_ip_addr1_0 h.ipv4.dst_addr
	mov m.MainControlT_ip_addr2_0 h.ipv4.src_addr
	mov m.MainControlT_port1_0 h.tcp.dstPort
	mov m.MainControlT_port2_0 h.tcp.srcPort
	mov m.MainControlT_tmp_13 m.MainControlT_ip_addr1_0
	mov m.MainControlT_tmp_14 m.MainControlT_ip_addr2_0
	mov m.MainControlT_tmp_15 m.MainControlT_port1_0
	mov m.MainControlT_tmp_16 m.MainControlT_port2_0
	mov m.MainControlT_tmp_17 h.ipv4.protocol
	hash jhash m.MainControlT_reg_pos_one  m.MainControlT_tmp_13 m.MainControlT_tmp_17
	and m.MainControlT_reg_pos_one 0xFFF
	add m.MainControlT_reg_pos_one 0x0
	mov m.MainControlT_tmp_18 m.MainControlT_ip_addr1_0
	mov m.MainControlT_tmp_19 m.MainControlT_ip_addr2_0
	mov m.MainControlT_tmp_20 m.MainControlT_port1_0
	mov m.MainControlT_tmp_21 m.MainControlT_port2_0
	mov m.MainControlT_tmp_22 h.ipv4.protocol
	hash crc32 m.MainControlT_reg_pos_two  m.MainControlT_tmp_18 m.MainControlT_tmp_22
	and m.MainControlT_reg_pos_two 0xFFF
	add m.MainControlT_reg_pos_two 0x0
	regwr bloom_filter m.MainControlT_reg_pos_one 0x1
	regwr bloom_filter_0 m.MainControlT_reg_pos_two 0x1
	LABEL_END :	emit h.ethernet
	emit h.ipv4
	jmpnv LABEL_END_4 h.tcp
	emit h.tcp
	LABEL_END_4 :	tx m.pna_main_output_metadata_output_port
}


