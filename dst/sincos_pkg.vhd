-------------------------------------------------------------------------------
-- sincos_pkg.vhd
-------------------------------------------------------------------------------
--
--	project		: SinCos PACKAGE
--	programmer	: C. Leuthold, INDEL AG
--	date		: 19.01.2010
--	language	: VHDL PACKAGE
--	
--	purpose	
--------------------------------------------------------------------------------
--	revision information
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

package sincos_pkg is
	
function sig_expand(val: signed; lng : natural) return signed;
function mul(v1,v2: signed; lng : natural) return signed;
	
end sincos_pkg;

package body sincos_pkg is

	function sig_expand(val: signed; lng : natural) return signed is
	variable ret : signed(lng-1 downto 0);
	variable arg : signed(val'length-1 downto 0);
	begin
		arg := val;
		if val'length<lng then
			for i in 0 to lng-1 loop
				if (i<val'length) then
					ret(i) := arg(i);
				else
					ret(i) := arg(arg'high);
				end if;
			end loop;
			return ret;
		else
			return arg;
		end if;
	end sig_expand;
	
	function mul(v1,v2: signed; lng : natural) return signed is
	variable res : signed(v1'length-1+v2'length downto 0);
	variable a1 : signed(v1'length-1 downto 0);
	variable a2 : signed(v2'length-1 downto 0);
	variable ret : signed(lng-1 downto 0);
	begin
		res := a1*a2;
		ret := res(res'high downto res'high-ret'high);
		return ret;
	end mul;
	
end sincos_pkg;

--------------------------------------------------------------------------------