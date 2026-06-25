`timescale 1ns / 1ps

// ============================================================
// Testbench for dino_key_input
// 覆盖：
//   1. Space 按下 / 长按重复码 / 释放
//   2. Up 扩展键按下 / 长按重复码 / 释放
//   3. Down 扩展键按下 / 释放
//   4. 错误校验帧不会改变按键状态，也不会产生触发脉冲
// ============================================================

module tb_dino_key_input;

    reg clk;
    reg rst;
    reg ps2_clk;
    reg ps2_data;

    wire space_key;
    wire up_key;
    wire down_key;
    wire space_trig;
    wire up_trig;
    wire down_trig;

    integer err_cnt;
    integer space_trig_cnt;
    integer up_trig_cnt;
    integer down_trig_cnt;

    dino_key_input uut(
        .clk        (clk),
        .rst        (rst),
        .ps2_clk    (ps2_clk),
        .ps2_data   (ps2_data),
        .space_key  (space_key),
        .up_key     (up_key),
        .down_key   (down_key),
        .space_trig (space_trig),
        .up_trig    (up_trig),
        .down_trig  (down_trig)
    );

    // 100MHz 系统时钟
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (rst) begin
            space_trig_cnt <= 0;
            up_trig_cnt    <= 0;
            down_trig_cnt  <= 0;
        end else begin
            if (space_trig)
                space_trig_cnt <= space_trig_cnt + 1;
            if (up_trig)
                up_trig_cnt <= up_trig_cnt + 1;
            if (down_trig)
                down_trig_cnt <= down_trig_cnt + 1;
        end
    end

    task check;
        input cond;
        input [255:0] msg;
        begin
            if (cond) begin
                $display("[PASS] %s", msg);
            end else begin
                $display("[FAIL] %s", msg);
                err_cnt = err_cnt + 1;
            end
        end
    endtask

    task ps2_send_bit;
        input bit_val;
        begin
            // PS/2 数据在时钟下降沿前保持稳定，接收端在下降沿采样。
            ps2_data = bit_val;
            #20000;
            ps2_clk = 1'b0;
            #20000;
            ps2_clk = 1'b1;
            #20000;
        end
    endtask

    task ps2_send_byte;
        input [7:0] data;
        reg parity;
        integer i;
        begin
            // PS/2 使用奇校验：8位数据与校验位异或结果为1。
            parity = ~(^data);

            ps2_send_bit(1'b0);       // start bit
            for (i = 0; i < 8; i = i + 1)
                ps2_send_bit(data[i]);
            ps2_send_bit(parity);     // parity bit
            ps2_send_bit(1'b1);       // stop bit

            ps2_data = 1'b1;
            ps2_clk  = 1'b1;
            #120000;
        end
    endtask

    task ps2_send_bad_parity_byte;
        input [7:0] data;
        reg parity;
        integer i;
        begin
            parity = ^data;           // 故意使用错误校验位

            ps2_send_bit(1'b0);
            for (i = 0; i < 8; i = i + 1)
                ps2_send_bit(data[i]);
            ps2_send_bit(parity);
            ps2_send_bit(1'b1);

            ps2_data = 1'b1;
            ps2_clk  = 1'b1;
            #120000;
        end
    endtask

    initial begin
        err_cnt = 0;
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        rst = 1'b1;
        #1000;
        rst = 1'b0;
        #1000;

        check((space_key == 1'b0) && (up_key == 1'b0) && (down_key == 1'b0),
              "reset clears all key states");

        // --------------------------------------------------------
        // Space: make / repeat make / break
        // --------------------------------------------------------
        ps2_send_byte(8'h29);
        #1000;
        check((space_key == 1'b1) && (space_trig_cnt == 1),
              "Space make: key=1 and one trigger");

        ps2_send_byte(8'h29);
        #1000;
        check((space_key == 1'b1) && (space_trig_cnt == 1),
              "Space repeated make while held: no extra trigger");

        ps2_send_byte(8'hF0);
        ps2_send_byte(8'h29);
        #1000;
        check((space_key == 1'b0) && (space_trig_cnt == 1),
              "Space break: key returns to 0");

        // --------------------------------------------------------
        // Up: E0 75 / E0 75 repeat / E0 F0 75
        // --------------------------------------------------------
        ps2_send_byte(8'hE0);
        ps2_send_byte(8'h75);
        #1000;
        check((up_key == 1'b1) && (up_trig_cnt == 1),
              "Up make: key=1 and one trigger");

        ps2_send_byte(8'hE0);
        ps2_send_byte(8'h75);
        #1000;
        check((up_key == 1'b1) && (up_trig_cnt == 1),
              "Up repeated make while held: no extra trigger");

        ps2_send_byte(8'hE0);
        ps2_send_byte(8'hF0);
        ps2_send_byte(8'h75);
        #1000;
        check((up_key == 1'b0) && (up_trig_cnt == 1),
              "Up break: key returns to 0");

        // --------------------------------------------------------
        // Down: E0 72 / E0 F0 72
        // --------------------------------------------------------
        ps2_send_byte(8'hE0);
        ps2_send_byte(8'h72);
        #1000;
        check((down_key == 1'b1) && (down_trig_cnt == 1),
              "Down make: key=1 and one trigger");

        ps2_send_byte(8'hE0);
        ps2_send_byte(8'hF0);
        ps2_send_byte(8'h72);
        #1000;
        check((down_key == 1'b0) && (down_trig_cnt == 1),
              "Down break: key returns to 0");

        // --------------------------------------------------------
        // Bad parity: should be ignored
        // --------------------------------------------------------
        ps2_send_bad_parity_byte(8'h29);
        #1000;
        check((space_key == 1'b0) && (space_trig_cnt == 1),
              "bad parity Space frame is ignored");

        if (err_cnt == 0)
            $display("\nALL PS/2 TESTS PASSED.\n");
        else
            $display("\nPS/2 TESTS FAILED: %0d error(s).\n", err_cnt);

        #1000;
        $finish;
    end

endmodule
