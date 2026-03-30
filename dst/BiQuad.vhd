---------------------------------------------------------------------------
--
--	BiQuad Filter
--
---------------------------------------------------------------------------
--
--  project     : BiQuad Filter
--  programmer  : F:Baschung, INDEL AG
--  date        : 09.03.2012
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--  	- BiQuad Filter
--
---------------------------------------------------------------------------
-- includes 
---------------------------------------------------------------------------  	     
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
--USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE ieee.numeric_std.ALL;    

--------------------------------------------------------------------------------
--	Die Biquad-Parameter berechnet man am einfachsten mit einem SAC
--	Die Frequenz ist ein Verhätlinss vom Clock
--	zB bei ADC mit 100M-Sample	und Filter Freqenz 10MHz 	(f bei 1/10)
--	--> nehme SAC mit 12kHz Abtastrate und FilterFreq bei 1.2kHz (f bei 1/10)
--	Die Parameter können dann direkt übernommen werden 
--------------------------------------------------------------------------------
entity BiQuad is
	port (
		-- doppelter Clock von ADC-SamplingRate
		i_CLKx2				: in	std_logic;
		
		--	Input value
		i_RawVal			: in	std_logic_vector(15 downto 0);
		
		--	Format			s1.kkkk_kkkk_kkkk_kkkk
		i_b0				: in	std_logic_vector(17 downto 0);
		i_b1				: in	std_logic_vector(17 downto 0);
		i_b2				: in	std_logic_vector(17 downto 0);
		i_a1				: in	std_logic_vector(17 downto 0);
		i_a2				: in	std_logic_vector(17 downto 0);
		
		-- filtered Output value
		o_FiltVal           : out	std_logic_vector(15 downto 0)

    );
end;

architecture impl of BiQuad is 
--------------------------------------------------------------------------------
	constant H : std_logic := '1';
	constant L : std_logic := '0';

--------------------------------------------------------------------------------
	signal b0	 			: signed(17 downto 0);
	signal b1	 			: signed(17 downto 0);
	signal b2	 			: signed(17 downto 0);
	signal a1	 			: signed(17 downto 0);
	signal a2	 			: signed(17 downto 0);

--------------------------------------------------------------------------------

	signal	X			: signed(17 downto 0) 			:= (others => L);			
	signal	Y			: signed(35 downto 0) 			:= (others => L);
	alias	Yh			: signed(17 downto 0) is Y(33 downto 16);
				
	signal	Z1a			: signed(35 downto 0) 			:= (others => L);			
	signal	Z2a		 	: signed(35 downto 0) 			:= (others => L);
	signal	Z1			: signed(35 downto 0) 			:= (others => L);			
	signal	Z2		 	: signed(35 downto 0) 			:= (others => L);

	signal	state		: signed( 1 downto 0) 			:= (others => L);
	signal	t2			: std_logic			 			:= L;
----------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
--	Spartan 6 has: Fast 18 x 18 multiplier and 48-bit accumulator
--	18*18 -> 36

--	      s1.kkkk_kkkk_kkkk_kkkk * s1.kkkk_kkkk_kkkk_kkkk
--	=   sss1.kkkk_kkkk_kkkk_kkkk_kkkk_kkkk_kkkk_kkkk 
--	Bit35432 1
        	        
--------------------------------------------------------------------------------
	b0 <= signed(i_b0);
    b1 <= signed(i_b1);
    b2 <= signed(i_b2);
    a1 <= signed(i_a1);
    a2 <= signed(i_a2);
--------------------------------------------------------------------------------
--    X <= signed(i_RawVal(15) &i_RawVal(15) & i_RawVal(15 downto 0));
    o_FiltVal <= std_logic_vector(Y(31 downto 16)); 
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
    process (i_CLKx2) begin
		if rising_edge(i_CLKx2) then
		    X <= signed(i_RawVal(15) & i_RawVal(15) & i_RawVal);

			case state is
			--------------------------------------------------------------------
			when "00"	=>
				Y  <= (b0 * X) + Z1;
				
				Z1a <= (b1 * X) + Z2;  
				Z2a <= (b2 * X);
				
				state <= "01";
			--------------------------------------------------------------------
			when "01"	=>    
			    Z1 <= Z1a - (a1 * Yh) ;	
			    Z2 <= Z2a - (a2 * Yh) ;	
			
				state <= "00";
			--------------------------------------------------------------------
        when others => null; 
        	end case;
			    
        end if; 
    end process;
			
--------------------------------------------------------------------------------
END;
