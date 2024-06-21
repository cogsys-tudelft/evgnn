#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import torch
import torch.nn.functional as F
import torch_geometric
import pytorch_lightning as pl
import torchmetrics.functional as pl_metrics

from torch.nn.functional import softmax
from typing import Tuple
from .networks import by_name as model_by_name


class RecognitionModel(pl.LightningModule):

    def __init__(self, network, dataset: str, num_classes, img_shape: Tuple[int, int],
                 dim: int = 3, learning_rate: float = 1e-3, weight_decay: float = 5e-3, distill: bool = False, character: str = None, teacher_model_path: str = None, distill_t: float = 1., distill_alpha: float = 0.75, **model_kwargs):
        super(RecognitionModel, self).__init__()
        self.lr = learning_rate
        self.weight_decay = weight_decay
        self.criterion = torch.nn.CrossEntropyLoss()
        self.num_outputs = num_classes
        self.dim = dim
        self.distill = distill
        self.character = character

        model_input_shape = torch.tensor(img_shape + (dim, ), device=self.device)
        self.model = model_by_name(network)(dataset, model_input_shape, num_outputs=num_classes, distill=self.distill, character=self.character, **model_kwargs)

        if self.distill:
            if self.character == 'teacher':
                pass
            if self.character == 'student':
                if teacher_model_path is None:
                    raise ValueError('Distillation needs a trained teacher model path')
                self.teacher_model = torch.load(teacher_model_path)

                if not hasattr(self.teacher_model, 'distill'):
                    self.teacher_model.distill = True
                    self.teacher_model.model.distill = True
                    self.teacher_model.model.character = 'teacher'
                    self.distill_t = distill_t
                    self.distill_alpha = distill_alpha
                    self.distill_criterion = torch.nn.KLDivLoss()

            else:
                raise ValueError("Assign a teacher/student character for distillation training")



    def forward(self, data: torch_geometric.data.Batch) -> torch.Tensor:
        # data.pos = data.pos[:, :self.dim]
        # data.edge_attr = data.edge_attr[:, :self.dim]
        return self.model.forward(data)

    ###############################################################################################
    # Steps #######################################################################################
    ###############################################################################################
    def training_step(self, batch: torch_geometric.data.Batch, batch_idx: int) -> torch.Tensor:
        if not self.distill or self.model.character == 'teacher':
            outputs = self.forward(data=batch)
            loss = self.criterion(outputs, target=batch.y)

            y_prediction = torch.argmax(outputs, dim=-1)
            accuracy = pl_metrics.accuracy(preds=y_prediction, target=batch.y)
            self.logger.log_metrics({"Train/Loss": loss, "Train/Accuracy": accuracy}, step=self.trainer.global_step)

        else:
            assert self.distill is True
            assert self.model.character == 'student'
            teacher_batch = batch.clone().detach()

            student_outputs = self.forward(data=batch)
            student_target_loss = self.criterion(student_outputs, target=batch.y)
            y_prediction = torch.argmax(student_outputs, dim=-1)
            accuracy = pl_metrics.accuracy(preds=y_prediction, target=batch.y)

            with torch.no_grad():
                self.teacher_model.eval()
                assert self.teacher_model.model.training is False
                teacher_outputs = self.teacher_model.forward(data=teacher_batch)

            distill_loss = self.distill_criterion(
                F.log_softmax(student_outputs / self.distill_t, dim=1),
                F.softmax(teacher_outputs / self.distill_t, dim=1)
            )

            loss = (1 - self.distill_alpha) * student_target_loss + self.distill_alpha * distill_loss

            self.logger.log_metrics({"Train/Loss": loss, "Train/Accuracy": accuracy}, step=self.trainer.global_step)
        return loss

    def validation_step(self, batch: torch_geometric.data.Batch, batch_idx: int) -> torch.Tensor:
        outputs = self.forward(data=batch)
        y_prediction = torch.argmax(outputs, dim=-1)
        predictions = softmax(outputs, dim=-1)

        self.log("Val/Loss", self.criterion(outputs, target=batch.y))
        self.log("Val/Accuracy", pl_metrics.accuracy(preds=y_prediction, target=batch.y))
        k = min(3, self.num_outputs - 1)
        self.log(f"Val/Accuracy_Top{k}", pl_metrics.accuracy(preds=predictions, target=batch.y, top_k=k))
        return predictions

    def test_step(self, batch: torch_geometric.data.Batch, batch_idx: int) -> torch.Tensor:
        outputs = self.forward(data=batch)
        y_prediction = torch.argmax(outputs, dim=-1)
        predictions = softmax(outputs, dim=-1)

        loss = self.criterion(outputs, target=batch.y)
        acc = pl_metrics.accuracy(preds=y_prediction, target=batch.y)
        k = min(3, self.num_outputs - 1)
        acc_k = pl_metrics.accuracy(preds=predictions, target=batch.y, top_k=k)

        self.log("Test/Loss", loss)
        self.log("Test/Accuracy", acc)
        self.log(f"Test/Accuracy_Top{k}", acc_k)
        return predictions

    def configure_optimizers(self):
        optimizer = torch.optim.Adam(self.parameters(), lr=self.lr, weight_decay=self.weight_decay)
        lr_scheduler = torch.optim.lr_scheduler.LambdaLR(optimizer, lr_lambda=LRPolicy())
        return [optimizer], [lr_scheduler]
        # lr_scheduler = torch.optim.lr_scheduler.OneCycleLR(optimizer, max_lr=self.lr*1.5, epochs=100, steps_per_epoch=240, anneal_strategy='cos', div_factor=2.0, final_div_factor=5.0)
        # return {
        #     "optimizer": optimizer,
        #     "lr_scheduler": {
        #         "scheduler": lr_scheduler,
        #         "interval": "step",
        #         "frequency": 1
        #     }
        # }


class LRPolicy(object):
    def __call__(self, epoch: int):
        if epoch < 20:
            # return 5e-3
            return 1
        elif epoch >= 20 and epoch < 50:
            # return 5e-4
            return 0.5
        else:
            return 0.1
