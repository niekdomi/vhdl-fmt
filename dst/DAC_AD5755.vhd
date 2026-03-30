---------------------------------------------------------------------------
--
--  DAC AD5755
--
---------------------------------------------------------------------------
--
--  project     : DAC AD5755
--  programmer  : F:Baschung, INDEL AG
--  date        : 24.01.2010
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- DAC AD5755
--
---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	11.01.2011-FB : - erste Version
--	22.06.2011-MS : - selectable int/ext resistors for the current outputs
--	27.07.2011-le : - synchron clr
--					- correct o_DAC_SDI(i)
--	29.07.2011-le : - set DC-DC bit on voltage ranges
--					- correct i_DAC_SDO(i)
--					- add svn keywords
--	02.08.2011-le : - use oddr to genearate clk
--	03.08.2011-le : - wait longer at power on
--					- DC-DC register must be the first
--------------------------------------------------------------------------------
--$Rev:: 2080                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2011-08-03 16:21:40 +0200 (Mi., 03 Aug 2011)                         $
--------------------------------------------------------------------------------
--
--	Fehlt noch:
--  
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library Unisim;
use Unisim.vcomponents.all;


entity DAC_AD5755 is 
	generic (
		NrOfDAC			: integer 	:= 1;
		IntCurRes		: std_logic := H 	--H: enabled internal current resistor's
											--L: enabled external current resistor's
	);
	port (              
		 i_CLK			: in	std_logic;
		 i_Reset		: in 	std_logic;

		 i_DAC_Init_Reg	: in 	std_logic;
		 i_DAC_SOC		: in 	std_logic;

		 i_DAC_Mode		: in	tSLV_NxNx4	(0 to NrOfDAC-1,0 to 3);
	     i_DAC_Value	: in	tSLV_NxNx16	(0 to NrOfDAC-1,0 to 3);
	     o_DAC_Status	: out	tSLV_Nx16	(0 to NrOfDAC-1);

		 -- DAC	AD5755
        no_DAC_Reset	: out	std_logic;                      
         o_DAC_Clear	: out	std_logic;                      
         o_DAC_SCLK 	: out	std_logic_vector(NrOfDAC-1 downto 0);
        no_DAC_Sync 	: out	std_logic;                     
         o_DAC_SDI	    : out	std_logic_vector(NrOfDAC-1 downto 0);                     
         i_DAC_SDO	    : in	std_logic_vector(NrOfDAC-1 downto 0)                     
    );
end DAC_AD5755;                                         

architecture impl of DAC_AD5755 is   
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------  
    constant H 				: std_logic	:= '1';
    constant L 				: std_logic	:= '0';
--------------------------------------------------------------------------------
	----------------------------------------------------------------------------	
	--	DAC
	----------------------------------------------------------------------------	
	signal 	DAC_Init_Seq	: integer 						:= 0;

	signal 	DAC_Ch	 		: std_logic_vector( 1 downto 0)	:= (others => '0');
	signal 	DAC_BitCnt 		: std_logic_vector( 7 downto 0)	:= (others => '0');

	type tSreg is array(0 to NrOfDAC-1) of std_logic_vector(23 downto 0);
	signal 	DAC_Sreg 		: tSreg;
	
	signal DAC_Init			: std_logic 					:= L;
	signal DAC_SOC			: std_logic 					:= L;
	signal DAC_ClkEn		: std_logic 					:= L;

	signal DAC_Reset		: std_logic 					:= L;
	signal DAC_SCLK			: std_logic 					:= L;
	signal DAC_Sync			: std_logic 					:= L;
	signal DAC_LDAC			: std_logic 					:= L;
	signal DAC_Clear		: std_logic 					:= L;

	-- 32 x 40ns = 1280ns 
	signal 	PowerOnTim 		: std_logic_vector( 4 downto 0)	:= (others => '1');

	signal 	DAC_SDO 		: std_logic_vector(NrOfDAC-1 downto 0)	:= (others => '0');
	
	signal nCLK				: std_logic;

	signal po_init			: std_logic := H;
	
    type sDACSeq is (
    	sIdle,sStart_Fast,sStart_Init,
    	sLoad_SR,sSynch,sShift,sWait,
    	sNext,
    	sEnd
	);	
	signal DACSeq: sDACSeq := sIdle;	    -- DAC-sequencer

	signal 	DAC_Status 	: tSLV_Nx16		(0 to NrOfDAC-1);       


--------------------------------------------------------------------------------	
	type		tCfgReg is array(0 to 15) of std_logic_vector(15 downto 0);
	constant	DAC_Ctr_Cfg		: tCfgReg := (
					--        I CORD OMMM
					b"0100_0000_0000_0000",						-- 0	disabled 
					b"0100_0000_10"& IntCurRes & b"1_0101",		-- 1	0..20mA  
					b"0100_0000_10"& IntCurRes & b"1_0110",		-- 2	0..24mA  
					b"0100_0000_10"& IntCurRes & b"1_0100",		-- 3	4..20mA  
					b"0100_0000_1001_0000",						-- 4	0..5V    
					b"0100_0000_1001_1000",						-- 5	0..6V    
					b"0100_0000_1001_0001",						-- 6	0..10V   
					b"0100_0000_1001_1001",						-- 7	0..12V   
					b"0100_0000_1001_0010",						-- 8	+- 5V    
					b"0100_0000_1001_1010",						-- 9	+- 6V    
					b"0100_0000_1001_0011",						-- 10	+- 10V   
					b"0100_0000_1001_1011",						-- 11	+- 12V
					b"0100_0000_0000_0000",						-- 12	disabled 
					b"0100_0000_0000_0000",						-- 13	disabled 
					b"0100_0000_0000_0000",						-- 14	disabled 
					b"0100_0000_0000_0000" 						-- 15	disabled 
				);	
	
--------------------------------------------------------------------------------	

begin

--******************************************************************************	               
--
--	DAC AD5755
--
--******************************************************************************	               

--------------------------------------------------------------------------------
--	In/Outs
--------------------------------------------------------------------------------
	 o_DAC_Status  <= 		DAC_Status;
	no_DAC_Reset   <= not	DAC_Reset;
	 o_DAC_Clear   <= 		DAC_Clear; 
	no_DAC_Sync    <= not	DAC_Sync;
	
	DAC_SDO		<= i_DAC_SDO;
	
	sdi_loop : for i in 0 to NrOfDAC-1 generate begin
		o_DAC_SDI(i) <= DAC_Sreg(i)(23);
	end generate sdi_loop;

--------------------------------------------------------------------------------
--	Power-ON reset
--------------------------------------------------------------------------------
	process(i_CLK) begin
		if rising_edge(i_CLK) then 
            DAC_Reset <= L;
			if (PowerOnTim > 0) then 
				DAC_Reset <= H;
			
				if (PowerOnTim = 1) then
					DAC_Init <= H;	
				end if;	 
				
                PowerOnTim <= PowerOnTim - 1;
            end if;    
			
			-- latch external DAC_Init_Req
			if (i_DAC_Init_Reg = H) then
				DAC_Init <= H;	
			end if;
            
	        if (DAC_Init_Seq > 0) then
				DAC_Init <= L;
			end if;    
            

		end if;
	end process;
                  
                  
--------------------------------------------------------------------------------
--	DAC write sequence
--------------------------------------------------------------------------------
	
	nCLK <= not i_CLK;
	

	clk_loop : for i in 0 to NrOfDAC-1 generate begin
		-- spartan6 ddr output
		inst_DAC_SCLK : ODDR2
		generic map(
			--DDR_CLK_EDGE => "SAME_EDGE",-- "OPPOSITE_EDGE" or "SAME_EDGE" 
			DDR_ALIGNMENT => "NONE",
			INIT => '0',		-- Initial value for Q port ('1' or '0')
			SRTYPE => "SYNC")	-- Reset Type ("ASYNC" or "SYNC")
		port map (
			Q  => o_DAC_SCLK(i),-- DDR output
			C0 => i_CLK,		-- clock input
			C1 => nCLK,			-- clock input
			CE => DAC_ClkEn,	-- clock enable input
			D0 => H,			-- data input (positive edge)
			D1 => L,			-- data input (negative edge)
			R  => L,			-- reset input
			S  => L				-- set input
		);
	end generate clk_loop;
	
	process(i_CLK) begin  
		if rising_edge(i_CLK) then
			DAC_BitCnt	<= x"00";
			DAC_ClkEn 	<= L;
			DAC_Sync 	<= L;
			DAC_Clear <= i_Reset;
   
			--------------------------------------------------------------------
			case DACSeq is  
			--------------------------------------------------------------------
			--	wait to DAC_SOC
			--------------------------------------------------------------------
			when sIdle =>   
				DAC_Ch <="00";   
				
				if (DAC_Init_Seq > 0) then
					DACSeq <= sStart_Init;
				elsif (DAC_Init = H) then
					DAC_Init_Seq <= 8;
				elsif (i_DAC_SOC = H)  then
					DACSeq <= sStart_Fast;
				end if;               
		
			--------------------------------------------------------------------
			--	start DAC-INIT
			--------------------------------------------------------------------
			when sStart_Init =>
			  for i in 0 to NrOfDAC-1 loop
			   
			  	case DAC_Init_Seq is
			  	when 8 =>                                                      
					-- Status Register (noop, read only)    (one only, DAC_Ch=0)
					-- write to Main-Controll-Register 		(one only, DAC_Ch=1)
					-- write to DC-DC-Controll-Register  	(one only, DAC_Ch=2)
					-- noop									(one only, DAC_Ch=3)
					-- DC-DC must be the first
					DAC_Sreg(i)(23 downto 16) <= b"000_111" & DAC_Ch;
					case DAC_Ch is 
					when "10" =>	-- MAIN
						DAC_Sreg(i)(23 downto 16) <= b"000_111" & "01";
						DAC_Sreg(i)(15 downto  0) <= b"001_0_1000_0000_0000";
					when "01" =>	-- DC-DC
						DAC_Sreg(i)(23 downto 16) <= b"000_111" & "10";
						DAC_Sreg(i)(15 downto  0) <= b"011_0000000_11_00_00";
					when others => null; 
					end case;

				when 7 =>   -- write to Slew-Rate-Controll-Register
					DAC_Sreg(i)(23 downto 16) <= b"000_111" & DAC_Ch;
					DAC_Sreg(i)(15 downto  0) <= b"000_0_0000_0000_0000";
					
				when 6 =>	-- write to DAC-Control-Register	(Ch_Disabled)
					DAC_Sreg(i)(23 downto 16) <= b"000_111" & DAC_Ch;
					DAC_Sreg(i)(15 downto  0) <= DAC_Ctr_Cfg(CONV_INTEGER(i_DAC_Mode(i,CONV_INTEGER(DAC_Ch))));
					if (i_DAC_Mode(i,CONV_INTEGER(DAC_Ch)) > 0) then
						DAC_Sreg(i)(8) <= H;	-- set INT_ENABLE
					end if;
					
				when 5 =>	-- write to DAC-Gain-Register
					DAC_Sreg(i)(23 downto 16) <= b"000_010" & DAC_Ch;
					DAC_Sreg(i)(15 downto  0) <= b"1111_1111_1111_1111";
					
				when 4 =>   -- write to DAC-Offset-Register
					DAC_Sreg(i)(23 downto 16) <= b"000_100" & DAC_Ch;
					DAC_Sreg(i)(15 downto  0) <= b"1000_0000_0000_0000";

				when 3 =>	-- write to DAC-ClearCode-Register
					DAC_Sreg(i)(23 downto 16) <= b"000_110" & DAC_Ch;
					case i_DAC_Mode(i,CONV_INTEGER(DAC_Ch)) is 
					when x"0" 		-- disabled
						|x"1" 		-- 0..20mA
						|x"2" 		-- 0..24mA
						|x"3" =>	-- 4..20mA
						DAC_Sreg(i)(15 downto  0) <= b"0000_0000_0000_0000";
						
					when x"4" 		-- 0..5V
						|x"5" 		-- 0..6V
						|x"6" 		-- 0..10V 
						|x"7" =>	-- 0..12V 
						DAC_Sreg(i)(15 downto  0) <= b"0000_0000_0000_0000";
						
					when x"8"		-- +- 5V 
						|x"9"		-- +- 6V
						|x"A"		-- +- 10V
						|x"B" =>	-- +- 12V
						DAC_Sreg(i)(15 downto  0) <= b"1000_0000_0000_0000";

					when others => 	-- disabled 
						DAC_Sreg(i)(15 downto  0) <= b"0000_0000_0000_0000";
					end case; 
					
				when 2 => 	-- write to DAC-Register
					DAC_Sreg(i)(23 downto 16) <= b"000_000" & DAC_Ch;
					case i_DAC_Mode(i,CONV_INTEGER(DAC_Ch)) is 
					when x"0" 		-- disabled
						|x"1" 		-- 0..20mA
						|x"2" 		-- 0..24mA
						|x"3" =>	-- 4..20mA
						DAC_Sreg(i)(15 downto  0) <= b"0000_0000_0000_0000";
						
					when x"4" 		-- 0..5V
						|x"5" 		-- 0..6V
						|x"6" 		-- 0..10V 
						|x"7" =>	-- 0..12V 
						DAC_Sreg(i)(15 downto  0) <= b"0000_0000_0000_0000";
						
					when x"8" 		-- +- 5V 
						|x"9" 		-- +- 6V
						|x"A" 		-- +- 10V
						|x"B" =>	-- +- 12V
						DAC_Sreg(i)(15 downto  0) <= b"1000_0000_0000_0000";

					when others => 	-- disabled 
						DAC_Sreg(i)(15 downto  0) <= b"0000_0000_0000_0000";
					end case; 
				when 1 =>
					-- write to DAC-Control-Register
					DAC_Sreg(i)(23 downto 16) <= b"000_111" & DAC_Ch;
					DAC_Sreg(i)(15 downto  0) <= DAC_Ctr_Cfg(CONV_INTEGER(i_DAC_Mode(i,CONV_INTEGER(DAC_Ch))));
					
					if (i_DAC_Mode(i,CONV_INTEGER(DAC_Ch)) > 0) then
						DAC_Sreg(i)(8) <= H;	-- set INT_ENABLE
						DAC_Sreg(i)(6) <= H;	-- set OUTEN
					end if;
					
				when others => null; 
				end case;
			  end loop;
			    
			    -- skip Status and noop Controll-Reg 
				if (po_init = H) then
					-- wait longer at power on
					DACSeq <= sWait;
				elsif (DAC_Init_Seq = 8) and (DAC_Ch = 0) then 
					-- wait 5us after reset
					DACSeq <= sWait;
				elsif (DAC_Init_Seq = 8) and (DAC_Ch = 3) then
					DACSeq <= sNext;
				else
					DAC_Sync  <= H;
					DAC_ClkEn <= H;
					DACSeq <= sShift;
				end if;	
							
			--------------------------------------------------------------------
			--	start DAC-Out
			--------------------------------------------------------------------
			when sStart_Fast =>    
			  for i in 0 to NrOfDAC-1 loop
				DAC_Sreg(i)(23 downto 16) <= b"000_000" & DAC_Ch;
				-- unipolar or bipolar?
				if (i_DAC_Mode(i,CONV_INTEGER(DAC_Ch)) < x"8") then
					-- unipolar, 0V = x"0000"
					DAC_Sreg(i)(15 downto 0) <= i_DAC_Value(i,CONV_INTEGER(DAC_Ch));
				else
					-- bipolar, 0V = x"8000"
					DAC_Sreg(i)(15 downto 0) <= i_DAC_Value(i,CONV_INTEGER(DAC_Ch)) + x"8000";
				end if;	
			  end loop;
					
				DAC_Sync  <= H;
				DAC_ClkEn <= H;
				DACSeq <= sShift;

			--------------------------------------------------------------------
			--	shift data
			--------------------------------------------------------------------
			when sShift => 
			  for i in 0 to NrOfDAC-1 loop
			  	-- shift to output
				DAC_Sreg(i)   <= DAC_Sreg(i)(22 downto 0) & DAC_SDO(i);
				---- shift from input to Status   
				--DAC_Status(i) <= (DAC_Status(i)(14 downto 0)) & DAC_SDO(i); 
			  end loop;
				
	         	DAC_BitCnt <= DAC_BitCnt +1;

		        if (DAC_BitCnt < 23) then
					DAC_Sync <= DAC_Sync;
					DAC_ClkEn  <= H;
		        else		
		        	DAC_BitCnt <= x"00";
		        	DACSeq <= sWait;
		        	for i in 0 to NrOfDAC-1 loop
						-- shift from input to Status
						DAC_Status(i) <= (DAC_Sreg(i)(14 downto 0)) & DAC_SDO(i);
					end loop;
		        end if;

			--------------------------------------------------------------------
			--	pause	DAC needs at least 5us pause  	5000/40= 125
			--------------------------------------------------------------------
			when sWait => 
	         	DAC_BitCnt <= DAC_BitCnt +1;

		        if (DAC_BitCnt >= 125) then
		        	DACSeq <= sNext;
		        end if;

			--------------------------------------------------------------------
			--	next channel
			--------------------------------------------------------------------
			when sNext => 
				if (DAC_Init_Seq > 0) then 
					-- still Init
		        	DACSeq <= sStart_Init;
					if (DAC_Ch < 3) then  
			        else         
			        	-- init next DAC-Reg type       
						DAC_Init_Seq <= DAC_Init_Seq - 1;
			        end if;
			                       
				else
					if (DAC_Ch < 3) then  
			        	DACSeq <= sStart_Fast;
			        else
			        	DACSeq <= sIdle;
			        	po_init <= L;
			        	if (po_init = H) then
							-- repeat after power on, first init is onli a wait without data
			        		DAC_Init_Seq <= 8;
			        	end if;
			        end if;               
				end if;

				-- next DAC-channel  
				DAC_CH <= DAC_Ch + 1;
				
			--------------------------------------------------------------------
			when others => null; 
			end case;
			--------------------------------------------------------------------
		end if;
	end process;					


--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
