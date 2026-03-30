---------------------------------------------------------------------------
--
--  clockgenerator
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
--  	- clockgenerator
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

---------------------------------------------------------------------------
-- revision information !!! update g_SlaveSeq_Rev prior to svn commits !!!
---------------------------------------------------------------------------
-- Rev.08	02.09.2011-FB	- new CLK-Input i_CLK/ni_CLK to Q25
--------------------------------------------------------------------------------
--$Rev:: 2694                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-01-25 12:07:31 +0100 (Fr., 25 Jan 2013)                         $
--------------------------------------------------------------------------------


entity clockgenerator is
	port (
		 i_C64_CLK		: in	std_logic;
		ni_C64_CLK		: in	std_logic;
		 o_clk			: out	std_logic
	);
end;

architecture impl of clockgenerator is
--------------------------------------------------------------------------------
	constant H : std_logic := '1';
	constant L : std_logic := '0';
--------------------------------------------------------------------------------

	signal pQ25				: std_logic := L;
	signal pQ25_0			: std_logic := L;
	signal pQ25_1			: std_logic := L;
	signal pQ25_2			: std_logic := L;

	signal nQ25				: std_logic := L;
	signal nQ25_0			: std_logic := L;
	signal nQ25_1			: std_logic := L;
	signal nQ25_2			: std_logic := L;

	signal clk				: std_logic := L;

	-- xilinx
	attribute KEEP : string;
	attribute KEEP of clk : signal is "TRUE";
	-- altera
	attribute syn_keep : boolean;
	attribute syn_keep of clk : signal is true;

	-- xilinx
	attribute clock_signal : string;
	attribute clock_signal of clk : signal is "yes";

--------------------------------------------------------------------------------
begin -- of architecture CS_Seq

--------------------------------------------------------------------------------
--	external C64-Clock
------------------------------------------------------------------------------
--	ni_C64_CLK		__-------+______-------+______-------+______-------+______
--	clk (Q25)		-----_____---------______----------_____---------______---
--	pQ25_0			___________+--___________+--___________+--___________+--__
--	pQ25_1			____________--____________--____________--____________--__
--	pQ25_2			_____________+_____________+_____________+_____________+__

--	 i_C64_CLK		--+______-------+______-------+______-------+______-------
--	nQ25			___---------_____---------_____---------_____---------____
--	nQ25_0			____+--___________+--___________+--___________+--_________
--	nQ25_1			_____--____________--____________--____________--_________
--	nQ25_2			______+_____________+_____________+_____________+_________
--
--	+ = used to do something
--------------------------------------------------------------------------------
	o_clk <= clk;
	
	-- set Q25 as fast as possible (with falling ni_CLK)
	process(ni_C64_CLK,nQ25_0) begin
		if (nQ25_0 = H) then
			clk <= L after 2 ns;
		else
			if falling_edge(ni_C64_CLK) then
				clk <= H after 1 ns;
			end if;
		end if;
	end process;

	-- wait a bit
	process(clk,pQ25_2) begin
		if (pQ25_2 = H) then
			pQ25_0 <= L after 2 ns;
		else
			if rising_edge(clk) then
				pQ25_0 <= H after 1 ns;
			end if;
		end if;
	end process;
	-- wait a bit longer
	process(pQ25_0,pQ25_2) begin
		if (pQ25_2 = H) then
			pQ25_1 <= L after 2 ns;
		else
			if rising_edge(pQ25_0) then
				pQ25_1 <= H after 1 ns;
			end if;
		end if;
	end process;
	-- wait even more
	process(pQ25_1,pQ25_2) begin
		if (pQ25_2 = H) then
			pQ25_2 <= L after 2 ns;
		else
			if rising_edge(pQ25_1) then
				pQ25_2 <= H after 1 ns;
			end if;
		end if;
	end process;

	-- dedect CLK_End as fast as possible (with falling i_CLK)
	process(i_C64_CLK,pQ25_0) begin
		if (pQ25_0 = H) then
			nQ25 <= L after 2 ns;
		else
			if falling_edge(i_C64_CLK) then
				nQ25 <= H after 1 ns;
			end if;
		end if;
	end process;

	-- wait a bit
	process(nQ25,nQ25_2) begin
		if (nQ25_2 = H) then
			nQ25_0 <= L after 2 ns;
		else
			if rising_edge(nQ25) then
				nQ25_0 <= H after 1 ns;
			end if;
		end if;
	end process;
	-- wait a bit longer
	process(nQ25_0,nQ25_2) begin
		if (nQ25_2 = H) then
			nQ25_1 <= L after 2 ns;
		else
			if rising_edge(nQ25_0) then
				nQ25_1 <= H after 1 ns;
			end if;
		end if;
	end process;
	-- wait even more
	process(nQ25_1,nQ25_2) begin
		if (nQ25_2 = H) then
			nQ25_2 <= L after 2 ns;
		else
			if rising_edge(nQ25_1) then
				nQ25_2 <= H after 1 ns;
			end if;
		end if;
	end process;
--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
