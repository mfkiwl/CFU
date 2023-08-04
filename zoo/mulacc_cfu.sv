// mulacc_cfu.sv: multiply-accumulate serializable stateful fixed latency (CFU-L1) CFU
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

// IMulAcc custom functions:
//     0:   mul
//     1:   mulacc
//     *:   error
//  1020:   cfid_write_state
//  1021:   cfid_read_state
//  1022:   cfid_write_status
//  1023:   cfid_read_status

`include "cfu.svh"

/* verilator lint_off DECLFILENAME */

// mulacc_cfu: 32/64-bit stateful serializable fixed latency (CFU-L1) CFU
module mulacc_cfu
    import common_pkg::*, cfu_pkg::*;
#(
    `CFU_L1_PARAMS(/*N_CFUS*/1, /*N_STATES*/1, /*LAT*/0, /*RESET*/0, /*FUNC_ID_W*/10, /*DATA_W*/32)
) (
    `CFU_CLK_L1_PORTS(input, output, req, resp)
);
    typedef `V(CFU_FUNC_ID_W)   func_id_t;
    typedef `V(CFU_STATE_ID_W)  state_id_t;
    typedef `V(CFU_DATA_W)      data_t;

    initial begin
        ignore(
            `CHECK_CFU_L1_PARAMS
        &&  check_param_pos("CFU_N_STATES", CFU_N_STATES)
        &&  check_param("CFU_FUNC_ID_W", CFU_FUNC_ID_W, $bits(cfid_t)));
    end
    wire _unused_ok = &{1'b0,req_cfu,1'b0};
`ifdef MULACC_CFU_VCD
    initial begin $dumpfile("mulacc_cfu.vcd"); $dumpvars(0, mulacc_cfu); end
`endif
    typedef enum logic[$bits(cfid_t)-1:0] {
        cfid_mul    = 0,                // acc = data0*data1
        cfid_mulacc = 1                 // acc += data0*data1
        // + IStateContext's standard CF_IDs
    } mulacc_cfid_t;                    // IMulAcc CF_IDs

    // state contexts
    logic [CFU_N_STATES-1:0][1:0]   css;    // context statuses (flops)
    logic [CFU_N_STATES-1:0]        zaccs;  // zero'd-accumulators (flops)
    data_t accs[CFU_N_STATES];              // accumulators (prob. LUT-RAM)
    // Cannot flash clear accs[*] on reset. Flash set zero-indicators zaccs[*] instead.

    // Fixed latency pipeline: shift registers' inputs and outputs.
    //
    // Note Xilinx synthesis (for example) takes a multiplier feeding a shallow shift
    // register and technology maps it to a pipelined multipler using DSP registers.
    logic       pass_data0;             // req_data0 => product
    data_t      prod_0;                 // product (current cycle)
    func_id_t   func;                   // function (+CFU_LATENCY cycles)
    state_id_t  state_raw;              // raw state ID (+CFU_LATENCY cycles)
    state_id_t  state;                  // bounds-checked state ID (+CFU_LATENCY cycles)
    data_t      prod;                   // product (+CFU_LATENCY cycles)

    always_comb begin
        // pipelined product; when pass_data0, product is just req_data0 * 1
        pass_data0 = (req_func == cfid_write_status || req_func == cfid_write_state);
        prod_0 = req_data0 * (pass_data0 ? data_t'(1) : req_data1);
    end
    localparam int N = CFU_LATENCY;
    shift_reg #(.W(1),                 .N(N)) valid_(.clk, .rst, .clk_en, .d(req_valid), .q(resp_valid));
    shift_reg #(.W($bits(func_id_t)),  .N(N)) func_ (.clk, .rst, .clk_en, .d(req_func),  .q(func));
    shift_reg #(.W($bits(state_id_t)), .N(N)) state_(.clk, .rst, .clk_en, .d(req_state), .q(state_raw));
    shift_reg #(.W($bits(data_t)),     .N(N)) prod_ (.clk, .rst, .clk_en, .d(prod_0),    .q(prod));
    // (when N==0, shift_reg is a 0-stage shift register, i.e. just wires)

    // Compute response and update current accumulator and context status state.
    // All state access happens as the product emerges from the mult. pipeline.
    // This block is structured to minimize edge-case control signals from impacting
    // logic-intensive case statement datapath that computes resp_data.
    // Besides resp_*, block computes wr and cs for the sync state update block below.
    logic       wr;                     // state write enable
    cfu_cs_t    cs_nxt;                 // next CSW.CS (when func is cfid_write_status)

    always_comb begin
        cfu_csw_t   csw;                // current state context status word
        data_t      acc;                // accumulator value, or zero when zaccs[state]

        // bounds-checking state index keeps simulation clean
        state = (int'(state_raw) < CFU_N_STATES) ? state_raw : 0;

        // current and possible new context status words
        csw = '0; csw.state_size = 1; csw.cs = css[state];
        cs_nxt = cfu_cs_t'(prod);

        // select response
        resp_status = CFU_OK;           // default
        acc = zaccs[state] ? '0 : accs[state];
        case (func)
        cfid_mul:           begin wr = 1; resp_data = prod;             end
        cfid_mulacc:        begin wr = 1; resp_data = acc + prod;       end
        cfid_read_status:   begin wr = 0; resp_data = data_t'(csw);     end
        cfid_write_status:  begin wr = 1; resp_data = data_t'(csw);     end
        cfid_read_state:    begin wr = 0; resp_data = acc;              end
        cfid_write_state:   begin wr = 1; resp_data = prod;             end
        default:            begin wr = 0; resp_data = prod; resp_status = CFU_ERROR_FUNC; end
        endcase

        // error cases, can overrule above CFU_ERROR_FUNC
        if (!resp_valid) begin
            // non-requests are ignored, no side effects
            resp_status = CFU_OK;       // not strictly necessary
            wr = 0;
        end
        else if (int'(state_raw) >= CFU_N_STATES) begin
            // invalid state index
            resp_status = CFU_ERROR_STATE;
            wr = 0;
        end
        else if (css[state] == CFU_OFF && !(func==cfid_read_status || func==cfid_write_status)) begin
            // valid state context, but it's turned off
            resp_status = CFU_ERROR_OFF;
            wr = 0;
        end
    end
    // reset or update state
    always_ff @(posedge clk) begin
        if (rst) begin
            // reset all state contexts to init status, with all accumulators zero
            css <= {CFU_N_STATES{CFU_INIT}};
            zaccs <= '1;
        end
        else if (clk_en && wr) begin
            if (func == cfid_write_status) begin
                css[state] <= cs_nxt;
                // when context status becomes off or init, logically zero this state's accumulator
                if (cs_nxt == CFU_OFF || cs_nxt == CFU_INIT)
                    zaccs[state] <= 1;
            end
            else begin
                // context status becomes dirty when state is updated
                css[state] <= CFU_DIRTY;
                zaccs[state] <= 0;
                accs[state] <= resp_data;
            end
        end
    end
endmodule
