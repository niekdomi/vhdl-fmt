---------------------------------------------------------------------------
--
--  GIN Master/Slave IRQ controller
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
--  	- 64-Bit IRQ controller for up to 32 IRQs
--
---------------------------------------------------------------------------
--	18.12.2008-le : - add svn keywords
--	07.06.2011-le : - add second reg level for sync
--	11.08.2011-le : - add generic for 32 bit ram
--	31.08.2011-fb : - add IRQ-Timer
--	13.01.2014-le : - add a mask for IRQ_Mask to define which irqs can be enabled
--	26.05.2016-le : - add C_SECOND_ICU to activate a second irq with own mask and timer
--	19.12.2017-le : - adjust sensitivity list
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

--  Uncomment the following lines to use the declarations that are
--  provided for instantiating Xilinx primitive components.
--library UNISIM;
--use UNISIM.VComponents.all;

--------------------------------------------------------------------------------
entity Gin_ICU is
	generic (
		g64_n32BitRam	: in integer range 0 to 1 := 1;
		g_OUTREG_A		: in integer range -1 to 1 := 0;
		C_SECOND_ICU	: in integer range 0 to 1 := 1
	);
	port (
		i_ICU_Clk	: in  std_logic;		-- PPC-Clock (f.e 100MHz)
		i_ICU_EN	: in  std_logic;
		i_WR 		: in  std_logic_vector( 3 + g64_n32BitRam* 4 downto 0);
		i_Din		: in  std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		o_Dout		: out std_logic_vector(31 + g64_n32BitRam*32 downto 0);
		i_addr		: in std_logic := '0';
		i_addr_tim	: in std_logic := '0';	-- read IRQ-Timer	(Addr-2)
		i_addr_2nd	: in std_logic := '0';
		i_IRQs		: in  std_logic_vector(31 downto 0) := (others => '0');
		i_IRQ_Mask  : in  std_logic_vector(31 downto 0) := (others => '1'); -- mask for IRQ_Mask
		i_IRQ2_Mask : in  std_logic_vector(31 downto 0) := (others => '1'); -- mask for IRQ_Mask
		o_IRQ		: out std_logic;
		o_IRQs		: out 	std_logic_vector( 1 downto 0)
	);

end Gin_ICU;
--------------------------------------------------------------------------------
architecture impl of Gin_ICU is
--------------------------------------------------------------------------------	

--------------------------------------------------------------------------------
    constant H 	: std_logic := '1';
    constant L 	: std_logic := '0';

--------------------------------------------------------------------------------
    signal IRQ_Pending		: std_logic_vector(31 downto 0) := x"00000000";
    signal IRQ_Mask			: std_logic_vector(31 downto 0) := x"00000000";
    signal IRQ_Synched		: std_logic_vector(31 downto 0) := x"00000000";
    signal IRQ_Synched_1	: std_logic_vector(31 downto 0) := x"00000000";

    signal IRQ_Timer		: std_logic_vector(31 downto 0) := x"00000000";
    signal IRQ				: std_logic;
    signal IRQ_t1			: std_logic;
	
	signal IRQ2_Pending		: std_logic_vector(31 downto 0) := x"00000000";
	signal IRQ2_Mask			: std_logic_vector(31 downto 0) := x"00000000";

	signal IRQ2_Timer		: std_logic_vector(31 downto 0) := x"00000000";
	signal IRQ2				: std_logic;
	signal IRQ2_t1			: std_logic;
	
	signal Dout				: std_logic_vector(31 + g64_n32BitRam*32 downto 0);
	signal Dout_1			: std_logic_vector(31 + g64_n32BitRam*32 downto 0);

--------------------------------------------------------------------------------
begin -- of architecture Gin_ICU    
--------------------------------------------------------------------------------
	o_IRQ <= IRQ;
	o_IRQs <= IRQ2 & IRQ;

--------------------------------------------------------------------------------
--	Synch  IRQ-Registers
--------------------------------------------------------------------------------
--	Wir haben 32 asynchrone IRQs. 
--	Die Pulse müssen länger als 10ns (100MHz, PPC_Clk) sein
--	Ich synchronisiere sie hier vorsichtshalber nochmals
--------------------------------------------------------------------------------
	process (i_ICU_Clk) begin
		if rising_edge(i_ICU_Clk) then 
			IRQ_Synched_1 <= i_IRQs;
			IRQ_Synched <= IRQ_Synched_1;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Read IRQ-Registers
--------------------------------------------------------------------------------
--	Wir lesen auf 32-Bit Adr
--		0	IRQ-Reg
--		1	IRQ-Mask 
--		2	IRQ-Timer
--------------------------------------------------------------------------------


	outreg_en0: if g_OUTREG_A=0 generate
	process (i_ICU_Clk) begin
		if rising_edge(i_ICU_Clk) then 
			o_Dout <= Dout;
		end if;
	end process;
	end generate outreg_en0;
	
	outreg_en1: if g_OUTREG_A=1 generate
	process (i_ICU_Clk) begin
		if rising_edge(i_ICU_Clk) then
			Dout_1 <= Dout;
			o_Dout <= Dout_1;
		end if;
	end process;
	end generate outreg_en1;

	outreg_dis: if g_OUTREG_A=-1 generate
		o_Dout <= Dout;
	end generate outreg_dis;



out64 : if g64_n32BitRam=1 generate
	process (i_addr_tim,IRQ_Pending,IRQ_Mask,i_addr_2nd,IRQ2_Pending,IRQ2_Mask,IRQ2_Timer,IRQ_Timer) begin
		if C_SECOND_ICU=1 and i_addr_2nd=H then
			if (i_addr_tim = L) then
				Dout <= IRQ_Pending & IRQ_Mask;
			else	
				Dout <= IRQ_Timer & x"00000000";
			end if;
		else
			if (i_addr_tim = L) then
				Dout <= IRQ2_Pending & IRQ2_Mask;
			else	
				Dout <= IRQ2_Timer & x"00000000";
			end if;
		end if;
	end process;
end generate out64;
	
out32 : if g64_n32BitRam=0 generate
	process (i_addr,i_addr_tim,IRQ_Pending,IRQ_Mask,i_addr_2nd,IRQ2_Pending,IRQ2_Mask,IRQ2_Timer,IRQ_Timer) begin
		if C_SECOND_ICU=1 and i_addr_2nd=H then
			if (i_addr_tim = L) then
				if (i_addr = L) then
					Dout <= IRQ2_Pending;
				else
					Dout <= IRQ2_Mask;
				end if;
			else	
				if (i_addr = L) then
					Dout <= IRQ2_Timer;
				else
					Dout <= x"00000000";
				end if;	
			end if;
		else
			if (i_addr_tim = L) then
				if (i_addr = L) then
					Dout <= IRQ_Pending;
				else
					Dout <= IRQ_Mask;
				end if;
			else	
				if (i_addr = L) then
					Dout <= IRQ_Timer;
				else
					Dout <= x"00000000";
				end if;	
			end if;
		end if;
	end process;
end generate out32;

--------------------------------------------------------------------------------
--	IRQ-Output 
--------------------------------------------------------------------------------
	process (i_ICU_Clk) begin
		if rising_edge(i_ICU_Clk) then 
			-- save irq t-1
			IRQ_t1 <= IRQ;
			
			if ((IRQ_Pending and IRQ_Mask) = x"00000000") then
				IRQ <= L; 
			else	
				IRQ <= H; 
			end if;
			if C_SECOND_ICU=1 then
				IRQ2_t1 <= IRQ2;
				
				if ((IRQ2_Pending and IRQ2_Mask) = x"00000000") then
					IRQ2 <= L; 
				else	
					IRQ2 <= H; 
				end if;
			end if;
		end if;
	end process;

--------------------------------------------------------------------------------
--	Write to IRQ-Registers
--------------------------------------------------------------------------------
	process (i_ICU_Clk) begin
		if rising_edge(i_ICU_Clk) then 
			
			-- set and hold IRQ_Pendig
			IRQ_Pending <= (IRQ_Pending or IRQ_Synched);
			if C_SECOND_ICU=1 then
				IRQ2_Pending <= (IRQ2_Pending or IRQ_Synched);
			end if;
			-- write to ICU ?
			if (i_ICU_EN = H) then
				if C_SECOND_ICU=1 and i_addr_2nd=H then
					-- write to IRQ_Pending register
					if (i_WR(3+g64_n32BitRam*4 downto g64_n32BitRam*4) = "1111" and (g64_n32BitRam=1 or i_addr=L)) then
						IRQ2_Pending <= ((IRQ2_Pending or IRQ_Synched) and not i_Din(31+g64_n32BitRam*32 downto g64_n32BitRam*32));
					end if;
						
					-- write to IRQ_Mask register
					if (i_WR(3 downto 0) = "1111" and (g64_n32BitRam=1 or i_addr=H)) then
						IRQ2_Mask <= i_Din(31 downto 0) and i_IRQ2_Mask;
					end if;
				else
					-- write to IRQ_Pending register
					if (i_WR(3+g64_n32BitRam*4 downto g64_n32BitRam*4) = "1111" and (g64_n32BitRam=1 or i_addr=L)) then
						IRQ_Pending <= ((IRQ_Pending or IRQ_Synched) and not i_Din(31+g64_n32BitRam*32 downto g64_n32BitRam*32));
					end if;
						
					-- write to IRQ_Mask register
					if (i_WR(3 downto 0) = "1111" and (g64_n32BitRam=1 or i_addr=H)) then
						IRQ_Mask <= i_Din(31 downto 0) and i_IRQ_Mask;
					end if;
				end if;
			end if;
		end if;
	end process;
			
--------------------------------------------------------------------------------
--	IRQ-Timer	zero with o_IRQ _+-
--------------------------------------------------------------------------------
	process (i_ICU_Clk) begin
		if rising_edge(i_ICU_Clk) then 
			if (IRQ = H) and (IRQ_t1 = L) then
				IRQ_Timer <= x"00000000";
			else
				IRQ_Timer <= IRQ_Timer+1;
			end if;
			if C_SECOND_ICU=1 then
				if (IRQ2 = H) and (IRQ2_t1 = L) then
					IRQ2_Timer <= x"00000000";
				else
					IRQ2_Timer <= IRQ2_Timer+1;
				end if;
			end if;
		end if;
	end process;	
--------------------------------------------------------------------------------
end impl;
