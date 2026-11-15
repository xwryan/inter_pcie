// R-Tile Avalon-ST adapter 的值类型、端口配置与包对象。
// side 描述接口方向而非 RC/EP 角色：RC 用户 DUT 也需要 HARD_IP 方向的对端 BFM。
typedef enum {INTEL_PCIE_AUTO, INTEL_PCIE_APPLICATION, INTEL_PCIE_HARD_IP}
    intel_pcie_side_e;
typedef bit [7:0] intel_pcie_bytes_t[$];

typedef struct packed {
    logic [INTEL_SEGMENTS-1:0][INTEL_DATA_WIDTH-1:0] data;
    logic [INTEL_SEGMENTS-1:0][127:0] hdr;
    logic [INTEL_SEGMENTS-1:0][31:0] prefix;
    logic [INTEL_SEGMENTS-1:0] sop, eop, hvalid, dvalid, pvalid;
    logic [INTEL_SEGMENTS-1:0][2:0] empty, bar, pfnum;
    logic [INTEL_SEGMENTS-1:0] vfactive;
    logic [INTEL_SEGMENTS-1:0][10:0] vfnum;
    logic [INTEL_SEGMENTS-1:0][INTEL_DATA_WIDTH/32-1:0] data_par;
    logic [INTEL_SEGMENTS-1:0][3:0] hdr_par;
    logic [INTEL_SEGMENTS-1:0] prefix_par;
} intel_pcie_beat_t;

typedef struct packed {
    logic [2:0] hinit, dinit, hupdate, dupdate;
    logic [5:0] hcnt;
    logic [11:0] dcnt;
} intel_pcie_credit_pins_t;

// 每端口独立的方向、缓冲量和压力策略（不用全局 plusarg）。
class intel_pcie_adapter_config extends uvm_object;
    `uvm_object_utils(intel_pcie_adapter_config)

    intel_pcie_side_e side = INTEL_PCIE_AUTO;
    bit header_big_endian = `INTEL_PCIE_HEADER_BIG_ENDIAN;
    bit check_parity = 0;
    bit credit_enable = 1;
    // 下标为 P/NP/CPL；容量单位为 header 个数 / 16 B data credit。
    int unsigned header_capacity[3] = '{16,16,16};
    int unsigned data_capacity[3] = '{512,512,512};
    bit infinite_header[3] = '{0,0,0};
    bit infinite_data[3] = '{0,0,0};
    int unsigned tx_stop_latency = 1;
    int unsigned rx_gap_cycles = 0;
    int unsigned rx_start_segment = 0;
    bit x16_single_width = 0;

    function new(string name = "intel_pcie_adapter_config");
        super.new(name);
    endfunction

    function void validate();
        if (!((INTEL_DATA_WIDTH == 256 && INTEL_SEGMENTS inside {1,2,4}) ||
              (INTEL_DATA_WIDTH == 128 && INTEL_SEGMENTS inside {1,2})))
            `uvm_fatal("RTILE_CONFIG", "unsupported segment geometry")
        if (tx_stop_latency < 1 || tx_stop_latency > 16)
            `uvm_fatal("RTILE_CONFIG", "tx_stop_latency must be 1..16")
        if (rx_start_segment >= INTEL_SEGMENTS)
            `uvm_fatal("RTILE_CONFIG", "rx_start_segment exceeds port width")
        // 量产器件不会在 st0/st1 都空闲时只用 st2/st3 起包；重组器仍接受合法的 st2/st3 起包。
        if (INTEL_SEGMENTS == 4 && rx_start_segment >= 2)
            `uvm_fatal("RTILE_CONFIG", "standalone RX start must use st0/st1 on production devices")
        if (x16_single_width && !(INTEL_SEGMENTS == 2 && INTEL_DATA_WIDTH == 256))
            `uvm_fatal("RTILE_CONFIG", "x16 single-width requires 2 x 256 bits")
        foreach (header_capacity[i]) begin
            if (!infinite_header[i] && header_capacity[i] == 0)
                `uvm_fatal("RTILE_CONFIG", "finite header capacity must be nonzero")
            if (!infinite_data[i] && data_capacity[i] <= 32)
                `uvm_fatal("RTILE_CONFIG", "initial data credits must exceed 32")
        end
    endfunction
endclass

// 线上包快照（隔离调用者后续修改），保留完整 11-bit VF 号（公共模型 target_func 仅 8 bit）；
// completed/aborted 用于唤醒等待它的 send()。
class intel_pcie_packet extends uvm_object;
    `uvm_object_utils(intel_pcie_packet)
    bit [127:0] header;
    bit [31:0] prefix;
    bit prefix_valid;
    intel_pcie_bytes_t payload;
    int expected_bytes;
    int category;
    bit [2:0] bar, pfnum;
    bit vfactive;
    bit [10:0] vfnum;
    bit completed, aborted;

    function new(string name = "intel_pcie_packet");
        super.new(name);
    endfunction

    // 每 16 B 一个 data credit；无数据包只占 header credit。
    function int data_credits();
        return (expected_bytes + 15) / 16;
    endfunction
endclass
