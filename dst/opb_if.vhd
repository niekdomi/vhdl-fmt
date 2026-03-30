--------------------------------------------------------------------------------
-- revision information
--------------------------------------------------------------------------------
--	
--	16.09.2004-le impl. a write fifo...  
--	C_WR_FIFO_SIZE = 1 is only a wr register: one single write acc. is faster
--	but everything else is slow ( do not use..)
--	14.06.2006-le	+DF_ADDR_MASK for address comparator
--	11.05.2007-le	add svn keywords
--------------------------------------------------------------------------------
--$Rev:: 187                                                                   $
--$Author:: LEUTHOLD                                                           $
--$Date:: 2007-05-11 17:11:43 +0200 (Fr., 11 Mai 2007)                         $
--------------------------------------------------------------------------------
--
---- fifo length                          16     0
--Logic Utilization:
-- Number of Slices:                     103    48
-- Number of Slice Flip Flops:           150    74
-- Number of 4 input LUTs:               170    49
--    Number used as logic:              102
--    Number used as Shift registers:     68
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
-- synthesis translate_off
library Unisim;
use Unisim.all;
-- synthesis translate_on
entity opb_if is            
  generic
    (
    C_BASEADDR      	: std_logic_vector := X"0000_0000";
    C_HIGHADDR      	: std_logic_vector := X"ffff_ffff"; 
    C_WR_FIFO_SIZE 		: integer range 0 to 16:=0;     -- do not use 1...
    C_OPB_DWIDTH    	: integer := 32;
    C_OPB_AWIDTH    	: integer := 32
    );
  port 
    (
    OPB_Clk             : in  std_logic;
    OPB_Rst             : in  std_logic;
    OPB_ABus            : in  std_logic_vector(0 to C_OPB_AWIDTH-1);
    OPB_BE              : IN  std_logic_vector(0 to C_OPB_DWIDTH/8-1);
    OPB_RNW             : IN  std_logic;
    OPB_select          : IN  std_logic;
    OPB_seqAddr         : IN  std_logic;
    OPB_DBus            : IN  std_logic_vector(0 to C_OPB_DWIDTH-1);
    Sln_DBus         	: OUT std_logic_vector(0 to C_OPB_DWIDTH-1);
    Sln_errAck       	: OUT std_logic;
    Sln_retry        	: OUT std_logic;
    Sln_toutSup      	: OUT std_logic;
    Sln_xferAck      	: OUT std_logic;
    -- Generic Interface
    addr                : OUT std_logic_vector(C_OPB_AWIDTH-1 downto 0);
    rd_acc              : OUT std_logic;
    wr_acc              : OUT std_logic;
    byte_ebl            : OUT std_logic_vector(C_OPB_DWIDTH/8-1 downto 0);
    wr_data             : OUT std_logic_vector(C_OPB_DWIDTH-1 downto 0);
    rd_data             : IN  std_logic_vector(C_OPB_DWIDTH-1 downto 0);
    rd_acc_done         : IN  std_logic;
    wr_acc_done         : IN  std_logic
    );
end opb_if;

-----------------------------------------------------------------------------
-- Architecture section
-----------------------------------------------------------------------------

architecture rtl of opb_if is
  component SRL16E
  generic (
       INIT : bit_vector := X"0000");
  port (D   : in STD_logic;
        CE  : in STD_logic;
        CLK : in STD_logic;
        A0  : in STD_logic;
        A1  : in STD_logic;
        A2  : in STD_logic;
        A3  : in STD_logic;
        Q   : out STD_logic); 
  end component; 

  type t_fifo is record
        Data	: std_logic_vector(C_OPB_DWIDTH-1 DOWNTO 0);     
        BEn		: std_logic_vector(C_OPB_DWIDTH/8-1 DOWNTO 0);
        Addr	: std_logic_vector(C_OPB_AWIDTH-1 DOWNTO 0);
  end record;  	
  
  signal fifo_in		: t_fifo;
  signal fifo_out		: t_fifo; 
  signal pFifo			: std_logic_vector(3 downto 0):=(others=>'0'); 
  signal srl_addr		: std_logic_vector(3 downto 0):=(others=>'0');    
  SIGNAL loc_rd_acc     : std_logic;
  SIGNAL loc_wr_acc     : std_logic;
  SIGNAL loc_select     : std_logic;
  SIGNAL loc_addr       : std_logic_vector(C_OPB_AWIDTH-1 DOWNTO 0);
  SIGNAL loc_wr_data    : std_logic_vector(C_OPB_DWIDTH-1 DOWNTO 0);
  SIGNAL loc_byte_ebl   : std_logic_vector(C_OPB_DWIDTH/8-1 DOWNTO 0); 
  signal loc_wr_acc_done: std_logic; 
  signal fifo_empty		: std_logic:='1';

  constant DF_ADDR_MASK : std_logic_vector(0 to C_OPB_AWIDTH-1) := not (C_HIGHADDR - C_BASEADDR);
begin  -- VHDL_RTL


Sln_errAck  <= '0';
Sln_retry   <= '0'; 
no_fifo: if C_WR_FIFO_SIZE=0 generate
begin  
	Sln_xferAck <= (loc_rd_acc AND rd_acc_done) OR (loc_wr_acc AND wr_acc_done);
end generate no_fifo;
fifo_1: if C_WR_FIFO_SIZE>0 generate
begin  
	Sln_xferAck <= (loc_rd_acc AND rd_acc_done) OR (loc_wr_acc_done);              
end generate fifo_1;

rd_acc   <= loc_rd_acc;
wr_acc   <= loc_wr_acc;

srl_addr <= pFifo;

--loc_select <= OPB_select WHEN (OPB_ABus >= C_BASEADDR AND OPB_ABus <= C_HIGHADDR) ELSE '0';
loc_select <= OPB_select when (OPB_ABus and DF_ADDR_MASK) = (C_BASEADDR and DF_ADDR_MASK) else '0';

big_little_endian: PROCESS(OPB_ABus, OPB_DBus, OPB_BE)
BEGIN
  FOR i IN C_OPB_AWIDTH-1 DOWNTO 0 LOOP
    loc_addr(i)    <= OPB_ABus(C_OPB_AWIDTH-1 - i);
  END LOOP;
  FOR i IN C_OPB_DWIDTH-1 DOWNTO 0 LOOP
    loc_wr_data(i) <= OPB_DBus(C_OPB_DWIDTH-1 - i);
  END LOOP;
  FOR i IN C_OPB_DWIDTH/8-1 DOWNTO 0 LOOP
    loc_byte_ebl(i) <= OPB_BE(C_OPB_DWIDTH/8-1 - i);
  END LOOP;
END PROCESS big_little_endian;

p1: PROCESS (OPB_Clk, OPB_Rst)
BEGIN
  IF OPB_Rst = '1' THEN
    loc_rd_acc <= '0';
    loc_wr_acc <= '0'; 
    if C_WR_FIFO_SIZE>0 then loc_wr_acc_done <= '0'; end if;
    fifo_empty <= '1';
    addr       <= (OTHERS => '0');
    wr_data    <= (OTHERS => '0');
    pFifo		<= (OTHERS => '0');  
    Sln_toutSup <= '0';
  ELSIF OPB_Clk'EVENT AND OPB_Clk = '1' THEN
  -- default value: always = '0'
    loc_rd_acc <= '0';
    -- Write access 
    if C_WR_FIFO_SIZE>0 then -- with fifo
    	IF loc_wr_acc = '1' AND wr_acc_done = '1' THEN  --real wr.acc. done -> fifo -1
    	  	loc_wr_acc <= '0';
		  	if pFifo>0 then
		  		pFifo <= pFifo - 1;
		  	else
		  		fifo_empty <= '1'; 
		  	end if;
    	elsif fifo_empty='0' and loc_wr_acc_done='0' and loc_wr_acc = '0' and C_WR_FIFO_SIZE>1 then
    		loc_wr_acc 	<= '1';
    		wr_data    	<= fifo_out.data ;
    		addr		<= fifo_out.addr ;
    		byte_ebl 	<= fifo_out.BEn	 ;
    	elsif fifo_empty='0' and loc_wr_acc = '0' and C_WR_FIFO_SIZE=1 then
    		loc_wr_acc 	<= '1';
    		wr_data    	<= fifo_in.data ;
    		addr		<= fifo_in.addr ;
    		byte_ebl 	<= fifo_in.BEn	;   
    	end if;
    	if loc_wr_acc_done='1' then 
    		loc_wr_acc_done <= '0';
    	elsif loc_select = '1' AND OPB_RNW = '0' THEN -- new write acc. -> store in fifo    
    		if C_WR_FIFO_SIZE=1 then
    			if fifo_empty='0' then --and wr_acc_done = '0' then
    	  			Sln_toutSup <= '1';
    	  			loc_wr_acc_done <= '0';
    			else
    				loc_wr_acc_done <= '1'; 
		    	  	fifo_in.data<= loc_wr_data;
		    	  	fifo_in.addr<= loc_addr;
		    	  	fifo_in.BEn	<= loc_byte_ebl; 
		    	  	if wr_acc_done = '1' then
		    	  		 -- do nothing (read and write in one cycle)
		    	  	elsif fifo_empty='1' then
		    	  		fifo_empty <= '0'; 
		    	  	end if;
		    	  	Sln_toutSup <= '0'; 
				end if;	
    		else
    	  		if pFifo=C_WR_FIFO_SIZE-1 then
    	  			Sln_toutSup <= '1';
    			else
    				loc_wr_acc_done <= '1'; 
		    	  	fifo_in.data<= loc_wr_data;
		    	  	fifo_in.addr<= loc_addr;
		    	  	fifo_in.BEn	<= loc_byte_ebl; 
		    	  	if wr_acc_done = '1' then
		    	  		-- do nothing (read and write in one cycle)
		    	  	elsif fifo_empty='1' then
		    	  		fifo_empty <= '0';
		    	  	else
    	    	    	pFifo 	<= pFifo + 1;  
		    	  	end if;
		    	  	Sln_toutSup <= '0'; 
				end if;
			end if;      
    	END IF;
    else -- no fifo
    	loc_wr_acc <= '0';
    	IF loc_wr_acc = '1' AND wr_acc_done = '1' THEN
    	  loc_wr_acc <= '0';  
    	  Sln_toutSup <= '0'; 
    	ELSIF loc_select = '1' AND OPB_RNW = '0' THEN 
    	  Sln_toutSup <= '1';	
    	  loc_wr_acc <= '1';
    	  wr_data   <= loc_wr_data;
		  addr		<= loc_addr;
		  byte_ebl 	<= loc_byte_ebl;
    	END IF;
    end if;
    -- Read access
    IF loc_rd_acc = '1' AND rd_acc_done = '1' THEN
      	loc_rd_acc <= '0';
      	Sln_toutSup <= '0';
    ELSIF  loc_select = '1' AND OPB_RNW = '1' THEN 
    	if fifo_empty='1' or C_WR_FIFO_SIZE=0 then   -- fifo empty or no fifo
    		Sln_toutSup <= '1';
      		loc_rd_acc <= '1'; 
      		addr <= loc_addr; 
   			byte_ebl <= loc_byte_ebl; 
   		else 	-- wr-fifo full, pleas wait...
   			Sln_toutSup <= '1';
   		end if;
    END IF;
  END IF;
END PROCESS;


-- Data readback                     

p3: PROCESS (loc_rd_acc, rd_data)
BEGIN
  Sln_DBus <= (OTHERS =>'0');
  IF loc_rd_acc = '1' THEN
    Sln_DBus <= rd_data; 
  END IF;
END PROCESS;

fifo : if C_WR_FIFO_SIZE>1 generate
begin
	fifo_data : for i in 0 to C_OPB_DWIDTH-1 generate 
	begin
		I_data_sr : SRL16E
		port map (
			D   => fifo_in.data(i),
			CE  => loc_wr_acc_done,
			CLK => OPB_Clk,
			A0  => srl_addr(0),
			A1  => srl_addr(1),
			A2  => srl_addr(2),
			A3  => srl_addr(3),
			Q   => fifo_out.data(i)
		);
	end generate fifo_data;
	fifo_addr : for i in 0 to C_OPB_AWIDTH-1 generate 
	begin
		addr_sr : SRL16E
		port map (
			D   => fifo_in.addr(i),
			CE  => loc_wr_acc_done,
			CLK => OPB_Clk ,
			A0  => srl_addr(0),
			A1  => srl_addr(1),
			A2  => srl_addr(2),
			A3  => srl_addr(3),
			Q   => fifo_out.addr(i)
		);
	end generate fifo_addr;
	fifo_BEn : for i in 0 to C_OPB_DWIDTH/8-1 generate 
	begin
		ben_sr : SRL16E
		port map (
			D   => fifo_in.BEn(i),
			CE  => loc_wr_acc_done,
			CLK => OPB_Clk ,
			A0  => srl_addr(0),
			A1  => srl_addr(1),
			A2  => srl_addr(2),
			A3  => srl_addr(3),
			Q   => fifo_out.BEn(i)
		);
	end generate fifo_BEn;
end generate fifo;
end rtl;


