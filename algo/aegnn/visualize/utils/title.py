#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import torch
from typing import Any


def make_title(title: Any, default: Any) -> str:
    def readable_string(x: Any) -> str:
        if type(x) == str:
            return x
        elif type(x) == torch.Tensor:
            return str(round(float(x), 2))
        elif type(x) == float:
            return str(round(x, 2))
        else:
            return x

    if title is not None:
        return readable_string(title)
    return readable_string(default)
