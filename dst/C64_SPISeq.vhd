---------------------------------------------------------------------------
--
--  C64 SPI Sequencer
--
---------------------------------------------------------------------------
--
--  project     : C64_SPI Loader
--  programmer  : F:Baschung, INDEL AG
--  date        : 23.06.2010
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- SPI Loader
--
---------------------------------------------------------------------------
--
--	Fehlt noch:
--
---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	Rev. 1.00   23.06.2010-FB	erste Version 
--	31.03.2011-le : - support spi commands with datalength 0
--	18.05.2011-le : - avoid synthesis warnings:
--						correct sensitivity list
--	13.07.2011-le : - support half spi frequency
--	15.01.2014-le :	- add a extra state to avoid read failure at (re)start when
--						the master write at the same time as we read. this can 
--						result in wrong length usw.
--	16.01.2014-le :	- and wait a cycle longer to avoid the same failure with ppc
--	07.02.2014-stn: - corrected sampling error when using half spi frequency
--					(sample with falling edge; tested with COP-PAS and COP-IO)
--	25.06.2019-le:	- add support for Memory read register, switchable over 
--					  generic g_MEM_RdD_REG on top
--	10.02.2020-vz:	- sensitivity list completed to prevent warnings
--
--------------------------------------------------------------------------------
--$Rev:: 5782                                                                  $
--$Author:: Zuellig                                                            $
--$Date:: 2021-02-10 07:48:12 +0100 (Mi., 10 Feb 2021)                         $
--------------------------------------------------------------------------------


---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;




entity C64_SPISeq is 
	generic (
		g_MEM_RdD_REG : in integer range 0 to 1 := 0
	);
	port (                   	
		i_Q125		 	: in 	std_logic;
		i_SPI_En	 	: in 	std_logic;
		o_SPI_Done	 	: Out 	std_logic := '0';

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

architecture impl of C64_SPISeq is   
--------------------------------------------------------------------------------
--	DP-Ram Memory   	0X2000-Bytes = 8kByte total
--------------------------------------------------------------------------------
	constant Cfg_SPI_Cmd	: std_logic_vector(15 downto 0) := x"0318";
	constant Cfg_SPI_Job	: std_logic_vector(15 downto 0) := x"031C";

	constant Cfg_CmdTab		: std_logic_vector(15 downto 0) := x"0320";
	constant Cfg_AdrTab		: std_logic_vector(15 downto 0) := x"0324";

	-- EEPROMer/JTAGer commands
	constant cmd_SPI		: std_logic_vector(31 downto 0) := x"30000000";
	constant cmd_SPI_Start	: std_logic_vector(31 downto 0) := x"31000000";
	constant cmd_SPI_Busy	: std_logic_vector(31 downto 0) := x"B0000000";
	
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
    constant cmd_C64_SPI	:  std_logic_vector := "0010"; 
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
	signal	C64Clk_Seq	: std_logic_vector( 3 downto 0) := x"0";					-- clock counter

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
--	SPI loader
--------------------------------------------------------------------------------    
    type sSPI_MasSeq is (
		-- die EndZiffern deuten auf den C64_ClockState s0..s4 hin
		-- also immer schön synchron bleiben !!
     	sSPI0,sSPI1,sSPI_JobRead1,
     	sSPI_SynStart2,sSPI_NxStart2,
    	sSPI_Start0,sSPI_Start1,sSPI_Start2,sSPI_Start3,sSPI_Start4,
    	sSPI_CLK_L_04,sSPI_CLK_H_04,
    	sSPI_NextWord0,sSPI_NextWord1,
    	sSPI_BlockDone1,sSPI_ClearJob3,
    	sSPI_Terminate2,sSPI_Terminate_0_4,
        sSPI99
	);	
	signal	SPI_Seq		: sSPI_MasSeq := sSPI0;	    					-- SPI main sequencer

	signal 	SPI_WrDatPoi: std_logic_vector(11 downto 0) := x"000";		-- points to burn SPI_data

	signal	SPI_WrDat	: std_logic_vector(31 downto 0) := x"00000000";		
	signal	SPI_RdDat	: std_logic_vector(31 downto 0) := x"00000000";		
	signal	SPI_CEN		: std_logic_vector( 3 downto 0) := x"0";	

	-- Nr of Data-Bits
	signal	SPI_NoBit	: std_logic_vector(11 downto 0) := x"000";
	-- bit-counter per word
	signal	SPI_BitCnt	: std_logic_vector( 7 downto 0) := x"00";
	-- nr of command-bytes
	signal	SPI_NoCmd	: std_logic_vector( 3 downto 0) := x"0";
	-- 1 while command-bytes are written 
	signal	SPI_WrCmd	: std_logic := L;
	-- DPRAM_Addr 0x80 or 0x00
	signal	SPI_Adr80	: std_logic := L;

	signal	INI_Done	: std_logic := L;	
	signal	SPI_Done	: std_logic := L;
	
	signal half_clk		: std_logic := L;
	
--attribute fsm_encoding : string;
--attribute fsm_encoding of SPI_Seq : signal is "one-hot";

--------------------------------------------------------------------------------
begin -- of architecture CM_Seq    
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	outputs --------------------------------------------------------------------
	o_MEM_ByteAddr	<= MEM_Adr;
	
	o_MEM_WrData 	<= MEM_WrData;		
      MEM_RdData 	<= i_MEM_RdData after 10 ps;
	o_MEM_WR		<= MEM_WR ;
	o_SPI_Done		<= SPI_Done;
    
    C64Clk_Seq 		<= i_C64Clk_Seq;

    o_C64_SEL       <= C64_SEL;
    o_C64_Bend		<= C64_Bend;
    o_C64_Dat_HOE	<= C64_Dat_HOE;
    o_C64_Dat_LOE	<= C64_Dat_LOE;
    o_C64_Ack_OE  	<= C64_Ack_OE;
    o_C64_WrDat		<= C64_WrDat; 


--******************************************************************************
--
--		SPI Sequencer
--
--******************************************************************************
	process (i_Q125) begin
    	if rising_edge(i_Q125) then 
	
	 	  if (i_SPI_EN = L) or (SPI_Done = H) then
     		if (i_SPI_EN = L) then
	     		SPI_Done	<= L;
	     	end if;	

     		SPI_Seq		<= sSPI0;
     		half_clk <= L;
	 	  else
            --==================================================================
			--
			-- 		SPI	loader
			--
            --==================================================================
			case SPI_Seq is  
	            when sSPI0 =>
					-- asynch part: point to SPI-JOB
					-- be always synchron
					if (C64Clk_Seq = s0) then
						SPI_Seq <= sSPI1;				
					end if;	

				----------------------------------------------------------------		
				--	SPI CMD decoder
				----------------------------------------------------------------		
	            when sSPI1 =>	                
	                -- SPI already initiated ?
					if ((MEM_RdData and cmd_SPI_Busy) = cmd_SPI_Busy) then
						-- wait to next SPI-block
						SPI_Seq <= sSPI0;						
					else				
						-- no, new JOB ?
						if ((MEM_RdData and cmd_Mask) = cmd_SPI_Start) then
							-- yes, start SPI
							if (C64Clk_Seq = s0) then
								SPI_Seq <= sSPI_JobRead1;
							end if;
						else-- Busy cleared, and no SPI_Job                 
							-- is there a pending SPI Job to terminate 
							if (INI_Done = H) then       
								-- yes, send Bend to terminate SPI loading
						    	SPI_Seq <= sSPI_Terminate2;
						    else              
						    	-- nothing to do at all 
						    	SPI_Seq <= sSPI99;
						    end if;	
			           	end if;
					end if;
					
	            when sSPI_JobRead1 =>
					-- load Modul-Nr
					SPI_CEN   <= MEM_RdData(19 downto 16);
					-- load SPI-Bit Length (conv Bytes -> Bits)
					SPI_NoBit <= MEM_RdData(8 downto  0) & "000"; 
					-- load SPI_command ByteLength
					SPI_NoCmd <= MEM_RdData(23 downto 20); 
	                -- DPRAM_Addr 0x80 or 0x00
	                SPI_Adr80 <= MEM_RdData(15);
					-- Module already in SPI-mode ?
					if (INI_Done = L) then       
						-- no, initiate SPI-mode						
						SPI_Seq <= sSPI_SynStart2;				
					else
						-- yes, do next SPI block
						SPI_Seq <= sSPI_NxStart2;						
					end if;
				----------------------------------------------------------------		
				--	synch
				----------------------------------------------------------------		
	            when sSPI_SynStart2 =>
					-- be always synchron
					if (C64Clk_Seq = s4) then
						SPI_Seq <= sSPI_Start0;
					end if;

	            when sSPI_NxStart2 =>
					-- be always synchron
					if (C64Clk_Seq = s1) then
						SPI_Seq <= sSPI_Start2;
					end if;

				----------------------------------------------------------------		
				--	set Module in JTAG-State
				----------------------------------------------------------------		
	            when sSPI_Start0 =>
					SPI_Seq <= sSPI_Start1;				

	            when sSPI_Start1 =>
					SPI_Seq <= sSPI_Start2;				
	            
	            when sSPI_Start2 => 
	            	if (SPI_Adr80 = H) then
		            	-- SPI RD/WR-data at 0x80
						SPI_WrDatPoi <= X"080"; 
					else   
		            	-- SPI RD/WR-data at 0x00
						SPI_WrDatPoi <= X"000"; 
					end if;		
								
					if (SPI_NoCmd /= 0) then
						SPI_WrCmd <= H;
					else
						SPI_WrCmd <= L;
					end if; 

	            	-- asynch still points to SPI-descriptor  
					-- load SPI-command-bytes
					SPI_WrDat <= MEM_RdData;
					SPI_Seq <= sSPI_Start3;				
	            
	            when sSPI_Start3 =>       
	            	-- asynch points to SPI-Data block to read data to burn
					SPI_Seq <= sSPI_Start4;				

	            when sSPI_Start4 =>
					-- start with command-bytes?
					if (SPI_WrCmd = H) then     
						-- shift SPI_Cmd Bits 
		               	SPI_BitCnt <= '0' & SPI_NoCmd & "000";
					else
						-- shift max 32 SPI_D Bits per SPI-Block data-word
		               	SPI_BitCnt <= x"20";
						-- load first SPI-Block data-word
		               	SPI_WrDat <= MEM_RdData;         
		               	-- point to next rd-block-word
		            end if;   	
					-- start clean
	               	SPI_RdDat <= x"00000000";
		               	
					SPI_Seq <= sSPI_CLK_L_04;				
				
				----------------------------------------------------------------
				--  Q arrives one clk later:
				--	D 		 0 1 2 3 . E F   0 1 2
				--			_-_-_-_-_-_-_-___-_-_-_
				--	Q		   0 1 2 3 . E F   0 1
				----------------------------------------------------------------
				when sSPI_CLK_L_04 =>	-- SPI_CLK = 0 ------------------------
					-- be always synchron
					if (C64Clk_Seq = s4) then
					-- sample at falling edge: this is the last possible moment, before
					-- the slave shifts new data out (in spi mode 0)
					-- (spi standard would be rising edge, but falling edge results in
					-- better behavior relating to propagation delay...)
						if (half_clk=i_C64_RdDat(1)) then
							-- if full clock (with half clock sample already happened)
							if (i_C64_RdDat(1)=L) then 
								SPI_RdDat <= SPI_RdDat(30 downto 0) & i_C64_RdDat(0);
							end if;
							if (SPI_BitCnt > 0) and ((SPI_NoBit > 0) or (SPI_WrCmd=H)) then
			                	SPI_Seq <= sSPI_CLK_H_04;
							else
			                    SPI_Seq <= sSPI_NextWord0;
							end if;
							half_clk <= L;
						else
							-- sample right at falling edge (not 1 cycle delayed)
							SPI_RdDat <= SPI_RdDat(30 downto 0) & i_C64_RdDat(0); 
							half_clk <= H;
						end if;
					end if;	

				when sSPI_CLK_H_04 =>	-- SPI_CLK = 1 ------------------------
					-- be always synchron
					if (C64Clk_Seq = s4) then
						if (half_clk=i_C64_RdDat(1)) then
							SPI_WrDat(31 downto 0)  <= SPI_WrDat(30 downto 0) & '0';
							-- bit per word counter
							SPI_BitCnt <= SPI_BitCnt - 1;
								
							if (SPI_WrCmd = L) then
								-- count data-bits only
								SPI_NoBit  <= SPI_NoBit  - 1;
							end if;	
		               		SPI_Seq <= sSPI_CLK_L_04;
							half_clk <= L;
						else
							half_clk <= H;
						end if;
		            end if;   	
	            
				----------------------------------------------------------------
				--	next 16 TMS/TDI bits, store TDO-bits
				----------------------------------------------------------------
				when sSPI_NextWord0 =>
					-- asynch part: store SPI_RdDat into SPI wr-block data
					if (SPI_WrCmd = L) then
		               	-- point to next rd-block-word
		               	SPI_WrDatPoi <= SPI_WrDatPoi + 4;
                    end if;
                    
	               	-- are there still more bits to do
					if (SPI_NoBit > 0) then
						-- yes, do it 
					    SPI_Seq <= sSPI_NextWord1;
					else  
						-- no, clear JOB
	                    SPI_Seq <= sSPI_BlockDone1;
					end if;  							

				when sSPI_NextWord1 =>
					-- commands done   
					SPI_WrCmd <= L;
					-- be always synchron
					if (C64Clk_Seq = s2) then
						SPI_Seq <= sSPI_Start3;
					end if;	
	            
				----------------------------------------------------------------
				--	SPI block done, clear CMD 	!!- hold module  in JTAG-Mode -!
				----------------------------------------------------------------
				when sSPI_BlockDone1 =>
					-- asynch part: point to SPI_JOB
					INI_Done <= H;
					-- be always synchron
					if (C64Clk_Seq = s3) then
						SPI_Seq <= sSPI_ClearJob3;
	    			end if;
	    			
				when sSPI_ClearJob3 =>
					-- be always synchron
					if (C64Clk_Seq = s4) then
						SPI_Seq <= sSPI0;
	    			end if;

				----------------------------------------------------------------
				--	terminate SPI-Mode in module
				----------------------------------------------------------------
				when sSPI_Terminate2 => 
					INI_Done <= L;

					-- Bend muss ganzer C64-Clock lang anliegen, 
					-- darum warte bis neuer Clock-Anfang
					-- be always synchron
					if (C64Clk_Seq = s4) then
						SPI_Seq <= sSPI_Terminate_0_4;
					end if;	

				when sSPI_Terminate_0_4 =>
				   	-- Bend von s0...s4
					-- be always synchron
					if (C64Clk_Seq = s3) then
						-- set SPI_Done at s3, so C64Master leaves on S4 
						SPI_Done <= H;
					elsif (C64Clk_Seq = s4) then
						SPI_Seq <= sSPI0;
					end if;	
				    
				----------------------------------------------------------------
				--	nothing to do, leave SPI sequencer
				----------------------------------------------------------------
				when sSPI99 =>	--- leave SPI seq -----------------------------
					if (C64Clk_Seq = s3) then
						-- set SPI_Done at s3, so C64Master leaves on S4 
						SPI_Done <= H;
						SPI_Seq <= sSPI0;
					end if;	
	                                 
				----------------------------------------------------------------
				when others => null; -------------------------------------------
			end case;
		  end if; -- SPI_En
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
--------------------------------------------------------------------------------
--	asynchron part of DP-Ram read
--------------------------------------------------------------------------------
	process (MEM_Adr_1,MEM_RdData,
	         i_SPI_EN,SPI_Done,
			 SPI_Seq,SPI_WrDatPoi,SPI_RdDat,
			 c_C64_SEL,c_C64_Bend,
			 c_C64_Dat_HOE,c_C64_Dat_LOE,c_C64_Ack_OE,c_C64_WrDat, 
			 i_C64_RdDat,i_C64_Ack,SPI_Adr80,
			 spi_cen,spi_wrdat,spi_wrcmd
	) begin                             

	 	if (i_SPI_EN = L) or (SPI_Done = H) then
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
			
			C64_SEL		<= c_C64_SEL		;		
            C64_Bend	<= c_C64_Bend		;	
            C64_Dat_HOE	<= c_C64_Dat_HOE	;
            C64_Dat_LOE	<= c_C64_Dat_LOE	;
            C64_Ack_OE	<= c_C64_Ack_OE	;
            C64_WrDat	<= c_C64_WrDat	;		
			MEM_Adr 	<= MEM_Adr_1	;
			MEM_WR 		<= "0000"		;
			MEM_WrData 	<= x"00000000"	;
		
	        --==================================================================
			--
			-- 		SPI
			--
	        --==================================================================
			case SPI_Seq is  
				when sSPI0
					| sSPI1	=>
					-- point to SPI-Job
					MEM_Adr <= Cfg_SPI_Job;	

				when sSPI_SynStart2
					| sSPI_NxStart2
					| sSPI_JobRead1 =>
					-- point to SPI-descriptor
		        	MEM_Adr <= Cfg_SPI_Cmd; 		   			   	


	            when sSPI_Start0 =>
					C64_SEL <= H;
					C64_Bend <= L; 
					C64_WrDat <= cmd_C64_SPI & SPI_CEN & x"00" ;
					C64_Dat_HOE <= H;
					C64_Dat_LOE <= H;
					C64_Ack_OE <= L;

	            when sSPI_Start1 =>
					C64_Ack_OE <= H;

				when sSPI_Start2 =>
					if (g_MEM_RdD_REG = 1) then
						if (SPI_Adr80 = H) then
							-- SPI RD/WR-data at 0x80
							MEM_Adr <= x"0" & X"080";
						else   
							-- SPI RD/WR-data at 0x00
							MEM_Adr <= x"0" &  X"000";
						end if;
					end if;

				when sSPI_Start3 | sSPI_NextWord1 =>
					-- point into SPI-Data block to read data to burn
					MEM_Adr <= x"0" & SPI_WrDatPoi;
					
	            when sSPI_Start4 =>
	                -- ab jetzt soll der Slave ACK bringen       	
					C64_Ack_OE 	<= L;
	                -- ab jetzt soll der Slave D7..0 bringen       	
					C64_Dat_LOE <= L; 

				when sSPI_CLK_L_04 =>	-- SPI_CLK = 0 ------------------------
					C64_SEL <= L;
					C64_WrDat <= x"0000";

	                -- SPI_CLK = 0
					C64_WrDat(11) <= L;
					-- SPI_CS							
					C64_WrDat( 9) <= H;							
					-- SPI_D
					C64_WrDat( 8) <= SPI_WrDat(31);							

				when sSPI_CLK_H_04 =>	-- SPI_CLK = 1 ------------------------
	                -- SPI_CLK = H
					C64_WrDat(11) <= H;     

		        when sSPI_NextWord0 =>
					-- point into SPI-Data block to store readed device-data
		            MEM_Adr <= x"0" & SPI_WrDatPoi;
		        	-- store the readed bus-data to dest-mem 
		        	MEM_WrData <= SPI_RdDat;  
		        	if (SPI_WrCmd = L) then
		        		-- nothing to write while command-bytes
			        	MEM_WR <= "1111";	
			        end if;	

				when sSPI_BlockDone1 =>
						-- clear SPI_CS 							
						C64_WrDat( 9) <= L;							
					-- point to SPI-Job
					MEM_Adr <= Cfg_SPI_Job;	

				when sSPI_ClearJob3 =>
					--  set SPI-BUSY,delete SPI_Job 
				   	MEM_WrData <= cmd_SPI_Busy;
				   	-- wr high-byte only
		        	MEM_WR <= "1000";	
		        	
					when sSPI_Terminate_0_4 =>
					   	-- Bend von s0...s4
						-- terminate JTAG
						C64_Bend   <= H;

			--------------------------------------------------------------------
				when others => null;
			end case;    
			
		end if; -- SPI_En
    end process;
        
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------