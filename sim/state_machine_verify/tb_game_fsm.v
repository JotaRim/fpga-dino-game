`timescale 1ns / 1ps

// ============================================================
// Testbench for game_fsm
// 验证目标：
//   1. rst 后进入待机状态。
//   2. space_trig 在 IDLE / OVER 两帧之间出现时会被锁存，
//      并在下一次 frame_end 进入游戏中。
//   3. PLAY 状态下 space_trig 应被忽略，不能残留到 OVER 后触发重开。
//   4. game_start / game_over 只保持一个 clk 周期。
//   5. PLAY 状态下 hit_flag 在 frame_end 有效时进入 OVER。
//   6. OVER 状态下再次 space_trig 后，在下一次 frame_end 重开游戏。
// ============================================================

module tb_game_fsm_fixed;

    reg        clk;
    reg        rst;
    reg        frame_end;
    reg        space_trig;
    reg        hit_flag;

    wire [1:0] game_state;
    wire       game_start;
    wire       game_over;

    integer err_cnt;

    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_OVER = 2'b11;

    game_fsm dut(
        .clk        (clk),
        .rst        (rst),
        .frame_end  (frame_end),
        .space_trig (space_trig),
        .hit_flag   (hit_flag),
        .game_state (game_state),
        .game_start (game_start),
        .game_over  (game_over)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;   // 100MHz
    end

    task check_state;
        input [1:0] exp_state;
        input [8*96:1] msg;
        begin
            if (game_state !== exp_state) begin
                $display("[FAIL] %0s: game_state=%b, expected=%b", msg, game_state, exp_state);
                err_cnt = err_cnt + 1;
            end else begin
                $display("[PASS] %0s", msg);
            end
        end
    endtask

    task check_bit;
        input got;
        input exp;
        input [8*96:1] msg;
        begin
            if (got !== exp) begin
                $display("[FAIL] %0s: got=%b, expected=%b", msg, got, exp);
                err_cnt = err_cnt + 1;
            end else begin
                $display("[PASS] %0s", msg);
            end
        end
    endtask

    task one_clk_space;
        begin
            @(posedge clk);
            space_trig <= 1'b1;
            @(posedge clk);
            space_trig <= 1'b0;
        end
    endtask

    task one_frame;
        begin
            @(posedge clk);
            frame_end <= 1'b1;
            @(posedge clk);
            #1;
            frame_end <= 1'b0;
        end
    endtask

    initial begin
        err_cnt    = 0;
        rst        = 1'b1;
        frame_end  = 1'b0;
        space_trig = 1'b0;
        hit_flag   = 1'b0;

        repeat (3) @(posedge clk);
        #1;
        check_state(S_IDLE, "reset enters IDLE");
        check_bit(game_start, 1'b0, "game_start is 0 after reset");
        check_bit(game_over,  1'b0, "game_over is 0 after reset");

        rst <= 1'b0;
        repeat (2) @(posedge clk);
        #1;
        check_state(S_IDLE, "stay IDLE after reset released");

        // --------------------------------------------------------
        // IDLE: space_trig 出现在 frame_end 之前，应先锁存，不应立即改变状态。
        // --------------------------------------------------------
        one_clk_space();
        repeat (2) @(posedge clk);
        #1;
        check_state(S_IDLE, "space before frame does not change state immediately");

        one_frame();
        #1;
        check_state(S_PLAY, "IDLE -> PLAY on next frame_end after space");
        check_bit(game_start, 1'b1, "game_start pulse when entering PLAY");
        check_bit(game_over,  1'b0, "game_over remains 0 when entering PLAY");

        @(posedge clk);
        #1;
        check_bit(game_start, 1'b0, "game_start clears after one clk");

        // --------------------------------------------------------
        // 关键回归测试：PLAY 状态下按空格，之后碰撞进入 OVER。
        // 期望：PLAY 中的空格被忽略，不能残留为 OVER -> PLAY 的重开请求。
        // --------------------------------------------------------
        one_clk_space();
        repeat (2) @(posedge clk);
        #1;
        check_state(S_PLAY, "space in PLAY does not change state immediately");

        one_frame();
        #1;
        check_state(S_PLAY, "space in PLAY is ignored at frame_end");
        check_bit(game_start, 1'b0, "no repeated game_start in PLAY");

        @(posedge clk);
        hit_flag <= 1'b1;
        repeat (2) @(posedge clk);
        #1;
        check_state(S_PLAY, "hit before frame does not change state immediately");

        one_frame();
        #1;
        check_state(S_OVER, "PLAY -> OVER on frame_end with hit_flag high");
        check_bit(game_over,  1'b1, "game_over pulse when entering OVER");
        check_bit(game_start, 1'b0, "game_start remains 0 when entering OVER");

        @(posedge clk);
        hit_flag <= 1'b0;
        #1;
        check_bit(game_over, 1'b0, "game_over clears after one clk");
        check_state(S_OVER, "stay OVER after hit removed");

        one_frame();
        #1;
        check_state(S_OVER, "old PLAY-space must not restart game after OVER");
        check_bit(game_start, 1'b0, "no game_start caused by stale PLAY-space");

        // --------------------------------------------------------
        // OVER: 新的 space_trig 后在下一帧重新进入 PLAY。
        // --------------------------------------------------------
        one_clk_space();
        repeat (2) @(posedge clk);
        #1;
        check_state(S_OVER, "restart space before frame keeps OVER temporarily");

        one_frame();
        #1;
        check_state(S_PLAY, "OVER -> PLAY on next frame_end after new space");
        check_bit(game_start, 1'b1, "game_start pulse when restarting");

        @(posedge clk);
        #1;
        check_bit(game_start, 1'b0, "restart game_start clears after one clk");

        // --------------------------------------------------------
        // 异步复位：PLAY 中拉高 rst，应立即回到 IDLE。
        // --------------------------------------------------------
        #2;
        rst <= 1'b1;
        #1;
        check_state(S_IDLE, "async reset returns to IDLE immediately");
        check_bit(game_start, 1'b0, "game_start cleared by reset");
        check_bit(game_over,  1'b0, "game_over cleared by reset");

        if (err_cnt == 0)
            $display("\nALL GAME FSM TESTS PASSED.");
        else
            $display("\nGAME FSM TESTS FAILED: %0d error(s).", err_cnt);

        $finish;
    end

endmodule
