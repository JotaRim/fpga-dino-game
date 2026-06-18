`timescale 1ns / 1ps

module top(
    input  wire       clk_100mhz,
    input  wire       RSTN,
    input  wire       PS2_clk,
    input  wire       PS2_data,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire       vga_hs,
    output wire       vga_vs,
    output wire       Buzzer
);

    wire rst = ~RSTN;
    wire frame_end;
    wire clk_25m;
    wire [1:0] game_state;
    wire [8:0] dino_y;
    wire [2:0] dino_state;
    wire signed [10:0] ground_x0;
    wire signed [10:0] ground_x1;
    wire [2:0] cactus_valid;
    wire signed [10:0] cactus_x0;
    wire signed [10:0] cactus_x1;
    wire signed [10:0] cactus_x2;
    wire [2:0] cactus_type0;
    wire [2:0] cactus_type1;
    wire [2:0] cactus_type2;
    wire [1:0] pterodactyl_valid;
    wire signed [10:0] pterodactyl_x0;
    wire signed [10:0] pterodactyl_x1;
    wire [8:0] pterodactyl_y0;
    wire [8:0] pterodactyl_y1;
    wire pterodactyl_state0;
    wire pterodactyl_state1;
    wire [2:0] cloud_valid;
    wire signed [10:0] cloud_x0;
    wire signed [10:0] cloud_x1;
    wire signed [10:0] cloud_x2;
    wire [8:0] cloud_y0;
    wire [8:0] cloud_y1;
    wire [8:0] cloud_y2;
    wire [2:0] moon_phase;
    wire night;
    wire [2:0] day_night_cycle;
    wire sound_press;
    wire sound_hit;
    wire sound_reached;
    wire [3:0] score0;
    wire [3:0] score1;
    wire [3:0] score2;
    wire [3:0] score3;
    wire [3:0] score4;

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
