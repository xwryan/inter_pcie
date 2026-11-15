// AIP 寄存器访问回归入口；aip_core_pkg 已由 filelist_lib.f 最先编译，这里不再重复。
+incdir+$AIP_CORE_ROOT
+incdir+$AIP_CORE_ROOT/src/sv
-f $INTEL_PCIE_ROOT/sim/filelist_bind_env.f
$INTEL_PCIE_ROOT/tests/aip/intel_pcie_aip_reg_test.sv
