`timescale 1ns / 1ps

// ============================================================
// PS/2 Board Verification Top - fixed version
// 修正点：
//   1. 数码管显示使用已有 DispNum.v。
//   2. 复位暂时只使用 SW[15]，避免 BTN[0] 极性/悬空导致一直复位。
//   3. LED[6]/LED[7] 分别显示原始PS/2时钟边沿/有效帧的可见拉长脉冲。
// ============================================================

module ps2_board_top(
    input  wire       clk,
    input  wire [3:0] BTN,
    input  wire [15:0] SW,
    input  wire       ps2_clk,
    input  wire       ps2_data,

    output wire [7:0] LED,
    output wire [7:0] SEGMENT,
    output wire [3:0] AN
    output wire       BTNX4
);

    // 上板排错阶段只用 SW[15] 做复位。
    wire rst;
    assign rst = SW[15];

    assign BTNX4 = 1'b0;

    wire [7:0] code;
    wire       code_vld;
    wire       code_err;

    wire       space_key;
    wire       up_key;
    wire       down_key;
    wire       space_trig;
    wire       up_trig;
    wire       down_trig;

    reg [7:0] latest_code;
    reg [7:0] valid_cnt;
    reg [7:0] err_cnt;
    reg [3:0] space_cnt;
    reg [3:0] up_cnt;
    reg [3:0] down_cnt;

    reg [23:0] space_flash;
    reg [23:0] up_flash;
    reg [23:0] down_flash;
    reg [23:0] valid_flash;
    reg [23:0] err_flash;

    // 原始 PS/2 时钟边沿观测：用于判断物理接口是否真的有信号进入 FPGA。
    reg [2:0]  ps2_clk_sync_dbg;
    reg [23:0] raw_clk_flash;
    reg [7:0]  raw_clk_cnt;
    wire       raw_ps2_fall_dbg;

    assign raw_ps2_fall_dbg = ps2_clk_sync_dbg[2] & ~ps2_clk_sync_dbg[1];

    // ------------------------------------------------------------
    // PS/2 接收与按键解析
    // ------------------------------------------------------------
    ps2_byte_rx u_rx(
        .clk      (clk),
        .rst      (rst),
        .ps2_clk  (ps2_clk),
        .ps2_data (ps2_data),
        .code     (code),
        .code_vld (code_vld),
        .code_err (code_err)
    );

    ps2_dino_key u_key(
        .clk        (clk),
        .rst        (rst),
        .code       (code),
        .code_vld   (code_vld & ~code_err),
        .space_key  (space_key),
        .up_key     (up_key),
        .down_key   (down_key),
        .space_trig (space_trig),
        .up_trig    (up_trig),
        .down_trig  (down_trig)
    );

    // ------------------------------------------------------------
    // 事件计数和可见脉冲拉长
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            latest_code <= 8'd0;
            valid_cnt   <= 8'd0;
            err_cnt     <= 8'd0;
            space_cnt   <= 4'd0;
            up_cnt      <= 4'd0;
            down_cnt    <= 4'd0;

            space_flash <= 24'd0;
            up_flash    <= 24'd0;
            down_flash  <= 24'd0;
            valid_flash <= 24'd0;
            err_flash   <= 24'd0;
            ps2_clk_sync_dbg <= 3'b111;
            raw_clk_flash <= 24'd0;
            raw_clk_cnt <= 8'd0;
        end else begin
            ps2_clk_sync_dbg <= {ps2_clk_sync_dbg[1:0], ps2_clk};
            if (raw_ps2_fall_dbg) begin
                raw_clk_flash <= 24'd12_000_000;
                raw_clk_cnt <= raw_clk_cnt + 8'd1;
            end else if (raw_clk_flash != 24'd0) begin
                raw_clk_flash <= raw_clk_flash - 24'd1;
            end

            if (code_vld) begin
                latest_code <= code;
                valid_cnt <= valid_cnt + 8'd1;
                valid_flash <= 24'd12_000_000;
            end else if (valid_flash != 24'd0) begin
                valid_flash <= valid_flash - 24'd1;
            end

            if (code_err) begin
                err_cnt <= err_cnt + 8'd1;
                err_flash <= 24'd12_000_000;
            end else if (err_flash != 24'd0) begin
                err_flash <= err_flash - 24'd1;
            end

            if (space_trig) begin
                space_cnt <= space_cnt + 4'd1;
                space_flash <= 24'd12_000_000;
            end else if (space_flash != 24'd0) begin
                space_flash <= space_flash - 24'd1;
            end

            if (up_trig) begin
                up_cnt <= up_cnt + 4'd1;
                up_flash <= 24'd12_000_000;
            end else if (up_flash != 24'd0) begin
                up_flash <= up_flash - 24'd1;
            end

            if (down_trig) begin
                down_cnt <= down_cnt + 4'd1;
                down_flash <= 24'd12_000_000;
            end else if (down_flash != 24'd0) begin
                down_flash <= down_flash - 24'd1;
            end
        end
    end

    assign LED[0] = space_key;
    assign LED[1] = up_key;
    assign LED[2] = down_key;
    assign LED[3] = (space_flash != 24'd0);
    assign LED[4] = (up_flash    != 24'd0);
    assign LED[5] = (down_flash  != 24'd0);
    // LED[6] 只说明 PS/2 时钟线有边沿进入 FPGA；LED[7] 说明已成功译出一帧。
    // 如果 LED[6] 亮而 LED[7] 不亮，再考虑接收器滤波/校验问题。
    assign LED[6] = (raw_clk_flash != 24'd0);
    assign LED[7] = (valid_flash   != 24'd0);

    // ------------------------------------------------------------
    // 数码管显示数据
    // SW[1:0]：
    //   00: 最近扫描码 + 有效字节计数低8位，例如 29 03
    //   01: 三个触发计数 + 当前按住状态
    //   10: 原始PS/2时钟下降沿计数 + 有效字节计数
    //   11: 错误帧计数 + 最近扫描码
    // ------------------------------------------------------------
    reg [3:0] disp0;  // AN[0]，通常为最右位
    reg [3:0] disp1;
    reg [3:0] disp2;
    reg [3:0] disp3;  // AN[3]，通常为最左位

    always @(*) begin
        case (SW[1:0])
            2'b00: begin
                disp3 = latest_code[7:4];
                disp2 = latest_code[3:0];
                disp1 = valid_cnt[7:4];
                disp0 = valid_cnt[3:0];
            end

            2'b01: begin
                disp3 = space_cnt;
                disp2 = up_cnt;
                disp1 = down_cnt;
                disp0 = {1'b0, down_key, up_key, space_key};
            end

            2'b10: begin
                disp3 = raw_clk_cnt[7:4];
                disp2 = raw_clk_cnt[3:0];
                disp1 = valid_cnt[7:4];
                disp0 = valid_cnt[3:0];
            end

            default: begin
                disp3 = err_cnt[7:4];
                disp2 = err_cnt[3:0];
                disp1 = latest_code[7:4];
                disp0 = latest_code[3:0];
            end
        endcase
    end

    // ------------------------------------------------------------
    // 用之前已经验证过的 DispNum.v 来驱动数码管。
    // DispNum 中约定：SEGMENT[0]=a, ..., SEGMENT[6]=g, SEGMENT[7]=p，低电平点亮；AN 低电平有效。
    // ------------------------------------------------------------
    reg [17:0] scan_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst)
            scan_cnt <= 18'd0;
        else
            scan_cnt <= scan_cnt + 18'd1;
    end

    DispNum u_disp(
        .scan    (scan_cnt[17:16]),
        .HEXS    ({disp3, disp2, disp1, disp0}),
        .point   (4'b0000),
        .LES     (4'b0000),
        .AN      (AN),
        .SEGMENT (SEGMENT)
    );

    // 防止未使用 BTN 在某些设置下产生 warning。综合会优化掉。
    wire unused_btn = |BTN;

endmodule
