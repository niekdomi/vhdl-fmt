--------------------------------------------------------------------------------
-- heat_master_pkg.vhd
--------------------------------------------------------------------------------
--
--	project	 	: INFO-HEAT
--	programmer	: C. Leuthold, INDEL AG
--	date		: 08.04.2008
--	version	 	: 0.00
--	language	: VHDL 
--	system		: ise / v2p
--
--	purpose
--				heat_master package
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	08.04.2008-le: - create
--	28.04.2008-le: - ! rename constants to DF_HEAT_PKG_...
--					 + add crc polynom and init values
--------------------------------------------------------------------------------
--$Rev:: 2612                                                                  $
--$Author:: leuthold                                                           $
--$Date:: 2013-01-07 10:26:12 +0100 (Mo., 07 Jan 2013)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package heat_master_pkg is
	constant DF_HEAT_PKG_INFOLINK : integer := 0;
	constant DF_HEAT_PKG_ESART : integer := 1;
	constant DF_HEAT_PKG_GINLINK : integer := 2;
	-- crc
	constant DF_HEAT_PKG_CRC_POLY : std_logic_vector(7 downto 0) := x"97";-- x^8 +x^5 +x^3 +x^2 +x +1
	constant DF_HEAT_PKG_CRC_INIT : std_logic_vector(DF_HEAT_PKG_CRC_POLY'range) := (others => '1');
end package heat_master_pkg;