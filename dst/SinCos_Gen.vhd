---------------------------------------------------------------------------
--
--	SinCos Generator
--
---------------------------------------------------------------------------
--
--  project     : SinCos_Gen
--  programmer  : F:Baschung, INDEL AG
--  date        : 15.12.2010
--  version     : 1.00
--  language    : VHDL
--  system      : Project Navigator
--
--  purpose
--  	- Sinus/Cosinus Generator
--		- inp Theta  Phi	== x"10000.0000"
--		- result sinCos +-1 == +-x"3FFFF"
--		- total 8 CLKs, 125MHz
--
---------------------------------------------------------------------------
--
--	Fehlt noch:
--
--
--
--
---------------------------------------------------------------------------
-- includes
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE ieee.numeric_std.ALL;

LIBRARY SinCos_Gen;
USE SinCos_Gen.SiCo_BRAM_4kByte_A18_B18;

--------------------------------------------------------------------------------
entity SinCos_GenSeq is
	port (
		i_CLK		: in	std_logic;
		i_Start		: in	std_logic;
		-- x"10000.0000" == Pi
		i_Theta		: in	std_logic_vector(16 downto 0);

		-- x"3FFFF" == +1
		o_Sin		: out	std_logic_vector(18 downto 0) := (others => '0');
		o_Cos		: out	std_logic_vector(18 downto 0) := (others => '0');
		-- H 7 clocks after i_Start
		o_done		: out	std_logic					  := '0';
		i_SinNCos	: in	std_logic := '0'
    );
end;

architecture impl of SinCos_GenSeq is
--------------------------------------------------------------------------------
	constant H : std_logic := '1';
	constant L : std_logic := '0';

--------------------------------------------------------------------------------
    type 	tState is (sWait,s0,s1,s2,s3,s4,s5,s6);
	signal	sState			: tState := sWait;

--------------------------------------------------------------------------------
--	Sinus
--------------------------------------------------------------------------------
	signal	SinTheta 		: unsigned(32 downto 0) 		:= (others => L);
	ALIAS	SinSig 			: std_logic is SinTheta(32);
	-- Ganzzahl Theta
    ALIAS  	SinThetaGZ		: unsigned(11 downto 0) is SinTheta(31 downto 20);
    ALIAS  	SinThetaAdr		: unsigned(15 downto 0) is SinTheta(31 downto 16);

	signal	Sin_idx 		: unsigned(15 downto 0) 		:= (others => L);
	ALIAS	SinThetaRem		: unsigned( 3 downto 0) is Sin_idx( 3 downto  0);

	signal	Sin_Ram		 	: std_logic_vector(17 downto 0) := (others => L);
	signal	Sin_Val_0 		: std_logic_vector(17 downto 0) := (others => L);
	signal	Sin90	 		: unsigned(18 downto 0) 		:= (others => L);
	signal	Sin		 		: signed(18 downto 0) 			:= (others => L);

	signal	SinDelta	 	: unsigned(17 downto 0) 		:= (others => L);
	signal	SinRem	 		: unsigned(21 downto 0) 		:= (others => L);
    ALIAS  	SinLIP			: unsigned(17 downto 0) is SinRem(21 downto 4);

--------------------------------------------------------------------------------
--	Cosinus
--------------------------------------------------------------------------------
	signal	CosTheta 		: unsigned(16 downto 0) 		:= (others => L);
	ALIAS	CosSig 			: std_logic is CosTheta(16);
	-- Ganzzahl Theta
    ALIAS  	CosThetaGZ		: unsigned(11 downto 0) is CosTheta(15 downto 4);
    ALIAS  	CosThetaAdr		: unsigned(15 downto 0) is CosTheta(15 downto 0);

	signal	Cos_idx 		: unsigned(15 downto 0) 		:= (others => L);
	ALIAS	CosThetaRem		: unsigned( 3 downto 0) is Cos_idx( 3 downto  0);

	signal	Cos_Ram		 	: std_logic_vector(17 downto 0) := (others => L);
	signal	Cos_Val_0 		: std_logic_vector(17 downto 0) := (others => L);
	signal	Cos90	 		: unsigned(18 downto 0) 		:= (others => L);
	signal	Cos		 		: signed(18 downto 0) 			:= (others => L);

	signal	CosDelta 		: unsigned(17 downto 0) 		:= (others => L);
	signal	CosRem	 		: unsigned(21 downto 0) 		:= (others => L);
    ALIAS  	CosLIP			: unsigned(17 downto 0) is CosRem(21 downto 4);
--------------------------------------------------------------------------------

begin

--------------------------------------------------------------------------------
   	o_Sin 	 <= std_logic_vector(Sin);
   	o_Cos 	 <= std_logic_vector(Cos);

--------------------------------------------------------------------------------
-- 	Sinus
--------------------------------------------------------------------------------
-- Die 0-07FF lange Sinus-Tabelle geht nur bis Phi/2  (0..+1 = 0..03FFFF)
-- daher muss der Index bis Phi gerechnet werden
-- und ab Phi bis 2Phi das Vorzeichen geändert werden

--******************************************************************************
--
--	Sequencer
--
--******************************************************************************
    process (i_CLK) begin
		if rising_edge(i_CLK) then
			o_done <= L;
	   		case sState is
	   		when sWait =>
	   			if (i_Start = H) then
	   			 	sState <= s0;
	   			end if;
			when s0 => sState <= s1;
			when s1 => sState <= s2;--s5;
			when s2 => sState <= s3;
			when s3 => sState <= s4;
			when s4 => sState <= s5;
			when s5 => sState <= s6;
			when s6 =>
				o_done <= H;
				sState <= sWait;
			when others => null;
			end case;
        end if;
    end process;


--******************************************************************************
--
--	Sinus
--
--******************************************************************************
--    process (i_CLK) begin
--		if rising_edge(i_CLK) then
--
--	   		case sState is
--	   		when sWait =>
--	   			if (i_Start = H) then
--	            	-- sinus / cosinus
--					SinTheta <= unsigned(i_Theta) + x"00008000";
--	   			end if;
--
--			--------------------------------------------------------------------
--			--	calc addr sin-tab-val 0
--			--------------------------------------------------------------------
--			when s0 =>
--	        	if (SinThetaGZ < 2047) then
--	        		Sin_idx <= SinThetaAdr;
--	        	else
--		        	if (SinThetaGZ = 2047) or (SinThetaGZ = 2048)  then
--	    	    		Sin_idx     <= x"7FF0";
--	    	    	else
--	    	    		Sin_idx     <= x"8000" - SinThetaAdr;
--	    	    	end if;
--	        	end if;
--
--			--------------------------------------------------------------------
--			--	calc addr sin-tab-val 1
--			--------------------------------------------------------------------
--			when s1 =>
--	        	if (SinThetaGZ < 2047) then
--	        		Sin_idx <= SinThetaAdr+x"10";
--	        	else
--		        	if (SinThetaGZ = 2047) or (SinThetaGZ = 2048)  then
--	    	    		Sin_idx <= x"7FF0";
--	    	    	else
--	    	    		Sin_idx <= x"8010" - SinThetaAdr;
--	    	    	end if;
--	        	end if;
--
--			--------------------------------------------------------------------
--			-- 	save sin-tab-val 0
--			--------------------------------------------------------------------
--			when s2 =>
--               	Sin_Val_0 <= Sin_Ram;
--
--			--------------------------------------------------------------------
--			--	calc sin-tab val1-val0
--			--------------------------------------------------------------------
--			when s3 =>
--				SinDelta <= unsigned(Sin_Ram) - unsigned(Sin_Val_0);
--
--			--------------------------------------------------------------------
--			--	linear interpolation
--			--------------------------------------------------------------------
--			when s4 =>
--				SinRem <= (SinDelta * SinThetaRem) + X"8" ;
--
--			when s5 =>
--				Sin90 <= unsigned(L & Sin_Val_0) + SinLIP;
--
--			--------------------------------------------------------------------
--			--	signum (+ for 0..Pi , - for pi..2Pi)
--			--------------------------------------------------------------------
--			when s6 =>
--		    	if (SinSig = H) then
--		    		Sin <= ("000" & x"0000") - signed(Sin90);
--		    	else
--		    		Sin <= signed(Sin90);
--		    	end if;
--			--------------------------------------------------------------------
--			when others => null;
--			end case;
--        end if;
--    end process;

--******************************************************************************
--
--	Cosinus
--
--******************************************************************************
    process (i_CLK) begin
		if rising_edge(i_CLK) then

	   		case sState is
	   		when sWait =>
--	   			if (i_Start = H) then
	            	-- Cosus / coCosus
	            	if (i_SinNCos=L) then
						CosTheta <= unsigned(i_Theta) + (x"4000"&H);
					else
						CosTheta <= unsigned(i_Theta) + (x"0000"&H);
					end if;
--	   			end if;

			--------------------------------------------------------------------
			--	calc addr Cos-tab-val 0
			--------------------------------------------------------------------
			when s0 =>
	        	if (CosThetaGZ < 2047) then
	        		Cos_idx <= CosThetaAdr;
	        	else
		        	if (CosThetaGZ = 2047) or (CosThetaGZ = 2048)  then
	    	    		Cos_idx     <= x"7FF0";
	    	    	else
	    	    		Cos_idx     <= x"8000" - CosThetaAdr;
	    	    	end if;
	        	end if;

			--------------------------------------------------------------------
			--	calc addr Cos-tab-val 1
			--------------------------------------------------------------------
			when s1 =>  -- wait
	        	if (CosThetaGZ < 2047) then
	        		Cos_idx <= CosThetaAdr+x"10";
	        	else
		        	if (CosThetaGZ = 2047) or (CosThetaGZ = 2048)  then
	    	    		Cos_idx <= x"7FF0";
	    	    	else
	    	    		Cos_idx <= x"8010" - CosThetaAdr;
	    	    	end if;
	        	end if;

			--------------------------------------------------------------------
			-- 	save Cos-tab-val 0
			--------------------------------------------------------------------
			when s2 =>
               	Cos_Val_0 <= Cos_Ram;

			--------------------------------------------------------------------
			--	calc Cos-tab val1-val0
			--------------------------------------------------------------------
			when s3 =>
				CosDelta <= unsigned(Cos_Ram) - unsigned(Cos_Val_0);

			--------------------------------------------------------------------
			--	linear interpolation
			--------------------------------------------------------------------
			when s4 =>
				CosRem <= (CosDelta * CosThetaRem) + X"8" ;

			when s5 =>
				--Cos90 <= unsigned(L & Cos_Ram);
				Cos90 <= unsigned(L & Cos_Val_0) + CosLIP;

			--------------------------------------------------------------------
			--	signum (+ for 0..Pi , - for pi..2Pi)
			--------------------------------------------------------------------
			when s6 =>
		    	if (CosSig = H) then
		    		Cos <= ("000" & x"0000") - signed(Cos90);
		    	else
		    		Cos <= signed(Cos90);
		    	end if;
			--------------------------------------------------------------------
			when others => null;
			end case;
        end if;
    end process;

--------------------------------------------------------------------------------
--	SinCos ROM instance
--------------------------------------------------------------------------------
	uSiCoRom : entity SinCos_Gen.SiCo_BRAM_4kByte_A18_B18
	PORT MAP (
		i_BRAM_Clk_A	=> i_CLK	 								,
		i_BRAM_Addr_A 	=> std_logic_vector(Sin_idx(14 downto 4)) 	,
		o_BRAM_Din_A 	=> Sin_Ram									,

		i_BRAM_Clk_B	=> i_CLK		 							,
		i_BRAM_Addr_B 	=> std_logic_vector(Cos_idx(14 downto 4)) ,
		o_BRAM_Din_B 	=> Cos_Ram
	);
--------------------------------------------------------------------------------
END;
