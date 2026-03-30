-------------------------------------------------------------------------------
-- $Id: mst_attach.vhd,v 1.3 2001/10/15 22:48:57 ostlerf Exp $
-------------------------------------------------------------------------------
-- Master Attachment - entity and architecture
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        mst_attach.vhd
-- Version:         v1.1
-- Description:     Master attachment for Xilinx OPB
--
-------------------------------------------------------------------------------
--
--              mst_attach.vhd
--
-------------------------------------------------------------------------------
-- Author:      MLL
-- History:
--  MLL      05/09/01      -- First version
--
--  <initials>      <date> 
-- ^^^^^^
--      Description of changes. If multiple lines are needed to fully describe
--      the changes made to the design, these lines should align with each other.
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_cmb" 
--      pipelined or register delay signals:    "*_d#" 
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce" 
--      internal version of output port         "*_i"
--      device pins:                            "*_pin" 
--      ports:                                  - Names begin with Uppercase 
--      processes:                              "*_PROCESS" 
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned."-";  --Used in comparison with counter value
use ieee.std_logic_unsigned."+";  --Used in XferAck counter in burst mode

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
entity mst_attach is
    generic (
        C_OPB_ABUS_WIDTH    : integer;                 -- 32 or 64 bits
        C_OPB_DBUS_WIDTH    : integer;                 -- 32 or 64 bits
        C_MA2SA_NUM_WIDTH   : integer                  -- 4 or 8 bits
        );

    port(
        Reset               : in STD_LOGIC;

       --OPB ports
        OPB_Clk             : in STD_LOGIC;
        OPB_MnGrant         : in STD_LOGIC;
        OPB_XferAck         : in STD_LOGIC;
        OPB_ErrAck          : in STD_LOGIC;
        OPB_TimeOut         : in STD_LOGIC;
        OPB_Retry           : in STD_LOGIC;

       --Master Attachment to OPB ports
        Mn_Request          : out STD_LOGIC;
        Mn_Select           : out STD_LOGIC;
        Mn_RNW_gtd          : out STD_LOGIC;
        Mn_SeqAddr_gtd      : out STD_LOGIC;
        Mn_BusLock_gtd      : out STD_LOGIC;
        Mn_BE_gtd           : out STD_LOGIC_VECTOR (0 to C_OPB_DBUS_WIDTH/8-1);
        Mn_ABus_gtd         : out STD_LOGIC_VECTOR (0 to C_OPB_ABUS_WIDTH-3);

       --Master Attachment to SA ports
        Bus_MnGrant         : out STD_LOGIC;
        MA2SA_Select        : out STD_LOGIC;
        MA2SA_XferAck       : out STD_LOGIC;
        MA2SA_Rd            : out STD_LOGIC;
        MA2SA_Num           : out STD_LOGIC_VECTOR(0 to C_MA2SA_NUM_WIDTH-1);
        SA2MA_RdRdy         : in STD_LOGIC := '0';
        SA2MA_WrAck         : in STD_LOGIC := '0';

       --Master Attachment from IP ports
        Mstr_Sel_ma         : out STD_LOGIC;

       --Master Attachment from IP ports
        IP2Bus_MstAddr      : in STD_LOGIC_VECTOR (0 to C_OPB_ABUS_WIDTH-3) 
                              := (others => '0');
        IP2Bus_MstBE        : in STD_LOGIC_VECTOR (0 to C_OPB_DBUS_WIDTH/8-1) 
                              := (others => '0');
        IP2Bus_MstWrReq     : in STD_LOGIC := '0';
        IP2Bus_MstRdReq     : in STD_LOGIC := '0';
        IP2Bus_MstBurst     : in STD_LOGIC := '0';
        IP2Bus_MstBusLock   : in STD_LOGIC := '0';

       --Master Attachment to IP ports
        Bus2IP_MstWrAck_ma  : out STD_LOGIC;
        Bus2IP_MstRdAck_ma  : out STD_LOGIC;
        Bus2IP_MstRetry_ma  : out STD_LOGIC;
        Bus2IP_MstError_ma  : out STD_LOGIC;
        Bus2IP_MstTimeOut_ma: out STD_LOGIC;
        Bus2IP_MstLastAck_ma: out STD_LOGIC;

       --Master Attachment from DMA ports
        DMA2Bus_MstAddr     : in STD_LOGIC_VECTOR (0 to C_OPB_ABus_WIDTH-3)
                              := (others => '0');
        DMA2Bus_MstBE       : in STD_LOGIC_VECTOR (0 to C_OPB_DBUS_WIDTH/8-1)
                              := (others => '0');
        DMA2Bus_MstWrReq    : in STD_LOGIC := '0';
        DMA2Bus_MstRdReq    : in STD_LOGIC := '0';
        DMA2Bus_MstBurst    : in STD_LOGIC := '0';
        DMA2Bus_MstBusLock  : in STD_LOGIC := '0'
        );
end mst_attach;
-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture implementation of mst_attach is

constant RESET_ACTIVE: std_logic := '1';

--signals
signal Bus2IP_MstLastAck_ma_int: STD_LOGIC;
signal Set_Last_Ack_Nxt_Clk    : STD_LOGIC;
signal Wait_For_WrAck_2_Last_Ack: STD_LOGIC;
signal Bus2IP_MstRdAck_ma_int  : STD_LOGIC;
signal Bus2IP_MstWrAck_ma_int  : STD_LOGIC;
signal Mn_Select_int           : STD_LOGIC;
signal Mn_Request_int          : STD_LOGIC;
signal Mn_ABus_gtd_int         : STD_LOGIC_VECTOR (0 to C_OPB_ABUS_WIDTH-3);
signal Mn_BusLock_gtd_int      : STD_LOGIC;
signal MA2SA_XferAck_int       : STD_LOGIC;
signal MA2SA_XferAck_Dly       : STD_LOGIC;
signal MA2SA_Rd_int            : STD_LOGIC;
signal Mstr_Sel_ma_int         : STD_LOGIC;
signal XXX2Bus_MstAddr         : STD_LOGIC_VECTOR (0 to C_OPB_ABUS_WIDTH-3);
signal XXX2Bus_MstBE           : STD_LOGIC_VECTOR (0 to C_OPB_DBUS_WIDTH/8-1);
signal XXX2Bus_MstBurst        : STD_LOGIC;
signal XXX2Bus_MstBusLock      : STD_LOGIC;
signal IP_Request_HasPriority  :STD_LOGIC;
signal DMA_Request_HasPriority :STD_LOGIC;
signal Mst_OP                  : STD_LOGIC;
signal IP_MstRmtRd_OP             : STD_LOGIC;
signal IP_MstRmtWr_OP             : STD_LOGIC;
signal DMA_MstRmtRd_OP            : STD_LOGIC;
signal DMA_MstRmtWr_OP            : STD_LOGIC;
signal IP_RdReqGrant           : STD_LOGIC;
signal DMA_RdReqGrant          : STD_LOGIC;
signal IP_WrReqGrant           : STD_LOGIC;
signal DMA_WrReqGrant          : STD_LOGIC;
signal Temp_Signal_For_Count   : STD_LOGIC_VECTOR(0 to C_MA2SA_NUM_WIDTH-1);
signal XferAck_Count           : STD_LOGIC_VECTOR(0 to C_MA2SA_NUM_WIDTH-1);
signal Addr_Count              : INTEGER;
signal Addr_Count_counting     : STD_LOGIC;
signal Repeat_Mn_Req           : STD_LOGIC;

begin
--Combinatorial operations
Bus_MnGrant <= OPB_MnGrant;
Mn_Select <= Mn_Select_int;
Mn_Request <= Mn_Request_int;
Mn_ABus_gtd <= Mn_ABus_gtd_int;
Mn_BusLock_gtd <= XXX2Bus_MstBusLock or Mn_BusLock_gtd_int;
MA2SA_Rd <= MA2SA_Rd_int;
MA2SA_XferAck_int <= OPB_XferAck and Mn_Select_int;
MA2SA_XferAck <= MA2SA_XferAck_int;
MA2SA_Select <= Mn_Select_int;
Mstr_Sel_ma <= Mstr_Sel_ma_int;
Bus2IP_MstLastAck_ma <= Bus2IP_MstLastAck_ma_int;
Bus2IP_MstRdAck_ma <= Bus2IP_MstRdAck_ma_int;
Bus2IP_MstWrAck_ma <= Bus2IP_MstWrAck_ma_int;
Mst_OP <= IP_MstRmtRd_OP or IP_MstRmtWr_OP or DMA_MstRmtRd_OP or DMA_MstRmtWr_OP;
Bus2IP_MstRetry_ma <= OPB_Retry and Mn_Select_int;
Bus2IP_MstError_ma <= OPB_ErrAck and Mn_Select_int;
Bus2IP_MstTimeOut_ma <= OPB_TimeOut and Mn_Select_int;


-----------------------------------------------------------------------------------
--Processes for local read/remote write operation**MA2SA_Rd signal control
MA2SA_Rd_PROCESS: process(IP2Bus_MstWrReq, IP_MstRmtWr_OP, DMA2Bus_MstWrReq,
                          DMA_MstRmtWr_OP, OPB_Clk)
--Process to assert MA2SA_Rd and Define Remote Read state (IP or DMA)
begin
   if((IP2Bus_MstWrReq = '0' and IP_MstRmtWr_OP  = '1') or
     (DMA2Bus_MstWrReq = '0' and DMA_MstRmtWr_OP  = '1')) then
      MA2SA_Rd_int <= '0';  --Asynchronously reset if aborted
      IP_MstRmtWr_OP <= '0';
      DMA_MstRmtWr_OP <= '0';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then --Synchronous reset
         MA2SA_Rd_int <= '0';
         IP_MstRmtWr_OP <= '0';
         DMA_MstRmtWr_OP <= '0';
      elsif(IP_WrReqGrant = '1') then     --Start IP Read operation
         MA2SA_Rd_int <= '1';
         IP_MstRmtWr_OP <= '1';
         DMA_MstRmtWr_OP <= '0';
      elsif(DMA_WrReqGrant = '1') then    --Start DMA Read operation
         MA2SA_Rd_int <= '1';
         IP_MstRmtWr_OP <= '0';
         DMA_MstRmtWr_OP <= '1';
      elsif(IP2Bus_MstWrReq = '0' and IP_MstRmtWr_OP = '1') then
         MA2SA_Rd_int <= '0';                 --Reset OP-flag on abort
         IP_MstRmtWr_OP <= '0';
      elsif(DMA2Bus_MstWrReq = '0' and DMA_MstRmtWr_OP = '1') then
         MA2SA_Rd_int <= '0';                 --Reset OP-flag on abort
         DMA_MstRmtWr_OP <= '0';
      elsif(XferAck_Count = Temp_Signal_For_Count-1 and
            MA2SA_XferAck_int = '1') then
         MA2SA_Rd_int <= '0';            --Reset with Last OPB_XferAck
      elsif(Bus2IP_MstLastAck_ma_int = '1') then
         MA2SA_Rd_int <= '0';              --Reset with LastAck
         IP_MstRmtWr_OP <= '0';               --Starts valid arbitration
         DMA_MstRmtWr_OP <= '0';
      end if;
   end if;
end process MA2SA_Rd_PROCESS;

-----------------------------------------------------------------------------------
--Shared processes for local read/remote write & local write/remote read operations

Mn_Select_PROCESS: process(Mst_OP, IP_RdReqGrant, DMA_RdReqGrant,
                   IP_WrReqGrant, DMA_WrReqGrant, IP2Bus_MstRdReq,
                   IP_MstRmtRd_OP, DMA2Bus_MstRdReq, DMA_MstRmtRd_OP, OPB_Clk)
--Process to assert Bus Request and respond with OPB Select
begin
   if((Mst_OP = '0' and IP_RdReqGrant = '0' and DMA_RdReqGrant = '0' and
      IP_WrReqGrant = '0' and DMA_WrReqGrant = '0') or
      (IP2Bus_MstRdReq = '0' and IP_MstRmtRd_OP  = '1') or
      (DMA2Bus_MstRdReq = '0' and DMA_MstRmtRd_OP  = '1')) then
         Mn_Request_int <= '0';
         Mn_Select_int <= '0';
         Mn_RNW_gtd <= '0';
         Mn_BusLock_gtd_int <= '0';
         Mn_SeqAddr_gtd <= '0';
         IP_MstRmtRd_OP <= '0';
         DMA_MstRmtRd_OP <= '0';
         Repeat_Mn_Req <= '0';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then --Synchronous reset
         Repeat_Mn_Req <= '0';
         Mn_Request_int <= '0';
         Mn_Select_int <= '0';
         Mn_RNW_gtd <= '0';
         Mn_BusLock_gtd_int <= '0';
         Mn_SeqAddr_gtd <= '0';
         IP_MstRmtRd_OP <= '0';
         DMA_MstRmtRd_OP <= '0';
      elsif(Mn_Select_int = '1' and 
            (OPB_TimeOut = '1' or OPB_Retry = '1')) then
         Repeat_Mn_Req <= '1';
         Mn_Request_int <= '0';
         Mn_Select_int <= '0';
         Mn_RNW_gtd <= '0';
         Mn_BusLock_gtd_int <= '0';
         Mn_SeqAddr_gtd <= '0';
      elsif(Repeat_Mn_Req = '1') then
         Mn_Request_int <= '1';
         Repeat_Mn_Req <= '0';
      elsif(MA2SA_Rd_int = '1' and SA2MA_RdRdy = '1' and
            Bus2IP_MstLastAck_ma_int = '0') then
         Mn_Request_int <= '1';      --OPB request for remote write operation
         Repeat_Mn_Req <= '0';
      elsif((IP_RdReqGrant = '1' or DMA_RdReqGrant = '1') and
             Bus2IP_MstLastAck_ma_int = '0' and Mn_Select_int = '0') then
         Mn_Request_int <= '1';      --OPB request for remote read operation
         Repeat_Mn_Req <= '0';
         if(IP_RdReqGrant = '1') then
            IP_MstRmtRd_OP <= '1';
         elsif(DMA_RdReqGrant = '1') then
            DMA_MstRmtRd_OP <= '1';
         end if;
      elsif(Mn_Request_int = '1' and OPB_MnGrant = '1') then
         Mn_Request_int <= '0';
         Mn_Select_int <= '1';
         Repeat_Mn_Req <= '0';
         if(MA2SA_Rd_int = '1') then
            Mn_RNW_gtd <= '0';
         else
            Mn_RNW_gtd <= '1';
         end if;
         if(XXX2Bus_MstBurst = '1') then
            Mn_SeqAddr_gtd <= '1';
            Mn_BusLock_gtd_int <= '1';
         else
            Mn_SeqAddr_gtd <= '0';
            Mn_BusLock_gtd_int <= '0';
         end if;
      elsif(MA2SA_Rd_int = '1' and Mn_Select_int = '1') then --MA Read transaction
         if(XferAck_Count = Temp_Signal_For_Count-2 and      --Bring Seq Addr low
            MA2SA_XferAck_int = '1' and XXX2Bus_MstBurst = '1') then
            Mn_SeqAddr_gtd <= '0';
            Mn_BusLock_gtd_int <= '0';
         elsif(XferAck_Count = Temp_Signal_For_Count-1 and    --End transaction
               MA2SA_XferAck_int = '1') then
            Mn_Request_int <= '0';
            Mn_Select_int <= '0';
            Mn_RNW_gtd <= '0';
            Mn_BusLock_gtd_int <= '0';
            Mn_SeqAddr_gtd <= '0';
            Repeat_Mn_Req <= '0';
         end if;
      elsif(Mn_Select_int = '1') then                      --MA Write transaction
         if(XferAck_Count = Temp_Signal_For_Count-2 and    --End transaction
               MA2SA_XferAck_int = '1') then
            Mn_SeqAddr_gtd <= '0';
            Mn_BusLock_gtd_int <= '0';
         elsif(XferAck_Count = Temp_Signal_For_Count-1 and    --End transaction
               MA2SA_XferAck_int = '1') then
            Mn_Request_int <= '0';
            Mn_Select_int <= '0';
            Mn_RNW_gtd <= '0';
            Mn_BusLock_gtd_int <= '0';
            Mn_SeqAddr_gtd <= '0';
            Repeat_Mn_Req <= '0';
         end if;
      elsif(Bus2IP_MstLastAck_ma_int = '1') then
         IP_MstRmtRd_OP <= '0';
         DMA_MstRmtRd_OP <= '0';
         Repeat_Mn_Req <= '0';
      end if;
   end if;
end process Mn_Select_PROCESS;

Address_and_BE_gating_PROCESS: process(Mn_Select_int, OPB_MnGrant, OPB_Clk)
--Process to gate Address bus and BE bus to OPB logic
begin
   if(Mn_Select_int = '0' and OPB_MnGrant = '0') then
      Mn_ABus_gtd_int <= (others => '0');
      Mn_BE_gtd <= (others => '0');
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE or
        (OPB_Retry = '1' and Mn_Select_int = '1')) then --Synchronous reset
         Mn_ABus_gtd_int <= (others => '0');
         Mn_BE_gtd <= (others => '0');
      elsif(Mn_Request_int = '1' and OPB_MnGrant = '1') then
         Mn_ABus_gtd_int <= XXX2Bus_MstAddr;  --Assert with Select
         Mn_BE_gtd <= XXX2Bus_MstBE;
      elsif(XferAck_Count < Temp_Signal_For_Count-1 and
               MA2SA_XferAck_int = '1') then  --De-assert with Select de-asserted
         Mn_ABus_gtd_int <= Mn_ABus_gtd_int + 1;
      elsif(XferAck_Count = Temp_Signal_For_Count-1 and
               MA2SA_XferAck_int = '1') then  --De-assert with Select de-asserted
         Mn_ABus_gtd_int <= (others => '0');
         Mn_BE_gtd <= (others => '0');
      end if;
   end if;
end process Address_and_BE_gating_PROCESS;

Address_and_BE_and_MnBurst_and_BusLock_routing_PROCESS: process(Mst_OP,
                  IP_MstRmtRd_OP, IP_MstRmtWr_OP, IP2Bus_MstAddr, IP2Bus_MstBE,
                  IP2Bus_MstBurst, IP2Bus_MstBusLock, DMA_MstRmtRd_OP,
                  DMA_MstRmtWr_OP, DMA2Bus_MstAddr, DMA2Bus_MstBE, DMA2Bus_MstBurst, 
                  DMA2Bus_MstBusLock)
--Combinatorial process to route IP or DMA data to XXX-data which is xfered to OPB
begin
   if(Mst_OP = '0') then
      XXX2Bus_MstAddr <= (others => '0');
      XXX2Bus_MstBE <= (others => '0');
      XXX2Bus_MstBurst <= '0';
      XXX2Bus_MstBusLock <= '0';
   elsif(IP_MstRmtRd_OP = '1' or IP_MstRmtWr_OP = '1') then
      XXX2Bus_MstAddr <= IP2Bus_MstAddr;
      XXX2Bus_MstBE <= IP2Bus_MstBE;
      XXX2Bus_MstBurst <= IP2Bus_MstBurst;
      XXX2Bus_MstBusLock <= IP2Bus_MstBusLock;
   elsif(DMA_MstRmtRd_OP = '1' or DMA_MstRmtWr_OP = '1') then
      XXX2Bus_MstAddr <= DMA2Bus_MstAddr;
      XXX2Bus_MstBE <= DMA2Bus_MstBE;
      XXX2Bus_MstBurst <= DMA2Bus_MstBurst;
      XXX2Bus_MstBusLock <= DMA2Bus_MstBusLock;
   else
      XXX2Bus_MstAddr <= (others => '0');
      XXX2Bus_MstBE <= (others => '0');
      XXX2Bus_MstBurst <= '0';
      XXX2Bus_MstBusLock <= '0';
   end if;
end process Address_and_BE_and_MnBurst_and_BusLock_routing_PROCESS;

Bus2IP_MstXXAck_PROCESS: process(OPB_CLK)
--Process to generate Rd and Wr Acks
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then --Synchronous reset
         Bus2IP_MstRdAck_ma_int <= '0';
         Bus2IP_MstWrAck_ma_int <= '0';
      elsif(IP_MstRmtRd_OP = '1' or DMA_MstRmtRd_OP = '1') then
         if(XXX2Bus_MstBurst = '0') then
            if(SA2MA_WrAck = '1' and Bus2IP_MstRdAck_ma_int = '0') then
               Bus2IP_MstRdAck_ma_int <= '1';--Local Write Ack for single write
               Bus2IP_MstWrAck_ma_int <= '0';
            else
               Bus2IP_MstRdAck_ma_int <= '0';
               Bus2IP_MstWrAck_ma_int <= '0';  --Wait for (SA2MA_)IP2Bus_WrAck
            end if;
         else
            Bus2IP_MstRdAck_ma_int <= MA2SA_XferAck_Dly;--Local Write Ack for burst write
            Bus2IP_MstWrAck_ma_int <= '0';
         end if;
      elsif(IP_MstRmtWr_OP = '1' or DMA_MstRmtWr_OP = '1') then
         Bus2IP_MstWrAck_ma_int <= MA2SA_XferAck_int;  --Write Ack for all local read
      else
         Bus2IP_MstRdAck_ma_int <= '0';
         Bus2IP_MstWrAck_ma_int <= '0';
      end if;
   end if;
end process Bus2IP_MstXXAck_PROCESS;

MA2SA_XferAck_Dly_PROCESS: process(OPB_Clk)
--Process to delay MA2SA_XferAck
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then  --Synchronous reset
         MA2SA_XferAck_Dly <= '0';
      else
         MA2SA_XferAck_Dly <= MA2SA_XferAck_int;
      end if;
   end if;
end process MA2SA_XferAck_Dly_PROCESS;

Bus2IP_MstLastAck_PROCESS: process(OPB_Clk)
--Process to generate Last Ack
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then  --Synchronous reset
         Bus2IP_MstLastAck_ma_int <= '0';
         Set_Last_Ack_Nxt_Clk <= '0';
         Wait_For_WrAck_2_Last_Ack <= '0';
      elsif(Wait_For_WrAck_2_Last_Ack = '1') then
         if(SA2MA_WrAck = '1' and Bus2IP_MstLastAck_ma_int = '0') then
            Bus2IP_MstLastAck_ma_int <= '1';
            Wait_For_WrAck_2_Last_Ack <= '0';
         else
            Bus2IP_MstLastAck_ma_int <= '0';
         end if;
         Set_Last_Ack_Nxt_Clk <= '0';
      elsif(Set_Last_Ack_Nxt_Clk = '1') then
         Bus2IP_MstLastAck_ma_int <= '1';
         Set_Last_Ack_Nxt_Clk <= '0';
         Wait_For_WrAck_2_Last_Ack <= '0';
      elsif(Mn_Select_int = '1' and Bus2IP_MstLastAck_ma_int = '0' and
               XferAck_Count = Temp_Signal_For_Count-1) then --Include Mn_Select to reset if abort
         if(MA2SA_XferAck_int = '1') then
            if(IP_MstRmtRd_OP = '1' or DMA_MstRmtRd_OP = '1') then --Rmt Read OP condition
               Bus2IP_MstLastAck_ma_int <= '0';
               if(XXX2Bus_MstBurst = '0') then  --Single Write condition
                  Wait_For_WrAck_2_Last_Ack <= '1';   --Single lcl Wr condition requires WrAck
                  Set_Last_Ack_Nxt_Clk <= '0';
               else
                  Set_Last_Ack_Nxt_Clk <= '1';   --Burst lcl Wr condition is Fire and Forget
                  Wait_For_WrAck_2_Last_Ack <= '0';
               end if;
            else      --Rmt Write Operation
               Bus2IP_MstLastAck_ma_int <= '1';
               Wait_For_WrAck_2_Last_Ack <= '0';
               Set_Last_Ack_Nxt_Clk <= '0';
            end if;
         else
            Bus2IP_MstLastAck_ma_int <= '0';
            Wait_For_WrAck_2_Last_Ack <= '0';
            Set_Last_Ack_Nxt_Clk <= '0';
         end if;
      else
         Bus2IP_MstLastAck_ma_int <= '0';
         Set_Last_Ack_Nxt_Clk <= '0';
         Wait_For_WrAck_2_Last_Ack <= '0';
      end if;
   end if;
end process Bus2IP_MstLastAck_PROCESS;

Set_Value_of_MA2SA_Num_PROCESS: process(DMA_MstRmtRd_OP, DMA_MstRmtWr_OP, DMA2Bus_MstBurst,
                                        IP_MstRmtRd_OP, IP_MstRmtWr_OP, IP2Bus_MstBurst)
--Process to set value of MA2SA_Num which is fixed to 8 or 1 at the time of the
--code development.  Ease in implementing an input from the master IP is
--realized with this additional code
begin
  if(DMA_MstRmtRd_OP = '1' or DMA_MstRmtWr_OP = '1') then
     if(DMA2Bus_MstBurst = '1') then
        MA2SA_Num <= "1000";
     else
        MA2SA_Num <= "0001";
     end if;
  elsif(IP_MstRmtRd_OP = '1' or IP_MstRmtWr_OP = '1') then
     if(IP2Bus_MstBurst = '1') then
        MA2SA_Num <= "1000";
     else
        MA2SA_Num <= "0001";
     end if;
   else
      MA2SA_Num <= "0001";
   end if;
end process Set_Value_of_MA2SA_Num_PROCESS;

Set_Value_of_Temp_Signal_For_Count_PROCESS: process(XXX2Bus_MstBurst)
--Process to set count value which is fixed to 8 or 1 at the time of the
--code development.  Ease in implementing an input from the master IP is
--realized with this additional code
begin
   if(XXX2Bus_MstBurst = '1') then
      Temp_Signal_For_Count <= "1000";
   else
      Temp_Signal_For_Count <= "0001";
   end if;
end process Set_Value_of_Temp_Signal_For_Count_PROCESS;

XferAck_Count_PROCESS: process(Mn_Select_int, OPB_Clk)
--Process to count the number of OPB_XferAcks when local select is asserted
begin
   if(Mn_Select_int = '0') then
      XferAck_Count <= (others => '0');
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE or Bus2IP_MstLastAck_ma_int = '1') then
         XferAck_Count <= (others => '0');      --Synchronous reset
      elsif(MA2SA_XferAck_int = '1') then
         XferAck_Count <= XferAck_Count + 1;
      end if;
   end if;
end process XferAck_Count_PROCESS;

Mstr_Sel_PROCESS: process(OPB_Clk)
--Process to properly encode Mstr_Sel
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(DMA_MstRmtRd_OP = '1' or DMA_MstRmtWr_OP = '1') then
         if(Bus2IP_MstLastAck_ma_int = '0') then
            Mstr_Sel_ma_int <= '1';
         else
            Mstr_Sel_ma_int <= '0';
         end if;
      else
         Mstr_Sel_ma_int <= '0';
      end if;
   end if;
end process Mstr_Sel_PROCESS;

Rd_Request_Grant_PROCESS: process(IP2Bus_MstRdReq, IP2Bus_MstWrReq,
                       DMA2Bus_MstRdReq, DMA2Bus_MstWrReq, Mst_OP,
                       Bus2IP_MstLastAck_ma_int, IP_Request_HasPriority,
                       DMA_Request_HasPriority)
--Process to issue READ grant for request based on priority assignment
begin
   if(((IP2Bus_MstRdReq = '1' and IP2Bus_MstWrReq = '0') or
       (DMA2Bus_MstRdReq = '1' and DMA2Bus_MstWrReq = '0')) and
        Mst_OP = '0' and Bus2IP_MstLastAck_ma_int = '0') then
      if(IP_Request_HasPriority = '1' and IP2Bus_MstRdReq = '1') then
         IP_RdReqGrant <= '1';
         DMA_RdReqGrant <= '0';
      elsif(DMA_Request_HasPriority = '1' and DMA2Bus_MstRdReq = '1') then
         IP_RdReqGrant <= '0';
         DMA_RdReqGrant <= '1';
      elsif(IP2Bus_MstRdReq = '1') then
         IP_RdReqGrant <= '1';
         DMA_RdReqGrant <= '0';
      elsif(DMA2Bus_MstRdReq = '1') then
         IP_RdReqGrant <= '0';
         DMA_RdReqGrant <= '1';
      end if;
   else
      IP_RdReqGrant <= '0';
      DMA_RdReqGrant <= '0';
   end if;
end process Rd_Request_Grant_PROCESS;

Wr_Request_Grant_PROCESS: process(IP2Bus_MstRdReq, IP2Bus_MstWrReq,
                       DMA2Bus_MstRdReq, DMA2Bus_MstWrReq, Mst_OP,
                       Bus2IP_MstLastAck_ma_int, IP_Request_HasPriority,
                       DMA_Request_HasPriority)
--Process to issue WRITE grant for request based on priority assignment
begin
   if(((IP2Bus_MstRdReq = '0' and IP2Bus_MstWrReq = '1') or
       (DMA2Bus_MstRdReq = '0' and DMA2Bus_MstWrReq = '1')) and
        Mst_OP = '0' and Bus2IP_MstLastAck_ma_int = '0') then
      if(IP_Request_HasPriority = '1' and IP2Bus_MstWrReq = '1') then
         IP_WrReqGrant <= '1';
         DMA_WrReqGrant <= '0';
      elsif(DMA_Request_HasPriority = '1' and DMA2Bus_MstWrReq = '1') then
         IP_WrReqGrant <= '0';
         DMA_WrReqGrant <= '1';
      elsif(IP2Bus_MstWrReq = '1') then
         IP_WrReqGrant <= '1';
         DMA_WrReqGrant <= '0';
      elsif(DMA2Bus_MstWrReq = '1') then
         IP_WrReqGrant <= '0';
         DMA_WrReqGrant <= '1';
      end if;
   else
      IP_WrReqGrant <= '0';
      DMA_WrReqGrant <= '0';
end if;
end process Wr_Request_Grant_PROCESS;

Request_Arbitration_PROCESS: process(OPB_Clk)
--Process to set priority for IP and DMA requests that occur at the 
--same time
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then
         IP_Request_HasPriority <= '1';
         DMA_Request_HasPriority <= '0';
      elsif(Bus2IP_MstLastAck_ma_int = '1') then
         if(IP_MstRmtRd_OP = '1' or IP_MstRmtWr_OP = '1') then
            IP_Request_HasPriority <= '0';
            DMA_Request_HasPriority <= '1';
         elsif(DMA_MstRmtRd_OP = '1' or DMA_MstRmtWr_OP = '1') then
            IP_Request_HasPriority <= '1';
            DMA_Request_HasPriority <= '0';
         end if;
      end if;
   end if;
end process Request_Arbitration_PROCESS;

Remote_Addr_Burst_Cntr_PROCESS: process(Mn_Select_int, OPB_Clk)
--Process to provide increment for address
begin
   if(Mn_Select_int = '0') then             --Reset with Bus2IPRangeSel
      Addr_Count <= 1;
      Addr_Count_counting <= '0';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then --Synchronous Reset
         Addr_Count <= 1;
         Addr_Count_counting <= '0';
      elsif(Mn_Select_int = '1' and XXX2Bus_MstBurst = '1') then
         Addr_Count_counting <= '1';
         if(MA2SA_XferAck_int = '1') then
            Addr_Count <= Addr_Count + 1;
         end if;
      end if;
   end if;
end process Remote_Addr_Burst_Cntr_PROCESS;

end implementation;

