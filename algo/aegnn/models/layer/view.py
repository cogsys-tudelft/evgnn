#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import torch.nn as nn

class View(nn.Module):
    def __init__(self, *args):
        super(View, self).__init__()
        self.shape = args

    def forward(self, x):
        return x.view(self.shape)
