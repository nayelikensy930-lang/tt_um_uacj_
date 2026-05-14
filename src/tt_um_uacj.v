/*
 * Copyright (c) 2024 Tiny Tapeout LTD
 * SPDX-License-Identifier: Apache-2.0
 * Author: Uri Shaked
 */

`default_nettype none

parameter LOGO_WIDTH  = 128;
parameter LOGO_HEIGHT = 40;
parameter DISPLAY_WIDTH  = 640;
parameter DISPLAY_HEIGHT = 480;
`define COLOR_WHITE 3'd7

module tt_um_uacj (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  wire hsync, vsync;
  reg [1:0] R, G, B;
  wire video_active;
  wire [9:0] pix_x, pix_y;

  wire cfg_tile  = ui_in[0];
  wire cfg_color = ui_in[1];

  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  wire _unused_ok = &{ena, ui_in[7:2], uio_in};

  hvsync_generator vga_sync_gen (
      .clk      (clk),
      .reset    (~rst_n),
      .hsync    (hsync),
      .vsync    (vsync),
      .display_on(video_active),
      .hpos     (pix_x),
      .vpos     (pix_y)
  );

  reg [9:0] logo_left, logo_top;
  reg       dir_x, dir_y;
  reg [9:0] prev_y;
  reg [2:0] color_index;

  wire pixel_value;
  wire [5:0] color;

  wire [9:0] x = pix_x - logo_left;
  wire [9:0] y = pix_y - logo_top;
  wire in_logo = cfg_tile || (x < LOGO_WIDTH && y < LOGO_HEIGHT);

  bitmap_rom rom1 (
      .x    (x[6:0]),
      .y    (y[5:0]),
      .pixel(pixel_value)
  );

  palette palette_inst (
      .color_index(cfg_color ? color_index : `COLOR_WHITE),
      .rrggbb     (color)
  );

  // RGB output
  always @(posedge clk) begin
    if (~rst_n) begin
      R <= 0; G <= 0; B <= 0;
    end else begin
      if (video_active && in_logo && pixel_value) begin
        R <= color[5:4];
        G <= color[3:2];
        B <= color[1:0];
      end else begin
        R <= 0; G <= 0; B <= 0;
      end
    end
  end

  // Bounce logic (once per frame at vblank)
  always @(posedge clk) begin
    if (~rst_n) begin
      logo_left   <= 10'd200;
      logo_top    <= 10'd200;
      dir_x       <= 1'b1;
      dir_y       <= 1'b0;
      color_index <= 3'd0;
      prev_y      <= 10'd0;
    end else begin
      prev_y <= pix_y;

      if (pix_y == 10'd0 && prev_y != 10'd0) begin
        logo_left <= logo_left + (dir_x ? 10'd1 : -10'd1);
        logo_top  <= logo_top  + (dir_y ? 10'd1 : -10'd1);

        if (!dir_x && logo_left <= 10'd1) begin
          dir_x       <= 1'b1;
          color_index <= color_index + 3'd1;
        end
        if (dir_x && logo_left >= DISPLAY_WIDTH - LOGO_WIDTH - 1) begin
          dir_x       <= 1'b0;
          color_index <= color_index + 3'd1;
        end
        if (!dir_y && logo_top <= 10'd1) begin
          dir_y       <= 1'b1;
          color_index <= color_index + 3'd1;
        end
        if (dir_y && logo_top >= DISPLAY_HEIGHT - LOGO_HEIGHT - 1) begin
          dir_y       <= 1'b0;
          color_index <= color_index + 3'd1;
        end
      end
    end
  end

endmodule
