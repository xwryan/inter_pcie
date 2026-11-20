// inter_pcie 根入口：inter_pcie.f 唯一编译的源文件，按原编译顺序 include 本项目的全部源码（package、interface、module）；
// 路径相对仓库根目录，经 inter_pcie.f 的 +incdir+./ 解析。依赖项目须先经各自的 filelist 编译。
`ifndef INTER_PCIE_PKG_SV
`define INTER_PCIE_PKG_SV
`include "src/interface/intel_pcie_if.sv"
`include "src/adapter/intel_pcie_adapter_pkg.sv"
`endif // INTER_PCIE_PKG_SV
