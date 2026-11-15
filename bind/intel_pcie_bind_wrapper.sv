// Intel R-Tile 用户侧 bind wrapper：把 intel_pcie_if 与 adapter 配置发布到 ADAPTER_PATH，不另建 adapter。
// DUT 用户侧端口须为 wire/tri net，方向由 SIDE 在 elaboration 时确定；
// 顶层须在 #0 之后调用 run_test()，保证 build_phase 前 config_db 已可见。
`include "intel_pcie_params.svh"

module intel_pcie_bind_wrapper_inout #(
    // 仅为兼容旧调用保留，只影响 cfg 对象名；接入路径由 ADAPTER_PATH 决定。
    parameter string ADAPTER_NAME = "",
    // 须与 pcie_tl_env 中的 adapter 实例路径一致：单 RC 为 rc_adapter_0，单 EP 为 ep_adapter，
    // 多 RC/EP 为 rc_adapter_<n>/ep_adapter_<n>。
    parameter string ADAPTER_PATH = "uvm_test_top.env.rc_adapter_0",
    // HARD_IP: wrapper 驱动 RX/tx_ready/TX credit；APPLICATION: 驱动
    // TX/rx_ready/RX credit。大小写必须使用这两个固定值。
    parameter string SIDE = "HARD_IP",
    localparam int DATA_WIDTH = `INTEL_PCIE_DATA_WIDTH,
    localparam int SEGMENTS = `INTEL_PCIE_SEGMENTS,
    localparam int DATA_PARITY_WORDS = DATA_WIDTH / 32
) (
    input wire clk,
    input wire rst_n,

    // 高位段对应较大的 st 编号，bind 时按 {stN,...,st0} 连接以匹配 interface 的 packed 数组。
    inout wire [SEGMENTS-1:0][DATA_WIDTH-1:0] rx_data,
    inout wire [SEGMENTS-1:0][127:0] rx_hdr,
    inout wire [SEGMENTS-1:0][31:0] rx_prefix,
    inout wire [SEGMENTS-1:0] rx_sop,
    inout wire [SEGMENTS-1:0] rx_eop,
    inout wire [SEGMENTS-1:0] rx_dvalid,
    inout wire [SEGMENTS-1:0] rx_hvalid,
    inout wire [SEGMENTS-1:0] rx_pvalid,
    inout wire [SEGMENTS-1:0][2:0] rx_empty,
    inout wire [SEGMENTS-1:0][2:0] rx_bar,
    inout wire [SEGMENTS-1:0][2:0] rx_pfnum,
    inout wire [SEGMENTS-1:0] rx_vfactive,
    inout wire [SEGMENTS-1:0][10:0] rx_vfnum,
    inout wire [SEGMENTS-1:0][DATA_PARITY_WORDS-1:0] rx_data_par,
    inout wire [SEGMENTS-1:0][3:0] rx_hdr_par,
    inout wire [SEGMENTS-1:0] rx_prefix_par,

    // TX 没有 empty/bar/function 路由字段。
    inout wire [SEGMENTS-1:0][DATA_WIDTH-1:0] tx_data,
    inout wire [SEGMENTS-1:0][127:0] tx_hdr,
    inout wire [SEGMENTS-1:0][31:0] tx_prefix,
    inout wire [SEGMENTS-1:0] tx_sop,
    inout wire [SEGMENTS-1:0] tx_eop,
    inout wire [SEGMENTS-1:0] tx_dvalid,
    inout wire [SEGMENTS-1:0] tx_hvalid,
    inout wire [SEGMENTS-1:0] tx_pvalid,
    inout wire [SEGMENTS-1:0][DATA_PARITY_WORDS-1:0] tx_data_par,
    inout wire [SEGMENTS-1:0][3:0] tx_hdr_par,
    inout wire [SEGMENTS-1:0] tx_prefix_par,

    // ready/credit 也是 inout，同一 wrapper 可用于两种 SIDE；generate 只为当前 SIDE 驱动一侧。
    inout wire rx_ready,
    inout wire tx_ready,
    inout wire [2:0] rx_hcrdt_init,
    inout wire [2:0] rx_hcrdt_init_ack,
    inout wire [2:0] rx_hcrdt_update,
    inout wire [5:0] rx_hcrdt_update_cnt,
    inout wire [2:0] rx_dcrdt_init,
    inout wire [2:0] rx_dcrdt_init_ack,
    inout wire [2:0] rx_dcrdt_update,
    inout wire [11:0] rx_dcrdt_update_cnt,
    inout wire [2:0] tx_hcrdt_init,
    inout wire [2:0] tx_hcrdt_init_ack,
    inout wire [2:0] tx_hcrdt_update,
    inout wire [5:0] tx_hcrdt_update_cnt,
    inout wire [2:0] tx_dcrdt_init,
    inout wire [2:0] tx_dcrdt_init_ack,
    inout wire [2:0] tx_dcrdt_update,
    inout wire [11:0] tx_dcrdt_update_cnt
);
    import uvm_pkg::*;
    import intel_pcie_adapter_pkg::*;

    localparam bit IS_HARD_IP = (SIDE == "HARD_IP");
    localparam bit IS_APPLICATION = (SIDE == "APPLICATION");

    intel_pcie_if #(DATA_WIDTH, SEGMENTS) u_intel_pcie_if(clk, rst_n);
    // 可在顶层 #0 后、run_test 前调整 cfg 的行为字段；cfg.side 不可改，网络方向已由 SIDE 固定。
    intel_pcie_adapter_config cfg;
    string resolved_name;

    // adapter 输入方向的 interface 字段由连续赋值采样 DUT 网络（adapter 不写它们，无多重驱动）；
    // 网络冲突产生的 X 会原样进入 interface。
    generate
        if (IS_HARD_IP) begin : g_hard_input
            assign u_intel_pcie_if.tx_data = tx_data;
            assign u_intel_pcie_if.tx_hdr = tx_hdr;
            assign u_intel_pcie_if.tx_prefix = tx_prefix;
            assign u_intel_pcie_if.tx_sop = tx_sop;
            assign u_intel_pcie_if.tx_eop = tx_eop;
            assign u_intel_pcie_if.tx_dvalid = tx_dvalid;
            assign u_intel_pcie_if.tx_hvalid = tx_hvalid;
            assign u_intel_pcie_if.tx_pvalid = tx_pvalid;
            assign u_intel_pcie_if.tx_data_par = tx_data_par;
            assign u_intel_pcie_if.tx_hdr_par = tx_hdr_par;
            assign u_intel_pcie_if.tx_prefix_par = tx_prefix_par;
            assign u_intel_pcie_if.rx_ready = rx_ready;
            assign u_intel_pcie_if.rx_hcrdt_init = rx_hcrdt_init;
            assign u_intel_pcie_if.rx_hcrdt_update = rx_hcrdt_update;
            assign u_intel_pcie_if.rx_hcrdt_update_cnt = rx_hcrdt_update_cnt;
            assign u_intel_pcie_if.rx_dcrdt_init = rx_dcrdt_init;
            assign u_intel_pcie_if.rx_dcrdt_update = rx_dcrdt_update;
            assign u_intel_pcie_if.rx_dcrdt_update_cnt = rx_dcrdt_update_cnt;
            assign u_intel_pcie_if.tx_hcrdt_init_ack = tx_hcrdt_init_ack;
            assign u_intel_pcie_if.tx_dcrdt_init_ack = tx_dcrdt_init_ack;
        end
        else if (IS_APPLICATION) begin : g_application_input
            assign u_intel_pcie_if.rx_data = rx_data;
            assign u_intel_pcie_if.rx_hdr = rx_hdr;
            assign u_intel_pcie_if.rx_prefix = rx_prefix;
            assign u_intel_pcie_if.rx_sop = rx_sop;
            assign u_intel_pcie_if.rx_eop = rx_eop;
            assign u_intel_pcie_if.rx_dvalid = rx_dvalid;
            assign u_intel_pcie_if.rx_hvalid = rx_hvalid;
            assign u_intel_pcie_if.rx_pvalid = rx_pvalid;
            assign u_intel_pcie_if.rx_empty = rx_empty;
            assign u_intel_pcie_if.rx_bar = rx_bar;
            assign u_intel_pcie_if.rx_pfnum = rx_pfnum;
            assign u_intel_pcie_if.rx_vfactive = rx_vfactive;
            assign u_intel_pcie_if.rx_vfnum = rx_vfnum;
            assign u_intel_pcie_if.rx_data_par = rx_data_par;
            assign u_intel_pcie_if.rx_hdr_par = rx_hdr_par;
            assign u_intel_pcie_if.rx_prefix_par = rx_prefix_par;
            assign u_intel_pcie_if.tx_ready = tx_ready;
            assign u_intel_pcie_if.tx_hcrdt_init = tx_hcrdt_init;
            assign u_intel_pcie_if.tx_hcrdt_update = tx_hcrdt_update;
            assign u_intel_pcie_if.tx_hcrdt_update_cnt = tx_hcrdt_update_cnt;
            assign u_intel_pcie_if.tx_dcrdt_init = tx_dcrdt_init;
            assign u_intel_pcie_if.tx_dcrdt_update = tx_dcrdt_update;
            assign u_intel_pcie_if.tx_dcrdt_update_cnt = tx_dcrdt_update_cnt;
            assign u_intel_pcie_if.rx_hcrdt_init_ack = rx_hcrdt_init_ack;
            assign u_intel_pcie_if.rx_dcrdt_init_ack = rx_dcrdt_init_ack;
        end
    endgenerate

    // adapter 输出以 supply 强度驱动绑定点；未拥有的方向保持 Z，避免与 DUT 输出竞争。
    generate
        if (IS_HARD_IP) begin : g_hard_output
            assign (supply1, supply0) rx_data = u_intel_pcie_if.rx_data;
            assign (supply1, supply0) rx_hdr = u_intel_pcie_if.rx_hdr;
            assign (supply1, supply0) rx_prefix = u_intel_pcie_if.rx_prefix;
            assign (supply1, supply0) rx_sop = u_intel_pcie_if.rx_sop;
            assign (supply1, supply0) rx_eop = u_intel_pcie_if.rx_eop;
            assign (supply1, supply0) rx_dvalid = u_intel_pcie_if.rx_dvalid;
            assign (supply1, supply0) rx_hvalid = u_intel_pcie_if.rx_hvalid;
            assign (supply1, supply0) rx_pvalid = u_intel_pcie_if.rx_pvalid;
            assign (supply1, supply0) rx_empty = u_intel_pcie_if.rx_empty;
            assign (supply1, supply0) rx_bar = u_intel_pcie_if.rx_bar;
            assign (supply1, supply0) rx_pfnum = u_intel_pcie_if.rx_pfnum;
            assign (supply1, supply0) rx_vfactive = u_intel_pcie_if.rx_vfactive;
            assign (supply1, supply0) rx_vfnum = u_intel_pcie_if.rx_vfnum;
            assign (supply1, supply0) rx_data_par = u_intel_pcie_if.rx_data_par;
            assign (supply1, supply0) rx_hdr_par = u_intel_pcie_if.rx_hdr_par;
            assign (supply1, supply0) rx_prefix_par = u_intel_pcie_if.rx_prefix_par;
            assign (supply1, supply0) tx_ready = u_intel_pcie_if.tx_ready;
            assign (supply1, supply0) tx_hcrdt_init = u_intel_pcie_if.tx_hcrdt_init;
            assign (supply1, supply0) tx_hcrdt_update = u_intel_pcie_if.tx_hcrdt_update;
            assign (supply1, supply0) tx_hcrdt_update_cnt = u_intel_pcie_if.tx_hcrdt_update_cnt;
            assign (supply1, supply0) tx_dcrdt_init = u_intel_pcie_if.tx_dcrdt_init;
            assign (supply1, supply0) tx_dcrdt_update = u_intel_pcie_if.tx_dcrdt_update;
            assign (supply1, supply0) tx_dcrdt_update_cnt = u_intel_pcie_if.tx_dcrdt_update_cnt;
            assign (supply1, supply0) rx_hcrdt_init_ack = u_intel_pcie_if.rx_hcrdt_init_ack;
            assign (supply1, supply0) rx_dcrdt_init_ack = u_intel_pcie_if.rx_dcrdt_init_ack;
        end
        else if (IS_APPLICATION) begin : g_application_output
            assign (supply1, supply0) tx_data = u_intel_pcie_if.tx_data;
            assign (supply1, supply0) tx_hdr = u_intel_pcie_if.tx_hdr;
            assign (supply1, supply0) tx_prefix = u_intel_pcie_if.tx_prefix;
            assign (supply1, supply0) tx_sop = u_intel_pcie_if.tx_sop;
            assign (supply1, supply0) tx_eop = u_intel_pcie_if.tx_eop;
            assign (supply1, supply0) tx_dvalid = u_intel_pcie_if.tx_dvalid;
            assign (supply1, supply0) tx_hvalid = u_intel_pcie_if.tx_hvalid;
            assign (supply1, supply0) tx_pvalid = u_intel_pcie_if.tx_pvalid;
            assign (supply1, supply0) tx_data_par = u_intel_pcie_if.tx_data_par;
            assign (supply1, supply0) tx_hdr_par = u_intel_pcie_if.tx_hdr_par;
            assign (supply1, supply0) tx_prefix_par = u_intel_pcie_if.tx_prefix_par;
            assign (supply1, supply0) rx_ready = u_intel_pcie_if.rx_ready;
            assign (supply1, supply0) rx_hcrdt_init = u_intel_pcie_if.rx_hcrdt_init;
            assign (supply1, supply0) rx_hcrdt_update = u_intel_pcie_if.rx_hcrdt_update;
            assign (supply1, supply0) rx_hcrdt_update_cnt = u_intel_pcie_if.rx_hcrdt_update_cnt;
            assign (supply1, supply0) rx_dcrdt_init = u_intel_pcie_if.rx_dcrdt_init;
            assign (supply1, supply0) rx_dcrdt_update = u_intel_pcie_if.rx_dcrdt_update;
            assign (supply1, supply0) rx_dcrdt_update_cnt = u_intel_pcie_if.rx_dcrdt_update_cnt;
            assign (supply1, supply0) tx_hcrdt_init_ack = u_intel_pcie_if.tx_hcrdt_init_ack;
            assign (supply1, supply0) tx_dcrdt_init_ack = u_intel_pcie_if.tx_dcrdt_init_ack;
        end
    endgenerate

    // time-0 发布配置；参数非法直接 fatal，避免 adapter 以默认方向运行。
    initial begin : publish_config
        string name_for_cfg;
        if (!IS_HARD_IP && !IS_APPLICATION)
            $fatal(1, "INTEL_PCIE_BIND_SIDE: SIDE must be HARD_IP or APPLICATION, got '%s'", SIDE);
        if (ADAPTER_PATH == "")
            $fatal(1, "INTEL_PCIE_BIND_PATH: ADAPTER_PATH must identify one pcie_tl adapter");
        resolved_name = ADAPTER_NAME;
        if (resolved_name == "") begin
            resolved_name = $sformatf("%m");
            for (int i = 0; i < resolved_name.len(); i++)
                if (!(resolved_name.getc(i) inside { ["a":"z"], ["A":"Z"], ["0":"9"], "_" }))
                    resolved_name.putc(i, "_");
        end
        else begin
            for (int i = 0; i < resolved_name.len(); i++)
                if (!(resolved_name.getc(i) inside { ["a":"z"], ["A":"Z"], ["0":"9"], "_" }))
                    $fatal(1, "INTEL_PCIE_BIND_NAME: ADAPTER_NAME must contain only letters, digits and underscore");
        end
        name_for_cfg = {resolved_name, "_cfg"};
        cfg = intel_pcie_adapter_config::type_id::create(name_for_cfg);
        cfg.side = IS_HARD_IP ? INTEL_PCIE_HARD_IP : INTEL_PCIE_APPLICATION;
        cfg.validate();
        uvm_config_db#(intel_pcie_vif_t)::set(null, ADAPTER_PATH, "vif", u_intel_pcie_if);
        uvm_config_db#(intel_pcie_adapter_config)::set(null, ADAPTER_PATH, "intel_cfg", cfg);
    end
endmodule
