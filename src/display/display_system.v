`timescale 1ns / 1ps

module display_system(
    input  wire        clk,
    input  wire        rst,

    input  wire [1:0]  game_state,
    input  wire [8:0]  dino_y,
    input  wire [2:0]  dino_state,
    input  wire signed [10:0] ground_x0,
    input  wire signed [10:0] ground_x1,

    input  wire [2:0]  cactus_valid,
    input  wire signed [10:0] cactus_x0,
    input  wire signed [10:0] cactus_x1,
    input  wire signed [10:0] cactus_x2,
    input  wire [2:0]  cactus_type0,
    input  wire [2:0]  cactus_type1,
    input  wire [2:0]  cactus_type2,

    input  wire [1:0]  pterodactyl_valid,
    input  wire signed [10:0] pterodactyl_x0,
    input  wire signed [10:0] pterodactyl_x1,
    input  wire [8:0]  pterodactyl_y0,
    input  wire [8:0]  pterodactyl_y1,
    input  wire        pterodactyl_state0,
    input  wire        pterodactyl_state1,

    input  wire [2:0]  cloud_valid,
    input  wire signed [10:0] cloud_x0,
    input  wire signed [10:0] cloud_x1,
    input  wire signed [10:0] cloud_x2,
    input  wire [8:0]  cloud_y0,
    input  wire [8:0]  cloud_y1,
    input  wire [8:0]  cloud_y2,

    input  wire [2:0]  moon_phase,
    input  wire        night,
    input  wire [2:0]  day_night_cycle,

    input  wire        sound_press,
    input  wire        sound_hit,
    input  wire        sound_reached,
    input  wire [3:0]  score0,
    input  wire [3:0]  score1,
    input  wire [3:0]  score2,
    input  wire [3:0]  score3,
    input  wire [3:0]  score4,

    output wire        frame_end,
    output wire        clk_25m,
    output wire        hsync,
    output wire        vsync,
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b,
    output wire        buzzer
);

    localparam S_OVER = 2'b11;
    localparam S_PAUS = 2'b10;

    localparam [9:0] DINO_X = 10'd50;
    localparam [9:0] DINO_W = 10'd66;
    localparam [8:0] DINO_H = 9'd70;
    localparam [9:0] DUCK_W = 10'd88;
    localparam [8:0] DUCK_H = 9'd45;

    localparam [9:0] PTERO_W = 10'd69;
    localparam [8:0] PTERO_H = 9'd60;
    localparam [9:0] CLOUD_W = 10'd69;
    localparam [8:0] CLOUD_H = 9'd20;
    localparam [9:0] GROUND_W = 10'd900;
    localparam [8:0] GROUND_H = 9'd20;
    localparam [8:0] GROUND_Y = 9'd360;
    localparam [9:0] MOON_X = 10'd92;
    localparam [8:0] MOON_Y = 9'd54;
    localparam [9:0] MOON_W = 10'd30;
    localparam [8:0] MOON_H = 9'd60;

    wire [9:0] px;
    wire [8:0] py;
    wire [11:0] pixel_rgb;

    vga_ctrl u_vga(
        .clk       (clk),
        .rst       (rst),
        .pixel_in  (pixel_rgb),
        .clk_25m   (clk_25m),
        .frame_end (frame_end),
        .vga_x     (px),
        .vga_y     (py),
        .hsync     (hsync),
        .vsync     (vsync),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b)
    );

    assign buzzer = sound_press | sound_hit | sound_reached;

    wire is_duck = (dino_state == 3'b010) || (dino_state == 3'b110);
    wire [8:0] dino_draw_y = is_duck ? (dino_y + (DINO_H - DUCK_H)) : dino_y;
    wire dino_norm_hit = !is_duck && rect_hit(px, py, DINO_X, dino_y, DINO_W, DINO_H);
    wire dino_duck_hit = is_duck && rect_hit(px, py, DINO_X, dino_draw_y, DUCK_W, DUCK_H);

    wire [12:0] dino_addr = (py - dino_y) * DINO_W + (px - DINO_X);
    wire [11:0] duck_addr = (py - dino_draw_y) * DUCK_W + (px - DINO_X);

    wire [1:0] pix_dino_default;
    wire [1:0] pix_dino_left;
    wire [1:0] pix_dino_right;
    wire [1:0] pix_dino_dead;
    wire [1:0] pix_duck_left;
    wire [1:0] pix_duck_right;

    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("dino_default.mem")) u_rom_dino_default(.addr(dino_addr), .data(pix_dino_default));
    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("dino_left.mem"))    u_rom_dino_left   (.addr(dino_addr), .data(pix_dino_left));
    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("dino_right.mem"))   u_rom_dino_right  (.addr(dino_addr), .data(pix_dino_right));
    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("dino_dead.mem"))    u_rom_dino_dead   (.addr(dino_addr), .data(pix_dino_dead));
    sprite_rom #(.ADDR_WIDTH(12), .MEM_FILE("dino_duck_left.mem"))  u_rom_duck_left (.addr(duck_addr), .data(pix_duck_left));
    sprite_rom #(.ADDR_WIDTH(12), .MEM_FILE("dino_duck_right.mem")) u_rom_duck_right(.addr(duck_addr), .data(pix_duck_right));

    wire [1:0] dino_pix = !dino_norm_hit ? 2'b00 :
                          (game_state == S_OVER || dino_state == 3'b111) ? pix_dino_dead :
                          (dino_state == 3'b001) ? pix_dino_left :
                          (dino_state == 3'b011) ? pix_dino_right :
                          pix_dino_default;

    wire [1:0] duck_pix = !dino_duck_hit ? 2'b00 :
                          (dino_state == 3'b010) ? pix_duck_left : pix_duck_right;

    wire [1:0] cactus_pix0;
    wire [1:0] cactus_pix1;
    wire [1:0] cactus_pix2;
    wire cactus_hit0;
    wire cactus_hit1;
    wire cactus_hit2;

    cactus_sprite u_cactus0(.x(px), .y(py), .valid(cactus_valid[0]), .base_x(cactus_x0), .typ(cactus_type0), .hit(cactus_hit0), .pix(cactus_pix0));
    cactus_sprite u_cactus1(.x(px), .y(py), .valid(cactus_valid[1]), .base_x(cactus_x1), .typ(cactus_type1), .hit(cactus_hit1), .pix(cactus_pix1));
    cactus_sprite u_cactus2(.x(px), .y(py), .valid(cactus_valid[2]), .base_x(cactus_x2), .typ(cactus_type2), .hit(cactus_hit2), .pix(cactus_pix2));

    wire [1:0] ptero_pix0;
    wire [1:0] ptero_pix1;
    wire signed [11:0] ptero_rel_x0 = $signed({2'b00, px}) - $signed({pterodactyl_x0[10], pterodactyl_x0});
    wire signed [11:0] ptero_rel_x1 = $signed({2'b00, px}) - $signed({pterodactyl_x1[10], pterodactyl_x1});
    wire ptero_hit0 = pterodactyl_valid[0] && (ptero_rel_x0 >= 12'sd0) && (ptero_rel_x0 < 12'sd69) &&
                      (py >= pterodactyl_y0) && (py < pterodactyl_y0 + PTERO_H);
    wire ptero_hit1 = pterodactyl_valid[1] && (ptero_rel_x1 >= 12'sd0) && (ptero_rel_x1 < 12'sd69) &&
                      (py >= pterodactyl_y1) && (py < pterodactyl_y1 + PTERO_H);
    wire [12:0] ptero_addr0 = (py - pterodactyl_y0) * PTERO_W + ptero_rel_x0[6:0];
    wire [12:0] ptero_addr1 = (py - pterodactyl_y1) * PTERO_W + ptero_rel_x1[6:0];
    wire [1:0] ptero_up0;
    wire [1:0] ptero_down0;
    wire [1:0] ptero_up1;
    wire [1:0] ptero_down1;

    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("ptero_up.mem"))   u_rom_ptero_up0  (.addr(ptero_addr0), .data(ptero_up0));
    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("ptero_down.mem")) u_rom_ptero_down0(.addr(ptero_addr0), .data(ptero_down0));
    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("ptero_up.mem"))   u_rom_ptero_up1  (.addr(ptero_addr1), .data(ptero_up1));
    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("ptero_down.mem")) u_rom_ptero_down1(.addr(ptero_addr1), .data(ptero_down1));

    assign ptero_pix0 = ptero_hit0 ? (pterodactyl_state0 ? ptero_down0 : ptero_up0) : 2'b00;
    assign ptero_pix1 = ptero_hit1 ? (pterodactyl_state1 ? ptero_down1 : ptero_up1) : 2'b00;

    wire [1:0] cloud_pix0;
    wire [1:0] cloud_pix1;
    wire [1:0] cloud_pix2;
    cloud_sprite u_cloud0(.x(px), .y(py), .valid(cloud_valid[0]), .base_x(cloud_x0), .base_y(cloud_y0), .pix(cloud_pix0));
    cloud_sprite u_cloud1(.x(px), .y(py), .valid(cloud_valid[1]), .base_x(cloud_x1), .base_y(cloud_y1), .pix(cloud_pix1));
    cloud_sprite u_cloud2(.x(px), .y(py), .valid(cloud_valid[2]), .base_x(cloud_x2), .base_y(cloud_y2), .pix(cloud_pix2));

    wire [1:0] ground_pix0;
    wire [1:0] ground_pix1;
    ground_sprite #(.MEM_FILE("ground_a.mem")) u_ground0(.x(px), .y(py), .base_x(ground_x0), .pix(ground_pix0));
    ground_sprite #(.MEM_FILE("ground_b.mem")) u_ground1(.x(px), .y(py), .base_x(ground_x1), .pix(ground_pix1));

    wire [1:0] moon_pix;
    moon_sprite u_moon(.x(px), .y(py), .phase(moon_phase), .pix(moon_pix));

    assign pixel_rgb = compose_pixel(
        px, py, night, day_night_cycle, game_state,
        ground_pix0, ground_pix1,
        cloud_pix2, cloud_pix1, cloud_pix0,
        moon_pix,
        ptero_pix1, ptero_pix0,
        cactus_pix2, cactus_pix1, cactus_pix0,
        dino_pix, duck_pix,
        dino_y, dino_state,
        score4, score3, score2, score1, score0
    );

    function [11:0] compose_pixel;
        input [9:0] x;
        input [8:0] y;
        input n;
        input [2:0] cycle;
        input [1:0] gstate;
        input [1:0] gp0;
        input [1:0] gp1;
        input [1:0] cl2;
        input [1:0] cl1;
        input [1:0] cl0;
        input [1:0] mp;
        input [1:0] pt1;
        input [1:0] pt0;
        input [1:0] ca2;
        input [1:0] ca1;
        input [1:0] ca0;
        input [1:0] dp;
        input [1:0] ddp;
        input [8:0] dy;
        input [2:0] dst;
        input [3:0] s4;
        input [3:0] s3;
        input [3:0] s2;
        input [3:0] s1;
        input [3:0] s0;
        reg [11:0] c;
        begin
            c = sky_color(y, 1'b0, cycle);
            if (gp0 != 2'b00) c = sprite_color(gp0, 1'b0, 12'h555, 12'h555);
            if (gp1 != 2'b00) c = sprite_color(gp1, 1'b0, 12'h555, 12'h555);
            if (cl2 != 2'b00) c = sprite_color(cl2, 1'b0, 12'h777, 12'h777);
            if (cl1 != 2'b00) c = sprite_color(cl1, 1'b0, 12'h777, 12'h777);
            if (cl0 != 2'b00) c = sprite_color(cl0, 1'b0, 12'h777, 12'h777);
            if (pt1 != 2'b00) c = sprite_color(pt1, 1'b0, 12'h555, 12'h555);
            if (pt0 != 2'b00) c = sprite_color(pt0, 1'b0, 12'h555, 12'h555);
            if (ca2 != 2'b00) c = sprite_color(ca2, 1'b0, 12'h555, 12'h555);
            if (ca1 != 2'b00) c = sprite_color(ca1, 1'b0, 12'h555, 12'h555);
            if (ca0 != 2'b00) c = sprite_color(ca0, 1'b0, 12'h555, 12'h555);
            if (dp  != 2'b00) c = sprite_color(dp,  1'b0, 12'h555, 12'h555);
            if (ddp != 2'b00) c = sprite_color(ddp, 1'b0, 12'h555, 12'h555);
            if (score_pixel(x, y, s4, s3, s2, s1, s0)) c = 12'h777;
            if (gstate == S_PAUS) begin
                if (pause_letter(x, y)) c = 12'h444;
            end
            if (gstate == S_OVER) begin
                if (gameover_letter(x, y)) c = 12'h444;
                if (restart_icon(x, y)) c = 12'he44;
            end
            if (n) c = 12'hfff - c;
            if (n && mp != 2'b00) c = sprite_color(mp, 1'b0, 12'hccc, 12'hccc);
            compose_pixel = c;
        end
    endfunction

    function [11:0] sky_color;
        input [8:0] y;
        input n;
        input [2:0] cycle;
        reg [11:0] base;
        begin
            if (n) begin
                case (cycle)
                    3'd0: base = 12'h9ab;
                    3'd1: base = 12'h789;
                    3'd2: base = 12'h567;
                    3'd3: base = 12'h456;
                    3'd4: base = 12'h345;
                    default: base = 12'h234;
                endcase
                if (y > 9'd360) base = base - 12'h011;
            end else begin
                base = 12'hfff;
            end
            sky_color = base;
        end
    endfunction

    function [11:0] sprite_color;
        input [1:0] pix;
        input n;
        input [11:0] dark;
        input [11:0] light;
        begin
            if (pix == 2'b10) sprite_color = n ? (12'hfff - light) : light;
            else sprite_color = n ? (12'hfff - dark) : dark;
        end
    endfunction

    function dino_contact_pixel;
        input [9:0] x;
        input [8:0] y;
        input [8:0] dy;
        input [2:0] dst;
        reg duck;
        begin
            duck = (dst == 3'b010) || (dst == 3'b110);
            dino_contact_pixel = (dy >= 9'd298) && (y >= 9'd360) && (y < 9'd363) &&
                                 ((duck && x >= DINO_X + 10'd18 && x < DINO_X + 10'd78) ||
                                  (!duck && ((x >= DINO_X + 10'd22 && x < DINO_X + 10'd34) ||
                                             (x >= DINO_X + 10'd41 && x < DINO_X + 10'd53))));
        end
    endfunction

    function rect_hit;
        input [9:0] x;
        input [8:0] y;
        input [9:0] bx;
        input [8:0] by;
        input [9:0] bw;
        input [8:0] bh;
        begin
            rect_hit = (x >= bx) && (x < bx + bw) && (y >= by) && (y < by + bh);
        end
    endfunction

    function score_area;
        input [9:0] x;
        input [8:0] y;
        begin
            score_area = (x >= 10'd510) && (x < 10'd620) && (y >= 9'd16) && (y < 9'd37);
        end
    endfunction

    function score_pixel;
        input [9:0] x;
        input [8:0] y;
        input [3:0] s4;
        input [3:0] s3;
        input [3:0] s2;
        input [3:0] s1;
        input [3:0] s0;
        begin
            score_pixel = digit_pixel(x - 10'd510, y - 9'd16, s4) ||
                          digit_pixel(x - 10'd532, y - 9'd16, s3) ||
                          digit_pixel(x - 10'd554, y - 9'd16, s2) ||
                          digit_pixel(x - 10'd576, y - 9'd16, s1) ||
                          digit_pixel(x - 10'd598, y - 9'd16, s0);
        end
    endfunction

    function digit_pixel;
        input [9:0] lx;
        input [8:0] ly;
        input [3:0] digit;
        reg [2:0] col;
        reg [2:0] row;
        reg [4:0] bits;
        begin
            if (lx >= 10'd15 || ly >= 9'd21) begin
                digit_pixel = 1'b0;
            end else begin
                if (lx < 10'd3) col = 3'd0;
                else if (lx < 10'd6) col = 3'd1;
                else if (lx < 10'd9) col = 3'd2;
                else if (lx < 10'd12) col = 3'd3;
                else col = 3'd4;

                if (ly < 9'd3) row = 3'd0;
                else if (ly < 9'd6) row = 3'd1;
                else if (ly < 9'd9) row = 3'd2;
                else if (ly < 9'd12) row = 3'd3;
                else if (ly < 9'd15) row = 3'd4;
                else if (ly < 9'd18) row = 3'd5;
                else row = 3'd6;

                bits = digit_row(digit, row);
                digit_pixel = bits[4 - col];
            end
        end
    endfunction

    function [4:0] digit_row;
        input [3:0] digit;
        input [2:0] row;
        begin
            case (digit)
                4'd0: case (row)
                    3'd0: digit_row = 5'b01110;
                    3'd1: digit_row = 5'b10001;
                    3'd2: digit_row = 5'b10011;
                    3'd3: digit_row = 5'b10101;
                    3'd4: digit_row = 5'b11001;
                    3'd5: digit_row = 5'b10001;
                    default: digit_row = 5'b01110;
                endcase
                4'd1: case (row)
                    3'd0: digit_row = 5'b00100;
                    3'd1: digit_row = 5'b01100;
                    3'd2: digit_row = 5'b00100;
                    3'd3: digit_row = 5'b00100;
                    3'd4: digit_row = 5'b00100;
                    3'd5: digit_row = 5'b00100;
                    default: digit_row = 5'b01110;
                endcase
                4'd2: case (row)
                    3'd0: digit_row = 5'b01110;
                    3'd1: digit_row = 5'b10001;
                    3'd2: digit_row = 5'b00001;
                    3'd3: digit_row = 5'b00010;
                    3'd4: digit_row = 5'b00100;
                    3'd5: digit_row = 5'b01000;
                    default: digit_row = 5'b11111;
                endcase
                4'd3: case (row)
                    3'd0: digit_row = 5'b11110;
                    3'd1: digit_row = 5'b00001;
                    3'd2: digit_row = 5'b00001;
                    3'd3: digit_row = 5'b01110;
                    3'd4: digit_row = 5'b00001;
                    3'd5: digit_row = 5'b00001;
                    default: digit_row = 5'b11110;
                endcase
                4'd4: case (row)
                    3'd0: digit_row = 5'b00010;
                    3'd1: digit_row = 5'b00110;
                    3'd2: digit_row = 5'b01010;
                    3'd3: digit_row = 5'b10010;
                    3'd4: digit_row = 5'b11111;
                    3'd5: digit_row = 5'b00010;
                    default: digit_row = 5'b00010;
                endcase
                4'd5: case (row)
                    3'd0: digit_row = 5'b11111;
                    3'd1: digit_row = 5'b10000;
                    3'd2: digit_row = 5'b10000;
                    3'd3: digit_row = 5'b11110;
                    3'd4: digit_row = 5'b00001;
                    3'd5: digit_row = 5'b00001;
                    default: digit_row = 5'b11110;
                endcase
                4'd6: case (row)
                    3'd0: digit_row = 5'b01110;
                    3'd1: digit_row = 5'b10000;
                    3'd2: digit_row = 5'b10000;
                    3'd3: digit_row = 5'b11110;
                    3'd4: digit_row = 5'b10001;
                    3'd5: digit_row = 5'b10001;
                    default: digit_row = 5'b01110;
                endcase
                4'd7: case (row)
                    3'd0: digit_row = 5'b11111;
                    3'd1: digit_row = 5'b00001;
                    3'd2: digit_row = 5'b00010;
                    3'd3: digit_row = 5'b00100;
                    3'd4: digit_row = 5'b01000;
                    3'd5: digit_row = 5'b01000;
                    default: digit_row = 5'b01000;
                endcase
                4'd8: case (row)
                    3'd0: digit_row = 5'b01110;
                    3'd1: digit_row = 5'b10001;
                    3'd2: digit_row = 5'b10001;
                    3'd3: digit_row = 5'b01110;
                    3'd4: digit_row = 5'b10001;
                    3'd5: digit_row = 5'b10001;
                    default: digit_row = 5'b01110;
                endcase
                4'd9: case (row)
                    3'd0: digit_row = 5'b01110;
                    3'd1: digit_row = 5'b10001;
                    3'd2: digit_row = 5'b10001;
                    3'd3: digit_row = 5'b01111;
                    3'd4: digit_row = 5'b00001;
                    3'd5: digit_row = 5'b00001;
                    default: digit_row = 5'b01110;
                endcase
                default: digit_row = 5'b00000;
            endcase
        end
    endfunction

    function gameover_letter;
        input [9:0] x;
        input [8:0] y;
        reg [9:0] lx;
        reg [8:0] ly;
        begin
            gameover_letter = 1'b0;
            if (x >= 10'd180 && x < 10'd460 && y >= 9'd150 && y < 9'd198) begin
                lx = x - 10'd180;
                ly = y - 9'd150;
                gameover_letter = letter_G(lx, ly) || letter_A(lx - 10'd36, ly) ||
                                  letter_M(lx - 10'd72, ly) || letter_E(lx - 10'd108, ly) ||
                                  letter_O(lx - 10'd164, ly) || letter_V(lx - 10'd200, ly) ||
                                  letter_E(lx - 10'd236, ly) || letter_R(lx - 10'd272, ly);
            end
        end
    endfunction

    function pause_letter;
        input [9:0] x;
        input [8:0] y;
        reg [9:0] lx;
        reg [8:0] ly;
        begin
            pause_letter = 1'b0;
            if (x >= 10'd226 && x < 10'd414 && y >= 9'd150 && y < 9'd198) begin
                lx = x - 10'd226;
                ly = y - 9'd150;
                pause_letter = letter_P(lx, ly) || letter_A(lx - 10'd36, ly) ||
                               letter_U(lx - 10'd72, ly) || letter_S(lx - 10'd108, ly) ||
                               letter_E(lx - 10'd144, ly);
            end
        end
    endfunction

    function restart_icon;
        input [9:0] x;
        input [8:0] y;
        reg [10:0] dx;
        reg [10:0] dy;
        reg [20:0] d2;
        begin
            dx = (x > 10'd320) ? (x - 10'd320) : (10'd320 - x);
            dy = (y > 9'd248) ? (y - 9'd248) : (9'd248 - y);
            d2 = dx * dx + dy * dy;
            restart_icon = (d2 > 21'd120) && (d2 < 21'd220) && !(x > 10'd328 && y < 9'd248);
            if (rect_hit(x, y, 10'd334, 9'd230, 10'd10, 9'd14)) restart_icon = 1'b1;
            if (rect_hit(x, y, 10'd344, 9'd234, 10'd8, 9'd8)) restart_icon = 1'b1;
        end
    endfunction

    function letter_G;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_G = rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd0, 9'd0, 10'd20, 9'd4) ||
                       rect_hit(x, y, 10'd0, 9'd24, 10'd20, 9'd4) ||
                       rect_hit(x, y, 10'd16, 9'd14, 10'd4, 9'd14) ||
                       rect_hit(x, y, 10'd10, 9'd14, 10'd10, 9'd4);
        end
    endfunction

    function letter_A;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_A = rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd16, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd0, 9'd0, 10'd20, 9'd4) ||
                       rect_hit(x, y, 10'd0, 9'd12, 10'd20, 9'd4);
        end
    endfunction

    function letter_P;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_P = rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd0, 9'd0, 10'd18, 9'd4) ||
                       rect_hit(x, y, 10'd14, 9'd0, 10'd4, 9'd16) ||
                       rect_hit(x, y, 10'd0, 9'd12, 10'd18, 9'd4);
        end
    endfunction

    function letter_U;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_U = rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd16, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd0, 9'd24, 10'd20, 9'd4);
        end
    endfunction

    function letter_S;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_S = rect_hit(x, y, 10'd0, 9'd0, 10'd20, 9'd4) ||
                       rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd16) ||
                       rect_hit(x, y, 10'd0, 9'd12, 10'd20, 9'd4) ||
                       rect_hit(x, y, 10'd16, 9'd12, 10'd4, 9'd16) ||
                       rect_hit(x, y, 10'd0, 9'd24, 10'd20, 9'd4);
        end
    endfunction

    function letter_M;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_M = rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd16, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd6, 9'd6, 10'd4, 9'd8) ||
                       rect_hit(x, y, 10'd10, 9'd6, 10'd4, 9'd8);
        end
    endfunction

    function letter_E;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_E = rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd0, 9'd0, 10'd20, 9'd4) ||
                       rect_hit(x, y, 10'd0, 9'd12, 10'd16, 9'd4) ||
                       rect_hit(x, y, 10'd0, 9'd24, 10'd20, 9'd4);
        end
    endfunction

    function letter_O;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_O = rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd16, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd0, 9'd0, 10'd20, 9'd4) ||
                       rect_hit(x, y, 10'd0, 9'd24, 10'd20, 9'd4);
        end
    endfunction

    function letter_V;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_V = rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd22) ||
                       rect_hit(x, y, 10'd16, 9'd0, 10'd4, 9'd22) ||
                       rect_hit(x, y, 10'd6, 9'd20, 10'd8, 9'd8);
        end
    endfunction

    function letter_R;
        input [9:0] x;
        input [8:0] y;
        begin
            letter_R = rect_hit(x, y, 10'd0, 9'd0, 10'd4, 9'd28) ||
                       rect_hit(x, y, 10'd0, 9'd0, 10'd18, 9'd4) ||
                       rect_hit(x, y, 10'd14, 9'd0, 10'd4, 9'd14) ||
                       rect_hit(x, y, 10'd0, 9'd12, 10'd18, 9'd4) ||
                       rect_hit(x, y, 10'd8, 9'd14, 10'd10, 9'd14);
        end
    endfunction

endmodule

module cactus_sprite(
    input  wire [9:0] x,
    input  wire [8:0] y,
    input  wire       valid,
    input  wire signed [10:0] base_x,
    input  wire [2:0] typ,
    output wire       hit,
    output wire [1:0] pix
);
    localparam [8:0] CACTUS_GROUND_Y = 9'd370;

    wire is_large = typ >= 3'd4;
    wire [9:0] w = (typ == 3'd1) ? 10'd26 :
                   (typ == 3'd2) ? 10'd51 :
                   (typ == 3'd3) ? 10'd77 :
                   (typ == 3'd4) ? 10'd38 :
                   (typ == 3'd5) ? 10'd75 : 10'd113;
    wire [8:0] h = is_large ? 9'd75 : 9'd53;
    wire [8:0] top = CACTUS_GROUND_Y - h;
    wire signed [11:0] rel_x = $signed({2'b00, x}) - $signed({base_x[10], base_x});
    wire in_box = valid && (typ != 3'd0) && (rel_x >= 12'sd0) && (rel_x < $signed({2'b00, w})) &&
                  (y >= top) && (y < top + h);
    wire [13:0] addr = (y - top) * w + rel_x[9:0];
    wire [1:0] small_a;
    wire [1:0] small_b;
    wire [1:0] small_c;
    wire [1:0] large_a;
    wire [1:0] large_b;
    wire [1:0] large_c;

    sprite_rom #(.ADDR_WIDTH(11), .MEM_FILE("cactus_small_a.mem")) u_sa(.addr(addr[10:0]), .data(small_a));
    sprite_rom #(.ADDR_WIDTH(12), .MEM_FILE("cactus_small_b.mem")) u_sb(.addr(addr[11:0]), .data(small_b));
    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("cactus_small_c.mem")) u_sc(.addr(addr[12:0]), .data(small_c));
    sprite_rom #(.ADDR_WIDTH(12), .MEM_FILE("cactus_large_a.mem")) u_la(.addr(addr[11:0]), .data(large_a));
    sprite_rom #(.ADDR_WIDTH(13), .MEM_FILE("cactus_large_b.mem")) u_lb(.addr(addr[12:0]), .data(large_b));
    sprite_rom #(.ADDR_WIDTH(14), .MEM_FILE("cactus_large_c.mem")) u_lc(.addr(addr), .data(large_c));

    assign hit = in_box;
    assign pix = !in_box ? 2'b00 :
                 (typ == 3'd1) ? small_a :
                 (typ == 3'd2) ? small_b :
                 (typ == 3'd3) ? small_c :
                 (typ == 3'd4) ? large_a :
                 (typ == 3'd5) ? large_b : large_c;
endmodule

module cloud_sprite(
    input  wire [9:0] x,
    input  wire [8:0] y,
    input  wire       valid,
    input  wire signed [10:0] base_x,
    input  wire [8:0] base_y,
    output wire [1:0] pix
);
    wire signed [11:0] rel_x = $signed({2'b00, x}) - $signed({base_x[10], base_x});
    wire in_box = valid && (rel_x >= 12'sd0) && (rel_x < 12'sd69) && (y >= base_y) && (y < base_y + 9'd20);
    wire [10:0] addr = (y - base_y) * 10'd69 + rel_x[6:0];
    wire [1:0] raw;

    sprite_rom #(.ADDR_WIDTH(11), .MEM_FILE("cloud.mem")) u_cloud(.addr(addr), .data(raw));

    assign pix = in_box ? raw : 2'b00;
endmodule

module ground_sprite #(
    parameter MEM_FILE = "ground_a.mem"
)(
    input  wire [9:0] x,
    input  wire [8:0] y,
    input  wire signed [10:0] base_x,
    output wire [1:0] pix
);
    wire signed [11:0] sx = {2'b00, x};
    wire signed [11:0] bx = {base_x[10], base_x};
    wire signed [11:0] rel = sx - bx;
    wire in_box = (rel >= 12'sd0) && (rel < 12'sd900) && (y >= 9'd360) && (y < 9'd380);
    wire [14:0] addr = (y - 9'd360) * 10'd900 + rel[9:0];
    wire [1:0] raw;

    sprite_rom #(.ADDR_WIDTH(15), .MEM_FILE(MEM_FILE)) u_ground(.addr(addr), .data(raw));

    assign pix = in_box ? raw : 2'b00;
endmodule

module moon_sprite(
    input  wire [9:0] x,
    input  wire [8:0] y,
    input  wire [2:0] phase,
    output wire [1:0] pix
);
    wire in_box = (phase != 3'd0) && (x >= 10'd92) && (x < 10'd122) && (y >= 9'd54) && (y < 9'd114);
    wire [10:0] addr = (y - 9'd54) * 10'd30 + (x - 10'd92);
    wire [1:0] raw;
    wire [9:0] lx = x - 10'd92;

    sprite_rom #(.ADDR_WIDTH(11), .MEM_FILE("moon.mem")) u_moon(.addr(addr), .data(raw));

    assign pix = (!in_box) ? 2'b00 :
                 (phase == 3'd1 && lx > 10'd8)  ? 2'b00 :
                 (phase == 3'd2 && lx > 10'd14) ? 2'b00 :
                 (phase == 3'd4 && lx < 10'd14) ? 2'b00 :
                 (phase == 3'd5 && lx < 10'd21) ? 2'b00 :
                 raw;
endmodule

