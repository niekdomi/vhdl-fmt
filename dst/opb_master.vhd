--------------------------------------------------------------------------------
-- opb_master.vhd
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library INDEL_pkg;
use INDEL_pkg.INDEL_pkg.all;

entity opb_master is
generic (
	C_USER_DWIDTH : integer range 32 to 64 := 64;
	C_OPB_DWIDTH : integer range 32 to 32 := 32;
	C_OPB_AWIDTH : integer range 32 to 32 := 32
);
port (
	-- user port
	o_bus2user_data : out std_logic_vector(C_USER_DWIDTH-1 downto 0);
	i_user2bus_data : in std_logic_vector(C_USER_DWIDTH-1 downto 0);
	i_user_addr : in std_logic_vector(C_OPB_AWIDTH-1 downto 0);
	i_user_be : in std_logic_vector(C_USER_DWIDTH/8-1 downto 0);
	i_user_wr_req : in std_logic;
	o_user_wr_ready : out std_logic;
	i_user_rd_req : in std_logic;
	o_user_rd_done : out std_logic;
	-- OPB Master
	OPB_Clk : in std_logic;
	OPB_Rst : in std_logic;
	OPB_DBus : in std_logic_vector(0 to C_OPB_DWIDTH-1);
	OPB_errAck : in std_logic;
	OPB_MnGrant : in std_logic;
	OPB_retry : in std_logic;
	OPB_timeout : in std_logic;
	OPB_xferAck : in std_logic;
	M_ABus : out std_logic_vector(0 to C_OPB_AWIDTH-1);
	M_BE : out std_logic_vector(0 to C_OPB_DWIDTH/8 -1);
	M_busLock : out std_logic;
	M_DBus : out std_logic_vector(0 to C_OPB_DWIDTH-1);
	M_request : out std_logic;
	M_RNW : out std_logic;
	M_select : out std_logic;
	M_seqAddr : out std_logic
);
end opb_master;

architecture opb_master_arc of opb_master is

	-- types
	-- constants
	-- static signals
	-- signals	
	signal high_word : std_logic;
	signal low_word : std_logic;
	type t_states is (s_idle, s_request, s_first, s_last);
	signal state : t_states;
	signal RNW : std_logic;
	signal user_wr_ready : std_logic;
	signal user_rd_done : std_logic;
	signal reg_wr_data : std_logic_vector(C_USER_DWIDTH-1 downto 0);
	
--	attribute FSM_ENCODING : string;
--	attribute FSM_ENCODING of state: signal is "ONE-HOT";
	attribute KEEP : string;
	attribute KEEP of high_word : signal is "TRUE";
	attribute KEEP of low_word : signal is "TRUE";
	
begin
	--unsupported inputs:	OPB_errAck : in std_logic;
	--unsupported inputs:	OPB_retry : in std_logic;
	--unsupported inputs:	OPB_timeout : in std_logic; 
	o_user_wr_ready <= user_wr_ready;
	o_user_rd_done <= user_rd_done;
	M_seqAddr <= L;
	
	--C_USER_DWIDTH = 2*C_OPB_DWIDTH
	user_opb_2_1 : if (C_USER_DWIDTH=2*C_OPB_DWIDTH) generate
	begin
		low_word <= H when (i_user_be(C_USER_DWIDTH/8-1 downto C_USER_DWIDTH/8/2)/=0) else L;
		high_word <= H when (i_user_be(C_USER_DWIDTH/8/2-1 downto 0)/=0) else L;
	end generate user_opb_2_1;
	
	process (opb_clk)
	begin
		if (rising_edge(opb_clk)) then
			if (opb_rst = H) then
				M_request <= L;
				M_select <= L;
				M_RNW <= L;
				M_ABus <= (others => L);
				M_DBus <= (others => L);
				M_BE <= (others => L);
				M_busLock <= L;
				user_wr_ready <= H;
				user_rd_done <= L;
				state <= s_idle;
				RNW <= L;
			else
				if (i_user_wr_req=H) then
					reg_wr_data <= i_user2bus_data;
					user_wr_ready <= L;
				end if;
				user_rd_done <= L;
				M_request <= L;
				case state is
					when s_idle =>
						if (i_user_rd_req=H and user_rd_done=L) then
							RNW <= H;
							M_request <= H;
							state <= s_request;
						elsif (user_wr_ready=L or i_user_wr_req=H) then
							RNW <= L;
							M_request <= H;
							state <= s_request;
						end if;
					when s_request =>
						M_request <= H;
						if (OPB_MnGrant=H) then
							M_request <= L;
							M_select <= H;
							M_RNW <= RNW;
							M_ABus <= crossbits(i_user_addr);
							if (C_USER_DWIDTH=2*C_OPB_DWIDTH) then
								if (high_word=H and low_word=H) then
									M_BE <= crossbits(i_user_be(C_USER_DWIDTH/8/2-1 downto 0));
									M_DBus <= crossbits(reg_wr_data(C_USER_DWIDTH/2-1 downto 0));
									M_ABus(C_OPB_AWIDTH-(C_OPB_AWIDTH/8-1)) <= L;
									M_busLock <= H;
									state <= s_first;
								elsif (low_word=H) then
									M_BE <= crossbits(i_user_be(C_USER_DWIDTH/8-1 downto C_USER_DWIDTH/8/2));
									M_DBus <= crossbits(reg_wr_data(C_USER_DWIDTH-1 downto C_USER_DWIDTH/2));
									M_ABus(C_OPB_AWIDTH-(C_OPB_AWIDTH/8-1)) <= L;
									M_busLock <= L;
									state <= s_last;
								elsif (high_word=H) then
									M_BE <= crossbits(i_user_be(C_USER_DWIDTH/8/2-1 downto 0));
									M_DBus <= crossbits(reg_wr_data(C_USER_DWIDTH/2-1 downto 0));
									M_ABus(C_OPB_AWIDTH-(C_OPB_AWIDTH/8-1)) <= H;
									M_busLock <= L;
									state <= s_last;
								end if;
							end if;
							if (C_USER_DWIDTH=C_OPB_DWIDTH) then
								M_BE <= crossbits(i_user_be);
								M_DBus <= crossbits(reg_wr_data);
								M_busLock <= L;
								state <= s_last;
							end if;
						end if;
					when s_first =>
						if (OPB_xferAck=H) then
							if (C_USER_DWIDTH=2*C_OPB_DWIDTH) then
								M_BE <= crossbits(i_user_be(C_USER_DWIDTH/8/2-1 downto 0));
								M_DBus <= crossbits(reg_wr_data(C_USER_DWIDTH/2-1 downto 0));
								M_ABus(C_OPB_AWIDTH-(C_OPB_AWIDTH/8-1)) <= H;
								state <= s_last;
							end if;
						end if;
					when s_last =>
						if (OPB_xferAck=H) then
							if (RNW=H) then
								user_rd_done <= H;
								if (C_USER_DWIDTH=2*C_OPB_DWIDTH) then
									if (high_word=H) then
										o_bus2user_data(C_USER_DWIDTH/2-1 downto 0) <= crossbits(OPB_DBus);
									else
										o_bus2user_data(C_USER_DWIDTH-1 downto C_USER_DWIDTH/2) <= crossbits(OPB_DBus);
									end if;
								end if;
								if (C_USER_DWIDTH=C_OPB_DWIDTH) then
									o_bus2user_data <= crossbits(OPB_DBus);
								end if;
							else
								user_wr_ready <= H;
							end if;
							M_select <= L;
							M_RNW <= L;
							M_ABus <= (others => L);
							M_DBus <= (others => L);
							M_BE <= (others => L);
							M_busLock <= L;
							state <= s_idle;
						end if;
				end case;
			end if;
		end if;
	end process;
end architecture opb_master_arc;