`timescale 1ns / 1ps

// ============================================================
// Dino Game Logic Top
// 功能：封装键盘输入、状态机、随机生成、运动、计分、音效与碰撞检测。
// 说明：
//   1. 运动与计分均以 frame_end 为帧同步信号更新。
//   2. 输出只包含游戏状态和元素坐标，不产生 VGA 像素数据。
//   3. 元素坐标均为左上角像素坐标，恐龙 X 坐标在本模块中固定。
// ============================================================
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

    // 游戏主状态编码，与显示系统约定保持一致
    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_PAUS = 2'b10;
    localparam S_OVER = 2'b11;

    // 恐龙固定位置与跳跃物理参数
    localparam [9:0] DINO_X = 10'd50;
    // 原始图片脚下有透明留白，因此碰撞/显示基准略低于地平线，使可见脚部贴地。
    localparam [8:0] DINO_STAND_Y = 9'd299;
    localparam [8:0] DINO_DUCK_Y  = 9'd324;
    localparam signed [7:0] JUMP_V0 = -8'sd16;
    localparam signed [7:0] GRAVITY = 8'sd1;
    localparam signed [7:0] FAST_FALL = 8'sd2;

    // 键盘输入解析结果：*_key 表示当前按下，*_trig 表示单周期触发
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

    // 主状态机与恐龙运动相关的组合信号
    wire game_start;
    wire game_over;
    wire hit_flag;
    wire signed [10:0] dino_next_y;
    wire signed [7:0]  dino_accel;
    wire [16:0]        score_step;
    wire [16:0]        score_next;

    // 恐龙运动、动画、分数和音效寄存器
    reg signed [7:0] dino_v;
    reg              jumping;
    reg [3:0]        anim_cnt;
    reg              anim_bit;
    reg [16:0]       score_bin;
    reg [4:0]        speed_px;
    reg [25:0]       press_tone_cnt;
    reg [25:0]       hit_tone_cnt;
    reg [25:0]       reached_tone_cnt;
    reg [15:0]       press_div_cnt;
    reg [15:0]       hit_div_cnt;
    reg [15:0]       reached_div_cnt;
    reg              press_tone;
    reg              hit_tone;
    reg              reached_tone;

    // 随机生成系统与运动系统之间的握手/缓存信号
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

    // 空格和上键都视为跳跃；下键保持按下时进入下蹲/快速下落逻辑
    assign jump_trig = space_trig | up_trig;
    assign duck_key = down_key;
    assign dino_accel = GRAVITY + ((jumping && duck_key) ? FAST_FALL : 8'sd0);
    assign dino_next_y = $signed({2'b00, dino_y}) + $signed(dino_v) + $signed(dino_accel);

    // 分数增长随速度提高而加快，并在 99999 饱和
    assign score_step = (speed_px <= 5'd7)  ? 17'd1 :
                        (speed_px <= 5'd8)  ? 17'd2 :
                        (speed_px <= 5'd10) ? 17'd3 :
                                               17'd4;
    assign score_next = (score_bin >= 17'd99999 - score_step) ? 17'd99999 : (score_bin + score_step);

    // PS/2 键盘输入模块：输出按键保持状态和触发脉冲
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

    // 游戏主状态机：待机、游戏中、暂停、游戏结束
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

    // 随机生成与昼夜系统：决定新障碍/云朵生成和背景阶段
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

    // 物体运动系统：维护地面、仙人掌、翼龙、云朵的槽位和坐标
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


    // 将随机系统的短脉冲缓存到下一帧，避免运动模块错过生成请求
    assign cactus_new = cactus_pending;
    assign cactus_type_new = cactus_type_pending;
    assign ptero_new = ptero_pending;
    assign ptero_y_new = ptero_y_pending;
    assign cloud_new = cloud_pending;
    assign cloud_y_new = cloud_y_pending;

    // 生成请求缓存：收到 *_new_raw 后保持到 frame_end，再交给运动模块消费
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
            // 随机模块可能不与 frame_end 对齐，因此先锁存生成请求。
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


    // 恐龙纵向运动：跳跃、重力、下蹲快速下落以及落地检测
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
        end else if (jump_trig && game_state == S_PLAY && !duck_key && !jumping) begin
            jump_req <= 1'b1;
        end else if (game_state == S_PAUS) begin
            jump_req <= 1'b0;
        end else if (frame_end && game_state == S_PLAY) begin
            if (!jumping && jump_req) begin
                // 起跳只在帧边界真正生效，避免同一帧重复起跳。
                jumping <= 1'b1;
                jump_req <= 1'b0;
                dino_v <= JUMP_V0;
                dino_y <= DINO_STAND_Y - 9'd16;
            end else if (jumping) begin
                jump_req <= 1'b0;
                if (dino_next_y >= $signed({2'b00, DINO_STAND_Y})) begin
                    // 回到站立高度即认为落地，清零速度和跳跃标志。
                    dino_y <= DINO_STAND_Y;
                    dino_v <= 8'sd0;
                    jumping <= 1'b0;
                end else begin
                    dino_y <= dino_next_y[8:0];
                    dino_v <= dino_v + dino_accel;
                end
            end else begin
                dino_y <= DINO_STAND_Y;
            end
        end
    end


    // 恐龙跑步/下蹲动画，每隔若干帧翻转一次姿态
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


    // 根据游戏状态、跳跃/下蹲状态和动画位选择恐龙显示姿态
    always @(*) begin
        if (game_state == S_OVER) begin
            dino_state = 3'b111;
        end else if (jumping) begin
            dino_state = 3'b000;
        end else if (game_state == S_PLAY && duck_key) begin
            dino_state = anim_bit ? 3'b110 : 3'b010;
        end else if (game_state == S_PLAY) begin
            dino_state = anim_bit ? 3'b011 : 3'b001;
        end else begin
            dino_state = 3'b000;
        end
    end


    // 分数与速度控制：分数按帧累加，速度随分数阶段性提升
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            score_bin <= 17'd0;
            speed_px <= 5'd7;
        end else if (game_start) begin
            score_bin <= 17'd0;
            speed_px <= 5'd7;
        end else if (frame_end && game_state == S_PLAY) begin
            score_bin <= score_next;

            // 速度分段提升，障碍和地面运动模块统一使用 speed_px。
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


    // 将二进制分数拆成 5 位 BCD，供显示系统直接使用
    assign score0 = score_bin % 10;
    assign score1 = (score_bin / 10) % 10;
    assign score2 = (score_bin / 100) % 10;
    assign score3 = (score_bin / 1000) % 10;
    assign score4 = (score_bin / 10000) % 10;


    // 简单方波音效：跳跃、碰撞和阶段得分分别使用不同持续时间/频率
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            press_tone_cnt <= 26'd0;
            hit_tone_cnt <= 26'd0;
            reached_tone_cnt <= 26'd0;
            press_div_cnt <= 16'd0;
            hit_div_cnt <= 16'd0;
            reached_div_cnt <= 16'd0;
            press_tone <= 1'b0;
            hit_tone <= 1'b0;
            reached_tone <= 1'b0;
        end else begin
            // 三类音效均通过倒计时控制持续时间，倒计时期间输出分频方波。
            if (game_start || (jump_trig && game_state == S_PLAY && !duck_key && !jumping))
                press_tone_cnt <= 26'd12000000;
            else if (press_tone_cnt != 26'd0)
                press_tone_cnt <= press_tone_cnt - 26'd1;

            if (game_over)
                hit_tone_cnt <= 26'd30000000;
            else if (hit_tone_cnt != 26'd0)
                hit_tone_cnt <= hit_tone_cnt - 26'd1;

            if (frame_end && game_state == S_PLAY && score_bin != 17'd0 && (score_bin / 17'd5000 != score_next / 17'd5000))
                reached_tone_cnt <= 26'd20000000;
            else if (reached_tone_cnt != 26'd0)
                reached_tone_cnt <= reached_tone_cnt - 26'd1;

            if (press_tone_cnt != 26'd0) begin
                if (press_div_cnt == 16'd52000) begin
                    press_div_cnt <= 16'd0;
                    press_tone <= ~press_tone;
                end else begin
                    press_div_cnt <= press_div_cnt + 16'd1;
                end
            end else begin
                press_div_cnt <= 16'd0;
                press_tone <= 1'b0;
            end

            if (hit_tone_cnt != 26'd0) begin
                if (hit_div_cnt == ((hit_tone_cnt > 26'd15000000) ? 16'd65000 : 16'd90000)) begin
                    hit_div_cnt <= 16'd0;
                    hit_tone <= ~hit_tone;
                end else begin
                    hit_div_cnt <= hit_div_cnt + 16'd1;
                end
            end else begin
                hit_div_cnt <= 16'd0;
                hit_tone <= 1'b0;
            end

            if (reached_tone_cnt != 26'd0) begin
                if (reached_div_cnt == ((reached_tone_cnt > 26'd10000000) ? 16'd48000 : 16'd36000)) begin
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


    assign sound_press = press_tone_cnt != 26'd0 ? press_tone : 1'b0;
    assign sound_hit = hit_tone_cnt != 26'd0 ? hit_tone : 1'b0;
    assign sound_reached = reached_tone_cnt != 26'd0 ? reached_tone : 1'b0;


    // 碰撞检测入口：只在游戏中检测恐龙与有效障碍物是否重叠
    wire dino_ducking = (dino_state == 3'b010) || (dino_state == 3'b110);

    assign hit_flag = (game_state == S_PLAY) &&
                      (dino_hits_cactus(cactus_valid[0], cactus_x0, cactus_type0, dino_y, dino_ducking) ||
                       dino_hits_cactus(cactus_valid[1], cactus_x1, cactus_type1, dino_y, dino_ducking) ||
                       dino_hits_cactus(cactus_valid[2], cactus_x2, cactus_type2, dino_y, dino_ducking) ||
                       dino_hits_ptero(pterodactyl_valid[0], pterodactyl_x0, pterodactyl_y0, dino_y, dino_ducking) ||
                       dino_hits_ptero(pterodactyl_valid[1], pterodactyl_x1, pterodactyl_y1, dino_y, dino_ducking));


    // 仙人掌碰撞：按类型拆成单个小/大仙人掌的近似矩形组合
    function dino_hits_cactus;
        input valid;
        input signed [10:0] x;
        input [2:0] typ;
        input [8:0] dy;
        input duck;
        reg [8:0] h;
        reg [8:0] top;
        reg signed [11:0] sx;
        begin
            h = cactus_h(typ);
            top = 9'd370 - h;
            sx = $signed({x[10], x});

            case (typ)
                3'd1: begin
                    dino_hits_cactus =
                        cactus_single_small(valid, sx + 12'sd0, top, dy, duck);
                end

                3'd2: begin
                    dino_hits_cactus =
                        cactus_single_small(valid, sx + 12'sd0, top, dy, duck) ||
                        cactus_single_small(valid, sx + 12'sd25, top, dy, duck);
                end

                3'd3: begin
                    dino_hits_cactus =
                        cactus_single_small(valid, sx + 12'sd0, top, dy, duck) ||
                        cactus_single_small(valid, sx + 12'sd25, top, dy, duck) ||
                        cactus_single_small(valid, sx + 12'sd51, top, dy, duck);
                end

                3'd4: begin
                    dino_hits_cactus =
                        cactus_single_large(valid, sx + 12'sd0, top, dy, duck);
                end

                3'd5: begin
                    dino_hits_cactus =
                        cactus_single_large(valid, sx + 12'sd0, top, dy, duck) ||
                        cactus_single_large(valid, sx + 12'sd37, top, dy, duck);
                end

                3'd6: begin
                    dino_hits_cactus =
                        cactus_single_large(valid, sx + 12'sd0, top, dy, duck) ||
                        cactus_single_large(valid, sx + 12'sd37, top, dy, duck) ||
                        cactus_single_large(valid, sx + 12'sd75, top, dy, duck);
                end

                default: begin
                    dino_hits_cactus = 1'b0;
                end
            endcase
        end
    endfunction


    // 翼龙碰撞：用身体、头部和上下翅膀的多个矩形近似有效区域
    function dino_hits_ptero;
        input valid;
        input signed [10:0] x;
        input [8:0] y;
        input [8:0] dy;
        input duck;
        begin
            dino_hits_ptero =
                dino_overlap_rect(valid, $signed({x[10], x}) + 12'sd18, y + 9'd25, 10'd34, 9'd15, dy, duck) ||
                dino_overlap_rect(valid, $signed({x[10], x}) + 12'sd49, y + 9'd18, 10'd13, 9'd15, dy, duck) ||
                dino_overlap_rect(valid, $signed({x[10], x}) + 12'sd16, y + 9'd12, 10'd25, 9'd12, dy, duck) ||
                dino_overlap_rect(valid, $signed({x[10], x}) + 12'sd16, y + 9'd40, 10'd25, 9'd11, dy, duck);
        end
    endfunction


    // 单个小仙人掌的有效碰撞区域，避开图片透明和空白部分
    function cactus_single_small;
        input valid;
        input signed [11:0] x;
        input [8:0] top;
        input [8:0] dy;
        input duck;
        begin
            cactus_single_small =
                dino_overlap_rect(valid, x + 12'sd9,  top + 9'd5,  10'd8,  9'd43, dy, duck) ||
                dino_overlap_rect(valid, x + 12'sd3,  top + 9'd21, 10'd7,  9'd12, dy, duck) ||
                dino_overlap_rect(valid, x + 12'sd15, top + 9'd15, 10'd7,  9'd14, dy, duck);
        end
    endfunction


    // 单个大仙人掌的有效碰撞区域
    function cactus_single_large;
        input valid;
        input signed [11:0] x;
        input [8:0] top;
        input [8:0] dy;
        input duck;
        begin
            cactus_single_large =
                dino_overlap_rect(valid, x + 12'sd15, top + 9'd5,  10'd11, 9'd62, dy, duck) ||
                dino_overlap_rect(valid, x + 12'sd5,  top + 9'd31, 10'd12, 9'd17, dy, duck) ||
                dino_overlap_rect(valid, x + 12'sd24, top + 9'd21, 10'd12, 9'd20, dy, duck);
        end
    endfunction


    // 恐龙碰撞区域：站立/跳跃和下蹲使用不同的矩形近似
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


    // 仙人掌整体宽度查询函数，保留用于后续扩展或接口兼容
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


    // 通用 AABB 矩形重叠判断
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
