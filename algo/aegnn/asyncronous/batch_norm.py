#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import numpy as np
import torch
import torch_geometric

from torch_geometric.nn.norm import BatchNorm
from .base.base import make_asynchronous, add_async_graph
from .base.utils import graph_changed_nodes, graph_new_nodes


def __graph_initialization(module: BatchNorm, x: torch.Tensor) -> torch.Tensor:
    if module.training:
        mean = torch.mean(x, dim=0)
        var = torch.var(x, dim=0) + module.module.eps
    else:
        mean = module.module.running_mean
        var = module.module.running_var + module.module.eps

    y = ((x - mean) / torch.sqrt(var)) * module.module.weight + module.module.bias
    module.asy_graph = torch_geometric.data.Data(x=x, y=y, mean=mean, variance=var)

    # If required, compute the flops of the asynchronous update operation.
    # flops computation from https://github.com/sovrasov/flops-counter.pytorch/
    if module.asy_flops_log is not None:
        flops = int(np.prod(x.size()) * y.size()[-1])
        module.asy_flops_log.append(flops)
    return y


def __graph_processing(module: BatchNorm, x: torch.Tensor) -> torch.Tensor:
    """Batch norms only execute simple normalization operation, which already is very efficient. The overhead
    for looking for diff nodes would be much larger than computing the dense update.

    However, a new node slightly changes the feature distribution and therefore all activations, when calling
    the dense implementation. Therefore, we approximate the distribution with the initial distribution as
    num_new_events << num_initial_events.
    """

    # Identify the new added idx and changed idx
    x_new, idx_new = graph_new_nodes(module, x=x)
    _, idx_diff = graph_changed_nodes(module, x=x)
    idx_changed = torch.cat([idx_diff, idx_new])

    y = ((x[idx_changed, :] - module.asy_graph.mean) / torch.sqrt(module.asy_graph.variance)) * module.module.weight + module.module.bias
    out_channels = module.asy_graph.y.size()[-1]
    module.asy_graph.y = torch.cat([module.asy_graph.y, torch.zeros(x_new.size()[0], out_channels, device=x.device)])
    module.asy_graph.y[idx_changed, :] = y
    module.asy_graph.x = x

    # y = ((x - module.asy_graph.mean) / torch.sqrt(module.asy_graph.variance)) * module.module.weight + module.module.bias

    # If required, compute the flops of the asynchronous update operation.
    if module.asy_flops_log is not None:
        # flops = int(x.shape[0] * x.shape[1]) * 4
        # module.asy_flops_log.append(flops)
        raise NotImplementedError(f'FLOPS for async BN is under designing')
    return module.asy_graph.y


def __check_support(module):
    return True


def make_batch_norm_asynchronous(module: BatchNorm, log_flops: bool = False, log_runtime: bool = False):
    """Module converter from synchronous to asynchronous & sparse processing for batch norm (1d) layers.
    By overwriting parts of the module asynchronous processing can be enabled without the need of re-learning
    and moving its weights and configuration. So, a layer can be converted by, for example:

    ```
    module = BatchNorm(4)
    module = make_batch_norm_asynchronous(module)
    ```

    :param module: batch norm module to transform.
    :param log_flops: log flops of asynchronous update.
    :param log_runtime: log runtime of asynchronous update.
    """
    assert __check_support(module)
    module = add_async_graph(module, r=None, log_flops=log_flops, log_runtime=log_runtime)
    return make_asynchronous(module, __graph_initialization, __graph_processing)
