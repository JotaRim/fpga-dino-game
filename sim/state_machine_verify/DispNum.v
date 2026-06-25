`timescale 1ns / 1ps

// lab 中已完成的模块

module Decoder2 (
    output out_0,
    output out_1,
    output out_2,
    output out_3,
    input [1:0] sel
);
    assign out_0 = (sel == 2'h0)? 1'b1 : 1'b0;
    assign out_1 = (sel == 2'h1)? 1'b1 : 1'b0;
    assign out_2 = (sel == 2'h2)? 1'b1 : 1'b0;
    assign out_3 = (sel == 2'h3)? 1'b1 : 1'b0;
endmodule


module Mux4to1 (
  input [1:0] S,
  input [3:0] I,
  output O
);
  assign O = (((~ S[0] & ~ S[1]) & I[0]) | ((S[0] & ~ S[1]) & I[1]) | ((~ S[0] & S[1]) & I[2]) | ((S[0] & S[1]) & I[3]));
endmodule

module Mux4to1b4 (
  input [1:0] S,
  input [3:0] I0,
  input [3:0] I1,
  input [3:0] I2,
  input [3:0] I3,
  output [3:0] O
);
  wire s0;
  wire s1;
  wire s2;
  wire s3;
  wire s4;
  wire s5;
  wire s6;
  wire s7;
  assign s0 = S[0];
  assign s1 = S[1];
  assign s2 = ~ s0;
  assign s3 = ~ s1;
  assign s7 = (s0 & s1);
  assign s4 = (s2 & s3);
  assign s5 = (s0 & s3);
  assign s6 = (s2 & s1);
  assign O[0] = ((s4 & I0[0]) | (s5 & I1[0]) | (s6 & I2[0]) | (s7 & I3[0]));
  assign O[1] = ((s4 & I0[1]) | (s5 & I1[1]) | (s6 & I2[1]) | (s7 & I3[1]));
  assign O[2] = ((s4 & I0[2]) | (s5 & I1[2]) | (s6 & I2[2]) | (s7 & I3[2]));
  assign O[3] = ((s4 & I0[3]) | (s5 & I1[3]) | (s6 & I2[3]) | (s7 & I3[3]));
endmodule

module MyMC14495 (
  input LE,
  input point,
  input D3,
  input D2,
  input D1,
  input D0,
  output g,
  output e,
  output c,
  output f,
  output d,
  output b,
  output a,
  output p
);
  wire s0;
  wire s1;
  wire s2;
  wire s3;
  assign s3 = ~ D0;
  assign s0 = ~ D1;
  assign s1 = ~ D2;
  assign s2 = ~ D3;
  assign p = (~ point | LE);
  assign g = (((s3 & s0 & D2 & D3) | (D0 & D1 & D2 & s2) | (s0 & s1 & s2)) | LE);
  assign e = (((D0 & s0 & s1) | (s0 & D2 & s2) | (D0 & s2)) | LE);
  assign c = (((D1 & D2 & D3) | (s3 & D2 & D3) | (s3 & D1 & s1 & s2)) | LE);
  assign f = (((D0 & s0 & D2 & D3) | (D0 & D1 & s2) | (D1 & s1 & s2) | (D0 & s1 & s2)) | LE);
  assign d = (((s3 & D1 & s1 & D3) | (D0 & D1 & D2) | (s3 & s0 & D2 & s2) | (D0 & s0 & s1 & s2)) | LE);
  assign b = (((D0 & D1 & D3) | (s3 & D2 & D3) | (s3 & D1 & D2) | (D0 & s0 & D2 & s2)) | LE);
  assign a = (((D0 & s0 & D2 & D3) | (D0 & D1 & s1 & D3) | (s3 & s0 & D2 & s2) | (D0 & s0 & s1 & s2)) | LE);
endmodule

module DispNum (
  input [1:0] scan,
  input [15:0] HEXS,
  input [3:0] point,
  input [3:0] LES,
  output [3:0] AN,
  output [7:0] SEGMENT
);
  wire s0;
  wire s1;
  wire s2;
  wire s3;
  wire [3:0] s4;
  wire [3:0] s5;
  wire [3:0] s6;
  wire [3:0] s7;
  wire [3:0] s8;
  wire s9;
  wire s10;
  wire s11;
  wire s12;
  wire s13;
  wire s14;
  wire s15;
  wire s16;
  wire s17;
  wire s18;
  wire s19;
  wire s20;
  wire s21;
  wire s22;
  Decoder2 Decoder2_i0 (
    .sel( scan ),
    .out_0( s0 ),
    .out_1( s1 ),
    .out_2( s2 ),
    .out_3( s3 )
  );
  Mux4to1 Mux4to1_i1 (
    .S( scan ),
    .I( point ),
    .O( s9 )
  );
  Mux4to1 Mux4to1_i2 (
    .S( scan ),
    .I( LES ),
    .O( s10 )
  );
  assign s4 = HEXS[3:0];
  assign s5 = HEXS[7:4];
  assign s6 = HEXS[11:8];
  assign s7 = HEXS[15:12];
  assign AN[0] = ~ s0;
  assign AN[1] = ~ s1;
  assign AN[2] = ~ s2;
  assign AN[3] = ~ s3;
  Mux4to1b4 Mux4to1b4_i3 (
    .S( scan ),
    .I0( s4 ),
    .I1( s5 ),
    .I2( s6 ),
    .I3( s7 ),
    .O( s8 )
  );
  assign s14 = s8[0];
  assign s13 = s8[1];
  assign s12 = s8[2];
  assign s11 = s8[3];
  MyMC14495 MyMC14495_i4 (
    .LE( s10 ),
    .point( s9 ),
    .D3( s11 ),
    .D2( s12 ),
    .D1( s13 ),
    .D0( s14 ),
    .g( s15 ),
    .e( s16 ),
    .c( s17 ),
    .f( s18 ),
    .d( s19 ),
    .b( s20 ),
    .a( s21 ),
    .p( s22 )
  );
  assign SEGMENT[0] = s21;
  assign SEGMENT[1] = s20;
  assign SEGMENT[2] = s17;
  assign SEGMENT[3] = s19;
  assign SEGMENT[4] = s16;
  assign SEGMENT[5] = s18;
  assign SEGMENT[6] = s15;
  assign SEGMENT[7] = s22;
endmodule
