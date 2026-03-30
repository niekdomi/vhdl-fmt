--------------------------------------------------------------------------------
--
--  FIFO_4kByte_x32.vhd
--
--------------------------------------------------------------------------------
--
--  project     : FIFO
--  programmer  : F. Baschung, INDEL AG
--  date        : 31.10.2011
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--
--------------------------------------------------------------------------------
--$Rev:: 1973                                                                  $
--$Author:: fb                                                           $
--$Date:: 2011-06-16 08:57:47 +0200 (Do, 16 Jun 2011)                          $
--------------------------------------------------------------------------------
--	25.10.2017-FB	+ synched LEVEL for both sides
-- 					+ unregisteres DATAout for faster access
--------------------------------------------------------------------------------

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

LIBRARY BRAM;
USE BRAM.ALL;  

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
entity FIFO_4kByte_i32_o32 is 
	port (
		i_Reset  	: IN  std_logic 					:= '0';

		i_CLKin  	: IN  std_logic;
		i_ENin   	: IN  std_logic 					:= '0';
		i_DATAin 	: IN  std_logic_vector(31 downto 0) := (others => '0');
		
		i_CLKout  	: IN  std_logic;
		i_ENout   	: IN  std_logic 					:= '0';
		-- unregistered DATAout
		o_DATAout  	: OUT std_logic_vector(31 downto 0) := (others => '0');
		-- registered DATAout
		o_REGout  	: OUT std_logic_vector(31 downto 0) := (others => '0');
        
        -- CLKin  snychron Level
		o_LEVELin  	: OUT std_logic_vector( 9 downto 0) := (others => '0');
        -- CLKout snychron Level
		o_LEVELout 	: OUT std_logic_vector( 9 downto 0) := (others => '0'); 
		-- asynchron Level , needs to be synchronized
		o_Level	  	: OUT std_logic_vector( 9 downto 0) := (others => '0')
	);
end FIFO_4kByte_i32_o32;

architecture impl OF FIFO_4kByte_i32_o32 is
--------------------------------------------------------------------------------
	signal 	ADDRin 		: std_logic_vector( 9 downto 0) := (others => '0');
	signal 	ADDRout 	: std_logic_vector( 9 downto 0) := (others => '0');

	signal 	Level	 	: std_logic_vector( 9 downto 0) := (others => '0');
	signal 	pLevelin	: std_logic_vector( 9 downto 0) := (others => '0');
	signal 	pLevelout	: std_logic_vector( 9 downto 0) := (others => '0');

--------------------------------------------------------------------------------
	signal	BRAM_Clk_A  : std_logic                     := '0';                
	signal	BRAM_EN_A   : std_logic                   	:= '1';                
	signal	BRAM_WEN_A  : std_logic_vector( 3 downto 0)	:= (others => '0');         
	signal	BRAM_Addr_A : std_logic_vector( 9 downto 0) := (others => '0');
	signal	BRAM_Din_A  : std_logic_vector(31 downto 0) := (others => '0');   
	signal	BRAM_Dout_A : std_logic_vector(31 downto 0) := (others => '0');   

	signal	ENout_0  	: std_logic 					:= '0';
	signal	ENout_1  	: std_logic 					:= '0';
	
	signal	BRAM_Clk_B  : std_logic 					:= '0';
	signal	BRAM_EN_B   : std_logic 					:= '1';
	signal	BRAM_WEN_B  : std_logic_vector( 3 downto 0) := (others => '0');
	signal	BRAM_Addr_B : std_logic_vector( 9 downto 0) := (others => '0');
	signal	BRAM_Din_B  : std_logic_vector(31 downto 0) := (others => '0');   
	signal	BRAM_Dout_B : std_logic_vector(31 downto 0) := (others => '0');   

--------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
	o_Level 	<= Level;	
	BRAM_Clk_A 	<= i_CLKin;
	BRAM_Clk_B 	<= i_CLKout;
	
	-- unregistered Data
	o_DATAout <= BRAM_Dout_B after 5 ns;
	
   
	process (i_CLKin) begin     
		if rising_edge(i_CLKin) then 
			BRAM_Din_A <= (others => '0');
			BRAM_WEN_A <= (others => '0');
			ADDRin 	   <= ADDRin; 
		   
		   	if (i_Enin = H) then 
				BRAM_Din_A <= i_DATAin;
				BRAM_WEN_A <= "1111";
				ADDRin <= ADDRin + 1; 
			end if;
		end if;
	end process;


--------------------------------------------------------------------------------
	-- synch Asyn-LEVEL to i_CLKin
	process (i_CLKin) begin     
		if rising_edge(i_CLKin) then  
		 
			pLevelin <= Level;
			if (pLevelin = Level) then
				o_Levelin <= pLevelin;
			end if;    
			
		end if;
	end process;

	-- synch Asyn-LEVEL to i_CLKout
	process (i_CLKout) begin     
		if rising_edge(i_CLKout) then  
		 
			pLevelout <= Level;
			if (pLevelout = Level) then
				o_Levelout <= pLevelout;
			end if;         
			
		end if;
	end process;

	
--------------------------------------------------------------------------------
--	read a byte from FIFO	
--------------------------------------------------------------------------------
	BRAM_Addr_A <= ADDRin;
	BRAM_Addr_B <= ADDRout;

	process (i_CLKout) begin
		if rising_edge(i_CLKout) then
			-- needs two clock till new data
			ENout_0 <= i_ENout; 

			if (ENout_0 = H) then
				o_REGout <= BRAM_Dout_B;
			else
				o_REGout <= (others => '0');
			end if;

			if (i_Reset = H) then
			  	ADDRout <= (others => '0');
			else
				if (i_ENout = '1') and (Level > 0) then  
					ADDRout  <= ADDRout + 1; 
				end if;
			end if;
				
		end if;
	end process;
	
	
	process (ADDRin,ADDRout) begin
	    Level <= (ADDRin - ADDRout) after 3 ns;
	end process;
	
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
inst_BRAM: entity BRAM.BRAM_4kByte_A32_B32  
	port map (
		i_BRAM_Clk_A  	=>  BRAM_Clk_A 		,
		i_BRAM_WEN_A  	=>  BRAM_WEN_A   	,
		i_BRAM_Addr_A 	=>  BRAM_Addr_A  	,
		o_BRAM_Din_A  	=>  BRAM_Dout_A  	,
		i_BRAM_Dout_A  	=>  BRAM_Din_A   	,
		                                 	
		i_BRAM_Clk_B  	=>  BRAM_Clk_B   	,
		i_BRAM_Addr_B 	=>  BRAM_Addr_B  	,
		o_BRAM_Din_B  	=>  BRAM_Dout_B  	,
		i_BRAM_Dout_B  	=>  BRAM_Din_B   
	);
	
--------------------------------------------------------------------------------
end architecture impl;
--------------------------------------------------------------------------------
