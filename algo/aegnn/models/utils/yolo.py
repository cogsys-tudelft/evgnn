#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import torch


def yolo_grid(input_shape: torch.Tensor, cell_map_shape: torch.Tensor) -> torch.Tensor:
    """Constructs a 2D grid with the cell center coordinates.

    :param input_shape: 2D size of the image (width, height).
    :param cell_map_shape: number of cells in grid in each input dimension.
    """
    assert len(input_shape) == len(cell_map_shape), "number of input and grid dimensions must be equal"
    cell_shape = input_shape / cell_map_shape
    num_cells = (cell_map_shape * cell_shape).int()

    # The last cell should start in `cell_shape` distance from the image frame, therefore avoid
    # creating the last shape when fitting perfectly.
    cell_top_left = torch.meshgrid([
        torch.arange(0, end=num_cells[0] - 1e-3, step=cell_shape[0], device=cell_shape.device),
        torch.arange(0, end=num_cells[1] - 1e-3, step=cell_shape[1], device=cell_shape.device)
    ])
    return torch.stack(cell_top_left, dim=-1)
