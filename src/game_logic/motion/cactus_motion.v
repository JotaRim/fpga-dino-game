`timescale 1ns / 1ps

// ============================================================
// Dino Cactus Motion
// 功能：维护 3 个仙人掌槽位，负责生成、左移和移出清空。
// 说明：
//   1. 仙人掌速度与地面速度一致，即 speed_px。
//   2. 收到 cactus_new 后，选择第一个空槽位放入新仙人掌。
//   3. cactus_type_new 来自随机生成系统。
// ============================================================

module cactus_motion(
    input  wire       clk,
    input  wire       rst,
    input  wire       frame_end,
    input  wire [1:0] game_state,
    input  wire       game_start,
    input  wire [4:0] speed_px,
    input  wire       cactus_new,
    input  wire [2:0] cactus_type_new,

    output reg  [2:0] cactus_valid,
    output reg  signed [10:0] cactus_x0,
    output reg  signed [10:0] cactus_x1,
    output reg  signed [10:0] cactus_x2,
    output reg  [2:0] cactus_type0,
    output reg  [2:0] cactus_type1,
    output reg  [2:0] cactus_type2,
    output wire       cactus_ready
);

    localparam S_PLAY = 2'b01;
    localparam signed [10:0] NEW_X = 11'sd700;

    wire       is_play;
    wire signed [10:0] spd;

    assign is_play = (game_state == S_PLAY);
    assign spd = {6'd0, speed_px};
    assign cactus_ready = ~(&cactus_valid);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cactus_valid <= 3'b000;
            cactus_x0 <= 11'sd0;
            cactus_x1 <= 11'sd0;
            cactus_x2 <= 11'sd0;
            cactus_type0 <= 3'b000;
            cactus_type1 <= 3'b000;
            cactus_type2 <= 3'b000;
        end else begin
            if (game_start) begin
                cactus_valid <= 3'b000;
                cactus_x0 <= 11'sd0;
                cactus_x1 <= 11'sd0;
                cactus_x2 <= 11'sd0;
                cactus_type0 <= 3'b000;
                cactus_type1 <= 3'b000;
                cactus_type2 <= 3'b000;
            end else if (frame_end && is_play) begin
                if (cactus_valid[0]) begin
                    if (cactus_x0 > -$signed({1'b0, cactus_width(cactus_type0)}) + spd)
                        cactus_x0 <= cactus_x0 - spd;
                    else begin
                        cactus_valid[0] <= 1'b0;
                        cactus_x0 <= 11'sd0;
                        cactus_type0 <= 3'b000;
                    end
                end

                if (cactus_valid[1]) begin
                    if (cactus_x1 > -$signed({1'b0, cactus_width(cactus_type1)}) + spd)
                        cactus_x1 <= cactus_x1 - spd;
                    else begin
                        cactus_valid[1] <= 1'b0;
                        cactus_x1 <= 11'sd0;
                        cactus_type1 <= 3'b000;
                    end
                end

                if (cactus_valid[2]) begin
                    if (cactus_x2 > -$signed({1'b0, cactus_width(cactus_type2)}) + spd)
                        cactus_x2 <= cactus_x2 - spd;
                    else begin
                        cactus_valid[2] <= 1'b0;
                        cactus_x2 <= 11'sd0;
                        cactus_type2 <= 3'b000;
                    end
                end

                if (cactus_new) begin
                    if (!cactus_valid[0]) begin
                        cactus_valid[0] <= 1'b1;
                        cactus_x0 <= NEW_X;
                        cactus_type0 <= cactus_type_new;
                    end else if (!cactus_valid[1]) begin
                        cactus_valid[1] <= 1'b1;
                        cactus_x1 <= NEW_X;
                        cactus_type1 <= cactus_type_new;
                    end else if (!cactus_valid[2]) begin
                        cactus_valid[2] <= 1'b1;
                        cactus_x2 <= NEW_X;
                        cactus_type2 <= cactus_type_new;
                    end
                end
            end
        end
    end

    function [9:0] cactus_width;
        input [2:0] typ;
        begin
            case (typ)
                3'd1: cactus_width = 10'd26;
                3'd2: cactus_width = 10'd51;
                3'd3: cactus_width = 10'd77;
                3'd4: cactus_width = 10'd38;
                3'd5: cactus_width = 10'd75;
                default: cactus_width = 10'd113;
            endcase
        end
    endfunction

endmodule
