`timescale 1ns / 1ps

// ============================================================
// Dino Object Motion System
// 功能：封装地面、仙人掌、翼龙、云朵四类运动模块。
// 说明：
//   1. 随机系统输出 *_new，本模块接收后放入空槽位。
//   2. 本模块输出 *_ready，反馈给随机系统判断是否还有空槽。
//   3. 坐标均为元素左上角坐标。
//   4. ground_x0 / ground_x1 为 signed，用于地面循环滚动。
// ============================================================

module dino_obj_motion(
    input  wire              clk,
    input  wire              rst,
    input  wire              frame_end,
    input  wire [1:0]        game_state,
    input  wire              game_start,
    input  wire [4:0]        speed_px,

    input  wire              cactus_new,
    input  wire [2:0]        cactus_type_new,
    input  wire              ptero_new,
    input  wire [8:0]        ptero_y_new,
    input  wire              cloud_new,
    input  wire [8:0]        cloud_y_new,

    output wire signed [10:0] ground_x0,
    output wire signed [10:0] ground_x1,

    output wire              cactus_ready,
    output wire              ptero_ready,
    output wire              cloud_ready,

    output wire [2:0]        cactus_valid,
    output wire signed [10:0] cactus_x0,
    output wire signed [10:0] cactus_x1,
    output wire signed [10:0] cactus_x2,
    output wire [2:0]        cactus_type0,
    output wire [2:0]        cactus_type1,
    output wire [2:0]        cactus_type2,

    output wire [1:0]        ptero_valid,
    output wire signed [10:0] ptero_x0,
    output wire signed [10:0] ptero_x1,
    output wire [8:0]        ptero_y0,
    output wire [8:0]        ptero_y1,
    output wire              ptero_state0,
    output wire              ptero_state1,

    output wire [2:0]        cloud_valid,
    output wire signed [10:0] cloud_x0,
    output wire signed [10:0] cloud_x1,
    output wire signed [10:0] cloud_x2,
    output wire [8:0]        cloud_y0,
    output wire [8:0]        cloud_y1,
    output wire [8:0]        cloud_y2
);

    ground_motion u_ground(
        .clk        (clk),
        .rst        (rst),
        .frame_end  (frame_end),
        .game_state (game_state),
        .game_start (game_start),
        .speed_px   (speed_px),

        .ground_x0  (ground_x0),
        .ground_x1  (ground_x1)
    );

    cactus_motion u_cactus(
        .clk             (clk),
        .rst             (rst),
        .frame_end       (frame_end),
        .game_state      (game_state),
        .game_start      (game_start),
        .speed_px        (speed_px),
        .cactus_new      (cactus_new),
        .cactus_type_new (cactus_type_new),

        .cactus_valid    (cactus_valid),
        .cactus_x0       (cactus_x0),
        .cactus_x1       (cactus_x1),
        .cactus_x2       (cactus_x2),
        .cactus_type0    (cactus_type0),
        .cactus_type1    (cactus_type1),
        .cactus_type2    (cactus_type2),
        .cactus_ready    (cactus_ready)
    );

    ptero_motion u_ptero(
        .clk          (clk),
        .rst          (rst),
        .frame_end    (frame_end),
        .game_state   (game_state),
        .game_start   (game_start),
        .speed_px     (speed_px),
        .ptero_new    (ptero_new),
        .ptero_y_new  (ptero_y_new),

        .ptero_valid  (ptero_valid),
        .ptero_x0     (ptero_x0),
        .ptero_x1     (ptero_x1),
        .ptero_y0     (ptero_y0),
        .ptero_y1     (ptero_y1),
        .ptero_state0 (ptero_state0),
        .ptero_state1 (ptero_state1),
        .ptero_ready  (ptero_ready)
    );

    cloud_motion u_cloud(
        .clk          (clk),
        .rst          (rst),
        .frame_end    (frame_end),
        .game_state   (game_state),
        .game_start   (game_start),
        .speed_px     (speed_px),
        .cloud_new    (cloud_new),
        .cloud_y_new  (cloud_y_new),

        .cloud_valid  (cloud_valid),
        .cloud_x0     (cloud_x0),
        .cloud_x1     (cloud_x1),
        .cloud_x2     (cloud_x2),
        .cloud_y0     (cloud_y0),
        .cloud_y1     (cloud_y1),
        .cloud_y2     (cloud_y2),
        .cloud_ready  (cloud_ready)
    );

endmodule
