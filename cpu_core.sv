// cpu_core.sv - RV32I 5-Stage Pipelined Processor
module cpu_core (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] pc_out,
    output logic [31:0] alu_result_out
);

    // Pipeline Registers
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr;
    } if_id_reg_t;

    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] rs1_data;
        logic [31:0] rs2_data;
        logic [31:0] imm;
        logic [4:0]  rd;
        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [2:0]  funct3;
        logic        reg_write;
        logic        alu_src;
        logic [3:0]  alu_op;
    } id_ex_reg_t;

    typedef struct packed {
        logic [31:0] alu_result;
        logic [31:0] rs2_data;
        logic [4:0]  rd;
        logic        reg_write;
    } ex_mem_reg_t;

    typedef struct packed {
        logic [31:0] result_data;
        logic [4:0]  rd;
        logic        reg_write;
    } mem_wb_reg_t;

    if_id_reg_t  if_id;
    id_ex_reg_t  id_ex;
    ex_mem_reg_t ex_mem;
    mem_wb_reg_t mem_wb;

    // Registers & Memory
    logic [31:0] pc;
    logic [31:0] reg_file [0:31];
    logic [31:0] imem [0:255]; // 256-word Instruction Memory

    assign pc_out = pc;
    assign alu_result_out = ex_mem.alu_result;

    // Initialize Register File and Pre-load Test Instructions
    initial begin
        integer i;
        for (i = 0; i < 32; i = i + 1) reg_file[i] = 32'h0;
        for (i = 0; i < 256; i = i + 1) imem[i] = 32'h00000013; // NOP (addi x0, x0, 0)

        // Load RISC-V Test Program:
        imem[0] = 32'h00500093; // addi x1, x0, 5   (x1 = 5)
        imem[1] = 32'h00a00113; // addi x2, x0, 10  (x2 = 10)
        imem[2] = 32'h002081b3; // add  x3, x1, x2  (x3 = x1 + x2 = 15)
        imem[3] = 32'h00310233; // add  x4, x2, x3  (x4 = x2 + x3 = 25)
    end

    // 1. FETCH STAGE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0;
            if_id.pc <= 32'h0;
            if_id.instr <= 32'h0;
        end else begin
            pc <= pc + 4;
            if_id.pc <= pc;
            if_id.instr <= imem[pc[9:2]];
        end
    end

    // 2. DECODE STAGE
    logic [31:0] imm_i;
    assign imm_i = {{20{if_id.instr[31]}}, if_id.instr[31:20]};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex.pc        <= 32'h0;
            id_ex.rs1_data  <= 32'h0;
            id_ex.rs2_data  <= 32'h0;
            id_ex.imm       <= 32'h0;
            id_ex.rd        <= 5'h0;
            id_ex.rs1       <= 5'h0;
            id_ex.rs2       <= 5'h0;
            id_ex.funct3    <= 3'h0;
            id_ex.reg_write <= 1'b0;
            id_ex.alu_src   <= 1'b0;
            id_ex.alu_op    <= 4'h0;
        end else begin
            id_ex.pc        <= if_id.pc;
            id_ex.rs1_data  <= reg_file[if_id.instr[19:15]];
            id_ex.rs2_data  <= reg_file[if_id.instr[24:20]];
            id_ex.imm       <= imm_i;
            id_ex.rd        <= if_id.instr[11:7];
            id_ex.rs1       <= if_id.instr[19:15];
            id_ex.rs2       <= if_id.instr[24:20];
            id_ex.funct3    <= if_id.instr[14:12];
            id_ex.reg_write <= (if_id.instr[6:0] == 7'b0010011 || if_id.instr[6:0] == 7'b0110011);
            id_ex.alu_src   <= (if_id.instr[6:0] == 7'b0010011); // I-Type
            id_ex.alu_op    <= 4'b0000;
        end
    end

    // 3. EXECUTE STAGE (Data Forwarding)
    logic [31:0] fwd_operand_a, fwd_operand_b;

    always @(*) begin
        if (ex_mem.reg_write && (ex_mem.rd != 5'd0) && (ex_mem.rd == id_ex.rs1))
            fwd_operand_a = ex_mem.alu_result;
        else if (mem_wb.reg_write && (mem_wb.rd != 5'd0) && (mem_wb.rd == id_ex.rs1))
            fwd_operand_a = mem_wb.result_data;
        else
            fwd_operand_a = id_ex.rs1_data;

        if (ex_mem.reg_write && (ex_mem.rd != 5'd0) && (ex_mem.rd == id_ex.rs2))
            fwd_operand_b = ex_mem.alu_result;
        else if (mem_wb.reg_write && (mem_wb.rd != 5'd0) && (mem_wb.rd == id_ex.rs2))
            fwd_operand_b = mem_wb.result_data;
        else
            fwd_operand_b = id_ex.rs2_data;
    end

    logic [31:0] alu_in_b;
    assign alu_in_b = id_ex.alu_src ? id_ex.imm : fwd_operand_b;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem.alu_result <= 32'h0;
            ex_mem.rs2_data   <= 32'h0;
            ex_mem.rd         <= 5'h0;
            ex_mem.reg_write  <= 1'b0;
        end else begin
            ex_mem.alu_result <= fwd_operand_a + alu_in_b;
            ex_mem.rs2_data   <= fwd_operand_b;
            ex_mem.rd         <= id_ex.rd;
            ex_mem.reg_write  <= id_ex.reg_write;
        end
    end

    // 4. MEMORY STAGE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb.result_data <= 32'h0;
            mem_wb.rd          <= 5'h0;
            mem_wb.reg_write   <= 1'b0;
        end else begin
            mem_wb.result_data <= ex_mem.alu_result;
            mem_wb.rd          <= ex_mem.rd;
            mem_wb.reg_write   <= ex_mem.reg_write;
        end
    end

    // 5. WRITEBACK STAGE
    always_ff @(posedge clk) begin
        if (mem_wb.reg_write && (mem_wb.rd != 5'd0)) begin
            reg_file[mem_wb.rd] <= mem_wb.result_data;
        end
    end

endmodule
