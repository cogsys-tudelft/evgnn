#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
#
from typing import Callable, Optional, Union, Tuple

import torch
from torch import Tensor
from torch.nn import Linear
from torch.quantization.observer import PerChannelMinMaxObserver, MinMaxObserver

# from torch_geometric.nn.conv import PointNetConv
from torch_geometric.nn.conv import MessagePassing
from torch_geometric.nn.inits import reset
from torch_geometric.typing import (
    Adj,
    OptTensor,
    PairOptTensor,
    PairTensor
)
from torch_geometric.utils import add_self_loops, remove_self_loops

from torch_geometric.nn.norm import BatchNorm
from torch.nn.functional import relu

from aegnn.utils import Qtype


class MyConvBNReLU(MessagePassing):

    def __init__(self, in_channels: int, out_channels: int, bias: bool = False, pos_dim: int = 2, add_self_loops: bool = False, **kwargs):
        kwargs.setdefault('aggr', 'max')
        super().__init__(**kwargs)

        self.in_channels = in_channels
        self.out_channels = out_channels
        self.pos_dim = pos_dim

        self.local_nn = Linear(self.in_channels+self.pos_dim, self.out_channels, bias=bias)
        self.global_nn = None
        self.add_self_loops = add_self_loops

        self.bn = BatchNorm(out_channels, eps=1e-16)
        self.act = relu

        self.fused = False
        self.calibre = False
        self.quantized = False

        self.obs_x = MinMaxObserver(dtype=torch.quint8, qscheme=torch.per_channel_affine)
        self.obs_y = MinMaxObserver(dtype=torch.quint8, qscheme=torch.per_channel_affine)
        # w only observe out feature qparams
        # self.obs_w = MinMaxObserver(dtype=torch.qint8, qscheme=torch.per_channel_symmetric)
        self.obs_w = PerChannelMinMaxObserver(ch_axis=1, dtype=torch.qint8, qscheme=torch.per_channel_symmetric)
        self.obs_b = MinMaxObserver(dtype=torch.qint8, qscheme=torch.per_channel_symmetric)

        self.reset_parameters()

    def reset_parameters(self):
        reset(self.local_nn)
        reset(self.global_nn)
        self.bn.module.reset_running_stats()
        reset(self.bn)

    def to_fused(self):
        assert self.local_nn.bias is None
        w = self.bn.module.weight
        b = self.bn.module.bias
        m = self.bn.module.running_mean
        v = self.bn.module.running_var
        eps = self.bn.module.eps

        self.w_new = w / torch.sqrt(v+eps)
        self.b_new = b - self.w_new * m

        self.local_nn.weight = torch.nn.Parameter(self.local_nn.weight * self.w_new.view(-1,1))
        self.fused = True

    def get_quant_params(self, f_dtype: Qtype, w_dtype: Qtype):
        assert self.training is False
        if self.fused is False: self.to_fused()
        assert self.fused is True

        # # x: uint8
        # qx_min = 0
        # qx_max = 2**(f_bit) - 1

        # # y: uint8
        # qy_min = 0
        # qy_max = 2**(f_bit) - 1

        # # w: int8
        # qw_max = 2**(w_bit-1) - 1
        # qw_min = -qw_max


        qx_min = qy_min = f_dtype.min
        qx_max = qy_max = f_dtype.max

        qw_max = w_dtype.max
        qw_min = w_dtype.min


        x_max = self.obs_x.max_val
        self.x_scale = x_max / qx_max

        y_max = self.obs_y.max_val
        self.y_scale = y_max / qy_max

        wx_max = torch.max(self.obs_w.max_val[:-self.pos_dim])
        wx_min = torch.min(self.obs_w.min_val[:-self.pos_dim])
        wx_abs_max = torch.maximum(torch.abs(wx_max), torch.abs(wx_min))
        self.wx_scale = 2 * wx_abs_max / (qw_max - qw_min)

        wpos_pseudo_max = wx_abs_max * x_max
        self.wpos_scale = 2 * wpos_pseudo_max / (qw_max - qw_min)

        self.dpos_scale = 4.0 / (2**(f_dtype.bit+2))

        self.b_scale = self.x_scale * self.wx_scale

        self.M = (self.wx_scale * self.x_scale) / self.y_scale



        self.NM = 20 # 20bit shifting
        self.m  = torch.round(self.M * 2**(self.NM))


    @staticmethod
    def quant_tensor(real, scale, dtype: Union[str, Qtype]):
        if isinstance(dtype, str): dtype = Qtype(dtype)

        quant = torch.round(real/scale)
        quant = torch.clamp(quant, min=dtype.min, max=dtype.max)

        return quant

    @staticmethod
    def dequant_tensor(quant, scale):
        real = quant * scale
        return real



    def quant(self, f_dtype: Union[str, Qtype, Tuple[int, bool]], w_dtype: Union[str, Qtype, Tuple[int, bool]], b_dtype = 'int32'):
        assert self.calibre is True
        # self.f_bit = 8
        # self.w_bit = 8
        # self.b_bit = 32
        if isinstance(f_dtype, str):
            self.f_dtype = Qtype(f_dtype)
        elif isinstance(f_dtype, Tuple):
            self.f_dtype = Qtype(bit=f_dtype[0], signed=f_dtype[1])
        else:
            self.f_dtype = f_dtype

        if isinstance(w_dtype, str):
            self.w_dtype = Qtype(w_dtype)
        elif isinstance(w_dtype, Tuple):
            self.w_dtype = Qtype(bit=w_dtype[0], signed=w_dtype[1])
        else:
            self.w_dtype = w_dtype

        self.b_dtype = Qtype(b_dtype)
        self.dpos_dtype = Qtype(bit=self.f_dtype.bit+2, signed=self.f_dtype.signed)

        # self.get_quant_params(self.f_bit, self.w_bit)
        self.get_quant_params(self.f_dtype, self.w_dtype)


        self.w_real = self.local_nn.weight.clone().detach()
        self.wx_quant = self.quant_tensor(self.w_real[:,:-self.pos_dim], scale=self.wx_scale, dtype=self.w_dtype)
        self.wpos_quant = self.quant_tensor(self.w_real[:,-self.pos_dim:], scale=self.wpos_scale, dtype=self.w_dtype)
        self.w_quant = torch.cat([self.wx_quant, self.wpos_quant], dim=1)
        self.local_nn.weight = torch.nn.Parameter(self.w_quant)

        self.b_real = self.b_new.clone().detach()
        self.b_quant = self.quant_tensor(self.b_real, scale=self.b_scale, dtype=self.b_dtype)

        self.quantized = True
        pass



    def forward(self, x: Union[OptTensor, PairOptTensor],
                pos: Union[Tensor, PairTensor], edge_index: Adj) -> Tensor:


        if not self.fused:
            out_conv = self.propagate(edge_index, x=x, pos=pos[:, :2], size=None)
            out_bn = self.bn(out_conv)
            out = self.act(out_bn)
        else:
            if not self.quantized:
                self.obs_x(x)
                # only observe x for quant params. pos_x, pos_y are in range 0-120, naturally within uint8 range, so no need for quant
                out_conv_bn = self.propagate(edge_index, x=x, pos=pos[:, :2], size=None) + self.b_new
                out = self.act(out_conv_bn)
                self.obs_y(out)

                self.obs_w(self.local_nn.weight)
                self.obs_b(self.b_new.unsqueeze(0))

                self.calibre = True
            else:
                assert self.calibre is True
                out_conv_bn = self.propagate(edge_index, x=x, pos=pos[:, :2], size=None) + self.b_quant
                # out_conv_bn *= self.M
                out_conv_bn *= self.m  # m is int
                out_conv_bn = torch.floor(out_conv_bn * (2**(-self.NM)))  # pure shifting, using floor() instead of round() is to be closer to real hw impl
                out = self.act(out_conv_bn)

        return out


    def message(self, x_j: Optional[Tensor], pos_i: Tensor,
                pos_j: Tensor) -> Tensor:

        dpos = pos_j - pos_i  # no timestamp
        dpos = torch.abs(dpos)


        if not self.quantized:
            cat = torch.cat([x_j, dpos], dim=1)
            msg = self.local_nn(cat)
        else:
            # dpos = self.quant_tensor(dpos, scale=self.dpos_scale, bit=self.f_bit, signed=False)
            # dpos = self.quant_tensor(dpos, scale=self.dpos_scale, bit=self.f_bit+2, signed=False)
            dpos = self.quant_tensor(dpos, scale=self.dpos_scale, dtype=self.dpos_dtype)
            cat = torch.cat([x_j, dpos], dim=1)
            msg = self.local_nn(cat)

        return msg



class qLinear(torch.nn.Module):
    def __init__(self, in_features: int, out_features: int, bias: bool = False):
        super().__init__()

        self.in_features = in_features
        self.out_features = out_features
        self.bias = bias
        self.lin = torch.nn.Linear(self.in_features, self.out_features, self.bias)

        self.calibre = False
        self.quantized = False

        # self.f_bit = 8
        # self.w_bit = 8
        # self.b_bit = 32

        self.obs_in = MinMaxObserver(dtype=torch.quint8, qscheme=torch.per_tensor_affine)
        self.obs_out = MinMaxObserver(dtype=torch.qint8, qscheme=torch.per_tensor_symmetric)
        self.obs_w = MinMaxObserver(dtype=torch.qint8, qscheme=torch.per_tensor_symmetric)
        # no bias for now
        self.reset_parameters()

    def reset_parameters(self):
        reset(self.lin)

    def get_quant_params(self, in_dtype: Qtype, w_dtype: Qtype, out_dtype: Qtype):
        assert self.training is False

        # self.in_scale,_ = self.obs_in.calculate_qparams()
        # self.out_scale,_ = self.obs_out.calculate_qparams()
        # self.w_scale,_ = self.obs_w.calculate_qparams()

        self.in_scale = self.obs_in.max_val / in_dtype.max

        out_abs_max = torch.maximum(torch.abs(self.obs_out.max_val), torch.abs(self.obs_out.min_val))
        self.out_scale = 2 * out_abs_max / (out_dtype.max - out_dtype.min)

        w_abs_max = torch.maximum(torch.abs(self.obs_w.max_val), torch.abs(self.obs_w.min_val))
        self.w_scale = 2 * w_abs_max / (w_dtype.max - w_dtype.min)

        self.b_scale = self.in_scale * self.w_scale

        self.M = (self.in_scale * self.w_scale) / self.out_scale

        self.NM = 20 # 20bit shifting
        self.m  = torch.round(self.M * 2**(self.NM))

    def quant(self, in_dtype: Union[str, Qtype, Tuple[int, bool]], w_dtype: Union[str, Qtype, Tuple[int, bool]], out_dtype: Union[str, Qtype, Tuple[int, bool]],b_dtype = 'int32'):
        assert self.calibre is True

        if isinstance(in_dtype, str):
            self.in_dtype = Qtype(in_dtype)
        elif isinstance(in_dtype, Tuple):
            self.in_dtype = Qtype(bit=in_dtype[0], signed=in_dtype[1])
        else:
            self.in_dtype = in_dtype

        if isinstance(out_dtype, str):
            self.out_dtype = Qtype(out_dtype)
        elif isinstance(out_dtype, Tuple):
            self.out_dtype = Qtype(bit=out_dtype[0], signed=out_dtype[1])
        else:
            self.out_dtype = out_dtype

        if isinstance(w_dtype, str):
            self.w_dtype = Qtype(w_dtype)
        elif isinstance(w_dtype, Tuple):
            self.w_dtype = Qtype(bit=w_dtype[0], signed=w_dtype[1])
        else:
            self.w_dtype = w_dtype

        self.b_dtype = Qtype(b_dtype)

        # self.get_quant_params(self.f_bit, self.w_bit)
        self.get_quant_params(self.in_dtype, self.w_dtype, self.out_dtype)


        self.w_real = self.lin.weight.clone().detach()
        self.w_quant = MyConvBNReLU.quant_tensor(self.w_real, scale=self.w_scale, dtype=self.w_dtype)
        self.lin.weight = torch.nn.Parameter(self.w_quant)

        if self.bias:
            self.b_real = self.lin.bias.clone().detach()
            self.b_quant = MyConvBNReLU.quant_tensor(self.b_real, scale=self.b_scale, dtype=self.b_dtype)
            self.lin.bias = torch.nn.Parameter(self.b_quant)

        self.quantized = True

    def forward(self, x: torch.Tensor) -> Tensor:

        if not self.quantized:
            self.obs_in(x)
            out = self.lin(x)
            self.obs_out(out)
            self.obs_w(self.lin.weight)

            self.calibre = True
        else:
            assert self.calibre is True
            # out = self.lin(x) * self.m
            # out = torch.round(out * (2**(-self.NM)))  # pure shifting
            out = self.lin(x) # if it is the last layer of the network, then it's no need for quant scaling, since no further layers need its outputs

        return out

