// 默认回归的测试与顶层 tb_intel_pcie；前置依次：aip_core.f host_mem.f pcie_work.f inter_pcie.f
+incdir+${INTER_PCIE_ROOT}/tests
+incdir+${INTER_PCIE_ROOT}/tb
${INTER_PCIE_ROOT}/tb/intel_pcie_test_control_if.sv
${INTER_PCIE_ROOT}/tests/intel_pcie_tests_pkg.sv
${INTER_PCIE_ROOT}/tb/tb_intel_pcie.sv
