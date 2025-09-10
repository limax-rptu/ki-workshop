`default_nettype none

module tt_um_vga_example(
    input  wire [7:0] ui_in,      // Dedizierte Eingänge
    output wire [7:0] uo_out,     // Dedizierte Ausgänge
    input  wire [7:0] uio_in,     // I/Os: Eingangspfad
    output wire [7:0] uio_out,    // I/Os: Ausgangspfad
    output wire [7:0] uio_oe,     // I/Os: Enable-Pfad (aktiv hoch: 0=Eingang, 1=Ausgang)
    input  wire       ena,        // immer 1, wenn das Design versorgt ist, kann ignoriert werden
    input  wire       clk,        // Takt
    input  wire       rst_n       // reset_n - niedrig zum Zurücksetzen
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

    // TinyVGA PMOD
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // Unbenutzte Ausgänge werden auf 0 gesetzt.
    assign uio_out = 0;
    assign uio_oe  = 0;

    // Unterdrückung von Warnungen für unbenutzte Signale
    wire _unused_ok = &{ena, ui_in, uio_in};

    // Definition des roten Rechtecks
    localparam RECT_X_START = 100;
    localparam RECT_Y_START = 100;
    localparam RECT_WIDTH   = 200;
    localparam RECT_HEIGHT  = 150;

    wire inside_rectangle = (pix_x >= RECT_X_START) && (pix_x < RECT_X_START + RECT_WIDTH) &&
                            (pix_y >= RECT_Y_START) && (pix_y < RECT_Y_START + RECT_HEIGHT);

    assign R = video_active && inside_rectangle ? 2'b11 : 2'b00; // Rote Farbe
    assign G = 2'b00; // Kein Grün
    assign B = 2'b00; // Kein Blau

    // In-Stand-Setzen des VGA-Signalgenerators
    hvsync_generator hvsync_gen(
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );
endmodule
