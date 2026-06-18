`timescale 1ns / 1ps

// ============================================================
// Dino Game Main FSM
// 功能：控制游戏主状态：待机、游戏中、游戏结束。
// 说明：
//   1. rst 为异步高电平复位，复位后进入待机状态。
//   2. 状态只在 frame_end 到来时更新，保证游戏逻辑按帧推进。
//   3. space_trig 为键盘模块输出的单周期空格按下脉冲。
//   4. hit_flag 由碰撞检测模块给出。
// ============================================================

module game_fsm(
    input  wire       clk,         // 100MHz 全局时钟
    input  wire       rst,         // 异步高电平复位
    input  wire       frame_end,   // 每帧一个 clk 周期的高脉冲
    input  wire       space_trig,  // 空格键按下单周期脉冲
    input  wire       pause_trig,  // P键按下单周期脉冲
    input  wire       hit_flag,    // 碰撞标志

    output reg  [1:0] game_state,  // 00=待机，01=游戏中，11=游戏结束
    output reg        game_start,  // 进入游戏中的单周期脉冲
    output reg        game_over    // 进入游戏结束的单周期脉冲
);

    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_PAUS = 2'b10;  // 暂停状态预留，当前不使用
    localparam S_OVER = 2'b11;

    reg [1:0] next_state;
    reg       start_req;
    reg       pause_req;

    // ------------------------------------------------------------
    // 空格请求锁存
    // space_trig 只有一个 clk 周期，而状态机按 frame_end 更新。
    // 因此先锁存请求，防止在两帧之间按键时被漏掉。
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            start_req <= 1'b0;
            pause_req <= 1'b0;
        end else begin
            if (space_trig && (game_state == S_IDLE || game_state == S_OVER))
                start_req <= 1'b1;
            else if (frame_end && (game_state != S_PLAY) && start_req)
                start_req <= 1'b0;
            else if (game_state == S_PLAY || game_state == S_PAUS)
                start_req <= 1'b0;

            if (pause_trig)
                pause_req <= 1'b1;
            else if (frame_end && pause_req)
                pause_req <= 1'b0;
        end
    end

    // ------------------------------------------------------------
    // 次态组合逻辑
    // ------------------------------------------------------------
    always @(*) begin
        next_state = game_state;

        case (game_state)
            S_IDLE: begin
                if (start_req)
                    next_state = S_PLAY;
            end

            S_PLAY: begin
                if (pause_req)
                    next_state = S_PAUS;
                else if (hit_flag)
                    next_state = S_OVER;
            end

            S_PAUS: begin
                if (pause_req)
                    next_state = S_PLAY;
            end

            S_OVER: begin
                if (start_req)
                    next_state = S_PLAY;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // ------------------------------------------------------------
    // 状态寄存器
    // 状态更新统一放在 frame_end 时刻。
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            game_state <= S_IDLE;
            game_start <= 1'b0;
            game_over  <= 1'b0;
        end else begin
            game_start <= 1'b0;
            game_over  <= 1'b0;

            if (frame_end) begin
                game_state <= next_state;

                if ((game_state != S_PLAY) && (next_state == S_PLAY))
                    game_start <= 1'b1;

                if ((game_state == S_PLAY) && (next_state == S_OVER))
                    game_over <= 1'b1;
            end
        end
    end

endmodule
