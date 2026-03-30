-------------------------------------------------------------------------------
-- $Id: slave_attachment.vhd,v 1.7 2001/11/30 17:09:12 ostlerf Exp $
-------------------------------------------------------------------------------
-- Slave attachment entity and architecture
-------------------------------------------------------------------------------
--
--                  ****************************
--                  ** Copyright Xilinx, Inc. **
--                  ** All rights reserved.   **
--                  ****************************
--
-------------------------------------------------------------------------------
-- Filename:        slave_attachment.vhd
--
-- Description:     OPB slave attachment for accessing arbitray byte(s) within
--                  word boundary aligned addresses on the OPB side.  Addresses
--                  are required to be contiguous word addresses starting at
--                  C_SLAVE_ATT_BAR with all lsbs are zero to C_SLAVE_ATT_BAR
--                  with all lsbs ones. This module has the master attachment
--                  functionality. This module is written to IEEE-93 vhdl specs.
--
-------------------------------------------------------------------------------
-- Structure: 
--
--              slave_attachment.vhd
-------------------------------------------------------------------------------
-- Author:      ML
-- History:
--      ML      04/20/01        -- First version
--
--      ALS     08/21/01    
-- ^^^^^^
--      Changed addr_sel_int to be of type integer. Addr_sel is then the
--      result of CONV_std_logic_vector function using addr_sel_int and the
--      C_SL_ATT_ADDR_SEL_WIDTH generic. 
--
--      Also changed the implementation of the master data buffer from registers
--      to SRL16 fifos.
-- ~~~~~~
--
--      ALS     08/24/01
-- ^^^^^^
--      Implemented Slave Only - No Burst logic using a state machine.
-- ~~~~~~
--
--      ALS     08/30/01
-- ^^^^^^
--      Added registers for OPB bus signals. Bus2IP address bus is no longer
--      zero'd as the address mux is a true mux.
--      Added pselect module for address decode.
-- ~~~~~~
--
--      ALS     09/10/01
-- ^^^^^^
--      Modified SLAVE ONLY NO BURST mode:
--      Pulled generation of Sln_Dbus_gtd_cmb from state machine. Instead, 
--      state machine just generates sln_dbus_rst. Sln_DBus_gtd is now
--      registers with IP2Bus_Data_sa as the D input, sln_dbus_rst as the
--      synchronous reset, and IP2Bus_RdAck_sa as the CE.
-- ~~~~~~
--
--      ALS     09/11/01
-- ^^^^^^
--      Modified SLAVE ONLY, BURST mode:
--      Implemented this logic as a state machine. Added bus registers.
-- ~~~~~~
--
--      ALS     09/13/01
-- ^^^^^^
--      Fixed implementation of Sln_ErrAck in both SLAVE ONLY BURST and NO 
--      BURST modes. IP must assert IP2Bus_RdAck or IP2Bus_WrAck when 
--      asserting IP2Bus_ErrAck. Changed sln_dbus_rst to sln_rst since this
--      signal will be used to reset both Sln_DBus and Sln_ErrAck.
-- ~~~~~~
--
--      ALS     09/18-19/01
-- ^^^^^^
--      Modified SLAVE ONLY BURST mode:
--      Implemented necessary changes to allow bursts to operate correctly.
-- ~~~~~~
--
--      ALS     09/25/01
-- ^^^^^^
--      Merged slv_attach.vhd and slave_attachment.vhd files. Incorporated new
--      generics and renamed generics as needed. Extended address bus to include
--      lower two bits. NO MODIFICATIONS TO THE SLAVE/MASTER module have been
--      made at this time.
-- ~~~~~~
--
--      ALS     09/28/01
-- ^^^^^^
--      Moved SRL_FIFOs to processor common library. Added library statement
--      and updated SRL_FIFO component declaration.
-- ~~~~~~
--
--      ALS     10/02/01
-- ^^^^^^
--      Modified SLAVE FULL mode to extend the address bus to include lower
--      two bits.
-- ~~~~~~
--
--      ML      10/23/01
-- ^^^^^^
--      Fixed problem that Bus2IP_RNW_sa was '1' instead of '0' during an
--      inbound slave write transaction that immediately followed a
--      burst read into the output buffer in preparation for a master
--      burst write transaction.
--      
-- ~~~~~~
--
--      FO      11/29/01
-- ^^^^^^
--      Changed the Full_Function_Slv_Attach version
--      so that Valid_Decode is generated using the high-order
--      C_DEV_ADDR_DECODE_WIDTH bits instead of being calculated
--      as C_OPB_ABUS_WIDTH - C_IPIF_ABUS_WIDTH - 2, which
--      was incompatible with the philosophy change that
--      allows undecoded bits.
--      
-- ~~~~~~
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
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
use ieee.std_logic_unsigned.all;     -- provides conv_std_logic_vector function
use ieee.std_logic_unsigned.CONV_INTEGER;  --Used in byte count compare 2 MA2SA_Num
use ieee.std_logic_arith.conv_std_logic_vector;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.ipif_pkg.all;

-- PROC_COMMON library contains the pselect and srl_fifo components
library proc_common_v1_00_a;
use proc_common_v1_00_a.all;

-------------------------------------------------------------------------------
-- Port Declaration
-------------------------------------------------------------------------------
--  Definition of Generics
--      C_OPB_ABUS_WIDTH            -- OPB address bus width                
--      C_OPB_DBUS_WIDTH            -- OPB data bus width
--      C_IPIF_ABUS_WIDTH           -- IPIF address bus width
--      C_IPIF_DBUS_WIDTH           -- IPIF data bus width
--      C_DEV_ADDR_DECODE_WIDTH     -- number of upper address bits to decode 
--      C_SL_ATT_ADDR_SEL_WIDTH     -- address mux select bus width
--      C_SLAVE_ATT_BASE            -- base address of slave attachment     
--      C_SLN_BURST                 -- indicates if burst is supported      
--      C_SLN_ONLY                  -- indicates if device is slave only    
--      C_MA2SA_NUM_WIDTH           -- width of master to slave number  
--      C_SLN_BUFFER_DEPTH          -- depth of master buffer in slave attachment
--
--
--  Definition of Ports
--      in Reset            
--
--      --OPB ports
--      in OPB_Clk          
--      in OPB_Select       
--      in OPB_RNW          
--      in OPB_SeqAddr      
--      in OPB_BE           
--      in OPB_ABus         
--      in OPB_DBus         
--
--      out Sln_DBus_gtd     
--      out Sln_XferAck      
--      out Sln_ErrAck       
--      out Sln_ToutSup      
--      out Sln_Retry        
--
--      --Master Attachment ports
--      in Bus_MnGrant      
--      in MA2SA_Select     
--      in MA2SA_XferAck    
--      in MA2SA_Rd         
--      in MA2SA_Num        
--                          
--      out SA2MA_RdRdy      
--      out SA2MA_WrAck      
--
--      -Address MUX ports
--      out Addr_Sel         
--      out Addr_Cntr_ClkEn  
--
--      -IP ports
--      out Bus2IP_Burst_sa  
--      out Bus2IP_RNW_sa    
--
--      out Bus2IP_BE_sa     
--      out Bus2IP_Addr_sa   
--      out Bus2IP_Data_sa   
--      out Bus2IP_RangeSel  
--      out Bus2IP_WrReq_sa  
--      out Bus2IP_RdReq_sa  
--
--      in IP2Bus_Data_sa   
--      in IP2Bus_WrAck_sa  
--      in IP2Bus_RdAck_sa  
--      in IP2Bus_ErrAck_sa 
--      in IP2Bus_ToutSup_sa
--      in IP2Bus_Retry_sa  
-------------------------------------------------------------------------------
entity slave_attachment is
    generic (
        C_OPB_ABUS_WIDTH        : integer;        
        C_OPB_DBUS_WIDTH        : integer;           
        C_IPIF_ABUS_WIDTH       : integer;           
        C_IPIF_DBUS_WIDTH       : integer;
        C_DEV_ADDR_DECODE_WIDTH : integer;          
        C_SL_ATT_ADDR_SEL_WIDTH : integer;           
        C_SLAVE_ATT_BASE        : std_logic_vector;  
        C_SLN_BURST             : boolean;           
        C_SLN_ONLY              : boolean;           
        C_MA2SA_NUM_WIDTH       : integer :=4;       
        C_SLN_BUFFER_DEPTH      : integer :=8        
        );
    port(        
        Reset           : in std_logic;
        OPB_Clk         : in std_logic;
        OPB_Select      : in std_logic;
        OPB_RNW         : in std_logic;
        OPB_SeqAddr     : in std_logic;
        OPB_BE          : in std_logic_vector (0 to C_OPB_DBUS_WIDTH/8-1);
        OPB_ABus        : in std_logic_vector (0 to C_OPB_ABUS_WIDTH-1);
        OPB_DBus        : in std_logic_vector (0 to C_OPB_DBUS_WIDTH-1);
        Sln_DBus_gtd    : out std_logic_vector (0 to C_OPB_DBUS_WIDTH-1);
        Sln_XferAck     : out std_logic;
        Sln_ErrAck      : out std_logic;
        Sln_ToutSup     : out std_logic;
        Sln_Retry       : out std_logic;
        Bus_MnGrant     : in std_logic := '0';
        MA2SA_Select    : in std_logic := '0';
        MA2SA_XferAck   : in std_logic := '0';
        MA2SA_Rd        : in std_logic := '0';
        MA2SA_Num       : in std_logic_vector(0 to C_MA2SA_NUM_WIDTH-1)
                             := (others => '0');
        SA2MA_RdRdy     : out std_logic;
        SA2MA_WrAck     : out std_logic;
        Addr_Sel        : out std_logic_vector (0 to C_SL_ATT_ADDR_SEL_WIDTH-1);
        Addr_Cntr_ClkEn : out std_logic;
        Bus2IP_Burst_sa : out std_logic;
        Bus2IP_RNW_sa   : out std_logic;
        Bus2IP_BE_sa    : out std_logic_vector (0 to C_IPIF_DBUS_WIDTH/8-1);
        Bus2IP_Addr_sa  : out std_logic_vector (0 to C_IPIF_ABUS_WIDTH-1);
        Bus2IP_Data_sa  : out std_logic_vector (0 to C_IPIF_DBUS_WIDTH-1);
        Bus2IP_RangeSel : out std_logic;
        Bus2IP_WrReq_sa : out std_logic;
        Bus2IP_RdReq_sa : out std_logic;
        IP2Bus_Data_sa  : in std_logic_vector (0 to C_IPIF_DBUS_WIDTH-1);
        IP2Bus_WrAck_sa : in std_logic;
        IP2Bus_RdAck_sa : in std_logic;
        IP2Bus_ErrAck_sa: in std_logic;
        IP2Bus_ToutSup_sa: in std_logic;
        IP2Bus_Retry_sa : in std_logic
        );
end slave_attachment;

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------

architecture implementation of slave_attachment is

-------------------------------------------------------------------------------
-- Constant Declarations
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
type Sln_DBus_array is array (0 to C_SLN_BUFFER_DEPTH-1) of
                       std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
                       
signal OPB_DBus_1Dly       : std_logic_vector (0 to C_OPB_DBUS_WIDTH-1);
signal OPB_DBus_Stored     : std_logic;
signal OPB_SeqAddr_1Dly    : std_logic := '0';
signal Sln_XferAck_int     : std_logic := '0';
signal Sln_XferAck_1Dly    : std_logic := '0';
signal IP2Bus_ErrAck_sa_Synchd: std_logic := '0';

signal opb_abus_d1          : std_logic_vector(0 to C_OPB_ABUS_WIDTH-1);
signal opb_dbus_d1          : std_logic_vector (0 to C_OPB_DBUS_WIDTH-1);
signal opb_rnw_d1           : std_logic;
signal opb_select_d1        : std_logic;
signal opb_seqaddr_d1       : std_logic;
--signal opb_seqaddr_d2       : std_logic;
signal opb_be_d1            : std_logic_vector(0 to C_OPB_DBUS_WIDTH/8-1);

-- sln_dbus fifo signals
signal Sln_DBus             : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
signal sln_dbus_fifo_rst    : std_logic := '0';
signal sln_dbus_fifo_wr     : std_logic := '0';
signal sln_dbus_fifo_rd     : std_logic := '0';
signal sln_dbus_fifo_notmt  : std_logic := '0';

-- slave only, no burst state machine signals
type SLVONLY_NOBURST_CTRLSMTYPE is (IDLE, ACK, SET_RANGE_SEL, SET_REQ, WAIT_ACK);
signal sonb_ctrlsm_cs, sonb_ctrlsm_ns : SLVONLY_NOBURST_CTRLSMTYPE;
-- Slave Only, Burst state machine signals
type SLVONLY_CTRLSMTYPE is (IDLE, ACK, RETRY, SET_RANGE_SEL, SET_REQ, WAIT_ACK);
signal sob_ctrlsm_cs, sob_ctrlsm_ns : SLVONLY_CTRLSMTYPE;

signal Bus2IP_RangeSel_Dec_cmb  : std_logic;
signal Bus2IP_Data_sa_cmb       : std_logic_vector(0 to C_IPIF_DBUS_WIDTH-1 );
signal Bus2IP_Data_sa_i         : std_logic_vector(0 to C_IPIF_DBUS_WIDTH-1 );
signal Bus2IP_Addr_sa_cmb       : std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1 );
signal Bus2IP_Addr_sa_i         : std_logic_vector(0 to C_IPIF_ABUS_WIDTH-1 );
signal Bus2IP_RdReq_sa_Dec_cmb  : std_logic := '0';
signal Bus2IP_WrReq_sa_Dec_cmb  : std_logic := '0';
signal sln_retry_i              : std_logic := '0';
signal Sln_Retry_cmb            : std_logic := '0';
signal Sln_XferAck_cmb          : std_logic := '0';
signal sln_rst_cmb              : std_logic := '0';     -- used to reset Sln_Dbus and Sln_ErrAck
signal sln_rst                  : std_logic;
signal Sln_DBus_gtd_i           : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1 );

signal burst                    : std_logic;

--signal Addr_Sel_int        : std_logic_vector (0 to C_SL_ATT_ADDR_SEL_WIDTH-1);
signal Addr_Sel_int             : integer := 0;
signal addr_sel_vec_cmb         : std_logic_vector (0 to C_SL_ATT_ADDR_SEL_WIDTH-1);
signal addr_sel_vec             : std_logic_vector (0 to C_SL_ATT_ADDR_SEL_WIDTH-1);
signal addr_cntr_clken_cmb      : std_logic := '0';

signal MA2SA_Select_1Dly   : std_logic := '0';
signal MA2SA_XferAck_1Dly  : std_logic := '0';
signal MA_Local_SingleWr   : std_logic := '0';
signal MA_Local_BurstWr    : std_logic := '0';
signal MA_Local_BurstWr_1Dly: std_logic := '0';
signal MA_Local_SingleRd   : std_logic := '0';
signal MA_Local_BurstRd    : std_logic := '0';
signal MA_Local_BurstRd_Sel_Cntrl: std_logic := '0';
signal MA_Local_BurstWr_Sel_Cntrl: std_logic := '0';
signal Bus_Local_SingleWr  : std_logic := '0';
signal Bus_Local_BurstWr   : std_logic := '0';
signal Bus_Local_SingleRd  : std_logic := '0';
signal Bus_Local_BurstRd   : std_logic := '0';
signal Bus_Local_BurstWr_Sel_Cntrl: std_logic := '0';
signal Bus_Local_BurstRd_Sel_Cntrl: std_logic := '0';
signal SA2MA_RdRdy_int     : std_logic := '0';
signal Pre_MnRequest_Flag  : std_logic := '0';
signal Rd_Count            : integer range 0 to 15 := 0;
signal Rd_Count_counting   : std_logic := '0';
signal Remote_Write_Index  : integer range 0 to 15 := 0;
signal Bus2IP_RangeSel_Dec : std_logic := '0';
signal Bus2IP_RangeSel_MA  : std_logic := '0';
signal Bus2IP_WrReq_sa_Dec : std_logic := '0';
signal Bus2IP_WrReq_sa_MA  : std_logic := '0';
signal Bus2IP_RdReq_sa_Dec : std_logic := '0';
signal Bus2IP_RdReq_sa_MA  : std_logic := '0';
signal SA_Sln_Retry        : std_logic := '0';
signal request_rdy_Dec     : std_logic := '0';
signal request_rdy_MA      : std_logic := '0';
signal Valid_Decode        : std_logic := '0';
signal Seq_Addr_Went_Low   : std_logic := '0';
signal Hold_for_1Prd_After_SeqAddr_low : std_logic := '0';

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
-- SRL_FIFO is used to provide buffering of master burst data in the slave 
-- attachment
component srl_fifo is
  generic (
    C_DATA_BITS : natural := 8;
    C_DEPTH     : natural := 16
    );
  port (
    Clk         : in  std_logic;
    Reset       : in  std_logic;
    FIFO_Write  : in  std_logic;
    Data_In     : in  std_logic_vector(0 to C_DATA_BITS-1);
    FIFO_Read   : in  std_logic;
    Data_Out    : out std_logic_vector(0 to C_DATA_BITS-1);
    FIFO_Full   : out std_logic;
    Data_Exists : out std_logic;
    Addr        : out std_logic_vector(0 to 3)
    );

end component srl_fifo;

-- PSELECT is used to decode the upper address bits
component pselect is
  
  generic (
    C_AB     : integer := 9;
    C_AW     : integer := 32;
    C_BAR    : std_logic_vector
    );
  port (
    A        : in   std_logic_vector(0 to C_AW-1);
    AValid   : in   std_logic;
    CS       : out  std_logic
    );
end component pselect;
-------------------------------------------------------------------------------
-- Slv_Attach_PROCESS
-------------------------------------------------------------------------------
begin
Full_Function_Slv_Attach: if(not(C_SLN_ONLY)) generate

--Combinatorial operations
Bus2IP_BE_sa <= OPB_BE;
Sln_ToutSup <= IP2Bus_ToutSup_sa and Valid_Decode;
Sln_Retry <= (IP2Bus_Retry_sa and Valid_Decode) or SA_Sln_Retry;
Sln_ErrAck <= IP2Bus_ErrAck_sa_Synchd and Valid_Decode;
Bus2IP_RangeSel <= Bus2IP_RangeSel_Dec or Bus2IP_RangeSel_MA;
Bus2IP_WrReq_sa <= Bus2IP_WrReq_sa_Dec or Bus2IP_WrReq_sa_MA;
Bus2IP_RdReq_sa <= Bus2IP_RdReq_sa_Dec or Bus2IP_RdReq_sa_MA;
Sln_XferAck <= Sln_XferAck_int;
Addr_Sel <= conv_std_logic_vector(Addr_Sel_int, C_SL_ATT_ADDR_SEL_WIDTH);
SA2MA_RdRdy <= SA2MA_RdRdy_int;
SA2MA_WrAck <= IP2Bus_WrAck_sa and Bus2IP_RangeSel_MA;

--------------------------------------------------------------------------------
--OPB related processes
OPB_Asynch_Decode_PROCESS: process(OPB_Select, Reset, OPB_ABus)
--Process to asynchronously decode range
begin
   if(OPB_Select = '1') then
      if(Reset = RESET_ACTIVE) then       --Synchronous reset
         Valid_Decode <= '0';
      elsif(OPB_ABus(0 to C_DEV_ADDR_DECODE_WIDTH-1)
         = C_SLAVE_ATT_BASE(0 to C_DEV_ADDR_DECODE_WIDTH-1)) then
            Valid_Decode <= '1';
      else
         Valid_Decode <= '0';
      end if;
   else
      Valid_Decode <= '0';
   end if;
end process OPB_Asynch_Decode_PROCESS;

OPB_Decode_Range_Select_PROCESS: process (OPB_Select, Bus_Local_BurstWr, Valid_Decode,
                                          Bus_Local_SingleWr, Bus_Local_BurstRd, 
                                          Hold_for_1Prd_After_SeqAddr_low, OPB_SeqAddr,
                                          OPB_Clk)
--Process to regiser valid decode as Bus2IP_RangeSel signal
begin
   if(OPB_Select = '0' and Bus_Local_BurstWr = '0') then  --Asynchronously RESET All when select low
      Seq_Addr_Went_Low <= '0';
      Bus2IP_RangeSel_Dec <= '0';
      Bus2IP_Addr_sa <= (others => '0');
      Bus_Local_SingleWr <= '0';
      Bus_Local_SingleRd <= '0';
      Bus_Local_BurstWr <= '0';
      Bus_Local_BurstRd <= '0';
   elsif(Valid_Decode = '0' and Bus_Local_SingleWr = '1') then
      Seq_Addr_Went_Low <= '0';
      Bus2IP_RangeSel_Dec <= '0';     --Asynchronously RESET if single Xfer aborted
      Bus2IP_Addr_sa <= (others => '0');
      Bus_Local_SingleWr <= '0';
      Bus_Local_SingleRd <= '0';
      Bus_Local_BurstWr <= '0';
      Bus_Local_BurstRd <= '0';
   elsif(OPB_SeqAddr = '0' and Bus_Local_BurstRd = '1' and
         Hold_for_1Prd_After_SeqAddr_low = '0') then
      Seq_Addr_Went_Low <= '1';   --Asynchronous flag that Seq_Addr goes low
      Bus2IP_RangeSel_Dec <= '0'; --Must terminate to avoid index address count
      Bus2IP_Addr_sa <= (others => '0');
      Bus_Local_SingleWr <= '0';
      Bus_Local_SingleRd <= '0';
      Bus_Local_BurstWr <= '0';
      Bus_Local_BurstRd <= '1';   --Don't terminate burst read OP-flag
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then       --Synchronous reset
         Seq_Addr_Went_Low <= '0';
         Bus2IP_RangeSel_Dec <= '0';
         Bus2IP_Addr_sa <= (others => '0');
         Bus_Local_SingleWr <= '0';
         Bus_Local_SingleRd <= '0';
         Bus_Local_BurstWr <= '0';
         Bus_Local_BurstRd <= '0';
      elsif(Bus2IP_RangeSel_Dec = '1' and
            (Bus_Local_SingleRd = '1' or Bus_Local_SingleWr = '1')) then
         if(OPB_RNW = '1') then           --Read Xfer
            if(IP2Bus_RdAck_sa = '1') then   --Reset Single Xfer on Ack
               Seq_Addr_Went_Low <= '0';
               Bus2IP_RangeSel_Dec <= '0';
               Bus2IP_Addr_sa <= (others => '0');
               Bus_Local_SingleRd <= '0';
               Bus_Local_SingleWr <= '0';
            end if;
         else
            if(IP2Bus_WrAck_sa = '1' and OPB_RNW = '0') then
               Seq_Addr_Went_Low <= '0';
               Bus2IP_RangeSel_Dec <= '0';   --Reset upon Slave Ack
               Bus2IP_Addr_sa <= (others => '0');
               Bus_Local_SingleRd <= '0';
               Bus_Local_SingleWr <= '0';
            end if;
         end if;
      elsif(Bus_Local_BurstRd = '1' and OPB_SeqAddr = '0') then
         Seq_Addr_Went_Low <= '0';
         Bus2IP_RangeSel_Dec <= '0';      --Synchronously RESET Burst read
         Bus2IP_Addr_sa <= (others => '0');
         Bus_Local_BurstRd <= '0';        --Terminate Burst Read OP-flag
         Bus_Local_BurstWr <= '0';
         Bus_Local_SingleRd <= '0';
         Bus_Local_SingleWr <= '0';
      elsif(Bus_Local_BurstWr = '1' and Sln_XferAck_1Dly = '0') then
         Seq_Addr_Went_Low <= '0';
         Bus2IP_RangeSel_Dec <= '0';      --Synchronously RESET Burst write
         Bus2IP_Addr_sa <= (others => '0');
         Bus_Local_BurstRd <= '0';        --Insure all are reset
         Bus_Local_BurstWr <= '0';        --Reset BurstWr
         Bus_Local_SingleRd <= '0';
         Bus_Local_SingleWr <= '0';
      elsif(Valid_Decode = '1' and Sln_XferAck_int = '0') then
         if(OPB_SeqAddr = '0') then       --Single Xfer
            if(Bus_Local_BurstWr = '0') then     --Insure Burst completes Xfers
               if(Bus2IP_RangeSel_MA = '0') then --Insure Master completes Xfers
                  Seq_Addr_Went_Low <= '0';
                  Bus2IP_RangeSel_Dec <= '1';   --Set for single Xfer
                  Bus2IP_Addr_sa <= OPB_ABus(C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH
                                         to C_OPB_ABUS_WIDTH-1);
                  if(OPB_RNW = '1') then
                     if(Bus_Local_BurstRd = '0') then
                        Bus_Local_SingleRd <= '1';
                        Bus_Local_SingleWr <= '0';
                     else
                        Bus_Local_SingleRd <= '0';
                        Bus_Local_SingleWr <= '0';
                     end if;
                  else
                     Bus_Local_SingleRd <= '0';
                     Bus_Local_SingleWr <= '1';
                  end if;
               end if;
            end if;
         else                             --Burst Xfer
            if(OPB_RNW = '1') then
               Seq_Addr_Went_Low <= '0';
               Bus2IP_RangeSel_Dec <= '1';--Set high immediately on burst Rd
               Bus2IP_Addr_sa <= OPB_ABus(C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH
                                         to C_OPB_ABUS_WIDTH-1);
               Bus_Local_SingleRd <= '0';
               Bus_Local_SingleWr <= '0';
               Bus_Local_BurstRd <= '1';
               Bus_Local_BurstWr <= '0';
            end if;
         end if;
      elsif(Valid_Decode = '1' and Sln_XferAck_int = '1') then
         if(OPB_SeqAddr = '1' and OPB_RNW = '0') then       --Burst Write Xfer
            Seq_Addr_Went_Low <= '0';
            Bus2IP_RangeSel_Dec <= '1';--Set high on XferAck
            if(Bus2IP_RangeSel_Dec = '0') then
               Bus2IP_Addr_sa <= OPB_ABus(C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH
                                         to C_OPB_ABUS_WIDTH-1);
            end if;
            Bus_Local_BurstWr <= '1';
         end if;
      end if;
   end if;
end process OPB_Decode_Range_Select_PROCESS;

Burst_Read_Hold_After_SeqAddr_low_PROCESS: process(Bus_Local_BurstRd, OPB_Clk)
begin
   if(Bus_Local_BurstRd = '0') then
      Hold_for_1Prd_After_SeqAddr_low <= '0';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then                   --Synchronous Reset
         Hold_for_1Prd_After_SeqAddr_low <= '0';
      elsif(Seq_Addr_Went_Low = '1') then
         Hold_for_1Prd_After_SeqAddr_low <= '1'; --Set to negate test in
                                      -- OPB_Decode_Range_Select_PROCESS
      end if;
   end if;
end process Burst_Read_Hold_After_SeqAddr_low_PROCESS;

OPB_Issue_Request_PROCESS: process(Bus2IP_RangeSel_Dec, OPB_Clk)
--Process to register Read and Write Request signal
begin
   if(Bus2IP_RangeSel_Dec = '0') then        --Reset with Bus2IPRangeSel
      Bus2IP_WrReq_sa_Dec <= '0';
      Bus2IP_RdReq_sa_Dec <= '0';
      request_rdy_Dec <= '1';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then                   --Synchronous Reset
         Bus2IP_WrReq_sa_Dec <= '0';
         Bus2IP_RdReq_sa_Dec <= '0';
         request_rdy_Dec <= '1';
      elsif(Bus2IP_RangeSel_Dec = '1') then 
         if(request_rdy_Dec = '1') then
            if(Bus_Local_SingleRd = '1') then
               Bus2IP_RdReq_sa_Dec <= '1';   --Issue Read request
               request_rdy_Dec <= '0';
            elsif(Bus_Local_SingleWr = '1') then
               Bus2IP_WrReq_sa_Dec <= '1';   --Issue Write request
               request_rdy_Dec <= '0';
            elsif(Bus_Local_BurstRd = '1') then
               Bus2IP_RdReq_sa_Dec <= '1';   --Issue Read request
            elsif(Bus_Local_BurstWr = '1') then
               Bus2IP_WrReq_sa_Dec <= '1';   --Issue Write request
            end if;
         else
            Bus2IP_WrReq_sa_Dec <= '0';
            Bus2IP_RdReq_sa_Dec <= '0';
         end if;
      else
         Bus2IP_WrReq_sa_Dec <= '0';
         Bus2IP_RdReq_sa_Dec <= '0';
         request_rdy_Dec <= '1';
      end if;
   end if;
end process OPB_Issue_Request_PROCESS;

OPB_Sln_XferAck_PROCESS: process(Valid_Decode, OPB_Select, Bus_Local_BurstWr,
                                 Bus_Local_BurstRd, OPB_Clk)
--Process to generate Sln_XferAck for OPB transactions
--Sln_XferAck is not generated for local Master operation since
--OPB_XferAck is generated by the remote slave addressed by the Master
begin
   if(Valid_Decode = '0') then
      if(OPB_Select = '0') then 
         Sln_XferAck_int <= '0';       --Always clear when OPB_Select is low
         OPB_SeqAddr_1Dly <= '0';
         IP2Bus_ErrAck_sa_Synchd <= '0';
      elsif(Bus_Local_BurstWr = '0' and Bus_Local_BurstRd = '0') then
         Sln_XferAck_int <= '0';    --Always clear when invalid address and 
         OPB_SeqAddr_1Dly <= '0';   --Reset with invalid address decode and not burst
         IP2Bus_ErrAck_sa_Synchd <= '0';
      end if;
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then         --Reset
         OPB_SeqAddr_1Dly <= '0';
         Sln_XferAck_int <= '0';
         IP2Bus_ErrAck_sa_Synchd <= '0';
      elsif(Bus_Local_SingleRd = '1'and Sln_XferAck_int = '0') then
         if(IP2Bus_RdAck_sa = '1') then     --Set XferAck on RdAck
            Sln_XferAck_int <= '1';
            if(IP2Bus_ErrAck_sa = '1') then
               IP2Bus_ErrAck_sa_Synchd <= '1';
            else
               IP2Bus_ErrAck_sa_Synchd <= '0';
            end if;
         end if;
      elsif(Bus_Local_BurstRd = '1') then
         if(IP2Bus_RdAck_sa = '1') then     --Set XferAck on RdAck
            Sln_XferAck_int <= '1';
            if(IP2Bus_ErrAck_sa = '1') then
               IP2Bus_ErrAck_sa_Synchd <= '1';
            else
               IP2Bus_ErrAck_sa_Synchd <= '0';
            end if;
         else
            Sln_XferAck_int <= '0';
            IP2Bus_ErrAck_sa_Synchd <= '0';
         end if;
      elsif(Bus_Local_SingleWr = '1' and Sln_XferAck_int = '0') then
         if(IP2Bus_WrAck_sa = '1') then     --Set XferAck on WrAck
            Sln_XferAck_int <= '1';
            if(IP2Bus_ErrAck_sa = '1') then
               IP2Bus_ErrAck_sa_Synchd <= '1';
            else
               IP2Bus_ErrAck_sa_Synchd <= '0';
            end if;
         else
            Sln_XferAck_int <= '0';
            IP2Bus_ErrAck_sa_Synchd <= '0';
         end if;
      elsif(Valid_Decode = '1' and OPB_SeqAddr  = '1' and OPB_RNW = '0') then
         OPB_SeqAddr_1Dly <= OPB_SeqAddr;     --Delay SeqAddr to generate XferAck
         Sln_XferAck_int <= OPB_SeqAddr or OPB_SeqAddr_1Dly; --"Fire and Forget"
         if(IP2Bus_ErrAck_sa = '1') then                     --transaction
            IP2Bus_ErrAck_sa_Synchd <= '1';
         else
            IP2Bus_ErrAck_sa_Synchd <= '0';
         end if;
      else
         OPB_SeqAddr_1Dly <= '0';
         Sln_XferAck_int <= '0';
         IP2Bus_ErrAck_sa_Synchd <= '0';
      end if;
   end if;
end process OPB_Sln_XferAck_PROCESS;
 
OPB_Sln_XferAck_Dly_PROCESS: process(OPB_Clk)
--Process to delay Sln_XferAck by one clock period
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then         --Reset
         Sln_XferAck_1Dly <= '0';
      else
         Sln_XferAck_1Dly <= Sln_XferAck_int;  --Update 1Dly on every clock edge
      end if;
   end if;
end process OPB_Sln_XferAck_Dly_PROCESS;

--------------------------------------------------------------------------------
--Master Attachment related processes
MA_Range_Sel_PROCESS: process (MA2SA_Rd, MA_Local_SingleRd, MA_Local_BurstRd,
                              OPB_Clk)
--Process to regiser Bus2IP_RangeSel_MA for Master operation
begin
   if(MA2SA_Rd = '0' and (MA_Local_SingleRd = '1' or MA_Local_BurstRd = '1')) then
                                      --Asynchronously reset Rd-flags when RdRdy low
      Bus2IP_RangeSel_MA <= '0';
      MA_Local_SingleRd <= '0';
      MA_Local_BurstRd <= '0';
      MA_Local_SingleWr <= '0';
      MA_Local_BurstWr <= '0';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then          --Synchronous reset
         Bus2IP_RangeSel_MA <= '0';
         MA_Local_SingleWr <= '0';
         MA_Local_BurstWr <= '0';
         MA_Local_SingleRd <= '0';
         MA_Local_BurstRd <= '0';
      elsif(IP2Bus_RdAck_sa = '1' and
        (Rd_Count = CONV_INTEGER(MA2SA_Num)-1 and Rd_Count_counting = '1')) then
         Bus2IP_RangeSel_MA <= '0';          --Clear RangeSelect when count done
                                             --(i.e. RdRdy goes high)
      elsif(MA_Local_SingleWr = '1' and IP2Bus_WrAck_sa = '1') then
         Bus2IP_RangeSel_MA <= '0';          --Clear Range Select REQUIRES WrAck
         MA_Local_SingleWr <= '0';           --Clear single local write flag
         MA_Local_BurstWr <= '0';            --Clear burst local write flag
      elsif(MA_Local_BurstWr = '1' and MA2SA_Select_1Dly = '0') then
         Bus2IP_RangeSel_MA <= '0';          --Clear Range Select WITHOUT WrAck
         MA_Local_SingleWr <= '0';           --Clear single local write flag
         MA_Local_BurstWr <= '0';            --Clear burst local write flag
      elsif(MA2SA_Select = '1' and MA2SA_Rd = '0') then
                                                --Local Master Read; local Write
         if(MA_Local_SingleWr = '0' and MA_Local_BurstWr = '0') then
                                             --Insure complete Master operation
            if(MA2SA_XferAck = '1') then     --No conflict possible with OPB Xfer
               Bus2IP_RangeSel_MA <= '1';    --Assert Range Select
               if(MA2SA_Num = "0001") then   --Master single local rite
                  MA_Local_SingleWr <= '1';  --Flag single
               else                
                  MA_Local_BurstWr <= '1';   --Flag busrt
               end if;
            end if;
         end if;
      elsif(MA2SA_Rd = '1') then             --Local Master Write; local Read
         if(MA_Local_SingleRd = '0' and MA_Local_BurstRd = '0') then
            if(Valid_Decode = '0') then      --Insure no OPB operation in progress
               Bus2IP_RangeSel_MA <= '1';    --Assert Range Select
               if(MA2SA_Num = "0001") then   --Master single local rite
                  MA_Local_SingleRd <= '1';  --Flag single
               else
                  MA_Local_BurstRd <= '1';   --Flag busrt
               end if;
            end if;
         end if;
      end if;
   end if;
end process MA_Range_Sel_PROCESS;

MA2SA_XferAck_Dly_PROCESS: process (OPB_Clk)
--Process to delay MA2SA_XferAck by 1 clock period
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then    --Synchronous reset
         MA2SA_XferAck_1Dly <= '0';
      elsif(MA2SA_Select = '1' and MA2SA_Rd = '0') then
         MA2SA_XferAck_1Dly <= MA2SA_XferAck;
      else
         MA2SA_XferAck_1Dly <= '0';
      end if;
   end if;
end process MA2SA_XferAck_Dly_PROCESS;

MA_Issue_Request_PROCESS: process (Bus2IP_RangeSel_MA, OPB_Clk)
--Process to register Read and Write Request signal
begin
   if(Bus2IP_RangeSel_MA = '0') then        --Reset with Bus2IPRangeSel
      Bus2IP_WrReq_sa_MA <= '0';
      Bus2IP_RdReq_sa_MA <= '0';
      request_rdy_MA <= '1';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then                   --Synchronous Reset
         Bus2IP_WrReq_sa_MA <= '0';
         Bus2IP_RdReq_sa_MA <= '0';
         request_rdy_MA <= '1';
      elsif(MA_Local_SingleWr = '1' and request_rdy_MA = '1') then
         Bus2IP_WrReq_sa_MA <= '1';
         Bus2IP_RdReq_sa_MA <= '0';
         request_rdy_MA <= '0';
      elsif(MA_Local_BurstWr = '1' and request_rdy_MA = '1') then
         Bus2IP_WrReq_sa_MA <= MA2SA_XferAck_1Dly;
      elsif(MA_Local_SingleRd = '1' and request_rdy_MA = '1') then
         Bus2IP_WrReq_sa_MA <= '0';   --Single Local Read set RdReq
         Bus2IP_RdReq_sa_MA <= '1';
         request_rdy_MA <= '0';
      elsif(MA_Local_SingleRd = '1' and request_rdy_MA = '0') then
         Bus2IP_WrReq_sa_MA <= '0';   --Single Local Read clear RdReq
         Bus2IP_RdReq_sa_MA <= '0';
      elsif(MA_Local_BurstRd = '1' and request_rdy_MA = '1') then
         Bus2IP_WrReq_sa_MA <= '0';
         Bus2IP_RdReq_sa_MA <= '1';   --MA Local Burst Read
         request_rdy_MA <= '0';
      end if;
   end if;
end process MA_Issue_Request_PROCESS;

SA2MA_RdRdy_Strobe_PROCESS: process (OPB_Clk)
--Process to generate SA2MA_RdRdy strobe
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(IP2Bus_RdAck_sa = '1' and
        (Rd_Count = CONV_INTEGER(MA2SA_Num)-1 and Rd_Count_counting = '1')) then
         SA2MA_RdRdy_int <= '1';
      else
         SA2MA_RdRdy_int <= '0';
      end if;
   end if;
end process SA2MA_RdRdy_Strobe_PROCESS;

MA2SA_Select_Delay_PROCESS: process (OPB_Clk)
--Process to delay MA2SA_Select by 1 clock period
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then
         MA2SA_Select_1Dly <= '0';
      else
         MA2SA_Select_1Dly <= MA2SA_Select;
      end if;
   end if;
end process MA2SA_Select_Delay_PROCESS;

Addr_Sel_PROCESS: process(Bus2IP_RangeSel_Dec, Bus_Local_SingleRd, Bus_Local_BurstRd,
                             Bus_Local_BurstRd_Sel_Cntrl, Bus_Local_SingleWr,
                             Bus_Local_BurstWr, Bus_Local_BurstWr_Sel_Cntrl,
                             Bus2IP_RangeSel_MA, MA_Local_SingleRd, MA_Local_BurstRd,
                             MA_Local_BurstRd_Sel_Cntrl, MA_Local_SingleWr,
                             MA_Local_BurstWr, MA_Local_BurstWr_Sel_Cntrl, Reset)
--Process to generate control signal of MUX in IPIF address bus MUX/counter
--  Addr    Configuration
--   00     Slave attachment
--   01     Local
--   10     Counter
--   11     Reserved
begin
   Addr_Sel_int <= 0;   --Slave Attachment Bus selected
   if(Reset = RESET_ACTIVE) then  --Reset
         Addr_Sel_int <= 0;
   elsif(Bus2IP_RangeSel_Dec = '1') then
      if(Bus_Local_SingleRd = '1') then          --Master Single Read
         Addr_Sel_int <= 0;      --Slave Attachment Bus selected
      elsif(Bus_Local_BurstRd = '1') then        --Master Burst Read
         if(Bus_Local_BurstRd_Sel_Cntrl = '0') then
            Addr_Sel_int <= 0;   --Slave Attachment Bus selected
         else
            Addr_Sel_int <= 2;   --Counter selected
         end if;
      elsif(Bus_Local_SingleWr = '1') then       --Master Single Write
         Addr_Sel_int <= 0;      --Slave Attachment Bus selected
      elsif(Bus_Local_BurstWr = '1') then        --Master Burst Write
         if(Bus_Local_BurstWr_Sel_Cntrl = '0') then
            Addr_Sel_int <= 0;      --Slave Attachment Bus selected
         else
            Addr_Sel_int <= 2;      --Counter selected
         end if;
      else
         Addr_Sel_int <= 0;      --Slave Attachment Bus selected
      end if;
   elsif(Bus2IP_RangeSel_MA = '1') then
      if(MA_Local_SingleRd = '1') then          --Master Single Read
         Addr_Sel_int <= 1;      --Local Bus selected
      elsif(MA_Local_BurstRd = '1') then        --Master Burst Read
         if(MA_Local_BurstRd_Sel_Cntrl = '0') then
            Addr_Sel_int <= 1;   --Local Bus selected
         else
            Addr_Sel_int <= 1;   --Counter selected
         end if;
      elsif(MA_Local_SingleWr = '1') then       --Master Single Write
         Addr_Sel_int <= 1;      --Local Bus selected
      elsif(MA_Local_BurstWr = '1') then        --Master Burst Write
         if(MA_Local_BurstWr_Sel_Cntrl = '0') then
            Addr_Sel_int <= 1;   --Local Bus selected
         else
            Addr_Sel_int <= 2;   --Counter selected
         end if;
      else
         Addr_Sel_int <= 1;      --Local Bus selected
      end if;
   end if;
end process Addr_Sel_PROCESS;

Bus_Local_Burst_Sel_Cntrl_PROCESS: process(Bus2IP_RangeSel_Dec, Bus2IP_RangeSel_MA,
                                           OPB_Clk)
--Process to register control signal for burst Xfer Address increment
begin
   if(Bus2IP_RangeSel_Dec = '0' and Bus2IP_RangeSel_MA = '0') then
      Bus_Local_BurstRd_Sel_Cntrl <= '0';
      Bus_Local_BurstWr_Sel_Cntrl <= '0';
      MA_Local_BurstRd_Sel_Cntrl <= '0';
      MA_Local_BurstWr_Sel_Cntrl <= '0';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then    --Synchronous Reset
         Bus_Local_BurstRd_Sel_Cntrl <= '0';
         Bus_Local_BurstWr_Sel_Cntrl <= '0';
         MA_Local_BurstRd_Sel_Cntrl <= '0';
         MA_Local_BurstWr_Sel_Cntrl <= '0';
      elsif(Bus_Local_BurstRd = '1') then 
         if(IP2Bus_RdAck_sa = '1') then
            Bus_Local_BurstRd_Sel_Cntrl <= '1';
         end if;
      elsif(Bus_Local_BurstWr = '1') then 
         if(Bus2IP_WrReq_sa_Dec = '1') then
            Bus_Local_BurstWr_Sel_Cntrl <= '1';
         else
            Bus_Local_BurstWr_Sel_Cntrl <= '0';
         end if;
      elsif(MA_Local_BurstRd = '1') then 
         if(IP2Bus_RdAck_sa = '1') then
            MA_Local_BurstRd_Sel_Cntrl <= '1';
         end if;
      elsif(MA_Local_BurstWr = '1') then 
         if(Bus2IP_WrReq_sa_MA = '1') then
            MA_Local_BurstWr_Sel_Cntrl <= '1';
         end if;
      else
         Bus_Local_BurstRd_Sel_Cntrl <= '0';
         Bus_Local_BurstWr_Sel_Cntrl <= '0';
         MA_Local_BurstRd_Sel_Cntrl <= '0';
         MA_Local_BurstWr_Sel_Cntrl <= '0';
      end if;
   end if;
end process Bus_Local_Burst_Sel_Cntrl_PROCESS;

Addr_Cntr_ClkEn_PROCESS: process(Bus2IP_RangeSel_Dec, Bus2IP_RangeSel_MA, Addr_Sel_int,
                       Bus_Local_BurstRd, MA_Local_BurstRd, IP2Bus_RdAck_sa,
                       Bus_Local_BurstWr, Bus2IP_WrReq_sa_Dec, MA_Local_BurstWr,
                       Bus2IP_WrReq_sa_MA, Bus_Local_SingleRd, MA_Local_SingleRd,
                       Bus_Local_SingleWr, MA_Local_SingleWr)
--Process to enable clock on address MUX/counter module
begin
   if(Bus2IP_RangeSel_Dec = '1' or Bus2IP_RangeSel_MA = '1') then
      if(Addr_Sel_int = 2) then      --Counter
         if(Bus_Local_BurstRd = '1' or MA_Local_BurstRd = '1') then
            Addr_Cntr_ClkEn <= IP2Bus_RdAck_sa; --Update Addr on every clock
         elsif(Bus_Local_BurstWr = '1') then
            Addr_Cntr_ClkEn <= Bus2IP_WrReq_sa_Dec;
         elsif(MA_Local_BurstWr = '1') then
            Addr_Cntr_ClkEn <= Bus2IP_WrReq_sa_MA;
         else
            Addr_Cntr_ClkEn <= '0';
         end if;
      elsif(Bus_Local_SingleRd = '1' or MA_Local_SingleRd = '1' or
            Bus_Local_SingleWr = '1' or MA_Local_SingleWr = '1') then
         Addr_Cntr_ClkEn <= '0';    --Disable counter register when Single OP
      else
         Addr_Cntr_ClkEn <= '1';    --Enable counter register when RangeSel high
      end if;
   else
      Addr_Cntr_ClkEn <= '0';       --Disable counter register when RangeSel low
   end if;
end process Addr_Cntr_ClkEn_PROCESS;

Pre_MnRequest_Flag_PROCESS: process(MA2SA_Rd, OPB_Clk)
--Process to flag when Mn_Request occurs for discrimination with Retry conditions
begin
   if(MA2SA_Rd = '0') then             --Reset with MA2SA_Rd
      Pre_MnRequest_Flag <= '1';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then    --Synchronous Reset
         Pre_MnRequest_Flag <= '1';
      elsif(SA2MA_RdRdy_int = '1') then
         Pre_MnRequest_Flag <= '0';
      end if;
   end if;
end process Pre_MnRequest_Flag_PROCESS;

SA_Sln_Retry_PROCESS: process(Valid_Decode, OPB_Clk)
--Process to issue retry if Master Read operation in progress
begin
   if(Valid_Decode = '0') then         --Reset with Bus2IPRangeSel
      SA_Sln_Retry <= '0';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then    --Synchronous Reset
         SA_Sln_Retry <= '0';
      elsif(MA2SA_Rd = '1'and Valid_Decode = '1') then
         if(Bus2IP_RangeSel_Dec = '1') then   --Don't Retry, OPB Xfer in progress
            SA_Sln_Retry <= '0';
         elsif(Pre_MnRequest_Flag = '1') then  --Retry for both read and write
            SA_Sln_Retry <= '1';
         elsif(OPB_RNW = '1' and MA2SA_Select = '0') then
            SA_Sln_Retry <= '1';               --Retry for only read
         else
            SA_Sln_Retry <= '0';
         end if;
      else
         SA_Sln_Retry <= '0';
      end if;
   end if;
end process SA_Sln_Retry_PROCESS;

Local_Rd_Burst_Cntr_PROCESS: process(MA2SA_Rd, OPB_Clk)
--Process to count to MA2SA_Num
begin
   if(MA2SA_Rd = '0') then             --Reset with Bus2IPRangeSel
      Rd_Count <= 0;
      Rd_Count_counting <= '0';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then    --Synchronous Reset
         Rd_Count <= 0;
         Rd_Count_counting <= '0';
      elsif(MA2SA_Rd = '1' and Bus2IP_RangeSel_MA = '1') then
         Rd_Count_counting <= '1';
         if(IP2Bus_RdAck_sa = '1') then
            Rd_Count <= Rd_Count + 1;
         end if;
      else
         Rd_Count <= 0;
         Rd_Count_counting <= '0';
      end if;
   end if;
end process Local_Rd_Burst_Cntr_PROCESS;

--------------------------------------------------------------------------------
--Read Not Write signal processes
Rd_not_Wr_Signal_PROCESS: process(MA_Local_SingleWr, MA_Local_BurstWr, MA_Local_SingleRd,
                                  Bus2IP_RangeSel_Dec, Bus_Local_SingleWr,
                                  MA_Local_BurstRd, OPB_RNW)
--Process to set Read not Write signal to decode module
begin
   if ((MA_Local_SingleWr = '1' or MA_Local_BurstWr = '1') and
     Bus2IP_RangeSel_Dec = '0') then
      Bus2IP_RNW_sa <= '0';
   elsif ((MA_Local_SingleRd = '1' and Bus2IP_RangeSel_Dec = '0') or
         (MA_Local_BurstRd = '1' and Bus2IP_RangeSel_Dec = '0')) then
      Bus2IP_RNW_sa <= '1';
   else
      Bus2IP_RNW_sa <= OPB_RNW;
   end if;
end process Rd_not_Wr_Signal_PROCESS;

-------------------------------------------------------------------------------
--Data routing processes
-------------------------------------------------------------------------------
--
-- Sln_DBus_Fifo Process sets up the fifo reset and write control signals
-- Sln_DBus_Fifo buffers data for remote burst write transfers
-------------------------------------------------------------------------------

SLN_DBUS_FIFO_PROCESS: process(Valid_Decode, MA2SA_Rd, Bus2IP_RangeSel_MA,
                                IP2Bus_RdAck_sa, MA_Local_BurstRd, MA_Local_SingleRd,
                                MA2SA_Select, BUs_local_BurstRd, sln_dbus_fifo_notmt,
                                Bus_MnGrant, MA2SA_XferAck)
----Process to latch data for Master operations
begin
    if(Valid_Decode = '0' and MA2SA_Rd = '0') then 
        sln_dbus_fifo_rst <= '1';
        sln_dbus_fifo_wr <= '0';
    else 
        sln_dbus_fifo_rst <= '0';
        if(Bus2IP_RangeSel_MA = '1' and IP2Bus_RdAck_sa = '1' and
            (MA_Local_BurstRd = '1' or MA_Local_SingleRd = '1')) then
                sln_dbus_fifo_wr <= '1';
        else
                sln_dbus_fifo_wr <= '0';
        end if;
   end if;

   if(Valid_Decode = '0' and MA2SA_Select = '0' and Bus_Local_BurstRd = '0'
      and MA_Local_SingleRd = '0' and MA_Local_BurstRd = '0') then
      sln_dbus_fifo_rd <= '0';
   else
      if(MA_Local_BurstRd = '1' and sln_dbus_fifo_notmt='1') then  --Master local Burst Read Xfer
         if (Bus_MnGrant = '1' or (MA2SA_Select='1' and MA2SA_XferAck='1')) then  --Mstr lcl Rd Xfer
            sln_dbus_fifo_rd <= '1';
         else
            sln_dbus_fifo_rd <= '0';
         end if;
      else
            sln_dbus_fifo_rd <= '0';
      end if;
   end if;   

end process SLN_DBUS_FIFO_PROCESS;

-- Instantiate the FIFO
SLN_DBUS_FIFO: srl_fifo 
  generic map (
                C_DATA_BITS => 32,
                C_DEPTH     => C_SLN_BUFFER_DEPTH
               )
  port map (
    Clk         => OPB_Clk,
    Reset       => sln_dbus_fifo_rst,      
    FIFO_Write  => sln_dbus_fifo_wr,
    Data_In     => IP2Bus_Data_sa,    
    FIFO_Read   => sln_dbus_fifo_rd,   
    Data_Out    => Sln_Dbus,   
    FIFO_Full   => open,   
    Data_Exists => sln_dbus_fifo_notmt, 
    Addr        => open
    );


Sln_DBus_gtd_Data_PROCESS: process(Valid_Decode, MA2SA_Select, Bus_Local_BurstRd,
                                   MA_Local_SingleRd, MA_Local_BurstRd, OPB_Clk)
--Process to gate Sln_DBus
begin
   if(Valid_Decode = '0' and MA2SA_Select = '0' and Bus_Local_BurstRd = '0'
      and MA_Local_SingleRd = '0' and MA_Local_BurstRd = '0') then
      Sln_DBus_gtd <= (others => '0');
      --sln_dbus_fifo_rd <= '0';
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Bus_Local_SingleRd = '1' or Bus_Local_BurstRd = '1') then  --OPB Read Xfer
         --sln_dbus_fifo_rd <= '0';
         if(IP2Bus_RdAck_sa = '1') then   --Latch data with Ack
            Sln_DBus_gtd <= IP2Bus_Data_sa;
         else
            Sln_DBus_gtd <= (others => '0');
         end if;
      elsif(MA_Local_SingleRd = '1') then
         --sln_dbus_fifo_rd <= '0';
         if(Bus_MnGrant = '1') then  --Mstr lcl Rd Xfer
            Sln_DBus_gtd <= Sln_DBus;
         end if;
      elsif MA_Local_BurstRd = '1' then  --Master local Burst Read Xfer
        -- if(Bus_MnGrant = '1' and Remote_Write_Index = 0) then  --Mstr lcl Rd Xfer
         if(Bus_MnGrant = '1' or (MA2SA_Select='1' and MA2SA_XferAck='1')) then  --Mstr lcl Rd Xfer
            Sln_DBus_gtd <= Sln_DBus;
         --   sln_dbus_fifo_rd <= '1';
         --else
         --   sln_dbus_fifo_rd <= '0';
         end if;
      else
            Sln_DBus_gtd <= (others => '0');
         --   sln_dbus_fifo_rd <= '0';
      end if;
   end if;
end process Sln_DBus_gtd_Data_PROCESS;


Wr_Data_PROCESS: process(Valid_Decode, OPB_DBus_Stored, Bus2IP_RangeSel_MA, OPB_Clk)
--Process to set Bus2IP_Data_sa
begin
   if(Valid_Decode = '0' and OPB_DBus_Stored = '0' and
      Bus2IP_RangeSel_MA = '0') then
      Bus2IP_Data_sa <= (others => '0');
   elsif(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then
         Bus2IP_Data_sa <= (others => '0');
      elsif(Bus_Local_SingleWr = '1') then
         Bus2IP_Data_sa <= OPB_DBus;
      elsif(MA_Local_SingleWr = '1') then
         if(OPB_DBus_Stored = '1') then
            Bus2IP_Data_sa <= OPB_DBus_1Dly;
         end if;
      elsif(OPB_DBus_Stored = '1') then
         Bus2IP_Data_sa <= OPB_DBus_1Dly;
      else
         Bus2IP_Data_sa <= (others => '0');
      end if;
   end if;
end process Wr_Data_PROCESS;

Wr_Data_Dly_PROCESS: process(OPB_Clk)
--Process to delay OPB_DBus by 1 clock period and flag data stored
begin
   if(OPB_Clk'event and OPB_Clk = '1') then
      if(Reset = RESET_ACTIVE) then
         OPB_DBus_1Dly <= (others => '0'); 
         OPB_DBus_Stored <= '0';
      elsif(MA2SA_Select = '1' and MA2SA_XferAck = '1' and MA2SA_Rd = '0') then
            OPB_DBus_1Dly <= OPB_DBus;     --Master Remote read/local write
            OPB_DBus_Stored <= '1';
      elsif((OPB_RNW = '0' and Sln_XferAck_int = '1' and MA2SA_Select = '0') or
             Bus_Local_BurstWr = '1') then --Conditions for OPB Burst
         OPB_DBus_1Dly <= OPB_DBus;
         OPB_DBus_Stored <= '1';
      else
         OPB_DBus_1Dly <= (others => '0'); 
         OPB_DBus_Stored <= '0';
      end if;
   end if;
end process Wr_Data_Dly_PROCESS;

--------------------------------------------------------------------------------
--Burst signal process
Burst_Signal_PROCESS: process(MA_Local_BurstWr, MA_Local_BurstRd, Bus_Local_BurstWr,
                              Bus2IP_RangeSel_Dec, Bus_Local_BurstRd, OPB_SeqAddr)
begin
   if((MA_Local_BurstWr = '1' and Bus2IP_RangeSel_Dec = '0') or
      (MA_Local_BurstRd = '1' and Bus2IP_RangeSel_Dec = '0') or
       Bus_Local_BurstWr = '1') then
      Bus2IP_Burst_sa <= '1';
   elsif(Bus_Local_BurstRd = '1') then
      Bus2IP_Burst_sa <= OPB_SeqAddr;
   else
      Bus2IP_Burst_sa <= '0';
   end if;
end process Burst_Signal_PROCESS;
end generate Full_Function_Slv_Attach;

--*********************************************************************************
Slv_Only_With_Burst_Slv_Attach: if(C_SLN_ONLY and C_SLN_BURST) generate

--Combinatorial operations
Bus2IP_BE_sa        <= opb_be_d1;
Bus2IP_RangeSel     <= Bus2IP_RangeSel_Dec_cmb;
Bus2IP_WrReq_sa     <= Bus2IP_WrReq_sa_Dec;
Bus2IP_RdReq_sa     <= Bus2IP_RdReq_sa_Dec;
Bus2IP_Burst_sa     <= opb_seqaddr_d1 and Valid_Decode;     --need to check this signal
--Bus2IP_Burst_sa     <= ((opb_seqaddr_d1 and not(opb_rnw_d1))
--                        or (opb_seqaddr_d2 and opb_rnw_d1));     --need to check this signal
Bus2IP_RNW_sa       <= opb_rnw_d1;

Bus2IP_Addr_sa      <= opb_abus_d1(C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH to C_OPB_ABUS_WIDTH-1);
Bus2IP_Data_sa      <= opb_dbus_d1;

Sln_ToutSup         <= IP2Bus_ToutSup_sa and Valid_Decode;
Sln_DBus_gtd        <= Sln_DBus_gtd_i;
Sln_Retry           <= sln_retry_i;

--Sln_Retry <= (IP2Bus_Retry_sa and Valid_Decode) or SA_Sln_Retry;
--Sln_ErrAck <= IP2Bus_ErrAck_sa_Synchd and Valid_Decode;
--Sln_XferAck <= Sln_XferAck_int;

Addr_Sel            <= addr_sel_vec;
SA2MA_RdRdy         <= '0';
SA2MA_WrAck         <= '0';

--------------------------------------------------------------------------------
-- Register the OPB Bus signals
--------------------------------------------------------------------------------
SLVONLY_OPB_REGS_PROCESS: process (OPB_Clk)
begin
    if OPB_Clk'event and OPB_Clk='1' then
        if Reset = RESET_ACTIVE  then
            opb_abus_d1 <= (others => '0');
            opb_dbus_d1 <= (others => '0');
            opb_rnw_d1 <= '0';
            opb_select_d1 <= '0';
            opb_be_d1 <= (others => '0');
            opb_seqaddr_d1 <= '0';
        else
            opb_abus_d1 <= OPB_ABus;
            opb_dbus_d1 <= OPB_DBus;
            opb_rnw_d1 <= OPB_RNW;
            opb_select_d1 <= OPB_Select;
            opb_be_d1 <= OPB_BE;
            opb_seqaddr_d1 <= OPB_SeqAddr;
        end if;
    end if;
end process SLVONLY_OPB_REGS_PROCESS;

--------------------------------------------------------------------------------
-- Decode the address
--------------------------------------------------------------------------------
SLONLY_ATTCH_PSELECT_I: pselect
    generic map (C_AB   => C_DEV_ADDR_DECODE_WIDTH,
                 C_AW   => C_OPB_ABUS_WIDTH,
                 C_BAR  => C_SLAVE_ATT_BASE)
    port map (A         => opb_abus_d1,
              AValid    => opb_select_d1,
              CS        => Valid_Decode);
--------------------------------------------------------------------------------
-- Set the burst transaction flag
-- If burst is 0, then set it to opb_seqaddr_d1. Reset it with opb_select_d1.
-- This signal is used in the state machine and is only viewed when there is a
-- valid decode.
--------------------------------------------------------------------------------
BURST_FLAG: process(OPB_Clk)
begin
    if OPB_Clk'event and OPB_Clk = '1' then
        if Reset = RESET_ACTIVE or opb_select_d1 = '0' then
            burst <= '0';
        elsif burst = '0' then
            burst <= OPB_SeqAddr;
        end if;
    end if;
end process BURST_FLAG;

--------------------------------------------------------------------------------
-- Slave Only with Burst State Machine
-- SLVONLY_CTRLSM_CMB:     combinational process for determining next state
-- SLVONLY_CTRLSM_REG:     state machine registers
--------------------------------------------------------------------------------
SLVONLY_BURST_CTRLSM_CMB:
    process (OPB_SeqAddr, opb_rnw_d1, IP2Bus_WrAck_sa, IP2Bus_RdAck_sa,
             Valid_Decode, opb_seqaddr_d1, IP2Bus_Retry_sa, sln_retry_i,
             sob_ctrlsm_cs, addr_sel_vec, burst)
    begin
        Bus2IP_RangeSel_Dec_cmb <= '0';
        Bus2IP_RdReq_sa_Dec_cmb <= '0';
        Bus2IP_WrReq_sa_Dec_cmb <= '0';
        sln_retry_cmb <= sln_retry_i;
        Sln_XferAck_cmb <= '0';
        sln_rst_cmb <= '0';
        addr_sel_vec_cmb <= addr_sel_vec;
        addr_cntr_clken_cmb <= '0'; 
 
        case sob_ctrlsm_cs is
            when IDLE =>
                sob_ctrlsm_ns <= SET_RANGE_SEL;
 
            when SET_RANGE_SEL =>
                -- set select for address mux to 0 for slave attachment
                addr_sel_vec_cmb(C_SL_ATT_ADDR_SEL_WIDTH-2) <= '0';
       
                if Valid_Decode = '1' then
                    Bus2IP_RangeSel_Dec_cmb <= '1';
                    -- since read request is combinational, set in next state
                    -- write request is registered, but only preset if 
                    -- not a burst
                    if (opb_rnw_d1 = '0' and opb_seqaddr_d1 = '0') then
                        Bus2IP_WrReq_sa_Dec_cmb <= '1';
                    end if ;
                    sob_ctrlsm_ns <= SET_REQ;
                else
                    sob_ctrlsm_ns <= SET_RANGE_SEL;
                end if;
 
            when SET_REQ =>
                if Valid_Decode = '1' then
                    Bus2IP_RangeSel_Dec_cmb <= '1';
                end if;
                if (opb_rnw_d1 = '1') then
                    -- read transaction
                    -- since read request is combinational, set in this state
                    Bus2IP_RdReq_sa_Dec_cmb <= '1';
                    -- wait for IP2BUS_RDACK
                    if IP2Bus_RdAck_sa = '1' then
                        Sln_XferAck_cmb <= '1';
                        sob_ctrlsm_ns <= ACK;
                        if opb_seqaddr_d1 = '1' then
                            -- read burst, set address counters
                            Addr_Cntr_ClkEn_cmb <= '1';
                            addr_sel_vec_cmb(C_SL_ATT_ADDR_SEL_WIDTH-2) <= '1';
                        end if ;
                    else
                        sob_ctrlsm_ns <= WAIT_ACK;
                    end if;
                elsif opb_seqaddr_d1 = '1' then
                    -- write burst transaction,
                    -- don't wait for IP2BUS_WRACK
                    Sln_XferAck_cmb <= '1';
                    sob_ctrlsm_ns <= ACK;
                elsif IP2Bus_WrAck_sa = '1' then
                    -- single  write transaction
                    Sln_XferAck_cmb <= '1';
                    sob_ctrlsm_ns <= ACK;
                elsif (IP2Bus_Retry_sa = '1') then
                    Sln_Retry_cmb <= '1';
                    sob_ctrlsm_ns <= RETRY;
                else
                    sob_ctrlsm_ns <= WAIT_ACK;
                end if;
 
            when WAIT_ACK =>
                if Valid_Decode = '1' then
                    Bus2IP_RangeSel_Dec_cmb <= '1';
                end if;
                if burst = '1' then
                    -- only bursts that come to this state are read bursts
                    -- set read request
                        Bus2IP_RdReq_sa_Dec_cmb <= '1';
                end if ;
                
                if (opb_rnw_d1 = '1' and IP2Bus_RdAck_sa = '1') then
                    -- read transaction has completed
                    Sln_XferAck_cmb <= '1';
                    if opb_seqaddr_d1 = '1' then
                       -- read burst, set address counter
                       Addr_Cntr_ClkEn_cmb <= '1';
                       addr_sel_vec_cmb(C_SL_ATT_ADDR_SEL_WIDTH-2) <= '1';
                    end if ;
                    sob_ctrlsm_ns <= ACK;
                elsif (opb_rnw_d1 = '0' and IP2Bus_WrAck_sa = '1') then
                    -- single write transaction has completed
                    Sln_XferAck_cmb <= '1';
                    sob_ctrlsm_ns <= ACK;
                elsif (IP2Bus_Retry_sa = '1') then
                    Sln_Retry_cmb <= '1';
                    sob_ctrlsm_ns <= RETRY;
                else
                    sob_ctrlsm_ns <= WAIT_ACK;
                end if;

            when ACK =>
                if burst = '0' then
                    -- single transaction, terminate transfer
                    sob_ctrlsm_ns <= IDLE;
                    sln_rst_cmb <= '1';
                elsif (opb_rnw_d1 = '1' and OPB_SeqAddr = '0') then
                    -- end of read burst
                    -- reads need to end immediately at end of burst
                    -- so use OPB_SeqAddr
                    sob_ctrlsm_ns <= IDLE;
                    sln_rst_cmb <= '1';                
                    addr_sel_vec_cmb(C_SL_ATT_ADDR_SEL_WIDTH-2) <= '0';
                elsif (opb_rnw_d1 = '0' and opb_seqaddr_d1 = '0') then
                    -- end of write burst
                    -- writes need to end one clock after end of burst
                    -- and need Bus2IP_RangeSel to be set
                    Bus2IP_RangeSel_Dec_cmb <= '1';
                    sob_ctrlsm_ns <= IDLE;
                    sln_rst_cmb <= '1';
                else
                    -- continue burst
                    Bus2IP_RangeSel_Dec_cmb <= '1';
                    if opb_rnw_d1 = '1' then
                        Bus2IP_RdReq_sa_Dec_cmb <= '1';
                        addr_sel_vec_cmb(C_SL_ATT_ADDR_SEL_WIDTH-2) <= '1';
                    else
                        Bus2IP_WrReq_sa_Dec_cmb <= '1';
                    end if ;
                    if (opb_rnw_d1 = '0' or 
                      (opb_rnw_d1 = '1' and IP2Bus_RdAck_sa = '1')) then
                        --write burst or read burst with immediate read ack
                        Sln_XferAck_cmb <= '1';
                        Addr_Cntr_ClkEn_cmb <= '1';
                        sob_ctrlsm_ns <= ACK;
                    else
                        -- read burst without immediate read ack
                        sob_ctrlsm_ns <= WAIT_ACK;
                        sln_rst_cmb <= '1';
                    end if;
                end if;
 
            when RETRY =>
                sob_ctrlsm_ns <= IDLE;
  
            when others =>
 
                sob_ctrlsm_ns <= IDLE;
        end case;
    end process;
 
SLVONLY_BURST_CTRLSM_REG: process (OPB_Clk)
    begin
 
        if (OPB_Clk'event and OPB_Clk = '1') then
            if (Reset = RESET_ACTIVE) then
                sob_ctrlsm_cs <= IDLE;
                Bus2IP_WrReq_sa_Dec <= '0';
                sln_rst <= '1';
                addr_sel_vec <= (others => '0');
            else
                if Valid_Decode = '0' then
                    sob_ctrlsm_cs <= SET_RANGE_SEL;
                else
                    sob_ctrlsm_cs <= sob_ctrlsm_ns;
                end if;
                addr_sel_vec <= addr_sel_vec_cmb;
                Bus2IP_WrReq_sa_Dec <= Bus2IP_WrReq_sa_Dec_cmb;
                sln_rst <= sln_rst_cmb;
            end if;
        end if;
    end process;

Addr_Cntr_Clken <= addr_cntr_clken_cmb;
Bus2IP_RdReq_sa_Dec <= Bus2IP_RdReq_sa_Dec_cmb;
            
SLVONLY_SLN_REG: process (OPB_Clk, OPB_Select)
begin
 
     if (OPB_Select = '0' ) then
        -- asynchronously reset slave signals when OPB_Select negates
            Sln_ErrAck <= '0';
            sln_retry_i <= '0';
            Sln_XferAck <= '0';
     elsif (OPB_Clk'event and OPB_Clk = '1') then
            if (Reset = RESET_ACTIVE) then
                sln_retry_i <= '0';
                Sln_XferAck <= '0';
            else
                sln_retry_i <= Sln_Retry_cmb;
                Sln_XferAck <= Sln_XferAck_cmb;
            end if;
            if (Reset = RESET_ACTIVE or sln_rst_cmb = '1') then
                Sln_ErrAck <= '0';
            elsif (IP2Bus_RdAck_sa = '1' or IP2Bus_WrAck_sa = '1' or
                (opb_seqaddr_d1 = '1' and opb_rnw_d1 = '0')) then
                Sln_ErrAck <= IP2Bus_ErrAck_sa;
            end if;
    end if;
end process SLVONLY_SLN_REG;

SLN_DBUS_REG: process (OPB_Clk)
begin
    if (OPB_Clk'event and OPB_Clk = '1') then
            if (sln_rst_cmb = '1' or Reset = RESET_ACTIVE) then
                Sln_DBus_gtd_i <= (others => '0');
            elsif IP2Bus_RdAck_sa = '1' then
                Sln_DBus_gtd_i <= IP2Bus_Data_sa;
            end if;           
    end if;
end process SLN_DBUS_REG; 

end generate Slv_Only_With_Burst_Slv_Attach;

--*********************************************************************************
Slv_Only_NO_Burst_Slv_Attach: if(C_SLN_ONLY and not(C_SLN_BURST)) generate

begin
--Combinatorial operations
Bus2IP_BE_sa    <= opb_be_d1;
Bus2IP_RangeSel <= Bus2IP_RangeSel_Dec_cmb;
Bus2IP_WrReq_sa <= Bus2IP_WrReq_sa_Dec;
Bus2IP_RdReq_sa <= Bus2IP_RdReq_sa_Dec;
Bus2IP_RNW_sa   <= opb_rnw_d1;

Bus2IP_Addr_sa      <= opb_abus_d1(C_OPB_ABUS_WIDTH-C_IPIF_ABUS_WIDTH to C_OPB_ABUS_WIDTH-1);
Bus2IP_Data_sa      <= opb_dbus_d1;

Bus2IP_Burst_sa <= '0';

SA2MA_RdRdy <= '0';
SA2MA_WrAck <= '0';
Addr_Sel <= (others => '0');
Addr_Sel_int <= 0;
Addr_Cntr_ClkEn <= '0';

Sln_DBus_gtd        <= Sln_DBus_gtd_i;
Sln_Retry           <= sln_retry_i;
Sln_ToutSup         <= IP2Bus_ToutSup_sa and Valid_Decode;


--------------------------------------------------------------------------------
-- Register the OPB Bus signals
--------------------------------------------------------------------------------
SLVONLY_NOBURST_OPB_REGS_PROCESS: process (OPB_Clk)
begin
    if OPB_Clk'event and OPB_Clk='1' then
        if Reset = RESET_ACTIVE  then
            opb_abus_d1 <= (others => '0');
            opb_dbus_d1 <= (others => '0');
            opb_rnw_d1 <= '0';
            opb_select_d1 <= '0';
            opb_be_d1 <= (others => '0');
        else
            opb_abus_d1 <= OPB_ABus;
            opb_dbus_d1 <= OPB_DBus;
            opb_rnw_d1 <= OPB_RNW;
            opb_select_d1 <= OPB_Select;
            opb_be_d1 <= OPB_BE;
        end if;
    end if;
end process SLVONLY_NOBURST_OPB_REGS_PROCESS;

--------------------------------------------------------------------------------
-- Decode the address
--------------------------------------------------------------------------------
SL_ATTCH_PSELECT_I: pselect
    generic map (C_AB   => C_DEV_ADDR_DECODE_WIDTH,
                 C_AW   => C_OPB_ABUS_WIDTH,
                 C_BAR  => C_SLAVE_ATT_BASE)
    port map (A         => opb_abus_d1,
              AValid    => opb_select_d1,
              CS        => Valid_Decode);
              
--------------------------------------------------------------------------------
-- Slave Only, No Burst State Machine
-- SLVONLY_NOBURST_CTRLSM_CMB:     combinational process for determining next state
-- SLVONLY_NOBURST_CTRLSM_REG:     state machine registers
--------------------------------------------------------------------------------
    -- Combinational process
SLVONLY_NOBURST_CTRLSM_CMB: process (Valid_Decode, opb_rnw_d1, IP2Bus_Data_sa,
                                    IP2Bus_RdAck_sa, IP2Bus_WrAck_sa, 
                                    IP2Bus_Retry_sa, sln_retry_i, sonb_ctrlsm_cs)
    begin
    
        -- Set default values
        Bus2IP_RangeSel_Dec_cmb <= '0';
        Bus2IP_RdReq_sa_Dec_cmb <= '0';
        Bus2IP_WrReq_sa_Dec_cmb <= '0';
        sln_retry_cmb <= sln_retry_i;       -- has to stay asserted until OPB_Select negates
        Sln_XferAck_cmb <= '0';
--        Sln_DBus_gtd_cmb <= (others => '0');
        sln_rst_cmb    <= '0';          -- used to reset data bus and errack
        sonb_ctrlsm_ns <= sonb_ctrlsm_cs;
 
        case sonb_ctrlsm_cs is
            when IDLE =>
                sonb_ctrlsm_ns <= SET_RANGE_SEL;
                
            when SET_RANGE_SEL =>
--                sln_rst_cmb <= '1';
                if (Valid_Decode = '1') then
                    sonb_ctrlsm_ns <= SET_REQ;
                    Bus2IP_RangeSel_Dec_cmb <= '1';
                    if (opb_rnw_d1 = '1') then
                        Bus2IP_RdReq_sa_Dec_cmb <= '1';
                    else
                        Bus2IP_WrReq_sa_Dec_cmb <= '1';
                    end if ;
                end if;
  
            when SET_REQ =>
                if (Valid_Decode='0' ) then
                    sonb_ctrlsm_ns <= SET_RANGE_SEL;
                else
                    Bus2IP_RangeSel_Dec_cmb <= '1';
                    if (opb_rnw_d1 = '1' and IP2Bus_RdAck_sa = '1') then
                        sonb_ctrlsm_ns <= ACK;
                        --Sln_DBus_gtd_cmb <= IP2Bus_Data_sa;
                        sln_rst_cmb <= '1';
                        Sln_XferAck_cmb <= '1';
                    elsif (opb_rnw_d1 = '0' and IP2Bus_WrAck_sa = '1') then
                        sonb_ctrlsm_ns <= ACK;
                        Sln_XferAck_cmb <= '1';
                        sln_rst_cmb <= '1';
                    elsif (IP2Bus_Retry_sa = '1') then
                        Sln_Retry_cmb <= '1';
                        sonb_ctrlsm_ns <= ACK;
                    else
                        sonb_ctrlsm_ns <= WAIT_ACK;
                    end if; 
                end if;
  
            when WAIT_ACK =>
                if (Valid_Decode='0') then
                    sonb_ctrlsm_ns <= SET_RANGE_SEL;
                else
                    Bus2IP_RangeSel_Dec_cmb <= '1';
                    if (opb_rnw_d1 = '1' and IP2Bus_RdAck_sa = '1') then
                        sonb_ctrlsm_ns <= ACK;
                        --Sln_DBus_gtd_cmb <= IP2Bus_Data_sa;
                        sln_rst_cmb <= '1';
                       Sln_XferAck_cmb <= '1';
                    elsif (opb_rnw_d1 = '0' and IP2Bus_WrAck_sa = '1') then
                        sonb_ctrlsm_ns <= ACK;
                        Sln_XferAck_cmb <= '1';
                        sln_rst_cmb <= '1';
                    elsif (IP2Bus_Retry_sa = '1') then
                        Sln_Retry_cmb <= '1';
                        sonb_ctrlsm_ns <= ACK;
                    else
                        sonb_ctrlsm_ns <= WAIT_ACK;
                    end if;
                end if;
            when ACK =>
                sonb_ctrlsm_ns <= IDLE; 
            when others => 
                sonb_ctrlsm_ns <= IDLE;
        end case;
    end process;
    
SLVONLY_NOBURST_CTRLSM_REG: process (OPB_Clk)
    begin
 
        if (OPB_Clk'event and OPB_Clk = '1') then
            if (Reset = RESET_ACTIVE) then
                sonb_ctrlsm_cs <= IDLE;
                Bus2IP_RdReq_sa_Dec <= '0';
                Bus2IP_WrReq_sa_Dec <= '0';
                sln_rst <= '1';
            else
                sonb_ctrlsm_cs <= sonb_ctrlsm_ns;
                Bus2IP_RdReq_sa_Dec <= Bus2IP_RdReq_sa_Dec_cmb;
                Bus2IP_WrReq_sa_Dec <= Bus2IP_WrReq_sa_Dec_cmb;
                sln_rst <= sln_rst_cmb;
            end if;
        end if;
    end process SLVONLY_NOBURST_CTRLSM_REG;    

SLVONLY_NOBURST_SLN_REG: process (OPB_Clk, OPB_Select)
begin
 
     if (OPB_Select = '0' ) then
        -- asynchronously reset slave signals when OPB_Select negates
            Sln_ErrAck <= '0';
            sln_retry_i <= '0';
            Sln_XferAck <= '0';
     elsif (OPB_Clk'event and OPB_Clk = '1') then
            if (Reset = RESET_ACTIVE) then
                sln_retry_i <= '0';
                Sln_XferAck <= '0';
            else
                sln_retry_i <= Sln_Retry_cmb;
                Sln_XferAck <= Sln_XferAck_cmb;
            end if;
            if (Reset = RESET_ACTIVE or sln_rst = '1') then
                Sln_ErrAck <= '0';
            elsif (IP2Bus_RdAck_sa = '1' or IP2Bus_WrAck_sa = '1') then
                Sln_ErrAck <= IP2Bus_ErrAck_sa;
            end if;
    end if;
end process SLVONLY_NOBURST_SLN_REG;

SLN_DBUS_REG: process (OPB_Clk)
begin
    if (OPB_Clk'event and OPB_Clk = '1') then
            if (sln_rst = '1') then
                Sln_DBus_gtd_i <= (others => '0');
            elsif IP2Bus_RdAck_sa = '1' then
                Sln_DBus_gtd_i <= IP2Bus_Data_sa;
            end if;           
    end if;
end process SLN_DBUS_REG; 

end generate Slv_Only_NO_Burst_Slv_Attach;


end implementation;
