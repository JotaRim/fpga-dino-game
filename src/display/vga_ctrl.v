`timescale 1ns / 1ps

// ============================================================
// VGA 控制器
// 功能：
//   1. 由 100MHz 系统时钟分频得到约 25MHz 像素时钟；
//   2. 按照 640×480@60Hz VGA 时序产生行/场同步信号；
//   3. 输出当前可见区域内的像素坐标 vga_x、vga_y；
//   4. 在每一帧结束时产生单周期 frame_end 脉冲，作为游戏逻辑更新节拍。
// ============================================================
module vga_ctrl(
    input  wire        clk,       // 100MHz 全局时钟
    input  wire        rst,       // 异步高电平复位
    input  wire [11:0] pixel_in,  // 显示系统生成的 RGB444 像素颜色

    output reg         clk_25m,    // 约 25MHz VGA 像素时钟
    output reg         frame_end,  // 每帧结束时拉高一个 clk 周期
    output reg  [9:0]  vga_x,      // 当前像素 X 坐标，仅可见区域有效
    output reg  [8:0]  vga_y,      // 当前像素 Y 坐标，仅可见区域有效
    output reg         hsync,      // VGA 行同步信号，低电平有效
    output reg         vsync,      // VGA 场同步信号，低电平有效
    output reg  [3:0]  vga_r,      // VGA 红色分量
    output reg  [3:0]  vga_g,      // VGA 绿色分量
    output reg  [3:0]  vga_b       // VGA 蓝色分量
);

    // VGA 640×480@60Hz 标准水平时序参数
    localparam H_VISIBLE = 10'd640;  // 可见像素宽度
    localparam H_FRONT   = 10'd16;   // 行前沿
    localparam H_SYNC    = 10'd96;   // 行同步脉冲宽度
    localparam H_BACK    = 10'd48;   // 行后沿
    localparam H_TOTAL   = 10'd800;  // 一整行的总像素周期数

    // VGA 640×480@60Hz 标准垂直时序参数
    localparam V_VISIBLE = 10'd480;  // 可见像素高度
    localparam V_FRONT   = 10'd10;   // 场前沿
    localparam V_SYNC    = 10'd2;    // 场同步脉冲宽度
    localparam V_BACK    = 10'd33;   // 场后沿
    localparam V_TOTAL   = 10'd525;  // 一整帧的总行数

    // 4 分频计数器：100MHz / 4 = 25MHz
    reg [1:0] div_cnt;
    wire pix_tick;
    // 当前扫描位置计数器，包含可见区和消隐区
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    // 每 4 个系统时钟更新一次 VGA 扫描位置
    assign pix_tick = (div_cnt == 2'd3);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div_cnt   <= 2'd0;
            clk_25m   <= 1'b0;
            h_cnt     <= 10'd0;
            v_cnt     <= 10'd0;
            frame_end <= 1'b0;
        end else begin
            // 默认不产生帧结束脉冲，仅在最后一个扫描点置 1
            frame_end <= 1'b0;
            div_cnt <= div_cnt + 2'd1;
            clk_25m <= div_cnt[1];

            // 像素节拍到来时，推进水平/垂直扫描计数器
            if (pix_tick) begin
                if (h_cnt == H_TOTAL - 10'd1) begin
                    h_cnt <= 10'd0;
                    if (v_cnt == V_TOTAL - 10'd1) begin
                        v_cnt <= 10'd0;
                        frame_end <= 1'b1;
                    end else begin
                        v_cnt <= v_cnt + 10'd1;
                    end
                end else begin
                    h_cnt <= h_cnt + 10'd1;
                end
            end
        end
    end

    always @(*) begin
        // 只在可见区域输出真实坐标；消隐区坐标清零，避免上层误用
        vga_x = (h_cnt < H_VISIBLE) ? h_cnt : 10'd0;
        vga_y = (v_cnt < V_VISIBLE) ? v_cnt[8:0] : 9'd0;

        // VGA 同步信号为低电平有效
        hsync = ~((h_cnt >= (H_VISIBLE + H_FRONT)) && (h_cnt < (H_VISIBLE + H_FRONT + H_SYNC)));
        vsync = ~((v_cnt >= (V_VISIBLE + V_FRONT)) && (v_cnt < (V_VISIBLE + V_FRONT + V_SYNC)));

        // 可见区域输出像素颜色；消隐区输出黑色
        if ((h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE)) begin
            vga_r = pixel_in[11:8];
            vga_g = pixel_in[7:4];
            vga_b = pixel_in[3:0];
        end else begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end
    end

endmodule
