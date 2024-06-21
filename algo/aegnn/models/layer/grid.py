#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import torch

from torch_geometric.data import Data
from torch_geometric.nn.pool import max_pool_x, voxel_grid
from typing import List, Optional, Tuple, Union
from torch import Tensor


def fixed_voxel_grid(pos: Tensor, full_shape: Tensor, size: Tensor, batch: Tensor = None) -> Tensor:

    # device = torch.device('cuda') if torch.cuda.is_available() else torch.device('cpu')
    device = pos.device

    # params and check
    node_dims = pos.size(1)
    num_nodes = pos.size(0)
    assert len(full_shape) == node_dims
    assert len(size)==node_dims or len(size)==1

    # batch is None when a single sample
    if batch is None:
        batch = torch.zeros(num_nodes, device=device, dtype=torch.long)

    # counting how many grids in each dimension, upward ceiling
    num_grids = torch.squeeze(torch.ceil(torch.div(full_shape, size)))

    # according to node's pos, calculating its idx (x,y,z,...) in grids
    idx = torch.div(pos, size, rounding_mode='floor')
    # batch is natually the batch_size idx; transposition for later matmul
    idx = torch.cat([idx, batch.view(-1,1)], dim=1).T

    # calculating accumulated indices: for grids with (A,B,C,..) voxels idx, and point (x,y,z,...)
    # the accumulated indices are: (1,A,AB,ABC,...)
    acc_idx = torch.ones(node_dims+1, device=device)
    for i in range(node_dims):
        acc_idx[i+1] = acc_idx[i] * num_grids[i]

    # final index is x*1 + y*A + z*AB + ...., which equals to a vector times the idx
    cluster = (acc_idx @ idx).type(torch.long)

    return cluster