// Hope this will work at some point :(
// DE-1's SDRAM chip is a 8MByte IS42S16400J
// Organized as 1MBit * 16bits * 4 banks

// Bursts and auto-precharge aren't handled at all, no need for it

// Init:
// Word (A11~0) = 001000100000
// NOPs during 100us, PRECHARGE, REFRESH, NOP, REFRESH, NOP, LOAD MODE, NOP

// Read:
// ACTIVE, NOP(tRCD), READ, NOP(CAS latency = 2), NOP & latch data, PRECHARGE, NOP(tRP)

// Write:
// ACTIVE, NOP(tRCD), WRITE, 2x NOP(tRAS), PRECHARGE, NOP(tRP)

module ShittySDRAMCtrl(
	input CLK,
	input nRESET,
	
	input WR_REQ,
	input [21:0] WR_ADDR,	// In words
	input [15:0] WR_DATA,
	
	input RD_REQ,
	input [21:0] RD_ADDR,	// In words
	output reg [15:0] RD_DATA,
	
	output reg [1:0] DRAM_BA,
	output reg [11:0] DRAM_ADDR,
	inout [15:0] DRAM_DQ,
	output DRAM_RAS_N,
	output DRAM_CAS_N,
	output DRAM_WE_N,
	output reg [1:0] DRAM_DQM
);

parameter [2:0] SDRAM_CMD_LOADMODE  = 3'b000;
parameter [2:0] SDRAM_CMD_REFRESH   = 3'b001;
parameter [2:0] SDRAM_CMD_PRECHARGE = 3'b010;
parameter [2:0] SDRAM_CMD_ACTIVE    = 3'b011;
parameter [2:0] SDRAM_CMD_WRITE     = 3'b100;
parameter [2:0] SDRAM_CMD_READ      = 3'b101;
parameter [2:0] SDRAM_CMD_NOP       = 3'b111;

parameter [2:0] STATE_IDLE			= 3'd0;
parameter [2:0] STATE_INIT			= 3'd1;
parameter [2:0] STATE_PRECHARGE	= 3'd2;
parameter [2:0] STATE_READ			= 3'd3;
parameter [2:0] STATE_WRITE		= 3'd4;
parameter [2:0] STATE_REFRESH		= 3'd5;

/*
parameter CLK_FREQUENCY = 133;	// MHz
parameter REFRESH_TIME =  64;		// ms
parameter REFRESH_COUNT = 4096;	// cycles

parameter CYCLES_BETWEEN_REFRESH = ( CLK_FREQUENCY
                                      * 1_000
                                      * REFRESH_TIME
                                    ) / REFRESH_COUNT;*/

reg [2:0] COMMAND;
reg [2:0] STATE;
reg [2:0] STEP;
reg [21:0] ADDR_R;
reg [15:0] INIT_TIMER;
// Issue autorefresh command every 8clk or a bit more (more OK but not less !)
reg [3:0] REFRESH_TIMER = 4'd0;

wire [21:0] ADDR = (STATE == STATE_READ) ? RD_ADDR : WR_ADDR;

always @(posedge CLK)
	ADDR_R <= ADDR;

assign {DRAM_RAS_N, DRAM_CAS_N, DRAM_WE_N} = COMMAND;

always @(posedge CLK)
begin
	if (!nRESET)
	begin
		COMMAND <= SDRAM_CMD_NOP;
		INIT_TIMER <= 16'd15000;		// >100us @ 133MHz
		DRAM_DQM <= 2'b11;
		STATE <= STATE_INIT;
		STEP <= 3'd0;
		REFRESH_TIMER <= 4'd0;
	end
	else
	begin
		if (REFRESH_TIMER != 4'd8)
			REFRESH_TIMER <= REFRESH_TIMER + 1'b1;
			
		case (STATE)
			STATE_INIT:
			begin
				if (!INIT_TIMER)
				begin
					if (STEP == 3'd0)
					begin
						// PRECHARGE
						COMMAND <= SDRAM_CMD_PRECHARGE;
						DRAM_ADDR <= 12'b0100_0000_0000;		// A10=1: All banks
						//DRAM_DQM <= 2'b11;
						STEP <= 3'd1;
					end
					else if (STEP == 3'd1)
					begin
						// REFRESH 1
						COMMAND <= SDRAM_CMD_REFRESH;
						STEP <= 3'd2;
					end
					else if (STEP == 3'd2)
					begin
						// NOP
						COMMAND <= SDRAM_CMD_NOP;
						STEP <= 3'h3;
					end
					else if (STEP == 3'd3)
					begin
						// REFRESH 2
						COMMAND <= SDRAM_CMD_REFRESH;
						STEP <= 3'd4;
					end
					else if (STEP == 3'd4)
					begin
						// NOP
						COMMAND <= SDRAM_CMD_NOP;
						STEP <= 3'h5;
					end
					else if (STEP == 3'd5)
					begin
						// LOAD MODE
						COMMAND <= SDRAM_CMD_LOADMODE;
						DRAM_ADDR <= 12'b0010_0010_0000;
						STEP <= 3'd6;
					end
					else if (STEP == 3'd6)
					begin
						// NOP
						COMMAND <= SDRAM_CMD_NOP;
						STEP <= 3'd0;
						STATE <= STATE_IDLE;
					end
				end
				else
					INIT_TIMER <= INIT_TIMER - 1'b1;	// NOPs during 100us
			end
			
			STATE_IDLE:
			begin
				// Idle
				if (RD_REQ | WR_REQ)
				begin
					COMMAND <= SDRAM_CMD_ACTIVE;
					DRAM_BA <= ADDR[21:20];
					DRAM_ADDR <= ADDR[19:8];
					STEP <= 3'd0;			// Just to make sure
					STATE <= (RD_REQ) ? STATE_READ : STATE_WRITE;
				end
				else if (REFRESH_TIMER == 4'd8)
				begin
					// Start refresh
					COMMAND <= SDRAM_CMD_REFRESH;
					STATE <= STATE_REFRESH;
				end
				else
				begin
					// Just NOP
					COMMAND <= SDRAM_CMD_NOP;
					DRAM_DQM <= 2'b11;
				end
			end
			
			STATE_REFRESH:
			begin
				// NOP after refresh
				COMMAND <= SDRAM_CMD_NOP;
				REFRESH_TIMER <= 4'd0;
				STATE <= STATE_IDLE;
			end
			
			STATE_READ:
			begin
				if (STEP == 3'd0)
				begin
					// NOP(tRCD)
					COMMAND <= SDRAM_CMD_NOP;
					DRAM_DQM <= 2'b00;
					STEP <= 3'd1;
				end
				else if (STEP == 3'd1)
				begin
					// READ
					COMMAND <= SDRAM_CMD_READ;
					DRAM_BA <= ADDR_R[21:20];
					DRAM_ADDR <= {4'b0000, ADDR_R[7:0]};	// No auto-precharge
					//DRAM_DQM <= 2'b00;
					STEP <= 3'd2;
				end
				else if (STEP == 3'd2)
				begin
					// NOP(CAS latency = 2)
					COMMAND <= SDRAM_CMD_NOP;
					//DRAM_DQM <= 2'b11;
					STEP <= 3'd3;
				end
				else if (STEP == 3'd3)
				begin
					// Latch data
					COMMAND <= SDRAM_CMD_NOP;
					RD_DATA <= DRAM_DQ;
					STEP <= 3'd0;
					STATE <= STATE_PRECHARGE;
				end
			end
			
			STATE_WRITE:
			begin
				if (STEP == 3'd0)
				begin
					// NOP(tRCD)
					COMMAND <= SDRAM_CMD_NOP;
					DRAM_DQM <= 2'b00;
					STEP <= 3'd1;
				end
				else if (STEP == 3'd1)
				begin
					// WRITE
					COMMAND <= SDRAM_CMD_WRITE;
					DRAM_BA <= ADDR_R[21:20];
					DRAM_ADDR <= {4'b0000, ADDR_R[7:0]};	// No auto-precharge
					//DRAM_DQM <= 2'b00;
					STEP <= 3'd2;
				end
				else if (STEP == 3'd2)
				begin
					// NOP 1
					COMMAND <= SDRAM_CMD_NOP;
					//DRAM_DQM <= 2'b11;
					STEP <= 3'd3;
				end
				else if (STEP == 3'd3)
				begin
					// NOP 2
					COMMAND <= SDRAM_CMD_NOP;
					STEP <= 3'd0;
					STATE <= STATE_PRECHARGE;
				end
			end
			
			STATE_PRECHARGE:
			begin
				if (STEP == 3'd0)
				begin
					// Precharge
					COMMAND <= SDRAM_CMD_PRECHARGE;
					DRAM_BA <= 2'h0;
					DRAM_ADDR <= 12'b0100_0000_0000;		// All banks
					DRAM_DQM <= 2'b11;
					STEP <= 3'd1;
				end
				else if (STEP == 3'd1)
				begin
					// NOP
					COMMAND <= SDRAM_CMD_NOP;
					STEP <= 3'd0;
					STATE <= STATE_IDLE;
				end
			end
		endcase
	end
end

assign DRAM_DQ = ((STATE == STATE_WRITE) && (STEP >= 3'd1)) ? WR_DATA : 16'hzzzz;

endmodule
