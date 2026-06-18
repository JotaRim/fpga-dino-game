`timescale 1ns / 1ps

// ============================================================
// Dino PS/2 Keyboard Input
// 功能：读取 PS/2 键盘，识别空格、上方向键、下方向键。
// 复位：rst 为异步高电平有效。
// ============================================================

module dino_key_input(
    input  wire clk,        // 100MHz 全局时钟
    input  wire rst,        // 异步高电平复位
    input  wire ps2_clk,
    input  wire ps2_data,

    output wire space_key,  // 空格键按住状态
    output wire up_key,     // 上方向键按住状态
    output wire down_key,   // 下方向键按住状态
    output wire p_key,      // P键按住状态

    output wire space_trig, // 空格键按下时的单周期脉冲
    output wire up_trig,    // 上方向键按下时的单周期脉冲
    output wire down_trig,  // 下方向键按下时的单周期脉冲
    output wire p_trig      // P键按下时的单周期脉冲
);

    wire [7:0] code;
    wire       code_vld;
    wire       code_err;

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
        .p_key      (p_key),
        .space_trig (space_trig),
        .up_trig    (up_trig),
        .down_trig  (down_trig),
        .p_trig     (p_trig)
    );

endmodule


// ============================================================
// PS/2 字节接收模块
// 每帧格式：起始位0 + 8位数据(低位先传) + 奇校验 + 停止位1
// 在 ps2_clk 下降沿采样 ps2_data。
// ============================================================

module ps2_byte_rx(
    input  wire       clk,
    input  wire       rst,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output reg  [7:0] code,
    output reg        code_vld,
    output reg        code_err
);

    reg [2:0] ps2c_sync;
    reg [3:0] bit_cnt;
    reg [7:0] data_buf;
    reg       par_bit;

    wire ps2c_fall;
    assign ps2c_fall = ps2c_sync[2] & ~ps2c_sync[1];

    // 同步 PS/2 时钟，并检测下降沿
    always @(posedge clk or posedge rst) begin
        if (rst)
            ps2c_sync <= 3'b111;
        else
            ps2c_sync <= {ps2c_sync[1:0], ps2_clk};
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_cnt  <= 4'd0;
            data_buf <= 8'd0;
            par_bit  <= 1'b0;
            code     <= 8'd0;
            code_vld <= 1'b0;
            code_err <= 1'b0;
        end else begin
            code_vld <= 1'b0;
            code_err <= 1'b0;

            if (ps2c_fall) begin
                case (bit_cnt)
                    4'd0: begin
                        // 起始位必须为0，否则继续等待下一帧
                        if (ps2_data == 1'b0)
                            bit_cnt <= 4'd1;
                    end

                    4'd1, 4'd2, 4'd3, 4'd4,
                    4'd5, 4'd6, 4'd7, 4'd8: begin
                        data_buf[bit_cnt - 4'd1] <= ps2_data;
                        bit_cnt <= bit_cnt + 4'd1;
                    end

                    4'd9: begin
                        par_bit <= ps2_data;
                        bit_cnt <= 4'd10;
                    end

                    4'd10: begin
                        bit_cnt <= 4'd0;

                        // 数据位和校验位整体应满足奇校验，停止位应为1
                        if ((ps2_data == 1'b1) && (^{par_bit, data_buf})) begin
                            code     <= data_buf;
                            code_vld <= 1'b1;
                        end else begin
                            code_err <= 1'b1;
                        end
                    end

                    default: begin
                        bit_cnt <= 4'd0;
                    end
                endcase
            end
        end
    end

endmodule


// ============================================================
// Dino 游戏按键解析模块
// 识别扫描码集合2：
//   Space = 29h
//   Up    = E0 75h
//   Down  = E0 72h
//   P     = 4Dh
// 断码 F0 表示释放；E0 表示扩展键。
// ============================================================

module ps2_dino_key(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] code,
    input  wire       code_vld,

    output reg        space_key,
    output reg        up_key,
    output reg        down_key,
    output reg        p_key,
    output reg        space_trig,
    output reg        up_trig,
    output reg        down_trig,
    output reg        p_trig
);

    localparam C_EXT   = 8'hE0;
    localparam C_BREAK = 8'hF0;
    localparam C_SPACE = 8'h29;
    localparam C_UP    = 8'h75;
    localparam C_DOWN  = 8'h72;
    localparam C_P     = 8'h4D;

    reg got_ext;
    reg got_break;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            got_ext    <= 1'b0;
            got_break  <= 1'b0;

            space_key  <= 1'b0;
            up_key     <= 1'b0;
            down_key   <= 1'b0;
            p_key      <= 1'b0;

            space_trig <= 1'b0;
            up_trig    <= 1'b0;
            down_trig  <= 1'b0;
            p_trig     <= 1'b0;
        end else begin
            // trig 只保持一个 clk 周期，key 状态保持到断码到来
            space_trig <= 1'b0;
            up_trig    <= 1'b0;
            down_trig  <= 1'b0;
            p_trig     <= 1'b0;

            if (code_vld) begin
                if (code == C_EXT) begin
                    got_ext <= 1'b1;
                end else if (code == C_BREAK) begin
                    got_break <= 1'b1;
                end else begin
                    case ({got_ext, code})
                        {1'b0, C_SPACE}: begin
                            if (got_break) begin
                                space_key <= 1'b0;
                            end else begin
                                if (!space_key)
                                    space_trig <= 1'b1;
                                space_key <= 1'b1;
                            end
                        end

                        {1'b1, C_UP}: begin
                            if (got_break) begin
                                up_key <= 1'b0;
                            end else begin
                                if (!up_key)
                                    up_trig <= 1'b1;
                                up_key <= 1'b1;
                            end
                        end

                        {1'b1, C_DOWN}: begin
                            if (got_break) begin
                                down_key <= 1'b0;
                            end else begin
                                if (!down_key)
                                    down_trig <= 1'b1;
                                down_key <= 1'b1;
                            end
                        end

                        {1'b0, C_P}: begin
                            if (got_break) begin
                                p_key <= 1'b0;
                            end else begin
                                if (!p_key)
                                    p_trig <= 1'b1;
                                p_key <= 1'b1;
                            end
                        end

                        default: begin
                            // 其他按键不影响当前三键状态
                        end
                    endcase

                    got_ext   <= 1'b0;
                    got_break <= 1'b0;
                end
            end
        end
    end

endmodule
