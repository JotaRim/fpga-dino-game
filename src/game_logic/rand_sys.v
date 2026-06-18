`timescale 1ns / 1ps

// ============================================================
// Dino Random System
// 功能：生成障碍物、云朵和昼夜变化信息。
// 说明：
//   1. 本模块只产生“生成请求”，不直接维护元素坐标。
//   2. 运动系统收到 *_new 后，再选择空槽位并设置初始坐标。
//   3. 所有随机事件只在 frame_end 到来时判断一次。
// ============================================================

module dino_rand_sys(
    input  wire       clk,          // 100MHz 全局时钟
    input  wire       rst,          // 异步高电平复位
    input  wire       frame_end,    // 每帧一个 clk 周期的高脉冲
    input  wire [1:0] game_state,   // 00=待机，01=游戏中，11=游戏结束
    input  wire       game_start,   // 进入游戏中的单周期脉冲
    input  wire [4:0] speed_px,     // 当前每帧移动像素数，建议 5~8

    input  wire       cactus_ready, // 运动系统中是否有空仙人掌槽位
    input  wire       ptero_ready,  // 运动系统中是否有空翼龙槽位
    input  wire       cloud_ready,  // 运动系统中是否有空云朵槽位

    output reg        cactus_new,   // 生成仙人掌的单周期脉冲
    output reg  [2:0] cactus_type,  // 001:011=小仙人掌，100:110=大仙人掌
    output reg        ptero_new,    // 生成翼龙的单周期脉冲
    output reg  [8:0] ptero_y,      // 翼龙左上角 Y 坐标
    output reg        cloud_new,    // 生成云朵的单周期脉冲
    output reg  [8:0] cloud_y,      // 云朵左上角 Y 坐标

    output reg        obs_skip,     // 随机命中但间距不足或槽位不足
    output reg  [2:0] moon_phase,   // 0~5 表示 6 种月相
    output wire       night,        // 0=白天，1=夜晚
    output reg  [2:0] day_night_cycle
);

    localparam S_PLAY = 2'b01;

    // 按建议物理参数估算：初速度18、重力1，最长滞空约36帧。
    // min_gap = max(speed_px * 36 + 32, 300)，单位为像素。
    localparam [11:0] AIR_FRM    = 12'd36;
    localparam [11:0] GAP_MARGIN = 12'd32;
    localparam [11:0] GAP_MIN    = 12'd300;
    localparam [11:0] CLOUD_GAP  = 12'd160;

    // 障碍物按最小安全距离确定生成，避免上板调试时长时间等不到随机事件。
    localparam [7:0] OBS_PROB = 8'd18;

    // 每600帧切换一个昼夜阶段，约10秒。
    localparam [9:0] DAY_FRM = 10'd600;

    wire [29:0] rand;
    wire [11:0] jump_gap;
    wire [11:0] min_gap;
    wire [11:0] speed_ext;
    wire        is_play;
    wire        obs_try;
    wire        obs_due;
    wire        cloud_try;
    wire        cloud_due;
    wire        want_cactus;

    reg  [11:0] obs_gap;
    reg  [11:0] cloud_gap;
    reg  [9:0]  day_cnt;
    reg  [2:0]  obs_seq;

    assign is_play     = (game_state == S_PLAY);
    assign speed_ext   = {7'd0, speed_px};
    assign jump_gap    = speed_ext * AIR_FRM + GAP_MARGIN;
    assign min_gap     = (jump_gap < GAP_MIN) ? GAP_MIN : jump_gap;
    assign obs_try     = (rand[7:0] < OBS_PROB);
    assign obs_due     = (obs_gap >= min_gap + 12'd240);
    assign cloud_try   = (rand[23:19] == 5'd0);
    assign cloud_due   = (cloud_gap >= CLOUD_GAP + 12'd160);
    assign want_cactus = (obs_seq != 3'd2) && (obs_seq != 3'd5);
    assign night       = day_night_cycle[2];

    rand_lfsr u_rand(
        .clk  (clk),
        .rst  (rst),
        .en   (frame_end),
        .data (rand)
    );

    // ------------------------------------------------------------
    // 按随机数选择仙人掌类型
    // ------------------------------------------------------------
    always @(*) begin
        case (rand[13:11])
            3'd0: cactus_type = 3'b001;
            3'd1: cactus_type = 3'b010;
            3'd2: cactus_type = 3'b011;
            3'd3: cactus_type = 3'b100;
            3'd4: cactus_type = 3'b101;
            default: cactus_type = 3'b110;
        endcase
    end

    // ------------------------------------------------------------
    // 障碍物和云朵生成
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            obs_gap    <= 12'd0;
            cloud_gap  <= 12'd0;
            obs_seq    <= 3'd0;
            cactus_new <= 1'b0;
            ptero_new  <= 1'b0;
            cloud_new  <= 1'b0;
            ptero_y    <= 9'd240;
            cloud_y    <= 9'd130;
            obs_skip   <= 1'b0;
        end else begin
            cactus_new <= 1'b0;
            ptero_new  <= 1'b0;
            cloud_new  <= 1'b0;
            obs_skip   <= 1'b0;

            if (game_start) begin
                obs_gap   <= GAP_MIN;
                cloud_gap <= CLOUD_GAP;
                obs_seq   <= 3'd0;
            end else if (frame_end && is_play) begin
                if (obs_gap < (12'hfff - speed_ext))
                    obs_gap <= obs_gap + speed_ext;
                else
                    obs_gap <= 12'hfff;

                if (cloud_gap < (12'hfff - speed_ext))
                    cloud_gap <= cloud_gap + speed_ext;
                else
                    cloud_gap <= 12'hfff;

                if (obs_due || obs_try) begin
                    if (obs_gap < min_gap) begin
                        obs_skip <= 1'b1;
                    end else if (want_cactus && cactus_ready) begin
                        cactus_new <= 1'b1;
                        obs_gap <= 12'd0;
                        obs_seq <= obs_seq + 3'd1;
                    end else if (!want_cactus && ptero_ready) begin
                        ptero_new <= 1'b1;
                        obs_gap <= 12'd0;
                        obs_seq <= obs_seq + 3'd1;

                        case (rand[15:14])
                            2'd0: ptero_y <= 9'd265;  // 高空，站立会擦到头部
                            2'd1: ptero_y <= 9'd290;  // 中空
                            2'd2: ptero_y <= 9'd305;  // 低空
                            default: ptero_y <= 9'd290;
                        endcase
                    end else begin
                        obs_skip <= 1'b1;
                    end
                end

                if ((cloud_try || cloud_due) && (cloud_gap >= CLOUD_GAP) && cloud_ready) begin
                    cloud_new <= 1'b1;
                    cloud_y <= 9'd110 + {3'd0, rand[5:0]};
                    cloud_gap <= 12'd0;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // 昼夜和月相变化
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            day_cnt <= 10'd0;
            day_night_cycle <= 3'd0;
            moon_phase <= 3'd3;
        end else begin
            if (game_start) begin
                day_cnt <= 10'd0;
                day_night_cycle <= 3'd0;
                moon_phase <= 3'd3;
            end else if (frame_end && is_play) begin
                if (day_cnt == DAY_FRM - 10'd1) begin
                    day_cnt <= 10'd0;
                    day_night_cycle <= day_night_cycle + 3'd1;

                    if (day_night_cycle == 3'd7) begin
                        if (moon_phase == 3'd5)
                            moon_phase <= 3'd0;
                        else
                            moon_phase <= moon_phase + 3'd1;
                    end
                end else begin
                    day_cnt <= day_cnt + 10'd1;
                end
            end
        end
    end

endmodule


// ============================================================
// 30位 Fibonacci LFSR
// 说明：用于生成伪随机数。en 为1时更新一次。
// ============================================================

module rand_lfsr(
    input  wire       clk,
    input  wire       rst,
    input  wire       en,
    output reg [29:0] data
);

    wire feedback;
    assign feedback = data[29] ^ data[5] ^ data[3] ^ data[0];

    always @(posedge clk or posedge rst) begin
        if (rst)
            data <= 30'h20000029;
        else if (en)
            data <= {data[28:0], feedback};
    end

endmodule
