// 测试专用复位控制（不属于 DUT 端口）：初始复位由 top 发起，之后只由 reset 测试调用，不可并发驱动。
interface intel_pcie_test_control_if(input logic clk);
    logic rst_n = 0;

    // 在下降沿改变复位，避免与采样沿竞争。
    task reset_cycles(int cycles = 5);
        @(negedge clk);
        rst_n = 0;
        repeat (cycles) @(negedge clk);
        rst_n = 1;
    endtask
endinterface
