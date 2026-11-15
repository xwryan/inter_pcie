// 向明确的 adapter 层次路径发布 vif（支持 rc_adapter_<n>/ep_adapter_<n>，不用跨端口通配）；
// 每条总线最多接一个 APPLICATION 和一个 HARD_IP，信号方向由 adapter 的 side 决定。
`ifndef INTEL_PCIE_ADAPTER_CONNECT_SVH
`define INTEL_PCIE_ADAPTER_CONNECT_SVH
`define INTEL_PCIE_ADAPTER_CONNECT(PATH, BUS) \
    uvm_config_db#(intel_pcie_adapter_pkg::intel_pcie_vif_t)::set(null, PATH, "vif", BUS);
`endif
