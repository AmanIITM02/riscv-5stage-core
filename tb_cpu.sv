module tb_cpu;
    logic clk;
    logic rst_n;
    logic [31:0] pc_out;
    logic [31:0] alu_result_out;

    cpu_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .pc_out(pc_out),
        .alu_result_out(alu_result_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim_trace.vcd");
        $dumpvars(0, tb_cpu);

        clk = 0;
        rst_n = 0;
        #10 rst_n = 1;

        #200;
        $display("\n[SUCCESS] Simulation Completed! Waveform written to sim_trace.vcd\n");
        $finish;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            $display("[Cycle] PC: 0x%h | ALU Result: %d", pc_out, alu_result_out);
        end
    end
endmodule
