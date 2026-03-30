---------------------------------------------------------------------------
--
--  PowerLink Timer	
--
---------------------------------------------------------------------------
--
--  project     : GIN_LINK
--  programmer  : F:Baschung, INDEL AG
--  date        : 23.08.2004
--  version     : 1.00
--  language    : VHDL 
--  system      : Project Navigator
--
--  purpose
--		- 32-Bit ICU	(8-internal, 24 external) 	
--  	- 8x32Bit Highresolution Timer	(connected on IRQ(31 downto 24))
--
---------------------------------------------------------------------------
--	31.05.2012-fb	first version of PL-Timers with ICU
--	11.09.2012-le	PL-Timers and ICU support for 64/32 bit devices
--	13.01.2014-le	add a mask for IRQ_Mask to define which irqs can be enabled
--	15.05.2014-le	g_OUTREG_A for Gin_ICU must be fix -1
--	21.12.2017-le	g_SKIP_TIMER for skip the timer
--------------------------------------------------------------------------------
--$Rev:: 4693                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-12-21 16:22:50 +0100 (Do., 21 Dez 2017)                         $
--------------------------------------------------------------------------------
---------------------------------------------------------------------------
-- includes         
---------------------------------------------------------------------------  	     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library gin_link;
use gin_link.all;
library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
entity PL_TIMER is
	generic (
		g64_n32BitRam	: in integer range 0 to 1 := 1;
		g_OUTREG_A		: in integer range 0 to 1 := 0;
		g_SKIP_TIMER	: in integer range 0 to 1 := 0
	);
	port (
		i_CLK		: in  std_logic;		-- PPC-Clock (f.e 115MHz)
		i_EN		: in  std_logic;
		i_WEN		: in  std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);
		i_Din		: in  std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_Dout		: out std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		i_addr		: in  std_logic_vector( 3 downto 0); -- 32 bit address
		i_IRQ_Mask  : in  std_logic_vector(23 downto 0) := (others => '1'); -- mask for IRQ_Mask 
		i_EthIRQs	: in  std_logic_vector(23 downto 0) := (others => '0');
		o_IRQ		: out std_logic
	);

end PL_TIMER;
--------------------------------------------------------------------------------
architecture impl of PL_TIMER is
--------------------------------------------------------------------------------	

--------------------------------------------------------------------------------

    signal Timer		: tSLV_Nx32(0 to 7) := (others => (others => '0'));
    signal TimIrq		: std_logic_vector( 7 downto 0) := (others => '0');
                    	
	signal TIM_En		: std_logic 					:= L;
	signal lastEN		: std_logic 					:= L;
	signal t			: integer;

	signal ICU_En		: std_logic 					:= L;
    signal ICU_RdData	: std_logic_vector(31 + g64_n32BitRam*32 downto 0) := (others => '0');
    signal I_ICU_RQs	: std_logic_vector(31 downto 0) := (others => '0');

    signal Dout			: std_logic_vector(31 + g64_n32BitRam*32 downto 0) := (others => '0');
	
	signal IRQ_Mask		: std_logic_vector(31 downto 0);

--------------------------------------------------------------------------------
begin -- of architecture PL_TIMER    
--------------------------------------------------------------------------------
	outreg_en0: if g_OUTREG_A=0 generate
		o_Dout <= Dout;
	end generate outreg_en0;
	
	outreg_en1: if g_OUTREG_A=1 generate
	process (i_CLK) begin
		if rising_edge(i_CLK) then
			o_Dout <= Dout;
		end if;
	end process;
	end generate outreg_en1;
    
--------------------------------------------------------------------------------
--	Address decoder
--------------------------------------------------------------------------------
	process (i_EN,i_addr) begin
		TIM_En <= L;
		ICU_En <= L;
		
		if (i_EN = H) then
			if (i_addr(3) = H and g_SKIP_TIMER=0) then
				Tim_En <= H;
			else	
				ICU_En <= H;
	        end if;        
	    end if;
	end process;    

	t <= CONV_INTEGER(i_addr(2 downto 0));	-- 0..7
       	
--------------------------------------------------------------------------------
--	Read-Data mux
--------------------------------------------------------------------------------
	process (i_CLK) begin
		if rising_edge(i_CLK) then 
			Dout <= (others => '0');

            if (ICU_En = H) then
            	Dout <= ICU_RdData;
            elsif (TIM_En = H and g_SKIP_TIMER=0) then
				if (g64_n32BitRam=1) then
					Dout <= Timer(t) & Timer(t+1);
				else
					Dout <= Timer(t);
				end if;
			end if;
		end if;				
	end process;
			
--------------------------------------------------------------------------------
--	Write Timer
--------------------------------------------------------------------------------
uTimers: process (i_CLK) begin
	if rising_edge(i_CLK) then 
		TimIrq <= (others => L);
		if  (g_SKIP_TIMER=0) then
			for i in 0 to 7 loop
				-- timer still running?
				if (Timer(i) > 0) then  
					-- decrement timer
					Timer(i) <= Timer(i) -1;
					
					-- Timer abgelaufen?
					if (Timer(i) = 1) then
						-- set Timer-IRQ
						TimIrq(i) <= H;
					end if;
				end if;
			end loop;
			if (Tim_En = H) and ((i_WEN(3 downto 0) = "1111") or (i_WEN(3+g64_n32BitRam*4 downto g64_n32BitRam*4) = "1111")) then
				-- write timer
				if (g64_n32BitRam=1) then
					if (i_WEN(3 downto 0) = "1111") then
						Timer(t+1) <= i_Din(31 downto 0);
					end if;
					if (i_WEN(3+g64_n32BitRam*4 downto g64_n32BitRam*4) = "1111") then
						Timer(t) <= i_Din(31+g64_n32BitRam*32 downto g64_n32BitRam*32);
					end if;
				else
					Timer(t) <= i_Din;
				end if;
			end if;
		end if;
	end if;
end process;

	
--------------------------------------------------------------------------------
--	IRQ controller
--------------------------------------------------------------------------------
 	I_ICU_RQs <= TimIrq & i_EthIRQs;
	
	IRQ_Mask <= x"ff" & i_IRQ_Mask;

uWrap_ICU: entity gin_link.Gin_ICU
	generic map (
		g64_n32BitRam => g64_n32BitRam,
		g_OUTREG_A => -1
	)
	port map (
		i_ICU_Clk	=> i_CLK				,
		i_ICU_EN	=> ICU_En				,
		i_WR 		=> i_WEN				,
		i_Din		=> i_Din				,
		o_Dout		=> ICU_RdData			,
		i_addr		=> i_Addr(0)			,
		i_IRQs		=> I_ICU_RQs			,
		i_IRQ_Mask	=> IRQ_Mask				,
		o_IRQ		=> o_IRQ				
	);

--------------------------------------------------------------------------------  



end impl;
