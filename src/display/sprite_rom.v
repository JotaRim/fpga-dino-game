`timescale 1ns / 1ps

// ============================================================
// 精灵图片 ROM
// 功能：根据输入地址 addr，从指定的 .mem 文件中读取精灵像素数据。
// 说明：
//   1. MEM_FILE 由上层实例化时指定，对应不同图片资源。
//   2. DATA_WIDTH 默认为 2 bit，通常用于表示透明/黑/白等简单颜色编码。
//   3. 该模块只负责资源读取，不参与坐标判断和像素优先级选择。
// ============================================================
module sprite_rom #(
    // ROM 地址宽度，决定最多可寻址的像素数据数量
    parameter integer ADDR_WIDTH = 14,
    // 每个像素数据的位宽
    parameter integer DATA_WIDTH = 2,
    // 初始化文件名，由 Vivado 工程中的 .mem 文件提供
    parameter MEM_FILE = "dino_default.mem"
)(
    input  wire [ADDR_WIDTH-1:0] addr,  // 当前要读取的 ROM 地址
    output wire [DATA_WIDTH-1:0] data   // 对应地址处的像素编码
);

    // ROM 深度为 2^ADDR_WIDTH
    localparam integer DEPTH = (1 << ADDR_WIDTH);

    // 使用 block RAM 风格综合，节省 LUT 资源并适合存放图片数据
    (* rom_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        // 先将 ROM 全部清零，避免未覆盖地址出现不确定值
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
        // 从十六进制文本文件中加载精灵数据
        $readmemh(MEM_FILE, mem);
    end

    // 异步读出当前地址的数据，供显示系统组合逻辑使用
    assign data = mem[addr];

endmodule
