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

from aegnn.models.layer import MaxPoolingX
from .base.base import make_asynchronous, add_async_graph
from torch_geometric.data import Data
from typing import List, Optional, Tuple, Union
from torch import Tensor
from ..models.layer.grid import fixed_voxel_grid
from .base.utils import graph_changed_nodes, graph_new_nodes


def __graph_initialization(module: MaxPoolingX, x: torch.Tensor, pos: torch.Tensor, batch: Optional[torch.Tensor] = None) -> torch.Tensor:

    y, cluster = module.sync_forward(x, pos, batch)

    module.asy_graph = torch_geometric.data.Data(x=x.clone(), pos=pos, y=y)

    return module.asy_graph.y, cluster


def __graph_processing(module: MaxPoolingX, x: torch.Tensor, pos: torch.Tensor, batch: Optional[torch.Tensor] = None) -> torch.Tensor:

    module.asy_graph.x = torch.cat([module.asy_graph.x, x], dim=0)

    pos_all = module.pos_all[:, :2]
    pos_new = pos # also == module.pos_new[:, :2]
    idx_new = torch.tensor([module.idx_new], device=x.device)
    cluster_new = fixed_voxel_grid(pos_new, full_shape=module.full_shape, size=module.voxel_size, batch=None)

    old_max_x = module.asy_graph.y[cluster_new, :]
    new_x = x
    new_max_x = torch.maximum(old_max_x, new_x)
    module.asy_graph.y[cluster_new, :] = new_max_x
    cluster_changed = cluster_new

    return module.asy_graph.y, cluster_changed


def __check_support(module: MaxPoolingX):
    return True


def make_max_pool_x_asynchronous(module: MaxPoolingX, log_flops: bool = False, log_runtime: bool = False):
    """Module converter from synchronous to asynchronous & sparse processing for MaxPoolingX layers.
    When nodes added/changed by former layers, according to their location in grids, compute feature-wise max pooling (only at affected grids):

    ```
    module = MaxPoolingX(voxel_size, size, img_shape)
    module = make_max_pool_x_asynchronous(module)
    ```

    :param module: MaxPoolingX module to transform.
    :param log_flops: log flops of asynchronous update.
    :param log_runtime: log runtime of asynchronous update.
    """
    assert __check_support(module)
    module = add_async_graph(module, r=None, log_flops=log_flops, log_runtime=log_runtime)
    module.sync_forward = module.forward

    return make_asynchronous(module, __graph_initialization, __graph_processing)
