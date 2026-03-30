---------------------------------------------------------------------------
--
--  I2C primitives	
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
--  	- I2C primitives
--
--		Inp:	CMD 
--				WrDat      	up to 4 Bytes, 	D31 first out
--		Out:	DONE
--				RsDat		up to 4 Bytes	D0 latest inp
--				ACK3..0 	one per byte    D0 latest ack
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
--	18.05.2011-le : - avoid synthesis warnings:
--						use own if statment for clk_en
--						correct sensitivity list
--------------------------------------------------------------------------------
--$Rev:: 1945                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2011-05-18 16:50:45 +0200 (Mi., 18 Mai 2011)                         $
--------------------------------------------------------------------------------


---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---------------------------------------------------------------------------
-- revision information
---------------------------------------------------------------------------
-- 	Rev. 1.00   16.10.2010-FB	erste Version
---------------------------------------------------------------------------

entity I2C_Primitives is 
    generic (
		-- Clock divisor, 
		-- f.e. i_CLK=125MHz / 312 = 400kHz / 4cycl = 100kHz EEPROM-CLK
        g_ClkDiv	    : integer := 312
    );
	port (
		i_CLK		 	: in  	std_logic;

		i_ISQ_CMD		: in	std_logic_vector( 3 downto 0) := x"0";		
		i_ISQ_WrDat		: in	std_logic_vector(31 downto 0) := x"00000000";	
		o_ISQ_RdDat		: out	std_logic_vector(31 downto 0) := x"00000000";	
		o_ISQ_ACK		: out	std_logic_vector( 3 downto 0) := x"0";	
		o_ISQ_DONE		: out	std_logic := '0';	
    	            	  		
		o_I2C_SCL		: out	std_logic;		
		i_I2C_SDA		: in	std_logic;
		o_I2C_SDA		: out	std_logic;
		o_I2C_SDA_OE	: out	std_logic
    );
end;                                         

architecture impl of I2C_Primitives is   
--------------------------------------------------------------------------------
--	Commands:
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

--------------------------------------------------------------------------------	
    constant H : std_logic := '1';
    constant L : std_logic := '0';

--------------------------------------------------------------------------------
--	EEPROM
--------------------------------------------------------------------------------
	signal	ISQ_ClkCnt	: std_logic_vector(11 downto 0) := x"000";		
	
	signal	ISQ_CLK		: std_logic := L;		
	signal	ISQ_CLK_EN	: std_logic := L;		
	signal	I2C_SCL		: std_logic := H;		
	signal	I2C_SDA		: std_logic := H;		
	signal	I2C_SDA_OE	: std_logic := L;		
			
	signal	ISQ_WrDat	: std_logic_vector(31 downto 0) := x"00000000";		
	signal	ISQ_RdDat	: std_logic_vector(31 downto 0) := x"00000000";		
	signal	ISQ_ACK		: std_logic_vector( 3 downto 0) := x"0";	
--	signal	ISQ_DONE	: std_logic := L;	

	signal	ISQ_BitCnt	: std_logic_vector( 3 downto 0) := x"0";		
	signal	ISQ_ByteCnt	: std_logic_vector( 3 downto 0) := x"0";		
	-- to terminate the READ
	signal	I2C_SetNACK	: std_logic := L;		

    type sI2CSeq is (
		s_idle,
		s_Start0,s_Start1,s_Start2,s_Start3,s_Start4,s_Start5,
		s_RdByte0,s_RdByte1,s_RdByte2,s_RdByte3,
		s_WrByte0,s_WrByte1,s_WrByte2,s_WrByte3,
		s_RdAck0,s_RdAck1,s_RdAck2,s_RdAck3,s_RdAck4,s_RdAck5,
		s_WrAck0,s_WrAck1,s_WrAck2,s_WrAck3,s_WrAck4,s_WrAck5,
		s_Stop0,s_Stop1,s_Stop2,s_Stop3,s_Stop4,s_Stop5,
		s_End
	);
	signal ISQ_Seq		: sI2CSeq := s_idle;


	-- 4 x 100kHz : 125MHz/400kHz = 312
    constant Cfg_ISQ_ClkDiv	:  integer := g_ClkDiv;

     
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------



--------------------------------------------------------------------------------
begin -- of architecture CM_Seq    
--------------------------------------------------------------------------------
	
--------------------------------------------------------------------------------
--	In/Outs
--------------------------------------------------------------------------------
	o_I2C_SCL 	<= I2C_SCL;
	o_I2C_SDA 	<= I2C_SDA;
	o_I2C_SDA_OE<= I2C_SDA_OE;
	

    o_ISQ_RdDat	<= ISQ_RdDat;
    o_ISQ_ACK	<= ISQ_ACK;


	process(ISQ_Seq) begin
		if (ISQ_Seq = s_End) then
        	o_ISQ_DONE <= H;
		else
        	o_ISQ_DONE <= L;
		end if;
	end process;              

--------------------------------------------------------------------------------
--	EEPROM	ClockDiv
--------------------------------------------------------------------------------
	ISQ_CLK	<= i_CLK;
		
	process (ISQ_CLK) begin
    	if rising_edge(ISQ_CLK) then 
		
	        if (ISQ_ClkCnt = Cfg_ISQ_ClkDiv) then
	        	ISQ_CLK_EN <= H;                   
	        	ISQ_ClkCnt <= x"000";
	        else
	        	ISQ_CLK_EN <= L;
	        	ISQ_ClkCnt <= ISQ_ClkCnt + 1;
	        end if;

		end if;
    end process;

	
--------------------------------------------------------------------------------
--	I2C Sequencer
--------------------------------------------------------------------------------
	process (ISQ_CLK) begin
    	if rising_edge(ISQ_CLK) then
    		if (ISQ_CLK_EN = H) then

    	    	if (i_ISQ_CMD = Cmd_ISQ_NOP) then
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= H;
	    		    I2C_SDA_OE 	<= L;
    	    	elsif (i_ISQ_CMD = Cmd_ISQ_Hold) then
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= H;
	    		    I2C_SDA_OE 	<= H;
				end if;
				
	   			case ISQ_Seq is 
            	
				when s_idle =>
					-- 
					I2C_SetNACK <= L;
					-- get WrByte data
					ISQ_WrDat <= i_ISQ_WrDat; 
					-- bit 7..0
					ISQ_BitCnt <= x"8";               
            	    
            	    case i_ISQ_CMD is
					when Cmd_ISQ_Start =>
						ISQ_Seq <= s_Start0;
						
					when Cmd_ISQ_Wr1Byte =>        
						ISQ_ByteCnt <= x"1";
						ISQ_Seq <= s_WrByte0;
					when Cmd_ISQ_Wr2Byte =>
						ISQ_ByteCnt <= x"2";
						ISQ_Seq <= s_WrByte0;
					when Cmd_ISQ_Wr3Byte =>
						ISQ_ByteCnt <= x"3";
						ISQ_Seq <= s_WrByte0;
					when Cmd_ISQ_Wr4Byte =>
						ISQ_ByteCnt <= x"4";
						ISQ_Seq <= s_WrByte0;
            	
					when Cmd_ISQ_Rd1Byte =>
						ISQ_RdDat <= x"00000000";
						ISQ_ByteCnt <= x"1";
						ISQ_Seq <= s_RdByte0; 
					when Cmd_ISQ_Rd2Byte =>
						ISQ_RdDat <= x"00000000";
						ISQ_ByteCnt <= x"2";
						ISQ_Seq <= s_RdByte0; 
					when Cmd_ISQ_Rd3Byte =>
						ISQ_RdDat <= x"00000000";
						ISQ_ByteCnt <= x"2";
						ISQ_Seq <= s_RdByte0; 
					when Cmd_ISQ_Rd4Byte =>
						ISQ_RdDat <= x"00000000";
						ISQ_ByteCnt <= x"4";
						ISQ_Seq <= s_RdByte0;
						
					when Cmd_ISQ_RdStop =>
						-- Read kann nur beendet werden, indem ein Byte 
						-- gelesen und mit NACK abgeschlossen  wird
						-- Wenn wir alles 00000000_0 schicken, sollte
						-- sicher ein Bit als NACK gesehen wird
						ISQ_WrDat <= x"00000000";
						ISQ_ByteCnt <= x"1";
						I2C_SetNACK <= H;
						ISQ_Seq <= s_WrByte0;
            	
					when Cmd_ISQ_WrStop =>
						ISQ_Seq <= s_Stop0;
            	
					when others => null;
					end case; 
            	
				--------------------------------------------------------------------
				--	set Start Condition
				--------------------------------------------------------------------
				--  SCL		----__  _--__--__-- .. -__--__--_  __--__  __----
				--	SDA		---___  00001111222 .. 5566667777  xxxAxX  ____--
				--------------------------------------------------------------------
				when s_Start0 =>	--- Start condition ----------------------------        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= H;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Start1;
					
				when s_Start1 =>        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= H;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Start2;
					
				when s_Start2 =>        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= H;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Start3;
					
				when s_Start3 =>        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Start4;
					
				when s_Start4 =>        
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Start5;
					
				when s_Start5 =>        
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    -- release this state with SDA = aktive low
	    		    I2C_SDA_OE 	<= H; 
            	
					ISQ_Seq <= s_End;
            	
				--------------------------------------------------------------------
				--	write a Byte
				--------------------------------------------------------------------
				--  SCL		----__  _--__--__-- .. -__--__--_  __--__  __----
				--	SDA		---___  00001111222 .. 5566667777  xxxAxX  ____--
				--------------------------------------------------------------------
				when s_WrByte0 =>        
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= ISQ_WrDat(31);
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_WrByte1;
					
				when s_WrByte1 =>        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= ISQ_WrDat(31);
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_WrByte2;
					
				when s_WrByte2 =>        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= ISQ_WrDat(31);
	    		    I2C_SDA_OE 	<= H;           
	    		    -- one bit done
	    		    ISQ_BitCnt <= ISQ_BitCnt - 1;
					ISQ_Seq <= s_WrByte3;
					
				when s_WrByte3 =>        
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= ISQ_WrDat(31);
	    		    
	    		    if (ISQ_BitCnt > 0) then
		    		    I2C_SDA_OE 	<= H; 
		    		else     
		    			-- release SDA to tristate for EEPROMs-ACK
		    		    I2C_SDA_OE 	<= L; 
		    		end if;    
					
					-- shift data-byte
            	    ISQ_WrDat(31 downto 1) <= ISQ_WrDat(30 downto 0); 
            	
					-- all 8 bits done?
					if (ISQ_BitCnt > x"0") then 
						-- no, do next bit
						ISQ_Seq <= s_WrByte0;
					else              
						-- one Byte done
						ISQ_ByteCnt <= ISQ_ByteCnt- 1; 
						if (I2C_SetNACK = H) then  
							-- this byte was written only to set ReadEnd_NACK
							ISQ_Seq <= s_WrAck0;    
						else
							ISQ_Seq <= s_RdAck0;    
						end if;	
					end if;
            	                 
				--------------------------------------------------------------------
				--	read the ACK bit
				--------------------------------------------------------------------
				--  SCL		----__  _--__--__-- .. -__--__--_  __--__  __----
				--	SDA		---___  00001111222 .. 5566667777  xxxAxX  ____--
				--
				--	we make this state longer to see it better in the data-flow
				--------------------------------------------------------------------
				when s_RdAck0 => 	-- get Ack -------------------------------------
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= L;
					ISQ_Seq <= s_RdAck1; 
					
				when s_RdAck1 =>
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= L;
					ISQ_Seq <= s_RdAck2;
					
				when s_RdAck2 =>
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= L;
					ISQ_Seq <= s_RdAck3;
					
				when s_RdAck3 =>
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= L;
            	    -- shift & save Ack3..0  (ACK=low; NACK=high)                    	
					ISQ_ACK <= ISQ_ACK(2 downto 0) & i_I2C_SDA;
					ISQ_Seq <= s_RdAck4;
					
				when s_RdAck4 =>
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= L;
					ISQ_Seq <= s_RdAck5;
					
				when s_RdAck5 =>
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    -- release this state with SDA = still tristate
	    		    I2C_SDA_OE 	<= L;
            	
					-- for next bit 7..0 
					ISQ_BitCnt <= x"8";               
            	
					if (ISQ_ByteCnt > x"0") then
	        	        case i_ISQ_CMD is   
						when Cmd_ISQ_Wr2Byte 
						   | Cmd_ISQ_Wr3Byte 
						   | Cmd_ISQ_Wr4Byte =>
							ISQ_Seq <= s_WrByte0;
						when others =>
							ISQ_Seq <= s_End;
						end case; 
					else	         
						ISQ_Seq <= s_End;
					end if;
					
				--------------------------------------------------------------------
				--	read a Byte
				--------------------------------------------------------------------
				--  SCL		----__  _--__--__-- .. -__--__--_  __--__  __----
				--	SDA		---___  00001111222 .. 5566667777  xxxAxX  ____--
				--------------------------------------------------------------------
				when s_RdByte0 => 	-- get RdByte -------------------------------------
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= H;
	    		    I2C_SDA_OE 	<= L;
					ISQ_Seq <= s_RdByte1; 
					
				when s_RdByte1 =>
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= H;
	    		    I2C_SDA_OE 	<= L;
					ISQ_Seq <= s_RdByte2;
					
				when s_RdByte2 =>
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= H;
	    		    I2C_SDA_OE 	<= L;
	    		    -- one bit done
	    		    ISQ_BitCnt <= ISQ_BitCnt - 1;
            	    -- save RdBit and shift data-byte
					ISQ_RdDat(31 downto 0) <= ISQ_RdDat(30 downto 0) & i_I2C_SDA;
					ISQ_Seq <= s_RdByte3;
					
				when s_RdByte3 =>
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= H;
	    		    -- release this state with SDA = still tristate
	    		    I2C_SDA_OE 	<= L;
					
					-- all 8 bits done?
					if (ISQ_BitCnt > x"0") then 
						-- no, do next bit
						ISQ_Seq <= s_RdByte0;
					else              
						-- one Byte done
						ISQ_ByteCnt <= ISQ_ByteCnt - 1;
						ISQ_Seq <= s_WrAck0;    
					end if;
            	
				--------------------------------------------------------------------
				--	write the ACK bit
				--------------------------------------------------------------------
				--  SCL		----__  _--__--__-- .. -__--__--_  __--__  __----
				--	SDA		---___  00001111222 .. 5566667777  xxxAxX  ____--
				--
				--	we make this state longer to see it better in the data-flow
				--------------------------------------------------------------------
				when s_WrAck0 => 	-- get Ack -------------------------------------
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= I2C_SetNACK;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_WrAck1; 
					
				when s_WrAck1 =>
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= I2C_SetNACK;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_WrAck2;
					
				when s_WrAck2 =>
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= I2C_SetNACK;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_WrAck3;
					
				when s_WrAck3 =>
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= I2C_SetNACK;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_WrAck4;
					
				when s_WrAck4 =>
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= L;
            	
            	    -- save6shift Ack3..0                     	
					ISQ_ACK <= ISQ_ACK(2 downto 0) & i_I2C_SDA;
            	
					ISQ_Seq <= s_WrAck5;
					
				when s_WrAck5 =>
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    -- release this state with SDA = aktive low
	    		    I2C_SDA_OE 	<= H;
            	
					-- for next bit 7..0 
					ISQ_BitCnt <= x"8";               
            	
					if (ISQ_ByteCnt > x"0") then
	        	        case i_ISQ_CMD is   
							
						when Cmd_ISQ_Rd2Byte 
						   | Cmd_ISQ_Rd3Byte 
						   | Cmd_ISQ_Rd4Byte =>
							ISQ_Seq <= s_RdByte0;
							
						when others =>
							ISQ_Seq <= s_End;
						end case; 
					else	         
						ISQ_Seq <= s_End;
					end if;
					
				--------------------------------------------------------------------
				--	set Stop Condition
				--------------------------------------------------------------------
				--  SCL		----__  _--__--__-- .. -__--__--_  __--__  __----
				--	SDA		---___  00001111222 .. 5566667777  xxxAxX  ____--
				--------------------------------------------------------------------
				when s_Stop0 =>	--- Stop condition ----------------------------        
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Stop1;
					
				when s_Stop1 =>        
	    		    I2C_SCL 	<= L;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Stop2;
					
				when s_Stop2 =>        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Stop3;
					
				when s_Stop3 =>        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= L;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Stop4;
					
				when s_Stop4 =>        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= H;
	    		    I2C_SDA_OE 	<= H;
					ISQ_Seq <= s_Stop5;
					
				when s_Stop5 =>        
	    		    I2C_SCL 	<= H;
	    		    I2C_SDA 	<= H;
	    		    -- release this state with SDA = (H) tristate
	    		    I2C_SDA_OE 	<= L; 
					ISQ_Seq <= s_End;
            	
				--------------------------------------------------------------------
				--	end
				--------------------------------------------------------------------
				when s_End =>  
	    		    I2C_SCL 	<= I2C_SCL ;
	    		    I2C_SDA 	<= I2C_SDA ;
	    		    I2C_SDA_OE 	<= I2C_SDA_OE;
					-- s_End makes ISQ_DONE <= H;
					if ((i_ISQ_CMD = Cmd_ISQ_NOP) or (i_ISQ_CMD = Cmd_ISQ_Hold)) then
						-- ISQ_DONE <= L;
						ISQ_Seq <= s_Idle;
					end if;
				when others => null;
				end case; 
			end if;
		end if;
    end process;   

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
