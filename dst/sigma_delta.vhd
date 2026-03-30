--------------------------------------------------------------------------------
--  sigma_delta interface
--------------------------------------------------------------------------------
--
--  project     : INFO-SAC2
--  programmer  : Christof Leuthold, INDEL AG
--  date        : 12.10.2004
--  version     : 1.00
--  language    : VHDL
--  system      : ispLever 3.0
--
--  purpose
--  	sigma_delta
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00a  :   12.10.2004-le  : +- conter
--  Rev. 1.00b  :   18.10.2004-le  : sinc3 filter (TI app. report SBAA094)
-- 				:	23.11.2004-le  : SINC3: clk = mclk
--										-> slower clk, better timing...
-- 				:  22.03.2006-le  : remove i_start_conv, start_conv
--	11.05.2007-le	add svn keywords
--	25.05.2007-le	add init-values for simulation
--------------------------------------------------------------------------------
--$Rev:: 3991                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2016-07-04 11:17:15 +0200 (Mo., 04 Jul 2016)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.all;

--library UNISIM;
--use UNISIM.VComponents.all;
--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity sigma_delta is
	generic (
		C_BIT_RES	: integer := 16;
		C_OVERRANGE	: integer := 0;
		C_CLK_DIV	: integer := 16;
		C_REG_LNG	: integer := 16;
		C_ChipScope_Implemented : integer := 0
	);
	port (
		i_Clk       : in    std_logic;                  -- clock input
		i_Reset    	: in    std_logic;					-- reset input H-active
		--sigma_delta Pins
		i_sClk		: in	std_logic;
		i_sData		: in	std_logic;
		-- interface
--		o_Data		: out	std_logic_vector(C_REG_LNG-1 downto 0);
		o_DataLA	: out	std_logic_vector(C_REG_LNG-1 downto 0);
		o_overrange	: out	std_logic;
		o_TP1		: out   std_logic;
		o_TP2		: out   std_logic;
		o_TP3		: out   std_logic;
		o_TP4		: out	std_logic
	);
end;                                                    -- of entity sigma_delta

architecture behavior_sigma_delta of sigma_delta is
-- component declarations ------------------------------------------------------
	component FD is
	port (Q : out std_logic;
		  C : in  std_logic;
		  D : in  std_logic);
	end component FD;
	component SINC3 is
	generic (
		C_BIT_RES	: integer := 10;
		C_CLK_EN	: integer := 1
	);
	port(
		clk, RESN, MOUT, MCLK, CNR : in std_logic;
		CN5 : out std_logic_vector(C_BIT_RES-1 downto 0));
	end component SINC3;
	-------------------------------------------------------------------
	--
	--  ILA core component declaration
	--
	-------------------------------------------------------------------
	component ila_sd_2048
		port
		(
			control     : in    std_logic_vector(35 downto 0);
			clk         : in    std_logic;
			trig0       : in    std_logic_vector(30 downto 0)
		);
	end component;
	-------------------------------------------------------------------
	--
	--  ICON core component declaration
	--
	-------------------------------------------------------------------
	component icon_sd_c
		port
		(
			control0    :   inout std_logic_vector(35 downto 0)
		);
	end component;

-- constants -------------------------------------------------------------------
	constant H          : std_logic := '1';
	constant L          : std_logic := '0';
	constant Z          : std_logic := 'Z';
	constant C_CLK_EN	: integer := 1;-- 0 funktioniert noch nich... le 23.11.04
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
	signal Data			: std_logic_vector(C_BIT_RES-1 downto 0):=(others => '0');
	signal sData		: std_logic:=L;
	signal sDataPre		: std_logic:=L;
	signal sClk			: std_logic:=L;
	signal sClkPre 		: std_logic:=L;
	signal oldData      : std_logic:=L;
	signal overrange    : std_logic:=L;
	signal or_cnt       : std_logic_vector(4 downto 0):=(others => '0');
	signal MCLK			: std_logic:=L;
	signal CNR 			: std_logic:=L;
	signal clk_div		: std_logic_vector(7 downto 0):=(others => '0');
	signal clk			: std_logic:=L;
	signal sClkRisingEdge: std_logic:=L;
	-------------------------------------------------------------------
	--
	--  ILA core signal declarations
	--
	-------------------------------------------------------------------
	signal control    : std_logic_vector(35 downto 0);
	signal trig0      : std_logic_vector(30 downto 0);


-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin												-- of architecture sigma_delta

	clk_ff1 : FD
	port map
	(
		Q => sClkPre,
		C => i_Clk,
		D => i_sClk
	);
	clk_ff2 : FD
	port map
	(
		Q => sClk,
		C => i_Clk,
		D => sClkPre
	);
	dat_ff1 : FD
	port map
	(
		Q => sDataPre,
		C => i_Clk,
		D => i_sData
	);
	dat_ff2 : FD
	port map
	(
		Q => sData,
		C => i_Clk,
		D => sDataPre
	);
	filter : SINC3
	generic map(
		C_BIT_RES	=> C_BIT_RES,
		C_CLK_EN	=> C_CLK_EN
	)
	port map(
		clk 	=> clk,
		RESN	=> i_Reset,
		MOUT	=> sData,
		MCLK	=> MCLK,
		CNR		=> CNR,
		CN5     => Data
	);
-- processes ------------------------------------------------------------------
	o_TP1 <= sClkRisingEdge;
	o_TP2 <= sData;
	o_TP3 <= sClk;
	o_TP4 <= CNR;
	sClkRisingEdge <= not(sClk) and sClkPre;

	clk_enable : if C_CLK_EN=1 generate begin
		MCLK <= sClkRisingEdge;
		clk	 <= i_Clk;
	end generate;
	no_clk_enable : if C_CLK_EN=0 generate begin
		MCLK <= sClkRisingEdge;
		clk	 <= sClkRisingEdge;
	end generate;

   -- data_lng_1: if C_REG_LNG>=C_BIT_RES generate begin
   -- 	o_Data(C_REG_LNG-1 downto C_BIT_RES) <= (others => L);
   -- 	o_Data(C_BIT_RES-1 downto 0) <= Data(C_BIT_RES-1 downto 0);
   --
   -- 	o_DataLA(C_REG_LNG-1) <= not Data(C_BIT_RES-2);
   -- 	o_DataLA(C_REG_LNG-2 downto C_REG_LNG-C_BIT_RES+1) <= Data(C_BIT_RES-3 downto 0) when Data(C_BIT_RES-1)=L else (others => H);
   -- 	o_DataLA(C_REG_LNG-C_BIT_RES downto 0) <= (others => L);
   --
   -- end generate data_lng_1;
   --
   -- data_lng_2: if C_REG_LNG<C_BIT_RES generate begin
   -- 	o_Data <= Data(C_BIT_RES-1 downto C_BIT_RES-C_REG_LNG-1);
   --
   -- 	o_DataLA(C_REG_LNG-1) <= not Data(C_BIT_RES-2);
   -- 	o_DataLA(C_REG_LNG-2 downto 0) <= Data(C_BIT_RES-3 downto C_BIT_RES-C_REG_LNG-1) when Data(C_BIT_RES-1)=L else (others => H);
   --
   -- end generate data_lng_2;




	process (i_Reset,i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
		elsif rising_edge(i_Clk) then
		-- clocked statements
			if C_REG_LNG>=C_BIT_RES then
--				o_Data(C_REG_LNG-1 downto C_BIT_RES) <= (others => L);
--				o_Data(C_BIT_RES-1 downto 0) <= Data(C_BIT_RES-1 downto 0);

				o_DataLA(C_REG_LNG-1) <= not Data(C_BIT_RES-2);
				trig0(16-1) <= not Data(C_BIT_RES-2);
				if Data(C_BIT_RES-1)=L then
					o_DataLA(C_REG_LNG-2 downto C_REG_LNG-C_BIT_RES+1) <= Data(C_BIT_RES-3 downto 0);
					trig0(16-2 downto 16-C_BIT_RES+1) <= Data(C_BIT_RES-3 downto 0);
				else
					o_DataLA(C_REG_LNG-2 downto C_REG_LNG-C_BIT_RES+1) <= (others => H);
					trig0(16-2 downto 16-C_BIT_RES+1) <= (others => H);
				end if;
				o_DataLA(C_REG_LNG-C_BIT_RES downto 0) <= (others => L);
				trig0(16-C_BIT_RES downto 0) <= (others => L);
			else
--				o_Data <= Data(C_BIT_RES-1 downto C_BIT_RES-C_REG_LNG-1);

				o_DataLA(C_REG_LNG-1) <= not Data(C_BIT_RES-2);
				trig0(16-1) <= not Data(C_BIT_RES-2);
				if Data(C_BIT_RES-1)=L then
					o_DataLA(C_REG_LNG-2 downto 0) <= Data(C_BIT_RES-3 downto C_BIT_RES-C_REG_LNG-1);
					trig0(16-2 downto 0) <= Data(C_BIT_RES-3 downto C_BIT_RES-16-1);
				else
					o_DataLA(C_REG_LNG-2 downto 0) <= (others => H);
					trig0(16-2 downto 0) <= (others => H);
				end if;
			end if;
			if sClkRisingEdge=H then --		rising edge __--
				if clk_div>=C_CLK_DIV-1 then
					CNR <= H;
					clk_div		<= (others => L);

				else
					CNR <= L;
					clk_div		<= clk_div + 1;
				end if;
			end if;
		end if;
	end process;                                        -- END of process NAME

	or_detection : process (i_Reset,i_Clk)
	begin
		if (i_Reset = H) then
		-- asynch reset statements
		elsif rising_edge(i_Clk) then
		-- clocked statements
			if sClkRisingEdge=H then --		rising edge __--
				oldData <= sData;
				if sData=oldData then
					if overrange=L then
						or_cnt <= or_cnt + 1;
					end if;
				else
					or_cnt <= (others => L);
				end if;
				if or_cnt>=C_OVERRANGE then
					overrange <= H;
				else
					overrange <= L;
				end if;
			end if;
		end if;
	end process;                                        -- END of process or_detection
	o_overrange <= overrange;

	cs_imp_inst: if C_ChipScope_Implemented=1 generate
	begin
		trig0(16) <= L;
		trig0(30 downto 17) <= (others=>L);
		----------------------------------------------------------------------------
		--
		--  ILA core instance
		--
		----------------------------------------------------------------------------
		i_ila : ila_sd_2048
		port map
		(
			control   => control,
			clk       => CNR,
			trig0     => trig0
		);
		----------------------------------------------------------------------------
		--
		--  ICON core instance
		--
		----------------------------------------------------------------------------
		i_icon : icon_sd_c
		port map
		(
			control0    => control
		);
	end generate cs_imp_inst;

end behavior_sigma_delta;                               -- END of architecture sigma_delta
--------------------------------------------------------------------------------

