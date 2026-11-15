// 集成回归：真实复用 pcie_tl_env、双向 requester/responder、统一内存与 rw_seq，经 Intel 引脚收发。
class intel_pcie_env_test extends uvm_test;
    `uvm_component_utils(intel_pcie_env_test)

    pcie_tl_env	          env;
    host_mem_manager	  host_manager;
    host_mem_manager	  device_manager;

    function new(string name = "intel_pcie_env_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        pcie_tl_env_config	c;
        pcie_tl_if_adapter	unrelated_adapter;
        string	            why;
        super.build_phase(phase);
        c = pcie_tl_env_config::type_id::create("cfg");
        c.rc_agent_enable = 1;
        c.ep_agent_enable = 1;
        c.ep_auto_response = 1;
        c.use_unified_mem = 1;
        c.scb_enable = 1;
        c.cpl_timeout_ns = 100000;

        // use_unified_mem 不会自动创建后备存储，必须显式注入独立的 Host/Device manager。
        host_manager = new("host_manager");
        device_manager = new("device_manager");
        host_manager.set_host_id(0);
        if (!c.bind_host_memory(0, 0, host_manager, why))
            `uvm_fatal("TEST_MEMORY", why)
        uvm_config_db#(host_mem_api)::set(this, "env", "dev_mem_0", device_manager);

        intel_pcie_configure_env(this, c);
        env = pcie_tl_env::type_id::create("env", this);

        // 在 env 之外创建一个公共 adapter，确认 override 只作用于本 env 子树。
        unrelated_adapter = pcie_tl_if_adapter::type_id::create("unrelated_adapter", this);
        if (unrelated_adapter.get_object_type() != pcie_tl_if_adapter::get_type())
            `uvm_fatal("ENV_FACTORY_SCOPE", "Intel override escaped the configured env")
    endfunction

    // RC->EP、EP->Host 都先 WRITE 再 READ，检查真实部分字节 BE 的端到端结果。
    // Completion 须经对端 adapter 回到公共 driver，才能释放 Tag、结束 rw_seq。
    task run_phase(uvm_phase phase);
        pcie_tl_rw_seq	wr;
        pcie_tl_rw_seq	rd;
        bit [63:0]	    address;
        int	          length_bytes = 137;

        phase.raise_objection(this);
        for (int side = 0; side < 2; side++) begin
            if (side == 0) address = env.dev_mem[0].alloc(256, 64);
            else address = env.host_mem.alloc(256, 64);

            wr = pcie_tl_rw_seq::type_id::create("write");
            wr.op = PCIE_RW_WRITE;
            wr.addr = address + 1;
            wr.byte_len = length_bytes;
            wr.wdata = new[length_bytes];
            foreach (wr.wdata[i]) wr.wdata[i] = 8'(i * 19 + side);
            if (side == 0) wr.start(env.rc_agent.sequencer);
            else wr.start(env.ep_agent.sequencer);

            rd = pcie_tl_rw_seq::type_id::create("read");
            rd.op = PCIE_RW_READ;
            rd.addr = address + 1;
            rd.byte_len = length_bytes;
            if (side == 0) rd.start(env.rc_agent.sequencer);
            else rd.start(env.ep_agent.sequencer);

            if (rd.status != PCIE_RW_OK || rd.rdata.size() != length_bytes)
                `uvm_fatal("ENV_READBACK", "public rw_seq did not complete")
            foreach (wr.wdata[i])
                if (rd.rdata[i] !== wr.wdata[i])
                    `uvm_fatal("ENV_READBACK", $sformatf("side=%0d byte=%0d mismatch", side, i))
            if (side == 0) env.dev_mem[0].free(address);
            else env.host_mem.free(address);
        end
        // monitor 与 requester 的完成处理可能同拍结束；让所有观察回调先排空。
        #20ns;
        check_scb_counts(4, 2, 6);
        `uvm_info("RTILE_TEST_PASS", "pcie_work env/rw_seq: bidirectional 137-byte unaligned write/read and SCB matched",UVM_LOW)
        phase.drop_objection(this);
    endtask

    // 精确计数，防止 TX 预登记与 RX monitor 重复计数；
    // expected_completions=-1 用于分片数随地址变化的压力场景。
    function void check_scb_counts(int expected_requests, int expected_matched,
                                   int expected_completions = -1);
        if (env.scb == null)
            `uvm_fatal("ENV_SCB", "scoreboard must be enabled")
        if (env.scb.total_requests != expected_requests ||
            env.scb.matched != expected_matched ||
            (expected_completions >= 0 &&
             env.scb.total_completions != expected_completions))
            `uvm_error("ENV_SCB_COUNT", $sformatf(
                "requests=%0d/%0d matched=%0d/%0d completions=%0d/%0d",
                env.scb.total_requests, expected_requests, env.scb.matched,
                expected_matched, env.scb.total_completions, expected_completions))
    endfunction

    // 所有派生压力测试都必须排空 pending 和分片表；读回成功不能代替 SCB 清账。
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (env.scb == null)
            `uvm_fatal("ENV_SCB", "scoreboard must be enabled")
        if (env.scb.unexpected != 0 || env.scb.mismatched != 0 ||
            env.scb.timed_out != 0 || env.scb.pending_requests.num() != 0 ||
            env.scb.cpl_trackers.num() != 0)
            `uvm_error("ENV_SCB", $sformatf(
                "unexpected=%0d mismatched=%0d timed_out=%0d pending=%0d trackers=%0d",
                env.scb.unexpected, env.scb.mismatched, env.scb.timed_out,
                env.scb.pending_requests.num(), env.scb.cpl_trackers.num()))
    endfunction
endclass
