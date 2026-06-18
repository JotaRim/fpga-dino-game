`timescale 1ns / 1ps

module vga_ctrl(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pixel_in,

    output reg         clk_25m,
    output reg         frame_end,
    output reg  [9:0]  vga_x,
    output reg  [8:0]  vga_y,
    output reg         hsync,
    output reg         vsync,
    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    localparam H_VISIBLE = 10'd640;
    localparam H_FRONT   = 10'd16;
    localparam H_SYNC    = 10'd96;
    localparam H_BACK    = 10'd48;
    localparam H_TOTAL   = 10'd800;

    localparam V_VISIBLE = 10'd480;
    localparam V_FRONT   = 10'd10;
    localparam V_SYNC    = 10'd2;
    localparam V_BACK    = 10'd33;
    localparam V_TOTAL   = 10'd525;

    reg [1:0] div_cnt;
    wire pix_tick;
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    assign pix_tick = (div_cnt == 2'd3);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div_cnt   <= 2'd0;
            clk_25m   <= 1'b0;
            h_cnt     <= 10'd0;
            v_cnt     <= 10'd0;
            frame_end <= 1'b0;
        end else begin
            frame_end <= 1'b0;
            div_cnt <= div_cnt + 2'd1;
            clk_25m <= div_cnt[1];
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
        vga_x = (h_cnt < H_VISIBLE) ? h_cnt : 10'd0;
        vga_y = (v_cnt < V_VISIBLE) ? v_cnt[8:0] : 9'd0;
        hsync = ~((h_cnt >= (H_VISIBLE + H_FRONT)) && (h_cnt < (H_VISIBLE + H_FRONT + H_SYNC)));
        vsync = ~((v_cnt >= (V_VISIBLE + V_FRONT)) && (v_cnt < (V_VISIBLE + V_FRONT + V_SYNC)));

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