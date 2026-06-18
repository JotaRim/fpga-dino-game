`timescale 1ns / 1ps

module dino_game_logic(
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_end,
    input  wire        PS2_clk,
    input  wire        PS2_data,

    output wire [1:0]  game_state,
    output reg  [8:0]  dino_y,
    output reg  [2:0]  dino_state,
    output wire signed [10:0] ground_x0,
    output wire signed [10:0] ground_x1,

    output wire [2:0]  cactus_valid,
    output wire signed [10:0] cactus_x0,
    output wire signed [10:0] cactus_x1,
    output wire signed [10:0] cactus_x2,
    output wire [2:0]  cactus_type0,
    output wire [2:0]  cactus_type1,
    output wire [2:0]  cactus_type2,

    output wire [1:0]  pterodactyl_valid,
    output wire signed [10:0] pterodactyl_x0,
    output wire signed [10:0] pterodactyl_x1,
    output wire [8:0]  pterodactyl_y0,
    output wire [8:0]  pterodactyl_y1,
    output wire        pterodactyl_state0,
    output wire        pterodactyl_state1,

    output wire [2:0]  cloud_valid,
    output wire signed [10:0] cloud_x0,
    output wire signed [10:0] cloud_x1,
    output wire signed [10:0] cloud_x2,
    output wire [8:0]  cloud_y0,
    output wire [8:0]  cloud_y1,
    output wire [8:0]  cloud_y2,

    output wire [2:0]  moon_phase,
    output wire        night,
    output wire [2:0]  day_night_cycle,

    output wire        sound_press,
    output wire        sound_hit,
    output wire        sound_reached,
    output wire [3:0]  score0,
    output wire [3:0]  score1,
    output wire [3:0]  score2,
    output wire [3:0]  score3,
    output wire [3:0]  score4
);

    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_PAUS = 2'b10;
    localparam S_OVER = 2'b11;

    localparam [9:0] DINO_X = 10'd50;
    // The source sprite has transparent padding below the feet. Put the
    // bounding box a few pixels below the horizon so the visible feet touch it.
    localparam [8:0] DINO_STAND_Y = 9'd299;
    localparam [8:0] DINO_DUCK_Y  = 9'd324;
    localparam signed [7:0] JUMP_V0 = -8'sd16;
    localparam signed [7:0] GRAVITY = 8'sd1;

    wire space_key;
    wire up_key;
    wire down_key;
    wire p_key;
    wire space_trig;
    wire up_trig;
    wire down_trig;
    wire p_trig;
    wire jump_trig;
    wire duck_key;
    reg  jump_req;

    wire game_start;
    wire game_over;
    wire hit_flag;
    wire signed [10:0] dino_next_y;

    reg signed [7:0] dino_v;
    reg              jumping;
    reg [3:0]        anim_cnt;
    reg              anim_bit;
    reg [16:0]       score_bin;
    reg [4:0]        speed_px;
    reg [16:0]       press_tone_cnt;
    reg [17:0]       hit_tone_cnt;
    reg [17:0]       reached_tone_cnt;
    reg [15:0]       press_div_cnt;
    reg [15:0]       hit_div_cnt;
    reg [15:0]       reached_div_cnt;
    reg              press_tone;
    reg              hit_tone;
    reg              reached_tone;

    wire cactus_ready;
    wire ptero_ready;
    wire cloud_ready;
    wire cactus_new_raw;
    wire [2:0] cactus_type_raw;
    wire ptero_new_raw;
    wire [8:0] ptero_y_raw;
    wire cloud_new_raw;
    wire [8:0] cloud_y_raw;
    reg  cactus_pending;
    reg  [2:0] cactus_type_pending;
    reg  ptero_pending;
    reg  [8:0] ptero_y_pending;
    reg  cloud_pending;
    reg  [8:0] cloud_y_pending;
    wire cactus_new;
    wire [2:0] cactus_type_new;
    wire ptero_new;
    wire [8:0] ptero_y_new;
    wire cloud_new;
    wire [8:0] cloud_y_new;
    wire obs_skip;

    assign jump_trig = space_trig | up_trig;
    assign duck_key = down_key;
    assign dino_next_y = $signed({2'b00, dino_y}) + $signed(dino_v) + $signed(GRAVITY);

    dino_key_input u_key(
        .clk        (clk),
        .rst        (rst),
        .ps2_clk    (PS2_clk),
        .ps2_data   (PS2_data),
        .space_key  (space_key),
        .up_key     (up_key),
        .down_key   (down_key),
        .p_key      (p_key),
        .space_trig (space_trig),
        .up_trig    (up_trig),
        .down_trig  (down_trig),
        .p_trig     (p_trig)
    );

    game_fsm u_fsm(
        .clk         (clk),
        .rst         (rst),
        .frame_end   (frame_end),
        .space_trig  (jump_trig),
        .pause_trig  (p_trig),
        .hit_flag    (hit_flag),
        .game_state  (game_state),
        .game_start  (game_start),
        .game_over   (game_over)
    );

    dino_rand_sys u_rand(
        .clk             (clk),
        .rst             (rst),
        .frame_end       (frame_end),
        .game_state      (game_state),
        .game_start      (game_start),
        .speed_px        (speed_px),
        .cactus_ready    (cactus_ready),
        .ptero_ready     (ptero_ready),
        .cloud_ready     (cloud_ready),
        .cactus_new      (cactus_new_raw),
        .cactus_type     (cactus_type_raw),
        .ptero_new       (ptero_new_raw),
        .ptero_y         (ptero_y_raw),
        .cloud_new       (cloud_new_raw),
        .cloud_y         (cloud_y_raw),
        .obs_skip        (obs_skip),
        .moon_phase      (moon_phase),
        .night           (night),
        .day_night_cycle (day_night_cycle)
    );

    dino_obj_motion u_motion(
        .clk              (clk),
        .rst              (rst),
        .frame_end        (frame_end),
        .game_state       (game_state),
        .game_start       (game_start),
        .speed_px         (speed_px),
        .cactus_new       (cactus_new),
        .cactus_type_new  (cactus_type_new),
        .ptero_new        (ptero_new),
        .ptero_y_new      (ptero_y_new),
        .cloud_new        (cloud_new),
        .cloud_y_new      (cloud_y_new),
        .ground_x0        (ground_x0),
        .ground_x1        (ground_x1),
        .cactus_ready     (cactus_ready),
        .ptero_ready      (ptero_ready),
        .cloud_ready      (cloud_ready),
        .cactus_valid     (cactus_valid),
        .cactus_x0        (cactus_x0),
        .cactus_x1        (cactus_x1),
        .cactus_x2        (cactus_x2),
        .cactus_type0     (cactus_type0),
        .cactus_type1     (cactus_type1),
        .cactus_type2     (cactus_type2),
        .ptero_valid      (pterodactyl_valid),
        .ptero_x0         (pterodactyl_x0),
        .ptero_x1         (pterodactyl_x1),
        .ptero_y0         (pterodactyl_y0),
        .ptero_y1         (pterodactyl_y1),
        .ptero_state0     (pterodactyl_state0),
        .ptero_state1     (pterodactyl_state1),
        .cloud_valid      (cloud_valid),
        .cloud_x0         (cloud_x0),
        .cloud_x1         (cloud_x1),
        .cloud_x2         (cloud_x2),
        .cloud_y0         (cloud_y0),
        .cloud_y1         (cloud_y1),
        .cloud_y2         (cloud_y2)
    );

    assign cactus_new = cactus_pending;
    assign cactus_type_new = cactus_type_pending;
    assign ptero_new = ptero_pending;
    assign ptero_y_new = ptero_y_pending;
    assign cloud_new = cloud_pending;
    assign cloud_y_new = cloud_y_pending;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cactus_pending <= 1'b0;
            cactus_type_pending <= 3'd0;
            ptero_pending <= 1'b0;
            ptero_y_pending <= 9'd0;
            cloud_pending <= 1'b0;
            cloud_y_pending <= 9'd0;
        end else if (game_start) begin
            cactus_pending <= 1'b0;
            cactus_type_pending <= 3'd0;
            ptero_pending <= 1'b0;
            ptero_y_pending <= 9'd0;
            cloud_pending <= 1'b0;
            cloud_y_pending <= 9'd0;
        end else begin
            if (cactus_new_raw) begin
                cactus_pending <= 1'b1;
                cactus_type_pending <= cactus_type_raw;
            end else if (frame_end && cactus_pending) begin
                cactus_pending <= 1'b0;
            end

            if (ptero_new_raw) begin
                ptero_pending <= 1'b1;
                ptero_y_pending <= ptero_y_raw;
            end else if (frame_end && ptero_pending) begin
                ptero_pending <= 1'b0;
            end

            if (cloud_new_raw) begin
                cloud_pending <= 1'b1;
                cloud_y_pending <= cloud_y_raw;
            end else if (frame_end && cloud_pending) begin
                cloud_pending <= 1'b0;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dino_y <= DINO_STAND_Y;
            dino_v <= 8'sd0;
            jumping <= 1'b0;
            jump_req <= 1'b0;
        end else if (game_start) begin
            dino_y <= DINO_STAND_Y;
            dino_v <= 8'sd0;
            jumping <= 1'b0;
            jump_req <= 1'b0;
        end else if (jump_trig && game_state == S_PLAY) begin
            jump_req <= 1'b1;
        end else if (game_state == S_PAUS) begin
            jump_req <= 1'b0;
        end else if (frame_end && game_state == S_PLAY) begin
            if (!jumping && jump_req) begin
                jumping <= 1'b1;
                jump_req <= 1'b0;
                dino_v <= JUMP_V0;
                dino_y <= DINO_STAND_Y - 9'd16;
            end else if (jumping) begin
                jump_req <= 1'b0;
                if (dino_next_y >= $signed({2'b00, DINO_STAND_Y})) begin
                    dino_y <= DINO_STAND_Y;
                    dino_v <= 8'sd0;
                    jumping <= 1'b0;
                end else begin
                    dino_y <= dino_next_y[8:0];
                    dino_v <= dino_v + GRAVITY;
                end
            end else begin
                dino_y <= DINO_STAND_Y;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            anim_cnt <= 4'd0;
            anim_bit <= 1'b0;
        end else if (game_start) begin
            anim_cnt <= 4'd0;
            anim_bit <= 1'b0;
        end else if (frame_end && game_state == S_PLAY) begin
            if (anim_cnt == 4'd5) begin
                anim_cnt <= 4'd0;
                anim_bit <= ~anim_bit;
            end else begin
                anim_cnt <= anim_cnt + 4'd1;
            end
        end
    end

    always @(*) begin
        if (game_state == S_OVER) begin
            dino_state = 3'b111;
        end else if (game_state == S_PLAY && duck_key) begin
            dino_state = anim_bit ? 3'b110 : 3'b010;
        end else if (jumping) begin
            dino_state = 3'b000;
        end else if (game_state == S_PLAY) begin
            dino_state = anim_bit ? 3'b011 : 3'b001;
        end else begin
            dino_state = 3'b000;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            score_bin <= 17'd0;
            speed_px <= 5'd7;
        end else if (game_start) begin
            score_bin <= 17'd0;
            speed_px <= 5'd7;
        end else if (frame_end && game_state == S_PLAY) begin
            if (score_bin != 17'd99999)
                score_bin <= score_bin + 17'd1;

            if (score_bin < 17'd500)
                speed_px <= 5'd7;
            else if (score_bin < 17'd1000)
                speed_px <= 5'd8;
            else if (score_bin < 17'd2000)
                speed_px <= 5'd9;
            else if (score_bin < 17'd3500)
                speed_px <= 5'd10;
            else
                speed_px <= 5'd11;
        end
    end

    assign score0 = score_bin % 10;
    assign score1 = (score_bin / 10) % 10;
    assign score2 = (score_bin / 100) % 10;
    assign score3 = (score_bin / 1000) % 10;
    assign score4 = (score_bin / 10000) % 10;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            press_tone_cnt <= 17'd0;
            hit_tone_cnt <= 18'd0;
            reached_tone_cnt <= 18'd0;
            press_div_cnt <= 16'd0;
            hit_div_cnt <= 16'd0;
            reached_div_cnt <= 16'd0;
            press_tone <= 1'b0;
            hit_tone <= 1'b0;
            reached_tone <= 1'b0;
        end else begin
            if (jump_trig)
                press_tone_cnt <= 17'd100000;
            else if (press_tone_cnt != 17'd0)
                press_tone_cnt <= press_tone_cnt - 17'd1;

            if (game_over)
                hit_tone_cnt <= 18'd250000;
            else if (hit_tone_cnt != 18'd0)
                hit_tone_cnt <= hit_tone_cnt - 18'd1;

            if (frame_end && game_state == S_PLAY && score_bin != 17'd0 && (score_bin % 17'd100 == 17'd0))
                reached_tone_cnt <= 18'd160000;
            else if (reached_tone_cnt != 18'd0)
                reached_tone_cnt <= reached_tone_cnt - 18'd1;

            if (press_tone_cnt != 17'd0) begin
                if (press_div_cnt == 16'd28000) begin
                    press_div_cnt <= 16'd0;
                    press_tone <= ~press_tone;
                end else begin
                    press_div_cnt <= press_div_cnt + 16'd1;
                end
            end else begin
                press_div_cnt <= 16'd0;
                press_tone <= 1'b0;
            end

            if (hit_tone_cnt != 18'd0) begin
                if (hit_div_cnt == 16'd45000) begin
                    hit_div_cnt <= 16'd0;
                    hit_tone <= ~hit_tone;
                end else begin
                    hit_div_cnt <= hit_div_cnt + 16'd1;
                end
            end else begin
                hit_div_cnt <= 16'd0;
                hit_tone <= 1'b0;
            end

            if (reached_tone_cnt != 18'd0) begin
                if (reached_div_cnt == 16'd18000) begin
                    reached_div_cnt <= 16'd0;
                    reached_tone <= ~reached_tone;
                end else begin
                    reached_div_cnt <= reached_div_cnt + 16'd1;
                end
            end else begin
                reached_div_cnt <= 16'd0;
                reached_tone <= 1'b0;
            end
        end
    end

    assign sound_press = press_tone_cnt != 17'd0 ? press_tone : 1'b0;
    assign sound_hit = hit_tone_cnt != 18'd0 ? hit_tone : 1'b0;
    assign sound_reached = reached_tone_cnt != 18'd0 ? reached_tone : 1'b0;

    wire dino_ducking = (dino_state == 3'b010) || (dino_state == 3'b110);

    assign hit_flag = (game_state == S_PLAY) &&
                      (dino_hits_cactus(cactus_valid[0], cactus_x0, cactus_type0, dino_y, dino_ducking) ||
                       dino_hits_cactus(cactus_valid[1], cactus_x1, cactus_type1, dino_y, dino_ducking) ||
                       dino_hits_cactus(cactus_valid[2], cactus_x2, cactus_type2, dino_y, dino_ducking) ||
                       dino_hits_ptero(pterodactyl_valid[0], pterodactyl_x0, pterodactyl_y0, dino_y, dino_ducking) ||
                       dino_hits_ptero(pterodactyl_valid[1], pterodactyl_x1, pterodactyl_y1, dino_y, dino_ducking));

    function dino_hits_cactus;
        input valid;
        input signed [10:0] x;
        input [2:0] typ;
        input [8:0] dy;
        input duck;
        reg [9:0] w;
        reg [8:0] h;
        reg signed [11:0] ox;
        reg [8:0] oy;
        reg [9:0] ow;
        reg [8:0] oh;
        begin
            w = cactus_w(typ);
            h = cactus_h(typ);
            ox = x + 11'sd4;
            oy = 9'd370 - h + 9'd4;
            ow = w - 10'd8;
            oh = h - 9'd8;
            dino_hits_cactus = dino_overlap_rect(valid && typ != 3'd0, ox, oy, ow, oh, dy, duck);
        end
    endfunction

    function dino_hits_ptero;
        input valid;
        input signed [10:0] x;
        input [8:0] y;
        input [8:0] dy;
        input duck;
        begin
            dino_hits_ptero = dino_overlap_rect(valid, x + 11'sd8, y + 9'd12, 10'd52, 9'd32, dy, duck);
        end
    endfunction

    function dino_overlap_rect;
        input valid;
        input signed [11:0] ox;
        input [8:0] oy;
        input [9:0] ow;
        input [8:0] oh;
        input [8:0] dy;
        input duck;
        begin
            if (duck) begin
                dino_overlap_rect =
                    rect_overlap(valid, ox, oy, ow, oh,
                                 $signed({2'b00, DINO_X}) + 12'sd8, DINO_DUCK_Y + 9'd12, 10'd58, 9'd24) ||
                    rect_overlap(valid, ox, oy, ow, oh,
                                 $signed({2'b00, DINO_X}) + 12'sd56, DINO_DUCK_Y + 9'd4, 10'd22, 9'd18);
            end else begin
                dino_overlap_rect =
                    rect_overlap(valid, ox, oy, ow, oh,
                                 $signed({2'b00, DINO_X}) + 12'sd14, dy + 9'd18, 10'd30, 9'd34) ||
                    rect_overlap(valid, ox, oy, ow, oh,
                                 $signed({2'b00, DINO_X}) + 12'sd38, dy + 9'd4, 10'd20, 9'd20) ||
                    rect_overlap(valid, ox, oy, ow, oh,
                                 $signed({2'b00, DINO_X}) + 12'sd23, dy + 9'd52, 10'd10, 9'd14) ||
                    rect_overlap(valid, ox, oy, ow, oh,
                                 $signed({2'b00, DINO_X}) + 12'sd41, dy + 9'd52, 10'd9, 9'd14);
            end
        end
    endfunction

    function [9:0] cactus_w;
        input [2:0] typ;
        begin
            case (typ)
                3'd1: cactus_w = 10'd26;
                3'd2: cactus_w = 10'd51;
                3'd3: cactus_w = 10'd77;
                3'd4: cactus_w = 10'd38;
                3'd5: cactus_w = 10'd75;
                default: cactus_w = 10'd113;
            endcase
        end
    endfunction

    function [8:0] cactus_h;
        input [2:0] typ;
        begin
            cactus_h = (typ >= 3'd4) ? 9'd75 : 9'd53;
        end
    endfunction

    function rect_overlap;
        input valid;
        input signed [11:0] ax;
        input [8:0] ay;
        input [9:0] aw;
        input [8:0] ah;
        input signed [11:0] bx;
        input [8:0] by;
        input [9:0] bw;
        input [8:0] bh;
        begin
            rect_overlap = valid &&
                           (ax < bx + bw) && (ax + aw > bx) &&
                           (ay < by + bh) && (ay + ah > by);
        end
    endfunction

endmodule
