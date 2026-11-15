// 把 pcie_tl_env 接到 Intel 用户接口所需的固定配置集中在此，避免漏开 bridge 而误走公共 TLM 回环。

// 须在创建 env 前调用；parent=null 时 env_name 为完整 UVM 路径（不能含通配符）。
// 只替换该 env 子树内的 adapter 并发布 cfg/bridge；公共 FC 设为无限信用，有限信用由各端口 intel_cfg 控制。
function automatic void intel_pcie_configure_env(
    input uvm_component parent,
    input pcie_tl_env_config cfg,
    input string env_name = "env"
);
    string env_path;

    if (cfg == null) begin
        `uvm_fatal("RTILE_ENV_CONFIG", "intel_pcie_configure_env requires a non-null cfg")
        return;
    end
    if (env_name == "") begin
        `uvm_fatal("RTILE_ENV_CONFIG", "env_name must identify one env without wildcards")
        return;
    end
    for (int i = 0; i < env_name.len(); i++) begin
        if (env_name.getc(i) inside {"*", "?"}) begin
            `uvm_fatal("RTILE_ENV_CONFIG", "env_name must identify one env without wildcards")
            return;
        end
    end

    env_path = env_name;
    if (parent != null)
        if (parent.get_full_name() != "")
            env_path = {parent.get_full_name(), ".", env_name};

    pcie_tl_if_adapter::type_id::set_inst_override(
        intel_pcie_if_adapter::get_type(), {env_path, ".*"});
    cfg.if_mode = SV_IF_MODE;
    cfg.infinite_credit = 1;
    uvm_config_db#(pcie_tl_env_config)::set(parent, env_name, "cfg", cfg);
    uvm_config_db#(bit)::set(parent, env_name, "pcie_svt_bridge_required", 1'b1);
endfunction
