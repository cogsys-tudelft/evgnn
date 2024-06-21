#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import aegnn.models.layer
import aegnn.models.networks
from aegnn.models.recognition import RecognitionModel

################################################################################################
# Access functions #############################################################################
################################################################################################
import pytorch_lightning as pl


def by_task(task: str) -> pl.LightningModule.__class__:
    if task == "recognition":
        return RecognitionModel
    else:
        raise NotImplementedError(f"Task {task} is not implemented!")
