#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import argparse
import pytorch_lightning as pl
import torch
import os
import datetime

import tqdm
import pathlib
import click

import aegnn


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", default=12345, type=int)
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--gpu", default=None, type=int)
    parser.add_argument("--run-name", default=None, type=str)
    parser = aegnn.datasets.EventDataModule.add_argparse_args(parser)
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    if args.debug:
        aegnn.utils.loggers.LoggingLogger(None, name="debug")

    if torch.cuda.is_available():
        if args.gpu is not None:
            torch.cuda.set_device(args.gpu)
        if args.num_workers > 1:
            torch.multiprocessing.set_start_method("spawn")
    pl.seed_everything(args.seed)

    experiment_name = datetime.datetime.now().strftime("%Y%m%d")
    run_name = experiment_name if args.run_name is None else args.run_name

    dm = aegnn.datasets.by_name(args.dataset).from_argparse_args(args)
    dm.run_name = run_name

    # Assign paths for processed datasets
    processed_dir_with_name = pathlib.Path(dm.root) / ("processed_" + dm.run_name)
    # Check if it exists
    if processed_dir_with_name.exists():
        click.confirm(f"Folder '{processed_dir_with_name.name}' already exists. Continue?", default=True, abort=True)

    dm.prepare_data()

    processed_dir_symlink = pathlib.Path(dm.root) / "processed"
    # If the symlink file already exists, remove it
    if processed_dir_symlink.exists():
        processed_dir_symlink.unlink()

    # Create the symlink
    processed_dir_symlink.symlink_to(processed_dir_with_name)
    print(f"Symlink created: '{processed_dir_symlink.name}' -> '{processed_dir_with_name.name}'")




