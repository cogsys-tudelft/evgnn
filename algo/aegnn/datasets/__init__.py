#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
from aegnn.datasets.base.event_dm import EventDataModule

from aegnn.datasets.ncaltech101 import NCaltech101
from aegnn.datasets.ncars import NCars
from aegnn.datasets.gen1 import Gen1


################################################################################################
# Access functions #############################################################################
################################################################################################
def by_name(name: str) -> EventDataModule.__class__:
    if name.lower() == "ncaltech101":
        return NCaltech101
    elif name.lower() == "ncars":
        return NCars
    elif name.lower() == "gen1":
        return Gen1
    else:
        raise NotImplementedError(f"Dataset with name {name} is not known!")
