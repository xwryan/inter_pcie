// 逐拍按 segment 顺序重组 AVST 包，最多持有一个半包；不依赖接口，便于用手工波形单独验证。
// RX 可有 dvalid 空拍，TX 仅在反压时可停顿；empty 只对 RX EOP 数据段有意义。
class intel_pcie_reassembler extends uvm_object;
    `uvm_object_utils(intel_pcie_reassembler)
    intel_pcie_avst_codec codec;
    intel_pcie_adapter_config cfg;
    intel_pcie_packet active;

    function new(string name = "intel_pcie_reassembler");
        super.new(name);
    endfunction

    // 丢弃半包；之后的第一个有效段必须重新带 SOP/Header。
    function void reset();
        active = null;
    endfunction

    // 无效 segment 上的 SOP/EOP 不解释；截断包报 UVM_ERROR 并丢弃，不当作成功 TLP。
    function void consume(intel_pcie_beat_t beat, bit tx_side, bit ready,
                         output intel_pcie_packet started[$],
                         output intel_pcie_packet done[$]);
        int nbytes, remain, nsop;
        bit valid, bad_data;

        started.delete(); done.delete(); nsop = 0;
        for (int s = 0; s < INTEL_SEGMENTS; s++) begin
            if ($isunknown({beat.hvalid[s],beat.dvalid[s],beat.pvalid[s]})) begin
                `uvm_error("RTILE_CONTROL_X", "unknown segment valid")
                continue;
            end
            valid = beat.hvalid[s] || beat.dvalid[s];
            if (!valid) begin
                if (beat.pvalid[s])
                    `uvm_error("RTILE_HEADER", "Prefix without a valid Header segment")
                if (tx_side && ready && active != null)
                    `uvm_error("RTILE_TX_GAP", "idle segment inside unpaused TX TLP")
                continue;
            end
            if ($isunknown({beat.sop[s],beat.eop[s]})) begin
                `uvm_error("RTILE_CONTROL_X", "unknown SOP/EOP")
                continue;
            end
            if (beat.sop[s]) begin
                nsop++;
                if (active != null) begin
                    `uvm_error("RTILE_SOP", "new SOP before previous EOP")
                    active = null;
                end
                if (!beat.hvalid[s]) begin
                    `uvm_error("RTILE_HEADER", "SOP requires hvalid")
                    continue;
                end
                // packet/TLP 是 2-state，须先查 X，否则 X 变 0 会造出看似成功的 TLP。
                if (!known_header(beat,s)) begin
                    `uvm_error("RTILE_CONTENT_X", "unknown valid Header or Prefix")
                    active = null;
                    continue;
                end
                if (tx_side && INTEL_SEGMENTS == 4 && (s % 2) != 0)
                    `uvm_error("RTILE_TX_START", "x16 double-width SOP only allowed on st0/st2")
                // 用 s-1 而非常量 st1，单段配置下不会静态越界；s=2 时允许前包在 st0 结束、st1 空闲。
                if (tx_side && s != 0 &&
                    !(beat.dvalid[0] && (beat.eop[s-1] ||
                      (s == 2 && beat.eop[0] && !beat.dvalid[s-1]))))
                    `uvm_error("RTILE_TX_START", "later SOP requires preceding data TLP to end")
                active = new("received_packet");
                active.header = beat.hdr[s];
                active.prefix = beat.prefix[s]; active.prefix_valid = beat.pvalid[s];
                active.expected_bytes = codec.payload_length(active.header);
                active.category = codec.category_of(active.header);
                active.bar = beat.bar[s]; active.pfnum = beat.pfnum[s];
                active.vfactive = beat.vfactive[s]; active.vfnum = beat.vfnum[s];
                started.push_back(active);
            end
            else if (beat.hvalid[s] || beat.pvalid[s])
                `uvm_error("RTILE_HEADER", "Header/Prefix outside SOP")
            if (active == null) begin
                `uvm_error("RTILE_ORPHAN", "data/EOP without an active TLP")
                continue;
            end
            if (cfg.check_parity) check_segment_parity(beat, s);
            if (beat.dvalid[s]) begin
                remain = active.expected_bytes - active.payload.size();
                nbytes = INTEL_DATA_BYTES;
                if (beat.eop[s]) begin
                    if (tx_side) nbytes = (remain < INTEL_DATA_BYTES) ? remain : INTEL_DATA_BYTES;
                    else begin
                        if ($isunknown(beat.empty[s])) begin
                            `uvm_error("RTILE_CONTENT_X", "unknown RX empty at EOP")
                            active = null;
                            continue;
                        end
                        nbytes -= int'(beat.empty[s])*4;
                    end
                end
                if (nbytes <= 0 || nbytes > remain) begin
                    `uvm_error("RTILE_LENGTH", "invalid empty or Payload exceeds declared Length")
                    active = null;
                    continue;
                end
                bad_data = 0;
                for (int b = 0; b < nbytes; b++)
                    bad_data |= $isunknown(beat.data[s][b*8 +: 8]);
                if (bad_data) begin
                    `uvm_error("RTILE_CONTENT_X", "unknown valid Payload byte")
                    active = null;
                    continue;
                end
                for (int b = 0; b < nbytes; b++)
                    active.payload.push_back(beat.data[s][b*8 +: 8]);
            end
            if (beat.eop[s]) begin
                if (active.payload.size() != active.expected_bytes)
                    `uvm_error("RTILE_LENGTH", "EOP before declared Payload completed")
                else begin active.completed = 1; done.push_back(active); end
                active = null;
            end
        end
        if (!tx_side && nsop > 3)
            `uvm_error("RTILE_RX_START", "more than three RX SOPs in one cycle")
        if (tx_side && cfg.x16_single_width && nsop > 1)
            `uvm_error("RTILE_TX_START", "x16 single-width permits one SOP per cycle")
    endfunction

    // 只查实际占用的 3/4 个 Header DW 与有效 Prefix，其余为 don't-care；
    // 必须直接读 4-state beat：codec.header_dw 返回 bit，会吞掉 X。
    function bit known_header(intel_pcie_beat_t b, int s);
        logic [31:0] dw0, dw;
        int count;
        dw0 = codec.header_big_endian ? b.hdr[s][127:96] : b.hdr[s][31:0];
        if ($isunknown(dw0)) return 0;
        count = dw0[29] ? 4 : 3;
        for (int n = 1; n < count; n++) begin
            dw = codec.header_big_endian ? b.hdr[s][127-32*n -: 32] : b.hdr[s][32*n +: 32];
            if ($isunknown(dw)) return 0;
        end
        return !b.pvalid[s] || !$isunknown(b.prefix[s]);
    endfunction

    // 可选 32:1 XOR 校验；无效总线不检查，避免把 don't-care 当错误。
    function void check_segment_parity(intel_pcie_beat_t b, int s);
        if (b.hvalid[s])
            for (int n = 0; n < 4; n++)
                if (b.hdr_par[s][n] !== ^b.hdr[s][32*n +: 32])
                    `uvm_error("RTILE_PARITY", "header parity mismatch")
        if (b.dvalid[s])
            for (int n = 0; n < INTEL_DATA_WIDTH/32; n++)
                if (b.data_par[s][n] !== ^b.data[s][32*n +: 32])
                    `uvm_error("RTILE_PARITY", "data parity mismatch")
        if (b.pvalid[s] && b.prefix_par[s] !== ^b.prefix[s])
            `uvm_error("RTILE_PARITY", "prefix parity mismatch")
    endfunction
endclass
