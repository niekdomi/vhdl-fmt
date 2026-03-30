--------------------------------------------------------------------------------
--  max2_logic
--------------------------------------------------------------------------------
--
--  project     : max2
--  programmer  : c. leuthold, INDEL AG
--  date        : 28.07.2005
--  version     : 1.00
--  language    : VHDL
--  system      : ispLever 3.0
--
--  purpose
--
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--  Rev. 1.00a  :   28.07.2005-le  : - disc.
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- includes
--------------------------------------------------------------------------------
library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.ALL;
--------------------------------------------------------------------------------
-- defines
--------------------------------------------------------------------------------
entity max2_logic is
	generic (
		C_NUM_OF_OVERRANGES : integer := 4
	);
	port (
		i_Clk			: in std_logic;			-- clock input
		i_Reset			: in std_logic;			-- reset input L-active
		-- SAC Register interface ----------------------------------------------
		-- triggers outputs _-_
		o_cADCx0  		: out	std_logic;
		o_cADCx1  		: out	std_logic;
		o_cEncoder		: out	std_logic;
		o_cMC			: out	std_logic;
		o_cMC180		: out	std_logic;
		-- ADS8361 interface ---------------------------------------------------
		i_data_ready	: in	std_logic;
		o_next_Channel	: out	std_logic;
		o_start_conv	: out	std_logic;
		o_conv_0_n_180	: out	std_logic;
		i_ADC_on		: in	std_logic;
		o_ADC_cs		: out	std_logic;
		-- PWM interface -------------------------------------------------------
		i_convSt		: in	std_logic;
		i_convSt180		: in	std_logic;
		i_convSt2		: in	std_logic;
		i_convSt2180	: in	std_logic;
		-- register ------------------------------------------------------------
		i_Flags			: in	std_logic_vector(31 downto 0);
		i_RESflg		: in	std_logic_vector(31 downto 0);
		o_Status		: out	std_logic_vector(31 downto 0);
		-- IOs -----------------------------------------------------------------
		-- OUT
		o_EnDataO		: out	std_logic;
		o_bridge_en		: out	std_logic_vector(2 downto 0);
		o_DAC_continuous: out	std_logic;
		-- IN
		ni_ext_board_mtd : in	std_logic;
		ni_err_bridge	: in	std_logic_vector(2 downto 0);
		ni_err_break	: in	std_logic;
		ni_err_pwm		: in	std_logic_vector(1 downto 0);
		ni_overrange	: in	std_logic_vector(C_NUM_OF_OVERRANGES-1 downto 0);
		i_Enc_a			: in	std_logic_vector(3 downto 0);
		i_Enc_b			: in	std_logic_vector(3 downto 0);
		i_Enc_ref		: in	std_logic_vector(3 downto 0);
		-- watchdogs
		i_EXT_Wdog		: in	std_logic;
		i_SPWM_Wdog		: in	std_logic;
		i_OUTS_Wdog		: in	std_logic;
		i_DAC_Wdog		: in	std_logic;
		i_IL_Wdog		: in	std_logic;
		i_PWM_Wdog		: in	std_logic
	);
end;													-- of entity max2_logic

architecture behavior_max2_logic of max2_logic is
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
	constant H			: std_logic := '1';
	constant L			: std_logic := '0';
	constant Z			: std_logic := 'Z';

	-- flags bit nr.
	constant MAX2_BRIDGE_EN_0	: integer := 0;
	constant MAX2_BRIDGE_EN_1	: integer := 1;
	constant MAX2_BRIDGE_EN_2	: integer := 2;
	constant FLG0		: integer := 16 + 0;
	constant FLG1		: integer := 16 + 1;
	constant FLG2		: integer := 16 + 2;
	constant FLG3		: integer := 16 + 3;
	constant FLG4		: integer := 16 + 4;
	constant FLG5		: integer := 16 + 5;
	constant FLG6		: integer := 16 + 6;
	constant FLG7		: integer := 16 + 7;
	constant LED0		: integer := 16 + 8;
	constant LED1		: integer := 16 + 9;
	constant LED2		: integer := 16 + 10;
	constant LED3		: integer := 16 + 11;
	constant LED4		: integer := 16 + 12;
	constant LED5		: integer := 16 + 13;
	constant LED6		: integer := 16 + 14;
	constant LED7		: integer := 16 + 15;
	-- RESflg bit nr.
	constant RESNP		: integer := 16 + 3;
	constant LSEN		: integer := 16 + 4;
	constant PERR		: integer := 16 + 12;
	constant FAN		: integer := 16 + 13;
	constant REL		: integer := 16 + 14;
	constant BRE		: integer := 16 + 15;
	constant OUT_EN		: integer := 15;
	constant ADC180OFF	: integer := 14;
	constant ADCALT		: integer := 13;
	constant DAC_CONT	: integer := 12;
	-- status bit nr.
	constant PWM		: integer := 0; -- watchdog
	constant EXT		: integer := 1; -- watchdog
	constant SPWM		: integer := 2; -- watchdog
	constant OUTS		: integer := 3; -- watchdog
	constant DAC		: integer := 4; -- watchdog
	constant ER_OV0		: integer := 5; -- overcurrent
	constant ER_OV1		: integer := 6; -- overcurrent
	constant ER_OV2		: integer := 7; -- overcurrent
	constant ER_OV3		: integer := 8; -- overcurrent
	constant ER_B0		: integer := 9; -- bridge error
	constant ER_B1		: integer := 10;-- bridge error
	constant ER_B2		: integer := 11;-- bridge error
	constant ER_BR		: integer := 12;-- fet error
	constant ER_PWM0	: integer := 13;-- fet error
	constant ER_PWM1	: integer := 14;-- fet error
	constant EXT_BOARD	: integer := 15;

	constant REF0		: integer := 16 + 0;
	constant REF1		: integer := 16 + 1;
	constant REF2		: integer := 16 + 2;
	constant REF3		: integer := 16 + 3;
	constant ENCA0		: integer := 16 + 4;
	constant ENCA1		: integer := 16 + 5;
	constant ENCA2		: integer := 16 + 6;
	constant ENCA3		: integer := 16 + 7;
	constant ENCB0		: integer := 16 + 8;
	constant ENCB1		: integer := 16 + 9;
	constant ENCB2		: integer := 16 + 10;
	constant ENCB3		: integer := 16 + 11;
	constant WDOG		: integer := 16 + 12;
	constant AUS		: integer := 16 + 13;
	constant KURZ		: integer := 16 + 14;
	constant STP		: integer := 16 + 15;

	constant SSI		: integer := 1;
	constant RS485		: integer := 2;
	constant RS422		: integer := 3;
-- types -----------------------------------------------------------------------
-- signals ---------------------------------------------------------------------
-- flags
	signal off				: std_logic := H;   -- AUS
	signal shorty			: std_logic := L;   -- KURZ
	signal Stop				: std_logic;        -- STOP
	signal PWM_brake		: std_logic := L;   -- Bre

	-- adc
	signal next_Channel		: std_logic := L;
	-- triggers
	signal data_ready_old 	: std_logic := L;
	-- inc
	signal Inc_sync			: std_logic := L;
	signal res_zero_p		: std_logic := L;
	signal Inp1old			: std_logic := L;

	signal shorty_b			: std_logic_vector(C_NUM_OF_OVERRANGES-1 downto 0) := (others => L);

-- functons ----------------------------------------------------------------
	FUNCTION vector_or ( inputs : std_logic_vector )
	RETURN std_logic IS
	CONSTANT floatvalue : std_logic := '0' ;
	BEGIN
	IF inputs'Length = 0 THEN
		RETURN floatvalue ;
	ELSE
		FOR i IN inputs'Range LOOP
			IF inputs(i) = '1' THEN
				RETURN '1' ;
			END IF ;
		END LOOP ;
		RETURN '0' ;
	END IF ;
	END ;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin												-- of architecture max2_logic
	o_EnDataO <= i_RESflg(OUT_EN);
	o_DAC_continuous <= i_RESflg(DAC_CONT);
-- flags -----------------------------------------------------------------------
	Stop <= not(i_Flags(FLG7)) or shorty or off;
	o_bridge_en(0) <= i_Flags(FLG7) and i_Flags(MAX2_BRIDGE_EN_0) and not i_PWM_Wdog;--and not (off);-- or shorty_b(0));
	o_bridge_en(1) <= i_Flags(FLG7) and i_Flags(MAX2_BRIDGE_EN_1) and not i_PWM_Wdog;--and not (off);-- or shorty_b(1) or shorty_b(2));
	o_bridge_en(2) <= i_Flags(FLG7) and i_Flags(MAX2_BRIDGE_EN_2) and not i_PWM_Wdog;--and not (off);-- or shorty_b(3));


	process (i_Clk)
	begin
		if rising_edge(i_Clk) then
			off <= i_PWM_Wdog
				or	(off and not(i_Flags(FLG3)));

			shorty <= (shorty and not(i_Flags(FLG3)))
					or	(vector_or(ni_overrange));

			for i in 0 to C_NUM_OF_OVERRANGES-1 loop
				shorty_b(i) <= (shorty_b(i) and not i_Flags(FLG3))
						or	(not ni_overrange(i));
			end loop;
		end if;
	end process;
-- status ----------------------------------------------------------------------

	o_Status(REF0 ) <= i_Enc_ref(0);
	o_Status(REF1 ) <= i_Enc_ref(1);
	o_Status(REF2 ) <= i_Enc_ref(2);
	o_Status(REF3 ) <= i_Enc_ref(3);
	o_Status(ENCA0) <= i_Enc_a(0);
	o_Status(ENCA1) <= i_Enc_a(1);
	o_Status(ENCA2) <= i_Enc_a(2);
	o_Status(ENCA3) <= i_Enc_a(3);
	o_Status(ENCB0) <= i_Enc_b(0);
	o_Status(ENCB1) <= i_Enc_b(1);
	o_Status(ENCB2) <= i_Enc_b(2);
	o_Status(ENCB3) <= i_Enc_b(3);
	o_Status(WDOG ) <= i_IL_Wdog;
	o_Status(AUS  ) <= off;
	o_Status(KURZ ) <= shorty;
	o_Status(STP  ) <= Stop;

	o_Status(PWM		) <= i_PWM_Wdog;
	o_Status(EXT		) <= i_EXT_Wdog;
	o_Status(SPWM		) <= i_SPWM_Wdog;
	o_Status(OUTS		) <= i_OUTS_Wdog;
	o_Status(DAC		) <= i_DAC_Wdog;
	o_Status(ER_OV0		) <= shorty_b(0);
	o_Status(ER_OV1		) <= shorty_b(1);
	o_Status(ER_OV2		) <= shorty_b(2);
	o_Status(ER_OV3		) <= shorty_b(3);
	o_Status(ER_B0		) <= not ni_err_bridge(0);
	o_Status(ER_B1		) <= not ni_err_bridge(1);
	o_Status(ER_B2		) <= not ni_err_bridge(2);
	o_Status(ER_BR		) <= not ni_err_break;
	o_Status(ER_PWM0	) <= not ni_err_pwm(0);
	o_Status(ER_PWM1	) <= not ni_err_pwm(1);
	o_Status(EXT_BOARD	) <= not ni_ext_board_mtd;

	
	
	
	
	
	
	
	
	
	

-- triggers --------------------------------------------------------------------
	o_cEncoder <= i_convSt;
	o_ADC_cs <= not i_ADC_on;
	o_cMC <= i_convSt2 and i_ADC_on;
	o_cMC180 <= i_convSt2180 and i_ADC_on;
	-- adc ---------------------------------------------------------------------
	o_next_Channel	<= next_Channel;
	triggers : process (i_Clk)
	begin
		if (i_Reset=H) then
			o_cADCx0 <= L;
			o_cADCx1 <= L;
			data_ready_old <= i_data_ready;
			o_start_conv <= L;
			o_cADCx0 <= L;
			o_cADCx1 <= L;
		elsif rising_edge(i_Clk) then
		-- clocked statements
			o_cADCx0 <= L;
			o_cADCx1 <= L;
			data_ready_old <= i_data_ready;
--			if (i_RESflg(ADCALT)=H) then
				o_start_conv <= L;
				if (i_convSt=H) then
					o_conv_0_n_180 <= H;
					next_Channel <= H;
					o_start_conv <= H;
				end if;
				if (i_convSt180=H) then
					o_conv_0_n_180 <= L;
					next_Channel <= L;
					o_start_conv <= H;
				end if;
				if i_data_ready=H and data_ready_old=L then
					if next_Channel=H then
						o_cADCx0 <= i_ADC_on;
					else
						o_cADCx1 <= i_ADC_on;
					end if;
				end if;
--			elsif (i_RESflg(ADC180OFF)=H) then
--				if (i_convSt=H) then
--					o_conv_0_n_180 <= H;
--					next_Channel <= H;
--					o_start_conv <= H;
--				end if;
--				if i_data_ready=H and data_ready_old=L then
--					if next_Channel=H then
--						o_cADCx0 <= i_ADC_on;
--						next_Channel <= L;
--					else
--						o_cADCx1 <= i_ADC_on;
--						next_Channel <= H;
--						o_start_conv <= L;
--					end if;
--				end if;
--			else
--				if (i_convSt=H) then
--					o_conv_0_n_180 <= H;
--					next_Channel <= H;
--					o_start_conv <= H;
--				end if;
--				if (i_convSt180=H) then
--					o_conv_0_n_180 <= L;
--					next_Channel <= H;
--					o_start_conv <= H;
--				end if;
--				if i_data_ready=H and data_ready_old=L then
--					if next_Channel=H then
--						o_cADCx0 <= i_ADC_on;
--						next_Channel <= L;
--					else
--						o_cADCx1 <= i_ADC_on;
--						next_Channel <= H;
--						o_start_conv <= L;
--					end if;
--				end if;
--			end if;
		end if;
	end process triggers;

end behavior_max2_logic;
--------------------------------------------------------------------------------

