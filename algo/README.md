### EvGNN Software Algorithm ###
This repository is associated with the EvGNN's framework, developed for the processing of event-driven direct graphs using convolutional GNNs and facilitating their efficient hardware acceleration. It has been published in ArXiV's paper [**EvGNN: An Event-driven Graph Neural Network Accelerator for Edge Vision**] by Y. Yang, A. Kneip and C. Frenkel. When making use, building on top or refering to this framework, we request users to reference the work as follows (BibTex format):

```
@article{YYang24,
  author    = {Yang, Yufeng and Kneip, Adrian and Frenkel, Charlotte},
  title     = {EvGNN: An Event-driven Graph Neural Network Accelerator for Edge Vision},
  booktitle = {arXiv:2404.19489 [cs.CV]},
  pages     = {1--12},
  year      = {2024}
}
```
# Setup and (un)install
First, install conda (if not avail. on your machine) and create a new virtual environment to store all required libs. The code heavily depends on PyTorch and the [PyG](https://github.com/pyg-team/pytorch_geometric) framework, which is optimized only for GPUs supporting CUDA. For our implementation the CUDA version 12.0 is used. Derive the new conda environment with the right requirements automatically bu running:
```
conda env create --file=environment.yml
```
Then, register as "aegnn" package by running:

```
pip install -e .
```
or
```
python setup.py develop
```

uninstall:
```
pip uninstall aegnn
```

# AEGNN baseline
This repository is built on top of the AEGNN framework (https://github.com/uzh-rpg/aegnn/blob/master) by Simon Schaefer* et al. As such, the following steps are modified versions of the original AEGNN ones to match our processing pipeline.

# Download & Files Parsing
The present work has been developed focusin on the N-CARS dataset [NCars](http://www.prophesee.ai/dataset-n-cars/), although it may further support any dataset with spatiotemporal events representation. Download the selected dataset and extract it. The paths to your dataset and running results can be specified in the `aegnn/__init__.py` file, as follows:

`AEGNN_DATA_DIR`: the path of your dataset(s)

`AEGNN_LOG_DIR`: will be used to save program running results (such as training checkpoint files)

When using the N-CARS dataset, a dedicated parser can be executed. After renaming the files to `original_ncars`, run the following command:

```
python3 ./scripts/parse_ncars.py
```

Other datasets may need different parsing algorithms, which are to implemented by the user.

# Static Graph Generation for Training
The training process relies on a static, offline-generated graph. For the N-CARS dataset, this graph can be generated using:

```
CUDA_VISIBLE_DEVICES=<your_gpu_id> python3 ./scripts/preprocessing.py --dataset ncars --num-workers 2 --run-name <your_run_name>

(example usage)

CUDA_VISIBLE_DEVICES=3 python3 ./scripts/preprocessing.py --dataset ncars --num-workers 2 --run-name hemi_d32
```

The selected neighbors search algorithm can be manually adapted in the /datasets/ncars.py file.

# Training Process
The GNN training process relies on the [PyTorch Lightning](https://www.pytorchlightning.ai/) backend and [WandB](https://wandb.ai/) for logging. By default, the logs are stored at the `AEGNN_LOG_DIR` location.

To run training:
```
CUDA_VISIBLE_DEVICES=<your_gpu_id> python3 ./scripts/train.py graph_res --task recognition --dataset ncars --batch-size 64 --dim 3 --init-lr 0.001 --weight-decay 0.005 --act relu --max-num-neighbors 16 --conv-type fuse --drop 0.1 --run-name <your_run_name>

(example usage)

CUDA_VISIBLE_DEVICES=2 python3 ./scripts/train.py graph_res --task recognition --dataset ncars --batch-size 64 --dim 3 --init-lr 0.001 --weight-decay 0.005 --act elu --max-num-neighbors 16 --conv-type fuse --drop 0.0 --run-name my_very_nice_run_name
```

# From Synchronous to Asynchronous Inference
The trained models are by default available in the `AEGNN_LOG_DIR/checkpoints/ncars/recognition` repository (`*.pt` files). The target model can now be asynchronously evaluated by launching the following command:

```
CUDA_VISIBLE_DEVICES=<your_gpu_id> python3 ./evaluation/async_accuracy.py <your_trained_model_file> --device cuda --dataset ncars --batch-size 1 --max-num-neighbors 16

(example usage)

CUDA_VISIBLE_DEVICES=2 python3 ./evaluation/async_accuracy.py <your_trained_model_file> --device cuda --dataset ncars --batch-size 1 --max-num-neighbors 16
```

The output is written to `./results/async_accuracy.pkl` and `./results/async_accuracy.csv`

# Export quantized model parameters for hardware

To export your quantized model for hardware evaluation, update the following in `./evaluation/async_accuracy.py`,

1. Uncomment Line 251
2. Comment out Line 252 - 419

Then, run the code in Section "Asynchronous Evaluation" to get your hardware-mappable version ready!

# Licenses
Copyright (c) 2024, Yufeng Yang (CogSys Group)

All software files in the present folder and sub-folders are under the MIT License (https://opensource.org/license/mit)

