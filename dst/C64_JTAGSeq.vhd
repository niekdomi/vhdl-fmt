---------------------------------------------------------------------------
--
--  C64 JTAG Sequencer
--
---------------------------------------------------------------------------
--
--  project     : C64_BusMaster
--  programmer  : F:Baschung, INDEL AG
--  date        : 23.06.2010
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- JTAG Loader 
--
---------------------------------------------------------------------------
--
--	Fehlt noch:
--
---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	Rev. 1.00   23.06.2010-FB	erste Version
--	18.05.2011-le : - avoid synthesis warnings:
--						correct sensitivity list
--	29.01.2014-le :	- add a extra state and wait a cycle longer to avoid read 
--						failure at (re)start when the master write at the same 
--						time as we read. this can result in wrong length usw.
--	25.06.2019-le:	- add support for Memory read register, switchable over 
--					  generic g_MEM_RdD_REG on top
--------------------------------------------------------------------------------
--$Rev:: 5321                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2019-06-25 10:11:29 +0200 (Di., 25 Jun 2019)                         $
--------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity C64_JTAGSeq is
	generic (
		g_MEM_RdD_REG : in integer range 0 to 1 := 0
	);
	port (                   	
		i_Q125		 	: in 	std_logic;
		i_JTG_En	 	: in 	std_logic;
		o_JTG_Done	 	: Out 	std_logic := '0';

        -- Gin-Slave Ram     	
		i_MEM_RdData	: in 	std_logic_vector(31 downto 0);		
		o_MEM_WrData	: out	std_logic_vector(31 downto 0) 	:= (others => '0');		
		o_MEM_ByteAddr	: out	std_logic_vector(15 downto 0) 	:= (others => '0');		
		o_MEM_WR		: out	std_logic_vector( 3 downto 0) 	:= (others => '0');
                             	
        -- C64-Bus          	
		i_C64Clk_Seq	: in	std_logic_vector( 3 downto 0);
		o_C64_SEL		: out	std_logic						:= '0';		
		o_C64_Bend		: out	std_logic						:= '0';		
		o_C64_Dat_HOE	: out	std_logic						:= '0';		
		o_C64_Dat_LOE	: out	std_logic						:= '0';		
		o_C64_Ack_OE	: out	std_logic						:= '0';		
		o_C64_WrDat		: out	std_logic_vector(15 downto 0)	:= (others => '0');		
		i_C64_RdDat		: in 	std_logic_vector(15 downto 0);
		i_C64_Ack		: in 	std_logic		
    );
end;                                         

architecture impl of C64_JTAGSeq is   
--------------------------------------------------------------------------------
--	DP-Ram Memory   	0X2000-Bytes = 8kByte total
--------------------------------------------------------------------------------
	constant Cfg_JTG_Job	: std_logic_vector(15 downto 0) := x"031C";
 
 	constant Cfg_CmdTab		: std_logic_vector(15 downto 0) := x"0320";
	constant Cfg_AdrTab		: std_logic_vector(15 downto 0) := x"0324";

	-- EEPROMer/JTAGer commands
	constant cmd_JTG		: std_logic_vector(31 downto 0) := x"20000000";
	constant cmd_JTG_Start	: std_logic_vector(31 downto 0) := x"21000000";
	constant cmd_JTG_Busy	: std_logic_vector(31 downto 0) := x"A0000000";
	constant cmd_Mask		: std_logic_vector(31 downto 0) := x"3F000000";      
	constant cmd_TMask		: std_logic_vector(31 downto 0) := x"70000000";      




--------------------------------------------------------------------------------
--	C64-Command
--------------------------------------------------------------------------------    
--|....'....:....'....!....'....:....'....| |....'....:....'....!....'....:....'....|
--|    command        !   module adr      | |                   !   DPR-decriptor   |
--|A     Timer        ! CMD'Mod_'channel__| |                   !.... .... .... ....|
--|ATTT TTTT TTTT TTTT!CCCC MMMM KKKK KKKK| |.... .... .... ....!.PPP TAAA AAAA AAAA|
--------------------------------------------------------------------------------    
    constant cmd_C64_nop	:  std_logic_vector := "0000"; 
    constant cmd_C64_JTAG	:  std_logic_vector := "0001"; 
    constant cmd_C64_2		:  std_logic_vector := "0010"; 
    constant cmd_C64_RD		:  std_logic_vector := "0011"; 
    constant cmd_C64_4		:  std_logic_vector := "0100"; 
    constant cmd_C64_WRl	:  std_logic_vector := "0101"; 
    constant cmd_C64_WRh	:  std_logic_vector := "0110"; 
    constant cmd_C64_WR		:  std_logic_vector := "0111"; 

--------------------------------------------------------------------------------	
    constant H : std_logic := '1';
    constant L : std_logic := '0';
    constant Z : std_logic := 'Z';
--------------------------------------------------------------------------------	
 	signal	MEM_Adr		: std_logic_vector(15 downto 0) := x"0000";		-- act dp-ram Byte-Adr		
	signal	MEM_Adr_1	: std_logic_vector(15 downto 0) := x"0000";		-- t-1 Byte-Adr
	signal	MEM_DatPoi	: std_logic_vector(15 downto 0) := x"0000";		-- points to Data		
	signal	MEM_WrData	: std_logic_vector(31 downto 0) := x"00000000";	-- data to dp-ram		
	signal	MEM_RdData	: std_logic_vector(31 downto 0) := x"00000000";	-- data from dp-ram	
	signal	MEM_WR		: std_logic_vector( 3 downto 0) :=  "0000";		-- write 
          	
--------------------------------------------------------------------------------
    constant s0 		: std_logic_vector( 3 downto 0) := x"0";
    constant s1 		: std_logic_vector( 3 downto 0) := x"1";
    constant s2 		: std_logic_vector( 3 downto 0) := x"2";
    constant s3 		: std_logic_vector( 3 downto 0) := x"3";
    constant s4 		: std_logic_vector( 3 downto 0) := x"4";
	signal	C64Clk_Seq	: std_logic_vector( 3 downto 0) := x"0";

    -- asyn C64-Bus  
	signal	C64_SEL		: std_logic := L;		
	signal	C64_Bend	: std_logic := L;		
	signal	C64_Dat_HOE	: std_logic := L;		
	signal	C64_Dat_LOE	: std_logic := L;		
	signal	C64_Ack_OE	: std_logic := L;		
	signal	C64_WrDat	: std_logic_vector(15 downto 0) := x"0000";		
      
    -- latched C64-Bus  
	signal	c_C64_SEL		: std_logic := L;		
	signal	c_C64_Bend		: std_logic := L;		
	signal	c_C64_Dat_HOE	: std_logic := L;		
	signal	c_C64_Dat_LOE	: std_logic := L;		
	signal	c_C64_Ack_OE	: std_logic := L;		
	signal	c_C64_WrDat		: std_logic_vector(15 downto 0) := x"0000";		

--------------------------------------------------------------------------------    
--	JTAGer
--------------------------------------------------------------------------------    
    type sJTG_MasSeq is (
		-- die EndZiffern deuten auf den C64_ClockState s0..s4 hin
		-- also immer schön synchron bleiben !!
     	sJTG0,sJTG1,sJTG_JobRead1,
     	sJTG_SynStart2,
    	sJTG_Start0,sJTG_Start1,sJTG_Start2,sJTG_Start3,sJTG_Start4,
    	sJTG_CLK_L_04,sJTG_CLK_H_04,
    	sJTG_NextWord0,sJTG_NextWord1,
    	sJTG_BlockDone1,sJTG_ClearJob3,
    	sJTG_Terminate2,sJTG_Terminate_0_4,
        sJTG99
	);	
	signal	JTG_Seq: sJTG_MasSeq := sJTG0;	    						-- JTAG main sequencer

	signal 	JTG_WrDatPoi: std_logic_vector(11 downto 0) := x"000";		-- points to burn JTG_data

	signal	JTG_WrDat	: std_logic_vector(31 downto 0) := x"00000000";		
	signal	JTG_RdDat	: std_logic_vector(15 downto 0) := x"0000";		
	signal	JTG_CEN		: std_logic_vector( 3 downto 0) := x"0";	

	signal	JTG_NoBit	: std_logic_vector(11 downto 0) := x"000";
	signal	JTG_BitCnt	: std_logic_vector( 7 downto 0) := x"00";
	-- DPRAM_Addr 0x80 or 0x00
	signal	JTG_Adr80	: std_logic := L;

	signal	INI_Done	: std_logic := L;	
	signal	JTG_Done	: std_logic := L;	

--------------------------------------------------------------------------------
begin -- of architecture CM_Seq    
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	outputs --------------------------------------------------------------------
	o_MEM_ByteAddr	<= MEM_Adr;
	
	o_MEM_WrData 	<= MEM_WrData;		
      MEM_RdData 	<= i_MEM_RdData after 10 ps;
	o_MEM_WR		<= MEM_WR ;
	o_JTG_Done		<= JTG_Done;
    
    C64Clk_Seq 		<= i_C64Clk_Seq;

    o_C64_SEL       <= C64_SEL;
    o_C64_Bend		<= C64_Bend;
    o_C64_Dat_HOE	<= C64_Dat_HOE;
    o_C64_Dat_LOE	<= C64_Dat_LOE;
    o_C64_Ack_OE  	<= C64_Ack_OE;
    o_C64_WrDat		<= C64_WrDat; 
    
--******************************************************************************
--
--		JTAG Sequencer
--
--******************************************************************************
	process (i_Q125) begin
    	if rising_edge(i_Q125) then
    	
 	 	  if (i_JTG_EN = L) or (JTG_Done = H) then
     		if (i_JTG_EN = L) then
	     		JTG_Done	<= L;
	     	end if;	

     		JTG_Seq		<= sJTG0;
	 	  else
            --==================================================================
			--
			-- 		JTAG
			--
            --==================================================================
			case JTG_Seq is  
	            when sJTG0 =>
					-- asynch part: point to JTG-JOB
					-- be always synchron
					if (C64Clk_Seq = s0) then
						JTG_Seq <= sJTG1;				
					end if;	

				----------------------------------------------------------------		
				--	JTAG CMD decoder
				----------------------------------------------------------------		
	            when sJTG1 =>
	                -- JTAG already initiated ?
					if ((MEM_RdData and cmd_JTG_Busy) = cmd_JTG_Busy) then
						-- wait to next JTAG-block
						JTG_Seq <= sJTG0;						
					else				
						-- no, new JOB ?
						if ((MEM_RdData and cmd_Mask) = cmd_JTG_Start) then
							-- yes, start JTAG
							if (C64Clk_Seq = s0) then
								JTG_Seq <= sJTG_JobRead1;
							end if;
						else-- Busy cleared, and no JTAG_Job                 
							-- is there a pending JTAG Job to terminate 
							if (INI_Done = H) then       
								-- yes, send Bend to terminate JTAG loading
						    	JTG_Seq <= sJTG_Terminate2;
						    else              
						    	-- nothing to do at all 
						    	JTG_Seq <= sJTG99;
						    end if;	
			           	end if;
					end if;  
	            when sJTG_JobRead1 =>
					-- load Modul-Nr
					JTG_CEN   <= MEM_RdData(19 downto 16);
					-- load JTAG-Bit Length
					JTG_NoBit <= MEM_RdData(11 downto  0); 
	                -- DPRAM_Addr 0x80 or 0x00
	                JTG_Adr80 <= MEM_RdData(15);
					-- Module already in JTAG-mode ?
					if (INI_Done = L) then       
						-- no, initiate JTAG-mode						
						JTG_Seq <= sJTG_SynStart2;				
					else
						-- yes, do next JTAG block
						JTG_Seq <= sJTG_Start2;						
					end if;              
				----------------------------------------------------------------		
				--	synch
				----------------------------------------------------------------		
	            when sJTG_SynStart2 =>
					-- be always synchron
					if (C64Clk_Seq = s4) then
						JTG_Seq <= sJTG_Start0;
					end if;

				----------------------------------------------------------------		
				--	set Module in JTAG-State
				----------------------------------------------------------------		
	            when sJTG_Start0 =>
					JTG_Seq <= sJTG_Start1;				

	            when sJTG_Start1 =>
					JTG_Seq <= sJTG_Start2;				
	            
	            when sJTG_Start2 => 
	            	if (JTG_Adr80 = H) then
		            	-- JTG RD/WR-data at 0x80
						JTG_WrDatPoi <= X"080"; 
					else   
		            	-- JTG RD/WR-data at 0x00
						JTG_WrDatPoi <= X"000"; 
					end if;		
					JTG_Seq <= sJTG_Start3;				
	            
	            when sJTG_Start3 =>
					-- asynch part: point into JTAG-Data block to read data to b
					JTG_Seq <= sJTG_Start4;				

	            when sJTG_Start4 =>
					-- shift max 16 TMS&TDO Bits per JTG-Block data-word
	               	JTG_BitCnt <= x"10";
					-- load first JTG-Block data-word
					JTG_WrDat <= MEM_RdData;    
	               	-- point to next rd-block-word
					-- start clean
	               	JTG_RdDat <= x"0000";
					JTG_Seq <= sJTG_CLK_L_04;				
				
				----------------------------------------------------------------
				--  TDI arrives one clk later:
				--	TDO		 0 1 2 3 . E F   0 1 2
				--			_-_-_-_-_-_-_-___-_-_-_
				--	TDI		   0 1 2 3 . E F   0 1
				----------------------------------------------------------------
				when sJTG_CLK_L_04 =>	-- JTAG_CLK = 0 ------------------------
					-- be always synchron
					if (C64Clk_Seq = s4) then
						JTG_RdDat <= JTG_RdDat(14 downto 0) & i_C64_RdDat(0); 
						if (JTG_BitCnt > 0) and (JTG_NoBit > 0) then
		                	JTG_Seq <= sJTG_CLK_H_04;
						else
		                    JTG_Seq <= sJTG_NextWord0;
						end if;  							
					end if;	

				when sJTG_CLK_H_04 =>	-- JTAG_CLK = 1 ------------------------
					-- be always synchron
					if (C64Clk_Seq = s4) then
						JTG_WrDat(31 downto 16) <= JTG_WrDat(30 downto 16) & JTG_WrDat(16);
						JTG_WrDat(15 downto  0) <= JTG_WrDat(14 downto  0) & JTG_WrDat(0);
						
						JTG_BitCnt <= JTG_BitCnt - 1;
						JTG_NoBit  <= JTG_NoBit  - 1;
		               	JTG_Seq <= sJTG_CLK_L_04;
		            end if;   	
	            
				----------------------------------------------------------------
				--	next 16 TMS/TDI bits, store TDO-bits
				----------------------------------------------------------------
				when sJTG_NextWord0 =>
					-- asynch part: store JTG_RdDat into JTG wr-block data
	               	-- point to next rd-block-word
	               	JTG_WrDatPoi <= JTG_WrDatPoi + 4;

	               	-- are there still more bits to do
					if (JTG_NoBit > 0) then
						-- yes, do it 
					    JTG_Seq <= sJTG_NextWord1;
					else  
						-- no, clear JOB
	                    JTG_Seq <= sJTG_BlockDone1;
					end if;  							

				when sJTG_NextWord1 =>
					-- be always synchron
					if (C64Clk_Seq = s2) then
						JTG_Seq <= sJTG_Start3;
					end if;	
	            
				----------------------------------------------------------------
				--	JTAG block done, clear CMD 	!!- hold module  in JTAG-Mode -!
				----------------------------------------------------------------
				when sJTG_BlockDone1 =>
					-- asynch part: point to JTAG_JOB
					INI_Done <= H;
					-- be always synchron
					if (C64Clk_Seq = s3) then
						JTG_Seq <= sJTG_ClearJob3;
	    			end if;
	    			
				when sJTG_ClearJob3 =>
					-- be always synchron
					if (C64Clk_Seq = s4) then
						JTG_Seq <= sJTG0;
	    			end if;

				----------------------------------------------------------------
				--	terminate JTAG-Mode in module
				----------------------------------------------------------------
				when sJTG_Terminate2 =>
					INI_Done <= L;   
					
					-- Bend muss ganzer C64-Clock lang anliegen, 
					-- darum warte bis neuer Clock-Anfang
					-- be always synchron
					if (C64Clk_Seq = s4) then
						JTG_Seq <= sJTG_Terminate_0_4;
					end if;	

				when sJTG_Terminate_0_4 =>  
					-- be always synchron
					if (C64Clk_Seq = s3) then
						-- set Done at s3, so C64Master leaves on S4 
						JTG_Done <= H;
					elsif (C64Clk_Seq = s4) then
						JTG_Seq <= sJTG0;
					end if;	
				    
				----------------------------------------------------------------
				--	nothing to do, leave JTAG sequencer
				----------------------------------------------------------------
				when sJTG99 =>	--- leave JTAG seq -----------------------------
					if (C64Clk_Seq = s3) then
						-- set Done at s3, so C64Master leaves on S4 
						JTG_Done <= H;
						JTG_Seq <= sJTG0;
					end if;
					                                 
				----------------------------------------------------------------
				when others => null; -------------------------------------------
			end case;
		  end if; -- JTG_En
		end if;	
    end process;
    
--******************************************************************************
--
--		Memory Access
--
--******************************************************************************
--  Vorsicht: zwischen MemAdr und RdData sind zweit States!
--------------------------------------------------------------------------------
	process (i_Q125) begin
    	if rising_edge(i_Q125) then 
    		MEM_Adr_1 <= MEM_Adr;
			c_C64_SEL		<= C64_SEL		;		
            c_C64_Bend		<= C64_Bend		;	
            c_C64_Dat_HOE	<= C64_Dat_HOE	;
            c_C64_Dat_LOE	<= C64_Dat_LOE	;
            c_C64_Ack_OE	<= C64_Ack_OE	;
            c_C64_WrDat		<= C64_WrDat	;		
		end if;
	end process;    
---------------------------------------------------------------------------------
--	asynchron part of DP-Ram read
--------------------------------------------------------------------------------
	process (MEM_Adr_1,
			i_JTG_EN,JTG_Done,JTG_Adr80,
			 JTG_Seq,JTG_WrDatPoi,JTG_RdDat,--JTG_RdDatPoi,
			 c_C64_SEL,c_C64_Bend,
			 c_C64_Dat_HOE,c_C64_Dat_LOE,c_C64_Ack_OE,c_C64_WrDat, 
			 i_C64_RdDat,i_C64_Ack, jtg_cen, jtg_wrdat
	) begin                             

	 	if (i_JTG_EN = L) or (JTG_Done = H) then
 			-- free all C64 signals
     		C64_SEL     <= L;
     		C64_Bend    <= L;
     		C64_Dat_HOE <= L;
     		C64_Dat_LOE <= L;
     		C64_Ack_OE  <= L;
     		C64_WrDat   <= (others => '0');
	     		
	 		-- free all MEM signals
		    MEM_Adr     <= (others => '0');	
		    MEM_WrData  <= (others => '0');
		    MEM_WR      <= (others => '0');
		    
		else
			
			C64_SEL		<= c_C64_SEL	;		
            C64_Bend	<= c_C64_Bend	;	
            C64_Dat_HOE	<= c_C64_Dat_HOE;
            C64_Dat_LOE	<= c_C64_Dat_LOE;
            C64_Ack_OE	<= c_C64_Ack_OE	;
            C64_WrDat	<= c_C64_WrDat	;		
			MEM_Adr 	<= MEM_Adr_1	;
			MEM_WR 		<= "0000"		;
			MEM_WrData 	<= x"00000000"	;
		
	        --==================================================================
			--
			-- 		JTAG loader
			--
	        --==================================================================
			case JTG_Seq is  
				when sJTG0
					| sJTG1	=>
					-- point to JTAG-Job
					MEM_Adr <= Cfg_JTG_Job;	

	            when sJTG_Start0 =>
					C64_SEL <= H;
					C64_Bend <= L; 
					C64_WrDat <= cmd_C64_JTAG & JTG_CEN & x"00" ;
					C64_Dat_HOE <= H;
					C64_Dat_LOE <= H;
					C64_Ack_OE <= L;

	            when sJTG_Start1 =>
					C64_Ack_OE <= H;
				
				when sJTG_Start2 =>
					if (g_MEM_RdD_REG = 1) then
						if (JTG_Adr80 = H) then
							-- JTG RD/WR-data at 0x80
							MEM_Adr <= x"0" & X"080";
						else   
							-- JTG RD/WR-data at 0x00
							MEM_Adr <= x"0" &  X"000";
						end if;
					end if;

				when sJTG_Start3 | sJTG_NextWord1 =>
					-- point into JTAG-Data block to read data to burn
					MEM_Adr <= x"0" & JTG_WrDatPoi;--JTG_RdDatPoi;
					
	            when sJTG_Start4 =>
	                -- ab jetzt soll der Slave ACK bringen       	
					C64_Ack_OE 	<= L;
	                -- ab jetzt soll der Slave D7..0 bringen       	
					C64_Dat_LOE <= L;

				when sJTG_CLK_L_04 =>	-- JTAG_CLK = 0 ------------------------
					C64_SEL <= L;
					C64_WrDat <= x"0000";

	                -- JTGED_CLK = 0
					C64_WrDat(11) <= L;							
					C64_WrDat( 9) <= JTG_WrDat(31);							
					C64_WrDat( 8) <= JTG_WrDat(15);							

				when sJTG_CLK_H_04 =>	-- JTAG_CLK = 1 ------------------------
	                -- JTGED_CLK = H
					C64_WrDat(11) <= H;     
					
		        when sJTG_NextWord0 =>
					-- point into JTAG-Data block to store readed device-data
		            MEM_Adr <= x"0" & JTG_WrDatPoi;
		        	-- store the readed bus-data to dest-mem 
		--        	MEM_WrData <= x"0000" & JTG_RdDat(14 downto 0) & i_C64_RdDat(0);
		        	MEM_WrData <= x"0000" & JTG_RdDat;
		        	MEM_WR <= "1111";

				when sJTG_BlockDone1 =>
					-- point to JTAG-Job
					MEM_Adr <= Cfg_JTG_Job;	

				when sJTG_ClearJob3 =>
					--  set JTAG-BUSY,delete JTAG_Job 
				   	MEM_WrData <= cmd_JTG_Busy;
				   	-- wr high-byte only
		        	MEM_WR <= "1000";	

				when sJTG_Terminate_0_4 =>  
					-- terminate JTAG
					C64_Bend   <= H;

				--------------------------------------------------------------------
				when others => null;
			end case;
		end if;	 
    end process;
        
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
