// Intel R-Tile adapter 的唯一 UVM 编译入口，复用 pcie_tl_pkg 的 agent/sequence/TLP；
// intel_pcie_if 必须先于本 package 编译。
`include "intel_pcie_params.svh"
package intel_pcie_adapter_pkg;
    import uvm_pkg::*;
    import pcie_tl_pkg::*;
    `include "uvm_macros.svh"

    localparam int INTEL_DATA_WIDTH = `INTEL_PCIE_DATA_WIDTH;
    localparam int INTEL_SEGMENTS = `INTEL_PCIE_SEGMENTS;
    localparam int INTEL_DATA_BYTES = INTEL_DATA_WIDTH / 8;
    typedef virtual intel_pcie_if #(INTEL_DATA_WIDTH, INTEL_SEGMENTS) intel_pcie_vif_t;

    `include "intel_pcie_types.sv"
    `include "codec/intel_pcie_avst_codec.sv"
    `include "codec/intel_pcie_reassembler.sv"
    `include "adapter/intel_pcie_credit_manager.sv"
    `include "adapter/intel_pcie_if_adapter.sv"
    `include "adapter/intel_pcie_env_setup.sv"
endpackage
