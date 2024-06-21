#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import os
import shutil
import glob
import sys

path='../../aegnn_results/training_results/latest'; # alternatively, <path_to_results>/training_results/latest
if not os.path.exists(path):
    os.makedirs(path)
else:
    # clean
    try:
        shutil.rmtree(path)
    except OSError as e:
        print("Error: %s : %s" % (path, e.strerror))
    
    # rebuild
    os.makedirs(path)

src_model = sorted(glob.glob(os.environ["AEGNN_LOG_DIR"]+r'checkpoints/ncars/recognition/*/*.pt'), key=os.path.getctime)[-1]
dst_model = os.path.join(path,'latest_model.pt')

src_log = sorted(glob.glob(os.environ["AEGNN_LOG_DIR"]+r'debug/*'), key=os.path.getctime)[-1]
dst_log = os.path.join(path,os.path.basename(src_log))


try:
    shutil.copy2(src_model, dst_model)
except IOError as e:
    print("Unable to copy file. %s" % e)
except:
    print("Unexpected error:", sys.exc_info())

try:
    shutil.copy2(src_log, dst_log)
except IOError as e:
    print("Unable to copy file. %s" % e)
except:
    print("Unexpected error:", sys.exc_info())