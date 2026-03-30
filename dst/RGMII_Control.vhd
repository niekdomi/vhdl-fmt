-- MODULE RGMII Control
-- VHDL Architecture Indel_lib.RGMII_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --

-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
--	07.06.2011-le - add clk enables to support 10/100 speeds
--				  - add generic to generate a clk output with a ddrff
--	23.07.2013-le - ddr input ff use inverted clk. invert the PHY_RXC for all other ff to avoid a 4ns stage
--				  - add generic to generate a extra register level between ddrios and first combinations
-- -------------------------------------------------------------------------- --
--                                                                            --
-- This RGMII entity should deliver the data RGMII conform. That means a      --
-- a Carrier Extend is delivered as 0x0F with GMII_RX_ERR = '1' and           --
-- GMII_RX_DV = '0'. This way round it should be possible to examine the link --
--- speed without MDIO accesses.                                              --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --

--------------------------------------------------------------------------------
--$Rev:: 4693                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2017-12-21 16:22:50 +0100 (Do., 21 Dez 2017)                         $
--------------------------------------------------------------------------------


---------------------------
-- Entity library inclusion
---------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
--USE Indel_lib.INFO_SAM3_Package_Take2.all;
-------------------------------
-- Entity library inclusion END
-------------------------------

ENTITY RGMII_Control IS
  GENERIC (
          RGMII_RX_BUF_LAT_C_S_PKG : integer := 5;
          C_USE_DDRFF_CLK : integer range 0 to 1 := 0;
          C_USE_EXTRA_REG : integer range 0 to 2 := 0
  );
  PORT    (
           GCLK           : IN   std_logic;
           CLR_n          : IN   std_logic;
           
           i_RXFIFO_clk_en: in   std_logic := '1';
           i_clk1         : in   std_logic := '1';
           i_clk2         : in   std_logic := '0';
           -- User Interface
           GMII_TX_EN     : IN   std_logic;
           GMII_TX_ERR    : IN   std_logic;
           GMII_TXD       : IN   std_logic_vector(7 DOWNTO 0);
           GMII_RX_DV     : OUT  std_logic;
           GMII_RX_ERR    : OUT  std_logic;
           GMII_RXD       : OUT  std_logic_vector(7 DOWNTO 0);
           -- RGMII
           PHY_RXC        : IN   std_logic;
           PHY_RXDV       : IN   std_logic;
           PHY_RXD        : IN   std_logic_vector(3 DOWNTO 0);
           TX_Disable     : IN   std_logic;
           PHY_GTXCLK     : OUT  std_logic;
           PHY_TXEN       : OUT  std_logic;
           PHY_TXD        : OUT  std_logic_vector(3 DOWNTO 0)
           );
END ENTITY RGMII_Control;


ARCHITECTURE Universal OF RGMII_Control IS

   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL    RGMII_RX_DV      : std_logic := '0';
   SIGNAL    RGMII_RX_ERR_DER : std_logic := '0';
   SIGNAL    RGMII_RXD        : std_logic_vector(7 DOWNTO 0) := (others => '0');
   SIGNAL    RGMII_RX_DV_1      : std_logic := '0';
   SIGNAL    RGMII_RX_ERR_DER_1 : std_logic := '0';
   SIGNAL    RGMII_RXD_1        : std_logic_vector(7 DOWNTO 0) := (others => '0');
   SIGNAL    RGMII_RX_DV_2      : std_logic := '0';
   SIGNAL    RGMII_RX_ERR_DER_2 : std_logic := '0';
   SIGNAL    RGMII_RXD_2        : std_logic_vector(7 DOWNTO 0) := (others => '0');
   
   SIGNAL    RGMII_RX_ERR     : std_logic := '0';
   SIGNAL    RGMII_TX_EN      : std_logic := '0';
   SIGNAL    RGMII_TX_ERR     : std_logic := '0';
   SIGNAL    RGMII_TX_ERR_DER : std_logic := '0';
   SIGNAL    RGMII_TXD        : std_logic_vector(7 DOWNTO 0) := (others => '0');
   SIGNAL    RX_BUF_Data_In   : std_logic_vector(9 DOWNTO 0) := (others => '0');
   SIGNAL    RX_BUF_Data_Out  : std_logic_vector(9 DOWNTO 0) := (others => '0');
   SIGNAL    start_read       : std_logic_vector(RGMII_RX_BUF_LAT_C_S_PKG DOWNTO 0) := (others => '0');
   SIGNAL    w_addr           : std_logic_vector(3 DOWNTO 0) := (others => '0');
   SIGNAL    r_addr           : std_logic_vector(3 DOWNTO 0) := (others => '0');
   SIGNAL    cnt              : std_logic_vector(2 DOWNTO 0) := (others => '0');
   SIGNAL    Lock_WR_AD       : std_logic := '0';
   
   SIGNAL    nPHY_RXC         : std_logic := '0';
   -------------------------
   -- Signal Declaration END
   -------------------------


   ------------------------
   -- Component Declaration
   ------------------------
   COMPONENT RGMII_IN IS
      PORT   (
              datain                       : IN   std_logic_vector(3 DOWNTO 0);
              inclock                      : IN   std_logic;
              dataout_h                    : OUT  std_logic_vector(3 DOWNTO 0);
              dataout_l                    : OUT  std_logic_vector(3 DOWNTO 0)
              );
   END COMPONENT RGMII_IN;

   COMPONENT RGMII_OUT IS
      PORT   (
              aclr                         : IN   std_logic;
              datain_h                     : IN   std_logic_vector(3 DOWNTO 0);
              datain_l                     : IN   std_logic_vector(3 DOWNTO 0);
              outclock                     : IN   std_logic;
              dataout                      : OUT  std_logic_vector(3 DOWNTO 0)
              );
   END COMPONENT RGMII_OUT;

   COMPONENT RGMII_IN_CTRL IS
      PORT   (
              datain                       : IN   std_logic;
              inclock                      : IN   std_logic;
              dataout_h                    : OUT  std_logic;
              dataout_l                    : OUT  std_logic 
              );
   END COMPONENT RGMII_IN_CTRL;

   COMPONENT RGMII_OUT_CTRL IS
      PORT   (
              aclr                         : IN   std_logic;
              datain_h                     : IN   std_logic;
              datain_l                     : IN   std_logic;
              outclock                     : IN   std_logic;
              dataout                      : OUT  std_logic 
              );
   END COMPONENT RGMII_OUT_CTRL;

   COMPONENT RGMII_RX_Buffer IS
      PORT   (
              data		                   : IN   std_logic_vector(9 DOWNTO 0);
              rdaddress		                : IN   std_logic_vector(3 DOWNTO 0);
              rdclock                      : IN   std_logic;
              wraddress                    : IN   std_logic_vector(3 DOWNTO 0);
              wrclock                      : IN   std_logic;
              wren                         : IN   std_logic:= '1';
              q                            : OUT  std_logic_vector(9 DOWNTO 0)
              );
   END COMPONENT RGMII_RX_Buffer;

   -- PRAGMA SYNTHESIS_OFF
   FOR ALL : RGMII_OUT USE ENTITY Indel_lib.RGMII_OUT;
   FOR ALL : RGMII_IN USE ENTITY Indel_lib.RGMII_IN;
   FOR ALL : RGMII_IN_CTRL USE ENTITY Indel_lib.RGMII_IN_CTRL;
   FOR ALL : RGMII_OUT_CTRL USE ENTITY Indel_lib.RGMII_OUT_CTRL;
   FOR ALL : RGMII_RX_Buffer USE ENTITY Indel_lib.RGMII_RX_Buffer;
    -- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- Component Declaration END
   ----------------------------


BEGIN

   -- ddr input ff use inverted clk. invert the clk for all other ff to avoid a 4ns stage
   nPHY_RXC <= not PHY_RXC;

   -- We have to acquire the RGMII DDR data
   RGMII_Data_In: RGMII_IN
       PORT MAP  (
                  datain                       => PHY_RXD,
                  inclock                      => PHY_RXC,
                  dataout_h                    => RGMII_RXD_1(7 DOWNTO 4),
                  dataout_l                    => RGMII_RXD_1(3 DOWNTO 0)
                  );

   RGMII_CTRL_In: RGMII_IN_CTRL
       PORT MAP  (
                  datain                       => PHY_RXDV,
                  inclock                      => PHY_RXC,
                  dataout_h                    => RGMII_RX_ERR_DER_1,
                  dataout_l                    => RGMII_RX_DV_1
                  );

   -- Concurrent 1
   RGMII_RX_ERR <= (RGMII_RX_ERR_DER XOR RGMII_RX_DV);
   
direct_route : if C_USE_EXTRA_REG=0 generate
begin
	RGMII_RX_ERR_DER  <= RGMII_RX_ERR_DER_1;
	RGMII_RX_DV       <= RGMII_RX_DV_1;
	RGMII_RXD         <= RGMII_RXD_1;
end generate direct_route;

extra_reg : if C_USE_EXTRA_REG/=0 generate
begin
	process(nPHY_RXC)
	begin
		if rising_edge(nPHY_RXC) then
			-- yes, i know the loop :)
			if (C_USE_EXTRA_REG/=1) then
				RGMII_RX_ERR_DER_2 <= RGMII_RX_ERR_DER_1;
				RGMII_RX_DV_2      <= RGMII_RX_DV_1;
				RGMII_RXD_2        <= RGMII_RXD_1;
				RGMII_RX_ERR_DER   <= RGMII_RX_ERR_DER_2;
				RGMII_RX_DV        <= RGMII_RX_DV_2;
				RGMII_RXD          <= RGMII_RXD_2;
			else-- C_USE_EXTRA_REG=1
				RGMII_RX_ERR_DER   <= RGMII_RX_ERR_DER_1;
				RGMII_RX_DV        <= RGMII_RX_DV_1;
				RGMII_RXD          <= RGMII_RXD_1;
			end if;
		end if;
	end process;
end generate extra_reg;


   -- WR Control to the Buffer
   WR_CTRL: PROCESS(nPHY_RXC)
   BEGIN
      IF (nPHY_RXC'EVENT AND nPHY_RXC = '1') THEN
         IF ((RGMII_RX_DV = '0') OR (RGMII_RX_ERR_DER = '0')) THEN
            cnt <= (cnt + 1);
            IF (cnt = 5) THEN
               start_read(0) <= '0';
               w_addr <= (OTHERS => '0');
               Lock_WR_AD <= '0';
            ELSIF (Lock_WR_AD = '1') THEN
               w_addr <= (w_addr + 1);
            END IF;
         ELSIF ((RGMII_RX_DV = '1') AND (RGMII_RX_ERR_DER = '1')) THEN
            w_addr <= (w_addr + 1);
            start_read(0) <= '1';
            cnt <= (OTHERS => '0');
            Lock_WR_AD <= '1';
         END IF;
      END IF;
   END PROCESS WR_CTRL;


   -- Concurrent 2
   RX_BUF_Data_In <= (RGMII_RX_DV & RGMII_RX_ERR & RGMII_RXD);


   -- The data acquired by the RX_CLK has to be decoupled
   RX_FIFO: RGMII_RX_Buffer
      PORT MAP  (
                 data         => RX_BUF_Data_In,
                 rdaddress    => r_addr,
                 rdclock      => GCLK,
                 wraddress    => w_addr,
                 wrclock      => nPHY_RXC,
                 wren         => '1',
                 q            => RX_BUF_Data_Out
                 );


   -- RD access to the RX FIFO Buffer
   RD_CTRL: PROCESS(GCLK)
   BEGIN
      IF (GCLK'EVENT AND GCLK = '1') THEN
         if (i_RXFIFO_clk_en='1') then
         start_read(start_read'HIGH DOWNTO 1) <= start_read(start_read'HIGH-1 DOWNTO 0);
         IF ((start_read(Return_Upper_F_I_PKG(RGMII_RX_BUF_LAT_C_S_PKG)) = '0') AND (start_read(RGMII_RX_BUF_LAT_C_S_PKG - 2) = '0')) THEN
            r_addr <= (OTHERS => '0');
         ELSE
            r_addr <= (r_addr + 1);
         END IF;
         end if;
      END IF;
   END PROCESS RD_CTRL;



   -- Concurrent
   GMII_RX_DV <= '0' WHEN (start_read(Return_Upper_F_I_PKG(RGMII_RX_BUF_LAT_C_S_PKG)) = '0' AND start_read(RGMII_RX_BUF_LAT_C_S_PKG) = '0') ELSE RX_BUF_Data_Out(9);

   -- Concurrent
   GMII_RX_ERR <= '0' WHEN (start_read(Return_Upper_F_I_PKG(RGMII_RX_BUF_LAT_C_S_PKG)) = '0' AND start_read(RGMII_RX_BUF_LAT_C_S_PKG) = '0') ELSE RX_BUF_Data_Out(8);

   -- Concurrent
   GMII_RXD <= (OTHERS => '0') WHEN ((start_read(Return_Upper_F_I_PKG(RGMII_RX_BUF_LAT_C_S_PKG)) = '0') AND (start_read(RGMII_RX_BUF_LAT_C_S_PKG) = '0')) ELSE RX_BUF_Data_Out(7 DOWNTO 0);



   -- Concurrent Group X-1
   RGMII_TX_EN <= GMII_TX_EN;
   RGMII_TX_ERR <= GMII_TX_ERR;
   RGMII_TXD <= GMII_TXD;

   -- Concurrent X
   RGMII_TX_ERR_DER <= (RGMII_TX_ERR XOR RGMII_TX_EN);

   -- Concurrent X + 1
   pll_clk : if (C_USE_DDRFF_CLK=0) generate
   begin
		PHY_GTXCLK <= GCLK;
   end generate pll_clk;

   -- We have to send out the RGMII DDR data
   RGMII_Data_Out: RGMII_OUT
       PORT MAP  (
                  aclr                         => TX_Disable,
                  datain_h                     => RGMII_TXD(3 DOWNTO 0),--Router_In(0).Data(3 DOWNTO 0), -- Positive edge TXD(3..0)
                  datain_l                     => RGMII_TXD(7 DOWNTO 4),--Router_In(0).Data(7 DOWNTO 4), -- Negative edge TXD(7..4)
                  outclock                     => GCLK,
                  dataout                      => PHY_TXD
                  );

   RGMII_CTRL_Out: RGMII_OUT_CTRL
       PORT MAP (
                 aclr                          => TX_Disable,
                 datain_h                      => RGMII_TX_EN,--Router_In(0).Data(8), -- Positive edge TXEN
                 datain_l                      => RGMII_TX_ERR_DER,--Router_In(0).Data(9), -- Negative edge TXEN/TXERR
                 outclock                      => GCLK,
                 dataout                       => PHY_TXEN
                 );
                 
                 
   ddrff_clk : if (C_USE_DDRFF_CLK=1) generate
   begin
   RGMII_CTRL_clk: RGMII_OUT_CTRL
       PORT MAP (
                 aclr                          => TX_Disable,
                 datain_h                      => i_clk1,--Router_In(0).Data(8), -- Positive edge TXEN
                 datain_l                      => i_clk2,--Router_In(0).Data(9), -- Negative edge TXEN/TXERR
                 outclock                      => GCLK,--PHY_REG_CLK1_Int,
                 dataout                       => PHY_GTXCLK
                 );
   end generate ddrff_clk;


END ARCHITECTURE Universal;