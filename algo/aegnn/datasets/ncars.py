#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import glob
import numpy as np
import os
import torch

from torch_geometric.data import Data
from torch_geometric.nn.pool import radius_graph
from typing import Callable, List, Optional, Union

from .utils.normalization import normalize_time
from .ncaltech101 import NCaltech101
from aegnn.asyncronous.base.utils import causal_radius_graph, hugnet_graph, hugnet_graph_cylinder


class NCars(NCaltech101):

    def __init__(self, batch_size: int = 64, shuffle: bool = True, num_workers: int = 8, pin_memory: bool = False, d_max=16, r=3, max_dt=65535,
                 transform: Optional[Callable[[Data], Data]] = None):
        super(NCars, self).__init__(batch_size, shuffle, num_workers, pin_memory=pin_memory, transform=transform)
        self.dims = (120, 100)  # overwrite image shape
        # pre_processing_params = {"r": 3.0, "d_max": 16, "n_samples": 10000, "sampling": False, "max_dt": 65535}
        pre_processing_params = {"r": 3.0, "d_max": 16, "n_samples": 10000, "sampling": True, "max_dt": 20000}
        self.save_hyperparameters({"preprocessing": pre_processing_params})

        self.d_max  = d_max;
        self.max_dt = max_dt;
        self.r      = r;
    
    def read_annotations(self, raw_file: str) -> Optional[np.ndarray]:
        return None

    @staticmethod
    def read_label(raw_file: str) -> Optional[Union[str, List[str]]]:
        label_file = os.path.join(raw_file, "is_car.txt")
        with open(label_file, "r") as f:
            label_txt = f.read().replace(" ", "").replace("\n", "")
        return "car" if label_txt == "1" else "background"

    @staticmethod
    def load(raw_file: str) -> Data:
        events_file = os.path.join(raw_file, "events.txt")
        events = torch.from_numpy(np.loadtxt(events_file)).float().cuda()
        x, pos = events[:, -1:], events[:, :3]
        return Data(x=x, pos=pos)

    def pre_transform(self, data: Data) -> Data:
        params = self.hparams.preprocessing

        torch.cuda.empty_cache()

        # Re-weight temporal vs. spatial dimensions to account for different resolutions.
        # data.pos[:, 2] = normalize_time(data.pos[:, 2]) # comment out = beta==1
        data.pos[:, 2] = torch.round(data.pos[:, 2] * 1e6) # change back to unit us #! if use cylinder, uncomment this
        # data = data.to('cuda')

        # Coarsen graph by uniformly sampling n points from the event point cloud.
        # data = self.sub_sampling(data, n_samples=params["n_samples"], sub_sample=params["sampling"])

        # Radius graph generation.
        # data.edge_index = radius_graph(data.pos, r=params["r"], max_num_neighbors=params["d_max"])
        # data.edge_index = radius_graph(data.pos, r=params["r"], max_num_neighbors=data.pos.shape[0]) #this max nei basically equals to infinite
        # data.edge_index = causal_radius_graph(data.pos, r=params["r"], max_num_neighbors=params["d_max"])
        # data.edge_index = hugnet_graph(data.pos, r=params["r"], max_num_neighbors=params["d_max"])

        # data.edge_index = hugnet_graph(data.pos, r=params["r"], max_num_neighbors=params["d_max"], p=1)

        # data.edge_index = hugnet_graph_cylinder(data.pos, r=params["r"], max_num_neighbors=params["d_max"], max_dt=params["max_dt"], p=1)
        data.edge_index = hugnet_graph_cylinder(data.pos, r=params["r"], max_num_neighbors=params["d_max"], max_dt=params["max_dt"], p=1)
        return data

    #########################################################################################################
    # Files #################################################################################################
    #########################################################################################################
    def raw_files(self, mode: str) -> List[str]:
        return glob.glob(os.path.join(self.root, mode, "*"))

    #def processed_files(self, mode: str) -> List[str]:
    #    processed_dir = os.path.join(self.root, "processed")
    #    return glob.glob(os.path.join(processed_dir, mode, "*"))

    def processed_files(self, mode: str) -> List[str]:
        params = self.hparams.preprocessing;
        processed_dir = os.path.join(self.root, "processed_cylinder_d{}_t{}ms_r{}".format(self.d_max,int(self.max_dt//1000),int(self.r)));
        return glob.glob(os.path.join(processed_dir, mode, "*"))

    @property
    def classes(self) -> List[str]:
        return ["car", "background"]
