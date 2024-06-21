-makelib xcelium_lib/xilinx_vip -sv \
  "/data/cad/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi_vip_if.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/clk_vip_if.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/rst_vip_if.sv" \
-endlib
-makelib xcelium_lib/xpm -sv \
  "/data/cad/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
  "/data/cad/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
-endlib
-makelib xcelium_lib/xpm \
  "/data/cad/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib xcelium_lib/axi_infrastructure_v1_1_0 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/axi_vip_v1_1_13 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/ffc2/hdl/axi_vip_v1_1_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/zynq_ultra_ps_e_vip_v1_0_13 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/abef/hdl/zynq_ultra_ps_e_vip_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/top_bd/ip/top_bd_zynq_ultra_ps_e_0_0/sim/top_bd_zynq_ultra_ps_e_0_0_vip_wrapper.v" \
  "../../../bd/top_bd/ip/top_bd_top_0_0/sim/top_bd_top_0_0.v" \
-endlib
-makelib xcelium_lib/lib_cdc_v1_0_2 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/ef1e/hdl/lib_cdc_v1_0_rfs.vhd" \
-endlib
-makelib xcelium_lib/proc_sys_reset_v5_0_13 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/8842/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/top_bd/ip/top_bd_rst_ps8_0_99M_0/sim/top_bd_rst_ps8_0_99M_0.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/sim/bd_c78a.v" \
-endlib
-makelib xcelium_lib/xlconstant_v1_1_7 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/badb/hdl/xlconstant_v1_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_0/sim/bd_c78a_one_0.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_1/sim/bd_c78a_psr_aclk_0.vhd" \
-endlib
-makelib xcelium_lib/smartconnect_v1_0 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/f0b6/hdl/sc_util_v1_0_vl_rfs.sv" \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/be1f/hdl/sc_mmu_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_2/sim/bd_c78a_s00mmu_0.sv" \
-endlib
-makelib xcelium_lib/smartconnect_v1_0 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/4fd2/hdl/sc_transaction_regulator_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_3/sim/bd_c78a_s00tr_0.sv" \
-endlib
-makelib xcelium_lib/smartconnect_v1_0 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/637d/hdl/sc_si_converter_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_4/sim/bd_c78a_s00sic_0.sv" \
-endlib
-makelib xcelium_lib/smartconnect_v1_0 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/f38e/hdl/sc_axi2sc_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_5/sim/bd_c78a_s00a2s_0.sv" \
-endlib
-makelib xcelium_lib/smartconnect_v1_0 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/66be/hdl/sc_node_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_6/sim/bd_c78a_sarn_0.sv" \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_7/sim/bd_c78a_srn_0.sv" \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_8/sim/bd_c78a_sawn_0.sv" \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_9/sim/bd_c78a_swn_0.sv" \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_10/sim/bd_c78a_sbn_0.sv" \
-endlib
-makelib xcelium_lib/smartconnect_v1_0 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/9cc5/hdl/sc_sc2axi_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_11/sim/bd_c78a_m00s2a_0.sv" \
-endlib
-makelib xcelium_lib/smartconnect_v1_0 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/6bba/hdl/sc_exit_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib -sv \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/bd_0/ip/ip_12/sim/bd_c78a_m00e_0.sv" \
-endlib
-makelib xcelium_lib/smartconnect_v1_0 -sv \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/c012/hdl/sc_switchboard_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/axi_register_slice_v2_1_27 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/f0b4/hdl/axi_register_slice_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/top_bd/ip/top_bd_axi_smc_0/sim/top_bd_axi_smc_0.v" \
  "../../../bd/top_bd/ip/top_bd_ila_0_0/sim/top_bd_ila_0_0.v" \
-endlib
-makelib xcelium_lib/generic_baseblocks_v2_1_0 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/b752/hdl/generic_baseblocks_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/fifo_generator_v13_2_7 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/83df/simulation/fifo_generator_vlog_beh.v" \
-endlib
-makelib xcelium_lib/fifo_generator_v13_2_7 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/83df/hdl/fifo_generator_v13_2_rfs.vhd" \
-endlib
-makelib xcelium_lib/fifo_generator_v13_2_7 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/83df/hdl/fifo_generator_v13_2_rfs.v" \
-endlib
-makelib xcelium_lib/axi_data_fifo_v2_1_26 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/3111/hdl/axi_data_fifo_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/axi_protocol_converter_v2_1_27 \
  "../../../../sys_acc.gen/sources_1/bd/top_bd/ipshared/aeb3/hdl/axi_protocol_converter_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/top_bd/ip/top_bd_auto_pc_0/sim/top_bd_auto_pc_0.v" \
  "../../../bd/top_bd/sim/top_bd.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  glbl.v
-endlib
