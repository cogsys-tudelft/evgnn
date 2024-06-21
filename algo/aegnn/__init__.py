#
# Copyright (c) 2024, Yufeng Yang (CogSys Group)
# Licensed under the MIT License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at: https://opensource.org/license/mit
# Modified from Copyright (c) 2022 Simon Schaefer,
# https://github.com/uzh-rpg/aegnn
#

import aegnn.asyncronous
import aegnn.utils
import aegnn.datasets
import aegnn.models

try:
    import aegnn.visualize
except ModuleNotFoundError:
    import logging
    logging.warning("AEGNN Module imported without visualization tools")

# Setup default values for environment variables, if they have not been defined already.
# Consequently, when another system is used, other than the default system, the env variable
# can simply be changed prior to importing the `aegnn` module.
aegnn.utils.io.setup_environment({
    "AEGNN_DATA_DIR": "<path_to_dataset>/data/storage/",
    "AEGNN_LOG_DIR": "<path_to_dataset>/data/scratch/"
})
