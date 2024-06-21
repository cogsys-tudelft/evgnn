### EvGNN Hardware files ###
The present folder and sub-folders contain all HDL files to implement the EvGNN accelerator, as well as a baseline baremetal C software to run it. Below is a description of the sub-folders' content.

- axi: Implementation of AXI bus communication protocol (do not modify)

- graph_build: Hardware files related to graph construction (modify with custom GNN HW)

- graph_conv:  Hardware files related to graph convolution  (modify with custom GNN HW)

- include: Header files (adapt depending on HW needs)

- linear: Implementation of fully-connected layers (adapt depending on HW needs)

- max_pool_x: Hardware defintition of grid-based max-pooling (modify with custom GNN HW)

- mem_files: Contains the quantized model parameters files (change with target GNN model)

- sw: The baremetal C-code host software to execute the event-based GNN algo. (change with custom GNN algo)

- utils: Vivado FIFO instantiation file for FGPA mapping + other useful files (adapt depending on project)

## Modify accelerator driver files (C)
You can modify accelerator core files in `./sw/hugnet_ncars.c` and `./sw/hugnet_ncars.h`. Then sync and upgrade your files back to the `vitis_project`.

## Modify accelerator core files (Verilog)
You can modify accelerator core files in `src/aegnn_hw/*.v` or `*.sv`. Then upgrade your files back to the `vivado2022_2_project`.

Notice: when the 1st time opening `vivado2022_2_project`, please type the following command in the vivado tcl window:
```
set_property XPM_LIBRARIES {XPM_FIFO XPM_MEMORY} [current_project]
```

## Licenses
Copyright (c) 2024, Yufeng Yang (CogSys Group)

All HDL files in the present repository are under the SolderPad Hardware License V2.1 (https://solderpad.org/licenses/SHL-2.1/)
