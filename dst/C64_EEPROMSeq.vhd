---------------------------------------------------------------------------
--
--  EEPROM Sequencer
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
--  	- EEPROM Sequencer 
--
---------------------------------------------------------------------------
--
--	Fehlt noch:
--  
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;

LIBRARY I2C;
USE I2C.ALL;

---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	23.06.2010-FB	erste Version
--	28.07.2011-le : - split sda to input and output
--	20.03.2014-stn:	- added generics to patch eeprom i2c address
--					(reference project gin-ttl_oct)
--	25.06.2019-le:	- add support for Memory read register, switchable over 
--					  generic g_MEM_RdD_REG on top
--	12.06.2020-vz:	- add handshake signal to/from C64_EEPROMER to share i2c bus with another i2c master
--					  used in cv_sodimm_max4x10 
---------------------------------------------------------------------------

entity C64_EEPSeq is
	generic (
		-- patch to change eeprom address 
		g_patch_ee_addr	: in	integer range 0 to 1 := 0;
		g_patch_addr_f	: in	std_logic_vector(3 downto 0) := x"0"; -- from
		g_patch_addr_t	: in	std_logic_vector(3 downto 0) := x"0"; -- to
		g_MEM_RdD_REG	: in integer range 0 to 1 := 0
	);
	port (                   	
		i_Q125		 	: in 	std_logic;
		i_EEP_En	 	: in 	std_logic;
		o_EEP_Done	 	: Out 	std_logic := '0';
		i_eep_i2c_acpt	: in	std_logic := '1';
		o_eep_i2c_req	: out	std_logic := '1';
        -- Gin-Slave Ram     	
		i_MEM_RdData	: in 	std_logic_vector(31 downto 0);		
		o_MEM_WrData	: out	std_logic_vector(31 downto 0) 	:= (others => '0');		
		o_MEM_ByteAddr	: out	std_logic_vector(15 downto 0) 	:= (others => '0');		
		o_MEM_WR		: out	std_logic_vector( 3 downto 0) 	:= (others => '0');

        -- C64-Bus          	
		i_C64Clk_Seq	: in	std_logic_vector( 3 downto 0);

		o_C64_I2C_SCL	: out	std_logic;
		o_C64_I2C_SDA	: out	std_logic;
		i_C64_I2C_SDA	: in	std_logic;

		o_C96_I2C_SCL	: out	std_logic;
		o_C96_I2C_SDA	: out	std_logic;
		i_C96_I2C_SDA	: in	std_logic
    );
end;                                         

architecture impl of C64_EEPSeq is   
--------------------------------------------------------------------------------
--	DP-Ram Memory   	0X2000-Bytes = 8kByte total
--------------------------------------------------------------------------------
	-- 0x80000000 = INIT-DONE (EEPROM readed)
	constant Cfg_INTI_DONE	: std_logic_vector(15 downto 0) := x"0184";

	constant Cfg_EEP_Desc	: std_logic_vector(15 downto 0) := x"0318";
	constant Cfg_EEP_Job	: std_logic_vector(15 downto 0) := x"031C";
	constant Cfg_CmdTab		: std_logic_vector(15 downto 0) := x"0320";
	constant Cfg_AdrTab		: std_logic_vector(15 downto 0) := x"0324";

	-- EEPROMer/JTAGer commands
	constant cmd_EEP		: std_logic_vector(31 downto 0) := x"10000000";
	constant cmd_EEP_Rd		: std_logic_vector(31 downto 0) := x"11000000";
	constant cmd_EEP_Wr		: std_logic_vector(31 downto 0) := x"12000000";
	constant cmd_EEP_Busy	: std_logic_vector(31 downto 0) := x"90000000";
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

	signal	I2C_SCL		: std_logic := L;		
	signal	I2C_SDAi	: std_logic := L;		
	signal	I2C_SDAo	: std_logic := L;
	signal	I2C_SDA_OE	: std_logic := L;
	signal  eep_i2c_req	: std_logic := H;
			
--------------------------------------------------------------------------------    
--	EEPROM loader
--------------------------------------------------------------------------------    
    type sEEP_MasSeq is (
		-- die EndZiffern deuten auf den C64_ClockState s0..s4 hin
		-- also immer schön synchron bleiben !!  
    	sEEProm0,sEEProm1,sEEP_Terminate2,sEEP_Terminate3,sEEP_Terminate4,sEEProm99,
    	sEEP_Start2,sEEP_Start3,sEEP_Start4,
    	sEEP_RD2,sEEP_RD3,sEEP_RD4,
    	sEEP_WR2,sEEP_WR3,sEEP_WR4,
    	sEEP_WrDone1,sEEP_WrDone2,sEEP_WrDone3,sEEP_WrDone4,
    	sEEP_RdDone1,sEEP_RdDone2,sEEP_RdDone3,sEEP_RdDone4
	);	
	signal	EEP_Seq: sEEP_MasSeq := sEEProm0;   							-- EEP main sequencer
	signal	EEP_DatPoi	: std_logic_vector(11 downto 0) := x"000";		-- points to EEP_data
          	
 	signal	EEP_CMD		: std_logic_vector( 3 downto 0) := x"0";	
	signal	EEP_CEN		: std_logic_vector( 3 downto 0) := x"0";
	signal	EEP_WrDat	: std_logic_vector(31 downto 0) := x"00000000";		
	signal	EEP_RdDat	: std_logic_vector(31 downto 0) := x"00000000";		
	signal	EEP_Error	: std_logic := L;	
	signal	EEP_Addr	: std_logic_vector(11 downto 0) := x"000";
	signal	EEP_NoB		: std_logic_vector(11 downto 0) := x"000";
			
    constant Cmd_EEP_Nop: 		std_logic_vector := x"0";
    constant Cmd_EEP_Wr4Byte:	std_logic_vector := x"4";
    constant Cmd_EEP_Rd4Byte:	std_logic_vector := x"C"; 
    constant Cmd_EEP_Hold:		std_logic_vector := x"8"; 
    constant Cmd_EEP_RdStop:  	std_logic_vector := x"F"; 

	-- DPRAM_Addr 0x80 or 0x00
	signal	EEP_Adr80	: std_logic := L;

	signal	INI_Done	: std_logic := L;	
	signal	EEP_Done	: std_logic := L;	

--------------------------------------------------------------------------------
begin -- of architecture CM_Seq    
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	outputs --------------------------------------------------------------------
	o_MEM_ByteAddr	<= MEM_Adr;
	
	o_MEM_WrData 	<= MEM_WrData;		
      MEM_RdData 	<= i_MEM_RdData after 10 ps;
	o_MEM_WR		<= MEM_WR ;
	o_EEP_Done		<= EEP_Done;
    o_eep_i2c_req 	<= eep_i2c_req;
    C64Clk_Seq 		<= i_C64Clk_Seq;
    
    
--------------------------------------------------------------------------------
--	select local C96_EEP or extern C64_module_EEP
--------------------------------------------------------------------------------
--	0..7	extern C64_module_EEP
--	8..F	local C96_EEP
--------------------------------------------------------------------------------
	process (EEP_CEN,I2C_SCL,I2C_SDAo,I2C_SDA_OE,i_C64_I2C_SDA,i_C96_I2C_SDA) begin
	   	o_C64_I2C_SCL 	<= H;
	   	o_C64_I2C_SDA 	<= H;
	   	o_C96_I2C_SCL 	<= H;
	   	o_C96_I2C_SDA 	<= H;
	
		if (EEP_CEN(3) = L) then
			o_C64_I2C_SCL <= I2C_SCL;
        	I2C_SDAi <= i_C64_I2C_SDA; 	
			if (I2C_SDA_OE = H) and (I2C_SDAo = L) then 
	        	o_C64_I2C_SDA <= L;
	        end if;	
		else
			o_C96_I2C_SCL <= I2C_SCL;
        	I2C_SDAi <= i_C96_I2C_SDA; 	
			if (I2C_SDA_OE = H) and (I2C_SDAo = L) then 
	        	o_C96_I2C_SDA <= L;
	        end if;	
		end if;   
		
	end process;      
	
--******************************************************************************
--
--		EEPROM Sequencer
--
--******************************************************************************
	process (i_Q125) begin
    	if rising_edge(i_Q125) then 
			MEM_Adr_1 <= MEM_Adr;
			eep_i2c_req <= eep_i2c_req;
			if (i_EEP_EN = L)  then
				if (g_MEM_RdD_REG = 1) then
					MEM_Adr_1 <= Cfg_EEP_Job;
				end if;
				if (i_EEP_EN = L) then
					EEP_Done	<= L;
				end if;	
			else
				--==================================================================
				--
				-- 	EPROM loader
				--
				--==================================================================
				case EEP_Seq is  
				when sEEProm0 =>	--- 
					-- asynch part: point to EEPROM-Job
					-- EEP_command done?			
					if (INI_Done = L) then    
						if ((EEP_CMD = Cmd_EEP_Nop) or (EEP_CMD = Cmd_EEP_Hold)) then
							-- all free, check for new EEP_Job?
							eep_i2c_req <= H;
							if(i_eep_i2c_acpt = H)then
								EEP_Seq <= sEEProm1;
							else
								EEP_Seq <= sEEProm99;
							end if;
							
						else                        
							-- EEP_command still running
			            	EEP_Seq <= sEEProm99;
						end if;	
					else         
						-- INI_Done=H, clear this already done command
						-- was it a read or write command?
						if (EEP_CMD = Cmd_EEP_Rd4Byte) then
				           	-- hold EEP-signals, clear Done
				           	EEP_CMD <= Cmd_EEP_Hold;
							-- was a read, store readed data
							EEP_Seq <= sEEP_RdDone1;
						elsif (EEP_CMD = Cmd_EEP_Wr4Byte) then    
				           	-- hold EEP-signals, clear Done
				           	EEP_CMD <= Cmd_EEP_Hold;
							-- was a write, inc pointers
							EEP_Seq <= sEEP_WrDone1;    
						elsif (EEP_CMD = Cmd_EEP_RdStop) then    
							EEP_Seq <= sEEP_Terminate2;    
						else 
							-- hope never to reach this state
				           	EEP_CMD <= Cmd_EEP_Nop;
			            	EEP_Seq <= sEEProm99;
						end if;	
					end if;
					
	            ----------------------------------------------------------------
				--	check EEPROM-Job
	            ----------------------------------------------------------------
				when sEEProm1 =>	---
					-- asynch part: point to EEPROM-descriptor
					-- but now read from EEPROM-Job
					if ((MEM_RdData and cmd_EEP_Busy) = cmd_EEP_Busy) then
						-- EEPROMer is already running!
						if ((MEM_RdData and cmd_Mask) = cmd_EEP_Rd) then
							-- init read
				           	EEP_Seq <= sEEP_RD2;
						elsif ((MEM_RdData and cmd_Mask) = cmd_EEP_Wr) then	 	
							-- init write
				           	EEP_Seq <= sEEP_WR2;
						else
							-- nothing to to     
							-- release EEP-signals
				           	EEP_CMD <= Cmd_EEP_Nop;
				           	EEP_Seq <= sEEProm99;
						end if;
					else
						-- save EEP CEN&ADR
						if(g_patch_ee_addr = 0) then -- normal operation
							EEP_CEN  <= MEM_RdData(19 downto 16);
						else -- patch eeprom address ..
							-- .. for selected address 
							if(MEM_RdData(19 downto 16) = g_patch_addr_f) then
								EEP_CEN <= g_patch_addr_t;
							-- .. normal operation for the others
							else
								EEP_CEN  <= MEM_RdData(19 downto 16);
							end if;
						end if;
						--EEP_Addr <= MEM_RdData(11 downto  0); 
						EEP_NoB <= MEM_RdData(11 downto 0);
		                -- DPRAM_Addr 0x80 or 0x00
		                EEP_Adr80 <= MEM_RdData(15);

						-- anything todo?
						if ((MEM_RdData and cmd_Mask) = 0) then
				        	EEP_Seq <= sEEProm99;
						else
					    	EEP_Seq <= sEEP_Start2;
			           	end if;
					end if;  

	            ----------------------------------------------------------------
				--	start/prepare EEPROM Rd/Wr
	            ----------------------------------------------------------------
				when sEEP_Start2 =>	---
					-- read from EEPROM-descriptor
					--EEP_NoB <= MEM_RdData(27 downto 16);
					EEP_Addr <= MEM_RdData(27 downto 16); 
	            	if (EEP_Adr80 = H) then
		            	-- EEP RD/WR-data at 0x80
						EEP_DatPoi <= X"080"; 
					else   
		            	-- EEP RD/WR-data at 0x00
						EEP_DatPoi <= X"000"; 
					end if;		
		           	EEP_Seq <= sEEP_Start3;
				
				when sEEP_Start3 =>	---
					-- asynch part: point EEP_JOB
					-- set Done at s3, so C64Master leaves on S4 
					EEP_Done <= H;
		           	EEP_Seq <= sEEP_Start4;  
		           	
				when sEEP_Start4 =>	---
					-- asynch part: set EEP_running-bit
					-- for next entry
		           	EEP_Seq <= sEEProm0;
		           	-- leave EEPROMer

	            ----------------------------------------------------------------
				--	init EEPROM-Read
				----------------------------------------------------------------
				when sEEP_RD2 =>	---
					-- all done?
					if (EEP_NoB(11 downto 2) = "0000000000") then
						-- delete EEP_Job
	               		EEP_Seq <= sEEP_Terminate3;
					else	
		           		EEP_Seq <= sEEP_Rd3;
	               	end if;	
				
				when sEEP_RD3 =>	---
					-- set Done at s3, so C64Master leaves on S4 
					EEP_Done <= H;
	            	EEP_Seq <= sEEP_RD4;

				when sEEP_RD4 =>	---
					EEP_CMD <= Cmd_EEP_Rd4Byte;
					-- for next entry
		           	EEP_Seq <= sEEProm0;
		           	-- leave EEPROMer

	            ----------------------------------------------------------------
				--	finish EEPROM-Read
				----------------------------------------------------------------
				when sEEP_RdDone1 =>	---
					-- asynch part: store EEP_dat into Gin_EEP area
					EEP_NoB <= EEP_NoB - 4; 
					EEP_Addr <= EEP_Addr + 4;
					EEP_DatPoi <= EEP_DatPoi + 4;
	               	EEP_Seq <= sEEP_RdDone2;

				when sEEP_RdDone2 =>	---
					-- all done?
					if (EEP_NoB(11 downto 2) = "0000000000") then
						EEP_CMD <= Cmd_EEP_RdStop;
						EEP_Seq <= sEEProm99;
						---- delete command
						--EEP_Seq <= sEEP_Terminate3;
					else
						EEP_Seq <= sEEProm99;
					end if;
					
	            ----------------------------------------------------------------
				--	init EEPROM-Write
				----------------------------------------------------------------
				when sEEP_WR2 =>	---
					-- all done?
					if (EEP_NoB(11 downto 2) = "0000000000") then
						-- delete EEP_Job
	               		EEP_Seq <= sEEP_Terminate3;
	               	else
	               		EEP_Seq <= sEEP_WR3;
	               	end if;	
				
				when sEEP_WR3 =>	---
					-- asynch part: point to Gin_EEP area
					-- set Done at s3, so C64Master leaves on S4 
					EEP_Done <= H;
					EEP_Seq <= sEEP_WR4;

				when sEEP_WR4 =>	---
					-- read EEP_Dat from Gin_EEP area
				    EEP_WrDat <= MEM_RdData; 
					EEP_CMD <= Cmd_EEP_WR4Byte;
					-- for next entry
					EEP_Seq <= sEEProm0;
		           	-- leave EEPROMer

				----------------------------------------------------------------
				--	finish EEPROM-Write
				----------------------------------------------------------------
				when sEEP_WrDone1 =>	---
					EEP_NoB <= EEP_NoB - 4; 
					EEP_Addr <= EEP_Addr + 4;
					EEP_DatPoi <= EEP_DatPoi + 4;
					EEP_Seq <= sEEProm99;

				----------------------------------------------------------------
				--	all done, clear EEP_JOB
				----------------------------------------------------------------
				when sEEP_Terminate2 =>	--- delete EEP_Job ---------------------
					EEP_Seq <= sEEP_Terminate3;
					
				when sEEP_Terminate3 =>	--- delete EEP_Job ---------------------
					-- asynch part: write 0 to EEP_Job
					-- set Done at s3, so C64Master leaves on S4 
					EEP_Done <= H;
					EEP_Seq <= sEEP_Terminate4;
					
				when sEEP_Terminate4 =>	--- set INIT-DONE bit ------------------
					-- asynch part: write INIT-DONE bit
		           	EEP_CMD <= Cmd_EEP_Nop;
					eep_i2c_req <= L;
	            	EEP_Seq <= sEEProm0;
		           	-- leave EEPROMer

				----------------------------------------------------------------
				--	nothing more to do
				----------------------------------------------------------------
				when sEEProm99 =>	--- leave EEP ------------------------------
					-- be always synchron
					if (C64Clk_Seq = s3) then
						-- set Done at s3, so C64Master leaves on S4 
						EEP_Done <= H;
					elsif (C64Clk_Seq = s4) then
						EEP_Seq <= sEEProm0;
			           	-- leave EEPROMer
					end if;	
	                
				----------------------------------------------------------------
				when others => null; -------------------------------------------
				end case;
			end if; -- EP_En
		end if;	
    end process;
    
--******************************************************************************
--
--		Memory Access
--
--******************************************************************************
--  Vorsicht: zwischen MemAdr und RdData sind zweit States!
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--	asynchron part of DP-Ram read
--------------------------------------------------------------------------------
	process (MEM_Adr_1,MEM_RdData,
	         i_EEP_EN,EEP_Done,
			 EEP_Seq,EEP_DatPoi,EEP_RdDat
		) begin                             
		
	 	if (i_EEP_EN = L)	-- no MEM-Access
	 	or ((EEP_Done = H) and (EEP_Seq /= sEEP_Terminate4)) then
	 		-- free all MEM signals
		    MEM_Adr     <= (others => '0');	
		    MEM_WrData  <= (others => '0');
		    MEM_WR      <= (others => '0');
		    
		else
			MEM_Adr 	<= MEM_Adr_1	;
			MEM_WR 		<= "0000"		;
			MEM_WrData 	<= x"00000000"	;
		
	        --==================================================================
			--
			-- 		EEPROM loader
			--
	        --==================================================================
			case EEP_Seq is  
				when sEEProm0 =>
					-- point to EEPROM-Job
					if (g_MEM_RdD_REG = 1) then
						MEM_Adr <= Cfg_EEP_Desc;
					else
						MEM_Adr <= Cfg_EEP_Job;
					end if;

				when sEEProm1 =>
					-- point to EEPROM-descriptor
					if (g_MEM_RdD_REG = 0) then
						MEM_Adr <= Cfg_EEP_Desc;
					else
						MEM_Adr <= Cfg_EEP_Job;
					end if;
				
				when sEEP_Terminate3 =>
					-- delete EEP_Job (Busy&CMD only)
					MEM_Adr <= Cfg_EEP_Job;	
				   	MEM_WrData <= X"00000000";
		        	MEM_WR <= "1000";	

				when sEEP_Terminate4 =>
					-- set INIT-DONE bit
					MEM_Adr <= Cfg_INTI_DONE;	
				   	MEM_WrData <= X"80000000";
		        	MEM_WR <= "1000";	

				when sEEP_Start2 => 
					MEM_Adr <= Cfg_EEP_Job;	

				when sEEP_Start3 => 
					-- set EEP_CMD running bit 
				   	MEM_WrData <= (cmd_EEP_Busy or MEM_RdData) and x"FF000000";
		        	MEM_WR <= "1000";	

				----------------------------------------------------------------
				-- 	EEPROMer	RD init
				----------------------------------------------------------------
				when sEEP_Rd2 =>
					-- point to EEPROM-Data area
					MEM_Adr <= x"0" & EEP_DatPoi;

				----------------------------------------------------------------
				-- 	EEPROMer	RD finished, store EEP_data into Gin_EEP area
				----------------------------------------------------------------
				when sEEP_RdDone1 =>
					-- point to EEPROM-Data area
					MEM_Adr <= x"0" & EEP_DatPoi;	
					-- store EEP_dat into Gin_EEP area
				   	MEM_WrData <= EEP_RdDat;
		        	MEM_WR <= "1111";	

				----------------------------------------------------------------
				-- 	EEPROMer	WR init
				----------------------------------------------------------------
				when sEEP_WR2 =>
					-- point to EEPROM-Data area
					MEM_Adr <= x"0" & EEP_DatPoi;

				----------------------------------------------------------------
			when others => null;
			end case; 
      	end if;
    end process;
                   
                   
--------------------------------------------------------------------------------
--	I2C EEPROMer
--------------------------------------------------------------------------------
	uWrap_I2C_EEPORMer: entity I2C.I2C_EEPORMer
	generic map (
		g_ClkDiv => 312
	)
	PORT MAP(
		i_CLK			=> i_Q125				,	
        i_EEP_CMD		=> EEP_CMD				,
        i_EEP_CEN		=> EEP_CEN(2 downto 0)	,
		i_EEP_Addr		=> EEP_Addr(7 downto 0)	,
		i_EEP_WrDat		=> EEP_WrDat			,
		o_EEP_RdDat		=> EEP_RdDat			,
		o_EEP_Error		=> EEP_Error			,
		o_EEP_DONE		=> INI_Done				,
        o_I2C_SCL		=> I2C_SCL				,
		i_I2C_SDA		=> I2C_SDAi				,   
		o_I2C_SDA		=> I2C_SDAo				,   
		o_I2C_SDA_OE	=> I2C_SDA_OE	   
	);

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
