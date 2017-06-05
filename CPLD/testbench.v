module testbench();

reg [18:0] M68K_ADDR;
wire [15:0] M68K_DATA;
reg [15:0] CPU_DATA;
reg MCLK;
reg nRESET;
reg M68K_WR;
reg nSYSROM_OE;

SDInterface U1(
	{1'b0, MCLK},
	M68K_WR,
	{3'b0, nRESET},
	{9'b0, MODESW},
	1'b0,
	nSYSROM_OE,
	M68K_ADDR,
	M68K_DATA,
	,
	,
	,,,,,
	,

	,
	,
	,
	1'b1);

assign M68K_DATA = M68K_WR ? 16'bzzzzzzzzzzzzzzzz : CPU_DATA;

always
begin
	#21 MCLK <= ~MCLK;
end

initial
begin
	MCLK <= 1'b0;
	nRESET <= 1'b1;
	M68K_WR <= 1'b1;
	nSYSROM_OE <= 1'b1;
	#500
	nRESET <= 1'b0;
	#1000
	nRESET <= 1'b1;
	#500
	
	CPU_DATA <= 16'h741C;		// Unlock
	M68K_ADDR <= 19'h0;
	M68K_WR <= 1'b0;
	#100
	M68K_WR <= 1'b1;
	#500
	
	CPU_DATA <= 16'h01AA;		// Send AA byte with CS low, slow speed
	M68K_ADDR <= 19'h1;
	M68K_WR <= 1'b0;
	#100
	M68K_WR <= 1'b1;
	#15000
	
	CPU_DATA <= 16'h8355;		// Send 55 byte with CS high, high speed
	M68K_ADDR <= 19'h1;
	M68K_WR <= 1'b0;
	#100
	M68K_WR <= 1'b1;
	#1500
	
	M68K_ADDR <= 19'h40001;		// Read byte with CS high, high speed
	M68K_WR <= 1'b1;
	nSYSROM_OE <= 1'b0;
	#500
	nSYSROM_OE <= 1'b1;
	#1000
	
	CPU_DATA <= 16'h57F1;		// Lock
	M68K_ADDR <= 18'h0;
	M68K_WR <= 1'b0;
	#100
	M68K_WR <= 1'b1;
	#500
	
	#2000
	$stop;
	
end

endmodule
