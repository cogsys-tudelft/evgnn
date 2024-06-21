#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#
import logging
from typing import Any


class CallbackFactory:

    def __init__(self, listeners, log_name: str):
        self.listeners = listeners
        self.log_name = log_name
        logging.debug(f"Setting callback for module {log_name} with {len(listeners)} listeners")

    def __call__(self, key: str, value: Any):
        for listener in self.listeners:
            logging.debug(f"Setting attribute {key} of module {listener} from module {self.log_name}")
            setattr(listener, key, value)
