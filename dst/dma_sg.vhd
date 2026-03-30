library ieee;
use ieee.std_logic_1164.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.dma_sg_pkg.natural_vector;
use opb_ipif_v1_23_a.dma_sg_pkg.boolean_vector;
use opb_ipif_v1_23_a.dma_sg_pkg.RESET_ACTIVE;
use opb_ipif_v1_23_a.dma_sg_pkg.ceil_log2;

entity dma_sg is
-- Four channel version
  generic (
       C_OPB_DBUS_WIDTH : natural := 32;  --  Width of data bus (32, 64).
       C_OPB_ABUS_WIDTH : natural := 32;  --  width of Bus addr.
       C_M : natural :=13;  --  Width of IP/IPIF addr bus - 1.
       C_B : natural := 4;  --  Number of byte enables, (C_N+1) DIV 8.
 
       C_CLOCK_PERIOD_PS : integer := 16000; --ps  -- Period of Bus2IP_Clk_i.
 
       -- The time unit, in nanoseconds, that applies to
       -- the Packet Wait Bound register. The specified value of this
       -- generic is 1,000,000 (1 ms), but a smaller value can be used for
       -- simulations. 
       C_PACKET_WAIT_UNIT_NS : integer := 1000; --ns
 
       C_DMA_CHAN_TYPE         -- 0=simple, 1=sg, 2=tx, 3=rx
        : natural_vector
        :=                    (    2,    3  );
 
       -- The leftmost defined bit of the LENGTH field, assuming
       -- big endian bit numbering and a LSB at bit 31.
       -- If the channel is a packet channel, it is assumed that
       -- the number bits defined in the LENGTH register is also
       -- enough bits to hold the length of a maximum sized packet.
       -- ToDo, current impl requires all channels to be the same length.
       C_LENGTH_LEFT
        : natural_vector
        :=                    (   21,  21  );
 
       C_LEN_FIFO_BAR
        : natural_vector
        :=                    (   (1*1024+512)*4, (2*1024+512)*4 );
 
       C_STAT_FIFO_BAR
        : natural_vector
        :=                    (   (1*1024+513)*4, (2*1024+513)*4 );
 
       C_INTR_COALESCE
        : boolean_vector
        :=                    (  true,  true  );
 
       C_CHAN_BLOCK_ID
        : natural_vector
        :=                    (  0,     0  );
 
       C_DMA_BAR : std_logic_vector
                 := X"00000000";

       C_DMA_ALLOW_BURST : boolean := true
  );
    port (
          DMA2Bus_Data : out std_logic_vector(0 to C_OPB_DBUS_WIDTH-1 );
          DMA2Bus_Addr : out std_logic_vector(0 to C_OPB_ABUS_WIDTH-1 );
          DMA_MstBE : out std_logic_vector(0 to C_B-1);
          DMA_MstWrReq : out std_logic;
          DMA_MstRdReq : out std_logic;
          DMA_MstBurst : out std_logic;
          DMA_MstBusLock : out std_logic;
          DMA2IP_Addr : out std_logic_vector(0 to C_M-1);
          DMA_WrAck : out std_logic;
          DMA_RdAck : out std_logic;
          DMA_Retry : out std_logic;
          DMA_Error : out std_logic;
          DMA_ToutSup : out std_logic;
          Bus2IP_MstWrAck_i : in std_logic;
          Bus2IP_MstRdAck_i : in std_logic;
          Mstr_sel_ma : in std_logic;
          Bus2IP_MstRetry_i : in std_logic;
          Bus2IP_MstError_i : in std_logic;
          Bus2IP_MstTimeOut_i : in std_logic;
          Bus2IP_BE_sa : in std_logic_vector(0 to C_B-1);
          Bus2IP_WrReq_sa : in std_logic;
          Bus2IP_RdReq_sa : in std_logic;
          Bus2IP_Clk_i : in std_logic;
          Bus2IP_Reset_i : in std_logic;
          Bus2IP_Freeze_i : in std_logic;
          Bus2IP_Addr_i : in std_logic_vector(0 to C_M-1);
          Bus2IP_Data_sa : in std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
          Bus2IP_Burst_sa : in std_logic;
          WFIFO2DMA_Vacancy : in std_logic_vector(0 to 9 );
          Bus2IP_MstLastAck_i : in std_logic;
          DMA_RdCE : in std_logic;
          DMA_WrCE : in std_logic;
          IP2DMA_RxStatus_Empty : in std_logic;
          IP2DMA_RxLength_Empty : in std_logic;
          IP2DMA_TxStatus_Empty : in std_logic;
          IP2DMA_TxLength_Full : in std_logic;
          IP2Bus_DMA_Req : in std_logic;
          Bus2IP_DMA_Ack : out std_logic;
          DMA2Intr_Intr  : out std_logic_vector(0 to C_DMA_CHAN_TYPE'length-1)
    );

end dma_sg;
