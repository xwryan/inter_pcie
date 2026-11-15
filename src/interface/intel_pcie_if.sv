// R-Tile 单端口 Avalon-ST 引脚接口：一个实例对应手册中的一个 pX，下标 N 对应 pX_*_stN_*。
// 每根信号只有一个驱动方：应用侧驱 TX、RX ready/RX credit；硬核侧（adapter 或真实 DUT）驱 RX、TX ready/TX credit。
`include "intel_pcie_params.svh"

interface intel_pcie_if #(
    parameter int DATA_WIDTH = `INTEL_PCIE_DATA_WIDTH,
    parameter int SEGMENTS = `INTEL_PCIE_SEGMENTS
)(input logic clk, input logic rst_n);

    // 低索引段在 PCIe 流中先出现。
    logic [SEGMENTS-1:0][DATA_WIDTH-1:0] rx_data, tx_data;
    logic [SEGMENTS-1:0][127:0] rx_hdr, tx_hdr;
    logic [SEGMENTS-1:0][31:0] rx_prefix, tx_prefix;
    logic [SEGMENTS-1:0] rx_sop, rx_eop, rx_dvalid, rx_hvalid, rx_pvalid;
    logic [SEGMENTS-1:0] tx_sop, tx_eop, tx_dvalid, tx_hvalid, tx_pvalid;
    logic [SEGMENTS-1:0][2:0] rx_empty, rx_bar, rx_pfnum;
    logic [SEGMENTS-1:0] rx_vfactive;
    logic [SEGMENTS-1:0][10:0] rx_vfnum;
    logic [SEGMENTS-1:0][DATA_WIDTH/32-1:0] rx_data_par, tx_data_par;
    logic [SEGMENTS-1:0][3:0] rx_hdr_par, tx_hdr_par;
    logic [SEGMENTS-1:0] rx_prefix_par, tx_prefix_par;
    logic rx_ready, tx_ready;

    // [0]/[1]/[2] 为 Posted/Non-Posted/Completion。
    // Header update 占 2 bit；Data update 占 4 bit，以 16 B 为一个 credit。
    logic [2:0] rx_hcrdt_init, rx_hcrdt_init_ack, rx_hcrdt_update;
    logic [5:0] rx_hcrdt_update_cnt;
    logic [2:0] rx_dcrdt_init, rx_dcrdt_init_ack, rx_dcrdt_update;
    logic [11:0] rx_dcrdt_update_cnt;
    logic [2:0] tx_hcrdt_init, tx_hcrdt_init_ack, tx_hcrdt_update;
    logic [5:0] tx_hcrdt_update_cnt;
    logic [2:0] tx_dcrdt_init, tx_dcrdt_init_ack, tx_dcrdt_update;
    logic [11:0] tx_dcrdt_update_cnt;

    // 采样沿前一个 time step 取值，消除 UVM 与 DUT NBA 的竞争。
    // Driver 在下降沿写输出；monitor_cb 只读，不能驱动对端拥有的 ACK。
    clocking monitor_cb @(posedge clk);
        default input #1step;
        input rst_n, rx_ready, tx_ready;
        input rx_data, rx_hdr, rx_prefix, rx_sop, rx_eop;
        input rx_dvalid, rx_hvalid, rx_pvalid, rx_empty, rx_bar;
        input rx_vfactive, rx_vfnum, rx_pfnum;
        input rx_data_par, rx_hdr_par, rx_prefix_par;
        input tx_data, tx_hdr, tx_prefix, tx_sop, tx_eop;
        input tx_dvalid, tx_hvalid, tx_pvalid;
        input tx_data_par, tx_hdr_par, tx_prefix_par;
        input rx_hcrdt_init, rx_hcrdt_init_ack, rx_hcrdt_update, rx_hcrdt_update_cnt;
        input rx_dcrdt_init, rx_dcrdt_init_ack, rx_dcrdt_update, rx_dcrdt_update_cnt;
        input tx_hcrdt_init, tx_hcrdt_init_ack, tx_hcrdt_update, tx_hcrdt_update_cnt;
        input tx_dcrdt_init, tx_dcrdt_init_ack, tx_dcrdt_update, tx_dcrdt_update_cnt;
    endclocking

    modport application (
        input clk, rst_n, rx_data, rx_hdr, rx_prefix, rx_sop, rx_eop,
              rx_dvalid, rx_hvalid, rx_pvalid, rx_empty, rx_bar, rx_pfnum,
              rx_vfactive, rx_vfnum, rx_data_par, rx_hdr_par, rx_prefix_par, tx_ready,
              rx_hcrdt_init_ack, rx_dcrdt_init_ack,
              tx_hcrdt_init, tx_hcrdt_update, tx_hcrdt_update_cnt,
              tx_dcrdt_init, tx_dcrdt_update, tx_dcrdt_update_cnt,
        output tx_data, tx_hdr, tx_prefix, tx_sop, tx_eop, tx_dvalid,
               tx_hvalid, tx_pvalid, tx_data_par, tx_hdr_par, tx_prefix_par, rx_ready,
               rx_hcrdt_init, rx_hcrdt_update, rx_hcrdt_update_cnt,
               rx_dcrdt_init, rx_dcrdt_update, rx_dcrdt_update_cnt,
               tx_hcrdt_init_ack, tx_dcrdt_init_ack
    );
endinterface
