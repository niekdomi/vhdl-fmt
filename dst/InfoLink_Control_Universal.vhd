-- MODULE InfoLink Control
-- VHDL Architecture Indel_lib.InfOLink_Control.Universal
--
-- InfoLink, GinLink, INFO-SAM3 Copyright (c): INDEL AG
--
-- Project:   SAM3
-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --
-- Module Description:                                                        --
-- Template for internal bus members
-- -------------------------------------------------------------------------- --
-- History (main versions):                                                   --
-- -------------------------------------------------------------------------- --

--                                                                            --
-- -------------------------------------------------------------------------- --
-- Remark:                                                                    --
-- If the new emergency system is active, we can reduce the number of RAM     --
-- blocks.                                                                    --
-- This entity supports two different modes that differ from each other by    --
-- the used address map. The so called SAM2 mode is compatible with the SAM2  --
-- layout, whereas the sAM3 mode is compatible with the IMP layout (the base  --
-- address space is different.                                                --
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
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;
USE Indel_lib.INFO_SAM3_Package_Take2.all;
-------------------------------
-- Entity library inclusion END
-------------------------------

ENTITY InfoLink_Control IS
   PORT    (
            GCLK                       : IN    std_logic;
            CLR_n                      : IN    std_logic;
            PPC_Dock                   : INOUT router_dock_t_s_pkg;
            CLK66                      : IN    std_logic;
            InfoLink_Job_IRQ_EN        : IN    std_logic;
            InfoLink_RXC_IRQ_EN        : IN    std_logic;
            InfoLink_TX_RX_Seq_Restart : IN    std_logic;
            InfoLink_Run_EN            : IN    std_logic;
            InfoLink_OverRun_EN        : IN    std_logic;
            InfoLink_Job_IRQ           : OUT   std_logic;
            InfoLink_RXC_IRQ           : OUT   std_logic;
            InfoLink_RX_Error          : OUT   std_logic;
            InfoLink_OverRun           : OUT   std_logic;
            InfoLink_Or1ms             : OUT   std_logic;
            InfoLink_RX                : IN    std_logic;
            InfoLink_TX                : OUT   std_logic;
            InfoLink_LED_REC           : OUT   std_logic;
            InfoLink_LED_OK            : IN    std_logic;
            InfoLink_LED_Error         : IN    std_logic
            );
END ENTITY InfoLink_Control;


ARCHITECTURE Universal OF InfoLink_Control IS
   
   
   -------------------
   -- Type Declaration
   -------------------
   TYPE     t_ilm_state            IS (idle_Info, write_info, preread_info, read_info);
   -----------------------
   -- Type Declaration END
   -----------------------
   
   
   -----------------------
   -- Constant Declaration
   -----------------------
   CONSTANT Delay                  : natural := 1;
   ---------------------------
   -- Constant Declaration END
   ---------------------------
   
   
   ---------------------
   -- Signal Declaration
   ---------------------
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
   SIGNAL   Member_Data            : std_logic_vector(Return_Upper_F_I_PKG(Router_Data_Width_C_S_PKG) DOWNTO 0);
   SIGNAL   CLR                    : std_logic;
   SIGNAL   TDP_InfoLink_AD        : std_logic_vector(10 DOWNTO 0);
   SIGNAL   InfoLink_AD            : std_logic_vector(8 DOWNTO 0);
   SIGNAL   InfoLink_BE            : std_logic_vector(7 DOWNTO 0);
   SIGNAL   InfoLink_Data          : std_logic_vector(63 DOWNTO 0);
   SIGNAL   InfoLink_Data_Out      : std_logic_vector(63 DOWNTO 0);
   SIGNAL   InfoLink_AD_Int        : std_logic_vector(1 DOWNTO 0);
   SIGNAL   InfoLink_WR            : std_logic;
   SIGNAL   l_JobIRQ               : std_logic;
   SIGNAL   l_CIRQ                 : std_logic;
   SIGNAL   l_WDOGout              : std_logic;
   SIGNAL   l_LEDrec               : std_logic;
   SIGNAL   l_Or1ms                : std_logic;
   SIGNAL   l_RUN                  : std_logic;
   SIGNAL   l_ReSt                 : std_logic;
   SIGNAL   l_Tgo_en               : std_logic;
   SIGNAL   l_Trst                 : std_logic;
   SIGNAL   l_Error                : std_logic;
   SIGNAL   l_Ovrun                : std_logic;
   SIGNAL   l_Treq                 : std_logic_vector(1 DOWNTO 0);
   SIGNAL   l_Rreq                 : std_logic_vector(1 DOWNTO 0);
   SIGNAL   l_Tack                 : std_logic;
   SIGNAL   l_Rack                 : std_logic;
   SIGNAL   WDog                   : std_logic;              
   SIGNAL   WDcnt                  : std_logic_vector(17 DOWNTO 0);
   SIGNAL   dpr_R16_req            : std_logic;
   SIGNAL   dpr_WHB_req            : std_logic;
   SIGNAL   dpr_W16_req            : std_logic;
   SIGNAL   dpr_done               : std_logic;           
   SIGNAL   ilm_state              : t_ilm_state;               
   SIGNAL   ilm_DataIn             : std_logic_vector(15 DOWNTO 0);    
   SIGNAL   ilm_DataOut            : std_logic_vector(15 DOWNTO 0);  
   SIGNAL   ilm_Address            : std_logic_vector(10 DOWNTO 0); 
   SIGNAL   l_Reg_IOP              : std_logic_vector(7 DOWNTO 0);
   SIGNAL   Status_Register_Int    : std_logic_vector(7 DOWNTO 0);
   SIGNAL   Status_Register_Out    : std_logic_vector(7 DOWNTO 0);
   SIGNAL   Synch_In               : std_logic_vector(7 DOWNTO 0);
   SIGNAL   Synch_OUT              : std_logic_vector(7 DOWNTO 0);
   SIGNAL   l_Reg_Sta              : std_logic_vector(7 DOWNTO 0);
   SIGNAL   l_Rx_Dat               : std_logic_vector(15 DOWNTO 0);
   -------------------------
   -- Signal Declaration END
   -------------------------
		
   
   ------------------------
   -- Component Declaration
   ------------------------
   COMPONENT InfoLink_TDP_RAM
	   PORT    (
		         address_a		: IN   std_logic_vector(10 DOWNTO 0); -- Remark: in reality we would just need 1024 x 64 Bit (=> (8 DOWNTO 0)!!!)
		         address_b		: IN   std_logic_vector(10 DOWNTO 0);
		         byteena_a		: IN   std_logic_vector(7 DOWNTO 0):= (OTHERS => '1');
		         byteena_b		: IN   std_logic_vector(7 DOWNTO 0):= (OTHERS => '1');
		         clock_a		   : IN   std_logic;
		         clock_b		   : IN   std_logic;
		         data_a		   : IN   std_logic_vector(63 DOWNTO 0);
		         data_b		   : IN   std_logic_vector(63 DOWNTO 0);
		         wren_a		   : IN   std_logic:= '1';
		         wren_b		   : IN   std_logic:= '1';
		         q_a		      : OUT  std_logic_vector(63 DOWNTO 0);
		         q_b		      : OUT  std_logic_vector(63 DOWNTO 0)
	            );
   END COMPONENT InfoLink_TDP_RAM;
   
   
   COMPONENT InfoLink_TDP_RAM_Optimized
	   PORT   (
		        address_a		   : IN   std_logic_vector(8 DOWNTO 0);
		        address_b	    	: IN   std_logic_vector(8 DOWNTO 0);
		        byteena_a		   : IN   std_logic_vector(7 DOWNTO 0):=  (OTHERS => '1');
		        byteena_b		   : IN   std_logic_vector(7 DOWNTO 0):=  (OTHERS => '1');
		        clock_a		   : IN   std_logic;
		        clock_b		   : IN   std_logic;
		        data_a		      : IN   std_logic_vector(63 DOWNTO 0);
		        data_b		      : IN   std_logic_vector(63 DOWNTO 0);
		        wren_a		      : IN   std_logic:= '1';
		        wren_b		      : IN   std_logic:= '1';
		        q_a		         : OUT  std_logic_vector(63 DOWNTO 0);
		        q_b		         : OUT  std_logic_vector(63 DOWNTO 0)
	           );
   END COMPONENT InfoLink_TDP_RAM_Optimized;
   
   
   COMPONENT InfoLink_DprSeq 
      GENERIC (
               C_SpezJob_Implemented       : boolean := true--false
               );                 
      PORT    (
               -- o_TP		                : OUT  std_logic_vector(15 DOWNTO 0);
		         i_Q66		                   : IN   std_logic;
		         i_Reset		                : IN   std_logic;
               -- Dualport Ram
               o_dprAdr	                   : OUT  std_logic_vector(10 DOWNTO 0);-- DP-RAM Adr
               i_dprDat	                   : IN   std_logic_vector(15 DOWNTO 0);-- D15.0 Inp Reg     
               o_dpr_R16_req               : OUT  std_logic;
               o_dpr_WHB_req               : OUT  std_logic;
               o_dpr_W16_req               : OUT  std_logic;
               i_dpr_done	                : IN   std_logic;
               -- Sequenzer ctrl
               i_RUN		                   : IN   std_logic;-- Sequenzer running
               i_ReSt		                : IN   std_logic;-- Sequenzer ReStart
               i_Reg_Sta	                : IN   std_logic_vector(7 DOWNTO 0);
               o_Tgo_en	                   : OUT  std_logic;-- short Puls
               o_Trst		                : OUT  std_logic;-- short Puls
               -- Transmit Data Request
		         i_Treq                      : IN   std_logic_vector(1 DOWNTO 0);
		         o_Tack                      : OUT  std_logic;
               -- Receiver Shift Register
		         i_Rreq                      : IN   std_logic_vector(1 DOWNTO 0);
		         o_Rack                      : OUT  std_logic;
               i_saveIRQ                   : IN   std_logic;                     	
               o_JobIRQ                    : OUT  std_logic;-- Tx Card-IRQ
               -- Debug
               dbg_R_TabEnd                : OUT  std_logic;
               dbg_T_TabEnd                : OUT  std_logic
               );
   END COMPONENT InfoLink_DprSeq;


   COMPONENT InfoLink_TxRx
      PORT    (
               i_Q66                       : IN   std_logic;-- 66MHz									  						
               i_Reset                     : IN   std_logic;-- nRST  			
               i_Tx_Dat                    : IN   std_logic_vector(15 downto 0);-- D15.0 Inp Reg
               o_Rx_Dat                    : OUT  std_logic_vector(15 downto 0);-- D15.0 Out Reg
               o_LEDrec                    : OUT  std_logic;							
               i_WDOGin                    : IN   std_logic;						
               o_WDOGout                   : OUT  std_logic;
               o_CIRQ                      : OUT  std_logic;						
               o_Or1ms                     : OUT  std_logic;
               -- Transmitter/ Receiver
               i_RX                        : IN   std_logic;-- Rec-Input
               o_TX                        : OUT  std_logic;-- Trans-Output
               -- Sequenzer ctrl
               o_RUN                       : OUT  std_logic;-- Sequenzer running
               o_ReSt                      : OUT  std_logic;-- Sequenzer ReStart
               i_Reg_Sta                   : IN   std_logic_vector(7 downto 0);
               i_Reg_IOP                   : IN   std_logic_vector(7 downto 0);
               i_Tgo_en                    : IN   std_logic;-- short nResetPuls
               i_Trst                      : IN   std_logic;-- short nResetPuls
               o_Error                     : OUT  std_logic;-- Transfer Error
               o_Ovrun                     : OUT  std_logic;-- Over-Run 1,2
               -- Transmit Data Request
               o_Treq                      : OUT  std_logic_vector(1 downto 0);
               i_Tack                      : IN   std_logic;
               -- Receiver Data Request
               o_Rreq                      : OUT  std_logic_vector(1 downto 0);
               i_Rack                      : IN   std_logic;
               dbg_o_RErr                  : OUT  std_logic;
               dbg_o_RXr                   : OUT  std_logic;
               dbg_o_RNr                   : OUT  std_logic;
               dbg_o_ReStart               : OUT  std_logic;
               dbg_o_M5old                 : OUT  std_logic
               );   
   END COMPONENT InfoLink_TxRx;
   
   
   COMPONENT InfoLink_Synchronization
	   PORT (
		      data		      : IN   std_logic_vector(7 DOWNTO 0);
		      rdaddress		: IN   std_logic_vector(3 DOWNTO 0);
		      rdclock		   : IN   std_logic;
		      wraddress		: IN   std_logic_vector(3 DOWNTO 0);
		      wrclock		   : IN   std_logic;
		      wren		      : IN   std_logic := '1';
		      q		         : OUT  std_logic_vector(7 DOWNTO 0)
	         );
   END COMPONENT InfoLink_Synchronization;


   -- PRAGMA SYNTHESIS_OFF
   FOR ALL : InfoLink_TDP_RAM USE ENTITY Indel_lib.InfoLink_TDP_RAM;
   FOR ALL : InfoLink_TDP_RAM_Optimized USE ENTITY indel_lib.InfoLink_TDP_RAM_Optimized;
   FOR ALL : InfoLink_DprSeq USE ENTITY Indel_lib.InfoLink_DprSeq;
   FOR ALL : InfoLink_TxRx USE ENTITY Indel_lib.InfoLink_TxRx;
   FOR ALL : InfoLink_Synchronization USE ENTITY Indel_lib.InfoLink_Synchronization;
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


   -- Data Ready Delay
   Delay_Count: PROCESS(GCLK, CLR_n)
      VARIABLE Counter : natural;
   BEGIN
       IF (CLR_n = '0') THEN
           EN_Delay_Counter <= '0';
       ELSIF (GCLK'EVENT AND GCLK = '1') THEN
          IF  (((PPC_Dock.Router_Data.TS = '1') AND (PPC_Dock.Router_Data.WE = '0')) OR ((Burst_OnGoing = '1') AND (WE_INT = '0'))) THEN
             EN_Delay_Counter <= '1';
          ELSIF (PPC_Dock.Acknowledge_Data.Ready_Acknowledge = '1') THEN
             EN_Delay_Counter <= '0';
          END IF;
       END IF;
   END PROCESS Delay_Count;


   -- Concurrent PPC Debug
   PPC_Dock.Member_Data.Data_Ready <= EN_Delay_Counter;
   PPC_Dock.Member_Data.IRQ <= ("00000" & l_Or1ms & l_CIRQ & l_JobIRQ);
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
         IF ((PPC_Dock.Router_Data.WE = '1') AND (PPC_Dock.Router_Data.TS = '1')) THEN
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
   
   
   -- Concurrent 0
   PPC_Dock.Member_Data.Entity_Router_Data <= Member_Data;

   -- Concurrent 1
   CLR <= NOT(CLR_n);

   -- Concurrent 2
   WDog <= WDcnt(17);
   
   -- Concurrent Block 4
   Status_Register_Int <= (InfoLink_OverRun_EN & InfoLink_Run_EN & InfoLink_TX_RX_Seq_Restart & InfoLink_RXC_IRQ_EN & InfoLink_LED_OK & InfoLink_LED_Error & '1' & InfoLink_Job_IRQ_EN);
   l_Reg_Sta <= (Status_Register_Out(7 DOWNTO 4) & "001" & Status_Register_Out(0));
   l_Reg_IOP <= ("00" & Status_Register_Out(3 DOWNTO 2) & "0000");
   Synch_In <= ("00" & l_LEDrec & l_Or1ms & l_Ovrun & l_Error & l_CIRQ & l_JobIRQ);
   InfoLink_Job_IRQ <= Synch_Out(0);
   InfoLink_RXC_IRQ <= Synch_Out(1);
   InfoLink_RX_Error <= Synch_Out(2);
   InfoLink_OverRun <= Synch_Out(3);
   InfoLink_Or1ms <= Synch_Out(4);
   InfoLink_LED_REC <= Synch_Out(5);


   -----------
   -- WatchDog   
   -----------
   -- WDog after 2^17*1/Freq(clk)
   -- 66MHz: 1.99 ms        				 
   Watch_Dog_Counter: PROCESS(CLK66, CLR_n)
   BEGIN    
      IF (CLR_n = '0') THEN -- reset values
         WDcnt <= (OTHERS => '0');
      ELSIF (CLK66'EVENT AND CLK66 = '1') THEN
         IF (l_WDOGout = '1') THEN -- reset WDcnt
            WDcnt <= (OTHERS => '0');
         ELSIF (WDog = '0') THEN -- count until Wdog
            WDcnt <= (WDcnt + 1);
         END IF;                                    	
      END IF;
   END PROCESS Watch_Dog_Counter;
   ---------------
   -- WatchDog END
   ---------------
   
   
   -----------------------------
   -- Input data Synchronization
   -----------------------------
   Status_In: InfoLink_Synchronization
	   PORT MAP (
		          data		      => Status_Register_Int,
		          rdaddress		=> "0000",
		          rdclock		   => CLK66,
		          wraddress		=> "0000",
		          wrclock		   => GCLK,
		          wren		      => '1',
		          q		         => Status_Register_Out
	             );
	---------------------------------
   -- Input data Synchronization END
   ---------------------------------
   
   
   ------------------------------
   -- Output data Synchronization
   ------------------------------
   Status_Out: InfoLink_Synchronization
	   PORT MAP (
		          data		      => Synch_In,
		          rdaddress		=> "0000",
		          rdclock		   => GCLK,
		          wraddress		=> "0000",
		          wrclock		   => CLK66,
		          wren		      => '1',
		          q		         => Synch_Out
	             );
	----------------------------------
   -- Output data Synchronization END
   ----------------------------------
   
   
   -----------------
   -- TxRx Sequencer
   -----------------
	TxRx: InfoLink_TxRx
	   PORT MAP    (
                   i_Q66         => CLK66,			
                   i_Reset       => CLR,	
                   i_Tx_Dat      => ilm_DataOut,	
                   i_WDOGin      => WDog,	
                   i_RX          => InfoLink_RX,	
                   i_Reg_Sta     => l_Reg_Sta,	
                   i_Reg_IOP     => l_Reg_IOP,	
                   i_Tgo_en      => l_Tgo_en,	
                   i_Trst        => l_Trst,		
                   i_Tack        => l_Tack,		
                   i_Rack        => l_Rack,		
                   o_Rx_Dat      => l_Rx_Dat,	
                   o_LEDrec      => l_LEDrec,	
                   o_WDOGout     => l_WDOGout,	
                   o_CIRQ        => l_CIRQ,		
                   o_Or1ms       => l_Or1ms,	
                   o_TX          => InfoLink_TX,	
                   o_Error       => l_Error,	
                   o_Ovrun       => l_Ovrun,	
                   o_RUN         => l_RUN,	
                   o_ReSt        => l_ReSt,	
                   o_Treq        => l_Treq,		
                   o_Rreq        => l_Rreq,		
                   dbg_o_RErr    => OPEN,
                   dbg_o_RXr     => OPEN,
                   dbg_o_RNr     => OPEN,
                   dbg_o_ReStart => OPEN,
                   dbg_o_M5old   => OPEN
                   );
   ---------------------
   --	TxRx Sequencer END
   ---------------------


   -------------------------
   -- Dualport Ram Sequencer
   ------------------------- 
   DprSeq: InfoLink_DprSeq 
      Generic Map (
                   C_SpezJob_Implemented => InfoLink_SPEC_Job_IMPL_C_S_PKG
	               )
      PORT MAP    (
                   i_Q66                 => CLK66,
                   i_Reset               => CLR,
                   -- Dualport Ram
                   o_dprAdr              => ilm_Address,
                   i_dprDat              => ilm_DataOut,
                   o_dpr_R16_req         => dpr_R16_req,
                   o_dpr_WHB_req         => dpr_WHB_req,
                   o_dpr_W16_req         => dpr_W16_req,
                   i_dpr_done            => dpr_done,	 
                   -- Sequenzer ctrl
                   i_RUN                 => l_RUN,
                   i_ReSt                => l_ReSt,
                   i_Reg_Sta             => l_Reg_Sta,
                   o_Tgo_en              => l_Tgo_en,
                   o_Trst                => l_Trst,
                   -- Transmit Data Request
                   i_Treq                => l_Treq,
                   o_Tack                => l_Tack,	
                   -- Receiver Shift Register
                   i_Rreq                => l_Rreq,	
                   o_Rack                => l_Rack, 
                   i_saveIRQ             => l_Rx_Dat(2),        	
                   o_JobIRQ              => l_JobIRQ,
                   dbg_R_TabEnd          => OPEN,
                   dbg_T_TabEnd          => OPEN 
                   );
   -----------------------------
   -- Dualport Ram Sequencer END
   -----------------------------
   
   
   -- We have to adapt the data width based on the fact that it is not possible to instantiate a dual ported RAM with the width's 64/ 16.
   -- dpr_WHB_req => only KillJobs
	-- dpr_W16_req => regular 16 bit write   
   ilm_DataIn  <= x"0000" WHEN (dpr_WHB_req = '1') ELSE l_Rx_Dat;
   InfoLink_Data <= (ilm_DataIn & ilm_DataIn & ilm_DataIn & ilm_DataIn); -- Simplest solution to make it 64 Bit...
   


   SAM2_Mode: IF (Config_InfoLink_Mode_C_S_PKG = 1) GENERATE
      CONSTANT Memory_Width           : natural := 11;
      SIGNAL   Internal_Address       : std_logic_vector(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 0);
   BEGIN
   
      -- Concurrent
      TDP_InfoLink_AD <= ('0' & ilm_Address(10 DOWNTO 1));
      
      
      -------------------
      -- InfoLink TDP RAM
      -------------------
      InfoLink_DP_RAM: InfoLink_TDP_RAM
	      PORT MAP (
		             address_a		=> Internal_Address,
		             address_b		=> TDP_InfoLink_AD,
		             byteena_a		=> PPC_Dock.Router_Data.BE,
		             byteena_b		=> InfoLink_BE,
		             clock_a		   => GCLK,
		             clock_b		   => CLK66,
		             data_a		   => PPC_Dock.Router_Data.Router_Entity_Data,
		             data_b		   => InfoLink_Data,
		             wren_a		   => WE_INT,
		             wren_b		   => InfoLink_WR,
		             q_a		      => Member_Data,
		             q_b		      => InfoLink_Data_Out
	                );
      -----------------------
      -- InfoLink TDP RAM END
      -----------------------
      
      
      -- Concurrent block
      Internal_Address(1 DOWNTO 0) <= PPC_Dock.Router_Data.AD(1 DOWNTO 0) WHEN (Burst_OnGoing = '0') ELSE Burst_Vector(Burst_Counter);
      Internal_Address(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2) <= PPC_Dock.Router_Data.AD(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2);
   
   
      InfoLink_TDP_RAM_Access : PROCESS(CLK66, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            InfoLink_BE <= (OTHERS => '0');
            InfoLink_WR <= '0';
            dpr_done <= '0';
            ilm_state <= idle_info;
         ELSIF (CLK66'EVENT AND CLK66 = '1') THEN
            InfoLink_BE <= (OTHERS => '0');
            InfoLink_WR <= '0';
            dpr_done <= '0';
            CASE ilm_state IS
               WHEN idle_info =>
                  IF ((dpr_W16_req = '1') OR (dpr_WHB_req = '1')) THEN -- write to dpr
                     InfoLink_WR <= '1';
                     InfoLink_BE(2) <= (NOT(ilm_Address(0)) AND dpr_W16_req);
                     InfoLink_BE(3) <= (NOT(ilm_Address(0)));
                     InfoLink_BE(0) <= '0';
                     InfoLink_BE(1) <= '0';
                     InfoLink_BE(6) <= (ilm_Address(0) AND dpr_W16_req);
                     InfoLink_BE(7) <= (ilm_Address(0));
                     InfoLink_BE(4) <= '0';
                     InfoLink_BE(5) <= '0';
                     dpr_done <= '1';
                     ilm_state <= write_info;        
                  ELSIF (dpr_R16_req = '1') THEN -- read from dpr
                     ilm_state <= preread_info;
                  END IF;
               WHEN preread_info =>
                  ilm_state <= read_info; 
                  dpr_done <= '1';
			      WHEN read_info =>
                  ilm_state <= idle_info;
			      WHEN write_info =>
                  ilm_state <= idle_info;
            END CASE;               	
         END IF;
      END PROCESS;
   
   
      Infolink_Data_Assignment: PROCESS(ilm_Address(1 DOWNTO 0), InfoLink_Data_Out)
      BEGIN
         CASE ilm_Address (1 DOWNTO 0) IS
            WHEN "00" =>
               ilm_DataOut <= InfoLink_Data_Out(31 DOWNTO 16);
            WHEN "01" =>
               ilm_DataOut <= InfoLink_Data_Out(63 DOWNTO 48);
            WHEN "10" =>
               ilm_DataOut <= InfoLink_Data_Out(31 DOWNTO 16);
            WHEN "11" =>
               ilm_DataOut <= InfoLink_Data_Out(63 DOWNTO 48);
            WHEN OTHERS =>
               ilm_DataOut <= (OTHERS => '0');
         END CASE;
      END PROCESS Infolink_Data_Assignment;
   END GENERATE SAM2_Mode;
   
   
   SAM3_Mode: IF (Config_InfoLink_Mode_C_S_PKG = 2) GENERATE
      CONSTANT Memory_Width           : natural := 9;
      SIGNAL   Internal_Address       : std_logic_vector(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 0);
   BEGIN
   
      -- Concurrent
      TDP_InfoLink_AD <= ("00" & ilm_Address(10 DOWNTO 2));
      
      
      -------------------
      -- InfoLink TDP RAM
      -------------------
      InfoLink_DP_RAM: InfoLink_TDP_RAM_Optimized
	      PORT MAP  (
		              address_a		   => Internal_Address,
		              address_b	    	=> TDP_InfoLink_AD(8 DOWNTO 0),
		              byteena_a		   => PPC_Dock.Router_Data.BE,
		              byteena_b		   => InfoLink_BE,
		              clock_a		   => GCLK,
		              clock_b		   => CLK66,
		              data_a		      => PPC_Dock.Router_Data.Router_Entity_Data,
		              data_b		      => InfoLink_Data,
		              wren_a		      => WE_INT,
		              wren_b		      => InfoLink_WR,
		              q_a		         => Member_Data,
		              q_b		         => InfoLink_Data_Out
	                 );
	   -----------------------
      -- InfoLink TDP RAM END
      -----------------------
      
      
      -- Concurrent block
      Internal_Address(1 DOWNTO 0) <= PPC_Dock.Router_Data.AD(1 DOWNTO 0) WHEN (Burst_OnGoing = '0') ELSE Burst_Vector(Burst_Counter);
      Internal_Address(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2) <= PPC_Dock.Router_Data.AD(Return_Upper_F_I_PKG(Memory_Width) DOWNTO 2);
      
   
      InfoLink_TDP_RAM_Access : PROCESS(CLK66, CLR_n)
      BEGIN
         IF (CLR_n = '0') THEN
            InfoLink_BE <= (OTHERS => '0');
            InfoLink_WR <= '0';
            dpr_done <= '0';
            ilm_state <= idle_info;
         ELSIF (CLK66'EVENT AND CLK66 = '1') THEN
            InfoLink_BE <= (OTHERS => '0');
            InfoLink_WR <= '0';
            dpr_done <= '0';
            CASE ilm_state IS
               WHEN idle_info =>
                  IF ((dpr_W16_req = '1') OR (dpr_WHB_req = '1')) THEN -- write to dpr
                     InfoLink_WR <= '1';
                     InfoLink_BE(2) <= (NOT(ilm_Address(0)) AND NOT(ilm_Address(1)) AND dpr_W16_req);
                     InfoLink_BE(3) <= (NOT(ilm_Address(0)) AND NOT(ilm_Address(1)));
                     InfoLink_BE(0) <= (ilm_Address(0) AND NOT(ilm_Address(1)) AND dpr_W16_req);
                     InfoLink_BE(1) <= (ilm_Address(0) AND NOT(ilm_Address(1)));
                     InfoLink_BE(6) <= (NOT(ilm_Address(0)) AND ilm_Address(1) AND dpr_W16_req);
                     InfoLink_BE(7) <= (NOT(ilm_Address(0)) AND ilm_Address(1));
                     InfoLink_BE(4) <= (ilm_Address(0) AND ilm_Address(1) AND dpr_W16_req);
                     InfoLink_BE(5) <= (ilm_Address(0) AND ilm_Address(1));
                     dpr_done <= '1';
                     ilm_state <= write_info;        
                  ELSIF (dpr_R16_req = '1') THEN -- read from dpr
                     ilm_state <= preread_info;
                  END IF;
               WHEN preread_info =>
                  ilm_state <= read_info; 
                  dpr_done <= '1';
			      WHEN read_info =>
                  ilm_state <= idle_info;
			      WHEN write_info =>
                  ilm_state <= idle_info;
            END CASE;               	
         END IF;
      END PROCESS;
   
   
      Infolink_Data_Assignment: PROCESS(ilm_Address(1 DOWNTO 0), InfoLink_Data_Out)
      BEGIN
         CASE ilm_Address (1 DOWNTO 0) IS
            WHEN "00" =>
               ilm_DataOut <= InfoLink_Data_Out(31 DOWNTO 16);
            WHEN "01" =>
               ilm_DataOut <= InfoLink_Data_Out(15 DOWNTO 0);
            WHEN "10" =>
               ilm_DataOut <= InfoLink_Data_Out(63 DOWNTO 48);
            WHEN "11" =>
               ilm_DataOut <= InfoLink_Data_Out(47 DOWNTO 32);
            WHEN OTHERS =>
               ilm_DataOut <= (OTHERS => '0');
         END CASE;
      END PROCESS Infolink_Data_Assignment;
   END GENERATE SAM3_Mode;
	
   
END ARCHITECTURE Universal;