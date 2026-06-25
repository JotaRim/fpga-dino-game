`timescale 1ns / 1ps

// ============================================================
// Testbench for dino_obj_motion
// 覆盖：
//   1. rst / game_start 清空
//   2. IDLE 状态不运动，PLAY 状态随 frame_end 运动
//   3. 地面 speed_px 左移和循环拼接
//   4. 仙人掌、翼龙、云朵生成到空槽位、左移、ready 变化
//   5. 翼龙速度 speed_px+1，云朵速度约 speed_px/2
//   6. 翼龙翅膀动画约 12 帧翻转一次
// ============================================================

module tb_dino_obj_motion;

    reg clk;
    reg rst;
    reg frame_end;
    reg [1:0] game_state;
    reg game_start;
    reg [4:0] speed_px;

    reg cactus_new;
    reg [2:0] cactus_type_new;
    reg ptero_new;
    reg [8:0] ptero_y_new;
    reg cloud_new;
    reg [8:0] cloud_y_new;

    wire signed [10:0] ground_x0;
    wire signed [10:0] ground_x1;

    wire cactus_ready;
    wire ptero_ready;
    wire cloud_ready;

    wire [2:0] cactus_valid;
    wire signed [10:0] cactus_x0;
    wire signed [10:0] cactus_x1;
    wire signed [10:0] cactus_x2;
    wire [2:0] cactus_type0;
    wire [2:0] cactus_type1;
    wire [2:0] cactus_type2;

    wire [1:0] ptero_valid;
    wire signed [10:0] ptero_x0;
    wire signed [10:0] ptero_x1;
    wire [8:0] ptero_y0;
    wire [8:0] ptero_y1;
    wire ptero_state0;
    wire ptero_state1;

    wire [2:0] cloud_valid;
    wire signed [10:0] cloud_x0;
    wire signed [10:0] cloud_x1;
    wire signed [10:0] cloud_x2;
    wire [8:0] cloud_y0;
    wire [8:0] cloud_y1;
    wire [8:0] cloud_y2;

    localparam S_IDLE = 2'b00;
    localparam S_PLAY = 2'b01;
    localparam S_OVER = 2'b11;

    integer pass_count;
    integer fail_count;
    integer i;

    reg signed [10:0] cap_ground_x0;
    reg signed [10:0] cap_ground_x1;
    reg signed [10:0] cap_cactus_x0;
    reg signed [10:0] cap_ptero_x0;
    reg signed [10:0] cap_cloud_x0;

    dino_obj_motion dut(
        .clk(clk),
        .rst(rst),
        .frame_end(frame_end),
        .game_state(game_state),
        .game_start(game_start),
        .speed_px(speed_px),
        .cactus_new(cactus_new),
        .cactus_type_new(cactus_type_new),
        .ptero_new(ptero_new),
        .ptero_y_new(ptero_y_new),
        .cloud_new(cloud_new),
        .cloud_y_new(cloud_y_new),
        .ground_x0(ground_x0),
        .ground_x1(ground_x1),
        .cactus_ready(cactus_ready),
        .ptero_ready(ptero_ready),
        .cloud_ready(cloud_ready),
        .cactus_valid(cactus_valid),
        .cactus_x0(cactus_x0),
        .cactus_x1(cactus_x1),
        .cactus_x2(cactus_x2),
        .cactus_type0(cactus_type0),
        .cactus_type1(cactus_type1),
        .cactus_type2(cactus_type2),
        .ptero_valid(ptero_valid),
        .ptero_x0(ptero_x0),
        .ptero_x1(ptero_x1),
        .ptero_y0(ptero_y0),
        .ptero_y1(ptero_y1),
        .ptero_state0(ptero_state0),
        .ptero_state1(ptero_state1),
        .cloud_valid(cloud_valid),
        .cloud_x0(cloud_x0),
        .cloud_x1(cloud_x1),
        .cloud_x2(cloud_x2),
        .cloud_y0(cloud_y0),
        .cloud_y1(cloud_y1),
        .cloud_y2(cloud_y2)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task check_bit;
        input value;
        input expected;
        input [255:0] name;
        begin
            if (value !== expected) begin
                $display("[FAIL] %s: got %b, expected %b", name, value, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] %s", name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_vec2;
        input [1:0] value;
        input [1:0] expected;
        input [255:0] name;
        begin
            if (value !== expected) begin
                $display("[FAIL] %s: got %b, expected %b", name, value, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] %s", name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_vec3;
        input [2:0] value;
        input [2:0] expected;
        input [255:0] name;
        begin
            if (value !== expected) begin
                $display("[FAIL] %s: got %b, expected %b", name, value, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] %s", name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_u3;
        input [2:0] value;
        input [2:0] expected;
        input [255:0] name;
        begin
            if (value !== expected) begin
                $display("[FAIL] %s: got %0d, expected %0d", name, value, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] %s", name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_u9;
        input [8:0] value;
        input [8:0] expected;
        input [255:0] name;
        begin
            if (value !== expected) begin
                $display("[FAIL] %s: got %0d, expected %0d", name, value, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] %s", name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_s11;
        input signed [10:0] value;
        input signed [10:0] expected;
        input [255:0] name;
        begin
            if (value !== expected) begin
                $display("[FAIL] %s: got %0d, expected %0d", name, value, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] %s", name);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task do_frame;
        begin
            @(negedge clk);
            frame_end = 1'b1;
            @(negedge clk);
            frame_end = 1'b0;
            #1;
        end
    endtask

    task pulse_game_start;
        begin
            @(negedge clk);
            game_start = 1'b1;
            @(negedge clk);
            game_start = 1'b0;
            #1;
        end
    endtask

    task spawn_cactus;
        input [2:0] typ;
        begin
            cactus_type_new = typ;
            cactus_new = 1'b1;
            do_frame;
            cactus_new = 1'b0;
            #1;
        end
    endtask

    task spawn_ptero;
        input [8:0] ypos;
        begin
            ptero_y_new = ypos;
            ptero_new = 1'b1;
            do_frame;
            ptero_new = 1'b0;
            #1;
        end
    endtask

    task spawn_cloud;
        input [8:0] ypos;
        begin
            cloud_y_new = ypos;
            cloud_new = 1'b1;
            do_frame;
            cloud_new = 1'b0;
            #1;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        rst = 1'b1;
        frame_end = 1'b0;
        game_state = S_IDLE;
        game_start = 1'b0;
        speed_px = 5'd5;
        cactus_new = 1'b0;
        cactus_type_new = 3'd1;
        ptero_new = 1'b0;
        ptero_y_new = 9'd160;
        cloud_new = 1'b0;
        cloud_y_new = 9'd120;

        repeat (4) @(negedge clk);
        rst = 1'b0;
        #1;

        $display("\n=== Reset values ===");
        check_s11(ground_x0, 11'sd0,   "ground_x0 reset to 0");
        check_s11(ground_x1, 11'sd900, "ground_x1 reset to 900");
        check_vec3(cactus_valid, 3'b000, "cactus valid reset");
        check_vec2(ptero_valid, 2'b00,   "ptero valid reset");
        check_vec3(cloud_valid, 3'b000,  "cloud valid reset");
        check_bit(cactus_ready, 1'b1, "cactus ready after reset");
        check_bit(ptero_ready,  1'b1, "ptero ready after reset");
        check_bit(cloud_ready,  1'b1, "cloud ready after reset");

        $display("\n=== IDLE should not move ===");
        game_state = S_IDLE;
        do_frame;
        check_s11(ground_x0, 11'sd0,   "ground_x0 unchanged in IDLE");
        check_s11(ground_x1, 11'sd900, "ground_x1 unchanged in IDLE");

        $display("\n=== Ground moves in PLAY ===");
        game_state = S_PLAY;
        speed_px = 5'd5;
        do_frame;
        check_s11(ground_x0, -11'sd5,  "ground_x0 moves by speed_px");
        check_s11(ground_x1, 11'sd895, "ground_x1 moves by speed_px");

        $display("\n=== Object spawning and speed ratios ===");
        spawn_cactus(3'd3);
        check_vec3(cactus_valid, 3'b001, "cactus slot0 valid after spawn");
        check_s11(cactus_x0, 11'sd700,   "cactus slot0 x = 700 after spawn");
        check_u3(cactus_type0, 3'd3,     "cactus slot0 type stored");

        do_frame;
        check_s11(cactus_x0, 11'sd695, "cactus moves by speed_px = 5");

        spawn_ptero(9'd160);
        check_vec2(ptero_valid, 2'b01, "ptero slot0 valid after spawn");
        check_s11(ptero_x0, 11'sd700,  "ptero slot0 x = 700 after spawn");
        check_u9(ptero_y0, 9'd160,     "ptero y stored");

        do_frame;
        check_s11(ptero_x0, 11'sd694, "ptero moves by speed_px + 1 = 6");

        spawn_cloud(9'd120);
        check_vec3(cloud_valid, 3'b001, "cloud slot0 valid after spawn");
        check_s11(cloud_x0, 11'sd700,   "cloud slot0 x = 700 after spawn");
        check_u9(cloud_y0, 9'd120,      "cloud y stored");

        do_frame;
        check_s11(cloud_x0, 11'sd698, "cloud moves by speed_px / 2 = 2");

        $display("\n=== Slot filling and ready ===");
        spawn_cactus(3'd4);
        check_vec3(cactus_valid, 3'b011, "cactus slot1 filled");
        check_bit(cactus_ready, 1'b1,    "cactus ready while one slot remains");
        spawn_cactus(3'd5);
        check_vec3(cactus_valid, 3'b111, "cactus slot2 filled");
        check_bit(cactus_ready, 1'b0,    "cactus not ready when all slots full");

        spawn_ptero(9'd200);
        check_vec2(ptero_valid, 2'b11, "ptero slot1 filled");
        check_bit(ptero_ready, 1'b0,   "ptero not ready when all slots full");

        spawn_cloud(9'd140);
        check_vec3(cloud_valid, 3'b011, "cloud slot1 filled");
        spawn_cloud(9'd160);
        check_vec3(cloud_valid, 3'b111, "cloud slot2 filled");
        check_bit(cloud_ready, 1'b0,    "cloud not ready when all slots full");

        $display("\n=== Pause / OVER should freeze motion ===");
        game_state = S_OVER;
        cap_ground_x0 = ground_x0;
        cap_ground_x1 = ground_x1;
        cap_cactus_x0 = cactus_x0;
        cap_ptero_x0  = ptero_x0;
        cap_cloud_x0  = cloud_x0;
        do_frame;
        check_s11(ground_x0, cap_ground_x0, "ground_x0 frozen in OVER");
        check_s11(ground_x1, cap_ground_x1, "ground_x1 frozen in OVER");
        check_s11(cactus_x0, cap_cactus_x0, "cactus frozen in OVER");
        check_s11(ptero_x0,  cap_ptero_x0,  "ptero frozen in OVER");
        check_s11(cloud_x0,  cap_cloud_x0,  "cloud frozen in OVER");

        $display("\n=== game_start clears all object slots ===");
        pulse_game_start;
        check_vec3(cactus_valid, 3'b000, "cactus cleared by game_start");
        check_vec2(ptero_valid, 2'b00,   "ptero cleared by game_start");
        check_vec3(cloud_valid, 3'b000,  "cloud cleared by game_start");
        check_s11(ground_x0, 11'sd0,     "ground_x0 reset by game_start");
        check_s11(ground_x1, 11'sd900,   "ground_x1 reset by game_start");

        $display("\n=== Ground wrap and object removal at high speed ===");
        game_state = S_PLAY;
        speed_px = 5'd31;
        repeat (30) do_frame;
        check_s11(ground_x0, 11'sd870,  "ground_x0 wraps after leaving left side");
        check_s11(ground_x1, -11'sd30,  "ground_x1 keeps 900px spacing after wrap");

        pulse_game_start;
        game_state = S_PLAY;
        speed_px = 5'd31;
        spawn_cactus(3'd1);
        repeat (25) do_frame;
        check_vec3(cactus_valid, 3'b000, "cactus removed after moving off screen");
        check_bit(cactus_ready, 1'b1,    "cactus ready again after removal");

        // 翼龙动画单独测试：game_start 后生成一只翼龙，12 帧左右应翻转一次。
        pulse_game_start;
        game_state = S_PLAY;
        speed_px = 5'd5;
        spawn_ptero(9'd160);
        check_bit(ptero_state0, 1'b0, "ptero wing initial state 0");
        repeat (11) do_frame;
        check_bit(ptero_state0, 1'b1, "ptero wing toggles after 12 play frames");

        if (fail_count == 0) begin
            $display("\nALL DINO OBJECT MOTION TESTS PASSED. pass=%0d", pass_count);
        end else begin
            $display("\nDINO OBJECT MOTION TESTS FAILED. pass=%0d fail=%0d", pass_count, fail_count);
        end

        #100;
        $finish;
    end

endmodule
