`timescale 1ns / 1ps

// ============================================================
// Dino Pterodactyl Motion
// 功能：维护 2 个翼龙槽位，负责生成、左移、移出清空和翅膀动画。
// 说明：
//   1. 翼龙速度为 speed_px + 1，比地面略快。
//   2. 每 12 帧翻转一次 ptero_state，约 0.2s。
//   3. ptero_y_new 来自随机生成系统，表示高空/中空/低空。
// ============================================================

module ptero_motion(
    input  wire       clk,
    input  wire       rst,
    input  wire       frame_end,
    input  wire [1:0] game_state,
    input  wire       game_start,
    input  wire [4:0] speed_px,
    input  wire       ptero_new,
    input  wire [8:0] ptero_y_new,

    output reg  [1:0] ptero_valid,
    output reg  signed [10:0] ptero_x0,
    output reg  signed [10:0] ptero_x1,
    output reg  [8:0] ptero_y0,
    output reg  [8:0] ptero_y1,
    output wire       ptero_state0,
    output wire       ptero_state1,
    output wire       ptero_ready
);

    localparam S_PLAY = 2'b01;
    localparam signed [10:0] NEW_X = 11'sd700;
    localparam signed [10:0] LEFT_LIM = -11'sd69;
    localparam [3:0] WING_FRM = 4'd12;

    wire       is_play;
    wire signed [10:0] ptero_spd;
    reg  [3:0] wing_cnt;
    reg        wing_bit;

    assign is_play = (game_state == S_PLAY);
    assign ptero_spd = {6'd0, speed_px} + 11'sd1;
    assign ptero_ready = ~(&ptero_valid);

    assign ptero_state0 = ptero_valid[0] ? wing_bit : 1'b0;
    assign ptero_state1 = ptero_valid[1] ? wing_bit : 1'b0;

    // 翼龙翅膀动画计数
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wing_cnt <= 4'd0;
            wing_bit <= 1'b0;
        end else begin
            if (game_start) begin
                wing_cnt <= 4'd0;
                wing_bit <= 1'b0;
            end else if (frame_end && is_play) begin
                if (wing_cnt == WING_FRM - 4'd1) begin
                    wing_cnt <= 4'd0;
                    wing_bit <= ~wing_bit;
                end else begin
                    wing_cnt <= wing_cnt + 4'd1;
                end
            end
        end
    end

    // 翼龙槽位运动
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ptero_valid <= 2'b00;
            ptero_x0 <= 11'sd0;
            ptero_x1 <= 11'sd0;
            ptero_y0 <= 9'd0;
            ptero_y1 <= 9'd0;
        end else begin
            if (game_start) begin
                ptero_valid <= 2'b00;
                ptero_x0 <= 11'sd0;
                ptero_x1 <= 11'sd0;
                ptero_y0 <= 9'd0;
                ptero_y1 <= 9'd0;
            end else if (frame_end && is_play) begin
                if (ptero_valid[0]) begin
                    if (ptero_x0 > LEFT_LIM + ptero_spd)
                        ptero_x0 <= ptero_x0 - ptero_spd;
                    else begin
                        ptero_valid[0] <= 1'b0;
                        ptero_x0 <= 11'sd0;
                        ptero_y0 <= 9'd0;
                    end
                end

                if (ptero_valid[1]) begin
                    if (ptero_x1 > LEFT_LIM + ptero_spd)
                        ptero_x1 <= ptero_x1 - ptero_spd;
                    else begin
                        ptero_valid[1] <= 1'b0;
                        ptero_x1 <= 11'sd0;
                        ptero_y1 <= 9'd0;
                    end
                end

                if (ptero_new) begin
                    if (!ptero_valid[0]) begin
                        ptero_valid[0] <= 1'b1;
                        ptero_x0 <= NEW_X;
                        ptero_y0 <= ptero_y_new;
                    end else if (!ptero_valid[1]) begin
                        ptero_valid[1] <= 1'b1;
                        ptero_x1 <= NEW_X;
                        ptero_y1 <= ptero_y_new;
                    end
                end
            end
        end
    end

endmodule
