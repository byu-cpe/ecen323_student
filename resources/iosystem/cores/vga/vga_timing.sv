/*********************************************************************************
* vga_timing.sv
*
*   VGA timing module
*
* 
*********************************************************************************/

module vga_timing (clk, rst, HS, VS, pixel_x, pixel_y, last_column, last_row, blank);

    input logic clk;
    input logic rst;
    output logic HS;
    output logic VS;
    output logic [9:0] pixel_x;
    output logic [9:0] pixel_y;
    output logic last_column;
    output logic last_row;
    output logic blank;

    localparam LAST_COLUMN = 799;
    localparam LAST_ROW = 520;

    localparam LAST_VISIBLE_COLUMN = 639;
    localparam LAST_VISIBLE_ROW = 479;

    localparam HS_LOW_COL_MIN = 656;
    localparam HS_LOW_COL_MAX = 751;
    localparam VS_LOW_COL_MIN = 490;
    localparam VS_LOW_COL_MAX = 491;
    localparam BLANK_FIRST_COL = 640;
    localparam BLANK_FIRST_ROW = 480;

    logic [9:0] x_reg, x_next, y_reg, y_next;
    logic pixel_en = 0;

    // Timing registers
    always_ff@(posedge clk)
        if (rst) begin
            pixel_en <= 0;
            x_reg <= 0;
            y_reg <= 0;
        end
        else begin
            pixel_en <= ~pixel_en;
            if (pixel_en) begin
                x_reg <= x_next;
                y_reg <= y_next;                
            end
        end

    // Next column
    assign x_next = (x_reg == LAST_COLUMN) ? 0 : x_reg + 1;

    // Next row
    assign y_next = (x_reg == LAST_COLUMN && y_reg == LAST_ROW) ? 0 :
                    (x_reg == LAST_COLUMN) ? y_reg + 1 :
                    y_reg;


    assign pixel_x = x_reg;
    assign pixel_y = y_reg;
    assign last_column = (x_reg == LAST_VISIBLE_COLUMN);
    assign last_row = (y_reg == LAST_VISIBLE_ROW);
    assign blank = ~(x_reg <= LAST_VISIBLE_COLUMN && y_reg <= LAST_VISIBLE_ROW );

    assign HS = ~(x_reg > 655 && x_reg < 752 );
    assign VS = ~(y_reg > 489 && y_reg < 492 );

endmodule

