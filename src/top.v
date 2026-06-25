`timescale 1ns / 1ps

// ============================================================
// 顶层模块：连接游戏逻辑层与显示/音效层
//
// 功能说明：
// 1. 接收板上 100MHz 时钟、复位按键和 PS/2 键盘信号；
// 2. 实例化 dino_game_logic，完成游戏状态、物体坐标、分数和音效触发计算；
// 3. 实例化 display_system，根据游戏状态生成 VGA 图像、帧同步信号和蜂鸣器输出；
// 4. 顶层本身只负责连线与信号极性转换，不直接修改游戏状态。
// ============================================================
module top(
    input  wire       clk_100mhz,  // 板载 100MHz 系统时钟
    input  wire       RSTN,        // 板载复位信号，低电平有效
    input  wire       PS2_clk,     // PS/2 键盘时钟线
    input  wire       PS2_data,    // PS/2 键盘数据线
    output wire [3:0] vga_r,       // VGA 红色分量
    output wire [3:0] vga_g,       // VGA 绿色分量
    output wire [3:0] vga_b,       // VGA 蓝色分量
    output wire       vga_hs,      // VGA 行同步信号
    output wire       vga_vs,      // VGA 场同步信号
    output wire       Buzzer       // 蜂鸣器输出
);

    // 统一复位极性：内部模块使用高电平有效 rst
    wire rst = ~RSTN;

    // 显示系统生成的帧结束脉冲，游戏逻辑在该脉冲到来时更新一帧状态
    wire frame_end;
    wire clk_25m;                  // VGA 像素时钟，由显示系统内部生成并导出

    // ------------------------
    // 游戏全局状态与恐龙状态
    // ------------------------
    wire [1:0] game_state;         // 00=待机，01=游戏中，11=游戏结束
    wire [8:0] dino_y;             // 恐龙左上角 Y 坐标，X 坐标固定在显示系统中处理
    wire [2:0] dino_state;         // 恐龙姿态：静止/奔跑/下蹲/死亡等

    // ------------------------
    // 地面滚动坐标
    // ------------------------
    wire signed [10:0] ground_x0;  // 第 0 段地面左上角 X 坐标
    wire signed [10:0] ground_x1;  // 第 1 段地面左上角 X 坐标

    // ------------------------
    // 仙人掌槽位信息
    // ------------------------
    wire [2:0] cactus_valid;       // 3 个仙人掌槽位是否有效
    wire signed [10:0] cactus_x0;
    wire signed [10:0] cactus_x1;
    wire signed [10:0] cactus_x2;
    wire [2:0] cactus_type0;       // 仙人掌类型，000 表示无仙人掌
    wire [2:0] cactus_type1;
    wire [2:0] cactus_type2;

    // ------------------------
    // 翼龙槽位信息
    // ------------------------
    wire [1:0] pterodactyl_valid;  // 2 个翼龙槽位是否有效
    wire signed [10:0] pterodactyl_x0;
    wire signed [10:0] pterodactyl_x1;
    wire [8:0] pterodactyl_y0;
    wire [8:0] pterodactyl_y1;
    wire pterodactyl_state0;       // 翼龙动画帧：0=翅膀上，1=翅膀下
    wire pterodactyl_state1;

    // ------------------------
    // 云朵槽位信息
    // ------------------------
    wire [2:0] cloud_valid;        // 3 个云朵槽位是否有效
    wire signed [10:0] cloud_x0;
    wire signed [10:0] cloud_x1;
    wire signed [10:0] cloud_x2;
    wire [8:0] cloud_y0;
    wire [8:0] cloud_y1;
    wire [8:0] cloud_y2;

    // ------------------------
    // 昼夜、月相、音效与分数信号
    // ------------------------
    wire [2:0] moon_phase;         // 月相编号
    wire night;                    // 0=白天，1=夜晚
    wire [2:0] day_night_cycle;    // 昼夜过渡阶段，用于显示系统做平滑变化
    wire sound_press;              // 跳跃音效触发
    wire sound_hit;                // 碰撞/游戏结束音效触发
    wire sound_reached;            // 分数达到整百音效触发
    wire [3:0] score0;             // 分数个位 BCD
    wire [3:0] score1;             // 分数十位 BCD
    wire [3:0] score2;             // 分数百位 BCD
    wire [3:0] score3;             // 分数千位 BCD
    wire [3:0] score4;             // 分数万位 BCD

    // ============================================================
    // 游戏逻辑层
    // 负责键盘输入、状态机、物体运动、随机生成、碰撞检测、计分和音效触发。
    // 所有状态更新由 frame_end 控制，使游戏逻辑与 VGA 帧率同步。
    // ============================================================
    dino_game_logic u_logic(
        .clk                (clk_100mhz),
        .rst                (rst),
        .frame_end          (frame_end),
        .PS2_clk            (PS2_clk),
        .PS2_data           (PS2_data),
        .game_state         (game_state),
        .dino_y             (dino_y),
        .dino_state         (dino_state),
        .ground_x0          (ground_x0),
        .ground_x1          (ground_x1),
        .cactus_valid       (cactus_valid),
        .cactus_x0          (cactus_x0),
        .cactus_x1          (cactus_x1),
        .cactus_x2          (cactus_x2),
        .cactus_type0       (cactus_type0),
        .cactus_type1       (cactus_type1),
        .cactus_type2       (cactus_type2),
        .pterodactyl_valid  (pterodactyl_valid),
        .pterodactyl_x0     (pterodactyl_x0),
        .pterodactyl_x1     (pterodactyl_x1),
        .pterodactyl_y0     (pterodactyl_y0),
        .pterodactyl_y1     (pterodactyl_y1),
        .pterodactyl_state0 (pterodactyl_state0),
        .pterodactyl_state1 (pterodactyl_state1),
        .cloud_valid        (cloud_valid),
        .cloud_x0           (cloud_x0),
        .cloud_x1           (cloud_x1),
        .cloud_x2           (cloud_x2),
        .cloud_y0           (cloud_y0),
        .cloud_y1           (cloud_y1),
        .cloud_y2           (cloud_y2),
        .moon_phase         (moon_phase),
        .night              (night),
        .day_night_cycle    (day_night_cycle),
        .sound_press        (sound_press),
        .sound_hit          (sound_hit),
        .sound_reached      (sound_reached),
        .score0             (score0),
        .score1             (score1),
        .score2             (score2),
        .score3             (score3),
        .score4             (score4)
    );

    // ============================================================
    // 显示与音效层
    // 根据游戏逻辑输出的坐标、类型和状态信号生成 VGA 像素；
    // 同时输出 frame_end 作为逻辑层的帧同步基准，并驱动蜂鸣器。
    // ============================================================
    display_system u_display(
        .clk                (clk_100mhz),
        .rst                (rst),
        .game_state         (game_state),
        .dino_y             (dino_y),
        .dino_state         (dino_state),
        .ground_x0          (ground_x0),
        .ground_x1          (ground_x1),
        .cactus_valid       (cactus_valid),
        .cactus_x0          (cactus_x0),
        .cactus_x1          (cactus_x1),
        .cactus_x2          (cactus_x2),
        .cactus_type0       (cactus_type0),
        .cactus_type1       (cactus_type1),
        .cactus_type2       (cactus_type2),
        .pterodactyl_valid  (pterodactyl_valid),
        .pterodactyl_x0     (pterodactyl_x0),
        .pterodactyl_x1     (pterodactyl_x1),
        .pterodactyl_y0     (pterodactyl_y0),
        .pterodactyl_y1     (pterodactyl_y1),
        .pterodactyl_state0 (pterodactyl_state0),
        .pterodactyl_state1 (pterodactyl_state1),
        .cloud_valid        (cloud_valid),
        .cloud_x0           (cloud_x0),
        .cloud_x1           (cloud_x1),
        .cloud_x2           (cloud_x2),
        .cloud_y0           (cloud_y0),
        .cloud_y1           (cloud_y1),
        .cloud_y2           (cloud_y2),
        .moon_phase         (moon_phase),
        .night              (night),
        .day_night_cycle    (day_night_cycle),
        .sound_press        (sound_press),
        .sound_hit          (sound_hit),
        .sound_reached      (sound_reached),
        .score0             (score0),
        .score1             (score1),
        .score2             (score2),
        .score3             (score3),
        .score4             (score4),
        .frame_end          (frame_end),
        .clk_25m            (clk_25m),
        .hsync              (vga_hs),
        .vsync              (vga_vs),
        .vga_r              (vga_r),
        .vga_g              (vga_g),
        .vga_b              (vga_b),
        .buzzer             (Buzzer)
    );

endmodule
