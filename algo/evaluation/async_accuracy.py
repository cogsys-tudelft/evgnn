#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
#
import argparse
import logging
import os
import numpy as np
import pandas as pd
import torch
import torchmetrics.functional as pl_metrics
import torch_geometric
import pytorch_lightning as pl
import time as timer

from torch_geometric.data import Batch
from torch_geometric.data import Data
from torch_geometric.utils import subgraph
from tqdm import tqdm
tprint = tqdm.write
from typing import Iterable, Tuple
import aegnn
from aegnn.asyncronous.base.utils import causal_radius_graph, hugnet_graph, hugnet_graph_cylinder


import signal


def signal_handler(signal, frame):
    global INT
    INT = True


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("model_file", help="Path of model to evaluate.")
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--test-samples", default=None, type=int)

    parser.add_argument("--radius", default=3, help="radius of radius graph generation")
    parser.add_argument("--max-num-neighbors", default=16, help="max. number of neighbors in graph")
    parser.add_argument("--max-dt", default=66000)

    parser = aegnn.datasets.EventDataModule.add_argparse_args(parser)
    return parser.parse_args()


def sample_initial_data(sample, num_events: int, radius: float, edge_attr, max_num_neighbors: int):
    data = Data(x=sample.x[:num_events], pos=sample.pos[:num_events])
    subset = torch.arange(num_events)
    data.edge_index, data.edge_attr = torch_geometric.utils.subgraph(subset, sample.edge_index, sample.edge_attr)
    nxt_event_idx = num_events
    return data, nxt_event_idx

def sample_new_data(sample, nxt_event_idx):
    x_new = sample.x[nxt_event_idx, :].view(1, -1)
    pos_new = sample.pos[nxt_event_idx, :3].view(1, -1)  #TODO: :2 ? no time?
    event_new = Data(x=x_new, pos=pos_new, batch=torch.zeros(1, dtype=torch.long))
    nxt_event_idx += 1
    return event_new, nxt_event_idx

@torch.no_grad()
def calibre_quant(model_eval, data_loader, args):

    if isinstance(model_eval, pl.LightningModule):
        model = model_eval.model
        model.device =  model_eval.device
    elif isinstance(model, torch.nn.Module):
        model = model_eval
    else:
        raise TypeError(f'The type of model is {type(model)}, not a `torch.nn.Module` or a `pl.LightningModule`')

    from copy import deepcopy
    unfused_model = deepcopy(model)
    unfused_model = unfused_model.to(model_eval.device)
    unfused_model.eval()

    assert model.fused is False
    assert model.quantized is False
    model.to_fused()
    assert model.fused is True
    assert model.quantized is False

    model.eval()

    # calibration
    num_test_samples = len(data_loader)
    unfused_correct = 0
    fused_correct = 0
    for i, sample in enumerate(tqdm(data_loader, position=1, desc='Samples', total=num_test_samples)):
        torch.cuda.empty_cache()
        if i==num_test_samples: break
        # tprint(f"\nSample {i}, file_id {sample.file_id}:")

        sample = sample.to(model.device)
        tot_nodes = sample.num_nodes

        unfused_test_sample = sample.clone().detach().to(model.device)
        output_unfused = unfused_model.forward(unfused_test_sample)
        y_unfused = torch.argmax(output_unfused, dim=-1)
        # tprint(f'unfused output = {output_unfused}')
        unfused_hit = torch.allclose(y_unfused, unfused_test_sample.y)
        if unfused_hit: unfused_correct += 1

        fused_test_sample = sample.clone().detach().to(model.device)
        output_fused = model.forward(fused_test_sample)
        y_fused = torch.argmax(output_fused, dim=-1)
        # tprint(f'  fused output = {output_fused}')
        fused_hit = torch.allclose(y_fused, fused_test_sample.y)
        if fused_hit: fused_correct += 1

        # diff = torch.allclose(y_unfused, y_fused)
        # if diff is not True:
        #     print(i)
        #     print(f'unfused output = {output_unfused}')
        #     print(f'  fused output = {output_fused}')
    unfused_acc = unfused_correct / num_test_samples
    fused_acc = fused_correct / num_test_samples

    tprint(f'unfused_acc = {unfused_acc}')
    tprint(f'fused_acc = {fused_acc}')

    # quantization
    model.quant()
    assert model.quantized is True

    # quantization test
    quant_correct = 0
    for i, sample in enumerate(tqdm(data_loader, position=1, desc='Samples', total=num_test_samples)):
        torch.cuda.empty_cache()
        if i==num_test_samples: break
        # tprint(f"\nSample {i}, file_id {sample.file_id}:")

        sample = sample.to(model.device)
        tot_nodes = sample.num_nodes

        output_quant = model.forward(sample)
        y_quant = torch.argmax(output_quant, dim=-1)
        # tprint(f'  quant output = {output_quant}')
        quant_hit = torch.allclose(y_quant, sample.y)
        if quant_hit: quant_correct += 1
    quant_acc = quant_correct / num_test_samples
    tprint(f'quant_acc = {quant_acc}')

    return model_eval

def fprint_params(async_model):

    i_qscale_reverse = (1 / async_model.model.fuse1.x_scale)  # 8bit
    i_qscale_reverse = torch.round(i_qscale_reverse).item()
    dpos_qscale_reverse = (1 / async_model.model.fuse1.dpos_scale)  # 10bit
    dpos_qscale_reverse = round(dpos_qscale_reverse)
    # async_model.model.fusex.NM === 20
    L1_w = async_model.model.fuse1.local_nn.weight.T.tolist() # [16,3]
    L1_b = async_model.model.fuse1.b_quant.T.tolist()  # [16]
    L1_m = async_model.model.fuse1.m.item()

    L2_w = async_model.model.fuse2.local_nn.weight.T.tolist() # [32,18]
    L2_b = async_model.model.fuse2.b_quant.T.tolist()  # [32]
    L2_m = async_model.model.fuse2.m.item()

    L3_w = async_model.model.fuse3.local_nn.weight.T.tolist() # [32,34]
    L3_b = async_model.model.fuse3.b_quant.T.tolist()  # [32]
    L3_m = async_model.model.fuse3.m.item()

    L4_w = async_model.model.fuse4.local_nn.weight.T.tolist() # [32,34]
    L4_b = async_model.model.fuse4.b_quant.T.tolist()  # [32]
    L4_m = async_model.model.fuse4.m.item()

    fc_w = async_model.model.fc.lin.weight.T.tolist()  # shape [2, 56*32]



    def fwrite_txt(f, layer, m = None, w = None, b = None):
        f.write(f'{layer}:\n')
        if m is not None:
            f.write(f'm: {m}\n')

        if w is not None:
            f.write(f'w:\n')
            for i in w:
                for j in i:
                    f.write(f'{int(j):6d}\t')
                f.write('\n')

        if b is not None:
            f.write(f'b:\n')
            for i in b:
                f.write(f'{int(i)}')
                f.write('\n')

        f.write('\n')

    params_dir = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "results")+'/training_results/params/';
    params_txt = params_dir + 'params.txt'
    with open(params_txt, 'w') as f:
        f.write(f'i_qscale_reverse: {i_qscale_reverse}\n')
        f.write(f'dpos_qscale_reverse: {dpos_qscale_reverse}\n')

        fwrite_txt(f, 'L1', m = L1_m, w = L1_w, b = L1_b)
        fwrite_txt(f, 'L2', m = L2_m, w = L2_w, b = L2_b)
        fwrite_txt(f, 'L3', m = L3_m, w = L3_w, b = L3_b)
        fwrite_txt(f, 'L4', m = L4_m, w = L4_w, b = L4_b)
        fwrite_txt(f, 'FC', w = fc_w)

    tprint(f'params are recorded into {params_txt}')


    # Note: This is little-endian storage (channelo31 channelo30 ... channelo0). Column order is reversed!
    def fwrite_hex(params_dir, param_name, w = None, b = None):
        if w is not None:
            param_mem = params_dir + param_name + '_w.mem'
            with open(param_mem, 'w') as f:
                for i in w:
                    for j in i[::-1]:  # Reversed column
                        f.write('{:02x}'.format(int(j) & 0xff))  # 8bit
                    f.write('\n')
            tprint(f'w params (hex) are stored into {param_mem}')

        if b is not None:
            param_mem = params_dir + param_name + '_b.mem'
            with open(param_mem, 'w') as f:
                for i in b:
                    f.write('{:08x}'.format(int(i) & 0xffffffff)) # 32bit
                    f.write('\n')
            tprint(f'b params (hex) are stored into {param_mem}')

    fwrite_hex(params_dir, 'L1', w = L1_w, b = L1_b)
    fwrite_hex(params_dir, 'L2', w = L2_w, b = L2_b)
    fwrite_hex(params_dir, 'L3', w = L3_w, b = L3_b)
    fwrite_hex(params_dir, 'L4', w = L4_w, b = L4_b)
    fwrite_hex(params_dir, 'FC', w = fc_w)

    tprint(f'params storing finished')



@torch.no_grad()
def evaluate(model, data_loader, args, img_size, init_event: int = None, iter_cnt: int = None) -> float:
    predss = []
    targets = []

    edge_attr = torch_geometric.transforms.Cartesian(cat=False, max_value=args.radius)

    from copy import deepcopy
    sync_model = deepcopy(model.model)
    sync_model = sync_model.to(model.device)
    sync_model.eval()

    # async_model = aegnn.asyncronous.make_model_asynchronous(model, args.radius, img_size, edge_attr)
    async_model = aegnn.asyncronous.make_model_asynchronous(model, r=args.radius, max_num_neighbors=args.max_num_neighbors, max_dt=args.max_dt)
    async_model.eval()

    # Print params into mem file for hw
    # fprint_params(async_model)

    df = pd.DataFrame()
    output_file = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "results")+'/mid_result'; # alteratively, <path_to_results>/mid_result
    # df_with_time = pd.DataFrame()
    # df_runtime = pd.DataFrame(columns=['runtime_sample', 'tot_nodes'])

    if args.test_samples is not None:
        num_test_samples = args.test_samples
        tprint(f"Will test {num_test_samples} sample(s) in the dataset")
    else:
        num_test_samples = len(data_loader)
        tprint(f"Will test all samples in the dataset")

    # # For hw debug:
    # params = {"r": 3.0, "d_max": 16, "n_samples": 10000, "sampling": True, "max_dt": 65535}
    # debug_num_nodes = 26

    # debug_p = torch.ones(debug_num_nodes).view(-1, 1)
    # debug_xyt = torch.tensor([
    #     [ 0 +10,  0 +10,   0],

    #     [ 0 +10,  1 +10,   1],
    #     [-1 +10,  0 +10,   2],
    #     [ 0 +10, -1 +10,   3],
    #     [ 1 +10,  0 +10,   4],

    #     [ 1 +10,  1 +10,   5],
    #     [ 0 +10,  2 +10,   6],
    #     [-1 +10,  1 +10,   7],
    #     [-2 +10,  0 +10,   8],
    #     [-1 +10, -1 +10,   9],
    #     [ 0 +10, -2 +10,  10],
    #     [ 1 +10, -1 +10,  11],
    #     [ 2 +10,  0 +10,  12],

    #     [ 2 +10,  1 +10,  13],
    #     [ 1 +10,  2 +10,  14],
    #     [ 0 +10,  3 +10,  15],
    #     [-1 +10,  2 +10,  16],
    #     [-2 +10,  1 +10,  17],
    #     [-3 +10,  0 +10,  18],
    #     [-2 +10, -1 +10,  19],
    #     [-1 +10, -2 +10,  20],
    #     [ 0 +10, -3 +10,  21],
    #     [ 1 +10, -2 +10,  22],
    #     [ 2 +10, -1 +10,  23],
    #     [ 3 +10,  0 +10,  24],

    #     [ 0 +10,  0 +10,  25]
    # ], dtype=torch.float)

    # debug_target = torch.tensor([1.])
    # debug_sample = Data(x=debug_p, pos=debug_xyt, y=debug_target, file_id='hw_debug', device=model.device)
    # debug_sample.edge_index = hugnet_graph_cylinder(debug_xyt, r=params["r"], max_num_neighbors=params["d_max"], max_dt=params["max_dt"])
    # # hw debug end

    max_nodes = 0
    # for NCars dataset, #events: min=500 at 1422, max=40810 at 219, mean=3920; #samples = 2462
    for i, sample in enumerate(tqdm(data_loader, position=1, desc='Samples', total=num_test_samples)):

        # For hw debug:
        # del sample
        # sample = debug_sample.clone().detach()
        # hw debug end

        torch.cuda.empty_cache()
        if i==num_test_samples: break
        tprint(f"\nSample {i}, file_id {sample.file_id}:")

        sample = sample.to(model.device)
        tot_nodes = sample.num_nodes
        if tot_nodes > max_nodes: max_nodes = tot_nodes

        sync_test_sample = sample.clone().detach()
        output_sync = sync_model.forward(sync_test_sample)
        y_sync = torch.argmax(output_sync, dim=-1)
        tprint(f' sync output = {output_sync}')
        # sample.y = y_sync  # Debug only: for random sample input
        targets.append(sample.y)

        async_model = aegnn.asyncronous.reset_async_module(async_model)
        aegnn.asyncronous.register_sync_graph(async_model, sample) #TODO: for debug


        # init_num_event = 2
        # init_num_event = tot_nodes - 2

        sub_predss = []

        # events_initial, nxt_event_idx = sample_initial_data(sample, init_num_event, args.radius, edge_attr, args.max_num_neighbors)
        # while nxt_event_idx < tot_nodes:
        #     if events_initial.edge_index.numel() > 0:
        #         break
        #     else:
        #         sub_predss.append(torch.tensor([0.], device=model.device))
        #         events_initial, nxt_event_idx = sample_initial_data(sample, nxt_event_idx+1, args.radius, edge_attr, args.max_num_neighbors)
        # tprint(f'1st edge starts from node {nxt_event_idx}; former predictions default to 0.0')

        # # init stage
        # output_new = async_model.forward(events_initial)
        # y_init = torch.argmax(output_new, dim=-1)
        # sub_predss.append(y_init)

        # # iterative adding nodes stage
        # with tqdm(total=(tot_nodes-nxt_event_idx), position=0, leave=False, desc='Events') as pbar:
        #     while nxt_event_idx < tot_nodes:
        #         torch.cuda.empty_cache()

        #         event_new, nxt_event_idx = sample_new_data(sample, nxt_event_idx)
        #         event_new = event_new.to(model.device)

        #         output_new = async_model.forward(event_new)
        #         y_new = torch.argmax(output_new, dim=-1)

        #         sub_predss.append(y_new)
        #         pbar.update(1)
        #         if INT: break
        # tprint(f'async output = {output_new}')

        # times = []
        # runtime_start = timer.time()
        for idx in tqdm(range(tot_nodes), position=0, leave=False, desc='Events'):
            torch.cuda.empty_cache()
            x_new = sample.x[idx, :].view(1, -1)
            pos_new = sample.pos[idx, :3].view(1, -1)
            event_new = Data(x=x_new, pos=pos_new, batch=torch.zeros(1, dtype=torch.long))
            event_new = event_new.to(model.device)
            output_async = async_model(event_new)
            # tprint(f'out = {output_async}')
            y_async = torch.argmax(output_async, dim=-1)
            sub_predss.append(y_async)
            event_time = pos_new[0,2].item()
            # times.append(event_time)
            if INT: break
        # runtime_end = timer.time()
        # runtime_sample = (runtime_end - runtime_start) * 1000 # runtime in ms
        tprint(f'async output = {output_async}')


        # Test if graphs are the same
        # aegnn_graph = async_model.model.conv1.asy_graph
        # aegnn_graph.edge_index = torch_geometric.utils.to_undirected(aegnn_graph.edge_index)
        # ordered_sync_edge = torch_geometric.utils.to_undirected(sync_test_sample.edge_index)
        # tprint(f'asy graph == sync graph ? {torch.allclose(aegnn_graph.edge_index, ordered_sync_edge)}')


        sub_preds = torch.cat(sub_predss)
        # time = torch.tensor(times)

        column_name = pd.MultiIndex.from_tuples([(i, sample.y.cpu().item())], names=['i', 'gnd_truth'])
        df.insert(len(targets)-1, column_name, pd.Series(sub_preds.cpu()), allow_duplicates=True)
        df.to_pickle(output_file+'.pkl')
        df.to_csv(output_file+'.csv')



        # df_with_time[f'time_{i}'] = pd.Series(time.numpy())
        # df_with_time[f'sub_preds_{i}'] = pd.Series(sub_preds.cpu())

        # df_runtime = df_runtime.append({'runtime_sample': runtime_sample, 'tot_nodes': tot_nodes}, ignore_index=True)


        predss.append(sub_preds)
        if INT: break

    # target = torch.cat(targets).unsqueeze(1)
    # dummy_time = torch.ones_like(target) * -1
    # header = torch.stack([dummy_time, target]).T
    # h_flat = header.reshape(-1)
    # df_with_time.loc[-1] = h_flat.cpu()
    # df_with_time.sort_index(inplace=True)
    # df_with_time.to_csv(output_file+'_with_time.csv', index=False, header=False)
    # df_with_time.to_pickle(output_file+'_with_time.pkl')

    # df_runtime.to_csv(output_file+'_runtime.csv', index=False)
    # df_runtime.to_pickle(output_file+'_runtime.pkl')



    # "torch.nested" is not yet supported!
    # preds_nt = torch.nested.nested_tensor(predss)
    # preds = torch.nested.to_padded_tensor(preds_nt, 0.0)


    max_nodes += 100
    for i, sub_preds in enumerate(predss):
        tmp = torch.nn.functional.pad(sub_preds, (0,max_nodes-len(sub_preds)), value=sub_preds[-1].item())
        predss[i] = tmp.unsqueeze(0)

    preds = torch.cat(predss, dim=0)
    target = torch.cat(targets).unsqueeze(1)
    tot_accuracies = []
    for j in tqdm(range(max_nodes), position=2, desc='Acc Calc', leave=False):
        tot_accuracy = pl_metrics.accuracy(preds=preds[:,j], target=target)
        tot_accuracy = tot_accuracy.item()
        tot_accuracies.append(tot_accuracy)
    return tot_accuracies


def main(args, model, data_module):

    img_size = list(data_module.dims)

    df = pd.DataFrame()
    output_dir = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "results")
    os.makedirs(output_dir, exist_ok=True)
    output_file = os.path.join(output_dir, "async_accuracy")

    data_loader = data_module.val_dataloader(num_workers=16)
    # data_loader = data_module.test_dataloader(num_workers=16)

    model = calibre_quant(model, data_loader, args)
    accuracy = evaluate(model, data_loader, args=args, img_size=img_size)
    df = pd.concat([df, pd.Series(accuracy)])
    df.to_pickle(output_file+'.pkl')
    df.to_csv(output_file+'.csv')
    tprint(f"Results are logged in {output_file}.*")
    return df


if __name__ == '__main__':
    pl.seed_everything(12345)
    args = parse_args()
    if args.debug:
        _ = aegnn.utils.loggers.LoggingLogger(None, name="debug")

    torch.set_printoptions(precision=16)

    model_eval = torch.load(args.model_file).to(args.device)
    model_eval.eval()
    dm = aegnn.datasets.by_name(args.dataset).from_argparse_args(args)
    dm.setup()

    args.max_num_neighbors = dm.hparams.preprocessing['d_max']
    args.radius = dm.hparams.preprocessing['r']
    args.max_dt = dm.hparams.preprocessing['max_dt']

    signal.signal(signal.SIGINT, signal_handler)
    INT = False

    main(args, model_eval, dm)
