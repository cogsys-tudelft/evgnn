#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import logging

import torch.nn
import torch_geometric

from torch_geometric.nn.norm import BatchNorm
from torch_geometric.data import Data
from aegnn.models.layer import MaxPooling, MaxPoolingX

from aegnn.asyncronous.base.utils import find_new_edges, find_new_edges_cylinder

from aegnn.asyncronous.conv import make_conv_asynchronous
from aegnn.asyncronous.batch_norm import make_batch_norm_asynchronous
from aegnn.asyncronous.linear import make_linear_asynchronous
# from aegnn.asyncronous.max_pool import make_max_pool_asynchronous
from aegnn.asyncronous.max_pool_x import make_max_pool_x_asynchronous

from aegnn.asyncronous.flops import compute_flops_from_module
from aegnn.asyncronous.runtime import compute_runtime_from_module
from aegnn.asyncronous.base.callbacks import CallbackFactory

import pytorch_lightning as pl

from ..models.networks.my_conv import MyConv
from ..models.networks.my_fuse import MyConvBNReLU, qLinear


def make_model_asynchronous(module, r: float, grid_size=None, edge_attributes=None, max_num_neighbors = 32, self_loops = False,
                            log_flops: bool = False, log_runtime: bool = False, max_dt: int = 65535, **module_kwargs):
    """Module converter from synchronous to asynchronous & sparse processing for graph convolutional layers.
    By overwriting parts of the module asynchronous processing can be enabled without the need of re-learning
    and moving its weights and configuration. So, a convolutional layer can be converted by, for example:

    ```
    module = GCNConv(1, 2)
    module = make_conv_asynchronous(module)
    ```

    :param module: convolutional module to transform.
    :param grid_size: grid size (grid starting at 0, spanning to `grid_size`), >= `size` for pooling operations,
                      e.g. the image size.
    :param r: update radius around new events.
    :param edge_attributes: function for computing edge attributes (default = None), assumed to be the same over
                            all convolutional layers.
    :param log_flops: log flops of asynchronous update.
    :param log_runtime: log runtime of asynchronous update.
    """
    # assert isinstance(module, torch.nn.Module), "module must be a `torch.nn.Module`"

    if isinstance(module, pl.LightningModule):
        nn_model = module._modules['model']
        nn_layers = nn_model._modules
    elif isinstance(module, torch.nn.Module):
        nn_layers = module._modules
    else:
        raise TypeError(f'The type of module is {type(module)}, not a `torch.nn.Module` or a `pl.LightningModule`')
    conv_is_initial = True
    model_forward = module.forward
    module.asy_flops_log = [] if log_flops else None
    module.asy_runtime_log = [] if log_runtime else None
    callback_keys = []

    module.asy_graph = Data()
    module.asy_graph.pos = torch.tensor([], device=module.device).reshape(0,3)
    module.asy_graph.edge_index = torch.tensor([], device=module.device, dtype=torch.long).reshape(2,0)

    module.r = r
    module.max_num_neighbors = max_num_neighbors
    module.self_loops = self_loops
    module.max_dt = max_dt


    # Make all layers asynchronous that have an implemented asynchronous function. Otherwise use
    # the synchronous forward function.
    log_kwargs = dict(log_flops=log_flops, log_runtime=log_runtime)
    # for key, nn in module._modules.items():
    for key, nn in nn_layers.items():
        nn_class_name = nn.__class__.__name__
        logging.debug(f"Making layer {key} of type {nn_class_name} asynchronous")

        if nn_class_name in torch_geometric.nn.conv.__all__:
            nn_layers[key] = make_conv_asynchronous(nn, r=r, edge_attributes=edge_attributes, is_initial=conv_is_initial, **log_kwargs)
            conv_is_initial = False
            callback_keys.append(key)

        elif isinstance(nn, MyConv):
            nn_layers[key] = make_conv_asynchronous(nn, r=r, edge_attributes=edge_attributes, is_initial=conv_is_initial, **log_kwargs)
            conv_is_initial = False
            callback_keys.append(key)

        elif isinstance(nn, MyConvBNReLU):
            # nn_layers[key].to_fused()
            #! tmp disable for debug
            # assert nn_layers[key].fused is True
            # assert nn_layers[key].calibre is True
            # assert nn_layers[key].quantized is True

            nn_layers[key] = make_conv_asynchronous(nn, r=r, edge_attributes=edge_attributes, is_initial=conv_is_initial, **log_kwargs)
            conv_is_initial = False
            callback_keys.append(key)
        # elif isinstance(nn, MaxPooling):
        #     assert grid_size is not None, "grid size must be defined for pooling operations"
        #     nn_layers[key] = make_max_pool_asynchronous(nn, grid_size=grid_size, r=r, **log_kwargs)
        #     callback_keys.append(key)

        elif isinstance(nn, MaxPoolingX):
            nn_layers[key] = make_max_pool_x_asynchronous(nn, **log_kwargs)
            callback_keys.append(key)

        elif isinstance(nn, BatchNorm):
            nn_layers[key] = make_batch_norm_asynchronous(nn, **log_kwargs)
            # no callbacks required

        # elif isinstance(nn, torch.nn.Linear):
        #     nn_layers[key] = make_linear_asynchronous(nn, **log_kwargs)
        #     # callback_keys.append(key)

        elif isinstance(nn, qLinear):
            nn_layers[key] = make_linear_asynchronous(nn, **log_kwargs)

        else:
            logging.debug(f"Asynchronous module for {nn_class_name} is not implemented, using dense module.")

    # Set callbacks for overwriting attributes on subsequent network layers, from a function factory design.
    callback_index = 0
    cb_listeners = [nn_layers[key] for key in callback_keys]
    for key, nn in nn_layers.items():
        if key not in callback_keys or callback_index >= len(callback_keys) - 1:
            continue
        nn.asy_pass_attribute = CallbackFactory(cb_listeners[callback_index + 1:], log_name=nn.__repr__())
        callback_index += 1
    module.asy_pass_attribute = CallbackFactory(cb_listeners, log_name="base model")

    def async_forward(data: torch_geometric.data.Data, *args, **kwargs):
        pos_past = module.asy_graph.pos
        idx_new = module.asy_graph.num_nodes
        pos_new = data.pos
        pos_all = torch.cat([pos_past, pos_new], dim=0)
        module.asy_graph.pos = pos_all

        # edge_new = find_new_edges(idx_new, pos_new, pos_all, r=module.r, max_num_neighbors=module.max_num_neighbors, self_loops=module.self_loops)
        edge_new = find_new_edges_cylinder(idx_new, pos_new, pos_all, r=module.r, max_num_neighbors=module.max_num_neighbors, self_loops=module.self_loops, max_dt=module.max_dt)
        edge_all = torch.cat([module.asy_graph.edge_index, edge_new], dim=1)
        module.asy_graph.edge_index = edge_all # for debug

        # pass data to all listened layers (convs+maxpool)
        module.asy_pass_attribute('pos_new', pos_new)
        module.asy_pass_attribute('idx_new', idx_new)
        module.asy_pass_attribute('pos_all', pos_all)
        module.asy_pass_attribute('edge_new', edge_new)

        out = model_forward(data, *args, **kwargs)

        if module.asy_flops_log is not None:
            flops_count = [compute_flops_from_module(layer) for layer in nn_layers.values()]
            module.asy_flops_log.append(sum(flops_count))
            logging.debug(f"Model's modules update with overall {sum(flops_count)} flops")
        if module.asy_runtime_log is not None:
            runtimes = [compute_runtime_from_module(layer) for layer in nn_layers.values()]
            module.asy_runtime_log.append(sum(runtimes))
            logging.debug(f"Model's modules took overall {sum(runtimes)}s")
        return out

    module.forward = async_forward
    return module

def reset_async_module(module):

    if isinstance(module, pl.LightningModule):
        nn_model = module._modules['model']
        nn_layers = nn_model._modules
    elif isinstance(module, torch.nn.Module):
        nn_layers = module._modules
    else:
        raise TypeError(f'The type of module is {type(module)}, not a `torch.nn.Module` or a `pl.LightningModule`')

    module.asy_graph.pos = torch.tensor([], device=module.device).reshape(0,3)
    module.asy_graph.edge_index = torch.tensor([], device=module.device, dtype=torch.long).reshape(2,0)

    for key, nn in nn_layers.items():

        logging.debug(f"Reset asy_graph and asy_pos of layer {key}")

        if hasattr(nn_layers[key], 'asy_graph') and nn_layers[key].asy_graph is not None:
            nn_layers[key].asy_graph = None
        if hasattr(nn_layers[key], 'asy_pos') and nn_layers[key].asy_pos is not None:
            nn_layers[key].asy_pos = None

    return module

#TODO: for debug
def register_sync_graph(module, sync_graph):
    module.asy_pass_attribute('sync_graph', None)
    module.asy_pass_attribute('sync_graph', sync_graph)

__all__ = [
    "make_conv_asynchronous",
    "make_linear_asynchronous",
    "make_max_pool_asynchronous",
    "make_model_asynchronous"
]