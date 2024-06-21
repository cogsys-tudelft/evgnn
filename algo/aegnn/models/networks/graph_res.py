#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
from collections import OrderedDict

import torch
import torch_geometric

from torch.nn import Linear
from torch.nn import Dropout
from torch.nn.functional import elu
from torch.nn.functional import relu
from torch_geometric.nn.conv import MessagePassing
from torch_geometric.nn.conv import SplineConv, GCNConv, LEConv, PointNetConv
from torch_geometric.nn.norm import BatchNorm
from torch_geometric.transforms import Cartesian, Distance
from torch_geometric.data import Data, Batch

from aegnn.models.layer import MaxPooling, MaxPoolingX

from .my_conv import MyConv
from .my_fuse import MyConvBNReLU, qLinear

from aegnn.utils import Qtype

import random
from torch_geometric.transforms import BaseTransform, Compose
from abc import abstractmethod
class BaseTransformPerSample(BaseTransform):
    @abstractmethod
    def __init__(self):
        pass

    @abstractmethod
    def transform_per_sample(self, data: Data):
        return data

    def __call__(self, batch: Batch):
        data_list = batch.to_data_list()
        transformed_data_list = []
        for data in data_list:
            transformed_data = self.transform_per_sample(data)
            transformed_data_list.append(transformed_data)
        transformed_batch = Batch.from_data_list(transformed_data_list)
        return transformed_batch


class RandomXFlip(BaseTransform):
    def __init__(self, p=0.5):
        self.p = p

    def __call__(self, data):
        if random.random() < self.p:
            pos = data.pos.clone()
            max,_ = pos.max(dim=0)
            max_x = max[0]
            pos[:,0] = -pos[:,0] + max_x
            data.pos = pos
        return data


class RandomShiftPerSample(BaseTransform):
    def __init__(self, p=0.5):
        self.p = p

    def sample_pos_trans(self, ori_pos):
        pos = ori_pos.clone()
        if random.random() < self.p:
            if pos.dim() == 1:
                pos = pos.unsqueeze(0)
            max,_ = pos.max(dim=0)
            x_max, y_max = max[0], max[1]
            dx = 119 - x_max
            dy = 99 - y_max
            rx = random.random()
            ry = random.random()
            sx = torch.floor(rx * dx)
            sy = torch.floor(ry * dy)
            pos[:,0] += sx
            pos[:,1] += sy
            pos = pos.squeeze()
        return pos

    def __call__(self, data):
        unique_samples = torch.unique(data.batch)
        for sample in unique_samples:
            # find which rows belong to which samples
            sample_indices = (data.batch == sample).nonzero().squeeze()

            # extract from data pos
            sample_pos = data.pos[sample_indices].clone()

            # bigmax,_ = sample_pos.max(dim=0)
            # x_bigmax, y_bigmax = bigmax[0], bigmax[1]

            tpos = self.sample_pos_trans(sample_pos)
            data.pos[sample_indices] = tpos
        return data


class RandomSubgraph(BaseTransformPerSample):
    def __init__(self, num_samples: int, p: float = 0.5):
        self.num_samples = num_samples
        self.p = p

    def transform_per_sample(self, data: Data):
        if (random.random() < self.p) and (data.label[0] == 'car'):
            real_num_samples = max(1, min(data.num_nodes, self.num_samples))  # real_num_samples = min(num_nodes, num_samples), and >= 1
            subset = random.sample(range(data.num_nodes), real_num_samples)
            sorted_unique_subset = torch.tensor(subset).sort().values
            data_subgraph = data.subgraph(sorted_unique_subset).clone()
        else:
            data_subgraph = data
        return data_subgraph

class RandomRangeSubgraph(BaseTransformPerSample):
    def __init__(self, range_start: int, range_end: int, p: float = 0.5):
        self.range_start = range_start
        self.range_end = range_end
        self.p = p

    def transform_per_sample(self, data: Data):
        if (random.random() < self.p) \
            and (data.label[0] == 'car') \
            and (data.num_nodes >= self.range_start) \
            and (data.num_nodes < self.range_end):

            bias = 500  # no sample has nodes less than 500
            scale = self.range_start - bias
            num_samples = int(random.random() * scale) + bias  # choose a random num samples that < range_start
            subset = random.sample(range(data.num_nodes), num_samples)
            sorted_unique_subset = torch.tensor(subset).sort().values
            data_subgraph = data.subgraph(sorted_unique_subset).clone()
        else:
            data_subgraph = data
        return data_subgraph


class GraphRes(torch.nn.Module):

    def __init__(self, dataset, input_shape: torch.Tensor, num_outputs: int, pooling_size=(16, 12),
                 bias: bool = False, root_weight: bool = False, act: str = 'relu', grid_div: int = 8, conv_type: str = 'fuse', distill: bool = False, character: str = None, drop: float = 0.0):
        super(GraphRes, self).__init__()
        assert len(input_shape) == 3, "invalid input shape, should be (img_width, img_height, dim)"
        dim = int(input_shape[-1])

        # TODO: more elegant way to use pl "self.device"
        device = torch.device('cuda') if torch.cuda.is_available() else torch.device('cpu')
        self.device = device
        self.pooling_size = torch.tensor(pooling_size, device=self.device)
        self.input_shape = input_shape.to(self.device)

        if act == 'relu':
            self.act = relu
        elif act == 'elu':
            self.act = elu
        else:
            raise ValueError('Unsupported activation function')

        self.fused = False
        self.quantized = False

        self.conv_type = conv_type

        self.distill = distill
        self.character = character

        # self.trans = RandomXFlip(p = 0.5)
        # self.trans = torch_geometric.transforms.Compose([RandomXFlip(p = 0.5), RandomShiftPerSample(p = 0.5)])
        self.trans = Compose([
            RandomRangeSubgraph(range_start=1125, range_end=1375, p=0.45),
            RandomRangeSubgraph(range_start=3250, range_end=3500, p=0.5),
            RandomSubgraph(num_samples=500, p=0.023),
            RandomSubgraph(num_samples=1000, p=0.012)
        ])

        if not self.distill:  # normal model
            if self.conv_type == 'fuse':
                n = [1, 16, 32, 32, 32]
                # print('Fuse mode: conv, bn, relu')
                self.fuse1 = MyConvBNReLU(n[0], n[1])
                self.fuse2 = MyConvBNReLU(n[1], n[2])
                self.fuse3 = MyConvBNReLU(n[2], n[3])
                self.fuse4 = MyConvBNReLU(n[3], n[4])

                pooling_outputs = self.fuse4.out_channels
                # pooling_outputs = self.fuse2.out_channels
                num_grids = 8*7
                pooling_dm_dims = torch.tensor([16.,16.], device=self.device)
                self.pool = MaxPoolingX(pooling_dm_dims, size=num_grids, img_shape=self.input_shape[:2])
                self.fc = qLinear(pooling_outputs * num_grids, out_features=num_outputs, bias=False)
                # self.fc = torch.nn.Sequential(
                #     qLinear(pooling_outputs * num_grids, out_features=512, bias=False),
                #     torch.nn.ReLU(),
                #     qLinear(512, out_features=num_outputs, bias=False)
                # )
                # self.fc.in_features = pooling_outputs * num_grids

                self.drop = Dropout(p = drop)



            elif self.conv_type == 'ori_aegnn':
                kernel_size = 2
                n = [1, 8, 16, 16, 16, 32, 32, 32, 32]
                pooling_outputs = 32

                self.conv1 = SplineConv(n[0], n[1], dim=dim, kernel_size=kernel_size, bias=bias, root_weight=root_weight)
                self.norm1 = BatchNorm(in_channels=n[1])
                self.conv2 = SplineConv(n[1], n[2], dim=dim, kernel_size=kernel_size, bias=bias, root_weight=root_weight)
                self.norm2 = BatchNorm(in_channels=n[2])

                self.conv3 = SplineConv(n[2], n[3], dim=dim, kernel_size=kernel_size, bias=bias, root_weight=root_weight)
                self.norm3 = BatchNorm(in_channels=n[3])
                self.conv4 = SplineConv(n[3], n[4], dim=dim, kernel_size=kernel_size, bias=bias, root_weight=root_weight)
                self.norm4 = BatchNorm(in_channels=n[4])

                self.conv5 = SplineConv(n[4], n[5], dim=dim, kernel_size=kernel_size, bias=bias, root_weight=root_weight)
                self.norm5 = BatchNorm(in_channels=n[5])
                # self.pool5 = MaxPooling(self.pooling_size, transform=Cartesian(norm=True, cat=False))
                self.pool5 = MaxPooling(self.pooling_size, img_shape=self.input_shape[:2], transform=Cartesian(norm=True, cat=False))

                self.conv6 = SplineConv(n[5], n[6], dim=dim, kernel_size=kernel_size, bias=bias, root_weight=root_weight)
                self.norm6 = BatchNorm(in_channels=n[6])
                self.conv7 = SplineConv(n[6], n[7], dim=dim, kernel_size=kernel_size, bias=bias, root_weight=root_weight)
                self.norm7 = BatchNorm(in_channels=n[7])

                # self.pool7 = MaxPoolingX(input_shape[:2] // 4, size=16)
                pooling_dm_dims = torch.tensor([30.,25.], device=self.device)
                self.pool7 = MaxPoolingX(pooling_dm_dims, size=16, img_shape=self.input_shape[:2])
                self.fc = Linear(pooling_outputs * 16, out_features=num_outputs, bias=bias)

            elif self.conv_type == 'gcn':
                n = [1, 8, 16, 16, 16, 32, 32, 32, 32]
                pooling_outputs = 32

                self.conv1 = GCNConv(n[0], n[1])
                self.norm1 = BatchNorm(in_channels=n[1])
                self.conv2 = GCNConv(n[1], n[2])
                self.norm2 = BatchNorm(in_channels=n[2])

                self.conv3 = GCNConv(n[2], n[3])
                self.norm3 = BatchNorm(in_channels=n[3])
                self.conv4 = GCNConv(n[3], n[4])
                self.norm4 = BatchNorm(in_channels=n[4])

                self.conv5 = GCNConv(n[4], n[5])
                self.norm5 = BatchNorm(in_channels=n[5])
                # self.pool5 = MaxPooling(self.pooling_size, transform=Cartesian(norm=True, cat=False))
                self.pool5 = MaxPooling(self.pooling_size, img_shape=self.input_shape[:2], transform=Cartesian(norm=True, cat=False))

                self.conv6 = GCNConv(n[5], n[6])
                self.norm6 = BatchNorm(in_channels=n[6])
                self.conv7 = GCNConv(n[6], n[7])
                self.norm7 = BatchNorm(in_channels=n[7])

                # self.pool7 = MaxPoolingX(input_shape[:2] // 4, size=16)
                pooling_dm_dims = torch.tensor([30.,25.], device=self.device)
                self.pool7 = MaxPoolingX(pooling_dm_dims, size=16, img_shape=self.input_shape[:2])
                self.fc = Linear(pooling_outputs * 16, out_features=num_outputs, bias=bias)

            elif self.conv_type == 'simple_pointnet':
                n = [1, 8, 16, 16, 16, 32, 32, 32, 32]
                pooling_outputs = 32

                self.conv1 = MyConvBNReLU(n[0], n[1])
                self.conv2 = MyConvBNReLU(n[1], n[2])

                self.conv3 = MyConvBNReLU(n[2], n[3])
                self.conv4 = MyConvBNReLU(n[3], n[4])

                self.conv5 = MyConvBNReLU(n[4], n[5])
                # self.pool5 = MaxPooling(self.pooling_size, transform=Cartesian(norm=True, cat=False))
                self.pool5 = MaxPooling(self.pooling_size, img_shape=self.input_shape[:2], transform=Cartesian(norm=True, cat=False))

                self.conv6 = MyConvBNReLU(n[5], n[6])
                self.conv7 = MyConvBNReLU(n[6], n[7])

                # self.pool7 = MaxPoolingX(input_shape[:2] // 4, size=16)
                pooling_dm_dims = torch.tensor([30.,25.], device=self.device)
                self.pool7 = MaxPoolingX(pooling_dm_dims, size=16, img_shape=self.input_shape[:2])
                self.fc = Linear(pooling_outputs * 16, out_features=num_outputs, bias=bias)

            else:
                raise ValueError(f"Other convolution type: {self.conv_type} is not supported")





        elif self.distill: # knowledge distillation
            if self.character == 'teacher':
                # Set dataset specific hyper-parameters.
                if dataset == "ncars":
                    kernel_size = 2
                    n = [1, 8, 16, 16, 16, 32, 32, 32, 32]
                    pooling_outputs = n[-1]
                elif dataset == "ncaltech101" or dataset == "gen1":
                    kernel_size = 8
                    n = [1, 16, 32, 32, 32, 128, 128, 128]
                    pooling_outputs = 128
                else:
                    raise NotImplementedError(f"No model parameters for dataset {dataset}")


                if self.conv_type == 'spline':
                    self.conv1 = SplineConv(1, 16, dim=dim, kernel_size=kernel_size, bias=False, root_weight=False)
                    self.conv2 = SplineConv(n[4], n[5], dim=dim, kernel_size=kernel_size, bias=False, root_weight=False)
                    self.conv3 = SplineConv(n[5], n[6], dim=dim, kernel_size=kernel_size, bias=False, root_weight=False)
                    self.conv4 = SplineConv(n[6], n[7], dim=dim, kernel_size=kernel_size, bias=False, root_weight=False)
                elif self.conv_type == 'gcn':
                    self.conv1 = GCNConv(1, 16, normalize=False, bias=False)
                    self.conv2 = GCNConv(n[4], n[5], normalize=False, bias=False)
                    self.conv3 = GCNConv(n[5], n[6], normalize=False, bias=False)
                    self.conv4 = GCNConv(n[6], n[7], normalize=False, bias=False)
                elif self.conv_type == 'le':
                    self.edge_weight_func = Distance(cat = True)
                    self.conv1 = LEConv(1, 16, bias=False)
                    self.conv2 = LEConv(n[4], n[5], bias=False)
                    self.conv3 = LEConv(n[5], n[6], bias=False)
                    self.conv4 = LEConv(n[6], n[7], bias=False)
                elif self.conv_type == 'pointnet':
                    self.conv1 = PointNetConv(local_nn=Linear(1+3, 16), global_nn=Linear(16, 16))
                    self.conv2 = PointNetConv(local_nn=Linear(n[4]+3, n[5]), global_nn=Linear(n[5], n[5]))
                    self.conv3 = PointNetConv(local_nn=Linear(n[5]+3, n[6]), global_nn=Linear(n[6], n[6]))
                    self.conv4 = PointNetConv(local_nn=Linear(n[6]+3, n[7]), global_nn=Linear(n[7], n[7]))
                elif self.conv_type == 'pointnet_single':
                    self.conv1 = PointNetConv(local_nn=Linear(1+3, 16, bias=False), global_nn=None, add_self_loops=False)
                    self.conv2 = PointNetConv(local_nn=Linear(n[4]+3, n[5], bias=False), global_nn=None, add_self_loops=False)
                    self.conv3 = PointNetConv(local_nn=Linear(n[5]+3, n[6], bias=False), global_nn=None, add_self_loops=False)
                    self.conv4 = PointNetConv(local_nn=Linear(n[6]+3, n[7], bias=False), global_nn=None, add_self_loops=False)
                elif self.conv_type == 'my':
                    self.conv1 = MyConv(1, 16)
                    self.conv2 = MyConv(n[4], n[5])
                    self.conv3 = MyConv(n[5], n[6])
                    self.conv4 = MyConv(n[6], n[7])


                if self.conv_type != 'fuse':
                    self.norm1 = BatchNorm(in_channels=16)
                    self.norm2 = BatchNorm(in_channels=n[5])
                    self.norm3 = BatchNorm(in_channels=n[6])
                    self.norm4 = BatchNorm(in_channels=n[7])
                elif self.conv_type == 'fuse':
                    # print('Fuse mode: conv, bn, relu')
                    self.fuse1 = MyConvBNReLU(1, 16)
                    self.fuse2 = MyConvBNReLU(n[4], n[5])
                    self.fuse3 = MyConvBNReLU(n[5], n[6])
                    self.fuse4 = MyConvBNReLU(n[6], n[7])
                else:
                    raise ValueError(f"Unkown convolution type: {self.conv_type}")

                num_grids = 8*7
                pooling_dm_dims = torch.tensor([16.,16.], device=self.device)
                self.pool = MaxPoolingX(pooling_dm_dims, size=num_grids, img_shape=self.input_shape[:2])

                self.hidden = 128
                self.fc = torch.nn.Sequential(OrderedDict([
                    ('fc1', qLinear(pooling_outputs * num_grids, out_features=self.hidden*2, bias=True)),
                    ('fc_bn1', torch.nn.BatchNorm1d(num_features=self.hidden*2)),
                    ('fc_relu1', torch.nn.ReLU()),
                    ('fc2', qLinear(self.hidden*2, out_features=self.hidden, bias=True)),
                    ('fc_bn2', torch.nn.BatchNorm1d(num_features=self.hidden)),
                    ('fc_relu2', torch.nn.ReLU()),
                    ('fc3', qLinear(self.hidden, out_features=num_outputs, bias=False))
                ]))
                self.fc.in_features = self.fc.fc1.in_features


            elif self.character == 'student':
                n = [1, 16, 32, 32, 32]
                if self.conv_type == 'fuse':
                    # print('Fuse mode: conv, bn, relu')
                    self.fuse1 = MyConvBNReLU(n[0], n[1])
                    self.fuse2 = MyConvBNReLU(n[1], n[2])
                    self.fuse3 = MyConvBNReLU(n[2], n[3])
                    self.fuse4 = MyConvBNReLU(n[3], n[4])
                else:
                    raise ValueError(f"Other convolution type: {self.conv_type} is not supported in student model")

                pooling_outputs = self.fuse4.out_channels
                # pooling_outputs = self.fuse2.out_channels

                num_grids = 8*7
                pooling_dm_dims = torch.tensor([16.,16.], device=self.device)
                self.pool = MaxPoolingX(pooling_dm_dims, size=num_grids, img_shape=self.input_shape[:2])
                self.fc = qLinear(pooling_outputs * num_grids, out_features=num_outputs, bias=False)

            else:
                raise ValueError("Assign a teacher/student character for distillation training")


    def convs(self, layer, data):
        if self.conv_type == 'spline':
            return layer(data.x, data.edge_index, data.edge_attr)
        elif self.conv_type == 'gcn':
            return layer(data.x, data.edge_index)
        elif self.conv_type == 'le':
            return layer(data.x, data.edge_index, data.edge_weight)
        elif self.conv_type == 'pointnet' or self.conv_type == 'pointnet_single' or self.conv_type == 'my':
            return layer(x=data.x, pos=data.pos, edge_index=data.edge_index)
        else:
            raise ValueError(f"Unkown convolution type: {self.conv_type}")

    def to_fused(self):
        for module in self.children():
            if isinstance(module, MyConvBNReLU):
                module.to_fused()
        self.fused = True
        return self

    def quant(self,*,conv_f_dtype='uint8', conv_w_dtype='int8', fc_in_dtype='uint8', fc_w_dtype='int8', fc_out_dtype='int8'):
        for module in self.children():
            if isinstance(module, MyConvBNReLU):
                module.quant(f_dtype=conv_f_dtype, w_dtype=conv_w_dtype)
            elif isinstance(module, qLinear):
                module.quant(in_dtype=fc_in_dtype, w_dtype=fc_w_dtype, out_dtype=fc_out_dtype)
        self.quantized = True
        return self

    def forward(self, data: torch_geometric.data.Batch) -> torch.Tensor:
        # assert data.x.device.type == data.pos.device.type == data.edge_index.device.type == self.device.type
        if self.training is True:
            with torch.no_grad():
                data = self.trans(data)
                # pass


        if not self.distill:
            if self.conv_type == 'fuse':
                if not self.quantized:
                    data.x = self.fuse1(x=data.x, pos=data.pos, edge_index=data.edge_index) # no timestamp
                    data.x = self.fuse2(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse3(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse4(x=data.x, pos=data.pos, edge_index=data.edge_index)
                else:
                    data.x = MyConvBNReLU.quant_tensor(data.x, scale=self.fuse1.x_scale, dtype=self.fuse1.f_dtype)
                    data.x = self.fuse1(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse2(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse3(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse4(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    # data.x = MyConvBNReLU.dequant_tensor(data.x, scale=self.fuse4.y_scale)

                x,_ = self.pool(data.x, pos=data.pos[:, :2], batch=data.batch)
                x = x.view(-1, self.fc.in_features) # x.shape = [batch_size, num_grids*num_last_hidden_features]
                #x = self.drop(x)

                if not self.quantized:
                    output = self.fc(x)
                else:
                    q_output = self.fc(x)
                    output = q_output

                # output = self.drop(output)

            elif self.conv_type == 'ori_aegnn':
                data.edge_attr[:,2] = 0.5  # if cylinder + aegnn struct, use it
                # Reason: original AEGNN shrink timestamp too much, so the dt around 1e-7. After Cartesian, each one will +0.5. So it is close to 0.5 constant
                data.x = self.act(self.conv1(data.x, data.edge_index, data.edge_attr))
                data.x = self.norm1(data.x)
                data.x = self.act(self.conv2(data.x, data.edge_index, data.edge_attr))
                data.x = self.norm2(data.x)

                x_sc = data.x.clone()
                data.x = self.act(self.conv3(data.x, data.edge_index, data.edge_attr))
                data.x = self.norm3(data.x)
                data.x = self.act(self.conv4(data.x, data.edge_index, data.edge_attr))
                data.x = self.norm4(data.x)
                data.x = data.x + x_sc

                data.x = self.act(self.conv5(data.x, data.edge_index, data.edge_attr))
                data.x = self.norm5(data.x)
                data = self.pool5(data.x, pos=data.pos, batch=data.batch, edge_index=data.edge_index, return_data_obj=True)
                data.edge_attr[:,2] = 0.5  # if cylinder + aegnn struct, use it

                x_sc = data.x.clone()
                data.x = self.act(self.conv6(data.x, data.edge_index, data.edge_attr))
                data.x = self.norm6(data.x)
                data.x = self.act(self.conv7(data.x, data.edge_index, data.edge_attr))
                data.x = self.norm7(data.x)
                data.x = data.x + x_sc

                x,_ = self.pool7(data.x, pos=data.pos[:, :2], batch=data.batch)
                x = x.view(-1, self.fc.in_features)
                output = self.fc(x)

            elif self.conv_type == 'gcn':
                data.x = self.act(self.conv1(data.x, data.edge_index))
                data.x = self.norm1(data.x)
                data.x = self.act(self.conv2(data.x, data.edge_index))
                data.x = self.norm2(data.x)

                x_sc = data.x.clone()
                data.x = self.act(self.conv3(data.x, data.edge_index))
                data.x = self.norm3(data.x)
                data.x = self.act(self.conv4(data.x, data.edge_index))
                data.x = self.norm4(data.x)
                data.x = data.x + x_sc

                data.x = self.act(self.conv5(data.x, data.edge_index))
                data.x = self.norm5(data.x)
                data = self.pool5(data.x, pos=data.pos, batch=data.batch, edge_index=data.edge_index, return_data_obj=True)

                x_sc = data.x.clone()
                data.x = self.act(self.conv6(data.x, data.edge_index))
                data.x = self.norm6(data.x)
                data.x = self.act(self.conv7(data.x, data.edge_index))
                data.x = self.norm7(data.x)
                data.x = data.x + x_sc

                x,_ = self.pool7(data.x, pos=data.pos[:, :2], batch=data.batch)
                x = x.view(-1, self.fc.in_features)
                output = self.fc(x)

            elif self.conv_type == 'simple_pointnet':
                data.x = self.conv1(x=data.x, pos=data.pos, edge_index=data.edge_index)
                data.x = self.conv2(x=data.x, pos=data.pos, edge_index=data.edge_index)

                x_sc = data.x.clone()
                data.x = self.conv3(x=data.x, pos=data.pos, edge_index=data.edge_index)
                data.x = self.conv4(x=data.x, pos=data.pos, edge_index=data.edge_index)
                data.x = data.x + x_sc

                data.x = self.conv5(x=data.x, pos=data.pos, edge_index=data.edge_index)
                data = self.pool5(data.x, pos=data.pos, batch=data.batch, edge_index=data.edge_index, return_data_obj=True)

                x_sc = data.x.clone()
                data.x = self.conv6(x=data.x, pos=data.pos, edge_index=data.edge_index)
                data.x = self.conv7(x=data.x, pos=data.pos, edge_index=data.edge_index)
                data.x = data.x + x_sc

                x,_ = self.pool7(data.x, pos=data.pos[:, :2], batch=data.batch)
                x = x.view(-1, self.fc.in_features)
                output = self.fc(x)

        elif self.distill:
            if self.character == 'teacher':  # teacher model

                assert self.conv_type == 'le' \
                    or self.conv_type == 'spline' \
                    or self.conv_type == 'gcn' \
                    or self.conv_type == 'pointnet' \
                    or self.conv_type == 'pointnet_single' \
                    or self.conv_type == 'my' \
                    or self.conv_type == 'fuse'


                if self.conv_type == 'le' :
                    data = self.edge_weight_func(data)
                    data.edge_weight = data.edge_attr[:,-1]
                    data.edge_attr = data.edge_attr[:, :-1]

                if self.conv_type != 'fuse':
                    data.x = self.convs(self.conv1, data)
                    data.x = self.norm1(data.x)
                    data.x = self.act(data.x)

                    data.x = self.norm2(self.convs(self.conv2, data))
                    data.x = self.act(data.x)

                    data.x = self.norm3(self.convs(self.conv3, data))
                    data.x = self.act(data.x)

                    data.x = self.norm4(self.convs(self.conv4, data))
                    data.x = self.act(data.x)


                elif self.conv_type == 'fuse':
                    if not self.quantized:
                        data.x = self.fuse1(x=data.x, pos=data.pos[:,:2], edge_index=data.edge_index) # no timestamp
                        data.x = self.fuse2(x=data.x, pos=data.pos[:,:2], edge_index=data.edge_index)
                        x_sc = data.x.clone()
                        data.x = self.fuse3(x=data.x, pos=data.pos[:,:2], edge_index=data.edge_index)
                        data.x = self.fuse4(x=data.x, pos=data.pos[:,:2], edge_index=data.edge_index)
                        data.x = data.x + x_sc
                    else:
                        # data.x = MyConvBNReLU.quant_tensor(data.x, scale=self.fuse1.x_scale, dtype=self.fuse1.f_dtype)
                        # data.x = self.fuse1(x=data.x, pos=data.pos[:,:2], edge_index=data.edge_index)
                        # data.x = self.fuse2(x=data.x, pos=data.pos[:,:2], edge_index=data.edge_index)
                        # data.x = self.fuse3(x=data.x, pos=data.pos[:,:2], edge_index=data.edge_index)
                        # data.x = self.fuse4(x=data.x, pos=data.pos[:,:2], edge_index=data.edge_index)
                        # # data.x = MyConvBNReLU.dequant_tensor(data.x, scale=self.fuse4.y_scale)
                        raise ValueError('Teacher model does not support quantization')



                x,_ = self.pool(data.x, pos=data.pos[:, :2], batch=data.batch)

                x = x.view(-1, self.fc.in_features) # x.shape = [batch_size, num_grids*num_last_hidden_features]

                if not self.quantized:
                    output = self.fc(x)
                else:
                    # q_output = self.fc(x)
                    # # dq_output = MyConvBNReLU.dequant_tensor(q_output, scale=self.fc.out_scale)
                    # # output = dq_output
                    # output = q_output
                    raise ValueError('Teacher model does not support quantization')

            elif self.character == 'student': # student model
                assert self.conv_type == 'fuse'

                if not self.quantized:
                    data.x = self.fuse1(x=data.x, pos=data.pos, edge_index=data.edge_index) # no timestamp
                    data.x = self.fuse2(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse3(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse4(x=data.x, pos=data.pos, edge_index=data.edge_index)
                else:
                    data.x = MyConvBNReLU.quant_tensor(data.x, scale=self.fuse1.x_scale, dtype=self.fuse1.f_dtype)
                    data.x = self.fuse1(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse2(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse3(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    data.x = self.fuse4(x=data.x, pos=data.pos, edge_index=data.edge_index)
                    # data.x = MyConvBNReLU.dequant_tensor(data.x, scale=self.fuse4.y_scale)

                x,_ = self.pool(data.x, pos=data.pos[:, :2], batch=data.batch)
                x = x.view(-1, self.fc.in_features) # x.shape = [batch_size, num_grids*num_last_hidden_features]

                if not self.quantized:
                    output = self.fc(x)
                else:
                    q_output = self.fc(x)
                    # dq_output = MyConvBNReLU.dequant_tensor(q_output, scale=self.fc.out_scale)
                    # output = dq_output
                    output = q_output

        return output

    def debug_logger(self):
        self.debug_y = {}
        self.debug_qy = {}
        self.debug_dqy = {}

        self.debug_fc = {}

        if self.conv_type == 'fuse':
            def log_y(name):
                def hook(module, input, output):
                    if not self.quantized:
                        self.debug_y[name] = output.detach()
                    else:
                        self.debug_qy[name] = output.detach()
                        self.debug_dqy[name] = MyConvBNReLU.dequant_tensor(output.detach(), scale=module.y_scale)
                return hook

            def log_io():
                def hook(module, input, output):
                    if not self.quantized:
                        self.debug_fc['in'] = input[0].detach()
                        self.debug_fc['out'] = output.detach()
                    else:
                        self.debug_fc['qin'] = input[0].detach()
                        self.debug_fc['dqin'] = MyConvBNReLU.dequant_tensor(input[0].detach(), scale=module.in_scale)
                        self.debug_fc['qout'] = output.detach()
                        self.debug_fc['dqout'] = MyConvBNReLU.dequant_tensor(output.detach(), scale=module.out_scale)
                return hook


            for name, module in self.named_children():
                if not name.startswith('params'):
                    if isinstance(module, MessagePassing):
                        module.register_forward_hook(log_y(name))
                    if isinstance(module, qLinear):
                        module.register_forward_hook(log_io())


