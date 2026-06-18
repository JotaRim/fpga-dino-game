`timescale 1ns / 1ps

module sprite_rom #(
    parameter integer ADDR_WIDTH = 14,
    parameter integer DATA_WIDTH = 2,
    parameter MEM_FILE = "dino_default.mem"
)(
    input  wire [ADDR_WIDTH-1:0] addr,
    output wire [DATA_WIDTH-1:0] data
);

    localparam integer DEPTH = (1 << ADDR_WIDTH);

    (* rom_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
        $readmemh(MEM_FILE, mem);
    end

    assign data = mem[addr];

endmodule

