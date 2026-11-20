// inter_pcie 可选 add-on：R-Tile bind wrapper intel_pcie_bind_wrapper。
// 只在绑定真实 DUT 用户侧网络时加入，否则 wrapper 会成为多余顶层。
// 用大写 -F 引用（vcs -F <路径>/inter_pcie/inter_pcie_bind.f），路径相对本文件目录；不拉入依赖，前置每个写一行 -F，依次为 aip_core/aip_core.f host_mem/host_mem.f dpu_common/dpu_common.f pcie_work/pcie_work.f inter_pcie/inter_pcie.f。
./bind/intel_pcie_bind_wrapper.sv
