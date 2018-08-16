module SDInterface(
	input CLOCK_50,
	
	// Dev stuff for DE-1 board
	input [3:0] KEY,
	input [9:0] SW,
	input [9:0] GPIO_0_I1,
	inout [20:10] GPIO_0_IO2,
	inout [30:21] GPIO_0_I3,
	inout [35:31] GPIO_0_IO4,
	
	output [7:0] LEDG,
	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output PS2_CLK,
	output PS2_DAT,
	
	output SPI_MOSI,		// SD_CMD
	output reg SPI_CS,	// SD_DAT3
	output SPI_CLK,		// SD_CLK
	input SPI_MISO			// SD_DAT
);

reg CARD_LOCK;
reg HIGH_SPEED;
reg REG_GPIO;
reg [7:0] SPI_OUT;
reg [15:0] SPI_IN;
reg [15:0] SPI_IN_SR;
reg [4:0] CLK_DIV;
reg [5:0] STEP_COUNTER;
reg IGNORE_STEP_FLAG;
reg BURST_MODE;
reg [7:0] BURST_COUNTER;
reg PREV_OE;
reg PREV_PREV_OE;
reg [16:0] M68K_ADDR_REG;
reg [15:0] M68K_DATA_REG /* synthesis noprune */ ;
reg REG_IN_FLAG;

wire nRESET;
wire SPI_BUSY;
wire READ_SPI_BYTE;
wire READ_SPI_WORD;
wire READ_SPI_STATUS;
wire [4:0] CLK_DIV_MAX;

wire [17:0] M68K_ADDR;		// 256kWords = 512kBytes
wire [15:0] DATA_OUT;
wire [15:0] DATA_IN;
wire nSYSROM_OE;
wire nEEPROM_OE;

// DEBUG
SEG7_LUT_4 U3(HEX0, HEX1, HEX2, HEX3, M68K_ADDR_REG[15:0]);

assign M68K_ADDR = {GPIO_0_I3[21], GPIO_0_I3[30:29], GPIO_0_I3[27:22], GPIO_0_I1[0], GPIO_0_I1[1], GPIO_0_I1[2],
							GPIO_0_I1[3], GPIO_0_I1[4], GPIO_0_I1[5], GPIO_0_I1[6], GPIO_0_I1[7], GPIO_0_I1[8]};

assign {GPIO_0_IO4[31], GPIO_0_IO4[33], GPIO_0_IO4[35], GPIO_0_IO2[15],
			GPIO_0_IO2[20], GPIO_0_IO2[18], GPIO_0_IO2[13], GPIO_0_IO2[11],
			GPIO_0_IO4[32], GPIO_0_IO4[34], GPIO_0_IO2[14], GPIO_0_IO2[16],
			GPIO_0_IO2[19], GPIO_0_IO2[17], GPIO_0_IO2[12], GPIO_0_IO2[10]} = DATA_OUT;

// DEBUG
assign DATA_IN = {GPIO_0_IO4[31], GPIO_0_IO4[33], GPIO_0_IO4[35], GPIO_0_IO2[15],
			GPIO_0_IO2[20], GPIO_0_IO2[18], GPIO_0_IO2[13], GPIO_0_IO2[11],
			GPIO_0_IO4[32], GPIO_0_IO4[34], GPIO_0_IO2[14], GPIO_0_IO2[16],
			GPIO_0_IO2[19], GPIO_0_IO2[17], GPIO_0_IO2[12], GPIO_0_IO2[10]};

assign GPIO_0_I3[28] = nEEPROM_OE;
assign nSYSROM_OE = GPIO_0_I1[9];

assign GPIO_0_I3[30:29] = 2'bzz;
assign GPIO_0_I3[27:21] = 7'bzzzzzzz;

// DEBUG
assign PS2_CLK = SW[0] ? SPI_CLK : REG_GPIO;
assign PS2_DAT = SW[1] ? SPI_MOSI : SPI_MISO;
assign LEDG[0] = SW[0];
assign LEDG[1] = SW[1];

//A8 GPIO_0[0]
//A7 GPIO_0[1]
//A6 GPIO_0[2]
//A5 GPIO_0[3]
//A4 GPIO_0[4]
//A3 GPIO_0[5]
//A2 GPIO_0[6]
//A1 GPIO_0[7]
//A0 GPIO_0[8]
//Sysrom nOE in GPIO_0[9]
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
//EEPROM nOE out GPIO_0[28]
//A15 GPIO_0[29]
//A16 GPIO_0[30]
//D15 GPIO_0[31]
//D7 GPIO_0[32]
//D14 GPIO_0[33]
//D6 GPIO_0[34]
//D13 GPIO_0[35]

// $C1E600 or $C1E601
// 11000001 11100110 0000000x
//      ### ######## #######
assign READ_SPI_STATUS = (M68K_ADDR[17:0] == 18'b001111001100000000) ? 1'b1 : 1'b0;

// $C1E800 or $C1E801
// 11000001 11101000 0000000x
//      ### ######## #######
assign READ_SPI_BYTE = (M68K_ADDR[17:0] == 18'b001111010000000000) ? 1'b1 : 1'b0;

// $C1E900 or $C1E901
// 11000001 11101001 0000000x
//      ### ######## #######
assign READ_SPI_WORD = (M68K_ADDR[17:0] == 18'b001111010010000000) ? 1'b1 : 1'b0;

assign DATA_OUT = nSYSROM_OE ? 16'bzzzzzzzzzzzzzzzz :
			READ_SPI_STATUS ? {7'b0000000, SPI_BUSY, 7'b0000000, SPI_BUSY} :
			READ_SPI_BYTE ? {SPI_IN[7:0], SPI_IN[7:0]} :
			READ_SPI_WORD ? {SPI_IN[15:8], SPI_IN[7:0]} :
			16'bzzzzzzzzzzzzzzzz;	//SRAM_DQ;

// Let the EEPROM reply only if the address isn't in the new registers space
// Additionnal read zones must be added here or the EEPROM will fight for the bus !
assign nEEPROM_OE = nSYSROM_OE | READ_SPI_STATUS | READ_SPI_BYTE | READ_SPI_WORD;

assign nRESET = KEY[0];

// DEBUG
assign LEDG[3:2] = 3'd0;
assign LEDG[4] = REG_GPIO;
assign LEDG[5] = |{BURST_COUNTER};
assign LEDG[6] = SPI_MISO;
assign LEDG[7] = CARD_LOCK;

assign CLK_DIV_MAX = HIGH_SPEED ? 5'd0 : 5'd30;		// SPI speed select
assign SPI_MOSI = SPI_OUT[7];
assign SPI_CLK = IGNORE_STEP_FLAG ? 1'b0 : STEP_COUNTER[0];

assign SPI_BUSY = |{STEP_COUNTER};

// nSYSROM_OE falling edge detector
assign READ = ~PREV_OE & PREV_PREV_OE;

always @(posedge CLOCK_50)
begin
	if (!nRESET)
	begin
		CARD_LOCK <= 1'b1;		// Lock SD card access
		STEP_COUNTER <= 6'd0;
		SPI_CS <= 1'b1;			// Deselect SD card
		BURST_COUNTER <= 8'd0;
		HIGH_SPEED <= 1'b0;		// Start in slow mode
		IGNORE_STEP_FLAG <= 1'b0;
		REG_GPIO <= 1'b0;
	end
	else
	begin
		// DEBUG
		M68K_ADDR_REG <= {M68K_ADDR[15:0], 1'b0};
		M68K_DATA_REG <= DATA_IN;
		
		if (READ)
		begin
			// Falling edge of nSYSROM_OE
			
			if (M68K_ADDR[17:4] == 14'b00111100101000)
			begin
				// "Read to trigger" SD card lock/unlock at $C1E500 or $C1E501 = 0, $C1E510 or $C1E511 = 1
				// 11000001 11100101 000d000x
				//      ### ######## ###----
				if (!SPI_BUSY)
					CARD_LOCK <= M68K_ADDR[3];
			end
			else if (M68K_ADDR[17:4] == 14'b00111101010000)
			begin
				// "Read to trigger" GPIO set/reset at $C1EA00 or $C1EA01 = 0, $C1EA10 or $C1EA11 = 1
				// 11000001 11101010 000d000x
				//      ### ######## ###----
					REG_GPIO <= M68K_ADDR[3];
			end
			else if (M68K_ADDR[17:8] == 10'b0011110000)
			begin
				// "Read to write" SD card SPI interface DATA OUT in $C1E000/$C1E001~$C1E1FE/$C1E1FF
				// 11000001 1110000d dddddddx
				//      ### #######
				//if (!SPI_BUSY)			// Let the software check if SPI is busy or not !
				//begin
					// We're idle, start byte send
					if (!CARD_LOCK)
					begin
						SPI_OUT <= M68K_ADDR[7:0];		// Load data from address bus
						STEP_COUNTER <= 6'd16;			// Two steps per bit
						IGNORE_STEP_FLAG <= 1'b1;		// Crappy glitch fix :(
						CLK_DIV <= 5'd0;
					end
				//end
			end
			else if (M68K_ADDR[17:4] == 14'b00111100011000)
			begin
				// "Read to set" SD card SPI CS state at $C1E300 or $C1E301 = 0, $C1E310 or $C1E311 = 1
				// 11000001 11100011 000d000x
				//      ### ######## ###----
				SPI_CS <= M68K_ADDR[3];
			end
			else if (M68K_ADDR[17:4] == 14'b00111100100000)
			begin
				// "Read to set" SD card SPI speed at $C1E400 or $C1E401 = 0, $C1E410 or $C1E411 = 1
				// 11000001 11100100 000d000x
				//      ### ######## ###----
				HIGH_SPEED <= M68K_ADDR[3];
			end
			else if (M68K_ADDR[17:4] == 14'b00111100111000)
			begin
				// "Read to set" SD card burst read mode $C1E700 or $C1E701
				// 11000001 11100111 0000000x
				//      ### ######## ###----
				BURST_COUNTER <= 8'd255;		// 512 / 2 bytes per read - 1
				SPI_OUT <= 8'hFF;
				STEP_COUNTER <= 6'd32;			// Two steps per bit
				IGNORE_STEP_FLAG <= 1'b1;		// Crappy glitch fix :(
				CLK_DIV <= 5'd0;
			end
			else if (READ_SPI_WORD & |{BURST_COUNTER})
			begin
				// Auto-read from SD card in burst mode
				SPI_OUT <= 8'hFF;
				STEP_COUNTER <= 6'd32;			// Two steps per bit
				IGNORE_STEP_FLAG <= 1'b1;		// Crappy glitch fix :(
				CLK_DIV <= 5'd0;
				BURST_COUNTER <= BURST_COUNTER - 1'b1;
			end
			
		end
		
		// For edge detector
		PREV_OE <= nSYSROM_OE;
		PREV_PREV_OE <= PREV_OE;
		
		if (REG_IN_FLAG)
		begin
			SPI_IN <= SPI_IN_SR;
			REG_IN_FLAG <= 1'b0;
		end
		
		// SPI interface
		if (CLK_DIV < CLK_DIV_MAX)
			CLK_DIV <= CLK_DIV + 1'b1;
		else
		begin
			// This should take 16*(1/50M)=320ns for 8 bit high-speed transfers
			if (IGNORE_STEP_FLAG)
				IGNORE_STEP_FLAG <= 1'b0;	// This is a crappy glitch fix to avoid assigning two different values to CLK_DIV in the same step
			else
			begin
				CLK_DIV <= 5'd0;
				if (STEP_COUNTER)
				begin
					STEP_COUNTER <= STEP_COUNTER - 1'b1;
					if (~STEP_COUNTER[0])
						SPI_IN_SR <= {SPI_IN_SR[14:0], SPI_MISO};	// Shift left
					else
						SPI_OUT <= {SPI_OUT[6:0], 1'b1};				// Shift left
				end
				else
					REG_IN_FLAG <= 1'b1;
			end
		end
	end
end

endmodule
