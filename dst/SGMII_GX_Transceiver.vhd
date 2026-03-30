-- GE extended mode GE GX-transceiver. 
--
--------------------------------------------------------------------------------
--$Rev:: 2287                                                                  $
--$Author:: Quirin                                                             $
--$Date:: 2012-05-31 17:09:09 +0200 (Do., 31 Mai 2012)                         $
--------------------------------------------------------------------------------



LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY SGMII_GX_Transceiver IS
   PORT  (
          cal_blk_clk            : IN   std_logic;
          gxb_powerdown          : IN   std_logic_vector(0 DOWNTO 0);
          pll_inclk              : IN   std_logic;
          rx_analogreset         : IN   std_logic_vector(0 DOWNTO 0);
          rx_cruclk              : IN   std_logic_vector(0 DOWNTO 0) := (OTHERS => '0');
          rx_datain              : IN   std_logic_vector(0 DOWNTO 0);
          rx_digitalreset        : IN   std_logic_vector(0 DOWNTO 0);
          tx_ctrlenable          : IN   std_logic_vector(0 DOWNTO 0);
          tx_datain              : IN   std_logic_vector(7 DOWNTO 0);
          tx_digitalreset        : IN   std_logic_vector(0 DOWNTO 0);
          rx_ctrldetect          : OUT  std_logic_vector(0 DOWNTO 0);
          rx_dataout             : OUT  std_logic_vector(7 DOWNTO 0);
          rx_disperr             : OUT  std_logic_vector(0 DOWNTO 0);
          rx_errdetect           : OUT  std_logic_vector(0 DOWNTO 0);
          rx_patterndetect       : OUT  std_logic_vector(0 DOWNTO 0);
          rx_rlv                 : OUT  std_logic_vector(0 DOWNTO 0);
          rx_rmfifodatadeleted   : OUT  std_logic_vector(0 DOWNTO 0);
          rx_rmfifodatainserted  : OUT  std_logic_vector(0 DOWNTO 0);
          rx_runningdisp         : OUT  std_logic_vector(0 DOWNTO 0);
          rx_syncstatus          : OUT  std_logic_vector(0 DOWNTO 0);
          tx_clkout              : OUT  std_logic_vector(0 DOWNTO 0);
          tx_dataout             : OUT  std_logic_vector(0 DOWNTO 0)
          );
END SGMII_GX_Transceiver;


ARCHITECTURE SYN OF sgmii_gx_transceiver IS

   SIGNAL sub_wire0  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire1  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire2  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire3  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire4  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire5  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire6  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire7  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire8  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire9  : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire10 : std_logic_vector(0 DOWNTO 0);
   SIGNAL sub_wire11 : std_logic_vector(7 DOWNTO 0);



   COMPONENT alt2gxb
      GENERIC (
               cmu_pll_inclock_period                        : natural;
               cmu_pll_loop_filter_resistor_control          : natural;
               digitalreset_port_width                       : natural;
               en_local_clk_div_ctrl                         : string;
               equalizer_ctrl_a_setting                      : natural;
               equalizer_ctrl_b_setting                      : natural;
               equalizer_ctrl_c_setting                      : natural;
               equalizer_ctrl_d_setting                      : natural;
               equalizer_ctrl_v_setting                      : natural;
               equalizer_dcgain_setting                      : natural;
               intended_device_family                        : string;
               loopback_mode                                 : string;
               lpm_type                                      : string;
               number_of_channels                            : natural;
               operation_mode                                : string;
               pll_legal_multiplier_list                     : string;
               preemphasis_ctrl_1stposttap_setting           : natural;
               preemphasis_ctrl_2ndposttap_inv_setting       : string;
               preemphasis_ctrl_2ndposttap_setting           : natural;
               preemphasis_ctrl_pretap_inv_setting           : string;
               preemphasis_ctrl_pretap_setting               : natural;
               protocol                                      : string;
               receiver_termination                          : string;
               reconfig_dprio_mode                           : natural;
               reverse_loopback_mode                         : string;
               rx_8b_10b_compatibility_mode                  : string;
               rx_8b_10b_mode                                : string;
               rx_align_pattern                              : string;
               rx_align_pattern_length                       : natural;
               rx_allow_align_polarity_inversion             : string;
               rx_allow_pipe_polarity_inversion              : string;
               rx_bandwidth_mode                             : natural;
               rx_bitslip_enable                             : string;
               rx_byte_ordering_mode                         : string;
               rx_channel_width                              : natural;
               rx_common_mode                                : string;
               rx_cru_inclock_period                         : natural;
               rx_cru_pre_divide_by                          : natural;
               rx_datapath_protocol                          : string;
               rx_data_rate                                  : natural;
               rx_data_rate_remainder                        : natural;
               rx_disable_auto_idle_insertion                : string;
               rx_enable_bit_reversal                        : string;
               rx_enable_lock_to_data_sig                    : string;
               rx_enable_lock_to_refclk_sig                  : string;
               rx_enable_self_test_mode                      : string;
               rx_enable_true_complement_match_in_word_align : string;
               rx_force_signal_detect                        : string;
               rx_ppmselect                                  : natural;
               rx_rate_match_back_to_back                    : string;
               rx_rate_match_fifo_mode                       : string;
               rx_rate_match_ordered_set_based               : string;
               rx_rate_match_pattern1                        : string;
               rx_rate_match_pattern2                        : string;
               rx_rate_match_pattern_size                    : natural;
               rx_rate_match_skip_set_based                  : string;
               rx_run_length                                 : natural;
               rx_run_length_enable                          : string;
               rx_signal_detect_threshold                    : natural;
               rx_use_align_state_machine                    : string;
               rx_use_clkout                                 : string;
               rx_use_coreclk                                : string;
               rx_use_cruclk                                 : string;
               rx_use_deserializer_double_data_mode          : string;
               rx_use_deskew_fifo                            : string;
               rx_use_double_data_mode                       : string;
               rx_use_rate_match_pattern1_only               : string;
               transmitter_termination                       : string;
               tx_8b_10b_compatibility_mode                  : string;
               tx_8b_10b_mode                                : string;
               tx_allow_polarity_inversion                   : string;
               tx_analog_power                               : string;
               tx_channel_width                              : natural;
               tx_common_mode                                : string;
               tx_data_rate                                  : natural;
               tx_data_rate_remainder                        : natural;
               tx_enable_bit_reversal                        : string;
               tx_enable_idle_selection                      : string;
               tx_enable_self_test_mode                      : string;
               tx_refclk_divide_by                           : natural;
               tx_transmit_protocol                          : string;
               tx_use_coreclk                                : string;
               tx_use_double_data_mode                       : string;
               tx_use_serializer_double_data_mode            : string;
               use_calibration_block                         : string;
               vod_ctrl_setting                              : natural
               );
      PORT    (
               rx_disperr              : OUT  std_logic_vector(0 DOWNTO 0);
               rx_rlv                  : OUT  std_logic_vector(0 DOWNTO 0);
               rx_patterndetect        : OUT  std_logic_vector(0 DOWNTO 0);
               rx_ctrldetect           : OUT  std_logic_vector(0 DOWNTO 0);
               pll_inclk               : IN   std_logic;
               gxb_powerdown           : IN   std_logic_vector(0 DOWNTO 0);
               tx_datain               : IN   std_logic_vector(7 DOWNTO 0);
               rx_errdetect            : OUT  std_logic_vector(0 DOWNTO 0);
               rx_rmfifodatadeleted    : OUT  std_logic_vector(0 DOWNTO 0);
               rx_cruclk               : IN   std_logic_vector(0 DOWNTO 0);
               cal_blk_clk             : IN   std_logic;
               rx_runningdisp          : OUT  std_logic_vector(0 DOWNTO 0);
               tx_dataout              : OUT  std_logic_vector(0 DOWNTO 0);
               rx_rmfifodatainserted   : OUT  std_logic_vector(0 DOWNTO 0);
               rx_datain               : IN   std_logic_vector(0 DOWNTO 0);
               tx_ctrlenable           : IN   std_logic_vector(0 DOWNTO 0);
               rx_analogreset          : IN   std_logic_vector(0 DOWNTO 0);
               rx_syncstatus           : OUT  std_logic_vector(0 DOWNTO 0);
               rx_digitalreset         : IN   std_logic_vector(0 DOWNTO 0);
               tx_digitalreset         : IN   std_logic_vector(0 DOWNTO 0);
               tx_clkout               : OUT  std_logic_vector(0 DOWNTO 0);
               rx_dataout              : OUT  std_logic_vector(7 DOWNTO 0)
               );
   END COMPONENT;

BEGIN
	rx_disperr    <= sub_wire0(0 DOWNTO 0);
	rx_rlv    <= sub_wire1(0 DOWNTO 0);
	rx_patterndetect    <= sub_wire2(0 DOWNTO 0);
	rx_ctrldetect    <= sub_wire3(0 DOWNTO 0);
	rx_errdetect    <= sub_wire4(0 DOWNTO 0);
	rx_rmfifodatadeleted    <= sub_wire5(0 DOWNTO 0);
	rx_runningdisp    <= sub_wire6(0 DOWNTO 0);
	tx_dataout    <= sub_wire7(0 DOWNTO 0);
	rx_rmfifodatainserted    <= sub_wire8(0 DOWNTO 0);
	rx_syncstatus    <= sub_wire9(0 DOWNTO 0);
	tx_clkout    <= sub_wire10(0 DOWNTO 0);
	rx_dataout    <= sub_wire11(7 DOWNTO 0);

	alt2gxb_component : alt2gxb
	GENERIC MAP (
		cmu_pll_inclock_period => 8000,
		cmu_pll_loop_filter_resistor_control => 3,
		digitalreset_port_width => 1,
		en_local_clk_div_ctrl => "true",
		equalizer_ctrl_a_setting => 0,
		equalizer_ctrl_b_setting => 0,
		equalizer_ctrl_c_setting => 0,
		equalizer_ctrl_d_setting => 0,
		equalizer_ctrl_v_setting => 0,
		equalizer_dcgain_setting => 0,
		intended_device_family => "Arria GX",
		loopback_mode => "none",
		lpm_type => "alt2gxb",
		number_of_channels => 1,
		operation_mode => "duplex",
		pll_legal_multiplier_list => "disable_4_5_mult_above_3125",
		preemphasis_ctrl_1stposttap_setting => 0,
		preemphasis_ctrl_2ndposttap_inv_setting => "false",
		preemphasis_ctrl_2ndposttap_setting => 0,
		preemphasis_ctrl_pretap_inv_setting => "false",
		preemphasis_ctrl_pretap_setting => 0,
		protocol => "gige",
		receiver_termination => "oct_100_ohms",
		reconfig_dprio_mode => 0,
		reverse_loopback_mode => "none",
		rx_8b_10b_compatibility_mode => "true",
		rx_8b_10b_mode => "normal",
		rx_align_pattern => "1111100",
		rx_align_pattern_length => 7,
		rx_allow_align_polarity_inversion => "false",
		rx_allow_pipe_polarity_inversion => "false",
		rx_bandwidth_mode => 1,
		rx_bitslip_enable => "false",
		rx_byte_ordering_mode => "none",
		rx_channel_width => 8,
		rx_common_mode => "0.9v",
		rx_cru_inclock_period => 8000,
		rx_cru_pre_divide_by => 1,
		rx_datapath_protocol => "basic",
		rx_data_rate => 1250,
		rx_data_rate_remainder => 0,
		rx_disable_auto_idle_insertion => "true",
		rx_enable_bit_reversal => "false",
		rx_enable_lock_to_data_sig => "false",
		rx_enable_lock_to_refclk_sig => "false",
		rx_enable_self_test_mode => "false",
		rx_enable_true_complement_match_in_word_align => "false",
		rx_force_signal_detect => "true",
		rx_ppmselect => 32,
		rx_rate_match_back_to_back => "true",
		rx_rate_match_fifo_mode => "normal",
		rx_rate_match_ordered_set_based => "true",
		rx_rate_match_pattern1 => "10100010010101111100",
		rx_rate_match_pattern2 => "10101011011010000011",
		rx_rate_match_pattern_size => 20,
		rx_rate_match_skip_set_based => "true",
		rx_run_length => 5,
		rx_run_length_enable => "true",
		rx_signal_detect_threshold => 2,
		rx_use_align_state_machine => "true",
		rx_use_clkout => "false",
		rx_use_coreclk => "false",
		rx_use_cruclk => "true",
		rx_use_deserializer_double_data_mode => "false",
		rx_use_deskew_fifo => "false",
		rx_use_double_data_mode => "false",
		rx_use_rate_match_pattern1_only => "false",
		transmitter_termination => "oct_100_ohms",
		tx_8b_10b_compatibility_mode => "true",
		tx_8b_10b_mode => "normal",
		tx_allow_polarity_inversion => "false",
		tx_analog_power => "1.5v",
		tx_channel_width => 8,
		tx_common_mode => "0.6v",
		tx_data_rate => 1250,
		tx_data_rate_remainder => 0,
		tx_enable_bit_reversal => "false",
		tx_enable_idle_selection => "true",
		tx_enable_self_test_mode => "false",
		tx_refclk_divide_by => 1,
		tx_transmit_protocol => "basic",
		tx_use_coreclk => "false",
		tx_use_double_data_mode => "false",
		tx_use_serializer_double_data_mode => "false",
		use_calibration_block => "true",
		vod_ctrl_setting => 3
	)
	PORT MAP (
		pll_inclk => pll_inclk,
		gxb_powerdown => gxb_powerdown,
		tx_datain => tx_datain,
		rx_cruclk => rx_cruclk,
		cal_blk_clk => cal_blk_clk,
		rx_datain => rx_datain,
		tx_ctrlenable => tx_ctrlenable,
		rx_analogreset => rx_analogreset,
		rx_digitalreset => rx_digitalreset,
		tx_digitalreset => tx_digitalreset,
		rx_disperr => sub_wire0,
		rx_rlv => sub_wire1,
		rx_patterndetect => sub_wire2,
		rx_ctrldetect => sub_wire3,
		rx_errdetect => sub_wire4,
		rx_rmfifodatadeleted => sub_wire5,
		rx_runningdisp => sub_wire6,
		tx_dataout => sub_wire7,
		rx_rmfifodatainserted => sub_wire8,
		rx_syncstatus => sub_wire9,
		tx_clkout => sub_wire10,
		rx_dataout => sub_wire11
	);



END SYN;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: ALT_SIMLIB_GEN STRING "0"
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Arria GX"
-- Retrieval info: PRIVATE: NUM_KEYS NUMERIC "27"
-- Retrieval info: PRIVATE: RECONFIG_PROTOCOL STRING "Basic"
-- Retrieval info: PRIVATE: RECONFIG_SUBPROTOCOL STRING "none"
-- Retrieval info: PRIVATE: RX_ENABLE_DC_COUPLING STRING "false"
-- Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
-- Retrieval info: PRIVATE: WIZ_DATA_RATE STRING "1250"
-- Retrieval info: PRIVATE: WIZ_DPRIO_INCLK_FREQ_ARRAY STRING ""
-- Retrieval info: PRIVATE: WIZ_DPRIO_INPUT_A STRING "2000"
-- Retrieval info: PRIVATE: WIZ_DPRIO_INPUT_A_UNIT STRING "Mbps"
-- Retrieval info: PRIVATE: WIZ_DPRIO_INPUT_B STRING "100"
-- Retrieval info: PRIVATE: WIZ_DPRIO_INPUT_B_UNIT STRING "MHz"
-- Retrieval info: PRIVATE: WIZ_DPRIO_INPUT_SELECTION NUMERIC "0"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK0_FREQ STRING "125"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK0_PROTOCOL STRING "GIGE"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK1_FREQ STRING "250"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK1_PROTOCOL STRING "Basic"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK2_FREQ STRING "250"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK2_PROTOCOL STRING "Basic"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK3_FREQ STRING "250"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK3_PROTOCOL STRING "Basic"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK4_FREQ STRING "250"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK4_PROTOCOL STRING "Basic"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK5_FREQ STRING "250"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK5_PROTOCOL STRING "Basic"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK6_FREQ STRING "250"
-- Retrieval info: PRIVATE: WIZ_DPRIO_REF_CLK6_PROTOCOL STRING "Basic"
-- Retrieval info: PRIVATE: WIZ_ENABLE_EQUALIZER_CTRL NUMERIC "0"
-- Retrieval info: PRIVATE: WIZ_EQUALIZER_CTRL_SETTING NUMERIC "0"
-- Retrieval info: PRIVATE: WIZ_FORCE_DEFAULT_SETTINGS NUMERIC "1"
-- Retrieval info: PRIVATE: WIZ_INCLK_FREQ STRING "125"
-- Retrieval info: PRIVATE: WIZ_INCLK_FREQ_ARRAY STRING "62.5 125"
-- Retrieval info: PRIVATE: WIZ_INPUT_A STRING "1250"
-- Retrieval info: PRIVATE: WIZ_INPUT_A_UNIT STRING "Mbps"
-- Retrieval info: PRIVATE: WIZ_INPUT_B STRING "125"
-- Retrieval info: PRIVATE: WIZ_INPUT_B_UNIT STRING "MHz"
-- Retrieval info: PRIVATE: WIZ_INPUT_SELECTION NUMERIC "0"
-- Retrieval info: PRIVATE: WIZ_PROTOCOL STRING "GIGE"
-- Retrieval info: PRIVATE: WIZ_RX_VCM STRING "0.85"
-- Retrieval info: PRIVATE: WIZ_SUBPROTOCOL STRING "GIGE-Enhanced"
-- Retrieval info: PRIVATE: WIZ_TX_VCM STRING "0.6"
-- Retrieval info: PRIVATE: WIZ_VCCHTX STRING "1.5"
-- Retrieval info: PRIVATE: WIZ_WORD_ALIGN_FLIP_PATTERN STRING "0"
-- Retrieval info: CONSTANT: CMU_PLL_INCLOCK_PERIOD NUMERIC "8000"
-- Retrieval info: CONSTANT: CMU_PLL_LOOP_FILTER_RESISTOR_CONTROL NUMERIC "3"
-- Retrieval info: CONSTANT: DIGITALRESET_PORT_WIDTH NUMERIC "1"
-- Retrieval info: CONSTANT: EN_LOCAL_CLK_DIV_CTRL STRING "true"
-- Retrieval info: CONSTANT: EQUALIZER_CTRL_A_SETTING NUMERIC "0"
-- Retrieval info: CONSTANT: EQUALIZER_CTRL_B_SETTING NUMERIC "0"
-- Retrieval info: CONSTANT: EQUALIZER_CTRL_C_SETTING NUMERIC "0"
-- Retrieval info: CONSTANT: EQUALIZER_CTRL_D_SETTING NUMERIC "0"
-- Retrieval info: CONSTANT: EQUALIZER_CTRL_V_SETTING NUMERIC "0"
-- Retrieval info: CONSTANT: EQUALIZER_DCGAIN_SETTING NUMERIC "0"
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Arria GX"
-- Retrieval info: CONSTANT: LOOPBACK_MODE STRING "none"
-- Retrieval info: CONSTANT: LPM_TYPE STRING "alt2gxb"
-- Retrieval info: CONSTANT: NUMBER_OF_CHANNELS NUMERIC "1"
-- Retrieval info: CONSTANT: OPERATION_MODE STRING "duplex"
-- Retrieval info: CONSTANT: PLL_LEGAL_MULTIPLIER_LIST STRING "disable_4_5_mult_above_3125"
-- Retrieval info: CONSTANT: PREEMPHASIS_CTRL_1STPOSTTAP_SETTING NUMERIC "0"
-- Retrieval info: CONSTANT: PREEMPHASIS_CTRL_2NDPOSTTAP_INV_SETTING STRING "false"
-- Retrieval info: CONSTANT: PREEMPHASIS_CTRL_2NDPOSTTAP_SETTING NUMERIC "0"
-- Retrieval info: CONSTANT: PREEMPHASIS_CTRL_PRETAP_INV_SETTING STRING "false"
-- Retrieval info: CONSTANT: PREEMPHASIS_CTRL_PRETAP_SETTING NUMERIC "0"
-- Retrieval info: CONSTANT: PROTOCOL STRING "gige"
-- Retrieval info: CONSTANT: RECEIVER_TERMINATION STRING "oct_100_ohms"
-- Retrieval info: CONSTANT: RECONFIG_DPRIO_MODE NUMERIC "0"
-- Retrieval info: CONSTANT: REVERSE_LOOPBACK_MODE STRING "none"
-- Retrieval info: CONSTANT: RX_8B_10B_COMPATIBILITY_MODE STRING "true"
-- Retrieval info: CONSTANT: RX_8B_10B_MODE STRING "normal"
-- Retrieval info: CONSTANT: RX_ALIGN_PATTERN STRING "1111100"
-- Retrieval info: CONSTANT: RX_ALIGN_PATTERN_LENGTH NUMERIC "7"
-- Retrieval info: CONSTANT: RX_ALLOW_ALIGN_POLARITY_INVERSION STRING "false"
-- Retrieval info: CONSTANT: RX_ALLOW_PIPE_POLARITY_INVERSION STRING "false"
-- Retrieval info: CONSTANT: RX_BANDWIDTH_MODE NUMERIC "1"
-- Retrieval info: CONSTANT: RX_BITSLIP_ENABLE STRING "false"
-- Retrieval info: CONSTANT: RX_BYTE_ORDERING_MODE STRING "none"
-- Retrieval info: CONSTANT: RX_CHANNEL_WIDTH NUMERIC "8"
-- Retrieval info: CONSTANT: RX_COMMON_MODE STRING "0.9v"
-- Retrieval info: CONSTANT: RX_CRU_INCLOCK_PERIOD NUMERIC "8000"
-- Retrieval info: CONSTANT: RX_CRU_PRE_DIVIDE_BY NUMERIC "1"
-- Retrieval info: CONSTANT: RX_DATAPATH_PROTOCOL STRING "basic"
-- Retrieval info: CONSTANT: RX_DATA_RATE NUMERIC "1250"
-- Retrieval info: CONSTANT: RX_DATA_RATE_REMAINDER NUMERIC "0"
-- Retrieval info: CONSTANT: RX_DISABLE_AUTO_IDLE_INSERTION STRING "true"
-- Retrieval info: CONSTANT: RX_ENABLE_BIT_REVERSAL STRING "false"
-- Retrieval info: CONSTANT: RX_ENABLE_LOCK_TO_DATA_SIG STRING "false"
-- Retrieval info: CONSTANT: RX_ENABLE_LOCK_TO_REFCLK_SIG STRING "false"
-- Retrieval info: CONSTANT: RX_ENABLE_SELF_TEST_MODE STRING "false"
-- Retrieval info: CONSTANT: RX_ENABLE_TRUE_COMPLEMENT_MATCH_IN_WORD_ALIGN STRING "false"
-- Retrieval info: CONSTANT: RX_FORCE_SIGNAL_DETECT STRING "true"
-- Retrieval info: CONSTANT: RX_PPMSELECT NUMERIC "32"
-- Retrieval info: CONSTANT: RX_RATE_MATCH_BACK_TO_BACK STRING "true"
-- Retrieval info: CONSTANT: RX_RATE_MATCH_FIFO_MODE STRING "normal"
-- Retrieval info: CONSTANT: RX_RATE_MATCH_ORDERED_SET_BASED STRING "true"
-- Retrieval info: CONSTANT: RX_RATE_MATCH_PATTERN1 STRING "10100010010101111100"
-- Retrieval info: CONSTANT: RX_RATE_MATCH_PATTERN2 STRING "10101011011010000011"
-- Retrieval info: CONSTANT: RX_RATE_MATCH_PATTERN_SIZE NUMERIC "20"
-- Retrieval info: CONSTANT: RX_RATE_MATCH_SKIP_SET_BASED STRING "true"
-- Retrieval info: CONSTANT: RX_RUN_LENGTH NUMERIC "5"
-- Retrieval info: CONSTANT: RX_RUN_LENGTH_ENABLE STRING "true"
-- Retrieval info: CONSTANT: RX_SIGNAL_DETECT_THRESHOLD NUMERIC "2"
-- Retrieval info: CONSTANT: RX_USE_ALIGN_STATE_MACHINE STRING "true"
-- Retrieval info: CONSTANT: RX_USE_CLKOUT STRING "false"
-- Retrieval info: CONSTANT: RX_USE_CORECLK STRING "false"
-- Retrieval info: CONSTANT: RX_USE_CRUCLK STRING "true"
-- Retrieval info: CONSTANT: RX_USE_DESERIALIZER_DOUBLE_DATA_MODE STRING "false"
-- Retrieval info: CONSTANT: RX_USE_DESKEW_FIFO STRING "false"
-- Retrieval info: CONSTANT: RX_USE_DOUBLE_DATA_MODE STRING "false"
-- Retrieval info: CONSTANT: RX_USE_RATE_MATCH_PATTERN1_ONLY STRING "false"
-- Retrieval info: CONSTANT: TRANSMITTER_TERMINATION STRING "oct_100_ohms"
-- Retrieval info: CONSTANT: TX_8B_10B_COMPATIBILITY_MODE STRING "true"
-- Retrieval info: CONSTANT: TX_8B_10B_MODE STRING "normal"
-- Retrieval info: CONSTANT: TX_ALLOW_POLARITY_INVERSION STRING "false"
-- Retrieval info: CONSTANT: TX_ANALOG_POWER STRING "1.5v"
-- Retrieval info: CONSTANT: TX_CHANNEL_WIDTH NUMERIC "8"
-- Retrieval info: CONSTANT: TX_COMMON_MODE STRING "0.6v"
-- Retrieval info: CONSTANT: TX_DATA_RATE NUMERIC "1250"
-- Retrieval info: CONSTANT: TX_DATA_RATE_REMAINDER NUMERIC "0"
-- Retrieval info: CONSTANT: TX_ENABLE_BIT_REVERSAL STRING "false"
-- Retrieval info: CONSTANT: TX_ENABLE_IDLE_SELECTION STRING "true"
-- Retrieval info: CONSTANT: TX_ENABLE_SELF_TEST_MODE STRING "false"
-- Retrieval info: CONSTANT: TX_REFCLK_DIVIDE_BY NUMERIC "1"
-- Retrieval info: CONSTANT: TX_TRANSMIT_PROTOCOL STRING "basic"
-- Retrieval info: CONSTANT: TX_USE_CORECLK STRING "false"
-- Retrieval info: CONSTANT: TX_USE_DOUBLE_DATA_MODE STRING "false"
-- Retrieval info: CONSTANT: TX_USE_SERIALIZER_DOUBLE_DATA_MODE STRING "false"
-- Retrieval info: CONSTANT: USE_CALIBRATION_BLOCK STRING "true"
-- Retrieval info: CONSTANT: VOD_CTRL_SETTING NUMERIC "3"
-- Retrieval info: USED_PORT: cal_blk_clk 0 0 0 0 INPUT NODEFVAL "cal_blk_clk"
-- Retrieval info: USED_PORT: gxb_powerdown 0 0 1 0 INPUT NODEFVAL "gxb_powerdown[0..0]"
-- Retrieval info: USED_PORT: pll_inclk 0 0 0 0 INPUT NODEFVAL "pll_inclk"
-- Retrieval info: USED_PORT: rx_analogreset 0 0 1 0 INPUT NODEFVAL "rx_analogreset[0..0]"
-- Retrieval info: USED_PORT: rx_cruclk 0 0 1 0 INPUT GND "rx_cruclk[0..0]"
-- Retrieval info: USED_PORT: rx_ctrldetect 0 0 1 0 OUTPUT NODEFVAL "rx_ctrldetect[0..0]"
-- Retrieval info: USED_PORT: rx_datain 0 0 1 0 INPUT NODEFVAL "rx_datain[0..0]"
-- Retrieval info: USED_PORT: rx_dataout 0 0 8 0 OUTPUT NODEFVAL "rx_dataout[7..0]"
-- Retrieval info: USED_PORT: rx_digitalreset 0 0 1 0 INPUT NODEFVAL "rx_digitalreset[0..0]"
-- Retrieval info: USED_PORT: rx_disperr 0 0 1 0 OUTPUT NODEFVAL "rx_disperr[0..0]"
-- Retrieval info: USED_PORT: rx_errdetect 0 0 1 0 OUTPUT NODEFVAL "rx_errdetect[0..0]"
-- Retrieval info: USED_PORT: rx_patterndetect 0 0 1 0 OUTPUT NODEFVAL "rx_patterndetect[0..0]"
-- Retrieval info: USED_PORT: rx_rlv 0 0 1 0 OUTPUT NODEFVAL "rx_rlv[0..0]"
-- Retrieval info: USED_PORT: rx_rmfifodatadeleted 0 0 1 0 OUTPUT NODEFVAL "rx_rmfifodatadeleted[0..0]"
-- Retrieval info: USED_PORT: rx_rmfifodatainserted 0 0 1 0 OUTPUT NODEFVAL "rx_rmfifodatainserted[0..0]"
-- Retrieval info: USED_PORT: rx_runningdisp 0 0 1 0 OUTPUT NODEFVAL "rx_runningdisp[0..0]"
-- Retrieval info: USED_PORT: rx_syncstatus 0 0 1 0 OUTPUT NODEFVAL "rx_syncstatus[0..0]"
-- Retrieval info: USED_PORT: tx_clkout 0 0 1 0 OUTPUT NODEFVAL "tx_clkout[0..0]"
-- Retrieval info: USED_PORT: tx_ctrlenable 0 0 1 0 INPUT NODEFVAL "tx_ctrlenable[0..0]"
-- Retrieval info: USED_PORT: tx_datain 0 0 8 0 INPUT NODEFVAL "tx_datain[7..0]"
-- Retrieval info: USED_PORT: tx_dataout 0 0 1 0 OUTPUT NODEFVAL "tx_dataout[0..0]"
-- Retrieval info: USED_PORT: tx_digitalreset 0 0 1 0 INPUT NODEFVAL "tx_digitalreset[0..0]"
-- Retrieval info: CONNECT: rx_patterndetect 0 0 1 0 @rx_patterndetect 0 0 1 0
-- Retrieval info: CONNECT: @rx_analogreset 0 0 1 0 rx_analogreset 0 0 1 0
-- Retrieval info: CONNECT: rx_ctrldetect 0 0 1 0 @rx_ctrldetect 0 0 1 0
-- Retrieval info: CONNECT: @gxb_powerdown 0 0 1 0 gxb_powerdown 0 0 1 0
-- Retrieval info: CONNECT: rx_dataout 0 0 8 0 @rx_dataout 0 0 8 0
-- Retrieval info: CONNECT: rx_runningdisp 0 0 1 0 @rx_runningdisp 0 0 1 0
-- Retrieval info: CONNECT: @cal_blk_clk 0 0 0 0 cal_blk_clk 0 0 0 0
-- Retrieval info: CONNECT: rx_errdetect 0 0 1 0 @rx_errdetect 0 0 1 0
-- Retrieval info: CONNECT: @tx_digitalreset 0 0 1 0 tx_digitalreset 0 0 1 0
-- Retrieval info: CONNECT: rx_syncstatus 0 0 1 0 @rx_syncstatus 0 0 1 0
-- Retrieval info: CONNECT: @rx_digitalreset 0 0 1 0 rx_digitalreset 0 0 1 0
-- Retrieval info: CONNECT: tx_clkout 0 0 1 0 @tx_clkout 0 0 1 0
-- Retrieval info: CONNECT: @rx_cruclk 0 0 1 0 rx_cruclk 0 0 1 0
-- Retrieval info: CONNECT: rx_rlv 0 0 1 0 @rx_rlv 0 0 1 0
-- Retrieval info: CONNECT: @pll_inclk 0 0 0 0 pll_inclk 0 0 0 0
-- Retrieval info: CONNECT: @tx_ctrlenable 0 0 1 0 tx_ctrlenable 0 0 1 0
-- Retrieval info: CONNECT: tx_dataout 0 0 1 0 @tx_dataout 0 0 1 0
-- Retrieval info: CONNECT: @tx_datain 0 0 8 0 tx_datain 0 0 8 0
-- Retrieval info: CONNECT: @rx_datain 0 0 1 0 rx_datain 0 0 1 0
-- Retrieval info: CONNECT: rx_rmfifodatainserted 0 0 1 0 @rx_rmfifodatainserted 0 0 1 0
-- Retrieval info: CONNECT: rx_rmfifodatadeleted 0 0 1 0 @rx_rmfifodatadeleted 0 0 1 0
-- Retrieval info: CONNECT: rx_disperr 0 0 1 0 @rx_disperr 0 0 1 0
-- Retrieval info: GEN_FILE: TYPE_NORMAL SGMII_GX_Transceiver.vhd TRUE FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL SGMII_GX_Transceiver.ppf TRUE FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL SGMII_GX_Transceiver.inc FALSE FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL SGMII_GX_Transceiver.cmp TRUE FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL SGMII_GX_Transceiver.bsf TRUE FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL SGMII_GX_Transceiver_inst.vhd TRUE FALSE
