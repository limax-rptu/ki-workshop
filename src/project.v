`default_nettype none

module tt_um_vga_example(
    input wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input wire ena,
    input wire clk,
    input wire rst_n
);

    // VGA-Signale
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 0;
    assign uio_oe  = 0;
    wire _unused_ok = &{ena, ui_in, uio_in};

    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // Mittelpunkt der Blume
    localparam CENTER_X = 320;
    localparam CENTER_Y = 240;
    localparam CORE_RADIUS = 20;
    localparam PETAL_RADIUS = 40;

    // Kern der Blume (braun)
    wire is_core = ((pix_x - CENTER_X)*(pix_x - CENTER_X) + (pix_y - CENTER_Y)*(pix_y - CENTER_Y)) <= (CORE_RADIUS*CORE_RADIUS);

    // Blütenblätter (gelb)
    wire is_petal = ((pix_x - CENTER_X)*(pix_x - CENTER_X) + (pix_y - CENTER_Y)*(pix_y - CENTER_Y)) <= (PETAL_RADIUS*PETAL_RADIUS)
                    && !is_core;

    // Grüner Stiel
    localparam STEM_WIDTH = 8;
    localparam STEM_HEIGHT = 100;
    wire is_stem = (pix_x >= CENTER_X - STEM_WIDTH/2) && (pix_x <= CENTER_X + STEM_WIDTH/2) &&
                   (pix_y > CENTER_Y + PETAL_RADIUS) && (pix_y <= CENTER_Y + PETAL_RADIUS + STEM_HEIGHT);

    // Blätter
    localparam LEAF_WIDTH = 30;
    localparam LEAF_HEIGHT = 15;
    // Linkes Blatt
    wire is_leaf_left = (pix_x >= CENTER_X - LEAF_WIDTH - 4) && (pix_x <= CENTER_X - 4) &&
                        (pix_y >= CENTER_Y + PETAL_RADIUS + 30) && (pix_y <= CENTER_Y + PETAL_RADIUS + 30 + LEAF_HEIGHT);
    // Rechtes Blatt
    wire is_leaf_right = (pix_x >= CENTER_X + 4) && (pix_x <= CENTER_X + LEAF_WIDTH + 4) &&
                         (pix_y >= CENTER_Y + PETAL_RADIUS + 50) && (pix_y <= CENTER_Y + PETAL_RADIUS + 50 + LEAF_HEIGHT);

    wire is_leaf = is_leaf_left || is_leaf_right;

    // Farben zuweisen
    assign R = video_active ? (is_core ? 2'b11 : (is_petal ? 2'b11 : 2'b00)) : 2'b00;
    assign G = video_active ? (is_core ? 2'b01 : ((is_petal || is_stem || is_leaf) ? 2'b11 : 2'b00)) : 2'b00;
    assign B = video_active ? 2'b00 : 2'b00;

endmodule
