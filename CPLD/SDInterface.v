module SDInterface(
	input CLOCK_50,
	input [1:0] CLOCK_24,
	//input M68K_WR,
	
	// Dev stuff for DE-1 board
	input [3:0] KEY,
	input [9:0] SW,
	input [9:0] GPIO_0_I1,
	inout [20:10] GPIO_0_IO2,
	input [30:21] GPIO_0_I3,
	inout [35:31] GPIO_0_IO4,
	
	/*output [17:0] SRAM_ADDR,
	inout [15:0] SRAM_DQ,
	output SRAM_CE_N,
	output SRAM_OE_N,
	output SRAM_WE_N,
	output SRAM_UB_N,
	output SRAM_LB_N,*/
	
	output [21:0] FL_ADDR,
	input [7:0] FL_DQ,
	output FL_OE_N,
	output FL_RST_N,
	output FL_WE_N,
	output FL_CE_N,
	
	output [7:0] LEDG,
	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	//input PS2_DAT
	
	output SPI_MOSI,		// SD_CMD
	output reg SPI_CS,	// SD_DAT3
	output SPI_CLK,		// SD_CLK
	input SPI_MISO		// SD_DAT
);

// Todo: Fast SPI_CLK is 12MHz, make it 24MHz ?

// $C00000 = 11000000 00000000 00000000
// $C7FFFF = 11000xxx xxxxxxxx xxxxxxx-
//               ^

reg [7:0] CPU_DATA_LOW;
reg [7:0] CPU_DATA_HIGH;

reg [7:0] READ_TIMER;
reg PREV_OE;
reg PREV_PREV_OE;
reg LSB;

reg CARD_LOCK;
reg [7:0] SPI_OUT;
reg [7:0] SPI_IN;
reg HIGH_SPEED;
reg [4:0] CLK_DIV;
wire [4:0] CLK_DIV_MAX;
reg [4:0] STEP_COUNTER;
wire [15:0] CPU_DATA;
wire BUSY;

wire [17:0] M68K_ADDR;		// 512k words
wire [15:0] M68K_DATA_IN;
wire nSYSROM_OE;
wire READ;

assign M68K_ADDR = {	GPIO_0_I3[21], GPIO_0_I3[30:29], GPIO_0_I3[27:22], GPIO_0_I1[0], GPIO_0_I1[1], GPIO_0_I1[2],
							GPIO_0_I1[3], GPIO_0_I1[4], GPIO_0_I1[5], GPIO_0_I1[6], GPIO_0_I1[7], GPIO_0_I1[8]};

//A8 GPIO_0[0]
//A7 GPIO_0[1]
//A6 GPIO_0[2]
//A5 GPIO_0[3]
//A4 GPIO_0[4]
//A3 GPIO_0[5]
//A2 GPIO_0[6]
//A1 GPIO_0[7]
//A0 GPIO_0[8]
//OE GPIO_0[9]
//D0 GPIO_0[10]
//D8 GPIO_0[11]
//D1 GPIO_0[12]
//D9 GPIO_0[13]
//D5 GPIO_0[14]
//D12 GPIO_0[15]
//D4 GPIO_0[16]
//D2 GPIO_0[17]
//D10 GPIO_0[18]
//D3 GPIO_0[19]
//D11 GPIO_0[20]
//A17 GPIO_0[21]
//A9 GPIO_0[22]
//A10 GPIO_0[23]
//A11 GPIO_0[24]
//A12 GPIO_0[25]
//A13 GPIO_0[26]
//A14 GPIO_0[27]
//Unused GPIO_0[28]
//A15 GPIO_0[29]
//A16 GPIO_0[30]
//D15 GPIO_0[31]
//D7 GPIO_0[32]
//D14 GPIO_0[33]
//D6 GPIO_0[34]
//D13 GPIO_0[35]

assign nSYSROM_OE = GPIO_0_I1[9];

// $C04800 or $C04801
// 11000000 01001000 0000000x
//      ### ######## #######
assign READ_SPI_BYTE = (M68K_ADDR[17:0] == 18'b000010010000000000) ? 1'b1 : 1'b0;

// $C04900 or $C04901
// 11000000 01001001 0000000x
//      ### ######## #######
assign READ_SPI_STATUS = (M68K_ADDR[17:0] == 18'b000010010010000000) ? 1'b1 : 1'b0;

assign {GPIO_0_IO4[31], GPIO_0_IO4[33], GPIO_0_IO4[35], GPIO_0_IO2[15],
			GPIO_0_IO2[20], GPIO_0_IO2[18], GPIO_0_IO2[13], GPIO_0_IO2[11],
			GPIO_0_IO4[32], GPIO_0_IO4[34], GPIO_0_IO2[14], GPIO_0_IO2[16],
			GPIO_0_IO2[19], GPIO_0_IO2[17], GPIO_0_IO2[12], GPIO_0_IO2[10]} =
			nSYSROM_OE ? 16'bzzzzzzzzzzzzzzzz : // CPU_DATA;
			READ_SPI_STATUS ? {7'b0000000, BUSY} : //CPU_DATA;
			READ_SPI_BYTE ? {SPI_IN, SPI_IN} : CPU_DATA;
			/*READ_SPI_BYTE ? {SPI_IN, SPI_IN} :
			READ_SPI_STATUS ? {7'b0000000, BUSY} : CPU_DATA;*/
			
assign M68K_DATA_IN = {GPIO_0_IO4[31], GPIO_0_IO4[33], GPIO_0_IO4[35], GPIO_0_IO2[15],
			GPIO_0_IO2[20], GPIO_0_IO2[18], GPIO_0_IO2[13], GPIO_0_IO2[11],
			GPIO_0_IO4[32], GPIO_0_IO4[34], GPIO_0_IO2[14], GPIO_0_IO2[16],
			GPIO_0_IO2[19], GPIO_0_IO2[17], GPIO_0_IO2[12], GPIO_0_IO2[10]};

assign nRESET = KEY[0];
assign LEDG[0] = CARD_LOCK;
assign LEDG[1] = BUSY;
assign LEDG[7:2] = 6'd0;
//assign LEDG[6:2] = 5'd0;
//assign LEDG[7] = PS2_DAT;

assign FL_CE_N = 1'b0;
assign FL_OE_N = 1'b0;
assign FL_WE_N = 1'b1;
assign FL_RST_N = 1'b1;

assign FL_ADDR = {3'b000, M68K_ADDR, LSB};

assign CPU_DATA = {CPU_DATA_HIGH, CPU_DATA_LOW};

assign CLK_DIV_MAX = HIGH_SPEED ? 5'd1 : 5'd30;
assign SPI_MOSI = SPI_OUT[7];
assign SPI_CLK = STEP_COUNTER[0];

assign BUSY = |{STEP_COUNTER};

SEG7_LUT_4 U1(HEX0, HEX1, HEX2, HEX3, FL_ADDR[15:0]);

assign READ = ~PREV_OE & PREV_PREV_OE;

always @(posedge CLOCK_50)
begin
	if (!nRESET)
	begin
		CARD_LOCK <= 1'b1;
		STEP_COUNTER <= 5'd0;
		SPI_CS <= 1'b1;
	end
	else
	begin
		if (READ)
		begin
			// Falling edge of OE
			
			if (M68K_ADDR[17:0] == 18'b000010001100101001)
			begin
				// "Read to trigger" SD card lock at $C04652 or $C04653
				// 11000000 01000110 0101001x
				//      ### ######## #######
				if (!BUSY) CARD_LOCK <= 1'b1;		// Lock
			end
			else if (M68K_ADDR[17:0] == 18'b000010001101010000)
			begin
				// "Read to trigger" SD card unlock at $C046A0 or $C046A1
				// 11000000 01000110 1010000x
				//      ### ######## #######
				if (!BUSY) CARD_LOCK <= 1'b0;		// Unlock
			end
			else if (M68K_ADDR[17:8] == 10'b0000100010)
			begin
				// "Read to write" SD card interface in $C04400/$C04401~$C045FE/$C045FF
				// 11000000 0100010d dddddddx
				//      ### #######
			
				if (!BUSY)
				begin
					// We're idle, start byte send
					if (!CARD_LOCK)
					begin
						SPI_OUT <= M68K_ADDR[7:0];
						STEP_COUNTER <= 5'd16;
						CLK_DIV <= 5'd0;
					end
				end
			end
			else if (M68K_ADDR[17:4] == 14'b00001000110000)
			begin
				// "Read to set" SD card SPI CS state at $C04600 or $C04601 = 0, $C04610 or $C04611 = 1
				// 11000000 01000110 000d000x
				//      ### ######## ###----
				SPI_CS <= M68K_ADDR[3];
			end
			else if (M68K_ADDR[17:4] == 14'b00001000111000)
			begin
				// "Read to set" SD card SPI speed at $C04700 or $C04701 = 0, $C04710 or $C04711 = 1
				// 11000000 01000111 000d000x
				//      ### ######## ###----
				HIGH_SPEED <= M68K_ADDR[3];
			end
			else
			begin
				// Normal flash read
				LSB <= 1'b0;
				READ_TIMER <= 8'd8;
			end
		end
		else
		begin
			if (READ_TIMER)
			begin
				READ_TIMER <= READ_TIMER - 1'b1;
				
				if (READ_TIMER == 8'd4)			// 4!
				begin
					CPU_DATA_LOW <= FL_DQ;
					LSB <= 1'b1;
				end
				else if (READ_TIMER == 8'd3)	// 3 !
					CPU_DATA_HIGH <= FL_DQ;
			end
			else
				LSB <= 1'b0;
		end
		
		PREV_OE <= nSYSROM_OE;
		PREV_PREV_OE <= PREV_OE;
		
		// SD card work
		if (CLK_DIV < CLK_DIV_MAX)
			CLK_DIV <= CLK_DIV + 1'b1;
		else
		begin
			CLK_DIV <= 5'd0;
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

endmodule
