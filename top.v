`timescale 1ns / 1ps

module top(
    input clk,
    input rst_btn,
    input rx_dv,
    input test_btn,         // NEW: Button to simulate packet for debugging
    input use_test_input,   // NEW: Switch to choose test or real input
    output [6:0] seg,
    output [3:0] an,
    output phy_resetn,
    output debug_led        // NEW: LED toggles on packet receive
);
    wire rst = ~rst_btn;  // Active-high reset

    // Assert PHY reset for a few cycles after power-up
    reg [15:0] reset_counter = 0;
    reg phy_resetn_reg = 0;
    assign phy_resetn = phy_resetn_reg;

    always @(posedge clk) begin
        if (reset_counter < 10000) begin
            reset_counter <= reset_counter + 1;
            phy_resetn_reg <= 0;  // Hold PHY in reset
        end else begin
            phy_resetn_reg <= 1;  // Release reset
        end
    end

    // Choose between test input and real rx_dv
    wire rx_dv_synced = use_test_input ? test_btn : rx_dv;

    // Ethernet packet counter with debug LED
    wire [15:0] packet_count;
    ethernet_packet_counter epc (
        .clk(clk),
        .rst(rst),
        .rx_dv(rx_dv_synced),
        .packet_count(packet_count),
        .debug_led(debug_led)
    );

    // 7-segment display
    seven_segment_display display (
        .clk(clk),
        .value(packet_count),
        .seg(seg),
        .an(an)
    );
endmodule

// Ethernet Packet Counter with debug LED
module ethernet_packet_counter (
    input clk,
    input rst,
    input rx_dv,
    output reg [15:0] packet_count,
    output reg debug_led
);
    reg rx_dv_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            packet_count <= 0;
            rx_dv_prev <= 0;
            debug_led <= 0;
        end else begin
            rx_dv_prev <= rx_dv;
            // Count a new packet when rx_dv rises
            if (~rx_dv_prev & rx_dv) begin
                packet_count <= packet_count + 1;
                debug_led <= ~debug_led;  // Toggle LED for visual confirmation
            end
        end
    end
endmodule

// 7-Segment Display Controller (Multiplexing)
module seven_segment_display(
    input clk,
    input [15:0] value,
    output reg [3:0] an,
    output [6:0] seg
);
    reg [1:0] digit_sel = 0;
    reg [3:0] current_digit = 0;
    reg [15:0] counter = 0;

    wire [6:0] seg_out;

    wire [3:0] digit0 = value[3:0];
    wire [3:0] digit1 = value[7:4];
    wire [3:0] digit2 = value[11:8];
    wire [3:0] digit3 = value[15:12];

    hex_to_7seg decoder (
        .hex(current_digit),
        .seg(seg_out)
    );

    assign seg = seg_out;

    always @(posedge clk) begin
        counter <= counter + 1;
        if (counter == 0)
            digit_sel <= digit_sel + 1;
    end

    always @(*) begin
        case (digit_sel)
            2'b00: begin an = 4'b1110; current_digit = digit0; end
            2'b01: begin an = 4'b1101; current_digit = digit1; end
            2'b10: begin an = 4'b1011; current_digit = digit2; end
            2'b11: begin an = 4'b0111; current_digit = digit3; end
        endcase
    end
endmodule

// Hex to 7-Segment Decoder
module hex_to_7seg(
    input [3:0] hex,
    output reg [6:0] seg
);
    always @(*) begin
        case (hex)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end
endmodule
