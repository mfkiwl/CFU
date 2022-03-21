// Copyright (C) 2019, Gray Research LLC

`define vp /* verilator public */
`define vloff_width /* verilator lint_off WIDTH */
`define vlon_width /* verilator lint_on WIDTH */

`define CFU_INTERFACE_ID    [CFU_INTERFACE_ID_W-1:0]
`define CFU_FUNCTION_ID     [CFU_FUNCTION_ID_W-1:0]
`define CFU_FUNC_ID         [CFU_FUNC_ID_W-1:0]
`define CFU_REORDER_ID      [CFU_REORDER_ID_W-1:0]
`define CFU_REQ_RESP_ID     [CFU_REQ_RESP_ID_W-1:0]
`define CFU_REQ_DATA        [CFU_REQ_DATA_W-1:0]
`define CFU_RESP_DATA       [CFU_RESP_DATA_W-1:0]
`define CFU_ERROR_ID        [CFU_ERROR_ID_W-1:0]
`define CFU_ERR_ID          [CFU_ERR_ID_W-1:0]

`define CFU_DATA            [CFU_RESP_DATA_W-1:0]

`define CFU_L0_PARAMETERS(INPUTS,DEF_WIDTH) \
    parameter CFU_FUNCTION_ID_W = 16, \
    parameter CFU_REQ_INPUTS = INPUTS, \
    parameter CFU_REQ_DATA_W = DEF_WIDTH, \
    parameter CFU_RESP_OUTPUTS = 1, \
    parameter CFU_RESP_DATA_W = DEF_WIDTH
