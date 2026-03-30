library ieee;
use ieee.std_logic_1164.all;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.dma_sg_pkg.natural_vector;
use opb_ipif_v1_23_a.dma_sg_pkg.boolean_vector;

package dma_sg_cmp is

component dma_sg is

-- Four channel version
--    generic (
--         C_OPB_DBUS_WIDTH : natural := 32;  --  Width of data bus (32, 64).
--         C_OPB_ABUS_WIDTH : natural := 32;  --  width of Bus addr.
--         C_M : natural :=13;  --  Width of IP/IPIF addr bus - 1.
--         C_B : natural := 4;  --  Number of byte enables, (C_N+1) DIV 8.
--  
--         C_CLOCK_PERIOD_PS : integer := 16000; --ps  -- Period of Bus2IP_Clk_i.
--  
--         -- The time unit, in nanoseconds, that applies to
--         -- the Packet Wait Bound register. The specified value of this
--         -- generic is 1,000,000 (1 ms), but a smaller value can be used for
--         -- simulations. 
--         C_PACKET_WAIT_UNIT_NS : integer := 1000; --ns
--  
--         C_DMA_CHAN_TYPE         -- 0=simple, 1=sg, 2=tx, 3=rx
--          : natural_vector
--          :=                    (    0,    1,    2,    3  );
--  
--         -- The leftmost defined bit of the LENGTH field, assuming
--         -- big endian bit numbering and a LSB at bit 31.
--         -- If the channel is a packet channel, it is assumed that
--         -- the number bits defined in the LENGTH register is also
--         -- enough bits to hold the length of a maximum sized packet.
--         -- ToDo, current impl requires all channels to be the same length.
--         C_LENGTH_LEFT
--          : natural_vector
--          :=                    (   21,   21,   21,  21  );
--  
--         C_LEN_FIFO_BAR
--          : natural_vector
--          :=                    (    0,     0, (3*1024+512)*4, (4*1024+512)*4 );
--  
--         C_STAT_FIFO_BAR
--          : natural_vector
--          :=                    (    0,     0, (3*1024+513)*4, (4*1024+513)*4 );
--  
--         C_INTR_COALESCE
--          : boolean_vector
--          :=                    (  false,  false,  true,  true  );
--  
--         C_CHAN_BLOCK_ID
--          : natural_vector
--          :=                    (     0,    0,    0,     0  );
--  
--         C_DMA_BAR : std_logic_vector
--                   := X"00000000";
-- 
--         C_DMA_ALLOW_BURST : boolean := true
--    );

-- Two channel version.
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
          DMA2Intr_Intr  : out std_logic_vector(0 to 1)
    );
end component;

component ctrl_reg
    generic(
        C_RESET_VAL: std_logic_vector
    );
    port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        chan_sel  : in  std_logic;
        reg_sel   : in  std_logic;
        wr_ce     : in  std_logic;
        d         : in  std_logic_vector;
        q         : out std_logic_vector
    );
end component;

component SRL_FIFO
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
    Addr        : out std_logic_vector(0 to 3) -- Added Addr as a port
    );
end component;

component ld_arith_reg
    generic (
        ------------------------------------------------------------------------
        -- True if the arithmetic operation is add, false if subtract.
        C_ADD_SUB_NOT : boolean := false;
        ------------------------------------------------------------------------
        -- Width of the register.
        C_REG_WIDTH   : natural := 8;
        ------------------------------------------------------------------------
        -- Reset value. (No default, must be specified in the instantiation.)
        C_RESET_VALUE : std_logic_vector;
        ------------------------------------------------------------------------
        -- Width of the load data.
        C_LD_WIDTH    : natural :=  8;
        ------------------------------------------------------------------------
        -- Offset to left (toward more significant) of the load data.
        C_LD_OFFSET   : natural :=  0;
        ------------------------------------------------------------------------
        -- Width of the arithmetic data.
        C_AD_WIDTH    : natural :=  8;
        ------------------------------------------------------------------------
        -- Offset to left of the arithmetic data.
        C_AD_OFFSET   : natural :=  0
        ------------------------------------------------------------------------
        -- Dependencies: (1) C_LD_WIDTH + C_LD_OFFSET <= C_REG_WIDTH
        --               (2) C_AD_WIDTH + C_AD_OFFSET <= C_REG_WIDTH
        ------------------------------------------------------------------------
    );
    port (
        CK       : in  std_logic;
        RST      : in  std_logic; -- Reset to C_RESET_VALUE. (Overrides OP,LOAD)
        Q        : out std_logic_vector(0 to C_REG_WIDTH-1);
        LD       : in  std_logic_vector(0 to C_LD_WIDTH-1); -- Load data.
        AD       : in  std_logic_vector(0 to C_AD_WIDTH-1); -- Arith data.
        LOAD     : in  std_logic;  -- Enable for the load op, Q <= LD.
        OP       : in  std_logic   -- Enable for the arith op, Q <= Q + AD.
                                   -- (Q <= Q - AD if C_ADD_SUB_NOT = false.)
                                   -- (Overrrides LOAD.)
    );
end component;

end package;
