`timescale 1ns / 1ps

// ============================================================
// Dino Object Motion Board Verification Top
// 说明：
//   1. 不使用 PS/2，不使用 VGA。
//   2. rst 只来自 SW[15]，BTN 不参与复位。
//   3. BTNX4 必须作为输出恒为 0，否则 BTN 可能不可用。
//   4. 使用课程已有 DispNum.v 驱动四位七段数码管。
//   5. 被测模块为 dino_obj_motion，集成验证地面、仙人掌、翼龙、云朵运动。
// ============================================================

module motion_board_top(
    input  wire        clk,
    input  wire [3:0]  BTN,
    input  wire [15:0] SW,

    output wire [7:0]  LED,
    output wire [7:0]  SEGMENT,
    output wire [3:0]  AN,
    output wire        BTNX4
);

    wire rst;
    assign rst = SW[15];

    assign BTNX4 = 1'b0;

    // ------------------------------------------------------------
    // BTN 输入同步、消抖、上升沿脉冲
    // ------------------------------------------------------------
    wire btn_start_level;
    wire btn_cactus_level;
    wire btn_ptero_level;
    wire btn_cloud_level;

    wire btn_start_pulse;
    wire btn_cactus_pulse;
    wire btn_ptero_pulse;
    wire btn_cloud_pulse;

    motion_btn_debounce_pulse u_btn_start(
        .clk   (clk),
        .rst   (rst),
        .btn_in(BTN[0]),
        .level (btn_start_level),
        .pulse (btn_start_pulse)
    );

    motion_btn_debounce_pulse u_btn_cactus(
        .clk   (clk),
        .rst   (rst),
        .btn_in(BTN[1]),
        .level (btn_cactus_level),
        .pulse (btn_cactus_pulse)
    );

    motion_btn_debounce_pulse u_btn_ptero(
        .clk   (clk),
        .rst   (rst),
        .btn_in(BTN[2]),
        .level (btn_ptero_level),
        .pulse (btn_ptero_pulse)
    );

    motion_btn_debounce_pulse u_btn_cloud(
        .clk   (clk),
        .rst   (rst),
        .btn_in(BTN[3]),
        .level (btn_cloud_level),
        .pulse (btn_cloud_pulse)
    );

    // ------------------------------------------------------------
    // frame_end 产生
    // SW[0] = 0: 暂停帧脉冲，便于冻结观察。
    // SW[0] = 1: 自动帧模式。
    // SW[1] = 0: 自动 2Hz，便于肉眼观察。
    // SW[1] = 1: 自动 60Hz，接近真实游戏帧率。
    // 注：运动模块的生成信号必须与 frame_end 同一拍有效，因此这里把按钮脉冲锁存到下一帧消费。
    // ------------------------------------------------------------
    wire frame_end_auto;
    wire frame_end;

    motion_frame_pulse_gen u_frame(
        .clk           (clk),
        .rst           (rst),
        .fast_mode     (SW[1]),
        .frame_end_auto(frame_end_auto)
    );

    assign frame_end = SW[0] ? frame_end_auto : 1'b0;

    // ------------------------------------------------------------
    // 人工控制信号
    // SW[9] = 1 时 game_state=PLAY，元素才会移动/生成。
    // speed_px 由 SW[8:4] 给出，0 自动映射为 1，避免完全不动。
    // ------------------------------------------------------------
    wire [1:0] game_state;
    wire [4:0] speed_px;

    assign game_state = SW[9] ? 2'b01 : 2'b00;
    assign speed_px = (SW[8:4] == 5'd0) ? 5'd1 : SW[8:4];

    // cactus type：0 自动改为 1，避免生成“无仙人掌”类型。
    wire [2:0] cactus_type_new;
    assign cactus_type_new = (SW[12:10] == 3'd0) ? 3'd1 : SW[12:10];

    wire [8:0] ptero_y_new;
    wire [8:0] cloud_y_new;

    motion_y_select u_y_select(
        .sel        (SW[14:13]),
        .ptero_y_new(ptero_y_new),
        .cloud_y_new(cloud_y_new)
    );

    // ------------------------------------------------------------
    // 将 BTN 产生请求锁存到 frame_end，再作为 *_new 输入被测模块。
    // 这样即使按钮脉冲和 frame_end 不同拍，也不会丢失生成请求。
    // ------------------------------------------------------------
    reg cactus_req;
    reg ptero_req;
    reg cloud_req;

    wire cactus_new;
    wire ptero_new;
    wire cloud_new;

    assign cactus_new = frame_end & cactus_req;
    assign ptero_new  = frame_end & ptero_req;
    assign cloud_new  = frame_end & cloud_req;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cactus_req <= 1'b0;
            ptero_req  <= 1'b0;
            cloud_req  <= 1'b0;
        end else begin
            if (btn_cactus_pulse)
                cactus_req <= 1'b1;
            else if (frame_end)
                cactus_req <= 1'b0;

            if (btn_ptero_pulse)
                ptero_req <= 1'b1;
            else if (frame_end)
                ptero_req <= 1'b0;

            if (btn_cloud_pulse)
                cloud_req <= 1'b1;
            else if (frame_end)
                cloud_req <= 1'b0;
        end
    end

    // ------------------------------------------------------------
    // 被测运动系统
    // ------------------------------------------------------------
    wire signed [10:0] ground_x0;
    wire signed [10:0] ground_x1;

    wire cactus_ready;
    wire ptero_ready;
    wire cloud_ready;

    wire [2:0] cactus_valid;
    wire signed [10:0] cactus_x0;
    wire signed [10:0] cactus_x1;
    wire signed [10:0] cactus_x2;
    wire [2:0] cactus_type0;
    wire [2:0] cactus_type1;
    wire [2:0] cactus_type2;

    wire [1:0] ptero_valid;
    wire signed [10:0] ptero_x0;
    wire signed [10:0] ptero_x1;
    wire [8:0] ptero_y0;
    wire [8:0] ptero_y1;
    wire ptero_state0;
    wire ptero_state1;

    wire [2:0] cloud_valid;
    wire signed [10:0] cloud_x0;
    wire signed [10:0] cloud_x1;
    wire signed [10:0] cloud_x2;
    wire [8:0] cloud_y0;
    wire [8:0] cloud_y1;
    wire [8:0] cloud_y2;

    dino_obj_motion u_motion(
        .clk             (clk),
        .rst             (rst),
        .frame_end       (frame_end),
        .game_state      (game_state),
        .game_start      (btn_start_pulse),
        .speed_px        (speed_px),
        .cactus_new      (cactus_new),
        .cactus_type_new (cactus_type_new),
        .ptero_new       (ptero_new),
        .ptero_y_new     (ptero_y_new),
        .cloud_new       (cloud_new),
        .cloud_y_new     (cloud_y_new),
        .ground_x0       (ground_x0),
        .ground_x1       (ground_x1),
        .cactus_ready    (cactus_ready),
        .ptero_ready     (ptero_ready),
        .cloud_ready     (cloud_ready),
        .cactus_valid    (cactus_valid),
        .cactus_x0       (cactus_x0),
        .cactus_x1       (cactus_x1),
        .cactus_x2       (cactus_x2),
        .cactus_type0    (cactus_type0),
        .cactus_type1    (cactus_type1),
        .cactus_type2    (cactus_type2),
        .ptero_valid     (ptero_valid),
        .ptero_x0        (ptero_x0),
        .ptero_x1        (ptero_x1),
        .ptero_y0        (ptero_y0),
        .ptero_y1        (ptero_y1),
        .ptero_state0    (ptero_state0),
        .ptero_state1    (ptero_state1),
        .cloud_valid     (cloud_valid),
        .cloud_x0        (cloud_x0),
        .cloud_x1        (cloud_x1),
        .cloud_x2        (cloud_x2),
        .cloud_y0        (cloud_y0),
        .cloud_y1        (cloud_y1),
        .cloud_y2        (cloud_y2)
    );

    // ------------------------------------------------------------
    // 为了肉眼观察，将 frame_end 和生成事件拉长显示。
    // ------------------------------------------------------------
    wire frame_seen;
    wire cactus_seen;
    wire ptero_seen;
    wire cloud_seen;

    motion_pulse_stretch #(.HOLD_CYCLES(25'd12_500_000)) u_seen_frame(
        .clk(clk), .rst(rst), .pulse_in(frame_end),  .level_out(frame_seen)
    );

    motion_pulse_stretch #(.HOLD_CYCLES(25'd12_500_000)) u_seen_cactus(
        .clk(clk), .rst(rst), .pulse_in(cactus_new), .level_out(cactus_seen)
    );

    motion_pulse_stretch #(.HOLD_CYCLES(25'd12_500_000)) u_seen_ptero(
        .clk(clk), .rst(rst), .pulse_in(ptero_new),  .level_out(ptero_seen)
    );

    motion_pulse_stretch #(.HOLD_CYCLES(25'd12_500_000)) u_seen_cloud(
        .clk(clk), .rst(rst), .pulse_in(cloud_new),  .level_out(cloud_seen)
    );

    // LED 显示
    assign LED[0] = frame_seen;
    assign LED[1] = game_state[0];
    assign LED[2] = cactus_ready;
    assign LED[3] = ptero_ready;
    assign LED[4] = cloud_ready;
    assign LED[5] = |cactus_valid;
    assign LED[6] = |ptero_valid;
    assign LED[7] = |cloud_valid;

    // ------------------------------------------------------------
    // 七段数码管显示：使用 DispNum.v
    // SW[3:2] 选择显示内容。
    //   00: 地面坐标低 8 位：{ground_x0[7:0], ground_x1[7:0]}
    //   01: 仙人掌：{cactus_valid, cactus_type0, cactus_x0[7:0]}
    //   10: 翼龙：{ptero_valid, ptero_state0, ptero_y0[3:0], ptero_x0[7:0]}
    //   11: 云朵：{cloud_valid, speed_px[4:1], cloud_y0[3:0], cloud_x0[7:0]}
    // ------------------------------------------------------------
    reg [15:0] hexs;

    always @(*) begin
        case (SW[3:2])
            2'b00: hexs = {ground_x0[7:0], ground_x1[7:0]};
            2'b01: hexs = {{1'b0, cactus_valid}, {1'b0, cactus_type0}, cactus_x0[7:0]};
            2'b10: hexs = {{2'b00, ptero_valid}, {3'b000, ptero_state0}, ptero_y0[3:0], ptero_x0[7:0]};
            2'b11: hexs = {{1'b0, cloud_valid}, speed_px[4:1], cloud_y0[3:0], cloud_x0[7:0]};
            default: hexs = 16'h0000;
        endcase
    end

    wire [1:0] scan;
    reg  [17:0] scan_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst)
            scan_cnt <= 18'd0;
        else
            scan_cnt <= scan_cnt + 18'd1;
    end

    assign scan = scan_cnt[17:16];

    DispNum u_disp_num(
        .scan   (scan),
        .HEXS   (hexs),
        .point  (4'b0000),
        .LES    (4'b0000),
        .AN     (AN),
        .SEGMENT(SEGMENT)
    );

endmodule

// ============================================================
// Y 坐标选择
// ============================================================
module motion_y_select(
    input  wire [1:0] sel,
    output reg  [8:0] ptero_y_new,
    output reg  [8:0] cloud_y_new
);
    always @(*) begin
        case (sel)
            2'b00: begin ptero_y_new = 9'd120; cloud_y_new = 9'd110; end
            2'b01: begin ptero_y_new = 9'd160; cloud_y_new = 9'd130; end
            2'b10: begin ptero_y_new = 9'd200; cloud_y_new = 9'd150; end
            2'b11: begin ptero_y_new = 9'd240; cloud_y_new = 9'd170; end
            default: begin ptero_y_new = 9'd160; cloud_y_new = 9'd130; end
        endcase
    end
endmodule

// ============================================================
// 按键同步、消抖和上升沿脉冲
// ============================================================
module motion_btn_debounce_pulse(
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output reg  level,
    output wire pulse
);

    parameter CNT_MAX = 20'd999_999; // 约 10ms @ 100MHz

    reg btn_meta;
    reg btn_sync;
    reg btn_last_sample;
    reg level_d;
    reg [19:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_meta        <= 1'b0;
            btn_sync        <= 1'b0;
            btn_last_sample <= 1'b0;
            level           <= 1'b0;
            level_d         <= 1'b0;
            cnt             <= 20'd0;
        end else begin
            btn_meta <= btn_in;
            btn_sync <= btn_meta;
            level_d  <= level;

            if (btn_sync != btn_last_sample) begin
                btn_last_sample <= btn_sync;
                cnt <= 20'd0;
            end else if (cnt < CNT_MAX) begin
                cnt <= cnt + 20'd1;
            end else begin
                level <= btn_last_sample;
            end
        end
    end

    assign pulse = level & ~level_d;

endmodule

// ============================================================
// 自动 frame_end 发生器
// ============================================================
module motion_frame_pulse_gen(
    input  wire clk,
    input  wire rst,
    input  wire fast_mode,
    output reg  frame_end_auto
);

    localparam [26:0] CNT_2HZ  = 27'd49_999_999;
    localparam [26:0] CNT_60HZ = 27'd1_666_666;

    reg [26:0] cnt;
    wire [26:0] cnt_max;

    assign cnt_max = fast_mode ? CNT_60HZ : CNT_2HZ;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 27'd0;
            frame_end_auto <= 1'b0;
        end else begin
            if (cnt >= cnt_max) begin
                cnt <= 27'd0;
                frame_end_auto <= 1'b1;
            end else begin
                cnt <= cnt + 27'd1;
                frame_end_auto <= 1'b0;
            end
        end
    end

endmodule

// ============================================================
// 单周期脉冲拉长，便于 LED 肉眼观察
// ============================================================
module motion_pulse_stretch(
    input  wire clk,
    input  wire rst,
    input  wire pulse_in,
    output wire level_out
);

    parameter HOLD_CYCLES = 25'd12_500_000; // 约 125ms @ 100MHz

    reg [24:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt <= 25'd0;
        end else begin
            if (pulse_in)
                cnt <= HOLD_CYCLES;
            else if (cnt != 25'd0)
                cnt <= cnt - 25'd1;
        end
    end

    assign level_out = (cnt != 25'd0);

endmodule
