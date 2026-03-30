---------------------------------------------------------------------------
--
--  EEPROM	Read/Write
--
---------------------------------------------------------------------------
--
--  project     : I2C EEPROM Read/Write 
--  programmer  : F:Baschung, INDEL AG
--  date        : 16.10.2010
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	-  EEPROM	Read/Write 
--
---------------------------------------------------------------------------
--
--	Fehlt noch:
--  
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	Rev. 1.00   16.10.2010-FB	erste Version
--	18.05.2011-le : - add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 1956                                                                  $
--$Author:: Administrator                                                      $
--$Date:: 2011-05-31 14:22:57 +0200 (Di., 31 Mai 2011)                         $
--------------------------------------------------------------------------------

---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;

LIBRARY I2C;
USE I2C.ALL;

entity I2C_EEPORMer is 
    generic (
		-- Clock divisor, 
		-- f.e. i_CLK=125MHz / 312 = 400kHz / 4cycl = 100kHz EEPROM-CLK
        g_ClkDiv	    : integer := 312
    );
	port (
		i_CLK		 	: in  	std_logic;

		i_EEP_CMD		: in	std_logic_vector( 3 downto 0) := x"0";		
		i_EEP_CEN		: in	std_logic_vector( 2 downto 0) := "000";		
		i_EEP_Addr		: in	std_logic_vector( 7 downto 0) := x"00";	
		i_EEP_WrDat		: in	std_logic_vector(31 downto 0) := x"00000000";	
		o_EEP_RdDat		: out	std_logic_vector(31 downto 0) := x"00000000";	
		o_EEP_Error		: out	std_logic := '0';	
		o_EEP_DONE		: out	std_logic := '0';	

		o_I2C_SCL		: out	std_logic;		
		i_I2C_SDA		: in	std_logic;
		o_I2C_SDA		: out	std_logic;
		o_I2C_SDA_OE	: out	std_logic
    );
end;                                         

architecture impl of I2C_EEPORMer is   
--------------------------------------------------------------------------------
--	Commands:
--------------------------------------------------------------------------------
    constant Cmd_EEP_Nop:  		std_logic_vector := x"0"; 
    constant Cmd_EEP_Wr4Byte:	std_logic_vector := x"4";
    constant Cmd_EEP_Rd4Byte:	std_logic_vector := x"C"; 

    constant Cmd_EEP_Hold:  	std_logic_vector := x"8"; 
    constant Cmd_EEP_RdStop:  	std_logic_vector := x"F"; 
     
--------------------------------------------------------------------------------
    constant Cmd_ISQ_NOP	:  std_logic_vector := x"0"; 

    constant Cmd_ISQ_Wr1Byte:  std_logic_vector := x"1"; 
    constant Cmd_ISQ_Wr2Byte:  std_logic_vector := x"2"; 
    constant Cmd_ISQ_Wr3Byte:  std_logic_vector := x"3"; 
    constant Cmd_ISQ_Wr4Byte:  std_logic_vector := x"4";

    constant Cmd_ISQ_Rd1Byte:  std_logic_vector := x"9"; 
    constant Cmd_ISQ_Rd2Byte:  std_logic_vector := x"A"; 
    constant Cmd_ISQ_Rd3Byte:  std_logic_vector := x"B"; 
    constant Cmd_ISQ_Rd4Byte:  std_logic_vector := x"C"; 
     
    constant Cmd_ISQ_Start	:  std_logic_vector := x"7";
    constant Cmd_ISQ_Hold	:  std_logic_vector := x"8";
    
    constant Cmd_ISQ_RdStop	:  std_logic_vector := x"E"; 
    constant Cmd_ISQ_WrStop	:  std_logic_vector := x"F"; 
                             	
-- ein Write-Retry dauert ca 55us
-- ältere EEPs brauchen bis 10ms zum Schreiben
-- 10000/55 = 181 = xB5
    constant Cfg_EEP_MaxTry	:	std_logic_vector := x"B5";

--------------------------------------------------------------------------------	
    constant H : std_logic := '1';
    constant L : std_logic := '0';

--------------------------------------------------------------------------------
--	EEPROM
--------------------------------------------------------------------------------
	signal	EEP_Error	: std_logic := L;	
	signal	EEP_DONE	: std_logic := L;	

	signal	EEP_MaxTry	: std_logic_vector( 7 downto 0) := x"00";	
			
	signal	ISQ_CMD		: std_logic_vector( 3 downto 0) := x"0";	
	signal	ISQ_WrDat	: std_logic_vector(31 downto 0) := x"00000000";		
	signal	ISQ_RdDat	: std_logic_vector(31 downto 0) := x"00000000";		
	signal	ISQ_ACK		: std_logic_vector( 3 downto 0) := x"0";	
	signal	ISQ_DONE	: std_logic := L;	

    type tEEP_Seq is (
		sEP_idle,
		sEP_Wcmd,
		sEP_StartWrite0,sEP_StartWrite1,sEP_StartWrite2,
		sEP_SeqWrite0,
		sEP_StartRead0,sEP_StartRead1,sEP_StartRead2,sEP_StartRead3,sEP_StartRead4,
		sEP_SeqRead0,sEP_SeqRead1,
		sEP_Stop,
		sEP_TryError,
		sEP_End
	);
	signal EEP_Seq		: tEEP_Seq := sEP_idle;


	-- 4 x 100kHz : 125MHz/400kHz = 312
    constant Cfg_EEP_ClkDiv	:  integer := g_ClkDiv;

     
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------



--------------------------------------------------------------------------------
begin -- of architecture CM_Seq    
--------------------------------------------------------------------------------
	
--------------------------------------------------------------------------------
--	In/Outs
--------------------------------------------------------------------------------
	o_EEP_RdDat <= ISQ_RdDat;
	o_EEP_Error	<= EEP_Error;	
	o_EEP_DONE	<= EEP_DONE;	
	
--------------------------------------------------------------------------------
--	test
--------------------------------------------------------------------------------
	process (i_CLK) begin
    	if rising_edge(i_CLK) then

           	EEP_Error <= L;
           	EEP_DONE <= L;

			if (ISQ_DONE = H) then			
				ISQ_CMD <= Cmd_ISQ_Hold;
			
			elsif ((ISQ_CMD = Cmd_ISQ_NOP) or (ISQ_CMD = Cmd_ISQ_Hold)) then
                ----------------------------------------------------------------
				-- EEPROM Tester
                ----------------------------------------------------------------
				case EEP_Seq is
                ----------------------------------------------------------------
                ----------------------------------------------------------------
				when sEP_Idle =>
                    EEP_Seq <= sEP_Wcmd; 
					
                ----------------------------------------------------------------
				--	command decoder
				----------------------------------------------------------------
				when sEP_Wcmd =>   
					EEP_MaxTry <= Cfg_EEP_MaxTry; 
					
					case i_EEP_CMD is
					when Cmd_EEP_Nop =>
						ISQ_CMD <= Cmd_ISQ_Nop;  

					when Cmd_EEP_Hold =>
						ISQ_CMD <= Cmd_ISQ_Hold;  

					when Cmd_EEP_Wr4Byte =>
						ISQ_CMD <= Cmd_ISQ_Hold;  
						if (i_EEP_Addr(3 downto 0) = x"0") then 
		                    EEP_Seq <= sEP_StartWrite0; 
		                else
		                    EEP_Seq <= sEP_SeqWrite0; 
		                end if;    
					when Cmd_EEP_Rd4Byte => 
						ISQ_CMD <= Cmd_ISQ_Hold;  
						if (i_EEP_Addr = x"00") then 
		                    EEP_Seq <= sEP_StartRead0; 
		                else
		                    EEP_Seq <= sEP_SeqRead0; 
		                end if;
		                 
					when Cmd_EEP_RdStop =>
						ISQ_CMD <= Cmd_ISQ_RdStop;  
	                    EEP_Seq <= sEP_End;
							                   
					when others => null; 
					end case;


                ----------------------------------------------------------------
				--	Set Write-Addr
                ----------------------------------------------------------------
				when sEP_StartWrite0 =>	--- set Start Condition ----------------
					-- Start Condition
					ISQ_CMD <= Cmd_ISQ_Start;  
					EEP_MaxTry <= EEP_MaxTry - 1;
                    EEP_Seq <= sEP_StartWrite1;

				
				when sEP_StartWrite1 =>	--- set WR and Addr --------------------
					-- DTI-A, ChipEn , WR ; Addr
					ISQ_WrDat <= x"A" & i_EEP_CEN(2 downto 0) & L & i_EEP_Addr & x"0000";
					ISQ_CMD <= Cmd_ISQ_Wr2Byte;
                    EEP_Seq <= sEP_StartWrite2;

				when sEP_StartWrite2 =>	-- 
					if ((ISQ_ACK(1) = H) or (ISQ_ACK(0) = H))  then 
						if (EEP_MaxTry > 0) then
		                    EEP_Seq <= sEP_StartWrite0;
	                	else
		                	EEP_Error <= H;
		                    EEP_Seq <= sEP_End;
	                	end if;    
					else 
	                    EEP_Seq <= sEP_SeqWrite0;
	                end if;
					               
                ----------------------------------------------------------------
				--	Sequential Write
                ----------------------------------------------------------------
				when sEP_SeqWrite0 =>  	--- sequencial write ------------------- 
					ISQ_WrDat <= i_EEP_WrDat;
					ISQ_CMD <= Cmd_ISQ_Wr4Byte;
					-- kommt gleich noch mehr?
					if (i_EEP_Addr(3 downto 0) < x"C") then
						-- es kommt noch was, noch nicht schreiben 
	                    EEP_Seq <= sEP_End;
					else
						-- set Stop Condition to initiate EEPROM-writing
	                    EEP_Seq <= sEP_Stop;
					end if;
					
                ----------------------------------------------------------------
				--	Set Read-Addr
                ----------------------------------------------------------------
				when sEP_StartRead0 =>	--- set Start Condition ----------------
					-- Start Condition
					ISQ_CMD <= Cmd_ISQ_Start;
					EEP_MaxTry <= EEP_MaxTry - 1;
                    EEP_Seq <= sEP_StartRead1;

				
				when sEP_StartRead1 =>	--- set WR and Addr --------------------
					-- DTI-A, ChipEn , WR ; Addr
					ISQ_WrDat <= x"A" & i_EEP_CEN(2 downto 0) & L & i_EEP_Addr & x"0000";
					ISQ_CMD <= Cmd_ISQ_Wr2Byte;
                    EEP_Seq <= sEP_StartRead2;

				when sEP_StartRead2 =>	-- 
					if ((ISQ_ACK(1) = H) or (ISQ_ACK(0) = H))  then 
						if (EEP_MaxTry > 0) then
		                    EEP_Seq <= sEP_StartRead0;
	                	else
		                	EEP_Error <= H;
		                    EEP_Seq <= sEP_End;
	                	end if;    
					else 
	                    EEP_Seq <= sEP_StartRead3;
	                end if;
					               
				when sEP_StartRead3 =>	--- set Start Condition ----------------
					-- Start Condition
					ISQ_CMD <= Cmd_ISQ_Start;
                    EEP_Seq <= sEP_StartRead4;

				when sEP_StartRead4 =>	--- set RD and Addr --------------------
					-- DTI-A, ChipEn , RD
					ISQ_WrDat <= x"A" & i_EEP_CEN(2 downto 0) & H & x"000000";
					ISQ_CMD <= Cmd_ISQ_Wr1Byte;
                    EEP_Seq <= sEP_SeqRead0;

                ----------------------------------------------------------------
				--	Sequential Read
                ----------------------------------------------------------------
				when sEP_SeqRead0 => 	--- sequencial Read -------------------
					-- not used WrDat
					ISQ_WrDat <= x"00000000";
					ISQ_CMD <= Cmd_ISQ_Rd4Byte;
                    EEP_Seq <= sEP_SeqRead1;
					
				when sEP_SeqRead1 => 	--- sequencial Read -------------------
	                EEP_Seq <= sEP_End;
 					
                ----------------------------------------------------------------
                --	Stop condition
                ----------------------------------------------------------------
				when sEP_Stop =>
                	EEP_Error <= EEP_Error;
					ISQ_CMD <= Cmd_ISQ_WrStop;
	                EEP_Seq <= sEP_End;
                    
                ----------------------------------------------------------------
                when sEP_End =>
                	EEP_Error <= EEP_Error;
                	EEP_DONE <= H;
                	if ((i_EEP_CMD = Cmd_EEP_Nop) or (i_EEP_CMD = Cmd_EEP_Hold)) then
		                EEP_Seq <= sEP_Idle;
		            end if;    
                	 
                ----------------------------------------------------------------
				when others => null; -------------------------------------------
				end case;
                ----------------------------------------------------------------
			end if;
						
		end if;
	end process;
	

--------------------------------------------------------------------------------
--	I2C EEPROMer
--------------------------------------------------------------------------------
	uWrap_I2C_Primitives: entity I2C.I2C_Primitives
	generic map (
--		g_ClkDiv => 312	-- 125MHz/312 /4 = 100kHz
		g_ClkDiv => 79	-- 125MHz/ 79 /4 = 395kHz
	)
	PORT MAP(
		i_CLK			=> i_CLK		,	
        i_ISQ_CMD		=> ISQ_CMD		,
		i_ISQ_WrDat		=> ISQ_WrDat	,
		o_ISQ_RdDat		=> ISQ_RdDat	,
		o_ISQ_ACK		=> ISQ_ACK		,
		o_ISQ_DONE		=> ISQ_DONE		,
        o_I2C_SCL		=> o_I2C_SCL	,
		i_I2C_SDA		=> i_I2C_SDA	,   
		o_I2C_SDA		=> o_I2C_SDA	,   
		o_I2C_SDA_OE	=> o_I2C_SDA_OE	   
	);

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
