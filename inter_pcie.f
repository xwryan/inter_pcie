// inter_pcie 主 filelist：用大写 -F 引用（vcs -F <路径>/inter_pcie/inter_pcie.f），文件与 +incdir+ 都相对本文件目录，可在任意目录编译。
// 不拉入依赖：前置项目每个写一行 -F，依次为 aip_core/aip_core.f host_mem/host_mem.f dpu_common/dpu_common.f pcie_work/pcie_work.f。
// 只编译根入口 inter_pcie_pkg.sv；在自己的 package/module 内 `include "inter_pcie_import.svh" 即可 import 本项目的 package。
// bind wrapper 在 add-on inter_pcie_bind.f（绑定真实 DUT 用户侧网络时才加）。
+incdir+./
+incdir+./src
./inter_pcie_pkg.sv
