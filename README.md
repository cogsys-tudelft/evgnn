### EvGNN: An Event-driven Graph Neural Network Accelerators for Edge Vision ###
This repository contains the entire EvGNN project, from algorithmic graph extraction and GNN training to hardware description files (RTL in SystemVerilog and C software for interfacing) and an example on-FGPA deployment. Each part of the work contains its own README file with its set of instructions, file structure and source codes. This repository consists of two main parts:

- The **algorithmic part** addressing the graph construction algorithm and the GNN training framework, available in /algo
- The **EvGNN-accelerator files** that implement the proposed algorithm in hardware, together with a Vivado demo, available in /hw 

When making use of any part of this work, we kindly request users to acknowledge the use of the present files, by citing the related published ArXiV's paper [**EvGNN: An Event-driven Graph Neural Network Accelerator for Edge Vision**] by Y. Yang, A. Kneip and C. Frenkel (BibTex format):

```
@article{YYang24,
  author    = {Yang, Yufeng and Kneip, Adrian and Frenkel, Charlotte},
  title     = {EvGNN: An Event-driven Graph Neural Network Accelerator for Edge Vision},
  booktitle = {arXiv:2404.19489 [cs.CV]},
  pages     = {1--12},
  year      = {2024}
}
```
# Licenses
Copyright (c) 2024, Yufeng Yang (CogSys Group)

All software files in the present repository are under the MIT License (https://opensource.org/license/mit)
All HDL files in the present repository are under the SolderPad Hardware License V2.1 (https://solderpad.org/licenses/SHL-2.1/)
