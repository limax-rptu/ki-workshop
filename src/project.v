module tt_um_yourgithub_penguin_fish (
    input  wire [7:0] ui_in,    // ui_in[0] = Pfeil hoch / Springen
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,      // VGA Playground: 25 MHz
    input  wire       rst_n
);

    // ------------------------------------------------------------
    // VGA 640x480 @ 60 Hz
    // Horizontal: 640 aktiv + 16 + 96 + 48 = 800
    // Vertikal:   480 aktiv + 10 + 2 + 33 = 525
    // ------------------------------------------------------------
    reg [9:0] hpos;
    reg [9:0] vpos;

    wire active_video;
    wire hsync;
    wire vsync;
    wire end_of_frame;

    assign active_video = (hpos < 10'd640) && (vpos < 10'd480);

    // Negative VGA-Synchronisation.
    assign hsync = !((hpos >= 10'd656) && (hpos < 10'd752));
    assign vsync = !((vpos >= 10'd490) && (vpos < 10'd492));

    assign end_of_frame = (hpos == 10'd799) && (vpos == 10'd524);

    // VGA-Zähler mit synchronem aktiv-low Reset.
    always @(posedge clk) begin
        if (!rst_n) begin
            hpos <= 10'd0;
            vpos <= 10'd0;
        end else begin
            if (hpos == 10'd799) begin
                hpos <= 10'd0;

                if (vpos == 10'd524)
                    vpos <= 10'd0;
                else
                    vpos <= vpos + 10'd1;
            end else begin
                hpos <= hpos + 10'd1;
            end
        end
    end

    // ------------------------------------------------------------
    // Spielzustand
    // ------------------------------------------------------------

    // Linke Position des Pinguins.
    reg [9:0] penguin_x;

    // Sprunghöhe: 0 = Boden, 72 = maximale Höhe.
    reg [6:0] jump_height;

    // Laufanimation und aktueller Wegabschnitt.
    reg       leg_phase;
    reg [1:0] level;

    // Drei Eisblöcke je Wegabschnitt.
    reg [9:0] obstacle1_x;
    reg [9:0] obstacle2_x;
    reg [9:0] obstacle3_x;

    reg [5:0] obstacle1_w;
    reg [5:0] obstacle2_w;
    reg [5:0] obstacle3_w;

    reg [6:0] obstacle1_h;
    reg [6:0] obstacle2_h;
    reg [6:0] obstacle3_h;

    // 1 = Fisch wurde bereits gegessen und wird nicht mehr gezeichnet.
    reg fish1_eaten;
    reg fish2_eaten;
    reg fish3_eaten;

    // 12 Frames bei 60 Hz sind etwa 0,2 Sekunden Leuchten.
    reg [3:0] flash_frames;

    wire penguin_flash;
    assign penguin_flash = (flash_frames != 4'd0);

    // Sprungzustandsautomat.
    localparam [1:0] JUMP_GROUND = 2'd0;
    localparam [1:0] JUMP_RISE   = 2'd1;
    localparam [1:0] JUMP_HOVER  = 2'd2;
    localparam [1:0] JUMP_FALL   = 2'd3;

    reg [1:0] jump_state;

    // Die Hoch-Pfeiltaste muss im Playground auf ui_in[0] gemappt werden.
    wire jump_button;
    assign jump_button = ui_in[0];

    // Der Pinguin ist ungefähr 86 Pixel breit, inklusive Schnabel.
    wire obstacle_ahead;

    assign obstacle_ahead =
        ((penguin_x + 10'd88 >= obstacle1_x) &&
         (penguin_x < obstacle1_x + {4'd0, obstacle1_w}) &&
         (jump_height < obstacle1_h)) ||

        ((penguin_x + 10'd88 >= obstacle2_x) &&
         (penguin_x < obstacle2_x + {4'd0, obstacle2_w}) &&
         (jump_height < obstacle2_h)) ||

        ((penguin_x + 10'd88 >= obstacle3_x) &&
         (penguin_x < obstacle3_x + {4'd0, obstacle3_w}) &&
         (jump_height < obstacle3_h));

    // ------------------------------------------------------------
    // Fische auf Schnabelhöhe.
    //
    // Der Schnabel befindet sich beim Sprung etwa bei y=200.
    // Alle Fische sind fest auf dieser Bildschirmhöhe.
    // ------------------------------------------------------------
    localparam [9:0] FISH_Y = 10'd200;

    wire touch_fish1;
    wire touch_fish2;
    wire touch_fish3;

    // Schnabel: x = penguin_x+70 .. penguin_x+86
    // Fisch:    x = obstacle_x .. obstacle_x+30
    // Der Schnabel erreicht y=200 ab ungefähr jump_height=47.
    assign touch_fish1 =
        !fish1_eaten &&
        (penguin_x + 10'd86 >= obstacle1_x) &&
        (penguin_x + 10'd70 < obstacle1_x + 10'd30) &&
        (jump_height >= 7'd47);

    assign touch_fish2 =
        !fish2_eaten &&
        (penguin_x + 10'd86 >= obstacle2_x) &&
        (penguin_x + 10'd70 < obstacle2_x + 10'd30) &&
        (jump_height >= 7'd47);

    assign touch_fish3 =
        !fish3_eaten &&
        (penguin_x + 10'd86 >= obstacle3_x) &&
        (penguin_x + 10'd70 < obstacle3_x + 10'd30) &&
        (jump_height >= 7'd47);

    // Bildschirm-Y-Koordinate relativ zum Boden-Pinguin.
    // Höhere jump_height verschiebt alle Pinguinteile nach oben.
    wire [10:0] penguin_y;
    assign penguin_y = {1'b0, vpos} + {4'd0, jump_height};

    // ------------------------------------------------------------
    // Spiel-Logik:
    // Laufen, Springen, Hindernisse, Fische und Leuchten.
    // Alle Änderungen passieren nur am Ende eines VGA-Frames.
    // ------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            penguin_x    <= 10'd20;
            jump_height  <= 7'd0;
            jump_state   <= JUMP_GROUND;
            leg_phase    <= 1'b0;
            level        <= 2'd0;

            fish1_eaten  <= 1'b0;
            fish2_eaten  <= 1'b0;
            fish3_eaten  <= 1'b0;
            flash_frames <= 4'd0;

            // Erster Wegabschnitt.
            obstacle1_x <= 10'd190;
            obstacle1_w <= 6'd35;
            obstacle1_h <= 7'd38;

            obstacle2_x <= 10'd360;
            obstacle2_w <= 6'd42;
            obstacle2_h <= 7'd55;

            obstacle3_x <= 10'd510;
            obstacle3_w <= 6'd36;
            obstacle3_h <= 7'd46;
        end else if (end_of_frame) begin

            // Leuchtdauer verringern.
            if (flash_frames != 4'd0)
                flash_frames <= flash_frames - 4'd1;

            // Fisch berührt: Fisch verschwindet und Pinguin leuchtet.
            if (touch_fish1) begin
                fish1_eaten  <= 1'b1;
                flash_frames <= 4'd12;
            end

            if (touch_fish2) begin
                fish2_eaten  <= 1'b1;
                flash_frames <= 4'd12;
            end

            if (touch_fish3) begin
                fish3_eaten  <= 1'b1;
                flash_frames <= 4'd12;
            end

            // Automatisch nach rechts laufen.
            // Ein Eisblock blockiert nur, wenn der Pinguin nicht hoch genug ist.
            if (!obstacle_ahead) begin
                if (penguin_x >= 10'd550) begin
                    // Rechter Rand: Nächster Wegabschnitt.
                    penguin_x <= 10'd20;
                    level <= level + 2'd1;

                    // Neue Fische für den nächsten Abschnitt.
                    fish1_eaten <= 1'b0;
                    fish2_eaten <= 1'b0;
                    fish3_eaten <= 1'b0;

                    // Neue Hindernisse.
                    case (level)
                        2'd0: begin
                            obstacle1_x <= 10'd165;
                            obstacle1_w <= 6'd30;
                            obstacle1_h <= 7'd32;

                            obstacle2_x <= 10'd320;
                            obstacle2_w <= 6'd45;
                            obstacle2_h <= 7'd50;

                            obstacle3_x <= 10'd485;
                            obstacle3_w <= 6'd40;
                            obstacle3_h <= 7'd42;
                        end

                        2'd1: begin
                            obstacle1_x <= 10'd230;
                            obstacle1_w <= 6'd40;
                            obstacle1_h <= 7'd48;

                            obstacle2_x <= 10'd400;
                            obstacle2_w <= 6'd34;
                            obstacle2_h <= 7'd58;

                            obstacle3_x <= 10'd525;
                            obstacle3_w <= 6'd38;
                            obstacle3_h <= 7'd44;
                        end

                        2'd2: begin
                            obstacle1_x <= 10'd180;
                            obstacle1_w <= 6'd36;
                            obstacle1_h <= 7'd40;

                            obstacle2_x <= 10'd350;
                            obstacle2_w <= 6'd46;
                            obstacle2_h <= 7'd60;

                            obstacle3_x <= 10'd500;
                            obstacle3_w <= 6'd34;
                            obstacle3_h <= 7'd36;
                        end

                        default: begin
                            obstacle1_x <= 10'd215;
                            obstacle1_w <= 6'd32;
                            obstacle1_h <= 7'd35;

                            obstacle2_x <= 10'd375;
                            obstacle2_w <= 6'd40;
                            obstacle2_h <= 7'd52;

                            obstacle3_x <= 10'd520;
                            obstacle3_w <= 6'd42;
                            obstacle3_h <= 7'd48;
                        end
                    endcase
                end else begin
                    penguin_x <= penguin_x + 10'd2;
                    leg_phase <= ~leg_phase;
                end
            end

            // Sprunglogik:
            // drücken = hochspringen
            // gedrückt halten = oben schweben
            // loslassen = herunterfallen
            case (jump_state)
                JUMP_GROUND: begin
                    jump_height <= 7'd0;

                    if (jump_button)
                        jump_state <= JUMP_RISE;
                end

                JUMP_RISE: begin
                    if (jump_height >= 7'd64) begin
                        jump_height <= 7'd72;

                        if (jump_button)
                            jump_state <= JUMP_HOVER;
                        else
                            jump_state <= JUMP_FALL;
                    end else begin
                        jump_height <= jump_height + 7'd8;
                    end
                end

                JUMP_HOVER: begin
                    jump_height <= 7'd72;

                    if (!jump_button)
                        jump_state <= JUMP_FALL;
                end

                JUMP_FALL: begin
                    if (jump_height <= 7'd8) begin
                        jump_height <= 7'd0;
                        jump_state <= JUMP_GROUND;
                    end else begin
                        jump_height <= jump_height - 7'd8;
                    end
                end

                default: begin
                    jump_height <= 7'd0;
                    jump_state <= JUMP_GROUND;
                end
            endcase
        end
    end

    // ------------------------------------------------------------
    // Pixelgenerator
    // ------------------------------------------------------------
    reg [1:0] red;
    reg [1:0] green;
    reg [1:0] blue;

    always @(*) begin
        // Standardfarbe: Himmel.
        red   = 2'b01;
        green = 2'b10;
        blue  = 2'b11;

        if (!active_video) begin
            // Austastbereich schwarz.
            red   = 2'b00;
            green = 2'b00;
            blue  = 2'b00;
        end else begin
            // Schnee.
            if (vpos >= 10'd400) begin
                red   = 2'b11;
                green = 2'b11;
                blue  = 2'b11;
            end

            // Graue Weglinie.
            if ((vpos >= 10'd396) && (vpos < 10'd400)) begin
                red   = 2'b10;
                green = 2'b10;
                blue  = 2'b10;
            end

            // ------------------------------------------------
            // Eisblock 1
            // ------------------------------------------------
            if (
                ((vpos >= 10'd400 - obstacle1_h) &&
                 (vpos < 10'd400) &&
                 (hpos >= obstacle1_x) &&
                 (hpos < obstacle1_x + {4'd0, obstacle1_w})) ||

                ((vpos >= 10'd392 - obstacle1_h) &&
                 (vpos < 10'd400 - obstacle1_h) &&
                 (hpos >= obstacle1_x + 10'd7) &&
                 (hpos < obstacle1_x + {4'd0, obstacle1_w} - 10'd7))
            ) begin
                red   = 2'b01;
                green = 2'b11;
                blue  = 2'b11;
            end

            // Eisblock 1: Schattenkante.
            if ((vpos >= 10'd400 - obstacle1_h) &&
                (vpos < 10'd400) &&
                (hpos >= obstacle1_x + {4'd0, obstacle1_w} - 10'd7) &&
                (hpos < obstacle1_x + {4'd0, obstacle1_w})) begin
                red   = 2'b00;
                green = 2'b10;
                blue  = 2'b11;
            end

            // ------------------------------------------------
            // Eisblock 2
            // ------------------------------------------------
            if (
                ((vpos >= 10'd400 - obstacle2_h) &&
                 (vpos < 10'd400) &&
                 (hpos >= obstacle2_x) &&
                 (hpos < obstacle2_x + {4'd0, obstacle2_w})) ||

                ((vpos >= 10'd392 - obstacle2_h) &&
                 (vpos < 10'd400 - obstacle2_h) &&
                 (hpos >= obstacle2_x + 10'd7) &&
                 (hpos < obstacle2_x + {4'd0, obstacle2_w} - 10'd7))
            ) begin
                red   = 2'b01;
                green = 2'b11;
                blue  = 2'b11;
            end

            // Eisblock 2: Schattenkante.
            if ((vpos >= 10'd400 - obstacle2_h) &&
                (vpos < 10'd400) &&
                (hpos >= obstacle2_x + {4'd0, obstacle2_w} - 10'd7) &&
                (hpos < obstacle2_x + {4'd0, obstacle2_w})) begin
                red   = 2'b00;
                green = 2'b10;
                blue  = 2'b11;
            end

            // ------------------------------------------------
            // Eisblock 3
            // ------------------------------------------------
            if (
                ((vpos >= 10'd400 - obstacle3_h) &&
                 (vpos < 10'd400) &&
                 (hpos >= obstacle3_x) &&
                 (hpos < obstacle3_x + {4'd0, obstacle3_w})) ||

                ((vpos >= 10'd392 - obstacle3_h) &&
                 (vpos < 10'd400 - obstacle3_h) &&
                 (hpos >= obstacle3_x + 10'd7) &&
                 (hpos < obstacle3_x + {4'd0, obstacle3_w} - 10'd7))
            ) begin
                red   = 2'b01;
                green = 2'b11;
                blue  = 2'b11;
            end

            // Eisblock 3: Schattenkante.
            if ((vpos >= 10'd400 - obstacle3_h) &&
                (vpos < 10'd400) &&
                (hpos >= obstacle3_x + {4'd0, obstacle3_w} - 10'd7) &&
                (hpos < obstacle3_x + {4'd0, obstacle3_w})) begin
                red   = 2'b00;
                green = 2'b10;
                blue  = 2'b11;
            end

            // ------------------------------------------------
            // Fische auf fester Schnabelhöhe: y=200.
            // ------------------------------------------------

            // Fisch 1: Körper.
            if (!fish1_eaten &&
                (vpos >= FISH_Y) && (vpos < FISH_Y + 10'd12) &&
                (hpos >= obstacle1_x + 10'd8) &&
                (hpos < obstacle1_x + 10'd30)) begin
                red   = 2'b11;
                green = 2'b10;
                blue  = 2'b00;
            end

            // Fisch 1: Schwanz.
            if (!fish1_eaten &&
                (vpos >= FISH_Y + 10'd3) && (vpos < FISH_Y + 10'd9) &&
                (hpos >= obstacle1_x) &&
                (hpos < obstacle1_x + 10'd8)) begin
                red   = 2'b11;
                green = 2'b01;
                blue  = 2'b00;
            end

            // Fisch 2: Körper.
            if (!fish2_eaten &&
                (vpos >= FISH_Y) && (vpos < FISH_Y + 10'd12) &&
                (hpos >= obstacle2_x + 10'd8) &&
                (hpos < obstacle2_x + 10'd30)) begin
                red   = 2'b11;
                green = 2'b10;
                blue  = 2'b00;
            end

            // Fisch 2: Schwanz.
            if (!fish2_eaten &&
                (vpos >= FISH_Y + 10'd3) && (vpos < FISH_Y + 10'd9) &&
                (hpos >= obstacle2_x) &&
                (hpos < obstacle2_x + 10'd8)) begin
                red   = 2'b11;
                green = 2'b01;
                blue  = 2'b00;
            end

            // Fisch 3: Körper.
            if (!fish3_eaten &&
                (vpos >= FISH_Y) && (vpos < FISH_Y + 10'd12) &&
                (hpos >= obstacle3_x + 10'd8) &&
                (hpos < obstacle3_x + 10'd30)) begin
                red   = 2'b11;
                green = 2'b10;
                blue  = 2'b00;
            end

            // Fisch 3: Schwanz.
            if (!fish3_eaten &&
                (vpos >= FISH_Y + 10'd3) && (vpos < FISH_Y + 10'd9) &&
                (hpos >= obstacle3_x) &&
                (hpos < obstacle3_x + 10'd8)) begin
                red   = 2'b11;
                green = 2'b01;
                blue  = 2'b00;
            end

            // ------------------------------------------------
            // Pinguin: Kopf, Körper und hinterer Flügel.
            // penguin_y verschiebt ihn beim Sprung nach oben.
            // ------------------------------------------------
            if (
                // Kopf.
                ((penguin_y >= 11'd220) && (penguin_y < 11'd250) &&
                 (hpos >= penguin_x + 10'd28) &&
                 (hpos <  penguin_x + 10'd68)) ||

                // Oberkörper.
                ((penguin_y >= 11'd250) && (penguin_y < 11'd285) &&
                 (hpos >= penguin_x + 10'd18) &&
                 (hpos <  penguin_x + 10'd73)) ||

                // Hauptkörper.
                ((penguin_y >= 11'd285) && (penguin_y < 11'd360) &&
                 (hpos >= penguin_x + 10'd12) &&
                 (hpos <  penguin_x + 10'd76)) ||

                // Unterkörper.
                ((penguin_y >= 11'd360) && (penguin_y < 11'd380) &&
                 (hpos >= penguin_x + 10'd23) &&
                 (hpos <  penguin_x + 10'd67)) ||

                // Flügel hinten.
                ((penguin_y >= 11'd285) && (penguin_y < 11'd340) &&
                 (hpos >= penguin_x) &&
                 (hpos < penguin_x + 10'd20))
            ) begin
                if (penguin_flash) begin
                    // Leuchtet kurz gelb nach einem gefressenen Fisch.
                    red   = 2'b11;
                    green = 2'b11;
                    blue  = 2'b00;
                end else begin
                    red   = 2'b00;
                    green = 2'b00;
                    blue  = 2'b00;
                end
            end

            // Weißer Bauch.
            if (
                ((penguin_y >= 11'd275) && (penguin_y < 11'd305) &&
                 (hpos >= penguin_x + 10'd38) &&
                 (hpos < penguin_x + 10'd64)) ||

                ((penguin_y >= 11'd305) && (penguin_y < 11'd355) &&
                 (hpos >= penguin_x + 10'd30) &&
                 (hpos < penguin_x + 10'd68)) ||

                ((penguin_y >= 11'd355) && (penguin_y < 11'd370) &&
                 (hpos >= penguin_x + 10'd38) &&
                 (hpos < penguin_x + 10'd61))
            ) begin
                red   = 2'b11;
                green = 2'b11;
                blue  = 2'b11;
            end

            // Weißes Auge.
            if ((penguin_y >= 11'd238) && (penguin_y < 11'd254) &&
                (hpos >= penguin_x + 10'd53) &&
                (hpos < penguin_x + 10'd67)) begin
                red   = 2'b11;
                green = 2'b11;
                blue  = 2'b11;
            end

            // Schwarze Pupille.
            if ((penguin_y >= 11'd243) && (penguin_y < 11'd253) &&
                (hpos >= penguin_x + 10'd59) &&
                (hpos < penguin_x + 10'd67)) begin
                red   = 2'b00;
                green = 2'b00;
                blue  = 2'b00;
            end

            // Orangener Schnabel nach rechts.
            if (
                ((penguin_y >= 11'd258) && (penguin_y < 11'd266) &&
                 (hpos >= penguin_x + 10'd70) &&
                 (hpos < penguin_x + 10'd80)) ||

                ((penguin_y >= 11'd266) && (penguin_y < 11'd274) &&
                 (hpos >= penguin_x + 10'd70) &&
                 (hpos < penguin_x + 10'd86)) ||

                ((penguin_y >= 11'd274) && (penguin_y < 11'd282) &&
                 (hpos >= penguin_x + 10'd70) &&
                 (hpos < penguin_x + 10'd80))
            ) begin
                red   = 2'b11;
                green = 2'b10;
                blue  = 2'b00;
            end

            // Füße mit Laufanimation.
            if (!leg_phase) begin
                if ((penguin_y >= 11'd375) && (penguin_y < 11'd400) &&
                    (hpos >= penguin_x + 10'd16) &&
                    (hpos < penguin_x + 10'd43)) begin
                    red   = 2'b11;
                    green = 2'b10;
                    blue  = 2'b00;
                end

                if ((penguin_y >= 11'd375) && (penguin_y < 11'd400) &&
                    (hpos >= penguin_x + 10'd50) &&
                    (hpos < penguin_x + 10'd80)) begin
                    red   = 2'b11;
                    green = 2'b10;
                    blue  = 2'b00;
                end
            end else begin
                if ((penguin_y >= 11'd375) && (penguin_y < 11'd400) &&
                    (hpos >= penguin_x + 10'd25) &&
                    (hpos < penguin_x + 10'd53)) begin
                    red   = 2'b11;
                    green = 2'b10;
                    blue  = 2'b00;
                end

                if ((penguin_y >= 11'd375) && (penguin_y < 11'd400) &&
                    (hpos >= penguin_x + 10'd43) &&
                    (hpos < penguin_x + 10'd72)) begin
                    red   = 2'b11;
                    green = 2'b10;
                    blue  = 2'b00;
                end
            end
        end
    end

    // ------------------------------------------------------------
    // VGA Playground Pinout:
    // uo_out[0] = R1, uo_out[1] = G1, uo_out[2] = B1
    // uo_out[3] = VSYNC
    // uo_out[4] = R0, uo_out[5] = G0, uo_out[6] = B0
    // uo_out[7] = HSYNC
    // ------------------------------------------------------------
    assign uo_out[0] = red[1];
    assign uo_out[1] = green[1];
    assign uo_out[2] = blue[1];
    assign uo_out[3] = vsync;
    assign uo_out[4] = red[0];
    assign uo_out[5] = green[0];
    assign uo_out[6] = blue[0];
    assign uo_out[7] = hsync;

    // Keine bidirektionalen IO-Pins verwendet.
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

endmodule
