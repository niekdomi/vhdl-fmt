--------------------------------------------------------------------------------
--  increment_counter
--------------------------------------------------------------------------------
--
--  project 	: info-sac2
--  programmer  : C. Leuthold, INDEL AG
--  date 		: 14.09.2004
--  version 	: 1.00
--  language 	: VHDL
--  system 	 : ispLever 3.0
--
--  purpose
--		increment encoder and counter
--		C_INC_FILTER = 1 includ a filter for i_IncA/B and i_ZeroPulse
--		(2 of 3 samples H => H)
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00a:	14.09.2004-le  : - disc.
--  Rev. 1.00b:	27.04.2005-le  : - disc.
--				29.11.2005-le  : add def. values for inputs 
--				23.03.2006-le  : add C_SYNCHRONIZE 1: internal input synchronisation ; 0: external input synchronisation
--	11.05.2007-le	add svn keywords
--	20.07.2011-le	add i_CntPermanentUp: use same resource as counter in C64-SSI
--	25.02.2014-le	add output o_CntPulse for external pulse counters
--	01.04.2016-le	add C_INC_FILTER>1: ZP must be C_INC_FILTER+1 times H for a zpcount
--	04.07.2016-le	correct Encoder Filter for i_IncA/B for C_INC_FILTER>1
--					  i_IncA/B hava a filter for 2of3 C_INC_FILTER/=0
--	12.04.2018-le	add AB_EXTRA_FILTER
--------------------------------------------------------------------------------
--$Rev:: 4833                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-04-12 17:58:52 +0200 (Do., 12 Apr 2018)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;
--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity increment_counter is
	generic (
		C_CNT_LENGTH: integer := 12;					-- length of Counter
		C_ZPCNT_LENGTH : integer := 4;					-- length of Counter
		C_REG_LENGTH : integer := 16;
		C_INC_FILTER : integer range 0 to 255 := 1;		-- 0: no filter / 1: filter
		C_AB_EXTRA_FILTER : integer range 0 to 255 := 0;		-- 0: no filter / !0: filter
		C_SYNCHRONIZE : integer := 1 					-- add 2 ff-stages for input synchronisation (A,B,ZP)
	);
	port (
		i_Clk		: in	std_logic;					-- clock input
		i_Reset		: in	std_logic;					-- reset input H-active
		-- increment input signals
		i_IncA		: in	std_logic := '0';			-- Increment Input
		i_IncB		: in	std_logic := '0';			-- Increment Input
		i_ClearIncCnt: in	std_logic := '0';			-- H: clear Counter
		i_ZeroPulse	: in	std_logic := '0';			-- ZP Input
		i_ClearZPCnt: in	std_logic := '0';			-- H: clear Counter
		-- increment output signals
		o_IncCnt	: out	std_logic_vector(C_CNT_LENGTH-1 downto 0);	-- Increment Counter
		o_ZPCnt		: out	std_logic_vector(C_ZPCNT_LENGTH-1 downto 0);-- ZP Counter
		o_ZeroPulse	: out	std_logic; -- one-Clk pulse on i_ZeroPulse __--
		o_IncUp		: out	std_logic;
		o_CntPulse	: out	std_logic;
		o_IncReg	: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		i_CntPermanentUp : in	std_logic := '0';
		i_ABFilterEn: in	std_logic := '0'			-- H: enable filter C_AB_EXTRA_FILTER
	);
end;													-- of entity increment_counter

architecture behavior_increment_counter of increment_counter is
-- component declarations ------------------------------------------------------
	component FD is
	port (Q : out std_logic;
		  C : in  std_logic;
		  D : in  std_logic);
	end component FD;
-- constants -------------------------------------------------------------------
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal IncCnt 		: std_logic_vector(C_CNT_LENGTH-1 downto 0) := (others => L);
	signal Iup			: std_logic := L;
	signal IncClk		: std_logic := L;
	signal IncClk_1		: std_logic := L;
	signal Ia0			: std_logic := L;
	signal Ia1			: std_logic := L;
	signal Ib0			: std_logic := L;
	signal Ib1			: std_logic := L;
	signal Iaa			: std_logic := L;
	signal Iab			: std_logic := L;
	signal Iba			: std_logic := L;
	signal Ibb			: std_logic := L;
	signal Ia			: std_logic	:= L;
	signal Ib			: std_logic	:= L;
	signal Ia_sync		: std_logic	:= L;
	signal Ib_sync		: std_logic	:= L;

	signal ZPa			: std_logic := L;
	signal ZPb			: std_logic := L;
	signal ZP			: std_logic := L;
	signal ZP_sync		: std_logic := L;
	signal zp_fi		: std_logic := L;
	signal zp_old		: std_logic	:= L;
	signal np_cnt		: std_logic_vector(C_ZPCNT_LENGTH-1 downto 0) := (others => L);
	
	signal zp_filter	: std_logic_vector(pkg_log2(C_INC_FILTER)-1 downto 0) := (others => L);
	signal a_filter	: std_logic_vector(pkg_log2(C_AB_EXTRA_FILTER)-1 downto 0) := (others => L);
	signal b_filter	: std_logic_vector(pkg_log2(C_AB_EXTRA_FILTER)-1 downto 0) := (others => L);

-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin									-- of architecture increment_counter
	o_ZPCnt <= np_cnt;
	o_IncCnt <= IncCnt;
	o_IncUp <= Iup;
	o_IncReg(C_CNT_LENGTH-1 downto 0) <= IncCnt;
	o_IncReg(C_REG_LENGTH-1 downto C_REG_LENGTH-C_ZPCNT_LENGTH) <= np_cnt;
	-- IncA/B synchronisation --------------------------------------------------
	synch : if (C_SYNCHRONIZE=1) generate
		INC_A_ff1 : FD
		port map
		(
			Q => Ia_sync,
			C => i_Clk,
			D => i_IncA
		);
		INC_A_ff2 : FD
		port map
		(
			Q => Ia,
			C => i_Clk,
			D => Ia_sync
		);
		INC_B_ff1 : FD
		port map
		(
			Q => Ib_sync,
			C => i_Clk,
			D => i_IncB
		);
		INC_B_ff2 : FD
		port map
		(
			Q => Ib,
			C => i_Clk,
			D => Ib_sync
		);
		INC_REF_ff1 : FD
		port map
		(
			Q => ZP_sync,
			C => i_Clk,
			D => i_ZeroPulse
		);
		INC_REF_ff2 : FD
		port map
		(
			Q => ZP,
			C => i_Clk,
			D => ZP_sync
		);
	end generate synch;
	extern_synch : if (C_SYNCHRONIZE=0) generate
		Ia <= i_IncA;
		Ib <= i_IncB;
		ZP <= i_ZeroPulse;
	end generate extern_synch;
	-- Filter ------------------------------------------------------------------
	Encoder: process (i_Reset, i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
			Iaa	<= L;
			Iab	<= L;
			Iba	<= L;
			Ibb	<= L;
			Ia0	<= L;
			Ia1	<= L;
			Ib0	<= L;
			Ib1	<= L;
		elsif rising_edge(i_Clk) then
		-- clocked statements
			if C_AB_EXTRA_FILTER/=0 and i_ABFilterEn=H then
				-- a
				Iaa <= Ia;
				if (Ia=Iaa) then
					if a_filter=C_AB_EXTRA_FILTER then
						Ia0 <= not(Ia);
					else	
						a_filter <= a_filter+1;
					end if;
				else
					a_filter <= (others => L);
				end if;
				-- b
				Iba <= Ib;
				if (Ib=Iba) then
					if b_filter=C_AB_EXTRA_FILTER then
						Ib0 <= not(Ib);
					else	
						b_filter <= b_filter+1;
					end if;
				else
					b_filter <= (others => L);
				end if;
				Ia1 <= Ia0;
				Ib1 <= Ib0;
			elsif C_INC_FILTER/=0 then
				-- Iaa
				Iaa <= Ia;
				-- Iab 												 ba0
				if    (Iab=L) and (Iaa=H)	and (Ia=H)	then Iab <= H;	--  _--
				elsif (Iab=H) and (Iaa=H)				then Iab <= H;	--  --x
				elsif (Iab=H)				and (Ia=H)	then Iab <= H;	--..-x-
				else Iab <= L;
				end if;
				-- Iba
				Iba <= Ib;
				-- Ibb 												 ba0
				if    (Ibb=L) and (Iba=H)	and (Ib=H)	then Ibb <= H;	--  _--
				elsif (Ibb=H) and (Iba=H)				then Ibb <= H;	--  --x
				elsif (Ibb=H)				and (Ib=H)	then Ibb <= H;	--  -x-
				else Ibb <= L;
				end if;
				Ia0 <= not(Iab);
				Ia1 <= Ia0;
				Ib0 <= not(Ibb);
				Ib1 <= Ib0;
			else
				Ia0 <= not(Ia);
				Ia1 <= Ia0;
				Ib0 <= not(Ib);
				Ib1 <= Ib0;
			end if;
		end if;
	end process;									-- END of process Encoder
	-- Quadrature Decoding -----------------------------------------------------
	--		  	1   2   3   4   1   2   3   4		 5   6   7   8   5   6   7   8
	-- A		__--------________--------________   ____--------________-------
	-- B		______--------________--------____   --------________--------___
	-- I0		0 1 1 1 1 0 0 0 0 1 1 1 1 0 0 0 0	 0 0 1 1 1 1 0 0 0   1   1   0
	-- I1		0 0 1 1 1 1 0 0 0 0 1 1 1 1 0 0 0	 0 0 0 1 1 1 1 0 0   0   1   1
	-- b0		0 0 0 1 1 1 1 0 0 0 0 1 1 1 1 0 0	 1 1 1 1 0 0 0 0 1   1   0   0
	-- b1		0 0 0 0 1 1 1 1 0 0 0 0 1 1 1 1 0	 0 1 1 1 1 0 0 0 0   1   1   0
	--
	-- UP		 _--__--__--__--__--__--__--__--__   _____________________________
	-- CLK  	 __--__--__--__--__--__--__--__--__   --__--__--__--__--__--__--__-
	--
	----------------------------------------------------------------------------
	QuadDec: process (i_Reset, i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
			Iup  <= L;
			IncClk <= L;
			IncClk_1 <= L;
		elsif rising_edge(i_Clk) then
		-- clocked statements
			-- Iup
			if (Iup=H) and (IncClk=H) then 							Iup <= H;-- * hold a bit
			elsif (Ia0=H) and (Ia1=L) and (Ib0=L) and (Ib1=L) then 	Iup <= H;-- 1
			elsif (Ia0=H) and (Ia1=H) and (Ib0=H) and (Ib1=L) then 	Iup <= H;-- 2
			elsif (Ia0=L) and (Ia1=H) and (Ib0=H) and (Ib1=H) then 	Iup <= H;-- 3
			elsif (Ia0=L) and (Ia1=L) and (Ib0=L) and (Ib1=H) then 	Iup <= H;-- 4
			else Iup <= L;
			end if;
			-- IncClk
			if    (Ia0/=Ia1) then IncClk <= H;
			elsif (Ib0/=Ib1) then IncClk <= H;
			else IncClk <= L;
			end if;
			IncClk_1 <= IncClk;
		end if;
	end process;									-- END of process QuadDec
	-- UP/DOWN Counter ---------------------------------------------------------
	Cunter : process (i_Reset, i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
			IncCnt <= (others => L);
		elsif rising_edge(i_Clk) then
		-- clocked statements
			o_CntPulse <= L;
			if i_ClearIncCnt=H then
				IncCnt <= (others => L);
			else
				if (IncClk=L and IncClk_1=H) or i_CntPermanentUp=H then -- falling edge of IncClk
					o_CntPulse <= H;
					if (Iup=H or i_CntPermanentUp=H) then
						IncCnt <= IncCnt + 1;	-- +1
					else
						IncCnt <= IncCnt - 1;	-- -1
					end if;
				end if;
			end if;
		end if;
	end process;									-- END of process Cunter
	-- ZeroPulse Counter -------------------------------------------------------
	ZeroPulse : process (i_Clk)
	begin
		if rising_edge(i_Clk) then
			ZPa	<= ZP;
			ZPb	<= ZPa;
			o_ZeroPulse <= L;
			if C_INC_FILTER=1 then
				-- filter 2 of 3
				if( (ZP=H and ZPa=H)
				  or(ZPa =H and ZPb=H)
				  or(ZP=H and ZPb=H)) then
					zp_fi <= H;
				else
					zp_fi <= L;
				end if;
			elsif C_INC_FILTER>1 then
				if (ZP=H) then
					if zp_filter/=C_INC_FILTER then
						zp_filter <= zp_filter+1;
					end if;
				else
					zp_filter <= (others => L);
				end if;
				if zp_filter=C_INC_FILTER then
					zp_fi <= H;
				else
					zp_fi <= L;
				end if;
			else
				zp_fi <= ZP;
			end if;
			zp_old <= zp_fi;
			if zp_fi=H and zp_old=L then 	-- rising edge __--
				o_ZeroPulse	<= H;
				if i_ClearZPCnt=H then
					np_cnt <= (others => L);
				else
					np_cnt <= np_cnt + 1;
				end if;
			end if;
		end if;
	end process;
end behavior_increment_counter;	-- END of architecture increment_counter
--------------------------------------------------------------------------------

