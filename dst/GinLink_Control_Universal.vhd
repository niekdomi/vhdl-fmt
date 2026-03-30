-- MODULE Ethernet Control
-- VHDL Architecture Indel_lib.GinMaster_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   INFO-SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- Wrapper for the ethernet functionality- not only GE                        --
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- Remarks:                                                                   --
-- Even if the PHY is conected via SGMII, the ports of the entity are GMII    --
-- based. But for generating the control signals, the MAC has to know the     --
-- interface type.                                                            --
--                                                                            --
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --


--------------------------------------------------------------------------------
--$Rev:: 1393                                                                  $
--$Author:: Quirin                                                             $
--$Date:: 2010-04-07 14:48:19 +0200 (Mi., 07 Apr 2010)                         $
--------------------------------------------------------------------------------

---------------------------
-- Entity library inclusion
---------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.INFO_SAM3_Package_Take2.all;

LIBRARY Gin_Master;
USE Gin_Master.all;
-------------------------------
-- Entity library inclusion END
-------------------------------

ENTITY GinLink_Control IS
  GENERIC (
           Ethernet_PHY_Interface  : IN    natural RANGE 0 TO 3 := 0 -- 0 = GMII/RGMII, 1 = SGMII
           );
  PORT    (
           -- General signals
           GCLK                    : IN    std_logic; -- Default clock (125MHz)
           CLK62_5                 : IN    std_logic; -- 62.5MHz clock
           CLR_n                   : IN    std_logic; -- Interface to the PPC bus
           PPC_Dock                : INOUT router_dock_t_s_pkg;
           -- Ethernet signals
           GMII_RX_DV              : IN    std_logic;
           GMII_RX_ERR             : IN    std_logic;
           GMII_RXD                : IN    std_logic_vector(7 DOWNTO 0);
           GMII_TX_EN              : OUT   std_logic;
           GMII_TX_ERR             : OUT   std_logic;
           GMII_TXD                : OUT   std_logic_vector(7 DOWNTO 0);
           -- Ethernet Status signals
           GIN_RX_Run              : OUT   std_logic;
           ETH_TX_Run              : OUT   std_logic
           );
END ENTITY GinLink_Control;

ARCHITECTURE Universal OF GinLink_Control IS


   CONSTANT Delay                  : natural := 1;
   CONSTANT Memory_Width           : natural := 16;
   SIGNAL   Burst_Vector           : burst_address_t_s_pkg;
   SIGNAL   Burst_Counter          : natural RANGE 0 TO 2;
   SIGNAL   Burst_OnGoing          : std_logic;
   SIGNAL   EN_Delay_Counter       : std_logic;
   SIGNAL   Wait_For_Data_On_Bus   : std_logic;
   SIGNAL   Wait_For_Burst_WR      : std_logic;
   SIGNAL   WE_INT                 : std_logic;
   SIGNAL   WE_INT_INT             : std_logic;
   SIGNAL   WE_INT_INT_INT         : std_logic;
   SIGNAL   WE_Burst_INT           : std_logic;
   SIGNAL   Internal_Address       : std_logic_vector(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 0);
   SIGNAL   GE_Wrap_Out_Data       : std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL   Module_AD              : std_logic_vector(Return_Upper_F_I_PKG(Router_AD_Width_C_S_PKG) DOWNTO 0);
   SIGNAL   Module_BE              : std_logic_vector(7 DOWNTO 0);
	SIGNAL	fb_wen	              : std_logic_vector(7 downto 0);
	SIGNAL   fb_irq                 : std_logic;
	SIGNAL	fb_irqs	              : std_logic_vector(7 downto 0);
	SIGNAL	fb_PPC_BE	           : std_logic_vector(7 downto 0);	
	SIGNAL	fb_PPC_Dout	           : std_logic_vector(63 downto 0);	
	SIGNAL	fb_PPC_Dinp	           : std_logic_vector(63 downto 0);
	SIGNAL   Delayed_Read           : std_logic;
	
   ------------------------
   -- Component Declaration
   ------------------------
   COMPONENT GM_Wrap
      PORT    (
               i_ppc_dom_clk	: IN   std_logic;
               o_IRQ          : OUT  std_logic;
                    	
               i_Q125			: IN   std_logic;
               i_Q62_5			: IN   std_logic;

               o_fwGMII_TxDat	: OUT  std_logic_vector(7 DOWNTO 0);		
               o_fwGMII_TxDv	: OUT  std_logic;	
               o_fwGMII_TxErr	: OUT  std_logic;

               i_bwGMII_RxDat	: IN   std_logic_vector(7 DOWNTO 0);		
               i_bwGMII_RxDv	: IN   std_logic;	
               i_bwGMII_RxErr : IN   std_logic;	
                    	
               o_EthRun 		: OUT  std_logic;
               o_GinRun 		: OUT  std_logic;
                 		
               i_BRAM_Clk 		: IN   std_logic;
               i_BRAM_EN 		: IN   std_logic;
               i_BRAM_WEN 		: IN   std_logic_vector( 7 DOWNTO 0);
               i_BRAM_Addr 	: IN   std_logic_vector(15 DOWNTO 0);
               i_BRAM_Dout 	: IN   std_logic_vector(63 DOWNTO 0);
               o_BRAM_Din 		: OUT  std_logic_vector(63 DOWNTO 0)
               );
   END COMPONENT GM_Wrap;

   -- PRAGMA SYNTHESIS_OFF
   FOR ALL : GM_Wrap USE ENTITY Gin_Master.GM_Wrap;
   -- PRAGMA SYNTHESIS_ON
   ----------------------------
   -- Component Declaration END
   ----------------------------
 
   

BEGIN


   -- It is simple to support bursting in the member entity. The following code has just to be added.
   Burst_Controller: PROCESS(GCLK, CLR_n)
   BEGIN
       IF (CLR_n = '0') THEN
           Burst_Vector <= (OTHERS => (OTHERS => '0'));
           Burst_OnGoing <= '0';
           Wait_For_Burst_WR <= '0';
       ELSIF (GCLK'EVENT AND GCLK = '1') THEN
           IF (PPC_Dock.Router_Data.TS = '1') THEN
              CASE PPC_Dock.Router_Data.TBST IS
                 WHEN '1' =>
                    IF (PPC_Dock.Router_Data.WE = '1') THEN
                       Burst_OnGoing <= '0';
                       Wait_For_Burst_WR <= '1';
                    ELSE
                       Burst_OnGoing <= '1';
                       Wait_For_Burst_WR <= '0';
                    END IF;
                    Burst_Vector <= PPC_Dock.Router_Data.Burst_Vector;
                 WHEN '0' =>
                    Burst_OnGoing <= '0';
                    Burst_Vector <= (OTHERS => (OTHERS => '0'));
                    Wait_For_Burst_WR <= '0';
                 WHEN OTHERS => 
                    Burst_OnGoing <= '0';
                    Burst_Vector <= (OTHERS => (OTHERS => '0'));
                    Wait_For_Burst_WR <= '0';
              END CASE;
              Burst_Counter <= 0;
           ELSIF (Burst_OnGoing = '1') THEN
              IF (Burst_Counter = 2) THEN
                 Burst_OnGoing <= '0';
              ELSE
                 Burst_Counter <= (Burst_Counter + 1);
              END IF;
           ELSIF (Wait_For_Burst_WR = '1') THEN
              Wait_For_Burst_WR <= '0';
              Burst_OnGoing <= '1';
           END IF;
       END IF;
    END PROCESS Burst_Controller;


   
   Delay_Count: PROCESS(GCLK, CLR_n)
      VARIABLE Counter : natural;
   BEGIN
       IF (CLR_n = '0') THEN
           EN_Delay_Counter <= '0';
           Delayed_Read <= '0';
       ELSIF (GCLK'EVENT AND GCLK = '1') THEN
          IF  (((PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Router_Data.WE = '0')) OR ((Burst_OnGoing = '1') AND (WE_INT = '0'))) THEN
             IF (WE_INT = '1') THEN
                Delayed_Read <= '1';
                EN_Delay_Counter <= '0';
             ELSE
                EN_Delay_Counter <= '1';
                Delayed_Read <= '0';
             END IF;
          ELSIF (Delayed_Read = '1') THEN
             EN_Delay_Counter <= '1';
             Delayed_Read <= '0';
          ELSIF (PPC_Dock.Acknowledge_Data.Ready_Acknowledge = '1') THEN
             EN_Delay_Counter <= '0';
             Delayed_Read <= '0';
          END IF;
       END IF;
   END PROCESS Delay_Count;

   PPC_Dock.Member_Data.Data_Ready <= EN_Delay_Counter;
   PPC_Dock.Member_Data.Write_Delay <= '0';
   PPC_Dock.Member_Data.Slow_Burst <= '0';

   
   -- Internal Write Enable
   WR_Enable: PROCESS(GCLK, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Wait_For_Data_On_Bus <= '0';
         WE_INT <= '0';
         WE_INT_INT <= '0';
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         IF ((PPC_Dock.Router_Data.WE = '1') AND (PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Acknowledge_Data.Data_On_Bus = '1')) THEN
            WE_INT_INT <= '1';
            Wait_For_Data_On_Bus <= '0';
         ELSIF ((PPC_Dock.Router_Data.WE = '1') AND (PPC_Dock.Router_Data.TS = '1')) THEN
            Wait_For_Data_On_Bus <= '1';
         ELSIF (Wait_For_Data_On_Bus = '1') THEN
            IF (PPC_Dock.Acknowledge_Data.Data_On_Bus = '1') THEN
               WE_INT_INT <= '1';
               Wait_For_Data_On_Bus <= '0';
            ELSE
               WE_INT_INT <= '0';
               Wait_For_Data_On_Bus <= '1';
            END IF;
         ELSIF ((WE_INT = '1') AND (Burst_OnGoing = '1')) THEN
            WE_INT_INT <= '1';
         ELSE
            WE_INT_INT <= '0';
         END IF;
         WE_INT <= WE_INT_INT;
      END IF;
   END PROCESS WR_Enable;
      
   	process (WE_INT,fb_PPC_BE) begin
		if (WE_INT = '1') then
			fb_wen <= fb_PPC_BE;
		else
			fb_wen <= x"00";
		end if;
	end process;
	
	
	AD_Delay: PROCESS(GCLK, CLR_n)
   BEGIN
     IF (CLR_n = '0') THEN
         Module_AD <= (OTHERS => '0');
         Module_BE <= (OTHERS => '0');
      ELSIF (GCLK'EVENT AND GCLK = '1') THEN
         Module_AD <= PPC_Dock.Router_Data.AD;
         Module_BE <= PPC_Dock.Router_Data.BE;
      END IF;
   END PROCESS AD_Delay;

	-- Anti Quirin Hack , xchange 32Bit to get PPC-Like 64Bit 
   fb_PPC_BE <= Module_BE(3 downto 0) & Module_BE(7 downto 4) WHEN (WE_INT = '1') ELSE PPC_Dock.Router_Data.BE(3 downto 0) & PPC_Dock.Router_Data.BE(7 downto 4);
	fb_PPC_Dout <= PPC_Dock.Router_Data.Router_Entity_Data(31 downto 0) & PPC_Dock.Router_Data.Router_Entity_Data(63 downto 32);
	fb_PPC_Dinp <= GE_Wrap_Out_Data(31 downto 0) & GE_Wrap_Out_Data(63 downto 32);
   
   The_GinMas: GM_Wrap
       PORT MAP    (
		              i_ppc_dom_clk   => GCLK,
		              o_IRQ           => fb_irq,
		              i_Q125          => GCLK,
		              i_Q62_5         => CLK62_5,
		              o_fwGMII_TxDat	=> GMII_TXD,
		              o_fwGMII_TxDv	=> GMII_TX_EN,
		              o_fwGMII_TxErr	=> GMII_TX_ERR,
		              i_bwGMII_RxDat	=> GMII_RXD,
		              i_bwGMII_RxDv	=> GMII_RX_DV,
		              i_bwGMII_RxErr	=> GMII_RX_ERR,			
		              o_EthRun 		   => ETH_TX_Run,
		              o_GinRun 		   => GIN_RX_Run,
		              i_BRAM_Clk      => GCLK,
		              i_BRAM_EN       => '1',
		              i_BRAM_WEN      => fb_wen,
		              i_BRAM_Addr     => Internal_Address,
		              i_BRAM_Dout     => fb_PPC_Dout,-- Debug, QFU, 12.02.2009 PPC_Dock.Router_Data.Router_Entity_Data,!!!!!!!!!!!!!!!!!!!!!!!!!
		              o_BRAM_Din      => GE_Wrap_Out_Data
	                 );
   
   
	fb_irqs <= fb_irq & "0000000";
	PPC_Dock.Member_Data.IRQ <= fb_irqs;
   
   -- Concurrent
   PPC_Dock.Member_Data.Entity_Router_Data <= fb_PPC_Dinp;
   Internal_Address(1 DOWNTO 0) <= PPC_Dock.Router_Data.AD(1 DOWNTO 0) WHEN ((Burst_OnGoing = '0') AND (WE_INT = '0')) ELSE Module_AD(1 DOWNTO 0) WHEN (Burst_OnGoing = '0') ELSE Burst_Vector(Burst_Counter);--Debug QFU, 16.09.2008
   Internal_Address(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2) <= Module_AD(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2) WHEN (WE_INT = '1') ELSE PPC_Dock.Router_Data.AD(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2);--Debug QFU, 16.09.2008


END ARCHITECTURE Universal;