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
from torch_geometric.nn.pool import max_pool, voxel_grid
from typing import Callable, List, Optional, Tuple, Union
from torch import Tensor
from .grid import fixed_voxel_grid


class MaxPooling(torch.nn.Module):

    def __init__(self, size: Tensor, img_shape: Tensor = None, transform: Callable[[Data, ], Data] = None):
        super(MaxPooling, self).__init__()
        self.voxel_size = size
        self.full_shape = img_shape
        self.transform = transform

    def forward(self, x: torch.Tensor, pos: torch.Tensor, batch: Optional[torch.Tensor] = None,
                edge_index: Optional[torch.Tensor] = None, return_data_obj: bool = False
                ) -> Union[Tuple[torch.Tensor, torch.Tensor, torch.LongTensor, torch.Tensor, torch.Tensor], Data]:
        assert edge_index is not None, "edge_index must not be None"

        # cluster = voxel_grid(pos[:, :2], batch=batch, size=self.voxel_size)
        cluster = fixed_voxel_grid(pos[:, :2], full_shape=self.full_shape, size=self.voxel_size, batch=batch)
        data = Data(x=x, pos=pos, edge_index=edge_index, batch=batch)
        data = max_pool(cluster, data=data, transform=self.transform)  # transform for new edge attributes
        if return_data_obj:
            return data
        else:
            return data.x, data.pos, getattr(data, "batch"), data.edge_index, data.edge_attr

    def __repr__(self):
        return f"{self.__class__.__name__}(voxel_size={self.voxel_size})"
