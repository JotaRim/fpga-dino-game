`timescale 1ns / 1ps

// ============================================================
// Game FSM Board Verification Top
// 说明：
//   1. 不使用 PS/2，不使用 VGA。
//   2. rst 只来自 SW[15]，BTN 不参与复位。
//   3. BTN 只作为人工事件输入：开始/重开、碰撞、手动帧。
//   4. 七段数码管显示通过课程已有 DispNum.v 完成。
// ============================================================

module game_fsm_board_top(
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
    wire btn_hit_level;
    wire btn_frame_level;
    wire btn_aux_level;

    wire btn_start_pulse;
    wire btn_hit_pulse;
    wire btn_frame_pulse;
    wire btn_aux_pulse;

    btn_debounce_pulse u_btn_start(
        .clk   (clk),
        .rst   (rst),
        .btn_in(BTN[0]),
        .level (btn_start_level),
        .pulse (btn_start_pulse)
    );

    btn_debounce_pulse u_btn_hit(
        .clk   (clk),
        .rst   (rst),
        .btn_in(BTN[1]),
        .level (btn_hit_level),
        .pulse (btn_hit_pulse)
    );

    btn_debounce_pulse u_btn_frame(
        .clk   (clk),
        .rst   (rst),
        .btn_in(BTN[2]),
        .level (btn_frame_level),
        .pulse (btn_frame_pulse)
    );

    btn_debounce_pulse u_btn_aux(
        .clk   (clk),
        .rst   (rst),
        .btn_in(BTN[3]),
        .level (btn_aux_level),
        .pulse (btn_aux_pulse)
    );

    // ------------------------------------------------------------
    // frame_end 产生
    // SW[0] = 0: 手动帧模式，按 BTN[2] 产生一帧。
    // SW[0] = 1: 自动帧模式。
    // SW[1] = 0: 自动 2Hz，便于肉眼观察。
    // SW[1] = 1: 自动 60Hz，接近真实游戏帧率。
    // ------------------------------------------------------------
    wire frame_end_auto;
    wire frame_end;

    frame_pulse_gen u_frame(
        .clk           (clk),
        .rst           (rst),
        .fast_mode     (SW[1]),
        .frame_end_auto(frame_end_auto)
    );

    assign frame_end = SW[0] ? frame_end_auto : btn_frame_pulse;

    // ------------------------------------------------------------
    // 被测状态机
    // ------------------------------------------------------------
    wire [1:0] game_state;
    wire       game_start;
    wire       game_over;

    game_fsm u_game_fsm(
        .clk        (clk),
        .rst        (rst),
        .frame_end  (frame_end),
        .space_trig (btn_start_pulse),
        .hit_flag   (btn_hit_level),
        .game_state (game_state),
        .game_start (game_start),
        .game_over  (game_over)
    );

    // ------------------------------------------------------------
    // 为了肉眼观察，将单周期脉冲拉长。
    // ------------------------------------------------------------
    wire start_seen;
    wire over_seen;
    wire frame_seen;
    wire hit_pulse_seen;
    wire start_btn_seen;

    pulse_stretch #(.HOLD_CYCLES(25'd12_500_000)) u_seen_start(
        .clk(clk), .rst(rst), .pulse_in(game_start),      .level_out(start_seen)
    );

    pulse_stretch #(.HOLD_CYCLES(25'd12_500_000)) u_seen_over(
        .clk(clk), .rst(rst), .pulse_in(game_over),       .level_out(over_seen)
    );

    pulse_stretch #(.HOLD_CYCLES(25'd12_500_000)) u_seen_frame(
        .clk(clk), .rst(rst), .pulse_in(frame_end),       .level_out(frame_seen)
    );

    pulse_stretch #(.HOLD_CYCLES(25'd12_500_000)) u_seen_hit_pulse(
        .clk(clk), .rst(rst), .pulse_in(btn_hit_pulse),   .level_out(hit_pulse_seen)
    );

    pulse_stretch #(.HOLD_CYCLES(25'd12_500_000)) u_seen_start_btn(
        .clk(clk), .rst(rst), .pulse_in(btn_start_pulse), .level_out(start_btn_seen)
    );

    // ------------------------------------------------------------
    // 调试计数器，只取低 4 位显示。
    // ------------------------------------------------------------
    reg [3:0] frame_cnt;
    reg [3:0] start_event_cnt;
    reg [3:0] hit_event_cnt;
    reg [3:0] game_start_cnt;
    reg [3:0] game_over_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            frame_cnt       <= 4'd0;
            start_event_cnt <= 4'd0;
            hit_event_cnt   <= 4'd0;
            game_start_cnt  <= 4'd0;
            game_over_cnt   <= 4'd0;
        end else begin
            if (frame_end)
                frame_cnt <= frame_cnt + 4'd1;

            if (btn_start_pulse)
                start_event_cnt <= start_event_cnt + 4'd1;

            if (btn_hit_pulse)
                hit_event_cnt <= hit_event_cnt + 4'd1;

            if (game_start)
                game_start_cnt <= game_start_cnt + 4'd1;

            if (game_over)
                game_over_cnt <= game_over_cnt + 4'd1;
        end
    end

    // ------------------------------------------------------------
    // LED 显示
    // ------------------------------------------------------------
    assign LED[0] = game_state[0];      // game_state bit0
    assign LED[1] = game_state[1];      // game_state bit1
    assign LED[2] = start_seen;         // game_start 脉冲拉长
    assign LED[3] = over_seen;          // game_over 脉冲拉长
    assign LED[4] = start_btn_seen;     // BTN[0] 开始/重开脉冲拉长
    assign LED[5] = btn_hit_level;      // BTN[1] 碰撞电平
    assign LED[6] = frame_seen;         // frame_end 脉冲拉长
    assign LED[7] = rst;                // SW[15] 复位

    // ------------------------------------------------------------
    // 七段数码管显示：使用 DispNum.v
    // SW[3:2] 选择显示内容。
    //   00: {frame_cnt, game_over_cnt, game_start_cnt, game_state}
    //   01: {frame_cnt, hit_event_cnt, start_event_cnt, game_state}
    //   10: {000, frame_mode, speed_mode, hit_level, game_state}
    //   11: {game_over_cnt, game_start_cnt, hit_event_cnt, start_event_cnt}
    // ------------------------------------------------------------
    reg [15:0] hexs;

    always @(*) begin
        case (SW[3:2])
            2'b00: hexs = {frame_cnt, game_over_cnt, game_start_cnt, 2'b00, game_state};
            2'b01: hexs = {frame_cnt, hit_event_cnt, start_event_cnt, 2'b00, game_state};
            2'b10: hexs = {4'h0, {1'b0, SW[0], SW[1], btn_hit_level},
                            {1'b0, btn_start_level, btn_frame_level, btn_aux_level},
                            {2'b00, game_state}};
            2'b11: hexs = {game_over_cnt, game_start_cnt, hit_event_cnt, start_event_cnt};
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
// 按键同步、消抖和上升沿脉冲
// ============================================================
module btn_debounce_pulse(
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
module frame_pulse_gen(
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
module pulse_stretch(
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
