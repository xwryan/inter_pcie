// 完整 env 的 bind 回归：复用默认测试，-top 选 tb_intel_pcie_bind_env 或 tb_intel_pcie_bind_split_env；前置依次（主 filelist 与 add-on 都用 -F）：aip_core.f host_mem.f dpu_common.f pcie_work.f inter_pcie.f inter_pcie_bind.f
-f ${INTER_PCIE_ROOT}/sim/filelist_tests.f
${INTER_PCIE_ROOT}/tests/bind/tb_intel_pcie_bind_env.sv
