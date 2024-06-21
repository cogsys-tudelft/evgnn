#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import torch


def normalize_time(ts: torch.Tensor, beta: float = 0.5e-5) -> torch.Tensor:
    """Normalizes the temporal component of the event pos by using beta re-scaling

    :param ts: time-stamps to normalize in microseconds [N].
    :param beta: re-scaling factor.
    """
    return (ts - torch.min(ts)) * beta
