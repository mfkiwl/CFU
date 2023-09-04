// mulacc_l2_cxu.sv: 32/64-bit multiply-accumulate stateful CXU-L2 streaming CXU
// via composing a cvt12_cxu with a CXU-L1 mulacc_cxu
//
// Copyright (C) 2019-2023, Gray Research LLC.
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//    http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// mulacc_l2_cxu: 32/64-bit multiply-accumulate stateful CXU-L2 streaming CXU,
// via composing a cvt12_cxu with a CXU-L1 mulacc_cxu.
module mulacc_l2_cxu
    import common_pkg::*, cxu_pkg::*;
#(
    `CXU_L2_PARAMS(/*N_CXUS*/1, /*N_STATES*/1, /*FUNC_ID_W*/10, /*INSN_W*/0, /*DATA_W*/32),
    parameter int CXU_LATENCY = 0,
    parameter int CXU_FIFO_SIZE = 2**$clog2(1+CXU_LATENCY)
) (
    `CXU_CLK_L2_PORTS(input, output, req, resp)
);
    initial ignore(`CHECK_CXU_L2_PARAMS && check_param_pos("CXU_N_STATES", CXU_N_STATES));
`ifdef MULACC_L2_CXU_VCD
    initial begin $dumpfile("mulacc_l2_cxu.vcd"); $dumpvars(0, mulacc_l2_cxu); end
`endif

    `CXU_L1_NETS(t_req, t_resp);
    cvt12_cxu #(`CXU_L2_PARAMS_MAP, .CXU_LATENCY(CXU_LATENCY), .CXU_FIFO_SIZE(CXU_FIFO_SIZE))
        cvt12(`CXU_CLK_L2_PORT_MAP(req,req, resp,resp),
              `CXU_L1_PORT_MAP(t_req,t_req, t_resp,t_resp));
    mulacc_cxu #(`CXU_L1_PARAMS_MAP) mulacc(`CXU_CLK_L1_PORT_MAP(req,t_req, resp,t_resp)); 
endmodule
