onbreak {quit -force}
onerror {quit -force}

asim +access +r +m+top_bd  -L xilinx_vip -L xpm -L axi_infrastructure_v1_1_0 -L axi_vip_v1_1_13 -L zynq_ultra_ps_e_vip_v1_0_13 -L xil_defaultlib -L lib_cdc_v1_0_2 -L proc_sys_reset_v5_0_13 -L xlconstant_v1_1_7 -L smartconnect_v1_0 -L axi_register_slice_v2_1_27 -L generic_baseblocks_v2_1_0 -L fifo_generator_v13_2_7 -L axi_data_fifo_v2_1_26 -L axi_protocol_converter_v2_1_27 -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.top_bd xil_defaultlib.glbl

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure

do {top_bd.udo}

run

endsim

quit -force
