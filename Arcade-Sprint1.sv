//============================================================================
//  Sprint1 port to MiSTer
//  Copyright (c) 2019 Alan Steremberg - alanswx
//
//   
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S    // 1 - signed audio samples, 0 - unsigned
);

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = lamp;

assign HDMI_ARX = status[1] ? 8'd16 : 8'd4;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd3;

`include "build_id.v"
localparam CONF_STR = {
	"A.SPRINT1;;",
	"-;",
	"O1,Aspect Ratio,Original,Wide;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	"O8,Oil Slicks,On,Off;",
	"O9,Cycle tracks,every lap,every two laps;",
	"OA,Extended Play,extended,normal;",
	"OBC,Game time,150 Sec,120 Sec,90 Sec,60 Sec;",
	"OD,Test,Off,On;",
	"-;",
	"R0,Reset;",
	"J1,Gas,GearUp,GearDown,Start 1P,Start 2P;",
	"V,v",`BUILD_DATE
};


wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_data;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key)
);



wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
//			'hX75: btn_up          <= pressed; // up
//			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h014: btn_gas         <= pressed; // ctrl
			'h011: btn_gearup      <= pressed; // Lalt
			'h029: btn_geardown    <= pressed; // space

			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2
			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start_1     <= pressed; // 1
			'h02E: btn_coin_1      <= pressed; // 5
			'h036: btn_coin_2      <= pressed; // 6
		endcase
	end
end

//reg btn_up    = 0;
//reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_gas  = 0;
reg btn_gearup  = 0;
reg btn_geardown  = 0;

reg btn_one_player  = 0;
reg btn_two_players = 0;

reg btn_start_1=0;
reg btn_coin_1=0;
reg btn_coin_2=0;


//wire m_up     =  btn_up    | joy[3];
//wire m_down   =  btn_down  | joy[2];
wire m_left     =  btn_left   | joy[1];
wire m_right    =  btn_right  | joy[0];
wire m_gas      =  btn_gas    | joy[4];
wire m_gearup   =  btn_gearup |joy[5];
wire m_geardown =  btn_geardown | joy[6];

wire m_start1 = btn_one_player  | joy[7];
wire m_start2 = btn_two_players | joy[8];
wire m_coin   = m_start1 | m_start2;



/*
-- Configuration DIP switches, these can be brought out to external switches if desired
-- See Sprint 2 manual page 11 for complete information. Active low (0 = On, 1 = Off)
--    1 								Oil slicks			(0 - Oil slicks enabled)
--			2							Cycle tracks      (0/1 - Cycle every lap/every two laps)
--   			3	4					Coins per play		(00 - 1 Coin per player) 
--						5				Extended Play		(0 - Extended Play enabled)
--							6			Not used				(X - Don't care)
--								7	8	Game time			(01 - 120 Seconds)
--SW1 <= "01000101"; -- Config dip switches

Game Time:
0 0 - 150 seconds
0 1 - 120 seconds
1 0 -  90 seconds
1 1 - 60 seconds

*/
wire [7:0] SW1 = {status[8],status[9],1'b0,1'b0,status[10],1'b1,status[12:11]};


wire [1:0] steer;

joy2quad steer1
(
	.CLK(CLK_VIDEO_2),
	.clkdiv('d22500),
	
	.right(m_right),
	.left(m_left),
	
	.steer(steer)
);

wire gear1,gear2,gear3;

gearshift gearshift1
(
	.CLK(CLK_VIDEO_2),
	.reset(m_start1|m_start2),
	
	.gearup(m_gearup),
	.geardown(m_geardown),
	
	.gear1(gear1),
	.gear2(gear2),
	.gear3(gear3)

);



wire videowht,videoblk,compositesync,lamp;

sprint1 sprint1(
	.Clk_50_I(CLK_50M),
	.Reset_n(~(RESET | status[0] | buttons[1] | ioctl_download)),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_data),
	.dn_wr(ioctl_wr),

	.VideoW_O(videowht),
	.VideoB_O(videoblk),

	.Sync_O(compositesync),
	.Audio1_O(audio),
	.Coin1_I(~(m_coin|btn_coin_1)),
	.Coin2_I(~(m_coin|btn_coin_2)),
	.Start_I(~(m_start1|btn_start_1)),
	.Gas_I(~m_gas),
	.Gear1_I(gear1),
	.Gear2_I(gear2),
	.Gear3_I(gear3),
	.Test_I	(~status[13]),
	.SteerA_I(steer[1]),
	.SteerB_I(steer[0]),
	.StartLamp_O(lamp),
	.hs_O(hs),
	.vs_O(vs),
	.hblank_O(hblank),
	.vblank_O(vblank),
	.clk_12(clk_12),
	.clk_6_O(CLK_VIDEO_2),
	.SW1_I(SW1)
	);
			
wire [6:0] audio;
wire [1:0] video;

///////////////////////////////////////////////////
wire clk_24,clk_12,CLK_VIDEO_2;
wire clk_sys,locked;
reg [7:0] vid_mono;
wire[1:0] sprint_vid;

always @(posedge clk_sys) begin
		casex({videowht,videoblk})
			//2'b01: vid_mono<=8'b01010000;
			2'b01: vid_mono<=8'b01110000;
			2'b10: vid_mono<=8'b10000110;
			2'b11: vid_mono<=8'b11111111;
			2'b00: vid_mono<=8'b00000000;
		endcase
end

assign r=vid_mono[7:5];
assign g=vid_mono[7:5];
assign b=vid_mono[7:5];

assign AUDIO_L={audio,1'b0,8'b00000000};
assign AUDIO_R=AUDIO_L;
assign AUDIO_S = 0;

wire hblank, vblank;
wire hs, vs;
wire [2:0] r,g;
wire [2:0] b;

reg ce_pix;
always @(posedge clk_24) begin
        reg old_clk;

        old_clk <= CLK_VIDEO_2;
        ce_pix <= old_clk & ~CLK_VIDEO_2;
end

arcade_fx #(320,9) arcade_video
(
        .*,

        .clk_video(clk_24),

        .RGB_in({r,g,b}),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3])
);


pll pll (
	.refclk ( CLK_50M   ),
	.rst(0),
	.locked 		( locked    ),        // PLL is running stable
	.outclk_0	( clk_24	),        // 24 MHz
	.outclk_1	( clk_12	)        // 12 MHz
	 );

assign clk_sys=clk_12;

endmodule
