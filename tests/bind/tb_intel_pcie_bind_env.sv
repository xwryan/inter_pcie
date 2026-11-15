// 完整 pcie_tl_env 经两个 bind wrapper（HARD_IP/APPLICATION）引脚互联的回归，数据只经 wrapper/net。
// 默认顶层两端来自同一 env，split 顶层来自两个单侧 env；接真实 DUT 时由 DUT 替换一端。
`include "intel_pcie_params.svh"

// 两个独立 interface 通过下列网络连接，验证分段数据、credit/ACK 的双向映射。
module intel_pcie_bind_env_link #(
  parameter string	RC_ADAPTER_PATH = "uvm_test_top.env.rc_adapter_0",
  parameter string	EP_ADAPTER_PATH = "uvm_test_top.env.ep_adapter"
);
  timeunit 1ns;
  timeprecision 1ps;
  localparam int DATA_WIDTH = `INTEL_PCIE_DATA_WIDTH;
  localparam int SEGMENTS = `INTEL_PCIE_SEGMENTS;
  localparam int DATA_PARITY_WORDS = DATA_WIDTH / 32;

  bit clk = 0;
  bit rst_n = 0;
  always #1ns clk = ~clk;
  initial begin
    repeat (8) @(negedge clk);
    rst_n = 1;
  end

  wire [SEGMENTS-1:0][DATA_WIDTH-1:0] rx_data;
  wire [SEGMENTS-1:0][127:0] rx_hdr;
  wire [SEGMENTS-1:0][31:0] rx_prefix;
  wire [SEGMENTS-1:0] rx_sop;
  wire [SEGMENTS-1:0] rx_eop;
  wire [SEGMENTS-1:0] rx_dvalid;
  wire [SEGMENTS-1:0] rx_hvalid;
  wire [SEGMENTS-1:0] rx_pvalid;
  wire [SEGMENTS-1:0][2:0] rx_empty;
  wire [SEGMENTS-1:0][2:0] rx_bar;
  wire [SEGMENTS-1:0][2:0] rx_pfnum;
  wire [SEGMENTS-1:0] rx_vfactive;
  wire [SEGMENTS-1:0][10:0] rx_vfnum;
  wire [SEGMENTS-1:0][DATA_PARITY_WORDS-1:0] rx_data_par;
  wire [SEGMENTS-1:0][3:0] rx_hdr_par;
  wire [SEGMENTS-1:0] rx_prefix_par;
  wire [SEGMENTS-1:0][DATA_WIDTH-1:0] tx_data;
  wire [SEGMENTS-1:0][127:0] tx_hdr;
  wire [SEGMENTS-1:0][31:0] tx_prefix;
  wire [SEGMENTS-1:0] tx_sop;
  wire [SEGMENTS-1:0] tx_eop;
  wire [SEGMENTS-1:0] tx_dvalid;
  wire [SEGMENTS-1:0] tx_hvalid;
  wire [SEGMENTS-1:0] tx_pvalid;
  wire [SEGMENTS-1:0][DATA_PARITY_WORDS-1:0] tx_data_par;
  wire [SEGMENTS-1:0][3:0] tx_hdr_par;
  wire [SEGMENTS-1:0] tx_prefix_par;
  wire rx_ready;
  wire tx_ready;
  wire [2:0] rx_hcrdt_init;
  wire [2:0] rx_hcrdt_init_ack;
  wire [2:0] rx_hcrdt_update;
  wire [5:0] rx_hcrdt_update_cnt;
  wire [2:0] rx_dcrdt_init;
  wire [2:0] rx_dcrdt_init_ack;
  wire [2:0] rx_dcrdt_update;
  wire [11:0] rx_dcrdt_update_cnt;
  wire [2:0] tx_hcrdt_init;
  wire [2:0] tx_hcrdt_init_ack;
  wire [2:0] tx_hcrdt_update;
  wire [5:0] tx_hcrdt_update_cnt;
  wire [2:0] tx_dcrdt_init;
  wire [2:0] tx_dcrdt_init_ack;
  wire [2:0] tx_dcrdt_update;
  wire [11:0] tx_dcrdt_update_cnt;
endmodule

bind intel_pcie_bind_env_link intel_pcie_bind_wrapper_inout #(
  .ADAPTER_PATH(RC_ADAPTER_PATH),
  .SIDE("HARD_IP")
) hard_bind (.*);

bind intel_pcie_bind_env_link intel_pcie_bind_wrapper_inout #(
  .ADAPTER_PATH(EP_ADAPTER_PATH),
  .SIDE("APPLICATION")
) application_bind (.*);

// time-0 发布完成后调整 cfg，再由现有 env 测试创建组件并运行流量。
module tb_intel_pcie_bind_env;
  timeunit 1ns;
  timeprecision 1ps;
  import uvm_pkg::*;
  import intel_pcie_tests_pkg::*;

  intel_pcie_bind_env_link link();

  initial begin
    #0;
    link.hard_bind.cfg.check_parity = 1;
    link.application_bind.cfg.check_parity = 1;
    run_test();
  end

  // 死锁必须以失败结束，不能因构建完成就算绑定成功。
  initial begin
    #1ms;
    $fatal(1, "bind env watchdog expired");
  end
endmodule

// 两个独立环境各持一端；复用同一 wire fixture，端口发布到不同 UVM 子树。
// 必须用 -top tb_intel_pcie_bind_split_env 单独编译，避免同时启动两个 run_test。
module tb_intel_pcie_bind_split_env;
  timeunit 1ns;
  timeprecision 1ps;
  import uvm_pkg::*;
  import intel_pcie_tests_pkg::*;

  intel_pcie_bind_env_link #(
    .RC_ADAPTER_PATH("uvm_test_top.env.rc_adapter_0"),
    .EP_ADAPTER_PATH("uvm_test_top.peer_env.ep_adapter")
  ) link();

  initial begin
    #0;
    link.hard_bind.cfg.check_parity = 1;
    link.application_bind.cfg.check_parity = 1;
    run_test();
  end

  // 读回或信用死锁必须显式失败，不能以阶段提前结束算通过。
  initial begin
    #1ms;
    $fatal(1, "split bind env watchdog expired");
  end
endmodule
