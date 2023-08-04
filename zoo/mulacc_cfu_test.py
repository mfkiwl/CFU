## mulacc_cfu_l1_test.py: mulacc_cfu_l1 (stateful serializable L1 CFU) testbench

'''
Copyright (C) 2019-2023, Gray Research LLC.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
'''

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.queue import Queue
from cocotb.triggers import FallingEdge, RisingEdge, Timer

from enum import IntEnum
import random
import math

from cfu_li import *
from tb import TB
from imulacc import *

# testbench
@cocotb.test()
async def mulacc_cfu_tb(dut):
    tb = TB(dut, Level.l1_pipe)
    await tb.start()
    await IStateContext_tests(tb)
    await IMulAcc_tests(tb)
    await tb.idle()


# cocotb-test, follows Alex Forencich's helpful examples to sweep over dut module parameters

import os
import pytest
from cocotb_test.simulator import run

@pytest.mark.parametrize("latency", [0,1,2])
@pytest.mark.parametrize("states", [1,2,3])
@pytest.mark.parametrize("width", [32,64])

def test_mulacc(request, latency, states, width):
    dut = "mulacc_cfu"
    module = os.path.splitext(os.path.basename(__file__))[0]
    parameters = {}
    parameters['CFU_LATENCY'] = latency
    parameters['CFU_N_STATES'] = states
    parameters['CFU_STATE_ID_W'] = (states-1).bit_length()
    parameters['CFU_DATA_W'] = width
    sim_build = os.path.join(".", "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    run(
        includes=["."],
        verilog_sources=["common.svh", "cfu.svh", f"{dut}.sv", "shared.sv"],
        toplevel=dut,
        module=module,
        parameters=parameters,
        defines=['MULACC_CFU_VCD'],
        extra_env={ 'CFU_N_STATES':str(states), 'CFU_LATENCY':str(latency), 'CFU_DATA_W':str(width) },
        sim_build=sim_build
    )
