--ToDo (x = done)
--   x(1) implement the software, per-channel reset.
--   x(2) implement the MIR.
--   x(3) put the right constant in the MIR.
--    (4) Implement the Freeze behavior.
--   x(5) Reverse the ISR bits so that they are on low-order bits.
--   x(6) Implement SGDA and SGEND.
--   x(7) Generate the clear of the bda_written bit when the
--          sgGo=0 condition is interpreted.
--   x(8) Interrupt coalescing, UPC, PCT, PWB and interrupts.
--   x(9) Make SG stop on packet boundaries (including all SR values
--        for started packets being written).
--  x(10) For SG Rx packet, make writing the SR the last activity
--        to complete a packet.
--   (11) Error conditions to detect:
--        (a) SGS=1 but not at end of Tx packet.
--        (b) SGS=1 but not enough buffer space to finish current Rx packet.
--        (c) Underflow or overflow of UPC.
--        (d) Exactly one of SLOCAL, DLOCAL set.
--        (e) Status value becomes available from the IP but there
--            is not a corresponding address saved in the SRAddr FIFO to
--            which to write it.
--  x(12) Implement the PD interrupt.
--   (13) Change pwb_clk so that the first pulse is a period, not
--        a half period, after reset.
--  x(14) num_stages parameterization working with synplify.
--  x(15) Remove the logic that assures that a write to a DMA register is
--        complete before going on after the "LastAck" signal changes to
--        imply this.
--  x(16) Add the SG_BSY status bit to the DMASR at bit 4 and rename
--        BSY (DMASR(0)) to DMA_BSY.
--  x(17) For SG packet tx channels, make DMASR.L a copy of DMACR.L. (Rick
--        Moleres)
--  x(18) Convert PLENGTH to structural.
--  x(19) Convert LENGTH to structural.
--  x(20) Convert SA to structural.
--  x(21) Convert DA to structural.
--   (22) Convert UPC to structural? (appears to be inferring okay)
--   (23) Convert pw_timer to structural?
--   (24) Handle the case where a Bus2IP_MstRetry is the response to
--        a master operation (DMA and SG not yet covered).
--   (25) Handle the case where a Bus2IP_MstError or Bus2IP_MstTimeout
--        is the response to a master operation (SG not yet covered).
--
--ToDo. Conditions regarding SG operation.
--  x (a) Go to the next BD if      not SGS and (SGE or (not first and
--                                                       "pkt style"))
--  x (b) sg_active asserts when    not SGS and SGE    and maintains until
--            (SGS or not SGE)
--        and idle
--        and (not "pkt style" or (not SRAddrFIFO_nonempty and first))
--  x (c) Signal SGEND and SGDA interrupts on change from sg_active to
--        not sg_active.
--
--  x (1) Introduce the is_idle signal for when dma_sm is waiting to start
--        processing the next BD or to start a simple DMA operation.
--  x (2) Consider renaming BSY(i) to dma_active(i) and assigning to BSY(i) on
--        register readout.
--  x (3) See if sg_busy can be eliminated as a separate signal.


library ieee;
use ieee.numeric_std.all;
-- VisualHDL gives compile errors when using the explicitly named
-- use clauses, below.
--use ieee.numeric_std.UNSIGNED;
--use ieee.numeric_std.TO_UNSIGNED;
--use ieee.numeric_std.TO_INTEGER;
--use ieee.numeric_std."=";
--use ieee.numeric_std."+";
--use ieee.numeric_std."-";
--use ieee.numeric_std."<";
--use ieee.numeric_std.RESIZE;

library opb_ipif_v1_23_a;
use opb_ipif_v1_23_a.dma_sg_cmp.all;
use opb_ipif_v1_23_a.dma_sg_pkg.all;

library proc_common_v1_00_a;

architecture sim of dma_sg is

    constant MAJOR_VERSION                : natural := 1;
    constant MINOR_VERSION                : natural := 1;
    constant HW_SW_COMPATIBILITY_REVISION : natural := 0;

    constant LAST_CHAN : natural := C_DMA_CHAN_TYPE'length - 1;
    constant NUM_CHANS : natural := LAST_CHAN+1;
    constant NUM_CHAN_BITS : natural := ceil_log2(NUM_CHANS);
    -- There are NUM_CHANS channels, numbered 0 .. LAST_CHAN.

    constant RPB : natural := 4;    -- Register-pitch bits = the number of bits
                                    -- needed to encode the word addresses
                                    -- of all registers (and reserved register
                                    -- addresses) for a channel. The number
                                    -- of registers and reserved addresses
                                    -- per channel is 2^RPB, so the the
                                    -- word address of a register on one channel
                                    -- is separated from the word address of
                                    -- of the same register on the next higher
                                    -- channel by 2^RPB.

    constant BPST : natural := C_OPB_DBUS_WIDTH / 8;
                                    -- Bytes per single transfer on the bus.
    constant BPST_BITS : natural := ceil_log2(BPST);
                                    -- Number of bits needed to encode 
                                    -- the range 0 to BPST-1.
    constant TPB  : natural := 8;   -- Transfers per burst (burst length).
    constant BPBT : natural := BPST * TPB;
                                    -- Bytes per burst transfer on the bus.

    -- Registers
    type   DMACR_t
             is array (natural range <>) of std_logic_vector(b_SINC to
                                                             b_L_dmacr);
    signal DMACR        : DMACR_t(0 to LAST_CHAN);

    type   UNSIGNED_t
             is array (natural range <>) of UNSIGNED(0 to C_OPB_DBUS_WIDTH-1);
    signal SA           : UNSIGNED_t(0 to LAST_CHAN);

    signal DA           : UNSIGNED_t(0 to LAST_CHAN);

    signal LENGTH       : UNSIGNED_t(0 to LAST_CHAN);

    signal BDA          : UNSIGNED_t(0 to LAST_CHAN);

    type   SWCR_t
             is array (natural range <>) of std_logic_vector(b_SGE to b_SGE);
    signal SWCR         : SWCR_t(0 to LAST_CHAN);

    type   UPC_t
             is array (natural range <>) of UNSIGNED(C_OPB_DBUS_WIDTH-UPCB to
                                                     C_OPB_DBUS_WIDTH-1);
    signal UPC          : UPC_t(0 to LAST_CHAN);

    signal PCT          : UPC_t(0 to LAST_CHAN);

    type   PWB_t
             is array (natural range <>) of UNSIGNED(C_OPB_DBUS_WIDTH-PWBB to
                                                     C_OPB_DBUS_WIDTH-1);
    signal PWB          : PWB_t(0 to LAST_CHAN); -- Packet Wait Bound
    signal pw_timer     : PWB_t(0 to LAST_CHAN); -- Timer used in generating
                                                 -- PWBR interrupt.


    signal PLENGTH      : UNSIGNED_t(0 to LAST_CHAN);

    signal  LENGTH_cco   : UNSIGNED(0 to C_OPB_DBUS_WIDTH-1);
    signal PLENGTH_cco   : UNSIGNED(0 to C_OPB_DBUS_WIDTH-1);


    -- Per-channel reset
    signal reset        : std_logic_vector (0 to LAST_CHAN);
    signal prog_reset   : std_logic_vector (0 to LAST_CHAN);

    -- Enables
    signal chan_num     : natural;  -- The channel addressed by Bus2IP_Addr.
    signal chan_sel     : std_logic_vector (0 to LAST_CHAN);
                                    -- Decode of chan_num to one-hot.
    signal cco          : natural range 0 to LAST_CHAN;
                                    -- The channel currently operating. 
    signal cco_onehot   : std_logic_vector (0 to LAST_CHAN);
                                    -- cco decoded to onehot.

    signal RSTMIR_sel   : std_logic;
    signal DMACR_sel    : std_logic;
    signal SA_sel       : std_logic;
    signal DA_sel       : std_logic;
    signal LENGTH_sel   : std_logic;
    signal dmasr_sel    : std_logic;
    signal BDA_sel      : std_logic;
    signal SWCR_sel     : std_logic;
    signal UPC_sel      : std_logic;
    signal PCT_sel      : std_logic;
    signal PWB_sel      : std_logic;
    signal ISR_sel      : std_logic;
    signal IER_sel      : std_logic;
    signal PLENGTH_sel  : std_logic;
    
  -- Read back register muxing
    signal ver_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal dcr_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal  sa_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal  da_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal lnt_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal dsr_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal bda_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal sge_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal upc_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal pct_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal pwb_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal isr_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal ier_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);
    signal ple_i         : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1);    
  
    

    signal adj : UNSIGNED(0 to 2);   -- Amt to add or subtr when updating
                                     -- LENGTH and PLENGTH.
    signal  LENGTH_ge_2BPST: std_logic; -- Used in calculating adj.
    signal PLENGTH_ge_2BPST: std_logic; -- Used in calculating adj.
    signal  LENGTH_ge_BPBT : std_logic; -- Used for deciding burst transaction.
    signal PLENGTH_ge_BPBT : std_logic; -- Used for deciding burst transaction.

--ToDo. dec_LENGTH, inc_SA and inc_DA can be combined into a common signal.
    signal dec_LENGTH   : std_logic;
    signal inc_SA       : std_logic;
    signal inc_DA       : std_logic;
    signal dec_PLENGTH  : std_logic;
    signal inc_PLENGTH  : std_logic;
    signal clr_PLENGTH  : std_logic;


    --Register bits and bit fields

    signal SINC         : std_logic_vector(0 to LAST_CHAN);
    signal DINC         : std_logic_vector(0 to LAST_CHAN);
    signal SLOCAL       : std_logic_vector(0 to LAST_CHAN);
    signal DLOCAL       : std_logic_vector(0 to LAST_CHAN);
    signal SGS          : std_logic_vector(0 to LAST_CHAN);
    signal L_tx         : std_logic_vector(0 to LAST_CHAN);

    --ToDo. rmv.
--  signal BSY          : std_logic_vector(0 to LAST_CHAN);
    signal dma_active   : std_logic_vector(0 to LAST_CHAN);
    signal DBE          : std_logic_vector(0 to LAST_CHAN);
    signal DBT          : std_logic_vector(0 to LAST_CHAN);
    signal L_rx         : std_logic_vector(0 to LAST_CHAN);
    signal L            : std_logic_vector(0 to LAST_CHAN);

    signal SGE          : std_logic_vector(0 to LAST_CHAN);

    signal DD           : std_logic_vector(0 to LAST_CHAN);
    signal DE           : std_logic_vector(0 to LAST_CHAN);
    signal PD           : std_logic_vector(0 to LAST_CHAN);
    signal SGDA         : std_logic_vector(0 to LAST_CHAN);
    signal SGEND        : std_logic_vector(0 to LAST_CHAN);
    signal PCTR         : std_logic_vector(0 to LAST_CHAN);
    signal PWBR         : std_logic_vector(0 to LAST_CHAN);

    signal EDD          : std_logic_vector(0 to LAST_CHAN);
    signal EDE          : std_logic_vector(0 to LAST_CHAN);
    signal EPD          : std_logic_vector(0 to LAST_CHAN);
    signal ESGDA        : std_logic_vector(0 to LAST_CHAN);
    signal ESGEND       : std_logic_vector(0 to LAST_CHAN);
    signal EPCTR        : std_logic_vector(0 to LAST_CHAN);
    signal EPWBR        : std_logic_vector(0 to LAST_CHAN);


    -- Other signals.
    signal sgGo         : std_logic_vector(0 to LAST_CHAN);
                          -- SG is enabled and not at end.
    signal DMA_WrAck_i  : std_logic;
    signal DMA_RdAck_i  : std_logic;


    -- is_idle: The DMA state machine is waiting to start processing the next
    -- BD or to start a simple DMA operation.
    signal is_idle      : std_logic_vector(0 to LAST_CHAN);

    -- sg_active: SG has been enabled
    -- and started and has not yet reached the point where it is stopped
    -- or disabled and has cleanly finished the work that it started
    -- while active. Cleanly finishing its work includes, for SG packet
    -- Rx and SG packet Tx channels, that all packets that were started
    -- have finished and their status is recorded.
    signal sg_active    : std_logic_vector(0 to LAST_CHAN);
    signal sg_active_d1 : std_logic_vector(0 to LAST_CHAN);
                       
    signal sg_busy      : std_logic_vector(0 to LAST_CHAN);
                          -- sg_busy(j) iff chan j is working on a BD.

    signal dma_completing : std_logic;
    signal dma_starting : std_logic;
    signal set_DBE, set_DBT, set_L_rx : std_logic;

    signal rx, tx : std_logic_vector(0 to LAST_CHAN);
      -- rx(i) iff channel i is for Rx; tx(i) iff channel i is for Tx
    signal dest_is_a_fifo : std_logic; -- The DMA destination for cco is a fifo.

    signal dma_sel   : std_logic;  -- Master transaction is for dma i/o.
    signal sg_sel    : std_logic;  -- Master transaction is for sg BD i/o.
    signal pl_sel    : std_logic;  -- Master transaction is for PLENGTH i/o.
    signal sr_sel    : std_logic;

    signal dma2bus_addr_dma : std_logic_vector(0 to C_OPB_ABUS_WIDTH-1);
    signal dma2ip_addr_dma  : std_logic_vector(0 to C_M-1);
    signal dma_mstwrreq_dma : std_logic;
    signal dma_mstrdreq_dma : std_logic;
    signal dma_mstburst_dma : std_logic;
    signal burst_cond_dma   : std_logic; -- The condition on which the decision
                                         -- to burst is based.

    signal dma2bus_addr_sg  : std_logic_vector(0 to C_OPB_ABUS_WIDTH-1);
    signal dma2ip_addr_sg   : std_logic_vector(0 to C_M-1);
    signal dma_mstwrreq_sg  : std_logic;
    signal dma_mstrdreq_sg  : std_logic;
    signal dma_mstburst_sg  : std_logic;

    signal dma_mstwrreq_sr  : std_logic;
    signal dma_mstburst_sr  : std_logic;

    signal dma_mstwrreq_pl  : std_logic;

    signal first            : std_logic_vector(0 to LAST_CHAN);
                                          -- Channel cco is on its first
                                          -- DMA operation of a packet.
    signal update_first     : std_logic;  -- Update first for the cco.

    signal no_bda_link      : std_logic_vector(0 to LAST_CHAN);
      -- The BDA for the corresponding channel has been written while
      -- not sg_active and an operation under the next sg_active tenure has not
      -- started.

    signal load_length     : std_logic_vector(0 to LAST_CHAN);
    signal load_bda        : std_logic_vector(0 to LAST_CHAN);

    signal wr_SRAddrFIFO   : std_logic_vector(0 to LAST_CHAN);
    signal rd_SRAddrFIFO   : std_logic_vector(0 to LAST_CHAN);
    signal SRAddrFIFO_full : std_logic_vector(0 to LAST_CHAN);
    signal SRAddrFIFO_nonempty : std_logic_vector(0 to LAST_CHAN);
    type   SRAddrFIFO_out_t
             is array (natural range <>) of std_logic_vector(
                                                0 to
                                                C_OPB_ABUS_WIDTH-1
                                            );
    signal SRAddrFIFO_out  : SRAddrFIFO_out_t(0 to LAST_CHAN);


    type   sg_offset_t
             is array (natural range <>) of UNSIGNED(C_OPB_DBUS_WIDTH-RPB to
                                                     C_OPB_DBUS_WIDTH-1);
    signal sg_offset       : sg_offset_t(0 to LAST_CHAN);
    signal reset_sg_offset : std_logic;
    signal inc_sg_offset   : std_logic_vector(0 to LAST_CHAN);

    signal SRAddrFIFO_cco_hasroom : std_logic;

    signal DMA2Intr_Intr_i : std_logic_vector(0 to LAST_CHAN);

    signal pw_enable_pulse : std_logic;
             -- An enable pulse of one Bus2IP_Clk_i period at the frequency
             -- of required PWB update.
    signal pwb_eq_0      : std_logic_vector(0 to LAST_CHAN);
    signal pw_timer_eq_0 : std_logic_vector(0 to LAST_CHAN);
    signal upc_eq_0      : std_logic_vector(0 to LAST_CHAN);
    signal pwb_loaded    : std_logic_vector(0 to LAST_CHAN);

    
    -- Bitwise "or" of an UNSIGNED value.
    function or_UNSIGNED(s: UNSIGNED) return std_logic is
        variable result: std_logic := '0';
    begin
        if s'ascending then
            for i in s'left to s'right loop
                result := result or s(i);
            end loop;
        else
            for i in s'left downto s'right loop
                result := result or s(i);
            end loop;
        end if;
        return result;
    end or_UNSIGNED;

    -- Find the leftmost bit over the LENGTH registers of all channels.
    function min_value(nv: natural_vector) return natural is
        variable result : natural := natural'high;
    begin
        for i in 0 to LAST_CHAN loop
            if nv(i) < result then result := nv(i); end if;
        end loop;
        return result;
    end min_value;

    constant LENGTHS_LEFT : natural := min_value(C_LENGTH_LEFT);

    function zero_vector(n: natural) return UNSIGNED is
        variable result : UNSIGNED(0 to n-1) := (others => '0');
    begin
        return result;
    end zero_vector;


begin

--ToDo, handle byte enable signals (probably return error on non BE=1111)

    -- Assignment of register bits and bit fields

    SINC_GENERATE: for i in 0 to LAST_CHAN generate
        SINC(i) <= DMACR(i)(0);
    end generate;

    DINC_GENERATE: for i in 0 to LAST_CHAN generate
        DINC(i) <= DMACR(i)(1);
    end generate;

    SLOCAL_GENERATE: for i in 0 to LAST_CHAN generate
        SLOCAL(i) <= DMACR(i)(2);
    end generate;

    DLOCAL_GENERATE: for i in 0 to LAST_CHAN generate
        DLOCAL(i) <= DMACR(i)(3);
    end generate;

    SGS_GENERATE: for i in 0 to LAST_CHAN generate
--ToDo. Check that DMACR(i)(4) gets optimized away by synthesis for
--      C_DMA_CHAN_TYPE(i) = 0.
        SGS(i) <= '1' when C_DMA_CHAN_TYPE(i) = 0 else
                  DMACR(i)(4);
    end generate;

    SGE_GENERATE: for i in 0 to LAST_CHAN generate
--ToDo. Check that SWCR(i)(0) gets optimized away by synthesis for
--      C_DMA_CHAN_TYPE(i) = 0.
        SGE(i) <= '0' when C_DMA_CHAN_TYPE(i) = 0 else
                  SWCR(i)(0);
    end generate;

    SGGO_GENERATE: for i in 0 to LAST_CHAN generate
        sgGo(i) <=    (not SGS(i) and SGE(i))
                   or -- If pkt SG, then get to a packet boundary.
                      (    not first(i)
                       and bo2sl(   C_DMA_CHAN_TYPE(i) = 2
                                 or C_DMA_CHAN_TYPE(i) = 3
                                )
                      );
    end generate;

    L_TX_GEN: for i in 0 to LAST_CHAN generate
        L_tx(i) <= '0' when (C_DMA_CHAN_TYPE(i) /= 2) else DMACR(i)(b_L_dmacr);
    end generate;


    --- Address decoding

    -- channel selects
    chan_num <= TO_INTEGER(UNSIGNED(Bus2IP_Addr_i(   C_M-RPB-NUM_CHAN_BITS
                                                  to C_M-RPB-1             )));
    CHAN_SELECTION: process (chan_num)
    begin
      for i in 0 to LAST_CHAN loop
          chan_sel(i) <= bo2sl(chan_num = i);
      end loop;
    end process;


    CCO_ONEHOT_PROCESS: process (cco)
    begin
      for i in 0 to LAST_CHAN loop
          cco_onehot(i) <= bo2sl(cco = i);
      end loop;
    end process;

    RX_GEN: for i in 0 to LAST_CHAN generate
        rx(i) <= bo2sl(C_DMA_CHAN_TYPE(i) = 3) and (sgGo(i) or sg_active(i));
          -- A sg rx packet channel can be used for simple DMA when it is not
          -- operating under SG.
    end generate;

    dest_is_a_fifo <= bo2sl(    C_DMA_CHAN_TYPE(cco) = 2 -- ToDo. Might want to
                            and sg_active(cco) = '1'); -- consider how this info
                                                       -- is gotten. Perhaps it
                                                       -- should be a dmacr bit
                                                       -- or if not, perhaps the
                                                       -- DA should be
                                                       -- read-only. hmmmn.

    TX_GEN: for i in 0 to LAST_CHAN generate
        tx(i) <= bo2sl(C_DMA_CHAN_TYPE(i) = 2) and (sgGo(i) or sg_active(i));
          -- A sg tx packet channel can be used for simple DMA when it is not
          -- operating under SG.
    end generate;

    -- register selects
--ToDo. Eventually remove (or restore) this version. (New version, below.)
--  RSTMIR_sel  <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_RSTMIR);
--  DMACR_sel   <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_DMACR); 
--  SA_sel      <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_SA);
--  DA_sel      <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_DA); 
--  LENGTH_sel  <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_LENGTH); 
--  DMASR_sel   <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_DMASR); 
--  BDA_sel     <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_BDA); 
--  UPC_sel     <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_UPC); 
--  PCT_sel     <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_PCT); 
--  PWB_sel     <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_PWB); 
--  ISR_sel     <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_ISR); 
--  IER_sel     <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_IER); 
--  PLENGTH_sel <= bo2sl(UNSIGNED(Bus2IP_Addr_i(C_M-RPB to C_M-1)) = r_PLENGTH); 
    RSTMIR_sel  <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_RSTMIR, RPB)));
    DMACR_sel   <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_DMACR, RPB))); 
    SA_sel      <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_SA, RPB)));
    DA_sel      <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_DA, RPB))); 
    LENGTH_sel  <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_LENGTH, RPB))); 
    DMASR_sel   <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_DMASR, RPB))); 
    BDA_sel     <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_BDA, RPB))); 
    SWCR_sel    <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_SWCR, RPB))); 
    UPC_sel     <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_UPC, RPB))); 
    PCT_sel     <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_PCT, RPB))); 
    PWB_sel     <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_PWB, RPB))); 
    ISR_sel     <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_ISR, RPB))); 
    IER_sel     <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_IER, RPB))); 
    PLENGTH_sel <= bo2sl(Bus2IP_Addr_i(C_M-RPB to C_M-1) =
                   std_logic_vector(TO_UNSIGNED(r_PLENGTH, RPB))); 

    --= end, Address decoding


    --- Various logic

    ---------------------------------------------------------------------- 
    -- These statements calculate adj.
    -- Either LENGTH or PLENGTH is the evaluated value, depending on whether the
    -- channel is rx. If the evaluated value is >= BPST, adj is BPST, which
    -- means that the low-order two bits may need to be masked. Otherwise,
    -- adj is the two low-order bits of the evaluated value.
    ---------------------------------------------------------------------- 

     LENGTH_ge_BPBT<= or_UNSIGNED( LENGTH_cco(LENGTHS_LEFT to 26));
    PLENGTH_ge_BPBT<= or_UNSIGNED(PLENGTH_cco(LENGTHS_LEFT to 26));

     LENGTH_ge_2BPST <=  LENGTH_ge_BPBT or
                         or_UNSIGNED( LENGTH_cco(26 to C_OPB_DBUS_WIDTH -
                                                       BPST_BITS - 2));
    PLENGTH_ge_2BPST <= PLENGTH_ge_BPBT or
                         or_UNSIGNED(PLENGTH_cco(26 to C_OPB_DBUS_WIDTH -
                                                       BPST_BITS - 2));


    ----------------------------------------------------------------------------
    -- The next process maintains the global adj value with
    -- respect to the cco.
    -- Notes:
    -- (1) Whenever adj is to be used to update channel n, cco=n must hold
    -- for both the previous and current cycles.
    -- (2) adj is sourced from FFs to reduce path time.
    -- (3) When dec_length is true, we are looking ahead by
    -- an extra BPST, which is the reason for the >= 2*BPST check
    -- instead of a >= BPST check.
    -- (4) It is required that BPST be a power of 2.
    ----------------------------------------------------------------------------
    ADJ_PROCESS: process (Bus2IP_Clk_i)
        variable len : UNSIGNED(0 to LENGTH_cco'length-1);
        variable len_ge_2BPST : std_logic;
    begin
      if Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1' then
        if rx(cco)='0' then
            len := LENGTH_cco;
            len_ge_2BPST := LENGTH_ge_2BPST;
        else
            len := PLENGTH_cco;
            len_ge_2BPST := PLENGTH_ge_2BPST;
        end if;
        adj(0) <=    len_ge_2BPST
                  or (not dec_length and len(  C_OPB_DBUS_WIDTH
                                             - BPST_BITS
                                             - 1)
                     );
        for i in 1 to BPST_BITS LOOP
          -- The following expression zeroes non high-order adj bits
          -- when the next transfer will be BPST, otherwise
          -- adj becomes what is left to transfer, i.e. the corresponding
          -- adj bit is taken from the corresponding len bit.
          adj(i) <=     not(   len_ge_2BPST
                            or (not dec_length and len(  C_OPB_DBUS_WIDTH
                                                       - BPST_BITS
                                                       - 1)
                               )
                           )
                    and len(C_OPB_DBUS_WIDTH - BPST_BITS + i - 1);
        end loop;
      end if;
    end process;


    DMA_Error   <= '0';
    DMA_Retry   <= '0';

    Bus2IP_DMA_Ack <= '0';

    DMA_ToutSup <= '0';

    DMA2INTR_GENERATE: for i in 0 to LAST_CHAN generate
        DMA2Intr_Intr_i(i) <=    (DD(i)    and EDD(i))
                              or (DE(i)    and EDE(i))
                              or (PD(i)    and EPD(i))
                              or (PCTR(i)  and EPCTR(i))
                              or (PWBR(i)  and EPWBR(i))
                              or (SGDA(i)  and ESGDA(i))
                              or (SGEND(i) and ESGEND(i));
        DMA2Intr_Intr(i) <= DMA2Intr_Intr_i(i);
    end generate;


    L_GEN: for i in 0 to LAST_CHAN generate
        L(i) <= (   (tx(i) and L_tx(i))
                 or (rx(i) and L_rx(i))
                );
    end generate;

    FIRST_PROCESS: process (Bus2IP_Clk_i) is
    begin
        if Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1' then
            for i in 0 to LAST_CHAN loop
                if reset(i) = '1' then
                    first(i) <= bo2sl(C_DMA_CHAN_TYPE(i) = 2 or
                                      C_DMA_CHAN_TYPE(i) = 3);
                elsif update_first = '1' and cco = i then
                    first(i) <= L(i);
                end if;
            end loop;
        end if;
    end process;

    SG_OFFSET_PROCESS: process (Bus2IP_Clk_i) is
    begin
        if Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1' then
            for i in 0 to LAST_CHAN loop
                if (reset(i) or (reset_sg_offset and cco_onehot(i))) = '1' then
                    sg_offset(i) <= (others => '0');
                elsif inc_sg_offset(i) = '1' then
                    sg_offset(i) <= sg_offset(i) + 1;
                end if;
            end loop;
        end if;
    end process;

    SRAddrFIFO_cco_hasroom <= '1' when     (C_DMA_CHAN_TYPE(cco) = 2 or
                                            C_DMA_CHAN_TYPE(cco) = 3)
                                       and SRAddrFIFO_full(cco) = '0'
                              else '0';

-- ToDo. rmv.
--  BSY_GEN: for i in 0 to LAST_CHAN generate
--      BSY(i) <= dma_active(i);
--  end generate;

    --= end, Various logic


    --- Clock divider.

    CLOCK_DIVIDER: block 
        constant num_stages : natural
                            := Div_Stages(base_period  => C_CLOCK_PERIOD_PS,
                                          target_period=>  C_PACKET_WAIT_UNIT_NS
                                                         * 1000
                                         );
        signal divby2to : std_logic_vector(0 to num_stages);
        signal ripout, ripout_d1, ripout_d2, ripout_d3 : std_logic;
    begin

        divby2to(0) <=  Bus2IP_Clk_i;
        ripout      <=  divby2to(num_stages);
      
        ------------------------------------------------------------------------
        -- Clock division via a ripple counter.
        ------------------------------------------------------------------------
        DIVIDE_CLK: for i in 1 to num_stages generate
           DIV_FF: process(divby2to(i-1), Bus2IP_Reset_i)
           begin
              if Bus2IP_Reset_i = RESET_ACTIVE then
                  divby2to(i) <= '0';
              else
                  if divby2to(i-1)'event and divby2to(i-1) = '1' then
                      divby2to(i) <= not divby2to(i);
                  end if;
              end if; 
           end process; 
        end generate;

        ------------------------------------------------------------------------
        -- This process syncronizes the output of the ripple counter into
        -- the Bus2IP_Clk_i domain and sets up edge detection.
        ------------------------------------------------------------------------
        SYNC_AND_ENABLE: process(Bus2IP_Clk_i, Bus2IP_Reset_i)
        begin
            if Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1' then
                if Bus2IP_Reset_i = RESET_ACTIVE then
                    ripout_d1 <= '0';
                    ripout_d2 <= '0';
                    ripout_d3 <= '0';
                else
                    ripout_d1 <= divby2to(num_stages);
                    ripout_d2 <= ripout_d1;
                    ripout_d3 <= ripout_d2;
                end if;
            end if; 
        end process; 

        ------------------------------------------------------------------------
        -- Edge detection gives a one-pulse signal in the Bus2IP_Clk_i domain.
        ------------------------------------------------------------------------
        pw_enable_pulse <= not ripout_d2 and ripout_d3;

    end block;

    --= end, Clock divider.


    --- Register implementations

    ---------------------------------------------------------------------  
    -- These processes generate the DMA_WrAck.
    ---------------------------------------------------------------------  
    DMA_WrAck_i_PROCESS: process(Bus2IP_Clk_i)
    begin
        if (Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1') then
            if (Bus2IP_Reset_i = RESET_ACTIVE) then
                DMA_WrAck_i <= '0';
--ToDo. The last conjunct probably not needed.
            elsif ((DMA_WrCE and Bus2IP_WrReq_sa)='1' and DMA_WrAck_i='0') then
                DMA_WrAck_i <= '1';
            else
                DMA_WrAck_i <= '0';
            end if;
        end if;
    end process;

    DMA_WrAck <= DMA_WrAck_i;

    ---------------------------------------------------------------------  
    -- These processes implement the channel reset "register".
    ---------------------------------------------------------------------  
    PERP_CHANNEL_RESET_GEN: for i in 0 to LAST_CHAN generate
        prog_reset(i) <=
                    bo2sl(    (chan_sel(i) and RSTMIR_sel and DMA_WrAck_i) = '1'
                          and (Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-4 to
                               C_OPB_DBUS_WIDTH-1)) = "1010"
                         );
        reset(i) <=    bo2sl(Bus2IP_Reset_i = RESET_ACTIVE)
                    or prog_reset(i);

    end generate;


    ---------------------------------------------------------------------  
    -- This process implements a DMACR register for each channel.
    ---------------------------------------------------------------------  
--  DMACR_REG_PROCESS: process (Bus2IP_Clk_i)
--  begin
--    for i in 0 to LAST_CHAN loop
--      if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
--          if (reset(i) = RESET_ACTIVE) then
--              DMACR(i)(0 to 6) <= "1001000"; 
--          elsif (chan_sel(i) and DMACR_sel and DMA_WrAck_i) = '1' then
--              DMACR(i)(0 to 6) <= Bus2IP_Data_sa(0 to 6);
--          end if;
--      end if;
--    end loop;
--  end process;


    DMACR_GENERATE: for i in 0 to LAST_CHAN generate
        I_DMACR: ctrl_reg
--      I_DMACR: entity ctrl_reg(sim)
            generic map ("1001100")
            port map (
               clk      => Bus2IP_Clk_i,
               rst      => reset(i),
               chan_sel => chan_sel(i),
               reg_sel  => DMACR_sel,
               wr_ce    => DMA_WrAck_i,
               d        => Bus2IP_Data_sa(b_SINC to b_L_dmacr),
               q        => DMACR(i)(b_SINC to b_L_dmacr)
            );
    end generate;

    SWCR_GENERATE: for i in 0 to LAST_CHAN generate
        I_SWCR: ctrl_reg
            generic map ("0")
            port map (
               clk      => Bus2IP_Clk_i,
               rst      => reset(i),
               chan_sel => chan_sel(i),
               reg_sel  => SWCR_sel,
               wr_ce    => DMA_WrAck_i,
               d        => Bus2IP_Data_sa(b_SGE to b_SGE),
               q        => SWCR(i)(b_SGE to b_SGE)
            );
    end generate;


--r ---------------------------------------------------------------------  
--r -- This process implements a SA register for each channel.
--r ---------------------------------------------------------------------  
--r SA_REG_PROCESS: process (Bus2IP_Clk_i)
--r begin
--r   for i in 0 to LAST_CHAN loop
--r      if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
--r          if (reset(i) = RESET_ACTIVE) then
--r              SA(i) <= (others => '0'); 
--r          elsif (cco_onehot(i) and SINC(i) and inc_SA) = '1' then
--r              SA(i) <= SA(i) + BPST;
--r          elsif (chan_sel(i) and SA_sel and DMA_WrAck_i) = '1' then
--r              SA(i) <= UNSIGNED(Bus2IP_Data_sa);
--r          end if;
--r      end if;
--r   end loop;
--r end process;

    ---------------------------------------------------------------------   --R
    -- The below implements a SA for each channel. --R
    ---------------------------------------------------------------------   --R
    SA_REG_GEN: for i in 0 to LAST_CHAN generate --R
    --R
        T_GEN:  if C_DMA_CHAN_TYPE(i) = 0  or C_DMA_CHAN_TYPE(i) = 1 or
                   C_DMA_CHAN_TYPE(i) = 2  or C_DMA_CHAN_TYPE(i) = 3
        generate --R
            signal OP, LOAD, RST : std_logic; --R
            signal qslv          : std_logic_vector(SA(i)'range); --R
    --R
        begin --R
    --R
          -------------------------------------------------------------- --R
          -- Compute RST, LOAD and OP. --R
          -------------------------------------------------------------- --R
          RST  <= reset(i); --R
    --R
          LOAD <= (chan_sel(i) and SA_sel and DMA_WrAck_i); --R
    --R
          OP <= (cco_onehot(i) and SINC(i) and inc_SA); --R
    --R
          ------------------------------------------------------------------ --R
          -- A register that can be loaded and added to (or subtracted from, --R
          -- but not both.) The width of the register is open. The value to --R
          -- be loaded or the value to be added (subtracted) may be of lesser --R
          -- width than the register and may be offset from the LSB position. --R
          -- (Undefined positions load or add (subtract) zero.) The register --R
          -- can be reset to a freely selectable value. --R
          ------------------------------------------------------------------ --R
         I_SA : component ld_arith_reg --R
            generic map ( --R
              -------------------------------------------------------------- --R
              -- True if the arithmetic operation is add, false if subtract. --R
              C_ADD_SUB_NOT =>  true, --R
              -------------------------------------------------------------- --R
              -- Width of the register. --R
              C_REG_WIDTH   =>  SA(i)'length, --R
              -------------------------------------------------------------- --R
              -- Reset value. --R
              C_RESET_VALUE => "00000000000000000000000000000000", --R
              -------------------------------------------------------------- --R
              -- Width of the load data. --R
              C_LD_WIDTH    =>  SA(i)'length, --R
              -------------------------------------------------------------- --R
              -- Offset to left (toward more significant) of the load data. --R
              C_LD_OFFSET   =>  0, --R
              -------------------------------------------------------------- --R
              -- Width of the arithmetic data. --R
              C_AD_WIDTH    =>  1, --R
              -------------------------------------------------------------- --R
              -- Offset to left of the arithmetic data. --R
              C_AD_OFFSET   =>  BPST_BITS --R
              -------------------------------------------------------------- --R
            ) --R
            port map ( --R
              CK   => Bus2IP_Clk_i, --R
              RST  => RST, --R
              Q    => qslv(SA(i)'range), --R
              LD   => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH-1), --R
              AD   => "1", --R
              LOAD => LOAD, --R
              OP   => OP --R
            ); --R
             --R
         SA(i)(SA(i)'range) <= --R
             UNSIGNED(qslv(SA(i)'range)); --R
    --R
        end generate; --R
    end generate; --R

--r ---------------------------------------------------------------------  
--r -- This process implements a DA register for each channel.
--r ---------------------------------------------------------------------  
--r DA_REG_PROCESS: process (Bus2IP_Clk_i)
--r begin
--r   for i in 0 to LAST_CHAN loop
--r      if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
--r          if (reset(i) = RESET_ACTIVE) then
--r              DA(i) <= (others => '0'); 
--r          elsif (cco_onehot(i) and DINC(i) and inc_DA) = '1' then
--r              DA(i) <= DA(i) + BPST;
--r          elsif (chan_sel(i) and DA_sel and DMA_WrAck_i) = '1' then
--r              DA(i) <= UNSIGNED(Bus2IP_Data_sa);
--r          end if;
--r      end if;
--r   end loop;
--r end process;

    ---------------------------------------------------------------------   --R
    -- The below implements a DA for each channel. --R
    ---------------------------------------------------------------------   --R
    DA_REG_GEN: for i in 0 to LAST_CHAN generate --R
    --R
        T_GEN:  if C_DMA_CHAN_TYPE(i) = 0  or C_DMA_CHAN_TYPE(i) = 1 or
                   C_DMA_CHAN_TYPE(i) = 2  or C_DMA_CHAN_TYPE(i) = 3
        generate --R
            signal OP, LOAD, RST : std_logic; --R
            signal qslv          : std_logic_vector(DA(i)'range); --R
    --R
        begin --R
    --R
          -------------------------------------------------------------- --R
          -- Compute RST, LOAD and OP. --R
          -------------------------------------------------------------- --R
          RST  <= reset(i); --R
    --R
          LOAD <= (chan_sel(i) and DA_sel and DMA_WrAck_i); --R
    --R
          OP <= (cco_onehot(i) and DINC(i) and inc_DA); --R
    --R
          ------------------------------------------------------------------ --R
          -- A register that can be loaded and added to (or subtracted from, --R
          -- but not both.) The width of the register is open. The value to --R
          -- be loaded or the value to be added (subtracted) may be of lesser --R
          -- width than the register and may be offset from the LSB position. --R
          -- (Undefined positions load or add (subtract) zero.) The register --R
          -- can be reset to a freely selectable value. --R
          ------------------------------------------------------------------ --R
         I_DA : component ld_arith_reg --R
            generic map ( --R
              -------------------------------------------------------------- --R
              -- True if the arithmetic operation is add, false if subtract. --R
              C_ADD_SUB_NOT =>  true, --R
              -------------------------------------------------------------- --R
              -- Width of the register. --R
              C_REG_WIDTH   =>  DA(i)'length, --R
              -------------------------------------------------------------- --R
              -- Reset value. --R
              C_RESET_VALUE => "00000000000000000000000000000000", --R
              -------------------------------------------------------------- --R
              -- Width of the load data. --R
              C_LD_WIDTH    =>  DA(i)'length, --R
              -------------------------------------------------------------- --R
              -- Offset to left (toward more significant) of the load data. --R
              C_LD_OFFSET   =>  0, --R
              -------------------------------------------------------------- --R
              -- Width of the arithmetic data. --R
              C_AD_WIDTH    =>  1, --R
              -------------------------------------------------------------- --R
              -- Offset to left of the arithmetic data. --R
              C_AD_OFFSET   =>  BPST_BITS --R
              -------------------------------------------------------------- --R
            ) --R
            port map ( --R
              CK   => Bus2IP_Clk_i, --R
              RST  => RST, --R
              Q    => qslv(DA(i)'range), --R
              LD   => Bus2IP_Data_sa(0 to C_OPB_DBUS_WIDTH-1), --R
              AD   => "1", --R
              LOAD => LOAD, --R
              OP   => OP --R
            ); --R
             --R
         DA(i)(DA(i)'range) <= --R
             UNSIGNED(qslv(DA(i)'range)); --R
    --R
        end generate; --R
    end generate; --R


    LOAD_LENGTH_GENERATE: for i in 0 to LAST_CHAN generate
        load_length(i) <= chan_sel(i) and LENGTH_sel and DMA_WrAck_i;
    end generate;

    LOAD_BDA_GENERATE: for i in 0 to LAST_CHAN generate
        load_bda(i) <= chan_sel(i) and BDA_sel and DMA_WrAck_i;
    end generate;

--r ---------------------------------------------------------------------  
--r -- This process implements a LENGTH register for each channel.
--r ---------------------------------------------------------------------  
--r LENGTH_REG_PROCESS: process (Bus2IP_Clk_i)
--r begin
--r   for i in 0 to LAST_CHAN loop
--r      if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
--r          if (reset(i) = RESET_ACTIVE) then
--r              LENGTH(i)(C_LENGTH_LEFT(i) to
--r                        C_OPB_DBUS_WIDTH-1) <= (others => '0'); 
--r          elsif (cco_onehot(i) and dec_LENGTH) = '1' then
--r              LENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) <=
--r                LENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) - adj;
--r          elsif load_length(i) = '1' then
--r              LENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) <=
--r                UNSIGNED(Bus2IP_Data_sa(C_LENGTH_LEFT(i) to
--r                                        C_OPB_DBUS_WIDTH-1));
--r          end if;
--r      end if;
--r   end loop;
--r end process;

    ---------------------------------------------------------------------   --R
    -- The below implements a LENGTH register of the correct size for --R
    -- each channel. --R
    ---------------------------------------------------------------------   --R
    LENGTH_REG_GEN: for i in 0 to LAST_CHAN generate --R
    --R
        T_GEN:  if C_DMA_CHAN_TYPE(i) = 0  or C_DMA_CHAN_TYPE(i) = 1 or
                   C_DMA_CHAN_TYPE(i) = 2  or C_DMA_CHAN_TYPE(i) = 3
        generate --R
            signal OP, LOAD, RST : std_logic; --R
            signal qslv          : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1); --R
    --R
        begin --R
    --R
          -------------------------------------------------------------- --R
          -- Compute RST, LOAD and OP. --R
          -------------------------------------------------------------- --R
          RST  <= reset(i) or ((cco_onehot(i) and clr_PLENGTH)); --R
    --R
          LOAD <= (chan_sel(i) and LENGTH_sel and DMA_WrAck_i); --R
    --R
          OP <= (cco_onehot(i) and dec_LENGTH); --R
    --R
          ------------------------------------------------------------------ --R
          -- A register that can be loaded and added to (or subtracted from, --R
          -- but not both.) The width of the register is open. The value to --R
          -- be loaded or the value to be added (subtracted) may be of lesser --R
          -- width than the register and may be offset from the LSB position. --R
          -- (Undefined positions load or add (subtract) zero.) The register --R
          -- can be reset to a freely selectable value. --R
          ------------------------------------------------------------------ --R
         I_LENGTH : component ld_arith_reg --R
            generic map ( --R
              -------------------------------------------------------------- --R
              -- True if the arithmetic operation is add, false if subtract. --R
              C_ADD_SUB_NOT =>  false, --R
              -------------------------------------------------------------- --R
              -- Width of the register. --R
              C_REG_WIDTH   =>  C_OPB_DBUS_WIDTH - C_LENGTH_LEFT(i), --R
              -------------------------------------------------------------- --R
              -- Reset value. --R
              C_RESET_VALUE => "00000000000000000000000000000000", --R
              -------------------------------------------------------------- --R
              -- Width of the load data. --R
              C_LD_WIDTH    =>  C_OPB_DBUS_WIDTH - C_LENGTH_LEFT(i), --R
              -------------------------------------------------------------- --R
              -- Offset to left (toward more significant) of the load data. --R
              C_LD_OFFSET   =>  0, --R
              -------------------------------------------------------------- --R
              -- Width of the arithmetic data. --R
              C_AD_WIDTH    =>  3, --R
              -------------------------------------------------------------- --R
              -- Offset to left of the arithmetic data. --R
              C_AD_OFFSET   =>  0 --R
              -------------------------------------------------------------- --R
            ) --R
            port map ( --R
              CK   => Bus2IP_Clk_i, --R
              RST  => RST, --R
              Q    => qslv(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1), --R
              LD   => Bus2IP_Data_sa(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1), --R
              AD   => std_logic_vector(adj), --R
              LOAD => LOAD, --R
              OP   => OP --R
            ); --R
             --R
         LENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) <= --R
             unsigned(qslv(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1)); --R
    --R
        end generate; --R
    end generate; --R


--r ---------------------------------------------------------------------
--r -- This process implements a PLENGTH register for each
--r -- sg pkt tx or sg pkt rx channel.
--r ---------------------------------------------------------------------
--r PLENGTH_REG_PROCESS: process (Bus2IP_Clk_i)
--r begin
--r   for i in 0 to LAST_CHAN loop
--r      if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
--r          if (reset(i) = RESET_ACTIVE) or
--r             (cco_onehot(i) and clr_PLENGTH) = '1' then
--r              PLENGTH(i)(C_LENGTH_LEFT(i) to
--r                         C_OPB_DBUS_WIDTH-1) <= (others => '0'); 
--r          elsif (cco_onehot(i) and dec_PLENGTH) = '1' then
--r              PLENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) <=
--r                PLENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) - adj;
--r          elsif (cco_onehot(i) and inc_PLENGTH) = '1' then
--r              PLENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) <=
--r                PLENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) + adj;
--r          elsif (chan_sel(i) and PLENGTH_sel and DMA_WrAck_i) = '1' then
--r              PLENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) <=
--r                UNSIGNED(Bus2IP_Data_sa(C_LENGTH_LEFT(i) to
--r                                        C_OPB_DBUS_WIDTH-1));
--r          end if;
--r      end if;
--r   end loop;
--r end process;

    ---------------------------------------------------------------------   --R
    -- The below implements a PLENGTH register of the correct size for --R
    -- each channel that requires one. --R
    ---------------------------------------------------------------------   --R
    PLENGTH_REG_GEN: for i in 0 to LAST_CHAN generate --R
    --R
        T0or1_GEN: if C_DMA_CHAN_TYPE(i) = 0 or C_DMA_CHAN_TYPE(i) = 1 generate --R
            PLENGTH(i) <= (others => '0'); --R
        end generate; --R
    --R
        T2_GEN: if C_DMA_CHAN_TYPE(i) = 2  or C_DMA_CHAN_TYPE(i) = 3 generate --R
            signal OP, LOAD, RST : std_logic; --R
            signal qslv          : std_logic_vector(0 to C_OPB_DBUS_WIDTH-1); --R
    --R
        begin --R
    --R
          -------------------------------------------------------------- --R
          -- Compute RST, LOAD and OP. --R
          -------------------------------------------------------------- --R
          RST  <= reset(i) or ((cco_onehot(i) and clr_PLENGTH)); --R
    --R
          LOAD <= (chan_sel(i) and PLENGTH_sel and DMA_WrAck_i); --R
    --R
          OP_ADD_GEN: if C_DMA_CHAN_TYPE(i) = 2 generate --R
              OP <= (cco_onehot(i) and inc_PLENGTH); --R
          end generate; --R
          OP_SUB_GEN: if C_DMA_CHAN_TYPE(i) = 3 generate --R
              OP <= (cco_onehot(i) and dec_PLENGTH); --R
          end generate; --R
    --R
          ------------------------------------------------------------------ --R
          -- A register that can be loaded and added to (or subtracted from, --R
          -- but not both.) The width of the register is open. The value to --R
          -- be loaded or the value to be added (subtracted) may be of lesser --R
          -- width than the register and may be offset from the LSB position. --R
          -- (Undefined positions load or add (subtract) zero.) The register --R
          -- can be reset to a freely selectable value. --R
          ------------------------------------------------------------------ --R
          I_PLENGTH : component ld_arith_reg --R
            generic map ( --R
              -------------------------------------------------------------- --R
              -- True if the arithmetic operation is add, false if subtract. --R
              C_ADD_SUB_NOT =>  C_DMA_CHAN_TYPE(i) = 2, --R
              -------------------------------------------------------------- --R
              -- Width of the register. --R
              C_REG_WIDTH   =>  C_OPB_DBUS_WIDTH - C_LENGTH_LEFT(i), --R
              -------------------------------------------------------------- --R
              -- Reset value. --R
              C_RESET_VALUE => "00000000000000000000000000000000", --R
              -------------------------------------------------------------- --R
              -- Width of the load data. --R
              C_LD_WIDTH    =>  C_OPB_DBUS_WIDTH - C_LENGTH_LEFT(i), --R
              -------------------------------------------------------------- --R
              -- Offset to left (toward more significant) of the load data. --R
              C_LD_OFFSET   =>  0, --R
              -------------------------------------------------------------- --R
              -- Width of the arithmetic data. --R
              C_AD_WIDTH    =>  3, --R
              -------------------------------------------------------------- --R
              -- Offset to left of the arithmetic data. --R
              C_AD_OFFSET   =>  0 --R
              -------------------------------------------------------------- --R
            ) --R
            port map ( --R
              CK   => Bus2IP_Clk_i, --R
              RST  => RST, --R
              Q    => qslv(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1), --R
              LD   => Bus2IP_Data_sa(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1), --R
              AD   => std_logic_vector(adj), --R
              LOAD => LOAD, --R
              OP   => OP --R
            ); --R
             --R
         PLENGTH(i)(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1) <= --R
             unsigned(qslv(C_LENGTH_LEFT(i) to C_OPB_DBUS_WIDTH-1)); --R
    --R
        end generate; --R
    end generate; --R

    ---------------------------------------------------------------------  
    -- dma_active bit (set when LENGTH loaded, cleared by dma state machine).
    ---------------------------------------------------------------------  
    DMA_ACTIVE_BIT_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             if (reset(i) = RESET_ACTIVE) then
                 dma_active(i) <= '0';
             elsif load_length(i) = '1' then
                 dma_active(i) <= '1';
             elsif dma_completing = '1' and cco = i then
                 dma_active(i) <= '0';
             end if;
         end if;
      end loop;
    end process;

    ---------------------------------------------------------------------  
    -- This process implements a DMASR register for each channel.
    -- (note: DMA_BSY and SG_BSY implemented separately.)
    ---------------------------------------------------------------------  
    DMASR_REG_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
          if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
              if (reset(i) = RESET_ACTIVE) then
                  DBE(i) <= '0';
                  DBT(i) <= '0';
                  L_rx(i)   <= '0';
              elsif cco = i then
                  if dma_starting = '1' then
                      DBE(i) <= '0';
                      DBT(i) <= '0';
                      L_rx(i) <= '0';
                  elsif set_DBE = '1' then
                      DBE(i) <= '1';
                  elsif set_DBT = '1' then
                      DBT(i) <= '1';
                  elsif set_L_rx= '1' then
                      L_rx(i) <= '1';
                  end if;
              end if;
          end if;
      end loop;
    end process;


    ---------------------------------------------------------------------  
    -- This process implements a BDA register for each channel that
    -- supports scatter/gather.
    ---------------------------------------------------------------------  
    BDA_REG_PROCESS: process (Bus2IP_Clk_i)
    begin
      if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
        for i in 0 to LAST_CHAN loop
          if    C_DMA_CHAN_TYPE(i) = 1
             or C_DMA_CHAN_TYPE(i) = 2
             or C_DMA_CHAN_TYPE(i) = 3 then
              if (reset(i) = RESET_ACTIVE) then
                  BDA(i) <= ( others => '0');
                  no_bda_link(i) <= '0';
              elsif load_bda(i) = '1' then
                  BDA(i) <= UNSIGNED(Bus2IP_Data_sa);
                  no_bda_link(i) <= not sg_active(i);
              elsif (cco_onehot(i) and sg_active(i) and not is_idle(i)) = '1' then
                  no_bda_link(i) <= '0';
              end if;
          else
              no_bda_link(i) <= '0';
          end if;
        end loop;
      end if;
    end process;

    ----------------------------------------------------------------------------
    -- The processes below implement the ISR interrupt bits for each channel.
    ----------------------------------------------------------------------------
    DD_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             if (reset(i) = RESET_ACTIVE) then
                 DD(i) <= '0';
             elsif dma_completing = '1' and cco_onehot(i) = '1' then
                 DD(i) <= '1';
             elsif (chan_sel(i) and ISR_sel and DMA_WrAck_i) = '1' then
                 DD(i) <= DD(i) xor Bus2IP_Data_sa(b_DD); -- Tog on wr.
             end if;
         end if;
      end loop;
    end process;

    DE_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             if (reset(i) = RESET_ACTIVE) then
                 DE(i) <= '0';
             elsif (set_DBE or set_DBT) = '1' and cco_onehot(i) = '1' then
                 DE(i) <= '1';
             elsif (chan_sel(i) and ISR_sel and DMA_WrAck_i) = '1' then
                 DE(i) <= DE(i) xor Bus2IP_Data_sa(b_DE); -- Tog on wr.
             end if;
         end if;
      end loop;
    end process;

    PD_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             if (reset(i) = RESET_ACTIVE) then
                 PD(i) <= '0';
             elsif rd_SRAddrFIFO(i) = '1' then
                 PD(i) <= '1';
             elsif (chan_sel(i) and ISR_sel and DMA_WrAck_i) = '1' then
                 PD(i) <= PD(i) xor Bus2IP_Data_sa(b_PD); -- Tog on wr.
             end if;
         end if;
      end loop;
    end process;

    PCTR_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             if (reset(i) = RESET_ACTIVE) then
                 PCTR(i) <= '0';
             elsif (UPC(i) >= PCT(i)) and (PCT(i) /= 0) then
                 PCTR(i) <= '1';
             elsif (chan_sel(i) and ISR_sel and DMA_WrAck_i) = '1' then
                 PCTR(i) <= PCTR(i) xor Bus2IP_Data_sa(b_PCTR); -- Tog on wr.
             end if;
         end if;
      end loop;
    end process;

    PWBR_PROCESS: process (Bus2IP_Clk_i) --r
    begin --r
      for i in 0 to LAST_CHAN loop --r
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then --r
             if (reset(i) = RESET_ACTIVE) then --r
                 PWBR(i) <= '0'; --r
             elsif C_DMA_CHAN_TYPE(i) > 1 and --r
                   C_INTR_COALESCE(i) and --r
                   (pw_timer_eq_0(i)) = '1' then --r
                 PWBR(i) <= '1'; --r
             elsif (chan_sel(i) and ISR_sel and DMA_WrAck_i) = '1' then --r
                 PWBR(i) <= PWBR(i) xor Bus2IP_Data_sa(b_PWBR); -- Tog on wr. --r
             end if; --r
         end if; --r
      end loop; --r
    end process; --r


--R PWBR_GEN:  for i in 0 to LAST_CHAN generate
--R
--R     ABSENT_GEN: if C_DMA_CHAN_TYPE(i) = 0 or c_DMA_CHAN_TYPE(i) = 1 or
--R                     not C_INTR_COALESCE(i) generate
--R       PWBR(i) <= '0';
--R     end generate;
--R
--R     PRESENT_GEN: if (C_DMA_CHAN_TYPE(i) = 2 or c_DMA_CHAN_TYPE(i) = 3) and
--R                     C_INTR_COALESCE(i) generate
--R       PWBR_PROCESS: process (Bus2IP_Clk_i)
--R       begin
--R         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
--R           if (reset(i) = RESET_ACTIVE) then
--R               PWBR(i) <= '0';
--R           elsif (pw_timer_eq_0(i)) = '1' then
--R               PWBR(i) <= '1';
--R           elsif (chan_sel(i) and ISR_sel and DMA_WrAck_i) = '1' then
--R               PWBR(i) <= PWBR(i) xor Bus2IP_Data_sa(b_PWBR); -- Tog on wr.
--R           end if;
--R         end if;
--R       end process;
--R     end generate;
--R
--R end generate;

    SGDA_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             if (reset(i) = RESET_ACTIVE) then
                 SGDA(i) <= '0';
             elsif (not sg_active(i) and sg_active_d1(i) and not SGE(i)) = '1'
                 then
                 SGDA(i) <= '1';
             elsif (chan_sel(i) and ISR_sel and DMA_WrAck_i) = '1' then
                 SGDA(i) <= SGDA(i) xor Bus2IP_Data_sa(b_SGDA); -- Tog on wr.
             end if;
         end if;
      end loop;
    end process;

    SGDEND_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             if (reset(i) = RESET_ACTIVE) then
                 SGEND(i) <= '0';
             elsif (not sg_active(i) and sg_active_d1(i) and SGS(i)) = '1' then
                 SGEND(i) <= '1';
             elsif (chan_sel(i) and ISR_sel and DMA_WrAck_i) = '1' then
                 SGEND(i) <= SGEND(i) xor Bus2IP_Data_sa(b_SGEND); -- Tog on wr.
             end if;
         end if;
      end loop;
    end process;


    ----------------------------------------------------------------------------
    -- This process implements the IER for each channel.
    ----------------------------------------------------------------------------
    IER_REG_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             if (reset(i) = RESET_ACTIVE) then
                 EDD(i) <= '0';
                 EDE(i) <= '0';
                 EPD(i) <= '0';
                 EPCTR(i) <= '0';
                 EPWBR(i) <= '0';
                 ESGDA(i) <= '0';
                 ESGEND(i) <= '0';
             elsif (chan_sel(i) and IER_sel and DMA_WrAck_i) = '1' then
                 EDD(i)    <= Bus2IP_Data_sa(b_DD);
                 EDE(i)    <= Bus2IP_Data_sa(b_DE);
                 EPD(i)    <= Bus2IP_Data_sa(b_PD);
                 EPCTR(i)  <= Bus2IP_Data_sa(b_PCTR);
                 EPWBR(i)  <= Bus2IP_Data_sa(b_PWBR);
                 ESGDA(i)  <= Bus2IP_Data_sa(b_SGDA);
                 ESGEND(i)  <= Bus2IP_Data_sa(b_SGEND);
             end if;
         end if;
      end loop;
    end process;

    ----------------------------------------------------------------------------
    -- This process implements the UPC register for each channel.
    ----------------------------------------------------------------------------
    UPC_REG_PROCESS: process (Bus2IP_Clk_i)
        variable add1 : UNSIGNED(C_OPB_DBUS_WIDTH-UPCB to C_OPB_DBUS_WIDTH-1);
        variable sub1 : natural;
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             add1 := (others => rd_SRAddrFIFO(i));
             if (chan_sel(i) and UPC_sel and DMA_WrAck_i and
                 Bus2IP_Data_sa(C_OPB_DBUS_WIDTH-1)) = '1' then
                  sub1 := 1;
             else sub1 := 0;
             end if;
             if (reset(i) = RESET_ACTIVE) then
                 UPC(i) <= (others => '0');
             else
                 UPC(i) <= (UPC(i) - add1) - sub1;
                   -- This will increment if rd_SRAddrFIFO(i), decrement if
                   -- writing a one in LSB, stay unchanged if both or neither.
             end if;
         end if;
      end loop;
    end process;

    ----------------------------------------------------------------------------
    -- This process implements the PCT register for each channel.
    ----------------------------------------------------------------------------
    PCT_REG_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             if (reset(i) = RESET_ACTIVE) then
                 PCT(i) <= (others => '0');
             elsif (chan_sel(i) and PCT_sel and DMA_WrAck_i) = '1' then
                 PCT(i) <= UNSIGNED(Bus2IP_Data_sa(C_OPB_DBUS_WIDTH - UPCB to
                                                   C_OPB_DBUS_WIDTH - 1)
                                   );
             end if;
         end if;
      end loop;
    end process;

    ----------------------------------------------------------------------------
    -- This process implements the PWB register for each channel.
    ----------------------------------------------------------------------------
    PWB_REG_PROCESS: process (Bus2IP_Clk_i)
    begin
      for i in 0 to LAST_CHAN loop
         if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
             pwb_loaded(i) <= '0';
             if (reset(i) = RESET_ACTIVE) then
                 PWB(i) <= (others => '0');
             elsif (chan_sel(i) and PWB_sel and DMA_WrAck_i) = '1' then
                 PWB(i) <= UNSIGNED(Bus2IP_Data_sa(C_OPB_DBUS_WIDTH - PWBB to
                                                   C_OPB_DBUS_WIDTH - 1)
                                   );
                 pwb_loaded(i) <= '1';
             end if;
         end if;
      end loop;
    end process;

    PWB_EQ_0_GEN: for i in 0 to LAST_CHAN generate
        pwb_eq_0(i) <= not or_UNSIGNED(PWB(i));
        pw_timer_eq_0(i) <= not or_UNSIGNED(pw_timer(i));
        upc_eq_0(i) <= not or_UNSIGNED(UPC(i));
    end generate;

--r ----------------------------------------------------------------------------
--r -- This process implements the Packet Wait timer for each channel.
--r ----------------------------------------------------------------------------
--r PW_TIMER_REG_PROCESS: process (Bus2IP_Clk_i)
--r begin
--r   for i in 0 to LAST_CHAN loop
--r      if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
--r          if    (reset(i) = RESET_ACTIVE)
--r                                -- Reset timer if resetting the channel.
--r             or pwb_eq_0(i) = '1'
--r                                -- Reset timer if pw mechanism disabled.
--r          then
--r              pw_timer(i) <= (others => '1'); -- Reset to the maximum value
--r                                              -- disabling PWBR.
--r          elsif
--r                upc_eq_0(i) = '1'
--r                                -- Init timer if no userviced packets.
--r             or DMA2Intr_Intr_i(i) = '1'
--r                                -- Init timer if some interrupt
--r                                -- makes any unserviced packets visible.
--r             or pw_timer_eq_0(i) = '1'
--r                                -- Init timer if it reaches terminal count.
--r             or pwb_loaded(i) = '1'
--r                                -- Init timer if PWB just loaded.
--r          then
--r              pw_timer(i) <= PWB(i);
--r          elsif pw_enable_pulse = '1' then
--r              pw_timer(i) <= pw_timer(i) - 1;
--r          end if;
--r      end if;
--r   end loop;
--r end process;

    ---------------------------------------------------------------------   --R
    -- The below implements a pw_timer register of each channel --R
    -- that requires one. --R
    ---------------------------------------------------------------------   --R
    PW_TIMER_REG_GEN: for i in 0 to LAST_CHAN generate --R
    --R
        T0or1_GEN: if C_DMA_CHAN_TYPE(i) = 0 or C_DMA_CHAN_TYPE(i) = 1 generate --R
            pw_timer(i) <= (others => '0'); --R
        end generate; --R
    --R
        T2or3_GEN: if C_DMA_CHAN_TYPE(i) = 2  or C_DMA_CHAN_TYPE(i) = 3 generate --R
            signal OP, LOAD, RST : std_logic; --R
            signal qslv          : std_logic_vector(pw_timer(i)'range); --R
    --R
        begin --R
    --R
          -------------------------------------------------------------- --R
          -- Compute RST, LOAD and OP. --R
          -------------------------------------------------------------- --R
          RST  <= reset(i) or pwb_eq_0(i); --R
          LOAD <= upc_eq_0(i) or DMA2Intr_Intr_i(i) or pw_timer_eq_0(i) or pwb_loaded(i); --R
          OP <= pw_enable_pulse; --R
          ------------------------------------------------------------------ --R
          -- A register that can be loaded and added to (or subtracted from, --R
          -- but not both.) The width of the register is open. The value to --R
          -- be loaded or the value to be added (subtracted) may be of lesser --R
          -- width than the register and may be offset from the LSB position. --R
          -- (Undefined positions load or add (subtract) zero.) The register --R
          -- can be reset to a freely selectable value. --R
          ------------------------------------------------------------------ --R
         i_pw_timer : component ld_arith_reg --R
            generic map ( --R
              -------------------------------------------------------------- --R
              -- True if the arithmetic operation is add, false if subtract. --R
              C_ADD_SUB_NOT =>  false, --R
              -------------------------------------------------------------- --R
              -- Width of the register. --R
              C_REG_WIDTH   =>  pw_timer(i)'length, --R
              -------------------------------------------------------------- --R
              -- Reset value. --R
              C_RESET_VALUE => "11111111111111111111111111111111", --R
              -------------------------------------------------------------- --R
              -- Width of the load data. --R
              C_LD_WIDTH    =>  pw_timer(i)'length, --R
              -------------------------------------------------------------- --R
              -- Offset to left (toward more significant) of the load data. --R
              C_LD_OFFSET   =>  0, --R
              -------------------------------------------------------------- --R
              -- Width of the arithmetic data. --R
              C_AD_WIDTH    =>  1, --R
              -------------------------------------------------------------- --R
              -- Offset to left of the arithmetic data. --R
              C_AD_OFFSET   =>  0 --R
              -------------------------------------------------------------- --R
            ) --R
            port map ( --R
              CK   => Bus2IP_Clk_i, --R
              RST  => RST, --R
              Q    => qslv(pw_timer(i)'range), --R
              LD   => std_logic_vector(PWB(i)), --R
              AD   => "1", --R
              LOAD => LOAD, --R
              OP   => OP --R
            ); --R
             --R
         pw_timer(i) <= unsigned(qslv(pw_timer(i)'range)); --R
    --R
        end generate; --R
    end generate; --R


    --= end, Register implementations

    --- Some register values selected by cco.

       LENGTH_cco <= zero_vector(C_LENGTH_LEFT(cco)) &
                     LENGTH(cco)(C_LENGTH_LEFT(cco) to C_OPB_DBUS_WIDTH-1);

      PLENGTH_cco <= zero_vector(C_LENGTH_LEFT(cco)) &
                    PLENGTH(cco)(C_LENGTH_LEFT(cco) to C_OPB_DBUS_WIDTH-1);


    --= end, Some register values selected by cco.


    --- Register readback

    ---------------------------------------------------------------------  
    -- This process enables the selected register onto DMA2Bus_Data
    -- on slave reads.
    -- ToDo, this may generate extra "priority encode" logic, so
    -- check this and adjust the implementation, if necessary.
    ---------------------------------------------------------------------  
READ_REGISTER_PROCESS:process (Bus2IP_Clk_i)
begin
   if Bus2IP_Clk_i'event and Bus2IP_Clk_i='1' then
               DMA2Bus_Data(0) <= 
                     (ver_i(0) and DMA_RdCE and RSTMIR_sel) or
                     (dcr_i(0) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(0) and DMA_RdCE and SA_sel) or
                     ( da_i(0) and DMA_RdCE and DA_sel) or
                     (lnt_i(0) and DMA_RdCE and LENGTH_sel) or
                     (dsr_i(0) and DMA_RdCE and DMASR_sel) or
                     (bda_i(0) and DMA_RdCE and BDA_sel) or
                     (sge_i(0) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(0) and DMA_RdCE and UPC_sel) or
--                     (pct_i(0) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(0) and DMA_RdCE and PWB_sel) or
--                     (isr_i(0) and DMA_RdCE and ISR_sel) or
--                     (ier_i(0) and DMA_RdCE and IER_sel) or
                     (ple_i(0) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(1) <= 
                     (ver_i(1) and DMA_RdCE and RSTMIR_sel) or
                     (dcr_i(1) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(1) and DMA_RdCE and SA_sel) or
                     ( da_i(1) and DMA_RdCE and DA_sel) or
                     (lnt_i(1) and DMA_RdCE and LENGTH_sel) or
                     (dsr_i(1) and DMA_RdCE and DMASR_sel) or
                     (bda_i(1) and DMA_RdCE and BDA_sel) or
--                     (sge_i(1) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(1) and DMA_RdCE and UPC_sel) or
--                     (pct_i(1) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(1) and DMA_RdCE and PWB_sel) or
--                     (isr_i(1) and DMA_RdCE and ISR_sel) or
--                     (ier_i(1) and DMA_RdCE and IER_sel) or
                     (ple_i(1) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(2) <= 
                     (ver_i(2) and DMA_RdCE and RSTMIR_sel) or
                     (dcr_i(2) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(2) and DMA_RdCE and SA_sel) or
                     ( da_i(2) and DMA_RdCE and DA_sel) or
                     (lnt_i(2) and DMA_RdCE and LENGTH_sel) or
                     (dsr_i(2) and DMA_RdCE and DMASR_sel) or
                     (bda_i(2) and DMA_RdCE and BDA_sel) or
--                     (sge_i(2) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(2) and DMA_RdCE and UPC_sel) or
--                     (pct_i(2) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(2) and DMA_RdCE and PWB_sel) or
--                     (isr_i(2) and DMA_RdCE and ISR_sel) or
--                     (ier_i(2) and DMA_RdCE and IER_sel) or
                     (ple_i(2) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(3) <= 
                     (ver_i(3) and DMA_RdCE and RSTMIR_sel) or
                     (dcr_i(3) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(3) and DMA_RdCE and SA_sel) or
                     ( da_i(3) and DMA_RdCE and DA_sel) or
                     (lnt_i(3) and DMA_RdCE and LENGTH_sel) or
                     (dsr_i(3) and DMA_RdCE and DMASR_sel) or
                       (bda_i(3) and DMA_RdCE and BDA_sel) or
--                     (sge_i(3) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(3) and DMA_RdCE and UPC_sel) or
--                     (pct_i(3) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(3) and DMA_RdCE and PWB_sel) or
--                     (isr_i(3) and DMA_RdCE and ISR_sel) or
--                     (ier_i(3) and DMA_RdCE and IER_sel) or
                     (ple_i(3) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(4) <= 
                     (ver_i(4) and DMA_RdCE and RSTMIR_sel) or
                     (dcr_i(4) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(4) and DMA_RdCE and SA_sel) or
                     ( da_i(4) and DMA_RdCE and DA_sel) or
                     (lnt_i(4) and DMA_RdCE and LENGTH_sel) or
                       (dsr_i(4) and DMA_RdCE and DMASR_sel) or
                       (bda_i(4) and DMA_RdCE and BDA_sel) or
--                     (sge_i(4) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(4) and DMA_RdCE and UPC_sel) or
--                     (pct_i(4) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(4) and DMA_RdCE and PWB_sel) or
--                     (isr_i(4) and DMA_RdCE and ISR_sel) or
--                     (ier_i(4) and DMA_RdCE and IER_sel) or
                     (ple_i(4) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(5) <= 
                     (ver_i(5) and DMA_RdCE and RSTMIR_sel) or
                     (dcr_i(5) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(5) and DMA_RdCE and SA_sel) or
                     ( da_i(5) and DMA_RdCE and DA_sel) or
                     (lnt_i(5) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(5) and DMA_RdCE and DMASR_sel) or
                       (bda_i(5) and DMA_RdCE and BDA_sel) or
--                     (sge_i(5) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(5) and DMA_RdCE and UPC_sel) or
--                     (pct_i(5) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(5) and DMA_RdCE and PWB_sel) or
--                     (isr_i(5) and DMA_RdCE and ISR_sel) or
--                     (ier_i(5) and DMA_RdCE and IER_sel) or
                     (ple_i(5) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(6) <= 
                     (ver_i(6) and DMA_RdCE and RSTMIR_sel) or
                     (dcr_i(6) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(6) and DMA_RdCE and SA_sel) or
                     ( da_i(6) and DMA_RdCE and DA_sel) or
                     (lnt_i(6) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(6) and DMA_RdCE and DMASR_sel) or
                       (bda_i(6) and DMA_RdCE and BDA_sel) or
--                     (sge_i(6) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(6) and DMA_RdCE and UPC_sel) or
--                     (pct_i(6) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(6) and DMA_RdCE and PWB_sel) or
--                     (isr_i(6) and DMA_RdCE and ISR_sel) or
--                     (ier_i(6) and DMA_RdCE and IER_sel) or
                     (ple_i(6) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(7) <= 
                     (ver_i(7) and DMA_RdCE and RSTMIR_sel) or
                     (dcr_i(7) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(7) and DMA_RdCE and SA_sel) or
                       ( da_i(7) and DMA_RdCE and DA_sel) or
                       (lnt_i(7) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(7) and DMA_RdCE and DMASR_sel) or
                       (bda_i(7) and DMA_RdCE and BDA_sel) or
--                     (sge_i(7) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(7) and DMA_RdCE and UPC_sel) or
--                     (pct_i(7) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(7) and DMA_RdCE and PWB_sel) or
--                     (isr_i(7) and DMA_RdCE and ISR_sel) or
--                     (ier_i(7) and DMA_RdCE and IER_sel) or
                     (ple_i(7) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(8) <= 
                     (ver_i(8) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(8) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(8) and DMA_RdCE and SA_sel) or
                       ( da_i(8) and DMA_RdCE and DA_sel) or
                       (lnt_i(8) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(8) and DMA_RdCE and DMASR_sel) or
                       (bda_i(8) and DMA_RdCE and BDA_sel) or
--                     (sge_i(8) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(8) and DMA_RdCE and UPC_sel) or
--                     (pct_i(8) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(8) and DMA_RdCE and PWB_sel) or
--                     (isr_i(8) and DMA_RdCE and ISR_sel) or
--                     (ier_i(8) and DMA_RdCE and IER_sel) or
                     (ple_i(8) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(9) <= 
                     (ver_i(9) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(9) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(9) and DMA_RdCE and SA_sel) or
                       ( da_i(9) and DMA_RdCE and DA_sel) or
                       (lnt_i(9) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(9) and DMA_RdCE and DMASR_sel) or
                       (bda_i(9) and DMA_RdCE and BDA_sel) or
--                     (sge_i(9) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(9) and DMA_RdCE and UPC_sel) or
--                     (pct_i(9) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(9) and DMA_RdCE and PWB_sel) or
--                     (isr_i(9) and DMA_RdCE and ISR_sel) or
--                     (ier_i(9) and DMA_RdCE and IER_sel) or
                     (ple_i(9) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(10) <= 
                     (ver_i(10) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(10) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(10) and DMA_RdCE and SA_sel) or
                       ( da_i(10) and DMA_RdCE and DA_sel) or
                       (lnt_i(10) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(10) and DMA_RdCE and DMASR_sel) or
                       (bda_i(10) and DMA_RdCE and BDA_sel) or
--                     (sge_i(10) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(10) and DMA_RdCE and UPC_sel) or
--                     (pct_i(10) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(10) and DMA_RdCE and PWB_sel) or
--                     (isr_i(10) and DMA_RdCE and ISR_sel) or
--                     (ier_i(10) and DMA_RdCE and IER_sel) or
                     (ple_i(10) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(11) <= 
                     (ver_i(11) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(11) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(11) and DMA_RdCE and SA_sel) or
                       ( da_i(11) and DMA_RdCE and DA_sel) or
                       (lnt_i(11) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(11) and DMA_RdCE and DMASR_sel) or
                       (bda_i(11) and DMA_RdCE and BDA_sel) or
--                     (sge_i(11) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(11) and DMA_RdCE and UPC_sel) or
--                     (pct_i(11) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(11) and DMA_RdCE and PWB_sel) or
--                     (isr_i(11) and DMA_RdCE and ISR_sel) or
--                     (ier_i(11) and DMA_RdCE and IER_sel) or
                     (ple_i(11) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(12) <= 
                     (ver_i(12) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(12) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(12) and DMA_RdCE and SA_sel) or
                       ( da_i(12) and DMA_RdCE and DA_sel) or
                       (lnt_i(12) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(12) and DMA_RdCE and DMASR_sel) or
                       (bda_i(12) and DMA_RdCE and BDA_sel) or
--                     (sge_i(12) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(12) and DMA_RdCE and UPC_sel) or
--                     (pct_i(12) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(12) and DMA_RdCE and PWB_sel) or
--                     (isr_i(12) and DMA_RdCE and ISR_sel) or
--                     (ier_i(12) and DMA_RdCE and IER_sel) or
                     (ple_i(12) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(13) <= 
                     (ver_i(13) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(13) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(13) and DMA_RdCE and SA_sel) or
                       ( da_i(13) and DMA_RdCE and DA_sel) or
                       (lnt_i(13) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(13) and DMA_RdCE and DMASR_sel) or
                       (bda_i(13) and DMA_RdCE and BDA_sel) or
--                     (sge_i(13) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(13) and DMA_RdCE and UPC_sel) or
--                     (pct_i(13) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(13) and DMA_RdCE and PWB_sel) or
--                     (isr_i(13) and DMA_RdCE and ISR_sel) or
--                     (ier_i(13) and DMA_RdCE and IER_sel) or
                     (ple_i(13) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(14) <= 
                     (ver_i(14) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(14) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(14) and DMA_RdCE and SA_sel) or
                       ( da_i(14) and DMA_RdCE and DA_sel) or
                       (lnt_i(14) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(14) and DMA_RdCE and DMASR_sel) or
                       (bda_i(14) and DMA_RdCE and BDA_sel) or
--                     (sge_i(14) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(14) and DMA_RdCE and UPC_sel) or
--                     (pct_i(14) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(14) and DMA_RdCE and PWB_sel) or
--                     (isr_i(14) and DMA_RdCE and ISR_sel) or
--                     (ier_i(14) and DMA_RdCE and IER_sel) or
                     (ple_i(14) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(15) <= 
                     (ver_i(15) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(15) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(15) and DMA_RdCE and SA_sel) or
                       ( da_i(15) and DMA_RdCE and DA_sel) or
                       (lnt_i(15) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(15) and DMA_RdCE and DMASR_sel) or
                       (bda_i(15) and DMA_RdCE and BDA_sel) or
--                     (sge_i(15) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(15) and DMA_RdCE and UPC_sel) or
--                     (pct_i(15) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(15) and DMA_RdCE and PWB_sel) or
--                     (isr_i(15) and DMA_RdCE and ISR_sel) or
--                     (ier_i(15) and DMA_RdCE and IER_sel) or
                     (ple_i(15) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(16) <= 
                     (ver_i(16) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(16) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(16) and DMA_RdCE and SA_sel) or
                       ( da_i(16) and DMA_RdCE and DA_sel) or
                       (lnt_i(16) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(16) and DMA_RdCE and DMASR_sel) or
                       (bda_i(16) and DMA_RdCE and BDA_sel) or
--                     (sge_i(16) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(16) and DMA_RdCE and UPC_sel) or
--                     (pct_i(16) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(16) and DMA_RdCE and PWB_sel) or
--                     (isr_i(16) and DMA_RdCE and ISR_sel) or
--                     (ier_i(16) and DMA_RdCE and IER_sel) or
                     (ple_i(16) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(17) <= 
                     (ver_i(17) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(17) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(17) and DMA_RdCE and SA_sel) or
                       ( da_i(17) and DMA_RdCE and DA_sel) or
                       (lnt_i(17) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(17) and DMA_RdCE and DMASR_sel) or
                       (bda_i(17) and DMA_RdCE and BDA_sel) or
--                     (sge_i(17) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(17) and DMA_RdCE and UPC_sel) or
--                     (pct_i(17) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(17) and DMA_RdCE and PWB_sel) or
--                     (isr_i(17) and DMA_RdCE and ISR_sel) or
--                     (ier_i(17) and DMA_RdCE and IER_sel) or
                     (ple_i(17) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(18) <= 
                     (ver_i(18) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(18) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(18) and DMA_RdCE and SA_sel) or
                       ( da_i(18) and DMA_RdCE and DA_sel) or
                       (lnt_i(18) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(18) and DMA_RdCE and DMASR_sel) or
                       (bda_i(18) and DMA_RdCE and BDA_sel) or
--                     (sge_i(18) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(18) and DMA_RdCE and UPC_sel) or
--                     (pct_i(18) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(18) and DMA_RdCE and PWB_sel) or
--                     (isr_i(18) and DMA_RdCE and ISR_sel) or
--                     (ier_i(18) and DMA_RdCE and IER_sel) or
                     (ple_i(18) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(19) <= 
                     (ver_i(19) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(19) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(19) and DMA_RdCE and SA_sel) or
                       ( da_i(19) and DMA_RdCE and DA_sel) or
                       (lnt_i(19) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(19) and DMA_RdCE and DMASR_sel) or
                       (bda_i(19) and DMA_RdCE and BDA_sel) or
--                     (sge_i(19) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(19) and DMA_RdCE and UPC_sel) or
--                     (pct_i(19) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(19) and DMA_RdCE and PWB_sel) or
--                     (isr_i(19) and DMA_RdCE and ISR_sel) or
--                     (ier_i(19) and DMA_RdCE and IER_sel) or
                     (ple_i(19) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(20) <= 
                     (ver_i(20) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(20) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(20) and DMA_RdCE and SA_sel) or
                       ( da_i(20) and DMA_RdCE and DA_sel) or
                       (lnt_i(20) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(20) and DMA_RdCE and DMASR_sel) or
                       (bda_i(20) and DMA_RdCE and BDA_sel) or
--                     (sge_i(20) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(20) and DMA_RdCE and UPC_sel) or
--                     (pct_i(20) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(20) and DMA_RdCE and PWB_sel) or
--                     (isr_i(20) and DMA_RdCE and ISR_sel) or
--                     (ier_i(20) and DMA_RdCE and IER_sel) or
                     (ple_i(20) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(21) <= 
                     (ver_i(21) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(21) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(21) and DMA_RdCE and SA_sel) or
                       ( da_i(21) and DMA_RdCE and DA_sel) or
                       (lnt_i(21) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(21) and DMA_RdCE and DMASR_sel) or
                       (bda_i(21) and DMA_RdCE and BDA_sel) or
--                     (sge_i(21) and DMA_RdCE and SWCR_sel) or
--                     (upc_i(21) and DMA_RdCE and UPC_sel) or
--                     (pct_i(21) and DMA_RdCE and PCT_sel) or
--                     (pwb_i(21) and DMA_RdCE and PWB_sel) or
--                     (isr_i(21) and DMA_RdCE and ISR_sel) or
--                     (ier_i(21) and DMA_RdCE and IER_sel) or
                     (ple_i(21) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(22) <= 
                     (ver_i(22) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(22) and DMA_RdCE and DMACR_sel) or
                       ( sa_i(22) and DMA_RdCE and SA_sel) or
                       ( da_i(22) and DMA_RdCE and DA_sel) or
                       (lnt_i(22) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(22) and DMA_RdCE and DMASR_sel) or
                       (bda_i(22) and DMA_RdCE and BDA_sel) or
--                     (sge_i(22) and DMA_RdCE and SWCR_sel) or
                     (upc_i(22) and DMA_RdCE and UPC_sel) or
                     (pct_i(22) and DMA_RdCE and PCT_sel) or
                     (pwb_i(22) and DMA_RdCE and PWB_sel) or
--                     (isr_i(22) and DMA_RdCE and ISR_sel) or
--                     (ier_i(22) and DMA_RdCE and IER_sel) or
                     (ple_i(22) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(23) <= 
                     (ver_i(23) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(23) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(23) and DMA_RdCE and SA_sel) or
                     ( da_i(23) and DMA_RdCE and DA_sel) or
                     (lnt_i(23) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(23) and DMA_RdCE and DMASR_sel) or
                     (bda_i(23) and DMA_RdCE and BDA_sel) or
--                     (sge_i(23) and DMA_RdCE and SWCR_sel) or
                     (upc_i(23) and DMA_RdCE and UPC_sel) or
                     (pct_i(23) and DMA_RdCE and PCT_sel) or
                     (pwb_i(23) and DMA_RdCE and PWB_sel) or
--                     (isr_i(23) and DMA_RdCE and ISR_sel) or
--                     (ier_i(23) and DMA_RdCE and IER_sel) or
                     (ple_i(23) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(24) <= 
                     (ver_i(24) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(24) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(24) and DMA_RdCE and SA_sel) or
                     ( da_i(24) and DMA_RdCE and DA_sel) or
                     (lnt_i(24) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(24) and DMA_RdCE and DMASR_sel) or
                     (bda_i(24) and DMA_RdCE and BDA_sel) or
--                     (sge_i(24) and DMA_RdCE and SWCR_sel) or
                     (upc_i(24) and DMA_RdCE and UPC_sel) or
                     (pct_i(24) and DMA_RdCE and PCT_sel) or
                     (pwb_i(24) and DMA_RdCE and PWB_sel) or
                     (isr_i(24) and DMA_RdCE and ISR_sel) or
                     (ier_i(24) and DMA_RdCE and IER_sel) or
                     (ple_i(24) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(25) <= 
                     (ver_i(25) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(25) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(25) and DMA_RdCE and SA_sel) or
                     ( da_i(25) and DMA_RdCE and DA_sel) or
                     (lnt_i(25) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(25) and DMA_RdCE and DMASR_sel) or
                     (bda_i(25) and DMA_RdCE and BDA_sel) or
--                     (sge_i(25) and DMA_RdCE and SWCR_sel) or
                     (upc_i(25) and DMA_RdCE and UPC_sel) or
                     (pct_i(25) and DMA_RdCE and PCT_sel) or
                     (pwb_i(25) and DMA_RdCE and PWB_sel) or
                     (isr_i(25) and DMA_RdCE and ISR_sel) or
                     (ier_i(25) and DMA_RdCE and IER_sel) or
                     (ple_i(25) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(26) <= 
                     (ver_i(26) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(26) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(26) and DMA_RdCE and SA_sel) or
                     ( da_i(26) and DMA_RdCE and DA_sel) or
                     (lnt_i(26) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(26) and DMA_RdCE and DMASR_sel) or
                     (bda_i(26) and DMA_RdCE and BDA_sel) or
--                     (sge_i(26) and DMA_RdCE and SWCR_sel) or
                     (upc_i(26) and DMA_RdCE and UPC_sel) or
                     (pct_i(26) and DMA_RdCE and PCT_sel) or
                     (pwb_i(26) and DMA_RdCE and PWB_sel) or
                     (isr_i(26) and DMA_RdCE and ISR_sel) or
                     (ier_i(26) and DMA_RdCE and IER_sel) or
                     (ple_i(26) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(27) <= 
                     (ver_i(27) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(27) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(27) and DMA_RdCE and SA_sel) or
                     ( da_i(27) and DMA_RdCE and DA_sel) or
                     (lnt_i(27) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(27) and DMA_RdCE and DMASR_sel) or
                     (bda_i(27) and DMA_RdCE and BDA_sel) or
--                     (sge_i(27) and DMA_RdCE and SWCR_sel) or
                     (upc_i(27) and DMA_RdCE and UPC_sel) or
                     (pct_i(27) and DMA_RdCE and PCT_sel) or
                     (pwb_i(27) and DMA_RdCE and PWB_sel) or
                     (isr_i(27) and DMA_RdCE and ISR_sel) or
                     (ier_i(27) and DMA_RdCE and IER_sel) or
                     (ple_i(27) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(28) <= 
                     (ver_i(28) and DMA_RdCE and RSTMIR_sel) or
--                     (dcr_i(28) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(28) and DMA_RdCE and SA_sel) or
                     ( da_i(28) and DMA_RdCE and DA_sel) or
                     (lnt_i(28) and DMA_RdCE and LENGTH_sel) or
--                     (dsr_i(28) and DMA_RdCE and DMASR_sel) or
                     (bda_i(28) and DMA_RdCE and BDA_sel) or
--                     (sge_i(28) and DMA_RdCE and SWCR_sel) or
                     (upc_i(28) and DMA_RdCE and UPC_sel) or
                     (pct_i(28) and DMA_RdCE and PCT_sel) or
                     (pwb_i(28) and DMA_RdCE and PWB_sel) or
                     (isr_i(28) and DMA_RdCE and ISR_sel) or
                     (ier_i(28) and DMA_RdCE and IER_sel) or
                     (ple_i(28) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(29) <= 
                     (ver_i(29) and DMA_RdCE and RSTMIR_sel) or
 --                    (dcr_i(29) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(29) and DMA_RdCE and SA_sel) or
                     ( da_i(29) and DMA_RdCE and DA_sel) or
                     (lnt_i(29) and DMA_RdCE and LENGTH_sel) or
 --                    (dsr_i(29) and DMA_RdCE and DMASR_sel) or
                     (bda_i(29) and DMA_RdCE and BDA_sel) or
 --                    (sge_i(29) and DMA_RdCE and SWCR_sel) or
                     (upc_i(29) and DMA_RdCE and UPC_sel) or
                     (pct_i(29) and DMA_RdCE and PCT_sel) or
                     (pwb_i(29) and DMA_RdCE and PWB_sel) or
                     (isr_i(29) and DMA_RdCE and ISR_sel) or
                     (ier_i(29) and DMA_RdCE and IER_sel) or
                     (ple_i(29) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(30) <= 
                     (ver_i(30) and DMA_RdCE and RSTMIR_sel) or
 --                    (dcr_i(30) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(30) and DMA_RdCE and SA_sel) or
                     ( da_i(30) and DMA_RdCE and DA_sel) or
                     (lnt_i(30) and DMA_RdCE and LENGTH_sel) or
 --                    (dsr_i(30) and DMA_RdCE and DMASR_sel) or
                     (bda_i(30) and DMA_RdCE and BDA_sel) or
 --                    (sge_i(30) and DMA_RdCE and SWCR_sel) or
                     (upc_i(30) and DMA_RdCE and UPC_sel) or
                     (pct_i(30) and DMA_RdCE and PCT_sel) or
                     (pwb_i(30) and DMA_RdCE and PWB_sel) or
                     (isr_i(30) and DMA_RdCE and ISR_sel) or
                     (ier_i(30) and DMA_RdCE and IER_sel) or
                     (ple_i(30) and DMA_RdCE and PLENGTH_sel);

               DMA2Bus_Data(31) <= 
                     (ver_i(31) and DMA_RdCE and RSTMIR_sel) or
 --                    (dcr_i(31) and DMA_RdCE and DMACR_sel) or
                     ( sa_i(31) and DMA_RdCE and SA_sel) or
                     ( da_i(31) and DMA_RdCE and DA_sel) or
                     (lnt_i(31) and DMA_RdCE and LENGTH_sel) or
 --                    (dsr_i(31) and DMA_RdCE and DMASR_sel) or
                     (bda_i(31) and DMA_RdCE and BDA_sel) or
 --                    (sge_i(31) and DMA_RdCE and SWCR_sel) or
                     (upc_i(31) and DMA_RdCE and UPC_sel) or
                     (pct_i(31) and DMA_RdCE and PCT_sel) or
                     (pwb_i(31) and DMA_RdCE and PWB_sel) or
                     (isr_i(31) and DMA_RdCE and ISR_sel) or
                     (ier_i(31) and DMA_RdCE and IER_sel) or
                     (ple_i(31) and DMA_RdCE and PLENGTH_sel);

   end if;
end process;




      -- Module Identification Register 0 - 31 used
ver_i <= std_logic_vector(TO_UNSIGNED(MAJOR_VERSION , 4)) &
         std_logic_vector(TO_UNSIGNED(MINOR_VERSION , 7)) &
         std_logic_vector(TO_UNSIGNED(HW_SW_COMPATIBILITY_REVISION, 5)) &
         std_logic_vector(TO_UNSIGNED(C_CHAN_BLOCK_ID(chan_num), 8)) &
         std_logic_vector(TO_UNSIGNED(C_DMA_CHAN_TYPE(chan_num)+4, 8));
         
      -- DMA Control Register 0 - 7 used   
dcr_i <= DMACR(chan_num) & "0000000000000000000000000";

      -- Source Address 0 - 31 used
sa_i <= std_logic_vector(SA(chan_num));

      -- Destination Address 0 - 31 used
da_i <= std_logic_vector(DA(chan_num));

      -- DMA Length 0 - 31 used
lnt_i <= std_logic_vector(RESIZE(LENGTH(chan_num)(C_LENGTH_LEFT(chan_num) to 
            C_OPB_DBUS_WIDTH-1),C_OPB_DBUS_WIDTH));

      -- DMA Status Register 0 - 3 used
dsr_i <= dma_active(chan_num) & DBE(chan_num) & DBT(chan_num) & L(chan_num)
          & sg_active(chan_num) & "000000000000000000000000000";    

      -- Buffer Descriptor Address 0 - 31 used
bda_i <= std_logic_vector(BDA(chan_num));

      -- Software Control Register 0 - 0 used
sge_i <= SGE(chan_num) & "0000000000000000000000000000000";

      -- Unserviced Packet Count 22 - 31 used
upc_i <= std_logic_vector(RESIZE(UPC(chan_num)(C_OPB_DBUS_WIDTH - UPCB to 
              C_OPB_DBUS_WIDTH - 1),32));

      -- Packet Count Threshold 22 - 31 used
pct_i <= std_logic_vector(RESIZE(PCT(chan_num)(C_OPB_DBUS_WIDTH - UPCB to 
              C_OPB_DBUS_WIDTH - 1),C_OPB_DBUS_WIDTH));
              
      -- Packet Wait Bound 22 - 31 used        
pwb_i <= std_logic_vector(RESIZE(PWB(chan_num)(C_OPB_DBUS_WIDTH - PWBB to 
              C_OPB_DBUS_WIDTH - 1),C_OPB_DBUS_WIDTH));

      -- Interrupt Status Register 24 - 31 used
isr_i <= "0000000000000000000000000" & SGEND(chan_num) & SGDA(chan_num)
           & PWBR(chan_num) & PCTR(chan_num) & PD(chan_num)
           & DE(chan_num) & DD(chan_num);
           
      -- Interrupt Enable Register 24 - 31 used   
ier_i <= "0000000000000000000000000" & ESGEND(chan_num) & ESGDA(chan_num)  
           & EPWBR(chan_num) & EPCTR(chan_num) & EPD(chan_num)  
           & EDE(chan_num) & EDD(chan_num);  
           
ple_i <= std_logic_vector(RESIZE(PLENGTH(chan_num)(C_LENGTH_LEFT(chan_num) to
            C_OPB_DBUS_WIDTH-1),C_OPB_DBUS_WIDTH));

           
--p   DMA2Bus_Data <= --p
--p          std_logic_vector(TO_UNSIGNED(MAJOR_VERSION , 4)) & --p
--p          std_logic_vector(TO_UNSIGNED(MINOR_VERSION , 7)) & --p
--p          std_logic_vector(TO_UNSIGNED(HW_SW_COMPATIBILITY_REVISION, 5)) & --p
--p          std_logic_vector(TO_UNSIGNED(C_CHAN_BLOCK_ID(chan_num), 8)) & --p
--p          std_logic_vector(TO_UNSIGNED(C_DMA_CHAN_TYPE(chan_num)+4, 8)) --p
--p                                               when (RSTMIR_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          DMACR(chan_num) --p
--p            & "0000000000000000000000000"      when ( DMACR_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          std_logic_vector(SA(chan_num))       when (    SA_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          std_logic_vector(DA(chan_num))       when (    DA_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          std_logic_vector( --p
--p          RESIZE( --p
--p            LENGTH(chan_num)( --p
--p               C_LENGTH_LEFT(chan_num) to C_OPB_DBUS_WIDTH-1), --p
--p            C_OPB_DBUS_WIDTH --p
--p          ) --p
--p          )                                    when (LENGTH_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p              dma_active(chan_num)  -- DMA_BSY --p
--p     & DBE(chan_num) --p
--p            & DBT(chan_num) --p
--p     & L(chan_num) --p
--p     & sg_active(chan_num)   -- SG_BSY --p
--p            & "000000000000000000000000000"    when ( DMASR_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          std_logic_vector(BDA(chan_num))      when (   BDA_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          SGE(chan_num) & --p
--p            "0000000000000000000000000000000"  when (  SWCR_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          std_logic_vector( --p
--p          RESIZE( --p
--p            UPC(chan_num)( --p
--p               C_OPB_DBUS_WIDTH - UPCB to  --p
--p               C_OPB_DBUS_WIDTH - 1 --p
--p            ), --p
--p            32 --p
--p          ) --p
--p          )                                    when (   UPC_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          std_logic_vector( --p
--p          RESIZE( --p
--p            PCT(chan_num)( --p
--p               C_OPB_DBUS_WIDTH - UPCB to  --p
--p               C_OPB_DBUS_WIDTH - 1 --p
--p            ), --p
--p            C_OPB_DBUS_WIDTH --p
--p          ) --p
--p          )                                    when (   PCT_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          std_logic_vector( --p
--p          RESIZE( --p
--p            PWB(chan_num)( --p
--p               C_OPB_DBUS_WIDTH - PWBB to  --p
--p               C_OPB_DBUS_WIDTH - 1 --p
--p            ), --p
--p            C_OPB_DBUS_WIDTH --p
--p          ) --p
--p          )                                    when (   PWB_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          "0000000000000000000000000" --p
--p            & SGEND(chan_num) & SGDA(chan_num) --p
--p            & PWBR(chan_num) & PCTR(chan_num) --p
--p            & PD(chan_num) --p
--p            & DE(chan_num) & DD(chan_num)      when (   ISR_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          "0000000000000000000000000" --p
--p            & ESGEND(chan_num) & ESGDA(chan_num) --p
--p            & EPWBR(chan_num) & EPCTR(chan_num) --p
--p            & EPD(chan_num) --p
--p            & EDE(chan_num) & EDD(chan_num) --p
--p                                               when (   IER_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          std_logic_vector( --p
--p          RESIZE( --p
--p            PLENGTH(chan_num)( --p
--p               C_LENGTH_LEFT(chan_num) to C_OPB_DBUS_WIDTH-1), --p
--p            C_OPB_DBUS_WIDTH --p
--p          ) --p
--p          )                                    when (PLENGTH_sel and DMA_RdCE) --p
--p                                                    = '1' --p
--p                                               else --p
--p          "00000000000000000000000000000000"; --p


    DMA_RdAck_i_PROCESS: process(Bus2IP_Clk_i)
    begin
        if (Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1') then
          if (Bus2IP_Reset_i = RESET_ACTIVE) then
            DMA_RdAck_i <= '0';
          else
            DMA_RdAck_i <= DMA_RdCE and Bus2IP_RdReq_sa and not DMA_RdAck_i;
          end if;
        end if;
    end process;

    DMA_RdAck   <= DMA_RdAck_i;


    --= end, Register readback


    --- Master arbitration and concentration.
    MASTER_CONCENTRATION: block
    begin

        DMA_MstBusLock <= '0';    -- Bus-lock capability not used.
        DMA_MstBE      <= "1111"; -- Word transfers, only.

        REG_MQ_PROCESS : process (Bus2IP_Clk_i) is
            variable dma_sg_sr_pl : std_logic_vector(0 to 3);
        begin
          if Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1' then

            dma_sg_sr_pl := dma_sel & sg_sel & sr_sel & pl_sel;

            if Bus2IP_MstLastAck_i = '1' then
              DMA2Bus_Addr <= (others => '0');
              DMA2IP_Addr  <= (others => '0');
              DMA_MstWrReq <= '0';
              DMA_MstRdReq <= '0';
              DMA_MstBurst <= '0';
            else 
  --ToDo. May want to use encoded select (regular mux) here.
              case dma_sg_sr_pl is
                when "1000" => 
                    DMA2Bus_Addr <= dma2bus_addr_dma;
                    DMA2IP_Addr  <= dma2ip_addr_dma;
                    DMA_MstWrReq <= dma_mstwrreq_dma;
                    DMA_MstRdReq <= dma_mstrdreq_dma;
                    DMA_MstBurst <= dma_mstburst_dma;
--                  DMA_MstBurst <= burst_cond_dma;
                when "0100" => 
                    DMA2Bus_Addr <= dma2bus_addr_sg;
                    DMA2IP_Addr  <= dma2ip_addr_sg;
                    DMA_MstWrReq <= dma_mstwrreq_sg;
                    DMA_MstRdReq <= dma_mstrdreq_sg;
                    DMA_MstBurst <= dma_mstburst_sg;
                when "0010" => 
                    DMA2Bus_Addr <= std_logic_vector(SRAddrFIFO_out(cco));
                    DMA2IP_Addr  <= std_logic_vector(
                                      TO_UNSIGNED(
                                        C_STAT_FIFO_BAR(cco),
                                        C_M + BPST_BITS
                                      )(C_M + BPST_BITS - 1 downto BPST_BITS)
                                    );
                    DMA_MstWrReq <= dma_mstwrreq_sr;
                    DMA_MstRdReq <= '0';
                    DMA_MstBurst <= '0';
                when "0001" => 
                    DMA2Bus_Addr <= std_logic_vector(
                                      TO_UNSIGNED(
                                        C_LEN_FIFO_BAR(cco),
                                        C_OPB_ABUS_WIDTH
                                      )
                                    );
                    DMA2IP_Addr <=
                          std_logic_vector(
                             UNSIGNED(
                                 C_DMA_BAR(   C_OPB_ABUS_WIDTH - BPST_BITS - C_M
                                           to C_OPB_ABUS_WIDTH - BPST_BITS - 1)
                             )
                           + (  TO_UNSIGNED(cco, NUM_CHAN_BITS)
                              & TO_UNSIGNED(r_PLENGTH, RPB))
                          ); 
                    DMA_MstWrReq <= dma_mstwrreq_pl;
                    DMA_MstRdReq <= not dma_mstwrreq_pl;
                    DMA_MstBurst <= '0';
                when others =>
                    DMA2Bus_Addr <= (others => '0');
                    DMA2IP_Addr  <= (others => '0');
                    DMA_MstWrReq <= '0';
                    DMA_MstRdReq <= '0';
                    DMA_MstBurst <= '0';
              end case;
            end if;
          end if;
        end process;

    end block;
    --= end, Master arbitration and concentration.

    --- SRAddrFIFO for each rx pkt or tx pkt channel.
    SRAddrFIFO_GEN: for i in 0 to LAST_CHAN generate
      SRAddrFIFO_GEN: if C_DMA_CHAN_TYPE(i) = 2 or
                              C_DMA_CHAN_TYPE(i) = 3 generate
        I_SRL_FIFO : SRL_FIFO
          generic map (
            C_DATA_BITS => C_OPB_DBUS_WIDTH,
            C_DEPTH     => 16
          )
          port map (
            Clk         => Bus2IP_Clk_i,
            Reset       => reset(i),
            FIFO_Write  => wr_SRAddrFIFO(i),
            Data_In     => dma2bus_addr_sg,
            FIFO_Read   => rd_SRAddrFIFO(i),
            Data_Out    => SRAddrFIFO_out(i),
            FIFO_Full   => SRAddrFIFO_full(i),
            Data_Exists => SRAddrFIFO_nonempty(i),
            Addr        => open
          );
      end generate;
      -- Tie off outputs for non-existent instances.
      SRAddrFIFO_TIEOFF_GEN: if C_DMA_CHAN_TYPE(i) = 0 or
                                C_DMA_CHAN_TYPE(i) = 1 generate
          SRAddrFIFO_out(i) <= (others => '0');
          SRAddrFIFO_full(i) <= '0';
          SRAddrFIFO_nonempty(i) <= '0';
      end generate;
    end generate;
    --= end, SRAddrFIFO for each rx pkt or tx pkt channel.


    --- DMA state machine.
    DMA_SM: block 
        type dma_state is (
            IDLE,
            DONECHK,    -- Done check. Test for end of DMA operation.
            XACTION,    -- Perform a bus transaction.
            GET_BDA,
            HANDLE_SRA, -- If required, save the address of where SR will go.
            GET_DMACR,
            GET_SA,
            GET_DA,
            GET_LENGTH,
            GET_PLENGTH,
            PUT_LENGTH, -- Write the completion LENGTH.
            PUT_DMASR,  -- Write the DMA completion status.
            LQCHK,       
            PUT_PLENGTH,
            HALT,
            A_WRITE_SR,
            B_WRITE_SR,
            C_WRITE_SR
        );
        type dma_state_array is array(0 to LAST_CHAN) of dma_state;
        signal dma_cs              : dma_state_array;
        signal dma_ns              : dma_state; 
        signal block_chan_muxing   : std_logic;
        signal dma_sel_ns          : std_logic;
        signal sg_sel_ns           : std_logic;
        signal pl_sel_ns           : std_logic;
        signal sr_sel_ns           : std_logic;
        signal dma_mstburst_dma_ns : std_logic;
        signal mstr_op_done        : std_logic;
        signal mstr_op_done_ns     : std_logic;
        signal wr_cond, rd_cond    : std_logic; -- direction of the mem xfer

    begin

        DMA_SM_COM_PROCESS: process(
            dma_cs, dma_active, LENGTH_cco, PLENGTH_cco,
            cco, rx, tx, LENGTH_ge_BPBT, WFIFO2DMA_Vacancy,
            Bus2IP_MstWrAck_i, Bus2IP_MstRdAck_i, Mstr_sel_ma,
            Bus2IP_MstError_i, Bus2IP_MstTimeOut_i, Bus2IP_MstLastAck_i,
            burst_cond_dma, dest_is_a_fifo,
            first, no_bda_link, sg_active, sgGo, L_tx,
            IP2DMA_TxLength_Full,  IP2DMA_RxLength_Empty,
            IP2DMA_TxStatus_Empty, SRAddrFIFO_nonempty,
            SRAddrFIFO_cco_hasroom, dma_mstburst_dma, dma_completing
        )
            variable incdec            : std_logic;
            variable rx_pkt_complete   : std_logic;
        begin

          -- Default assignments for dma_ns and state machine outputs.
          dma_starting        <= '0';
          dma_completing      <= '0';
          block_chan_muxing   <= '0';
          set_L_rx            <= '0';
	  set_DBE             <= '0';
          set_DBT             <= '0';
          inc_SA              <= '0';
          inc_DA              <= '0';
          dec_LENGTH          <= '0';
          inc_PLENGTH         <= '0';
          dec_PLENGTH         <= '0';
          clr_PLENGTH         <= '0';
          dma_sel_ns          <= '0';
          sg_sel_ns           <= '0';
          pl_sel_ns           <= '0';
          sr_sel_ns           <= '0';
          dma_mstburst_dma_ns <= '0';
          reset_sg_offset     <= '0';
          inc_sg_offset       <= (others => '0');
          dma_mstwrreq_sg     <= '0';
          dma_mstwrreq_sr     <= '0';
          dma_mstwrreq_pl     <= '0';
          mstr_op_done_ns     <= '0';
          update_first        <= '0';
          wr_SRAddrFIFO       <= (others => '0');
          rd_SRAddrFIFO       <= (others => '0');
          is_idle             <= (others => '0');
          rx_pkt_complete     := bo2sl(rx(cco)='1' and (PLENGTH_cco=0));

          -- Next state and output logic.
          case dma_cs(cco) is

--ToDo. There may be only one rx or tx channel because there is just one
--      each of IP2DMA_RxStatus_Empty and IP2DMA_TxStatus_Empty.

            when IDLE =>
              is_idle(cco) <= '1';
              if    (tx(cco) and not IP2DMA_TxStatus_Empty) = '1'
                 or (rx_pkt_complete and SRAddrFIFO_nonempty(cco)) = '1' then
                  sr_sel_ns <= '1';
                  block_chan_muxing <= '1';
                  dma_ns <= A_WRITE_SR;
              else
                if sgGo(cco) = '1' then
                    if (not rx(cco) or not IP2DMA_RxLength_Empty
                                    or not first(cco)
                       ) = '1' then    -- ToDo. IP2DMA_RxLength_Empty being
                                       -- scalar allows for just one Rx chan.
                      if (not no_bda_link(cco)) = '1' then
                        sg_sel_ns <= '1';
                        block_chan_muxing <= '1';
                        dma_ns <= GET_BDA;
                      elsif (rx(cco) and first(cco)) = '1' then
                        pl_sel_ns <= '1';
                        block_chan_muxing <= '1';
                        reset_sg_offset <= '1';
                        dma_ns <= GET_PLENGTH;
                      else 
                        block_chan_muxing <= '1';  -- Optional.
                        reset_sg_offset <= '1';
                        dma_ns <= HANDLE_SRA;
                      end if;
                    else
                        dma_ns <= IDLE;
                    end if;
                else
                    if  dma_active(cco) = '1' then  -- Simple DMA.
                        dma_starting <= '1';
                        dma_ns <= DONECHK;
                    else
                        dma_ns <= IDLE;
                    end if;
                end if;
              end if;

            when GET_BDA =>
                -- This implementation assumes that the Bus2IP_MstLastAck_i
                -- is concurrent with or follows the IP2Bus_WrAck that actually
                -- writes the PLENGTH register. (An earlier implementation
                -- assumed the opposite order--allowing the MasterAttachment/
                -- SlaveAttachment to do a posted write. When that
                -- implementation actually experienced the opposite during
                -- operation, then state GET_BDA's successor state,
                -- GET_PLENGTH, would respond to the Bus2IP_MstLastAck_i
                -- that corresponds to state GET_BDA!)
                -- State GET_LENGTH has similar considerations.
                if Bus2IP_MstLastAck_i = '1' then
                  if (rx(cco) and first(cco)) = '1' then
                    pl_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    reset_sg_offset <= '1';
                    dma_ns <= GET_PLENGTH;
                  else
                    block_chan_muxing <= '1';  -- Optional.
                    reset_sg_offset <= '1';
                    dma_ns <= HANDLE_SRA;
                  end if;
                else
                    block_chan_muxing <= '1';
                    sg_sel_ns <= '1';
                    dma_ns <= GET_BDA;
                end if;

            when GET_PLENGTH =>
                if Bus2IP_MstLastAck_i = '1' then
                    block_chan_muxing <= '1';  -- Optional.
                    dma_ns <= HANDLE_SRA;
                else
                    block_chan_muxing <= '1';
                    pl_sel_ns <= '1';
                    dma_ns <= GET_PLENGTH;
                end if;

            when HANDLE_SRA =>
              if (tx(cco) and not IP2DMA_TxStatus_Empty) = '1' then
                  sr_sel_ns <= '1';
                  block_chan_muxing <= '1';
                  dma_ns <= C_WRITE_SR;
              elsif ((rx(cco) or tx(cco)) and first(cco)) = '1' then
                  if (SRAddrFIFO_cco_hasroom = '1') then
                      wr_SRAddrFIFO(cco) <= '1';
                      inc_sg_offset(cco) <= '1';
                      block_chan_muxing <= '1';
                      sg_sel_ns <= '1';
                      dma_ns <= GET_DMACR;
                  else
                      dma_ns <= HANDLE_SRA;
                  end if;
              else
                  inc_sg_offset(cco) <= '1';
                  block_chan_muxing <= '1';
                  sg_sel_ns <= '1';
                  dma_ns <= GET_DMACR;
              end if;

            when GET_DMACR =>
                if Bus2IP_MstLastAck_i = '1' then
                    sg_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    inc_sg_offset(cco) <= '1';
                    dma_ns <= GET_SA;
                else
                    sg_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    dma_ns <= GET_DMACR;
                end if;

            when GET_SA =>
                if Bus2IP_MstLastAck_i = '1' then
                    sg_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    inc_sg_offset(cco) <= '1';
                    dma_ns <= GET_DA;
                else
                    sg_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    dma_ns <= GET_SA;
                end if;

            when GET_DA =>
                if Bus2IP_MstLastAck_i = '1' then
                    sg_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    inc_sg_offset(cco) <= '1';
                    dma_ns <= GET_LENGTH;
                else
                    sg_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    dma_ns <= GET_DA;
                end if;

            when GET_LENGTH =>
                if Bus2IP_MstLastAck_i = '1' then
                   -- See the comment of state GET_ BDA for considerations
                   -- that also apply to this state. The load of the LENGTH
                   -- register needs be complete before proceeding to the
                   -- next state. (A "MstLastAck" indication ahead of the
                   -- completion of a posted write will not work. An earlier
                   -- version had such posted write behavior. In that version,
                   -- this state was not exited until the LENGTH register
                   -- actually loaded; signal load_length(cco) was used.)
                    dma_starting <= '1';
                    dma_ns <= DONECHK;
                else
                    block_chan_muxing <= '1';
                    sg_sel_ns <= '1';
                    dma_ns <= GET_LENGTH;
                end if;

            when DONECHK =>
                dma_completing <= bo2sl(LENGTH_cco = 0) or rx_pkt_complete;
                if (tx(cco) and not IP2DMA_TxStatus_Empty) = '1' then
                    sr_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    dma_ns <= B_WRITE_SR;
                elsif dma_completing = '1' then
                    set_L_rx <= rx_pkt_complete;
                    if sg_active(cco) = '1' then
                        sg_sel_ns <= '1';
                        block_chan_muxing <= '1';
                        dma_ns <= PUT_LENGTH;
                    else
                        dma_ns <= IDLE;
                    end if;
                elsif
                -- We go to do a bus transaction when we are not at the normal
                -- end of a DMA operation and there is not a condition
                -- that keeps us from proceeding.
                -- The condition that could keep us from proceeding is that
                -- we are writing to a FIFO and it doesn't have vacancy
                -- to (1) accomodate a single transfer in the case there isn't
                -- enough left to do a burst or, otherwise, to (2) accomodate
                -- a burst.
                      (    dma_completing = '0'
                       and not (    (dest_is_a_fifo = '1')
                                and (   (    LENGTH_ge_BPBT = '0'
                                         and UNSIGNED(WFIFO2DMA_Vacancy) = 0
                                        )
                                     or (    LENGTH_ge_BPBT = '1'
                                         and UNSIGNED(WFIFO2DMA_Vacancy) < TPB
                                        )
                                    )
                               )
                      ) then
                    dma_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    dma_mstburst_dma_ns <= burst_cond_dma;
                    dma_ns <= XACTION;
                else
                    dma_ns <= DONECHK;
                end if;

            when XACTION => 
                incdec :=
                  (Bus2IP_MstWrAck_i or Bus2IP_MstRdAck_i) and Mstr_sel_ma;
                inc_SA <= incdec;
                inc_DA <= incdec;
                dec_LENGTH <= incdec;
                inc_PLENGTH <= incdec and tx(cco);
                dec_PLENGTH <= incdec and rx(cco);
                if (Bus2IP_MstError_i or Bus2IP_MstTimeOut_i) = '1' then
                    set_DBE <= Bus2IP_MstError_i;
                    set_DBT <= Bus2IP_MstTimeOut_i;
                    dma_completing <= '1';
                    if sg_active(cco) = '1' then
                        dma_ns <= HALT;
                    else
                        dma_ns <= IDLE;
                    end if;
                elsif (Bus2IP_MstLastAck_i) = '1' then
                  --block_chan_muxing  <= '1';   -- Optional, no blocking for
                                                 -- find-grain switching
                                                 -- between channels.
                    dma_ns <= DONECHK;
                else
                    dma_sel_ns <= '1';
                    block_chan_muxing  <= '1';
                    dma_mstburst_dma_ns <= dma_mstburst_dma;
                    dma_ns <= XACTION;
                end if;

            when PUT_LENGTH =>
                dma_mstwrreq_sg <= '1';
                if Bus2IP_MstLastAck_i = '1' then
                    block_chan_muxing <= '1';
                    sg_sel_ns <= '1';
                    inc_sg_offset(cco) <= '1';
                    dma_ns <= PUT_DMASR;
                else
                    block_chan_muxing <= '1';
                    sg_sel_ns <= '1';
                    dma_ns <= PUT_LENGTH;
                end if;

            when PUT_DMASR =>
                dma_mstwrreq_sg <= '1';
                if Bus2IP_MstLastAck_i = '1' then
                    inc_sg_offset(cco) <= '1';
                    dma_ns <= LQCHK;
                else
                    block_chan_muxing <= '1';
                    sg_sel_ns <= '1';
                    dma_ns <= PUT_DMASR;
                end if;

            when LQCHK =>
                update_first <= '1';
                if (not tx(cco) or not L_tx(cco)) = '1' then
                    dma_ns <= IDLE;
                elsif (not IP2DMA_TXLength_Full) = '1' then
                    block_chan_muxing <= '1';
                    pl_sel_ns <= '1';
                    dma_ns <= PUT_PLENGTH;
                else
                    dma_ns <= LQCHK;
                end if;

            when PUT_PLENGTH =>
                dma_mstwrreq_pl <= '1';
                if Bus2IP_MstLastAck_i = '1' then
                    clr_PLENGTH <= '1';
                    dma_ns <= IDLE;
                else
                    block_chan_muxing <= '1';
                    pl_sel_ns <= '1';
                    dma_ns <= PUT_PLENGTH;
                end if;

            when HALT =>
                dma_ns <= HALT;

            when A_WRITE_SR =>
                is_idle(cco) <= '1';
--ToDo. Perhaps can eliminate this sig and drive dma_mstwrreq to '1' when sr_sel
                dma_mstwrreq_sr <= '1';
                if Bus2IP_MstLastAck_i = '1' then
                    rd_SRAddrFIFO(cco) <= '1';
                    dma_ns <= IDLE;
                else
                    sr_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    dma_ns <= A_WRITE_SR;
                end if;

            when B_WRITE_SR =>
                dma_mstwrreq_sr <= '1';
                if Bus2IP_MstLastAck_i = '1' then
                    rd_SRAddrFIFO(cco) <= '1';
                    block_chan_muxing <= '1';
                    dma_ns <= DONECHK;
                else
                    sr_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    dma_ns <= B_WRITE_SR;
                end if;

            when C_WRITE_SR =>
                dma_mstwrreq_sr <= '1';
                if Bus2IP_MstLastAck_i = '1' then
                    rd_SRAddrFIFO(cco) <= '1';
                    block_chan_muxing <= '1';
                    dma_ns <= HANDLE_SRA;
                else
                    sr_sel_ns <= '1';
                    block_chan_muxing <= '1';
                    dma_ns <= C_WRITE_SR;
                end if;

          end case;
        end process;

        DMA_SM_DMA_CS_REG_PROCESS: process(Bus2IP_Clk_i)
        begin
          for i in 0 to LAST_CHAN loop
            if Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1' then
               if reset(i) = '1' then
                   dma_cs(i) <= IDLE;
               elsif cco = i then
                   dma_cs(i) <= dma_ns;
               end if; 
            end if;
          end loop;
        end process;

        DMA_SM_OTHER_REG_PROCESS: process(Bus2IP_Clk_i)
        begin
            if Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1' then
                if Bus2IP_Reset_i='1' then
                    dma_sel <= '0';
                    sg_sel <= '0';
                    pl_sel <= '0';
                    sr_sel <= '0';
                    dma_mstburst_dma <= '0';
                    mstr_op_done <= '0';
                    cco <= 0;
                else
                    dma_sel <= dma_sel_ns;
                    sg_sel <= sg_sel_ns;
                    pl_sel <= pl_sel_ns;
                    sr_sel <= sr_sel_ns;
                    dma_mstburst_dma <= dma_mstburst_dma_ns;
                    mstr_op_done <= mstr_op_done_ns;
                    if block_chan_muxing = '0' then
                        if cco = LAST_CHAN then
                            cco <= 0;
                        else
                            cco <= cco+1;
                        end if;
                    end if;
                end if;
            end if;
        end process;

        wr_cond <= SLOCAL(cco) and not DLOCAL(cco);
        rd_cond <= DLOCAL(cco) and not SLOCAL(cco);

        dma2bus_addr_dma <= std_logic_vector(SA(cco)) when rd_cond = '1' else
                            std_logic_vector(DA(cco));

        dma2ip_addr_dma  <= std_logic_vector(DA(cco)(29-C_M+1 to 29))
                            when rd_cond = '1'
                            else
                            std_logic_vector(SA(cco)(29-C_M+1 to 29));
--ToDo. Change 29, above, to symbolic constant.

        dma_mstwrreq_dma <= wr_cond;
        dma_mstrdreq_dma <= rd_cond;

        burst_cond_dma <= bo2sl(C_DMA_ALLOW_BURST) and
                          (   (rx(cco) and PLENGTH_ge_BPBT and LENGTH_ge_BPBT)
                           or (not rx(cco) and  LENGTH_ge_BPBT)
                          );
            -- Note, by using the e.g. "length" >= 32 test, we are
            -- passing up optimization of the 29, 30 and 31 cases
            -- in order to have a simpler test.

        SG_ACTIVE_PROCESS: process (Bus2IP_Clk_i) is
        begin
            if Bus2IP_Clk_i'event and Bus2IP_Clk_i = '1' then
                for i in 0 to LAST_CHAN loop
                    if reset(i) = '1' then
                        sg_active(i) <= '0';
                        sg_active_d1(i) <= '0';
                    else
                        sg_active_d1(i) <= sg_active(i);
                        if (SGE(i) and not SGS(i)) = '1' then
                            sg_active(i) <= '1';
                        elsif     is_idle(i) = '1'
                              and (   (    C_DMA_CHAN_TYPE(i) /=2
                                       and C_DMA_CHAN_TYPE(i) /=3
                                      )
                                   or (    SRAddrFIFO_nonempty(i) = '0'
                                       and first(i) = '1'
                                      )
                                  ) then
                            sg_active(i) <= '0';
                        end if;
                    end if;
                end loop;
            end if;
        end process;

    end block;
    --= end, DMA state machine.

    --- SG MQ bundle.
    SG_SM: block 
    begin
      dma2bus_addr_sg  <= std_logic_vector(
                              BDA(cco)(0 to BDA(cco)'length - BPST_BITS -1)
                            + sg_offset(cco)
                          ) & "00";
      dma2ip_addr_sg   <=     C_DMA_BAR(
                                   C_OPB_ABUS_WIDTH - BPST_BITS - C_M
                                to C_OPB_ABUS_WIDTH - BPST_BITS - NUM_CHAN_BITS 
                                                                - RPB
                                                                - 1
                              )
                            & std_logic_vector(TO_UNSIGNED(cco, NUM_CHAN_BITS))
                            & std_logic_vector(sg_offset(cco)); 
      dma_mstrdreq_sg  <= not dma_mstwrreq_sg;
      dma_mstburst_sg  <= '0';
    end block;
    --= end, SG MQ bundle.

end sim;

