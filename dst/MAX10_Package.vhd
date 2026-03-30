-- Module MAX10_Package
-- VHDL Package Indel_lib.Indel_Package
--                                                                           
-- Project: General
--                                                                      
-- -------------------------------------------------------------------------- --
-- This Package consists of MAX10 specific constants and functions.    			--
-- created by qfu, Indel AG for Besi AG.													--
-- -------------------------------------------------------------------------- --
--	Remarks:																							--
--		1.)	"CSR control register" is @CSR_AD = 0x01 (RD/ WR),						--
--				"CSR status register" is @CSR_AD = 0x00 (RD/ wR).						--
--                                                                            --
-- -------------------------------------------------------------------------- --
-- History:                                                                   --
-- IB-Code: IG00                                                              --
-- 1.) Initial   version                                                      --
-- 2.) In progress...																			--
--	3.) Based on the fact that DL incl. RAM init is possible in dual boot mode	--
--		 (look at the map file highest address has to be lower than 0x2b000)		--
--		 mapping was changed again																--
-- -------------------------------------------------------------------------- --
--------------------------------------------------------------------------------
--$Rev:: 5304                                                                  $
--$Author:: qfu_m                                                              $
--$Date:: 2019-05-13 16:32:50 +0200 (Mo., 13 Mai 2019)                         $
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;

PACKAGE MAX10_Package IS

	----------------------------------
	-- Type Declarations for constants
	----------------------------------
	TYPE	mx_xfm_range_t_mx_pkg			IS ARRAY (0 TO 7) OF natural RANGE 0 TO 16#1FFFF#;
	--------------------------------------
	-- Type Declarations for constants END
	--------------------------------------
	
  
	-----------------------
	-- Constant Declaration
	-----------------------
	-- MAX10 device definitions
	CONSTANT	M02_C_MX_PKG						: natural RANGE 0 TO 7:=0;
	CONSTANT	M04_C_MX_PKG						: natural RANGE 0 TO 7:=1;
	CONSTANT	M08_C_MX_PKG						: natural RANGE 0 TO 7:=2;
	CONSTANT	M16_C_MX_PKG						: natural RANGE 0 TO 7:=3;
	CONSTANT	M25_C_MX_PKG						: natural RANGE 0 TO 7:=4;
	CONSTANT	M40_C_MX_PKG						: natural RANGE 0 TO 7:=5;
	CONSTANT	M50_C_MX_PKG						: natural RANGE 0 TO 7:=6;
	CONSTANT	Mxy_C_MX_PKG						: natural RANGE 0 TO 7:=7;
   
   -- UFM structure constants "Sector ID" 
	CONSTANT UFM1_Sec_ID_C_MX_PKG				: natural RANGE 0 TO 7:= 0;
	CONSTANT UFM0_Sec_ID_C_MX_PKG				: natural RANGE 0 TO 7:= 1;
	CONSTANT CFM2_Sec_ID_C_MX_PKG				: natural RANGE 0 TO 7:= 2;
	CONSTANT CFM1_Sec_ID_C_MX_PKG				: natural RANGE 0 TO 7:= 3;
	CONSTANT CFM0_Sec_ID_C_MX_PKG				: natural RANGE 0 TO 7:= 4;
	
	-- UFM Sector WR "Un-Protect" Selector in the CSR control register:	CSR_Ctrl(27...23)
	CONSTANT	UFM1_CSR_Unprotected_C_MX_PKG	: std_logic_vector(4 DOWNTO 0):=	"11110";
	CONSTANT	UFM0_CSR_Unprotected_C_MX_PKG	: std_logic_vector(4 DOWNTO 0):=	"11101";
	CONSTANT	CFM2_CSR_Unprotected_C_MX_PKG	: std_logic_vector(4 DOWNTO 0):=	"11011";
	CONSTANT	CFM1_CSR_Unprotected_C_MX_PKG	: std_logic_vector(4 DOWNTO 0):=	"10111";
	CONSTANT	CFM0_CSR_Unprotected_C_MX_PKG	: std_logic_vector(4 DOWNTO 0):=	"01111";
	CONSTANT	CFM12_CSR_Unprotected_C_MX_PKG	: std_logic_vector(4 DOWNTO 0):=	"10011";
	CONSTANT	All_CSR_Unprotected_C_MX_PKG	: std_logic_vector(4 DOWNTO 0):=	"00000";
		-- default value...
	CONSTANT	No_CSR_Unprotected_C_MX_PKG	: std_logic_vector(4 DOWNTO 0):=	"11111";
	
	-- UFM Sector Erase Selector in the CSR control register:				CSR_Ctrl(22...20)
	CONSTANT	UFM1_CSR_Erase_Sel_C_MX_PKG	: std_logic_vector(2 DOWNTO 0):=	"001";
	CONSTANT	UFM0_CSR_Erase_Sel_C_MX_PKG	: std_logic_vector(2 DOWNTO 0):=	"010";
	CONSTANT	CFM2_CSR_Erase_Sel_C_MX_PKG	: std_logic_vector(2 DOWNTO 0):=	"011";
	CONSTANT	CFM1_CSR_Erase_Sel_C_MX_PKG	: std_logic_vector(2 DOWNTO 0):=	"100";
	CONSTANT	CFM0_CSR_Erase_Sel_C_MX_PKG	: std_logic_vector(2 DOWNTO 0):=	"101";
	CONSTANT	None_CSR_Erase_Sel_C_MX_PKG	: std_logic_vector(2 DOWNTO 0):=	"111";
	
	-- UFM CSR control register "dummy", padding top:							CSR_Ctrl(31...28)
	CONSTANT	Padding_Top_CSR_Ctrl_C_MX_PKG	: std_logic_vector(3 DOWNTO 0):=	x"F";
	
	-- UFM Page WR "Un-Protect" Selector in the CSR control register:		CSR_Ctrl(19...0)
		-- default value
	CONSTANT No_PG_CSR_Erase_Sel_C_MX_PKG	: std_logic_vector(19 DOWNTO 0):= x"FFFFF";
	
	-- UFM Block CSR Status Register
	CONSTANT	UFM_CSR_Idle_C_MX_PKG			: std_logic_Vector(1 DOWNTO 0):= "00";
	CONSTANT	UFM_CSR_Busy_Erase_C_MX_PKG	: std_logic_Vector(1 DOWNTO 0):= "01";
	CONSTANT	UFM_CSR_Busy_WRITE_C_MX_PKG	: std_logic_Vector(1 DOWNTO 0):= "10";
	CONSTANT	UFM_CSR_Busy_READ_C_MX_PKG		: std_logic_Vector(1 DOWNTO 0):= "11";
	
	-- UFM 
	
	-- Device constants
	-- 10M02: (Take care, this device does not have a "CFM2" & a"CFM1"!)
	CONSTANT M02_UFM1_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M02_UFM1_End_C_MX_PKG			: natural :=	16#5FF#;
	CONSTANT M02_UFM0_Start_C_MX_PKG		: natural :=	16#600#;
	CONSTANT M02_UFM0_End_C_MX_PKG			: natural :=	16#BFF#;
	CONSTANT M02_CFM2_Start_C_MX_PKG		: natural :=	16#0#;-- dummy
	CONSTANT M02_CFM2_End_C_MX_PKG			: natural :=	16#0#;-- dummy
	CONSTANT M02_CFM1_Start_C_MX_PKG		: natural :=	16#0#;-- dummy
	CONSTANT M02_CFM1_End_C_MX_PKG			: natural :=	16#0#;-- dummy
	CONSTANT M02_CFM0_Start_C_MX_PKG		: natural :=	16#C00#;
	CONSTANT M02_CFM0_End_C_MX_PKG			: natural :=	16#4FFF#;
	CONSTANT M02_User_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M02_User_End_C_MX_PKG			: natural :=	16#9FF#;
	CONSTANT M02_MAN_Start_C_MX_PKG			: natural :=	16#A00#;
	CONSTANT M02_MAN_End_C_MX_PKG			: natural :=	16#BFF#;
	
	-- 10M04: (Take care, this device does not have an "UFM1"!)
	CONSTANT M04_UFM1_Start_C_MX_PKG		: natural :=	16#0#;-- dummy
	CONSTANT M04_UFM1_End_C_MX_PKG			: natural :=	16#0#;-- dummy
	CONSTANT M04_UFM0_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M04_UFM0_End_C_MX_PKG			: natural :=	16#FFF#;
	CONSTANT M04_CFM2_Start_C_MX_PKG		: natural :=	16#1000#;
	CONSTANT M04_CFM2_End_C_MX_PKG			: natural :=	16#61FF#;
	CONSTANT M04_CFM1_Start_C_MX_PKG		: natural :=	16#6200#;
	CONSTANT M04_CFM1_End_C_MX_PKG			: natural :=	16#9BFF#;
	CONSTANT M04_CFM0_Start_C_MX_PKG		: natural :=	16#9C00#;
	CONSTANT M04_CFM0_End_C_MX_PKG			: natural :=	16#127FF#;
	CONSTANT M04_User_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M04_User_End_C_MX_PKG			: natural :=	16#DFF#;
	CONSTANT M04_MAN_Start_C_MX_PKG			: natural :=	16#E00#;
	CONSTANT M04_MAN_End_C_MX_PKG			: natural :=	16#FFF#;
	
	-- 10M08:
	CONSTANT M08_UFM1_Start_C_MX_PKG		: natural :=	16#0#; -- 32Bit	-> 8Bit: 16#0#
	CONSTANT M08_UFM1_End_C_MX_PKG			: natural :=	16#FFF#;	-- 32Bit -> 8Bit: 16#3FFF#
	CONSTANT M08_UFM0_Start_C_MX_PKG		: natural :=	16#1000#; -- 32Bit -> 8Bit: 16#4000#
	CONSTANT M08_UFM0_End_C_MX_PKG			: natural :=	16#1FFF#; -- 32Bit -> 8Bit: 16#7FFF#
	CONSTANT M08_CFM2_Start_C_MX_PKG		: natural :=	16#2000#; -- 32Bit -> 8Bit: 16#8000#
	CONSTANT M08_CFM2_End_C_MX_PKG			: natural :=	16#71FF#; -- 32Bit	-> 8Bit: 16#1C7FF#
	CONSTANT M08_CFM1_Start_C_MX_PKG		: natural :=	16#7200#; -- 32Bit -> 8Bit: 16#1C800#
	CONSTANT M08_CFM1_End_C_MX_PKG			: natural :=	16#ABFF#; -- 32Bit -> 8Bit: 16#2AFFF#
	CONSTANT M08_CFM0_Start_C_MX_PKG		: natural :=	16#AC00#; -- 32Bit -> 8Bit: 16#2B000#
	CONSTANT M08_CFM0_End_C_MX_PKG			: natural :=	16#137FF#; -- 32Bit-> 8Bit: 16#4DFFF#
	CONSTANT M08_User_Start_C_MX_PKG		: natural :=	16#0#; -- 32Bit -> 8Bit: 16#0#
	CONSTANT M08_User_End_C_MX_PKG			: natural :=	16#1DFF#; -- 32Bit -> 8Bit: 16#77FF#
	CONSTANT M08_MAN_Start_C_MX_PKG			: natural :=	16#1E00#; -- 32Bit -> 8Bit: 16#7800#
	CONSTANT M08_MAN_End_C_MX_PKG			: natural :=	16#1FFF#; -- 32Bit -> 8Bit: 16#7FFF#
	
	-- 10M16:
	CONSTANT M16_UFM1_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M16_UFM1_End_C_MX_PKG			: natural :=	16#FFF#;
	CONSTANT M16_UFM0_Start_C_MX_PKG		: natural :=	16#1000#;
	CONSTANT M16_UFM0_End_C_MX_PKG			: natural :=	16#1FFF#;
	CONSTANT M16_CFM2_Start_C_MX_PKG		: natural :=	16#2000#;
	CONSTANT M16_CFM2_End_C_MX_PKG			: natural :=	16#B7FF#;
	CONSTANT M16_CFM1_Start_C_MX_PKG		: natural :=	16#B800#;
	CONSTANT M16_CFM1_End_C_MX_PKG			: natural :=	16#127FF#;
	CONSTANT M16_CFM0_Start_C_MX_PKG		: natural :=	16#12800#;
	CONSTANT M16_CFM0_End_C_MX_PKG			: natural :=	16#22FFF#;
	CONSTANT M16_User_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M16_User_End_C_MX_PKG			: natural :=	16#1DFF#;
	CONSTANT M16_MAN_Start_C_MX_PKG			: natural :=	16#1E00#;
	CONSTANT M16_MAN_End_C_MX_PKG			: natural :=	16#1FFF#;
	
	-- 10M25:
	CONSTANT M25_UFM1_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M25_UFM1_End_C_MX_PKG			: natural :=	16#FFF#;
	CONSTANT M25_UFM0_Start_C_MX_PKG		: natural :=	16#1000#;
	CONSTANT M25_UFM0_End_C_MX_PKG			: natural :=	16#1FFF#;
	CONSTANT M25_CFM2_Start_C_MX_PKG		: natural :=	16#2000#;
	CONSTANT M25_CFM2_End_C_MX_PKG			: natural :=	16#EFFF#;
	CONSTANT M25_CFM1_Start_C_MX_PKG		: natural :=	16#F000#;
	CONSTANT M25_CFM1_End_C_MX_PKG			: natural :=	16#18FFF#;
	CONSTANT M25_CFM0_Start_C_MX_PKG		: natural :=	16#19000#;
	CONSTANT M25_CFM0_End_C_MX_PKG			: natural :=	16#2FFFF#;
	CONSTANT M25_User_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M25_User_End_C_MX_PKG			: natural :=	16#1DFF#;
	CONSTANT M25_MAN_Start_C_MX_PKG			: natural :=	16#1E00#;
	CONSTANT M25_MAN_End_C_MX_PKG			: natural :=	16#1FFF#;
	
	-- 10M40:
	CONSTANT M40_UFM1_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M40_UFM1_End_C_MX_PKG			: natural :=	16#1FFF#;
	CONSTANT M40_UFM0_Start_C_MX_PKG		: natural :=	16#2000#;
	CONSTANT M40_UFM0_End_C_MX_PKG			: natural :=	16#3FFF#;
	CONSTANT M40_CFM2_Start_C_MX_PKG		: natural :=	16#4000#;
	CONSTANT M40_CFM2_End_C_MX_PKG			: natural :=	16#1BFFF#;
	CONSTANT M40_CFM1_Start_C_MX_PKG		: natural :=	16#1C000#;
	CONSTANT M40_CFM1_End_C_MX_PKG			: natural :=	16#2DFFF#;
	CONSTANT M40_CFM0_Start_C_MX_PKG		: natural :=	16#2E000#;
	CONSTANT M40_CFM0_End_C_MX_PKG			: natural :=	16#57FFF#;
	CONSTANT M40_User_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M40_User_End_C_MX_PKG			: natural :=	16#3DFF#;
	CONSTANT M40_MAN_Start_C_MX_PKG			: natural :=	16#3E00#;
	CONSTANT M40_MAN_End_C_MX_PKG			: natural :=	16#3FFF#;
	
	-- 10M50:
	CONSTANT M50_UFM1_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M50_UFM1_End_C_MX_PKG			: natural :=	16#1FFF#;
	CONSTANT M50_UFM0_Start_C_MX_PKG		: natural :=	16#2000#;
	CONSTANT M50_UFM0_End_C_MX_PKG			: natural :=	16#3FFF#;
	CONSTANT M50_CFM2_Start_C_MX_PKG		: natural :=	16#4000#;
	CONSTANT M50_CFM2_End_C_MX_PKG			: natural :=	16#1BFFF#;
	CONSTANT M50_CFM1_Start_C_MX_PKG		: natural :=	16#1C000#;
	CONSTANT M50_CFM1_End_C_MX_PKG			: natural :=	16#2DFFF#;
	CONSTANT M50_CFM0_Start_C_MX_PKG		: natural :=	16#2E000#;
	CONSTANT M50_CFM0_End_C_MX_PKG			: natural :=	16#57FFF#;
	CONSTANT M50_User_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT M50_User_End_C_MX_PKG			: natural :=	16#3DFF#;
	CONSTANT M50_MAN_Start_C_MX_PKG			: natural :=	16#3E00#;
	CONSTANT M50_MAN_End_C_MX_PKG			: natural :=	16#3FFF#;
	
	-- 10Mxy: Virtual device, can be used for testing...
	CONSTANT Mxy_UFM1_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT Mxy_UFM1_End_C_MX_PKG			: natural :=	16#0#;
	CONSTANT Mxy_UFM0_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT Mxy_UFM0_End_C_MX_PKG			: natural :=	16#0#;
	CONSTANT Mxy_CFM2_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT Mxy_CFM2_End_C_MX_PKG			: natural :=	16#0#;
	CONSTANT Mxy_CFM1_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT Mxy_CFM1_End_C_MX_PKG			: natural :=	16#0#;
	CONSTANT Mxy_CFM0_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT Mxy_CFM0_End_C_MX_PKG			: natural :=	16#0#;
	CONSTANT Mxy_User_Start_C_MX_PKG		: natural :=	16#0#;
	CONSTANT Mxy_User_End_C_MX_PKG			: natural :=	16#0#;
	CONSTANT Mxy_MAN_Start_C_MX_PKG			: natural :=	16#0#;
	CONSTANT Mxy_MAN_End_C_MX_PKG			: natural :=	16#0#;
	
	--	MAX10 family constants
	CONSTANT MX_UFM1_Start_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_UFM1_Start_C_MX_PKG,M04_UFM1_Start_C_MX_PKG,M08_UFM1_Start_C_MX_PKG,M16_UFM1_Start_C_MX_PKG,M25_UFM1_Start_C_MX_PKG,M40_UFM1_Start_C_MX_PKG,M50_UFM1_Start_C_MX_PKG,Mxy_UFM1_Start_C_MX_PKG);
	CONSTANT MX_UFM1_End_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_UFM1_End_C_MX_PKG,M04_UFM1_End_C_MX_PKG,M08_UFM1_End_C_MX_PKG,M16_UFM1_End_C_MX_PKG,M25_UFM1_End_C_MX_PKG,M40_UFM1_End_C_MX_PKG,M50_UFM1_End_C_MX_PKG,Mxy_UFM1_End_C_MX_PKG);
	CONSTANT MX_UFM0_Start_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_UFM0_Start_C_MX_PKG,M04_UFM0_Start_C_MX_PKG,M08_UFM0_Start_C_MX_PKG,M16_UFM0_Start_C_MX_PKG,M25_UFM0_Start_C_MX_PKG,M40_UFM0_Start_C_MX_PKG,M50_UFM0_Start_C_MX_PKG,Mxy_UFM0_Start_C_MX_PKG);
	CONSTANT MX_UFM0_End_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_UFM0_End_C_MX_PKG,M04_UFM0_End_C_MX_PKG,M08_UFM0_End_C_MX_PKG,M16_UFM0_End_C_MX_PKG,M25_UFM0_End_C_MX_PKG,M40_UFM0_End_C_MX_PKG,M50_UFM0_End_C_MX_PKG,Mxy_UFM0_End_C_MX_PKG);
	CONSTANT MX_CFM2_Start_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_CFM2_Start_C_MX_PKG,M04_CFM2_Start_C_MX_PKG,M08_CFM2_Start_C_MX_PKG,M16_CFM2_Start_C_MX_PKG,M25_CFM2_Start_C_MX_PKG,M40_CFM2_Start_C_MX_PKG,M50_CFM2_Start_C_MX_PKG,Mxy_CFM2_Start_C_MX_PKG);
	CONSTANT MX_CFM2_End_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_CFM2_End_C_MX_PKG,M04_CFM2_End_C_MX_PKG,M08_CFM2_End_C_MX_PKG,M16_CFM2_End_C_MX_PKG,M25_CFM2_End_C_MX_PKG,M40_CFM2_End_C_MX_PKG,M50_CFM2_End_C_MX_PKG,Mxy_CFM2_End_C_MX_PKG);
	CONSTANT MX_CFM1_Start_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_CFM1_Start_C_MX_PKG,M04_CFM1_Start_C_MX_PKG,M08_CFM1_Start_C_MX_PKG,M16_CFM1_Start_C_MX_PKG,M25_CFM1_Start_C_MX_PKG,M40_CFM1_Start_C_MX_PKG,M50_CFM1_Start_C_MX_PKG,Mxy_CFM1_Start_C_MX_PKG);
	CONSTANT MX_CFM1_End_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_CFM1_End_C_MX_PKG,M04_CFM1_End_C_MX_PKG,M08_CFM1_End_C_MX_PKG,M16_CFM1_End_C_MX_PKG,M25_CFM1_End_C_MX_PKG,M40_CFM1_End_C_MX_PKG,M50_CFM1_End_C_MX_PKG,Mxy_CFM1_End_C_MX_PKG);
	CONSTANT MX_CFM0_Start_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_CFM0_Start_C_MX_PKG,M04_CFM0_Start_C_MX_PKG,M08_CFM0_Start_C_MX_PKG,M16_CFM0_Start_C_MX_PKG,M25_CFM0_Start_C_MX_PKG,M40_CFM0_Start_C_MX_PKG,M50_CFM0_Start_C_MX_PKG,Mxy_CFM0_Start_C_MX_PKG);
	CONSTANT MX_CFM0_End_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_CFM0_End_C_MX_PKG,M04_CFM0_End_C_MX_PKG,M08_CFM0_End_C_MX_PKG,M16_CFM0_End_C_MX_PKG,M25_CFM0_End_C_MX_PKG,M40_CFM0_End_C_MX_PKG,M50_CFM0_End_C_MX_PKG,Mxy_CFM0_End_C_MX_PKG);
	CONSTANT MX_User_Start_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_User_Start_C_MX_PKG,M04_User_Start_C_MX_PKG,M08_User_Start_C_MX_PKG,M16_User_Start_C_MX_PKG,M25_User_Start_C_MX_PKG,M40_User_Start_C_MX_PKG,M50_User_Start_C_MX_PKG,Mxy_User_Start_C_MX_PKG);
	CONSTANT MX_User_End_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_User_End_C_MX_PKG,M04_User_End_C_MX_PKG,M08_User_End_C_MX_PKG,M16_User_End_C_MX_PKG,M25_User_End_C_MX_PKG,M40_User_End_C_MX_PKG,M50_User_End_C_MX_PKG,Mxy_User_End_C_MX_PKG);
	CONSTANT MX_Man_Start_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_MAN_Start_C_MX_PKG,M04_MAN_Start_C_MX_PKG,M08_MAN_Start_C_MX_PKG,M16_MAN_Start_C_MX_PKG,M25_MAN_Start_C_MX_PKG,M40_MAN_Start_C_MX_PKG,M50_MAN_Start_C_MX_PKG,Mxy_MAN_Start_C_MX_PKG);
	CONSTANT MX_Man_End_C_MX_PKG			: mx_xfm_range_t_mx_pkg	:= (M02_MAN_End_C_MX_PKG,M04_MAN_End_C_MX_PKG,M08_MAN_End_C_MX_PKG,M16_MAN_End_C_MX_PKG,M25_MAN_End_C_MX_PKG,M40_MAN_End_C_MX_PKG,M50_MAN_End_C_MX_PKG,Mxy_MAN_End_C_MX_PKG);
	---------------------------
   -- Constant Declaration END
   ---------------------------


   -------------------
   -- Type Declaration
   -------------------
	TYPE ufm_csr_port_bundle_t_mx_pkg						IS RECORD
																AD									:	std_logic;
																RD									:	std_logic;
																WR_Data								:	std_logic_vector(31 DOWNTO 0);
																WR									:	std_logic;
																RD_Data								:	std_logic_vector(31 DOWNTO 0);
															END RECORD ufm_csr_port_bundle_t_mx_pkg;
																
	TYPE ufm_data_port_bundle_t_mx_pkg						IS RECORD
																AD									:	std_logic_vector(16 DOWNTO 0);
																RD									:	std_logic;
																WR_Data								:	std_logic_vector(31 DOWNTO 0);
																WR									:	std_logic;
																RD_Data								:	std_logic_vector(31 DOWNTO 0);
																Wait_RQ								:	std_logic;
																RD_Data_VD							:	std_logic;
																Burst_Count							:	std_logic_Vector(7 DOWNTO 0);
															END RECORD ufm_data_port_bundle_t_mx_pkg;
														
	-- xFM flash ranges (UFM, CFM) of MAX10 devices. Take care: The addresses are 32Bit addresses as used by the IP core! 												
	TYPE xfm_ranges_bundle_t_mx_pkg							IS RECORD
																UFM1_Start							:	natural	RANGE 0 TO 16#1FFFF#;
																UFM1_End							:	natural	RANGE 0 TO 16#1FFFF#;
																UFM0_Start							:	natural	RANGE 0 TO 16#1FFFF#;
																UFM0_End							:	natural	RANGE 0 TO 16#1FFFF#;
																CFM2_Start							:	natural	RANGE 0 TO 16#1FFFF#;
																CFM2_End							:	natural	RANGE 0 TO 16#1FFFF#;
																CFM1_Start							:	natural	RANGE 0 TO 16#1FFFF#;
																CFM1_End							:	natural	RANGE 0 TO 16#1FFFF#;
																CFM0_Start							:	natural	RANGE 0 TO 16#1FFFF#;
																CFM0_End							:	natural	RANGE 0 TO 16#1FFFF#;
																MAN_Start							:	natural	RANGE 0 TO 16#1FFFF#;
																MAN_END								:	natural	RANGE 0 TO 16#1FFFF#;
																RAM_Start							:	natural	RANGE 0 TO 16#1FFFF#;
																RAM_END								:	natural	RANGE 0 TO 16#1FFFF#;
																Emergency_Start						:	natural	RANGE 0 TO 16#1FFFF#;
																Emergency_End						:	natural	RANGE 0 TO 16#1FFFF#;
																Standard_Start						:	natural	RANGE 0 TO 16#1FFFF#;
																Standard_End						:	natural	RANGE 0 TO 16#1FFFF#;
																User_Start							:	natural	RANGE 0 TO 16#1FFFF#;
																User_End							:	natural	RANGE 0 TO 16#1FFFF#;
															END RECORD xfm_ranges_bundle_t_mx_pkg;
														
	TYPE max10_settings_bundle_t_mx_pkg						IS RECORD
																Device								:	natural	RANGE 0 TO 7; -- 0 = M02, 1 = M04, 2 = M08, 3 = M16, 4 = M25, 5 = M40, 6 = M50, 7 = not defined (see defined constants, too).
																Boot_Mode							:	natural	RANGE 0 TO 1; -- 0 = single Configuration, 1 = dual Configuration
																MFD_EN								:	natural	RANGE 0 TO 1; -- 0 = no manufacturing data saved in the flash, 1 = use the flash for manufacturing data, too.
																RAM_Loader_EN						:	natural	RANGE 0 TO 1; -- 0 = no user RAM loading in dual boot mode, 1 = RAM loading in dual boot mode active.
																RAM_Size							:	natural	RANGE	0 TO 16#3DFF#; -- Number of 32Bit words that have to be loaded from flash into user RAM's for initialization.
															END RECORD max10_settings_bundle_t_mx_pkg;
														
	TYPE max10_status_bundle_t_mx_pkg						IS RECORD
																Existent_Sectors					:	std_logic_vector(4 DOWNTO 0); -- (CFM0 & CFM1 & CFM2 & UFM0 & UFM1)
																Existent_User_Spaces				:	std_logic_vector(4 DOWNTO 0); -- (AUX_Firmware, Standard_Firmware, Manufacturing_Data, RAM_Loader, User_Space)?????
															END RECORD max10_status_bundle_t_mx_pkg;
	
	TYPE max10_setup_bundle_t_mx_pkg						IS RECORD
																Ranges								:	xfm_ranges_bundle_t_mx_pkg;
																Status								:	max10_status_bundle_t_mx_pkg;
															END RECORD max10_setup_bundle_t_mx_pkg;
														
	TYPE max10_range_access_bundle_t_mx_pkg	IS RECORD
																Range_Start							:	natural	RANGE 0 TO 16#1FFFF#;
																Range_End							:	natural	RANGE 0 TO 16#1FFFF#;
																CSR_Unprotected						:	std_logic_vector(4 DOWNTO 0);
																CSR_Erase_Sel						:	std_logic_vector(2 DOWNTO 0);
															END RECORD max10_range_access_bundle_t_mx_pkg;
   -----------------------
   -- Type Declaration END
   -----------------------
	
	------------------------------------------
	-- Constant Declaration with defined Types
   ------------------------------------------
	CONSTANT	NA_MAX10_RANGE_Selected_BUNDLE_C_MX_PKG		: max10_range_access_bundle_t_mx_pkg:= (0,0,No_CSR_Unprotected_C_MX_PKG,None_CSR_Erase_Sel_C_MX_PKG);
	----------------------------------------------
	-- Constant Declaration with defined Types END
	----------------------------------------------
	
   
	-----------------------
	--	Function Declaration
	-----------------------
	FUNCTION Setup_MAX10_F_MX_PKG(Settings: max10_settings_bundle_t_mx_pkg) RETURN max10_setup_bundle_t_mx_pkg;
	FUNCTION	Setup_MAX10_Range_Access_F_MX_PKG(Flash_Range: natural RANGE 0 TO 7; Device:max10_setup_bundle_t_mx_pkg) RETURN max10_range_access_bundle_t_mx_pkg;
	---------------------------
	-- Function Declaration END
	---------------------------

END PACKAGE MAX10_Package;


PACKAGE BODY MAX10_Package IS
	
	-- With the help of this function and the parameters chosen by the user, we set-up the MAX10 device...
	------------------------------
	-- Choosing the MAX10 settings
	------------------------------
	FUNCTION Setup_MAX10_F_MX_PKG(Settings: max10_settings_bundle_t_mx_pkg) RETURN max10_setup_bundle_t_mx_pkg IS
		VARIABLE	Result	:	max10_setup_bundle_t_mx_pkg;
		VARIABLE	MFD_EN	:	std_logic;
		VARIABLE	RAM_EN	:	std_logic;
		VARIABLE DBoot_EN	:	std_logic;
	BEGIN
				-- Concurrent 0, device constant selection based on user parameters.
				-- These constants are always defined for each device.- However the size can be zero...
				Result.Ranges.UFM1_Start 		:= 	MX_UFM1_Start_C_MX_PKG(Settings.Device);
				Result.Ranges.UFM1_END 			:= 	MX_UFM1_End_C_MX_PKG(Settings.Device);
				Result.Ranges.UFM0_Start		:=	MX_UFM0_Start_C_MX_PKG(Settings.Device);
				Result.Ranges.UFM0_End			:=	MX_UFM0_End_C_MX_PKG(Settings.Device);
				Result.Ranges.CFM2_Start		:=	MX_CFM2_Start_C_MX_PKG(Settings.Device);
				Result.Ranges.CFM2_End			:=	MX_CFM2_End_C_MX_PKG(Settings.Device);
				Result.Ranges.CFM1_Start		:=	MX_CFM1_Start_C_MX_PKG(Settings.Device);
				Result.Ranges.CFM1_End			:=	MX_CFM1_End_C_MX_PKG(Settings.Device);
				Result.Ranges.CFM0_Start		:=	MX_CFM0_Start_C_MX_PKG(Settings.Device);
				Result.Ranges.CFM0_End			:=	MX_CFM0_End_C_MX_PKG(Settings.Device);
				Result.Ranges.MAN_Start			:=	MX_Man_Start_C_MX_PKG(Settings.Device);
				Result.Ranges.MAN_END			:= 	MX_Man_End_C_MX_PKG(Settings.Device);
				
				-- Concurrent 1
				IF (Settings.MFD_EN = 1) THEN
					MFD_EN	:= '1';
				ELSE
					MFD_EN	:= '0';
				END IF;
				
				IF (Settings.RAM_Loader_EN = 1) THEN
					RAM_EN	:= '1';
				ELSE
					RAM_EN	:= '0';
				END IF;
				
				IF (Settings.Boot_Mode = 1) THEN
					DBoot_EN	:=	'1';
				ELSE
					DBoot_EN	:=	'0';
				END IF;
				
				--
				-- if (dual = '1') AND (RAM_Loader = '1')...else range not defined => status bit

				IF ((Settings.Boot_Mode = 1) AND (Settings.RAM_Loader_EN = 1)) THEN
					Result.Ranges.RAM_Start := MX_User_Start_C_MX_PKG(Settings.Device);
					IF (Settings.RAM_Size <= (MX_User_END_C_MX_PKG(Settings.Device) - MX_User_Start_C_MX_PKG(Settings.Device))) THEN -- We do not allow to use the MAN range even if it is not used at all. Otherswise we could overwrite the manufacturing data. 
						Result.Ranges.RAM_END := Settings.RAM_Size;
					ELSE
						Result.Ranges.RAM_END := MX_User_END_C_MX_PKG(Settings.Device);
					END IF;
				ELSE
					Result.Ranges.RAM_Start := 16#0#;
					Result.Ranges.RAM_END := 16#0#;
				END IF;
				
				--
				-- if (dual = '1')...else range not defined => status bit
				Result.Ranges.Emergency_Start	:=	MX_CFM0_Start_C_MX_PKG(Settings.Device);
				Result.Ranges.Emergency_End	:=	MX_CFM0_End_C_MX_PKG(Settings.Device);
				--
				-- Always defined, however can be CFM2+CFM1 OR CFM0 based on Boot_Mode (dual = '1') OR (dual = '0')
				IF (Settings.Boot_Mode = 1) THEN
					Result.Ranges.Standard_Start	:=	MX_CFM2_Start_C_MX_PKG(Settings.Device);
					Result.Ranges.Standard_End		:=	MX_CFM1_End_C_MX_PKG(Settings.Device);
				ELSE
					-- No emergency system at all
					Result.Ranges.Standard_Start	:=	MX_CFM2_Start_C_MX_PKG(Settings.Device);
					Result.Ranges.Standard_End		:=	MX_CFM1_End_C_MX_PKG(Settings.Device);
				END IF;
				-- 
				-- Take care: User is ((UFM1 + UFM0)-MAN) OR ((UFM1 + UFM0)-MA-RAM)?????
				Result.Ranges.User_Start := MX_User_Start_C_MX_PKG(Settings.Device);
				Result.Ranges.User_End := MX_User_END_C_MX_PKG(Settings.Device);
				--
				--
				
				-- Which sectors exist in the device at all?
				IF (Settings.Device = M02_C_MX_PKG) THEN
					Result.Status.Existent_Sectors := "10011"; -- (CFM0 & CFM1 & CFM2 & UFM0 & UFM1)
				ELSIF (Settings.Device = M04_C_MX_PKG) THEN
					Result.Status.Existent_Sectors := "11110";
				ELSE
					Result.Status.Existent_Sectors := "11111";
				END IF;
				
				Result.Status.Existent_User_Spaces := (DBoot_EN & '1' & MFD_EN & RAM_EN & '1'); -- (AUX_Firmware, Standard_Firmware, Manufacturing_Data, RAM_Loader, User_Space)
				
				-- Return the MAX10 configuration...
				RETURN Result;
	END Setup_MAX10_F_MX_PKG;
	----------------------------------
	-- Choosing the MAX10 settings END
	----------------------------------
	
	
	----------------------------------------
	-- Configuring the actual range settings
	----------------------------------------
	FUNCTION	Setup_MAX10_Range_Access_F_MX_PKG(Flash_Range: natural RANGE 0 TO 7; Device: max10_setup_bundle_t_mx_pkg) RETURN max10_range_access_bundle_t_mx_pkg IS
		VARIABLE	Result	:	max10_range_access_bundle_t_mx_pkg;
	BEGIN
		CASE	Flash_Range	IS
			WHEN	0	=>	-- Not allowed
				Result.Range_Start			:= 16#0#;
				Result.Range_End			:= 16#0#;
				Result.CSR_Unprotected		:= No_CSR_Unprotected_C_MX_PKG;
				Result.CSR_Erase_Sel		:= None_CSR_Erase_Sel_C_MX_PKG;
			WHEN	1	=>	-- Auxiliary
				Result.Range_Start			:= Device.Ranges.Emergency_Start;
				Result.Range_End			:= Device.Ranges.Emergency_End;
				Result.CSR_Unprotected		:= CFM0_CSR_Unprotected_C_MX_PKG;
				Result.CSR_Erase_Sel		:= CFM0_CSR_Erase_Sel_C_MX_PKG;
			WHEN	2	=>	-- Standard
				Result.Range_Start			:= Device.Ranges.Standard_Start;
				Result.Range_End			:= Device.Ranges.Standard_End;
				IF (Device.Status.Existent_User_Spaces(4) = '1') THEN
					Result.CSR_Unprotected	:= CFM12_CSR_Unprotected_C_MX_PKG;
					Result.CSR_Erase_Sel	:= CFM2_CSR_Erase_Sel_C_MX_PKG; -- Attention!!!
				ELSE
					Result.CSR_Unprotected	:= CFM12_CSR_Unprotected_C_MX_PKG;
					Result.CSR_Erase_Sel	:= CFM2_CSR_Erase_Sel_C_MX_PKG; -- Attention!!!
				END IF;
			WHEN	3	=>	-- RAM 
				Result.Range_Start			:= Device.Ranges.RAM_Start;
				Result.Range_End			:= Device.Ranges.RAM_End;
				Result.CSR_Unprotected		:= No_CSR_Unprotected_C_MX_PKG;
				Result.CSR_Erase_Sel		:= None_CSR_Erase_Sel_C_MX_PKG;
			WHEN	4	=>	--	User 0
				IF (Device.Status.Existent_User_Spaces(2) = '1') THEN
					Result.Range_Start		:= Device.Ranges.UFM0_Start;
					Result.Range_End		:= Device.Ranges.UFM0_End;
					Result.CSR_Unprotected	:= No_CSR_Unprotected_C_MX_PKG;
					Result.CSR_Erase_Sel	:= None_CSR_Erase_Sel_C_MX_PKG;
				ELSE
					Result.Range_Start		:= Device.Ranges.UFM0_Start;
					Result.Range_End		:= Device.Ranges.UFM0_End;
					Result.CSR_Unprotected	:= UFM0_CSR_Unprotected_C_MX_PKG;
					Result.CSR_Erase_Sel	:= UFM0_CSR_Erase_Sel_C_MX_PKG;
				END IF;
			WHEN	5	=>	--	User 1
				Result.Range_Start			:= Device.Ranges.UFM1_Start;
				Result.Range_End			:= Device.Ranges.UFM1_End;
				Result.CSR_Unprotected		:= UFM1_CSR_Unprotected_C_MX_PKG;
				Result.CSR_Erase_Sel		:= UFM1_CSR_Erase_Sel_C_MX_PKG;
			WHEN	6	=>	--	Future Use
				Result.Range_Start			:= 16#0#;
				Result.Range_End			:= 16#0#;
				Result.CSR_Unprotected		:= No_CSR_Unprotected_C_MX_PKG;
				Result.CSR_Erase_Sel		:= None_CSR_Erase_Sel_C_MX_PKG;
			WHEN	7	=>	--	Manufacturing
				Result.Range_Start			:= Device.Ranges.MAN_Start;
				Result.Range_End			:= Device.Ranges.MAN_End;
				Result.CSR_Unprotected		:= UFM0_CSR_Unprotected_C_MX_PKG;
				Result.CSR_Erase_Sel		:= UFM0_CSR_Erase_Sel_C_MX_PKG;
			WHEN	OTHERS	=>
				NULL;
		END CASE;
		-- Return the settings for the actual range
		RETURN Result;
	END Setup_MAX10_Range_Access_F_MX_PKG;
	--------------------------------------------
	-- Configuring the actual range settings END
	--------------------------------------------
	
END PACKAGE BODY MAX10_Package;
