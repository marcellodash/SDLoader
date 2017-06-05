module SDInterface(
	input [1:0] CLOCK_24,
	input M68K_WR,
	
	// Dev stuff for DE-1 board
	input [3:0] KEY,
	input [9:0] SW,
	input nSYSROM_CE,
	input nSYSROM_OE,
	input [18:0] M68K_ADDR,
	inout [15:0] M68K_DATA,
	output [17:0] SRAM_ADDR,
	inout [15:0] SRAM_DQ,
	output SRAM_CE_N,
	output SRAM_OE_N,
	output SRAM_WE_N,
	output SRAM_UB_N,
	output SRAM_LB_N,
	output [7:0] LEDG,
	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	// Todo: Serial port for SYSROM upload
	
	output SPI_MOSI,
	output reg SPI_CS,
	output SPI_CLK,
	input SPI_MISO
);

// Todo: Fast SPI_CLK is 12MHz, make it 24MHz ?
// SW0 sets the mode, down = upload, up = run

// $C00000 = 11000000 00000000 00000000
// $C7FFFF = 11000xxx xxxxxxxx xxxxxxx-
//               ^

wire DEV_STATE;				// 0 = Reset/Upload, 1 = Run
reg [17:0] DEV_ADDR;			// Upload address
reg [15:0] DEV_DATA;			// Upload data shift register

reg CARD_LOCK;
reg [7:0] SPI_OUT;
reg [7:0] SPI_IN;
reg HIGH_SPEED;
reg [3:0] CLK_DIV;
wire [3:0] CLK_DIV_MAX;
reg [4:0] STEP_COUNTER;
wire [15:0] CPU_DATA;
wire BUSY;

assign nRESET = KEY[0];
assign DEV_STATE = SW[0];
assign LEDG[0] = CARD_LOCK;
assign LEDG[1] = DEV_STATE;
assign LEDG[7:2] = 6'd0;

assign SRAM_CE_N = 1'b0;
assign SRAM_OE_N = ~DEV_STATE;
//assign SRAM_WE_N = ;
assign SRAM_LB_N = 1'b0;	// Always work in full words
assign SRAM_UB_N = 1'b0;

assign SRAM_ADDR = DEV_STATE ? M68K_ADDR[17:0] : DEV_ADDR;
assign M68K_DATA = (nSYSROM_OE | nSYSROM_CE) ? 16'bzzzzzzzzzzzzzzzz : CPU_DATA;
assign CPU_DATA = M68K_ADDR[18] ? {7'h0, BUSY, SPI_IN} : SRAM_DQ;

assign SRAM_DQ = DEV_STATE ? 16'bzzzzzzzzzzzzzzzz : DEV_DATA;

assign CLK_DIV_MAX = HIGH_SPEED ? 4'd0 : 4'd15;
assign SPI_MOSI = SPI_OUT[7];
assign SPI_CLK = STEP_COUNTER[0];

assign BUSY = |{STEP_COUNTER};

SEG7_LUT_4 U1(HEX0, HEX1, HEX2, HEX3, DEV_ADDR[15:0]);

always @(posedge CLOCK_24[0])
begin
	if (!nRESET)
	begin
		CARD_LOCK <= 1'b1;
		STEP_COUNTER <= 5'd0;
		SPI_CS <= 1'b1;
	end
	else
	begin
		if (!BUSY)
		begin
			// We're idle
			if (!M68K_WR)
			begin
				// Writes
				if (!nSYSROM_CE && !M68K_ADDR[0])
				begin
					// Write to $C00000
					if (M68K_DATA == 16'h57F1)
						CARD_LOCK <= 1'b1;		// Lock
					else if (M68K_DATA == 16'h741C)
						CARD_LOCK <= 1'b0;		// Unlock
				end
				else if (!nSYSROM_CE && M68K_ADDR[0])
				begin
					// Write to $C00002
					if (!CARD_LOCK)
					begin
						if (M68K_DATA[8])		// bit8 = send byte
						begin
							SPI_OUT <= M68K_DATA[7:0];
							STEP_COUNTER <= 5'd16;
							CLK_DIV <= 4'd0;
						end
						
						SPI_CS <= M68K_DATA[9];		// bit9 = CS state
					
						HIGH_SPEED <= M68K_DATA[15];	// bit15 = high speed
					end
				end
			end
		end
		else
		begin
			// We're busy
			if (CLK_DIV < CLK_DIV_MAX)
				CLK_DIV <= CLK_DIV + 1'b1;
			else
			begin
				CLK_DIV <= 4'd0;
				if (STEP_COUNTER)
				begin
					STEP_COUNTER <= STEP_COUNTER - 1'b1;
					if (STEP_COUNTER[0])
					begin
						SPI_OUT <= {SPI_OUT[6:0], 1'b0};		// Shift left
						SPI_IN <= {SPI_IN[6:0], SPI_MISO};	// Shift left
					end
				end
			end
		end
	end
end

endmodule
