#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import aegnn.utils.bounding_box
import aegnn.utils.io
from aegnn.utils.multiprocessing import TaskManager

import aegnn.utils.callbacks
import aegnn.utils.loggers


class Qtype():
    def __init__(self, dtype: str = None, *, bit: int = None, signed: bool = None) -> None:
        if dtype is not None:
            self.dtype = dtype
            self._bit, self._signed, self._format = Qtype.convert_dtype(self.dtype)
            self._min, self._max = self.get_range()
        elif bit is not None and signed is not None:
            self._bit = bit
            self._signed = signed
            self._format = 'int'
            self._min, self._max = self.get_range()
        else:
            raise ValueError(f'Init Error: Missing "dtype" or "bit with signed"')

    def __repr__(self) -> str:
        prefix = '' if self._signed else 'u'
        dtype_name = prefix + self._format + str(self._bit)
        return dtype_name

    @staticmethod
    def convert_dtype(dtype: str):
        dtype = dtype.lower()
        dtype = dtype.replace(' ','')
        signed = True
        bit = 32
        format = 'unkown'

        if 'int' in dtype:
            format = 'int'
            s = dtype.split('int')
            if s[0] == 'u' or s[0] == 'unsigned': signed = False
            if s[1] != '': bit = int(s[1])

        elif 'float' in dtype:
            format = 'float'
            s = dtype.split('float')
            if s[1] != '': bit = int(s[1])

        elif 'fp' in dtype:
            format = 'float'
            s = dtype.split('fp')
            if s[1] != '': bit = int(s[1])

        else:
            raise ValueError(f'Unkown data type: {dtype}')

        return bit, signed, format

    def get_range(self):
        if self._format == 'int':
            if self._signed:
                max = pow(2, self._bit-1) - 1
                min = - max  # symmetric clamp
            else:
                max = pow(2, self._bit) - 1
                min = 0
        elif self._format == 'float':
            max = float('+inf')
            min = float('-inf')
        else:
            raise ValueError(f'Unkown range')

        return min, max

    @property
    def bit(self):
        return self._bit

    @property
    def signed(self):
        return self._signed

    @property
    def format(self):
        return self._format

    @property
    def min(self):
        return self._min

    @property
    def max(self):
        return self._max
