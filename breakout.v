`timescale 1ns / 1ns // `timescale time_unit/time_precision
`include "vga_adapter/vga_adapter.v"
`include "vga_adapter/vga_address_translator.v"
`include "vga_adapter/vga_controller.v"
`include "vga_adapter/vga_pll.v"

module breakout
	(
		CLOCK_50,						//	On Board 50 MHz
      KEY,
      SW,
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK,						//	VGA BLANK
		VGA_SYNC,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   							//	VGA Blue[9:0]
	);

	input		CLOCK_50;				//	50 MHz
	input		[9:0] SW;
	input		[3:0] KEY;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK;				//	VGA BLANK
	output			VGA_SYNC;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.

	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			// Signals for the DAC to drive the monitor.
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK),
			.VGA_SYNC(VGA_SYNC),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "display.mif";

	wire resetn;
	assign resetn = KEY[0];
	wire start, ball_move;
	assign start = KEY[1];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour, ball_c, paddle_c;
	wire [3:0] score_left, score_right, prev_score_left, prev_score_right;
	wire [7:0] x, ball_x, paddle_x;
	wire [6:0] y, ball_y, paddle_y, prev_paddlewidth, paddle_width;
	wire [1:0] prev_balldir, ball_dir, prev_paddledir, paddle_dir, speed, draw_score_counter;
	reg  [1:0] lives;
	
	wire ld_update, writeEn, erase, draw_ball, draw_paddle, draw_bricks, draw_score, draw_lives,
		  ld_pos_ball, ld_pos_paddle, ld_pos_bricks, ld_pos_score, ld_pos_lives, set, go, 
		  done_drawing, done_bricks, clear_screen;
	
	parameter TOP = 7'b0000000,
				 BOTTOM = 7'b1111000,
				 RIGHT = 8'b10001000,
				 LEFT = 8'b00000000,
				 BALL_START_X = 8'b00001000,
				 BALL_START_Y = 7'b1000000,
				 PADDLE_START_X = 8'b00001000,
				 PADDLE_START_Y = 7'b1101100,
				 BALL_HEIGHT = 3'b010,
				 BALL_WIDTH = 3'b010,
				 // BALL_HEIGHT = 3'b001,
				 // BALL_WIDTH = 3'b001,
				 BALL_COLOUR = 3'b100,
				 PADDLE_HEIGHT = 3'b011,					
				 PADDLE_START_WIDTH = 7'b0011100,
				 PADDLE_INCREASE_WIDTH = 7'b000111,
				 PADDLE_COLOUR = 3'b010,
				 BRICK_HEIGHT = 4'b0110,
				 BRICK_WIDTH = 4'b1011,
				 BRICK_START_X = 8'b00001000,
				 BRICK_START_Y = 7'b0001000,
				 BRICK_SPACER = 2'b01,
				 BRICK_ROW = 10,
				 NUM_BRICKS = 50,
				 SCORE1_X = (1 + BRICK_ROW)*(BRICK_WIDTH + BRICK_SPACER) + 6*(BRICK_SPACER),
				 SCORE1_Y = BRICK_START_Y,
				 SCORE2_X = SCORE1_X + BRICK_WIDTH,
				 SCORE2_Y = BRICK_START_Y,
				 SCORE_ROWS = 10,
				 SCORE_COLS = 6,
				 LIVES_X = SCORE2_X,
				 LIVES_Y = SCORE2_Y + 4'b1111;

	// Number arrays for score, lives
		reg [SCORE_COLS-1:0] zero [SCORE_ROWS-1:0] 	= '{ 6'b111111, 6'b100001, 6'b100001, 6'b100001, 6'b100001,
																		  6'b100001, 6'b100001, 6'b100001, 6'b100001, 6'b111111 };
		reg [SCORE_COLS-1:0] one [SCORE_ROWS-1:0]	 	= '{ 6'b111111, 6'b000100, 6'b000100, 6'b000100, 6'b000100,
																		  6'b000100, 6'b000100, 6'b000100, 6'b000100, 6'b111100 };
		reg [SCORE_COLS-1:0] two [SCORE_ROWS-1:0]	 	= '{ 6'b111111, 6'b100000, 6'b100000, 6'b100000, 6'b100000,
																		  6'b111111, 6'b000001, 6'b000001, 6'b000001, 6'b111111 };	
		reg [SCORE_COLS-1:0] three [SCORE_ROWS-1:0]	= '{ 6'b111111, 6'b000001, 6'b000001, 6'b000001, 6'b000001,
																		  6'b111111, 6'b000001, 6'b000001, 6'b000001, 6'b111111 };
		reg [SCORE_COLS-1:0] four [SCORE_ROWS-1:0]	= '{ 6'b000001, 6'b000001, 6'b000001, 6'b000001, 6'b000001,
																		  6'b111111, 6'b100001, 6'b100001, 6'b100001, 6'b100001 };
		reg [SCORE_COLS-1:0] five [SCORE_ROWS-1:0]	= '{ 6'b111111, 6'b000001, 6'b000001, 6'b000001, 6'b000001,
																		  6'b111111, 6'b100000, 6'b100000, 6'b100000, 6'b111111 };
		reg [SCORE_COLS-1:0] six [SCORE_ROWS-1:0]		= '{ 6'b111111, 6'b100001, 6'b100001, 6'b100001, 6'b100001,
																		  6'b111111, 6'b100000, 6'b100000, 6'b100000, 6'b111111 };
		reg [SCORE_COLS-1:0] seven [SCORE_ROWS-1:0]	= '{ 6'b000001, 6'b000001, 6'b000001, 6'b000001, 6'b000001,
																		  6'b000001, 6'b000001, 6'b000001, 6'b000001, 6'b111111 };
		reg [SCORE_COLS-1:0] eight [SCORE_ROWS-1:0] 	= '{ 6'b111111, 6'b100001, 6'b100001, 6'b100001, 6'b100001,
																		  6'b111111, 6'b100001, 6'b100001, 6'b100001, 6'b111111 };
		reg [SCORE_COLS-1:0] nine [SCORE_ROWS-1:0]	= '{ 6'b000001, 6'b000001, 6'b000001, 6'b000001, 6'b000001,
																		  6'b111111, 6'b100001, 6'b100001, 6'b100001, 6'b111111 };															  
																		
			 
	reg [7:0] bricks_x [NUM_BRICKS-1:0];
	reg [6:0] bricks_y [NUM_BRICKS-1:0];
	reg [2:0] bricks_c [NUM_BRICKS-1:0];
	reg [0:0] bricks_e [NUM_BRICKS-1:0];
	reg [0:0] prev_bricks_e	 [NUM_BRICKS-1:0];
	reg [4:0] rand_number;
	wire [4:0] irand, irand_next;
	wire [24:0] divided_clock;
	
	initial begin
		lives = 2'b11;
		irand = 5'h1f;
		for (int i=0, r=0, k=0; k < NUM_BRICKS; i++, k++) begin
			irand_next[4] = irand[4]^irand[1];
			irand_next[3] = irand[3]^irand[0];
			irand_next[2] = irand[2]^irand_next[4];
			irand_next[1] = irand[1]^irand_next[3];
			irand_next[0] = irand[0]^irand_next[2];
			irand = irand_next;
			if (i == BRICK_ROW) begin r++; i = 0; end
			bricks_x[k] = BRICK_START_X + i*(BRICK_WIDTH + BRICK_SPACER);
			bricks_y[k] = BRICK_START_Y + r*(BRICK_HEIGHT + BRICK_SPACER);
			if ( ((irand[2:0] == 3'b111) || (irand[2:0] == 3'b110)) && (k%3) ) begin
				bricks_c[k] = irand[2:0];
			end else begin
				bricks_c[k] = 3'b011;
			end
		end
	end
	
	always @(negedge resetn) begin
		if (lives == 2'b10) lives <= 2'b00;
		else lives <= lives + 1'b1;
	end
	 
	// Instansiate datapath
	datapath d0(CLOCK_50, resetn, ld_pos_ball, ld_pos_paddle, ld_pos_bricks, ld_pos_score, ld_pos_lives, set,
					writeEn, erase, draw_ball, draw_paddle, draw_bricks, draw_score, draw_score_counter, draw_lives, clear_screen,
					rand_number, bricks_x, bricks_y, bricks_c, bricks_e, prev_bricks_e, lives,
				   ball_dir, paddle_dir, prev_balldir, prev_paddledir,
					score_left, score_right, prev_score_left, prev_score_right,
					ball_x, ball_y, ball_c, paddle_x, paddle_y, paddle_c, x, y, colour, done_drawing, done_bricks,
					TOP, BOTTOM, LEFT, RIGHT,
					BALL_HEIGHT, BALL_WIDTH, BALL_COLOUR,
					PADDLE_HEIGHT, PADDLE_COLOUR, paddle_width, prev_paddlewidth,
					BRICK_HEIGHT, BRICK_WIDTH,
					SCORE1_X, SCORE1_Y, SCORE2_X, SCORE2_Y, zero, one, two, three, four, five, six, seven, eight, nine,
					LIVES_X, LIVES_Y);
	
	// Instansiate FSM control
	control c0(CLOCK_50, resetn, SW[9], go, done_drawing, done_bricks, ld_pos_ball, ld_pos_paddle, ld_pos_bricks, ld_pos_score, ld_pos_lives, set,
				  ld_update, writeEn, erase, draw_ball, draw_paddle, draw_bricks, draw_score, draw_score_counter, draw_lives, clear_screen, ball_move);
	
	update u0(CLOCK_50, resetn, ball_dir, paddle_dir, prev_balldir, prev_paddledir, {SW[0],SW[1]}, ld_update, start, ball_move,
				 bricks_x, bricks_y, bricks_c, bricks_e, prev_bricks_e, speed, lives,
				 score_left, score_right, prev_score_left, prev_score_right,
				 ball_x, ball_y, ball_c, paddle_x, paddle_y, paddle_c, x, y, colour,
				 TOP, BOTTOM, LEFT, RIGHT,
				 BALL_START_X, BALL_START_Y, BALL_HEIGHT, BALL_WIDTH, BALL_COLOUR,
				 PADDLE_START_X, PADDLE_START_Y, PADDLE_HEIGHT, PADDLE_COLOUR,
				 PADDLE_START_WIDTH, PADDLE_INCREASE_WIDTH, paddle_width, prev_paddlewidth,
				 BRICK_START_X, BRICK_START_Y, BRICK_SPACER, BRICK_ROW, BRICK_HEIGHT, BRICK_WIDTH);
	
	fibonacci_lfsr_5bit f0(CLOCK_50, resetn, rand_number);
	RateDivider r0(CLOCK_50, resetn, 50000000/(60 + (speed * 20)), divided_clock, go);
endmodule


module RateDivider(Clock, Reset, d, Counter, Out);
    input Clock, Reset;
    input [24:0] d;
    output reg [24:0] Counter;
    output Out;

    always @(posedge Clock, negedge Reset)
    begin
        if (Reset == 1'b0)
            Counter <= d;
        else if (Counter == 0)
            Counter <= d;
        else
            Counter <= Counter - 1;
    end
    
    assign Out = (Counter == 0) ? 1 : 0;
endmodule

module fibonacci_lfsr_5bit(Clock, Reset, d);
	input Clock, Reset;
	output reg [4:0] d;
	reg [4:0] d_next;

	always @* begin
	  d_next[4] = d[4]^d[1];
	  d_next[3] = d[3]^d[0];
	  d_next[2] = d[2]^d_next[4];
	  d_next[1] = d[1]^d_next[3];
	  d_next[0] = d[0]^d_next[2];
	end

	always @(posedge Clock or negedge Reset) begin
	  if(!Reset) d <= 5'h1f;
	  else d <= d_next;
	end
endmodule

module control(clk, reset, start_game, go, done_drawing, done_bricks, ld_pos_ball, ld_pos_paddle, ld_pos_bricks, ld_pos_score, ld_pos_lives, set,
					ld_update, writeEn, erase, draw_ball, draw_paddle, draw_bricks, draw_score, draw_score_counter, draw_lives, clear_screen, ball_move);
	input clk, reset, start_game, go, done_drawing, done_bricks, ball_move;
	output reg  ld_pos_ball, ld_pos_paddle, ld_pos_bricks, ld_pos_score, ld_pos_lives, set, ld_update,
					writeEn, erase, draw_ball, draw_paddle, draw_bricks, draw_score, draw_lives, clear_screen;
	output reg [1:0] draw_score_counter;
	
	reg [5:0] current_state, next_state; 
	
	localparam START 			= 6'd0,
				  LOAD_PADDLE  = 6'd1,
				  DRAW_PADDLE  = 6'd2,
				  LOAD_BRICKS	= 6'd3,
				  DRAW_BRICKS	= 6'd4,
				  LOAD_BALL		= 6'd5,
				  DRAW_BALL 	= 6'd6,
				  UPDATE 		= 6'd7,
				  RESET			= 6'd8,
				  ERASE_BALL 	= 6'd9,
				  ERASE_PADDLE = 6'd10,
				  LOAD_EPADDLE	= 6'd11,
				  LOAD_EBALL	= 6'd12,
				  LOAD_SCORE1	= 6'd13,
				  DRAW_SCORE1	= 6'd14,
				  LOAD_SCORE2	= 6'd15,
				  DRAW_SCORE2	= 6'd16,
				  LOAD_LIVES	= 6'd17,
				  DRAW_LIVES   = 6'd18;
				  
    always@(*)
    begin: state_table 
		case (current_state)		 
			 START :  		next_state = (start_game) ? RESET : START;
			 RESET :			next_state = (done_drawing) ? UPDATE : RESET;
			 UPDATE:  		next_state = LOAD_PADDLE;			 
			 LOAD_PADDLE: 	next_state = DRAW_PADDLE;
			 DRAW_PADDLE:	next_state = (done_drawing) ? LOAD_BRICKS : DRAW_PADDLE;
			 LOAD_BRICKS:	next_state = DRAW_BRICKS;
			 DRAW_BRICKS:	next_state = (done_bricks) ? LOAD_SCORE1 : DRAW_BRICKS;
			 LOAD_SCORE1:	next_state = DRAW_SCORE1;
			 DRAW_SCORE1:	next_state = (done_drawing) ? LOAD_SCORE2 : DRAW_SCORE1;
			 LOAD_SCORE2:	next_state = DRAW_SCORE2;
			 DRAW_SCORE2:	next_state = (done_drawing) ? LOAD_LIVES : DRAW_SCORE2;
			 LOAD_LIVES:	next_state = DRAW_LIVES;
			 DRAW_LIVES:	next_state = (done_drawing) ? LOAD_BALL : DRAW_LIVES;
			 LOAD_BALL:		next_state = DRAW_BALL;
			 DRAW_BALL: 	next_state = (done_drawing && go) ? LOAD_EPADDLE : DRAW_BALL;
			 LOAD_EPADDLE: next_state = (ball_move) ? ERASE_PADDLE : LOAD_EPADDLE;
			 ERASE_PADDLE: next_state = (done_drawing) ? LOAD_EBALL : ERASE_PADDLE;
			 LOAD_EBALL: 	next_state = ERASE_BALL;
			 ERASE_BALL: 	next_state = (done_drawing) ? RESET : ERASE_BALL;
          default: 		next_state = START;
		endcase
    end
	 
	 always @(*)
    begin: enable_signals
	   ld_pos_ball = 1'b0;
		ld_pos_paddle = 1'b0;
		ld_pos_bricks = 1'b0;
		ld_pos_score = 1'b0;
		ld_pos_lives = 1'b0;
		ld_update = 1'b0;
		writeEn = 1'b0;
		erase = 1'b0;
		draw_ball = 1'b0;
		draw_paddle = 1'b0;
		draw_bricks = 1'b0;
		draw_score = 1'b0;
		draw_score_counter = 2'b00;
		draw_lives = 1'b0;
		set = 1'b0;
		clear_screen = 1'b0;
		case (current_state)
			RESET: begin clear_screen = 1'b1; writeEn = 1'b1; end
			LOAD_PADDLE: begin ld_pos_paddle = 1'b1; set = 1'b1; end
			DRAW_PADDLE: begin writeEn = 1'b1; draw_paddle = 1'b1; end
			LOAD_BRICKS: begin ld_pos_bricks = 1'b1; set = 1'b1; end
			DRAW_BRICKS: begin writeEn = 1'b1; draw_bricks = 1'b1; end
			
			LOAD_SCORE1: begin ld_pos_score = 1'b1; set = 1'b1; draw_score_counter = 2'b01; end
			DRAW_SCORE1: begin writeEn = 1'b1; draw_score = 1'b1; end
			LOAD_SCORE2: begin ld_pos_score = 1'b1; set = 1'b1; draw_score_counter = 2'b10; end
			DRAW_SCORE2: begin writeEn = 1'b1; draw_score = 1'b1; end
			LOAD_LIVES: begin ld_pos_lives = 1'b1; set = 1'b1; end
			DRAW_LIVES: begin writeEn = 1'b1; draw_lives = 1'b1; end
			
			LOAD_BALL: begin ld_pos_ball = 1'b1; set = 1'b1; end
			DRAW_BALL: begin writeEn = 1'b1; draw_ball = 1'b1; end
			LOAD_EPADDLE: begin set = 1'b1; ld_pos_paddle = 1'b1; end
			LOAD_EBALL: begin set = 1'b1; ld_pos_ball = 1'b1; end
			ERASE_BALL: begin writeEn = 1'b1; erase = 1'b1; draw_ball = 1'b1; end
			ERASE_PADDLE: begin writeEn = 1'b1; erase = 1'b1; draw_paddle = 1'b1; end
			UPDATE: begin ld_update = 1'b1; end
		endcase
	 end
	 
	always@(posedge clk) current_state <= (!reset) ? START : next_state;
	
endmodule

module update(clk, reset, ball_dir, paddle_dir, input_balldir, input_paddledir, sw, ld_update, start, ball_move,
				  bricks_x, bricks_y, bricks_c, bricks_e, input_bricks_e, speed, lives,
				  score_left, score_right, input_score_left, input_score_right,
				  ball_X, ball_Y, ball_C, paddle_X, paddle_Y, paddle_C, X, Y, C,
				  TOP, BOTTOM, LEFT, RIGHT,
				  BALL_START_X, BALL_START_Y, BALL_HEIGHT, BALL_WIDTH, BALL_COLOUR,
				  PADDLE_START_X, PADDLE_START_Y, PADDLE_HEIGHT, PADDLE_COLOUR,
				  PADDLE_START_WIDTH, PADDLE_INCREASE_WIDTH, paddle_width, input_paddlewidth,
				  BRICK_START_X, BRICK_START_Y, BRICK_SPACER, BRICK_ROW, BRICK_HEIGHT, BRICK_WIDTH);
	input [7:0] LEFT, RIGHT, BALL_START_X, PADDLE_START_X;
	input [6:0] TOP, BOTTOM, BALL_START_Y, PADDLE_START_Y;
	input [2:0] BALL_HEIGHT, BALL_WIDTH, BALL_COLOUR, PADDLE_HEIGHT, PADDLE_COLOUR;
	input [3:0] BRICK_HEIGHT, BRICK_WIDTH;
	input [1:0] BRICK_SPACER;
	input integer BRICK_ROW;
	input [7:0] BRICK_START_X;
	input [6:0] BRICK_START_Y;
	input [6:0] input_paddlewidth, PADDLE_START_WIDTH, PADDLE_INCREASE_WIDTH;
	output reg [6:0] paddle_width;
	output reg [1:0] speed;
	input [1:0] lives;
	
	localparam NUM_BRICKS = 50;
	input [7:0] bricks_x [NUM_BRICKS-1:0];
	input [6:0] bricks_y [NUM_BRICKS-1:0];
	input [2:0] bricks_c [NUM_BRICKS-1:0];
	input input_bricks_e [NUM_BRICKS-1:0];
	output reg bricks_e [NUM_BRICKS-1:0];
	
	input clk, reset, ld_update, start;
	input [1:0] input_balldir, input_paddledir, sw;
	input [7:0] X;
	input [6:0] Y;
	input [2:0] C;
	
	output reg [1:0] ball_dir, paddle_dir;
	output reg [7:0] ball_X, paddle_X;
	output reg [6:0] ball_Y, paddle_Y;
	output reg [2:0] ball_C, paddle_C;
	output reg ball_move;
	
	input [3:0] input_score_left, input_score_right;
	output reg [3:0] score_left, score_right;
	
	always@(posedge clk) begin
		if (!reset) begin
			ball_X <= BALL_START_X;
			ball_Y <= BALL_START_Y;
			ball_C <= BALL_COLOUR;
			ball_dir <= 2'b11;
			if (lives == 2'b00) begin
				paddle_width <= PADDLE_START_WIDTH;
				speed <= 1'b0;
				score_left <= 0; score_right <= 0;
				for (int i=0; i < NUM_BRICKS; i++) begin
					bricks_e[i] <= 1'b1;
				end
			end
			paddle_X <= PADDLE_START_X;
			paddle_Y <= PADDLE_START_Y;
			paddle_C <= PADDLE_COLOUR;
			paddle_dir <= 2'b00;
			ball_move <= 1'b0;
		end else if (!start) begin
			ball_move <= 1'b1;
		end else if (ld_update) begin
			bricks_e <= input_bricks_e;
			
			ball_X <= (input_balldir[0]) ? (ball_X + 1'b1) : (ball_X - 1'b1);			 
			ball_Y <= (input_balldir[1]) ? (ball_Y + 1'b1) : (ball_Y - 1'b1);
			 
			// paddle_X <= (input_paddledir == sw) ? (paddle_X + 1'b1) : (paddle_X - 1'b1);
			/* right */ if ( sw == 2'b01 && ((paddle_X + input_paddlewidth) <= RIGHT) ) begin paddle_X <= paddle_X + 1'b1; paddle_dir <= 2'b01; end
			/* left  */ else if ( sw == 2'b10 && (paddle_X >= (LEFT + 1'b1)) )	  begin paddle_X <= paddle_X - 1'b1; paddle_dir <= 2'b10; end
							else paddle_dir <= 2'b00;
			
			if ( ((ball_Y + BALL_HEIGHT) >= paddle_Y) && (ball_X >= paddle_X) && (ball_X <= (paddle_X + input_paddlewidth)) ) begin
				ball_dir[1] <= 1'b0;
				if ( (input_paddledir == 2'b01) && (!input_balldir[0]) ) begin
					ball_X <= ball_X + 1; ball_dir[0] <= 1'b1;
				end else if ( (input_paddledir == 2'b10) && (input_balldir[0]) ) begin
					ball_X <= ball_X - 1; ball_dir[0] <= 1'b0;
				end
			end
						
			for (int i=0, r=0, k=0; k < NUM_BRICKS; i++, k++) begin
				if (i == BRICK_ROW) begin r++; i = 0; end
				// hits bottom of brick
				if ( (ball_Y == (BRICK_START_Y + (r+1)*(BRICK_HEIGHT + BRICK_SPACER))) &&
					  (ball_X >= (BRICK_START_X + i*(BRICK_WIDTH + BRICK_SPACER))) &&
					  (ball_X <= (BRICK_START_X + i*(BRICK_WIDTH + BRICK_SPACER) + BRICK_WIDTH)) &&
					  (input_bricks_e[k] == 1'b1) ) begin
					ball_dir[1] <= 1'b1; bricks_e[k] <= 1'b0;
					if (bricks_c[k] == 3'b110) paddle_width <= (paddle_width + PADDLE_INCREASE_WIDTH);
					else if (bricks_c[k] == 3'b111) speed <= (speed + 1'b1);
					if (input_score_right == 4'b1001) begin
						score_right <= 0;
						score_left <= score_left + 1'b1;
					end else score_right <= score_right + 1;
					break;
				// hits top of brick
				end
				if ( ((ball_Y + BALL_HEIGHT) == (BRICK_START_Y + (r)*(BRICK_HEIGHT + BRICK_SPACER))) &&
					  (ball_X >= (BRICK_START_X + i*(BRICK_WIDTH + BRICK_SPACER))) &&
					  (ball_X <= (BRICK_START_X + i*(BRICK_WIDTH + BRICK_SPACER) + BRICK_WIDTH)) &&
					  (input_bricks_e[k] == 1'b1) ) begin
					ball_dir[1] <= 1'b0; bricks_e[k] <= 1'b0;
					if (bricks_c[k] == 3'b110) paddle_width <= (paddle_width + PADDLE_INCREASE_WIDTH);
					else if (bricks_c[k] == 3'b111) speed <= (speed + 1'b1);
					if (input_score_right == 4'b1001) begin
						score_right <= 0;
						score_left <= score_left + 1'b1;
					end else score_right <= score_right + 1;
					break;
				// hits left of brick
				end
				if ( (ball_X + BALL_WIDTH) == (BRICK_START_X + i*(BRICK_WIDTH + BRICK_SPACER)) &&
					  (ball_Y >= (BRICK_START_Y + r*(BRICK_HEIGHT + BRICK_SPACER))) &&
					  (ball_Y <= (BRICK_START_Y + (r+1)*(BRICK_HEIGHT + BRICK_SPACER))) &&
					  (input_bricks_e[k] == 1'b1) ) begin
					ball_dir[0] <= 1'b0; bricks_e[k] <= 1'b0;
					if (bricks_c[k] == 3'b110) paddle_width <= (paddle_width + PADDLE_INCREASE_WIDTH);
					else if (bricks_c[k] == 3'b111) speed <= (speed + 1'b1);
					if (input_score_right == 4'b1001) begin
						score_right <= 0;
						score_left <= score_left + 1'b1;
					end else score_right <= score_right + 1;
					break;
				// hits right of brick
				end
				if ( ball_X == (BRICK_START_X + (i+1)*(BRICK_WIDTH + BRICK_SPACER)) &&
					  (ball_Y >= (BRICK_START_Y + r*(BRICK_HEIGHT + BRICK_SPACER))) &&
					  (ball_Y <= (BRICK_START_Y + (r+1)*(BRICK_HEIGHT + BRICK_SPACER))) &&
					  (input_bricks_e[k] == 1'b1) ) begin
					ball_dir[0] <= 1'b1; bricks_e[k] <= 1'b0;
					if (bricks_c[k] == 3'b110) paddle_width <= (paddle_width + PADDLE_INCREASE_WIDTH);
					else if (bricks_c[k] == 3'b111) speed <= (speed + 1'b1);
					if (input_score_right == 4'b1001) begin
						score_right <= 0;
						score_left <= score_left + 1'b1;
					end else score_right <= score_right + 1;
					break;
				end
			end
			
			if (ball_Y > (BOTTOM - 2'b11)) ball_move <= 1'b0;  // ball_dir[1] <= 1'b0;
			else if (ball_Y < (TOP + 2'b11) ) ball_dir[1] <= 1'b1;
			
			if ((ball_X + BALL_WIDTH) > (RIGHT - 2'b11)) ball_dir[0] <= 1'b0;
			else if (ball_X < (LEFT + 2'b11) ) ball_dir[0] <= 1'b1;
			 
		end
	end
	
endmodule

module datapath(clk, reset, ld_pos_ball, ld_pos_paddle, ld_pos_bricks, ld_pos_score, ld_pos_lives, set,
					 writeEn, erase, draw_ball, draw_paddle, draw_bricks, draw_score, draw_score_counter, draw_lives, clear_screen,
					 rand_number, bricks_x, bricks_y, bricks_c, bricks_e, prev_bricks_e, lives,
					 ball_dir, paddle_dir, prev_balldir, prev_paddledir,
					 score_left, score_right, prev_score_left, prev_score_right,
					 ball_X, ball_Y, ball_C, paddle_X, paddle_Y, paddle_C, X, Y, C, done_drawing, done_bricks,
					 TOP, BOTTOM, LEFT, RIGHT,
					 BALL_HEIGHT, BALL_WIDTH, BALL_COLOUR,
					 PADDLE_HEIGHT, PADDLE_COLOUR, paddle_width, prev_paddlewidth,
					 BRICK_HEIGHT, BRICK_WIDTH,
					 SCORE1_X, SCORE1_Y, SCORE2_X, SCORE2_Y, zero, one, two, three, four, five, six, seven, eight, nine,
					 LIVES_X, LIVES_Y);
					 
	localparam SCORE_ROWS = 10, SCORE_COLS = 6;
	reg	[SCORE_COLS-1:0] curr_score [SCORE_ROWS-1:0];
	reg	[SCORE_COLS-1:0] curr_lives [SCORE_ROWS-1:0];
	
	input [SCORE_COLS-1:0] zero [SCORE_ROWS-1:0];
	input [SCORE_COLS-1:0] one [SCORE_ROWS-1:0];
	input [SCORE_COLS-1:0] two [SCORE_ROWS-1:0];
	input [SCORE_COLS-1:0] three [SCORE_ROWS-1:0];
	input [SCORE_COLS-1:0] four [SCORE_ROWS-1:0];
	input [SCORE_COLS-1:0] five [SCORE_ROWS-1:0];
	input [SCORE_COLS-1:0] six [SCORE_ROWS-1:0];
	input [SCORE_COLS-1:0] seven [SCORE_ROWS-1:0];
	input [SCORE_COLS-1:0] eight [SCORE_ROWS-1:0];
	input [SCORE_COLS-1:0] nine [SCORE_ROWS-1:0];
	
	input [7:0] LEFT, RIGHT, SCORE1_X, SCORE2_X, LIVES_X;
	input [6:0] TOP, BOTTOM, SCORE1_Y, SCORE2_Y, LIVES_Y;
	reg 	[7:0] CURR_SCORE_X;
	reg 	[6:0] CURR_SCORE_Y;
	
	
	input [2:0] BALL_HEIGHT, BALL_WIDTH, BALL_COLOUR, PADDLE_HEIGHT, PADDLE_COLOUR;
	input [3:0] BRICK_HEIGHT, BRICK_WIDTH;
	input [6:0] paddle_width;
	output reg [6:0] prev_paddlewidth;
	
	localparam NUM_BRICKS = 50;
	input [4:0] rand_number;
	input [7:0] bricks_x [NUM_BRICKS-1:0];
	input [6:0] bricks_y [NUM_BRICKS-1:0];
	input [2:0] bricks_c [NUM_BRICKS-1:0];
	input bricks_e [NUM_BRICKS-1:0];
	output reg prev_bricks_e [NUM_BRICKS-1:0];
	input [1:0] lives;
	
	input clk, reset, ld_pos_ball, ld_pos_paddle, ld_pos_bricks, ld_pos_score, ld_pos_lives, set, writeEn, erase,
			draw_ball, draw_paddle, draw_bricks, draw_score, draw_lives, clear_screen;
	output reg done_drawing, done_bricks;
	input [1:0] ball_dir, paddle_dir, draw_score_counter;
	output reg [1:0] prev_balldir, prev_paddledir;
	input [7:0] ball_X, paddle_X;
	input [6:0] ball_Y, paddle_Y;
	input [2:0] ball_C, paddle_C;
	output reg [7:0] X;
	output reg [6:0] Y;
	output reg [2:0] C;
	input[3:0] score_left, score_right;
	output reg [3:0] prev_score_left, prev_score_right;

	reg [7:0] counter_x;
	reg [6:0] counter_y;
	reg [6:0] counter_bricks;

	 always@(posedge clk) begin
        if(!reset) begin
				counter_x <= 0;
				counter_y <= 0;
				counter_bricks <= 0;
				done_drawing <= 1'b0;
				done_bricks <= 1'b0;
				if (lives == 2'b00) begin
					for (int i=0; i < NUM_BRICKS; i++) begin
						prev_bricks_e[i] <= 1'b1;
					end
				end
		  end else if (clear_screen) begin
				C <= 3'b000;
				if ( (counter_x < RIGHT) && !done_drawing ) begin
					counter_x <= counter_x + 1;
					X <= counter_x;
				end else if ( (counter_y < BOTTOM) && !done_drawing ) begin
					counter_x <= 0;
					counter_y <= counter_y + 1;
					Y <= counter_y;
				end else begin
					counter_x <= 0;
					counter_y <= 0;
					done_drawing <= 1'b1;
				end
        end else begin
				if (set) begin
					done_drawing <= 0;
					counter_x <= 0;
					counter_y <= 0;
            end
				if (ld_pos_ball) begin
					X <= ball_X;
					Y <= ball_Y;
					C <= ball_C;
					prev_balldir <= ball_dir;
				end else if (ld_pos_paddle) begin
					X <= paddle_X;
					Y <= paddle_Y;
					C <= paddle_C;
					prev_paddledir <= paddle_dir;
					prev_paddlewidth <= paddle_width;
				end else if (ld_pos_bricks) begin
					X <= bricks_x[0];
					Y <= bricks_y[0];
					C <= bricks_c[0];
					prev_bricks_e <= bricks_e;
				end else if (ld_pos_score) begin
					prev_score_left <= score_left;
					prev_score_right <= score_right;
					if (draw_score_counter == 2'b01) begin
						X <= SCORE1_X;
						Y <= SCORE1_Y;
						CURR_SCORE_X <= SCORE1_X;
						CURR_SCORE_Y <= SCORE1_Y;
						case (score_left)
							4'b0000: curr_score <= zero;
							4'b0001: curr_score <= one;
							4'b0010: curr_score <= two;
							4'b0011: curr_score <= three;
							4'b0100: curr_score <= four;
							4'b0101: curr_score <= five;
							4'b0110: curr_score <= six;
							4'b0111: curr_score <= seven;
							4'b1000: curr_score <= eight;
							4'b1001: curr_score <= nine;
						endcase
					end else if (draw_score_counter == 2'b10) begin
						X <= SCORE2_X;
						Y <= SCORE2_Y;
						CURR_SCORE_X <= SCORE2_X;
						CURR_SCORE_Y <= SCORE2_Y;
						case (score_right)
							4'b0000: curr_score <= zero;
							4'b0001: curr_score <= one;
							4'b0010: curr_score <= two;
							4'b0011: curr_score <= three;
							4'b0100: curr_score <= four;
							4'b0101: curr_score <= five;
							4'b0110: curr_score <= six;
							4'b0111: curr_score <= seven;
							4'b1000: curr_score <= eight;
							4'b1001: curr_score <= nine;
						endcase
					end
				end else if (ld_pos_lives) begin
					X <= LIVES_X;
					Y <= LIVES_Y;
					case (lives)
						2'b00: curr_lives <= three;
						2'b01: curr_lives <= two;
						2'b10: curr_lives <= one;
						2'b11: curr_lives <= zero;
					endcase
				end else if (writeEn) begin
					
					if (draw_ball) begin
						C <= erase ? 3'b000 : BALL_COLOUR;
						if ( (counter_x < BALL_WIDTH) && !done_drawing ) begin
							counter_x <= counter_x + 1;
							X <= ball_X + counter_x;
						end else if ( (counter_y < BALL_HEIGHT) && !done_drawing ) begin
							counter_x <= 0;
							counter_y <= counter_y + 1;
							Y <= ball_Y + counter_y;
						end else begin
							counter_x <= 0;
							counter_y <= 0;
							done_drawing <= 1'b1;
						end
					
					end else if (draw_paddle) begin
						C <= erase ? 3'b000 : PADDLE_COLOUR;
						if ( (counter_x < paddle_width) && !done_drawing ) begin
							counter_x <= counter_x + 1;
							X <= paddle_X + counter_x;
						end else if ( (counter_y < PADDLE_HEIGHT) && !done_drawing ) begin
							counter_x <= 0;
							counter_y <= counter_y + 1;
							Y <= paddle_Y + counter_y;
						end else begin
							counter_x <= 0;
							counter_y <= 0;
							done_drawing <= 1'b1;
						end
						
					end else if (draw_bricks) begin
						if (bricks_e[counter_bricks]) begin
							if (bricks_c[counter_bricks] == 3'b111) C <= rand_number[2:0];
							else C <= bricks_c[counter_bricks];
						end else C <= 3'b000;
						if (counter_x < BRICK_WIDTH) begin
							counter_x <= counter_x + 1;
							X <= bricks_x[counter_bricks] + counter_x;
						end else if (counter_y < BRICK_HEIGHT) begin
							counter_x <= 0;
							counter_y <= counter_y + 1;
							Y <= bricks_y[counter_bricks] + counter_y;
						end else begin
							counter_x <= 0;
							counter_y <= 0;
							counter_bricks <= counter_bricks + 1;
						end
						done_bricks <= (counter_bricks == NUM_BRICKS);
						if (done_bricks) counter_bricks <= 0;
					
					end else if (draw_score) begin
						C <= (curr_score[counter_y - 1][SCORE_COLS - counter_x - 1] == 0) ? 3'b001 : 3'b100;					
						if ( (counter_x < SCORE_COLS) && !done_drawing ) begin
							counter_x <= counter_x + 1;
							X <= CURR_SCORE_X + counter_x;
						end else if ( (counter_y < SCORE_ROWS) && !done_drawing ) begin
							counter_x <= 0;
							counter_y <= counter_y + 1;
							Y <= CURR_SCORE_Y + counter_y;
						end else begin
							C <= 3'b100;
							counter_x <= 0;
							counter_y <= 0;
							done_drawing <= 1'b1;
						end
					
					end else if (draw_lives) begin
						C <= (curr_lives[counter_y - 1][SCORE_COLS - counter_x - 1] == 0) ? 3'b001 : 3'b010;					
						if ( (counter_x < SCORE_COLS) && !done_drawing ) begin
							counter_x <= counter_x + 1;
							X <= LIVES_X + counter_x;
						end else if ( (counter_y < SCORE_ROWS) && !done_drawing ) begin
							counter_x <= 0;
							counter_y <= counter_y + 1;
							Y <= LIVES_Y + counter_y;
						end else begin
							C <= 3'b010;
							counter_x <= 0;
							counter_y <= 0;
							done_drawing <= 1'b1;
						end
					end
					
					
				end 
        end
    end
endmodule
