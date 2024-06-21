#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import struct
import os
import shutil
from tqdm import tqdm
import random


def load_atis_data(filename, flipX=0, flipY=0):
    td_data = {'ts': [], 'x': [], 'y': [], 'p': []}
    header = []

    with open(filename, 'rb') as f:
        # Parse header if any
        endOfHeader = False
        numCommentLine = 0
        while not endOfHeader:
            bod = f.tell()
            tline = f.readline().decode('utf-8', errors='ignore')
            if tline[0] != '%':
                endOfHeader = True
            else:
                words = tline.split()
                if len(words) > 2:
                    if words[1] == 'Date':
                        if len(words) > 3:
                            header.append((words[1], words[2] + ' ' + words[3]))
                    else:
                        header.append((words[1], words[2]))
                numCommentLine += 1
        f.seek(bod)

        evType = 0
        evSize = 8
        if numCommentLine > 0:  # Ensure compatibility with previous files.
            # Read event type
            evType = struct.unpack('b', f.read(1))[0]
            # Read event size
            evSize = struct.unpack('b', f.read(1))[0]

        bof = f.tell()
        f.seek(0, 2)
        numEvents = (f.tell() - bof) // evSize

        # Read data
        f.seek(bof)  # Start just after the header
        for _ in range(numEvents):
            timestamp = struct.unpack('<I', f.read(4))[0]
            timestamp *= 1e-6  # us -> s
            addr = struct.unpack('<I', f.read(4))[0]
            x = (addr & 0x00003FFF) >> 0
            y = (addr & 0x0FFFC000) >> 14
            p = (addr & 0x10000000) >> 28

            td_data['ts'].append(timestamp)
            td_data['x'].append(x if flipX == 0 else flipX - x)
            td_data['y'].append(y if flipY == 0 else flipY - y)
            td_data['p'].append(p)

    return td_data, header



# def parse_ncars_to_txt(src_ds_path: str, dst_ds_path: str):
#     sequence_counter = 0
#     # traverse binary files in NCars
#     for root, dirs, files in os.walk(src_ds_path):
#         for dir_name in dirs:
#             subfolder = os.path.join(root, dir_name)

#             if 'background' in subfolder:
#                 is_car = 0
#             elif 'cars' in subfolder:
#                 is_car = 1
#             else:
#                 continue

#             for file_name in tqdm(os.listdir(subfolder), desc=dir_name):
#                 if file_name.endswith('.dat'):
#                     binary_file = os.path.join(subfolder, file_name)

#                     td_data, _ = load_atis_data(binary_file)

#                     # make events.txt
#                     sequence_folder = os.path.join(dst_ds_path, f'sequence_{sequence_counter}')
#                     os.makedirs(sequence_folder, exist_ok=True)

#                     events_file = os.path.join(sequence_folder, 'events.txt')
#                     with open(events_file, 'w') as txt_file:
#                         for i in range(len(td_data['ts'])):
#                             formatted_line = "{:.18e} {:.18e} {:.18e} {:.18e}".format(td_data['x'][i], td_data['y'][i], td_data['ts'][i], td_data['p'][i])
#                             txt_file.write(formatted_line + '\n')

#                     # make is_car.txt
#                     is_car_file = os.path.join(sequence_folder, 'is_car.txt')
#                     with open(is_car_file, 'w') as txt_file:
#                         txt_file.write(str(is_car))

#                     # add counter
#                     sequence_counter += 1
#     print(f'Parsed {sequence_counter} ncars samples to txt')

def parse_ncars_to_txt(src_ds_path: str, dst_ds_path: str):
    sequence_counter = 0
    # Combine and shuffle the files in background and cars folders
    combined_file_list = []

    # Traverse binary files in NCars
    for root, dirs, files in os.walk(src_ds_path):
        for dir_name in dirs:
            subfolder = os.path.join(root, dir_name)

            if 'background' in subfolder:
                is_car = 0
            elif 'cars' in subfolder:
                is_car = 1
            else:
                continue

            # Collect the list of files in the current subfolder
            file_list = [file_name for file_name in os.listdir(subfolder) if file_name.endswith('.dat')]

            # Add files to the combined list
            combined_file_list.extend([(file, is_car) for file in file_list])

    # Shuffle the combined list
    random.shuffle(combined_file_list)

    # Process the shuffled files
    for (file_name, is_car) in tqdm(combined_file_list, desc='Processing shuffled files'):
        subfolder = 'background' if is_car == 0 else 'cars'

        binary_file = os.path.join(src_ds_path, subfolder, file_name)

        td_data, _ = load_atis_data(binary_file)

        # make events.txt
        sequence_folder = os.path.join(dst_ds_path, f'sequence_{sequence_counter}')
        os.makedirs(sequence_folder, exist_ok=True)

        events_file = os.path.join(sequence_folder, 'events.txt')
        with open(events_file, 'w') as txt_file:
            for i in range(len(td_data['ts'])):
                formatted_line = "{:.18e} {:.18e} {:.18e} {:.18e}".format(td_data['x'][i], td_data['y'][i], td_data['ts'][i], td_data['p'][i])
                txt_file.write(formatted_line + '\n')

        # make is_car.txt
        is_car_file = os.path.join(sequence_folder, 'is_car.txt')
        with open(is_car_file, 'w') as txt_file:
            txt_file.write(str(is_car))

        # Increment the counter
        sequence_counter += 1

    print(f'Parsed {sequence_counter} ncars samples to txt')

if __name__ == '__main__':

    #AEGNN_DATA_DIR = <path_to_data_dir>;

    src_train = os.path.join(os.environ["AEGNN_DATA_DIR"], 'original_ncars/Prophesee_Dataset_n_cars/n-cars_train')
    src_test  = os.path.join(os.environ["AEGNN_DATA_DIR"], 'original_ncars/Prophesee_Dataset_n_cars/n-cars_test')
    dst_train = os.path.join(os.environ["AEGNN_DATA_DIR"], 'ncars/training')
    dst_test  = os.path.join(os.environ["AEGNN_DATA_DIR"], 'ncars/test')

    if not os.path.exists(dst_train):
        os.makedirs(dst_train)
    if not os.path.exists(dst_test):
        os.makedirs(dst_test)

    print('Parsing training set')
    parse_ncars_to_txt(src_train, dst_train)

    print('Parsing test set')
    parse_ncars_to_txt(src_test, dst_test)


    # # Manually split validation set

    # # Set a random seed for reproducibility
    # seed = 12345
    # random.seed(seed)
    # print(f'Manually split validation set. Seed {seed}')

    # # Define the paths to the training and validation folders
    # dst_val = <path_to_validation_set>

    # # Ensure the validation folder exists; create it if it doesn't
    # if not os.path.exists(dst_val):
    #     os.makedirs(dst_val)

    # # Get a list of all files (samples) in the training folder
    # training_files = os.listdir(dst_train)

    # # Get a list of all subdirectories (samples) in the training folder
    # training_samples = [sample for sample in os.listdir(dst_train) if os.path.isdir(os.path.join(dst_train, sample))]

    # # Calculate the number of samples to move (20%)
    # num_samples_to_move = int(0.2 * len(training_samples))

    # # Randomly select the samples to move
    # samples_to_move = random.sample(training_samples, num_samples_to_move)

    # # Move the selected samples (entire directories) to the validation folder
    # for sample in samples_to_move:
    #     source_path = os.path.join(dst_train, sample)
    #     destination_path = os.path.join(dst_val, sample)
    #     shutil.move(source_path, destination_path)

    # print(f"Moved {len(samples_to_move)} samples (directories) to the validation folder.")
