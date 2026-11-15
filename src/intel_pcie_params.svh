// Intel R-Tile Avalon-ST 适配层的编译期参数，均可用 +define+ 覆盖。

`ifndef INTEL_PCIE_PARAMS_SVH
`define INTEL_PCIE_PARAMS_SVH

// 默认配置对应 R-Tile 1x16 double-width：四个 256-bit segment。
`ifndef INTEL_PCIE_DATA_WIDTH
`define INTEL_PCIE_DATA_WIDTH 256
`endif

`ifndef INTEL_PCIE_SEGMENTS
`define INTEL_PCIE_SEGMENTS 4
`endif

`ifndef INTEL_PCIE_HEADER_BIG_ENDIAN
`define INTEL_PCIE_HEADER_BIG_ENDIAN 1
`endif

`endif
