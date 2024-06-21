#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import pytorch_lightning as pl


class EpochLogger(pl.callbacks.base.Callback):

    def on_validation_end(self, trainer: pl.Trainer, model: pl.LightningModule) -> None:
        model.logger.log_metrics({"Epoch": model.current_epoch + 1})
