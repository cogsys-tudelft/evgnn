#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import logging

import torch
import torch_geometric.nn.conv

from torch_geometric.data import Data
from torch_geometric.typing import Adj
from torch_geometric.utils import k_hop_subgraph, remove_self_loops, add_self_loops
from typing import List, Union
from torch_geometric.utils import to_undirected, degree
from torch_geometric.nn.conv import GCNConv, LEConv, PointNetConv, SplineConv

from .base.base import make_asynchronous, add_async_graph
from .base.utils import compute_edges, graph_changed_nodes, graph_new_nodes, cdist
from .flops import compute_flops_conv

from ..models.networks.my_conv import MyConv
from ..models.networks.my_fuse import MyConvBNReLU

from tqdm import tqdm
tprint = tqdm.write


def __graph_initialization(module, x: torch.Tensor, edge_index: Adj = None, edge_attr=None, **kwargs):

    if module.conv_type == 'fuse':
        y = module.sync_forward(x, pos=module.pos_all, edge_index=module.edge_new)


    module.asy_graph = Data(x=x, pos=module.pos_all, edge_index=module.edge_new, edge_attr=edge_attr, y=y)


    # If required, compute the flops of the asynchronous update operation. Therefore, sum the flops for each node
    # update, as they highly depend on the number of neighbors of this node.
    if module.asy_flops_log is not None:
        flops = __compute_flops(module, idx_new=edge_index.unique().long(), idx_diff=[], edges=edge_index)
        module.asy_flops_log.append(flops)


    return module.asy_graph.y

#TODO: remove all asy_graph processing to the outside
def __graph_processing(module, x: torch.Tensor, edge_index = None, edge_attr: torch.Tensor = None, **kwargs):
    """Asynchronous graph update for graph convolutional layer.

    After the initialization of the graph, only the nodes (and their receptive field) have to updated which either
    have changed (different features) or have been added. Therefore, for updating the graph we have to first
    compute the set of "diff" and "new" nodes to then do the convolutional message passing on this subgraph,
    and add the resulting residuals to the graph.

    :param x: graph nodes features.
    """

    logging.debug(f"Input graph with x = {x.shape} and pos = {module.pos_new.shape}")
    logging.debug(f"Internal graph = {module.asy_graph}")

    need_self_loops = getattr(module, 'add_self_loops', False)

    module.asy_graph.x = torch.cat([module.asy_graph.x, x], dim=0)

    if module.conv_type == 'fuse':
        y_update = module.sync_forward(x=module.asy_graph.x, pos=module.pos_all, edge_index=module.edge_new)
        y_new = y_update[module.idx_new, :].unsqueeze(0)
    module.asy_graph.y = torch.cat([module.asy_graph.y, y_new], dim=0)


    # If required, compute the flops of the asynchronous update operation. Therefore, sum the flops for each node
    # update, as they highly depend on the number of neighbors of this node.
    if module.asy_flops_log is not None:
        # flops = __compute_flops(module, idx_new=idx_new, idx_diff=idx_diff, edges=edge_index)
        # module.asy_flops_log.append(flops)
        raise NotImplementedError(f'flops needs to be impl')

    return y_new


def __compute_flops(module, idx_new: Union[torch.LongTensor, List[int]], idx_diff: Union[torch.LongTensor, List[int]],
                    edges: torch.LongTensor) -> int:
    if not isinstance(idx_new, list):
        idx_new = idx_new.detach().cpu().numpy().tolist()
    if not isinstance(idx_diff, list):
        idx_diff = idx_diff.detach().cpu().numpy().tolist()
    return compute_flops_conv(module, idx_new=idx_new, idx_diff=idx_diff, edges=edges)


def __check_support(module) -> bool:
    if isinstance(module, torch_geometric.nn.conv.GCNConv):
        if module.normalize is True:
            raise NotImplementedError("GCNConvs with normalization are not yet supported!")
            # pass
    elif isinstance(module, torch_geometric.nn.conv.SplineConv):
        if module.bias is not None:
            raise NotImplementedError("SplineConvs with bias are not yet supported!")
            # pass
        # if module.root is not None:
        # if hasattr(module, 'root') and module.root is not None:
        if module.root_weight is True:
            raise NotImplementedError("SplineConvs with root weight are not yet supported!")
    return True


def make_conv_asynchronous(module, r: float, edge_attributes=None, is_initial: bool = False,
                           log_flops: bool = False, log_runtime: bool = False):
    """Module converter from synchronous to asynchronous & sparse processing for graph convolutional layers.
    By overwriting parts of the module asynchronous processing can be enabled without the need of re-learning
    and moving its weights and configuration. So, a convolutional layer can be converted by, for example:

    ```
    module = GCNConv(1, 2)
    module = make_conv_asynchronous(module)
    ```

    :param module: convolutional module to transform.
    :param r: update radius around new events.
    :param edge_attributes: function for computing edge attributes (default = None).
    :param is_initial: layer initial layer of sequential or deeper (default = False).
    :param log_flops: log flops of asynchronous update.
    :param log_runtime: log runtime of asynchronous update.
    """
    assert __check_support(module)

    module = add_async_graph(module, r=r, log_flops=log_flops, log_runtime=log_runtime)
    module.asy_pos = None
    module.asy_is_initial = is_initial
    module.asy_edge_attributes = edge_attributes
    module.sync_forward = module.forward

    module.sync_graph = None #TODO: for debug

    if isinstance(module, SplineConv): module.conv_type = 'spline'
    elif isinstance(module, GCNConv): module.conv_type = 'gcn'
    elif isinstance(module, PointNetConv): module.conv_type = 'pointnet'
    elif isinstance(module, LEConv): module.conv_type = 'le'
    elif isinstance(module, MyConv): module.conv_type = 'my'
    elif isinstance(module, MyConvBNReLU): module.conv_type = 'fuse'
    else: module.conv_type = 'other'

    return make_asynchronous(module, __graph_initialization, __graph_processing)
