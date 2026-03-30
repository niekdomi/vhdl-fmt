--------------------------------------------------------------------------------
--
--	ADC AutoRange
--
--------------------------------------------------------------------------------
--
--  project		: C64_BusMaster
--  programmer  : F:Baschung, INDEL AG
--  date		: 23.06.2010
--  version		: 1.00
--  language	: VHDL
--  system		: Project Navigator
--
--  purpose
-- 		- AutoRange
--
--------------------------------------------------------------------------------
-- revision information !!! update Revision prior to a release !!!
--------------------------------------------------------------------------------
--  22.01.2013-FB	in separates File
--------------------------------------------------------------------------------
--$Rev:: 2081																   $
--$Author:: leuthold														   $
--$Date:: 2011-08-03 15:53:32 +0100 (Mi, 03 Aug 2011)						   $
--------------------------------------------------------------------------------
--
--	Die ADC-Werte werden noch als tSLV_Nx16(0 to 7) übergeben,
-- 	da das so aus dem ADC-Module kommt.
-- 	Besser wäre vermutlich ein SimpleDualportRam
--
--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

--------------------------------------------------------------------------------
entity ADC_AutoRange is
	port (
		i_Q25				: in  std_logic;

		-- from ADC-Module
		i_ADC_AR_Start		: in  std_logic;					-- ADC measuring done
		i_ADC				: tSLV_Nx16(0 to 7);				-- 16Bit ADC-Value

		-- commanded scal (PGA_GAIN)
		i_PGA_Status		: in  std_logic_vector(15 downto 0);
		o_PGA_AUTO			: out std_logic_vector(15 downto 0)
	);
end ADC_AutoRange;
--------------------------------------------------------------------------------
architecture impl of ADC_AutoRange is
--------------------------------------------------------------------------------
	constant H				: std_logic := '1';
	constant L				: std_logic := '0';
----------------------------------------------------------------------------------
--  AutoRange
	signal	CmdScal			: tSLV_Nx2(0 to 7)				:= (others => (others => '0'));
	signal	ActScal			: tSLV_Nx2(0 to 7)				:= (others => (others => '0'));
	signal	NextScal		: tSLV_Nx2(0 to 7)				:= (others => (others => '0'));

	signal	PGA_AUTO		: std_logic_vector(15 downto 0) := (others => '0');
	signal	ASCL_DLY		: tSLV_Nx4(0 to 7)				:= (others => (others => '0'));

----------------------------------------------------------------------------------
begin
--------------------------------------------------------------------------------
--  In / Out
--------------------------------------------------------------------------------
	o_PGA_AUTO <= PGA_AUTO;

--------------------------------------------------------------------------------
--  convert std_logic_vector to tSLV_Nx2
--------------------------------------------------------------------------------
cmdscl: for i in 0 to 7 generate
	process(i_PGA_Status,PGA_AUTO) begin
		CmdScal(i) <= i_PGA_Status((i*2)+1 downto (i*2));
		ActScal(i) <= PGA_AUTO ((i*2)+1 downto (i*2));
	end process;
end generate;

--------------------------------------------------------------------------------
--  Auto-Range
--------------------------------------------------------------------------------
AutoRange: for i in 0 to 7 generate
	process (i_Q25) begin
	   if rising_edge(i_Q25) then
			if (i_ADC_AR_Start = H) then

				-- AutoScal ist nur aktiv wenn User +-10mV gewählt hat
				if (not(CmdScal(i) = "11")) then
					-- User bestimmt den Bereich
					NextScal(i) <= CmdScal(i);

				-- do a delay before changing scale again
				elsif (ASCL_DLY(i) > x"0") then
					ASCL_DLY(i) <= ASCL_DLY(i) -1;
				else
					-- teste Vorzeichen
					if (i_ADC(i)(15) = L) then
						--  + Vorzeichen
						if (i_ADC(i) < x"0C67") then		-- 07C00 / 10 = 0C67
							---------------------------------------------------------
							case ActScal(i) is
							---------------------------------------------------------
							when "00" => NextScal(i) <= "01";	-- *10
							when "01" => NextScal(i) <= "10";	-- *10
							when "10" => NextScal(i) <= "11";	-- *10
							when "11" => NextScal(i) <= "11";	-- mehr geht nicht
							---------------------------------------------------------
							when others => null;
							end case;
							ASCL_DLY(i) <= x"2";
							---------------------------------------------------------
						elsif (i_ADC(i) > x"7F80") then
							---------------------------------------------------------
							case ActScal(i) is
							---------------------------------------------------------
							when "00" => NextScal(i) <= "00";	-- weniger geht nicht
							when "01" => NextScal(i) <= "00";	-- /10
							when "10" => NextScal(i) <= "01";	-- /10
							when "11" => NextScal(i) <= "10";	-- /10
							---------------------------------------------------------
							when others => null;
							end case;
							---------------------------------------------------------
							ASCL_DLY(i) <= x"2";
						end if;
					else
						--  - Vorzeichen
						if (i_ADC(i) > x"F399") then
							---------------------------------------------------------
							case ActScal(i) is
							---------------------------------------------------------
							when "00" => NextScal(i) <= "01";	-- *10
							when "01" => NextScal(i) <= "10";	-- *10
							when "10" => NextScal(i) <= "11";	-- *10
							when "11" => NextScal(i) <= "11";	-- mehr geht nicht
							---------------------------------------------------------
							when others => null;
							end case;
							---------------------------------------------------------
							ASCL_DLY(i) <= x"2";
						elsif (i_ADC(i) < x"8080") then
							---------------------------------------------------------
							case ActScal(i) is
							---------------------------------------------------------
							when "00" => NextScal(i) <= "00";	-- weniger geht nicht
							when "01" => NextScal(i) <= "00";	-- /10
							when "10" => NextScal(i) <= "01";	-- /10
							when "11" => NextScal(i) <= "10";	-- /10
							---------------------------------------------------------
							when others => null;
							end case;
							---------------------------------------------------------
							ASCL_DLY(i) <= x"2";
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
end generate;

	PGA_AUTO <= NextScal(7)&NextScal(6)&NextScal(5)&NextScal(4)&NextScal(3)&NextScal(2)&NextScal(1)&NextScal(0);

--------------------------------------------------------------------------------
end impl;
--------------------------------------------------------------------------------
