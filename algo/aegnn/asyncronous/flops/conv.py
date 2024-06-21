#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import torch
import torch_geometric

from typing import List

from ...models.networks.my_conv import MyConv
from ...models.networks.my_fuse import MyConvBNReLU


# /// Compute number of (floating) point operations ///
def compute_flops_conv(module, idx_new: List[int], idx_diff: List[int], edges: torch.LongTensor) -> int:
    assert type(idx_new) == type(idx_diff) == list
    flops = 0
    node_idx_unique, edge_count = torch.unique(edges, return_counts=True)
    node_idx_unique = node_idx_unique.detach().cpu().numpy()  # can be slow, just for flops evaluation
    edge_count = edge_count.detach().cpu().numpy()
    edge_count_dict = {ni: c for ni, c in zip(node_idx_unique, edge_count)}

    # Iterate over every different and every new node, and add the number of flops introduced
    # by the node to the overall flops count of the layer.
    for i in idx_new + idx_diff:
        if i not in edge_count_dict.keys():
            continue  # no edges from this node
        num_neighs_i = edge_count_dict[i]
        flops += __compute_ops_node(module, num_neighs=num_neighs_i)
    return flops

# /// Evaluate PPA metrics of the graph convolutional module for the selected hardware ///
def compute_PPA_conv(module, idx_new: List[int], idx_diff: List[int], edges: torch.LongTensor) -> int:
    # Sanity check
    assert type(idx_new) == type(idx_diff) == list
    # Local variables
    
    # Iterate over every new event and their neighbors
    # /// TBD with rethought data structures ///
    return -1;


# ///////////////////////////////// Internal functions ///////////////////////////////////

# Compute the total number of operations (FP or INT, irrespective)
def __compute_ops_node(module, dim, nb_data) -> int:
    ni = len(nb_data);  # to use the same notation as in the derivation
    c_in = dim[0];
    c_out = dim[1];

    # SplineConv
    if isinstance(module, torch_geometric.nn.conv.SplineConv):
        nm = module.dim
        np = module.weight.size()[0]
        d = module.degree
        return ni * c_out * c_in * (1 + np) + ni * (2 * d + 2 * nm * d - 1)
        # return ni * m_out * m_in * (1 + 2*np) + ni * (2 * d + 2 * nm * d - 1)
     # Simple PointNetConv
    elif isinstance(module,MyConv):
        return 2*ni*(c_in+2)*c_out;
    # Simple PointNetConv with folded BN and ReLU
    elif isinstance(module,MyConvBNReLU):
        return 2*ni*(c_in+2)*c_out+3*ni*c_out;
    else:
        module_type = type(module).__name__
        raise NotImplementedError(f"FLOPS computation not implemented for module type {module_type}")
        
# Compute number of cycles per node
def __compute_cycle_node(module, dim, nb_data):
    # --- Local variables ---
    # Dynamic network params
    ni     = len(nb_data);
    # Architecture type
    archType  = module.graphConv.archType;
    mvmUnit   = module.graphConv.arch.mvmArch;
    dMemCache  = module.graphConv.arch.dMemCache;
    dMemMain   = module.graphConv.arch.dMemMain;
    # Clock frequency
    fclk     = module.graphConv.fclk;
    # Bitwidth(s)
    sram_bw  = module.graphConv.sram_bw;
    dram_bw  = module.graphConv.dram_bw;
    # FP or INT
    dType    = module.graphConv.dType;
    # Pipelining
    doPipe   = module.graphConv.pipelining;
    
    # --- Architecture-dependent solutions ---
    # Clusters
    if(archType == "clusters"):
        raise NotImplementedError(f"Implementation of graph clustering not supported yet!")
    
    # Default: separated graph build and conv.
    else:
        # --- MatVec architecture (message passing) ---
        if(isinstance(module,MyConv) or isinstance(module,MyConvBNReLU)):
            # Get number of cycles
            n_cycles_mvm_all = mvmUnit.get_cycles(dim,ni,fclk,doPipe);
            n_cycles_mvm_tot = n_cycles_mvm_all[0];
        
        else:
            raise NotImplementedError(f"Number of cycles of selected conv. operation not yet supported!!")

        # --- Delay from aggregate and BAQ units --- (move inside mvm ?)
        n_cycles_aggr = ni*(1-doPipe);
        n_cycles_baq  = 1-doPipe;

        # --- Input-transfer overhead to/from cache/DRAM ---
        # Get cache hit vector for the event
        hit_data = dMemCache.cache_hit(nb_data);
        hit_frac = torch.mean(hit_data);
        # Cache memory data retrieval
        (n_cycles_dCache, delay_dCache) = hit_frac*dMemCache.get_cycles(dim,ni,fclk,doPipe);
        # Main memory data retrieval
        (n_cycles_dMain, delay_dMain)   = (1-hit_frac)*torch.ceil(dMemMain.get_delay()*fclk);

        # --- Weight-transfer overhead to/from cache/DRAM ---
        # // TBD //
        (n_cycles_wCache, delay_wCache) = (0,0);
        (n_cycles_wMain, delay_wMain)   = (0,0);
        
        # Get total number of cycles, depending on pipelining hypo. at the system level
        tot_cycles = n_cycles_dCache + n_cycles_dMain + n_cycles_wCache + n_cycles_wMain + n_cycles_mvm_tot;
    
    # Return total and partial number of cycles (reused during energy estimate)
    return (tot_cycles, n_cycles_dCache, n_cycles_dMain, n_cycles_wCache, n_cycles_wMain, n_cycles_mvm_all);
        
# Estimate energy cost per op
def __compute_energy_per_op(module, dim, n_cycles, sparsity_in = 0.0, sparsity_w = 0.0):
    # --- Local variables ---
    # Architecture type
    archType  = module.graphConv.archType;
    mvmUnit   = module.graphConv.arch.mvmArch;
    dMemCache  = module.graphConv.arch.dMemCache;
    dMemMain   = module.graphConv.arch.dMemMain;
    # Clock frequency
    fclk     = module.graphConv.fclk;
    # FP or INT
    dType    = module.graphConv.dType;
    # Number of cycles
    tot_cycles = n_cycles[0];
    n_cycles_dCache  = n_cycles[1];
    n_cycles_dMain   = n_cycles[2];
    n_cycles_wCache  = n_cycles[3];
    n_cycles_wMain   = n_cycles[4];
    n_cycles_mvm_all = n_cycles[5];

    # --- Architecture-dependent solutions ---
    # Clusters
    if(archType == "clusters"):
        raise NotImplementedError(f"Implementation of graph clustering not supported yet!")

    # Default: separated graph build and conv.
    else:
        # --- MatVec architecture (message passing) ---
        if(isinstance(module,MyConv) or isinstance(module,MyConvBNReLU)):
            # Get mvm energy
            energy_mvm  = mvmUnit.get_energy(dim,n_cycles_mvm_all)+tot_cycles/fclk*mvmUnit.get_leakage();
        else:
            raise NotImplementedError(f"Number of cycles of selected conv. operation not yet supported!!")

        # --- Input transfer energy overhead ---
        (_,e_cache_addr,e_cache_data) = dMemCache.get_energy();
        energy_dCache = (n_cycles_dCache + n_cycles_dMain)*e_cache_addr + n_cycles_dCache*e_cache_data + tot_cycles/fclk*dMemCache.get_leakage();
        energy_dMain  = n_cycles_dMain*dMemMain.get_energy() + tot_cycles/fclk*dMemMain.get_leakage();

        # --- Weight transfer energy overhead ---
        # // TBD //
        energy_wCache = 0;
        energy_wMain  = 0;

        # Return total energy (ignores leakage)
        energy_tot = energy_mvm + energy_dCache + energy_dMain + energy_wCache + energy_wMain;
    return energy_tot;    

# Estimate area
def __compute_area(module):
    # --- Local variables ---
    # Architecture type
    archType   = module.graphConv.archType;
    mvmUnit    = module.graphConv.arch.mvmArch;
    dMemCache  = module.graphConv.arch.dMemCache;
    dMemMain   = module.graphConv.arch.dMemMain;

    # --- Architecture-dependent area ---
    # Clusters
    if(archType == "clusters"):
        raise NotImplementedError(f"Implementation of graph clustering not supported yet!")

    # Default: separated graph build and conv.
    else:
        # --- MatVec architecture (message passing) ---
        if(isinstance(module,MyConv) or isinstance(module,MyConvBNReLU)):
            # Get mvm energy
            area_mvm  = mvmUnit.get_area();
        else:
            raise NotImplementedError(f"Number of cycles of selected conv. operation not yet supported!!")
        
        # --- Input transfer energy overhead ---
        area_dCache = dMemCache.get_area();
        area_dMain  = dMemMain.get_area();

        # --- Weight transfer energy overhead ---
        # // TBD //
        area_wCache = 0;
        area_wMain  = 0;

        # Return total area
        area_tot = area_mvm + area_dCache + area_dMain + area_wCache + area_wMain;
    return area_tot;