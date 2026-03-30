--------------------------------------------------------------------------------
--	valve controller
--------------------------------------------------------------------------------
--
--	project     :
--	programmer  : Christof Leuthold, INDEL AG
--	date        : 24.06.2019
--	version     : 1.00
--	language    : VHDL
--
--	purpose
--	R: -128..128 Ohm signed hh.hh
--	kP: -128..128 signed hh.hh
--	Iact: -8..8 A signed h.hhh
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	24.06.2019-le	: - start
--	12.11.2020-le	: - add C_DOT_U
--					  - limit Uo to avoid ovverruns
--					  - adjust Ton counter
--	29.03.2021-le	: - valve_ctrl: add reset 	 
--------------------------------------------------------------------------------
--$Rev:: 4926                                                                  $
--$Author:: Leuthold                                                           $
--$Date:: 2018-06-29 13:03:27 +0200 (Fr., 29 Jun 2018)                         $
--------------------------------------------------------------------------------

library ieee;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

library division;
use division.division;

entity valve_ctrl is
	generic (
		C_REG_LENGTH		: integer range 8 to 18 := 12;
		C_ENpPWM			: integer range 1 to 20 := 10;
		C_TICKSpEN			: integer := 100;--
		C_DT 				: natural := 20; -- in Ticks
		C_FIXUCC			: integer range 0 to 120 := 24;-- 0 calculate from i_Ucc: >0 use this value
		C_PWMHALF			: integer range 0 to 1 := 1;
		C_DOT 				: natural := 4; -- R, kP, Gain
		C_DOT_U				: natural := 6; -- U
		C_DOT_I				: natural := 8; -- Ired, Imax, Iact
		C_PWM_SIM			: natural := 0 -- for simulation! >0 override the PWMfrequency for faster simulaton cycles of the calculations
	);
	port (
		i_Clk		: in	std_logic;				-- clock input
		i_reset		: in	std_logic;
		i_loop_en	: in	std_logic;
		i_pulse_en	: in	std_logic;
		i_Flags		: in	std_logic_vector(1 downto 0) := (others => L);
		-- pulse cfg
		i_IcmdMax	: in	std_logic_vector(C_REG_LENGTH-1 downto 0);
		i_IcmdRed	: in	std_logic_vector(C_REG_LENGTH-1 downto 0);
		i_TIMax		: in	std_logic_vector(C_REG_LENGTH-1 downto 0);
		i_off		: in	std_logic_vector(C_REG_LENGTH-1 downto 0);
		-- ctrl
		i_Iact		: in	std_logic_vector(C_REG_LENGTH-1 downto 0);
		i_Igain		: in	std_logic_vector(C_REG_LENGTH-1 downto 0);
		i_R			: in	std_logic_vector(C_REG_LENGTH-1 downto 0);
		i_kP		: in	std_logic_vector(C_REG_LENGTH-1 downto 0);
		i_Ucc		: in	std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => L);
		o_p			: out	std_logic;
		o_n			: out	std_logic;
		o_disable	: out	std_logic;
		o_Error		: out	std_logic;
		-- logging
		o_log_en	: out	std_logic;
		o_Iact		: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		o_Ierr		: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		o_Iact0		: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		o_Ierr0		: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		o_Ierrf		: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		o_Icmd		: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		o_Uout		: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		o_pwm 		: out	std_logic_vector(C_REG_LENGTH-1 downto 0);
		o_Status 	: out	std_logic_vector(15 downto 0);
		o_Ton		: out	std_logic_vector(C_REG_LENGTH-1 downto 0)
	);
end;

architecture behavior_valve_ctrl of valve_ctrl is
-- component declarations ------------------------------------------------------
-- constants -------------------------------------------------------------------
	signal Ierr_max : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	constant Icmd0 : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	constant n : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal gnd : std_logic_vector(C_REG_LENGTH-1 downto 0) := (others => L);
	constant PWMTICKS : natural := (C_TICKSpEN*C_ENpPWM)/2;
	constant PWM100 : signed(C_REG_LENGTH-1 downto 0) := to_signed(PWMTICKS,C_REG_LENGTH);
	constant PWM50 : signed(C_REG_LENGTH-1 downto 0) := to_signed(PWMTICKS/2,C_REG_LENGTH);

	constant DOT_U : integer := C_DOT_U;
	constant DOT_R : integer := C_DOT;
	constant DOT_K : integer := C_DOT;
	constant DOT_G : integer := C_DOT;
	constant DOT_I : integer := C_DOT_I;
	constant UCC_MIN : natural := 12*2**DOT_U; --12Volt
	-- calc the best resolutoin for U2PWM
	constant DOT_N : integer := integer(Log(real(UCC_MIN)*(2.00**(C_REG_LENGTH-1)-1.0)/real(PWMTICKS/2))/log(2.0));

-- types -----------------------------------------------------------------------
	type t_pulse_states is (stoped,start,imax,to_red,ired,to_zero,zero);
	type t_calc_states is (sIdle,sUout,sSM,sPWM);
-- signals ---------------------------------------------------------------------
	signal pulse_state : t_pulse_states := start;
	signal calc_state : t_calc_states := sIdle;
	signal PwmCyc : unsigned(4 downto 0) := (others => L);
	signal off : unsigned(4 downto 0) := (others => L);
	signal zcnt : unsigned(off'range) := (others => L);
	signal TIMax : unsigned(C_REG_LENGTH-1 downto 0) := (others => L);
	signal pwm_cnt : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal Ierr : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal IerrOld : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal IerrDelta : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal IcmdMax : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal IcmdRed : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal Iact : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal Uout : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal pwm : signed(C_REG_LENGTH-1 downto 0) := PWM50;
	signal R : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal kP : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal U2PWM : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal Icmd : signed(C_REG_LENGTH-1 downto 0) := (others => L);

	signal a : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal b : signed(C_REG_LENGTH-1 downto 0) := (others => L);
	signal cm : signed(C_REG_LENGTH*2-2 downto 0) := (others => L);
	signal mac : signed(C_REG_LENGTH*2-1 downto 0) := (others => L);

	signal pulse_en_1 : std_logic := L;
	signal pwm_reset : std_logic := L;
	signal pwm_reset_req : std_logic := L;
	signal down : std_logic := L;
	signal PWM_min : std_logic := L;
	signal PWM_max : std_logic := L;
	signal PWM_off : std_logic := L;
	signal pwm_disable : std_logic := L;

	-- pos shift shiftleft, neg shift shift right
	function sh(val : signed; s: integer) return signed is
	variable ret : signed(val'range);
	variable shr : integer:=0-s;
	begin
		if s>=0 then
			ret := (others => L);
			ret(val'high) := val(val'high);
			for i in s to val'high-1 loop
				ret(i) := val(i-s);
			end loop;
		else
			ret := (others => val(val'high));
			ret(val'high) := val(val'high);
			for i in 0 to val'high-1-shr loop
				ret(i) := val(i+shr);
			end loop;
		end if;
		return ret;
	end function sh;

	function shRes(val : signed; s, lng : integer) return signed is
	begin
		if s>=0 then
			return val(val'high)&val(val'high-1-s downto val'high-1-s-lng+2);
		else
			return sh(val,s)((val'high) downto val'high-lng+1);
		end if;
	end function shRes;

	function dotsh(lng,dot1,dot2,dotneu : natural) return integer is
	begin
		return 2*lng-(dot1+dot2)-(lng-dotneu);
	end function dotsh;

	function limSub(a,b : signed) return signed is
	variable r : signed(a'length downto 0);
	variable smin : signed(a'length downto 0);
	variable smax : signed(a'length downto 0);
	variable res : signed(a'length-1 downto 0);
	begin
		smin := (others => L);
		smin(a'length) := H;
		smin(a'length-1) := H;
		smax := (others => H);
		smax(a'length) := L;
		smax(a'length-1) := L;
		r := resize(a,a'length+1)-resize(b,b'length+1);--(a(a'high)&a)-(b(b'high)&b);
		if r>smax then
			r := smax;
		elsif r<smin then
			r := smin;
		end if;
		return r(r'high-1 downto 0);
	end function limSub;

	-- for simulation:
-- synthesis translate_off
	signal rIerr : real := 0.0;
	signal rIcmd : real := 0.0;
	signal rIact : real := 0.0;
	signal rUout : real := 0.0;
	signal rUcc : real := 0.0;
	signal rU2PWM : real := 0.0;
	signal rIgain : real := 0.0;
-- synthesis translate_on

	constant DF_NO2RED : integer := 0;
	constant DF_NO2MAX : integer := 1;

	signal Error : std_logic := L;
	signal IcSt : std_logic_vector(1 downto 0) := (others => L);

	signal Ton : unsigned(C_REG_LENGTH-1 downto 0) := (others => L);
	
	signal sim_RxI : signed(C_REG_LENGTH*2-2 downto 0) := (others => L);
	signal sim_Uout : signed(C_REG_LENGTH*2-1 downto 0) := (others => L);
	signal sim_PWM : signed(C_REG_LENGTH*2-1 downto 0) := (others => L);
	signal overrun : std_logic := L;
-- Attribute declaration -------------------------------------------------------
--------------------------------------------------------------------------------
-- implementation
--------------------------------------------------------------------------------
begin												-- of architecture
	IcmdMax		<= signed(i_IcmdMax);
	IcmdRed		<= signed(i_IcmdRed);
	R			<= signed(i_R);
	kP			<= signed(i_kP);
	off			<= unsigned(i_off(off'high downto 0));

	o_disable <= pwm_disable;
	o_Error <= Error;
	-- for simulation:
-- synthesis translate_off
	rIerr <= real(to_integer(Ierr))/(2.0**DOT_I);
	rIcmd <= real(to_integer(Icmd))/(2.0**DOT_I);
	rIact <= real(to_integer(Iact))/(2.0**DOT_I);
	rUout <= real(to_integer(Uout))/2.0**DOT_U;
	rUcc <= real(to_integer(signed(i_Ucc)))/2.0**DOT_U;
	rU2PWM <= real(to_integer(signed(U2PWM)))/2.0**(DOT_N-1);
	rIgain <= real(to_integer(signed(i_Igain)))/2.0**(DOT_G);
-- synthesis translate_on

	--  U2PWM = PWM50*2^(DOT_N)/(ucc_in_v*2^DOT_U)
	fix_U2PWM: if C_FIXUCC/=0 generate
	constant UCC_in_V : real := real(C_FIXUCC);
	begin
		U2PWM <= to_signed(integer(real(to_integer(PWM100))/2.0*2.0**(DOT_N)/(UCC_in_V*2.0**DOT_U)),C_REG_LENGTH);
	end generate fix_U2PWM;
	calc_U2PWM: if C_FIXUCC=0 generate
	signal o : std_logic_vector(C_REG_LENGTH+DOT_N-1 downto 0) := (others => L);
	signal p : std_logic_vector(C_REG_LENGTH+DOT_N-1 downto 0) := (others => L);
	signal u : std_logic_vector(C_REG_LENGTH+DOT_N-1 downto 0) := (others => L);
	begin
		p(C_REG_LENGTH+DOT_N-2 downto DOT_N-1) <= std_logic_vector(PWM100); --PWM100>>1
		u(C_REG_LENGTH-1 downto 0) <= i_Ucc when signed(i_Ucc)>UCC_MIN else std_logic_vector(to_unsigned(UCC_MIN,C_REG_LENGTH));
		i_division : entity division.division
		generic map (
			SIZE => C_REG_LENGTH+DOT_N,
			C_SIGNED => 1
		)
		port map (
			clk		=> i_Clk,
			Start	=> pwm_reset,
			num		=> p,
			den		=> u,
			res		=> o
		);
		U2PWM <= shRes(signed(o),DOT_N,C_REG_LENGTH);
	end generate calc_U2PWM;

	Ierr_max <= sh(IcmdMax,-4);
	
	mac <= a*b+cm;

	process (i_Clk)
	variable Uo : signed(C_REG_LENGTH-1 downto 0);
	variable Ic : signed(C_REG_LENGTH-1 downto 0);
	variable vpwm : signed(C_REG_LENGTH-1 downto 0);
	begin
		if rising_edge(i_Clk) then
			o_log_en <= L;
			a <= signed(i_Iact);--.xxxx
			b <= signed(i_Igain); --xx.xx
			cm <= (others => L);
			case calc_state is
			when sIdle =>
				Iact <= shRes(mac,dotsh(C_REG_LENGTH,C_REG_LENGTH-1,DOT_G,DOT_I),C_REG_LENGTH);
				if (i_loop_en=H) then
					-- puls and ierr calculation
					pulse_en_1 <= i_pulse_en;
					PwmCyc <= PwmCyc+1; --cyclecounter
					if (TIMax/=0 and i_pulse_en=H) or (i_pulse_en=H and pulse_en_1=L) then
						TIMax <= TIMax-1;
						Ic := IcmdMax;
						IcSt <= "10";
					else
						if (i_pulse_en=H) then
							Ic := IcmdRed;
							IcSt <= "01";
						else
							Ic := Icmd0;
							IcSt <= "00";
						end if;
					end if;
					-- start a new puls
					if (i_pulse_en=H and pulse_en_1=L) then
						TIMax <= unsigned(i_TIMax);
						IerrOld <= IcmdMax;
						Ton <= (others => L);
						o_Ton <= (others => L);
						PwmCyc <= (others => L);
						pulse_state <= start;
						pwm_reset <= H;
					end if;
					-- pwm to loop ctrl
					if PwmCyc=C_ENpPWM-1 then
						PwmCyc <= (others => L);
						pwm_reset <= H;
					end if;
					--Ierr=Ic-Iact
					Ierr <= limSub(Ic,Iact);
					calc_state <= sUout;
					Icmd <= Ic;
					a <= Ic;--x.xxx
					b <= R; --xx.xx
					cm <= (others => L);
				end if;
			when sUout =>
				--xxx.xxxxx => xx.xx dotIC 12 dotR 8 dotUx 8
				-- calc Uout = R*Icmd+(kP*Ierr);
				calc_state <= sSM;
				a <= Ierr;
				b <= kP;
				cm <= shRes(mac,1,cm'length);
				sim_RxI <= shRes(mac,1,cm'length);
		--		if (signed(abs(Ierr))>signed(abs(Ierr_max))) then
		--			Error <= H;
		--		else
		--			Error <= L;
		--		end if;
			when sSM =>
				PWM_max <= L;
				PWM_min <= L;
				PWM_off <= L;
				pwm_reset_req <= L;
				--x.xxx * xx.xx = xxx.xxxxx => xx.xx dotIerr 12 dotKP 8 dotUx 8
				sim_Uout <= mac;
				Uo := shRes(mac,dotsh(C_REG_LENGTH,DOT_I,DOT_K,DOT_U),C_REG_LENGTH);
				if (mac(mac'high downto mac'high-dotsh(C_REG_LENGTH,DOT_I,DOT_K,DOT_U))/=0) then
					if (mac(mac'high downto mac'high-dotsh(C_REG_LENGTH,DOT_I,DOT_K,DOT_U))=-1) then
						overrun <= L;
					else
						if (mac(mac'high)=L) then
							Uo := (L, others => H); -- pos max
						else
							Uo := (H, others => L); -- neg max
						end if;
						overrun <= H;
					end if;
				else
					overrun <= L;
				end if;
				
				-- pulse state
				case pulse_state is
				when stoped =>
					PWM_off <= H;
					pwm_disable <= L;
				when start =>
					pwm_disable <= L;
					if ((Ierr>IerrDelta) and i_Flags(DF_NO2MAX)=L) then
						PWM_max <= H;
						Ton <= Ton+1;
					else
						pwm_reset <= H;
						o_Ton <= std_logic_vector(Ton);
						pulse_state <= imax;
					end if;
					if (pulse_en_1=L) then
						pulse_state <= to_zero;
						pwm_reset_req <= H;
					end if;
				when imax =>
					if TIMax=0 then
						if (i_Flags(DF_NO2RED)=L) then
							pulse_state <= to_red;
						else
							pulse_state <= ired;
						end if;
						pwm_reset_req <= H;
					end if;
					if (pulse_en_1=L) then
						pulse_state <= to_zero;
						pwm_reset_req <= H;
					else
						if ((i_Flags(DF_NO2MAX)=H)) then
							if (Ierr>Ierr_max) then
								Ton <= Ton+1;
							else
								o_Ton <= std_logic_vector(Ton);
							end if;
						end if;
					end if;
				when to_red =>
					if (Ierr<(-Ierr_max)) then
						PWM_min <= H;
					else
						pwm_reset <= H;
						pulse_state <= ired;
					end if;
					if (pulse_en_1=L) then
						pulse_state <= to_zero;
						pwm_reset_req <= H;
					end if;
				when ired =>
					if (pulse_en_1=L) then
						pulse_state <= to_zero;
						pwm_reset_req <= H;
					end if;
				when to_zero =>
					zcnt <= (others =>L);
					if (Ierr<0) then
						PWM_min <= H;
					else
						pwm_reset <= H;
						pulse_state <= zero;
						pwm_disable <= H;
					end if;
				when zero =>
					if (pwm_reset=H) then
						zcnt <= zcnt+1;
						if zcnt=off then
							pulse_state <= stoped;
						end if;
					end if;
				end case;
				if pwm_reset_req=H then
					pwm_reset <= H;
				end if;
				Uout <= Uo;
				calc_state <= sPWM;
				a <= Uo;
				b <= U2PWM;
				cm <= sh(PWM100&n(C_REG_LENGTH-2 downto 0),C_REG_LENGTH-DOT_N);
			when sPWM =>
				o_log_en <= H;
				o_Iact <= std_logic_vector(Iact);
				o_Ierr <= std_logic_vector(Ierr);
				o_Icmd <= std_logic_vector(Icmd);
				o_Uout <= std_logic_vector(Uout);
				o_pwm <= std_logic_vector(pwm);
				o_Status(7 downto 0) <= Error & IcSt & pwm_disable & PWM_off & PWM_min & PWM_max & pwm_reset;
				--pwm = Uout*U2PWM+PWM50;
				--xx.xx * xx.xx = xxxx.xxxx => xx.xx dotIerr 8 dotU2PWM 16 dotUx 8
				sim_PWM <= mac;
				vpwm := shRes(mac,dotsh(C_REG_LENGTH,DOT_U,DOT_N,DOT_U),C_REG_LENGTH);
				if (pwm_reset=H or ((pwm_cnt=PWM100-1) and C_PWMHALF=1) or (C_PWM_SIM>0 and ((pwm_cnt=C_PWM_SIM-1) and C_PWMHALF=1))) then
					pwm_reset <= L;
					o_Ierr0 <= std_logic_vector(Ierr);
					o_Iact0 <= std_logic_vector(Iact);
					IerrOld <= Ierr;
					IerrDelta <= IerrOld-Ierr;
					-- Uout limiter
					if (PWM_max=H) then
						pwm <= (PWM100-C_DT);
					elsif (PWM_min=H) then
						pwm <= to_signed(C_DT,C_REG_LENGTH);
					elsif (vpwm>(PWM100-C_DT)) then
						pwm <= (PWM100-C_DT);
					elsif (vpwm<(C_DT)) then
						pwm <= to_signed(C_DT,C_REG_LENGTH);
					else
						pwm <= vpwm;
					end if;
				end if;
				calc_state <= sIdle;
			end case;
			-- PWM counter
			if (calc_state=sPWM) and (pwm_reset=H) then
				pwm_cnt <= to_signed(0,C_REG_LENGTH);
				down <= L;
			elsif down=L then
				pwm_cnt <= pwm_cnt +1;
				if (C_PWM_SIM=0) then
					if (pwm_cnt=PWM100-1) then
						down <= H;
					end if;
				else
					if (pwm_cnt=C_PWM_SIM-1) then
						down <= H;
					end if;
				end if;
			else --
				pwm_cnt <= pwm_cnt -1;
				if (pwm_cnt=1) then
					down <= L;
				end if;
			end if;
			--
			o_p <= L;
			o_n <= L;
			if (PWM_off=L) then
				if pwm_cnt>=PWM100-pwm then
					o_p <= H;
				end if;
				if pwm_cnt>=pwm then
					o_n <= H;
				end if;
			end if;
			
			if (i_reset=H) then
				calc_state <= sIdle;
				pulse_state <= stoped;
				pwm_disable <= H;
			end if;
			
			
		end if;
	end process;

end behavior_valve_ctrl;
--------------------------------------------------------------------------------

