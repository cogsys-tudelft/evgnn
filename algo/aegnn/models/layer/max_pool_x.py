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
from torch_geometric.nn.pool import max_pool_x, voxel_grid, avg_pool_x
from typing import List, Optional, Tuple, Union
from torch import Tensor
from .grid import fixed_voxel_grid

from torch_scatter import scatter

class MaxPoolingX(torch.nn.Module):

    def __init__(self, voxel_size: Tensor, size: int, img_shape: Tensor = None):
        super(MaxPoolingX, self).__init__()
        self.voxel_size = voxel_size
        self.full_shape = img_shape
        self.size = size

    def sum_pool_x(self, cluster, x, batch, size: Optional[int] = None):
        def _sum_pool_x(cluster, x, size: Optional[int] = None):
            return scatter(x, cluster, dim=0, dim_size=size, reduce='sum')

        batch_size = int(batch.max().item()) + 1
        return _sum_pool_x(cluster, x, batch_size * size), None

    def forward(self, x: torch.Tensor, pos: torch.Tensor, batch: Optional[torch.Tensor] = None
                ) -> Union[Tuple[torch.Tensor, torch.Tensor, torch.LongTensor, torch.Tensor, torch.Tensor], Data]:
        # for a single sample
        if batch is None:
            batch = torch.zeros(pos.size(0), device=pos.device, dtype=torch.long)
        # cluster = voxel_grid(pos, batch=batch, size=self.voxel_size)
        cluster = fixed_voxel_grid(pos, full_shape=self.full_shape, size=self.voxel_size, batch=batch)
        x, _ = max_pool_x(cluster, x, batch, size=self.size)
        # x, _ = avg_pool_x(cluster, x, batch, size=self.size)
        # x, _ = self.sum_pool_x(cluster, x, batch, size=self.size)

        return x, cluster

    def __repr__(self):
        return f"{self.__class__.__name__}(voxel_size={self.voxel_size}, size={self.size})"
