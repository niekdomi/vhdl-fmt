-- Module BSAT_TDP_RAM_Control																--
-- VHDL Architecture Indel_lib.BSAT_TDP_RAM_Control.Universal						--
--																										--
-- Project:   BSAT																				--
--																										--
-- qfu																								--
-- 26.02.2018																						--
-- This is a simplified version of the GinLink TDP_RAM Controller for the		--
-- BSAT. It is the scheduler for the main node RAM access. There are				--
-- different parts in a node design which need to access the memory				--
-- (Downloading, HW identification, Error Handling and the Node functionality)--
--																										--
-- History:																							--
-- --------------------------------------------------------------------------	--
--    1.) First Draft																			--
--		2.) Added words for DL (QFU, 22.08.2018).											--
--		3.) MID address added.																	--
--																										--
-- -------------------------------------------------------------------------- --
--------------------------------------------------------------------------------
--$Rev:: 5535                                                                  $
--$Author:: qfu_m                                                              $
--$Date:: 2020-03-20 10:52:01 +0100 (Fr., 20 MÃ¤r 2020)                        $
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

LIBRARY Indel_lib;
USE Indel_lib.Indel_Package.all;

-------------------------------------------------------------------------
-------------------------------------------------------------------------

ENTITY BSAT_TDP_RAM_Control IS
   GENERIC   (
              F_BSAT_UID				: std_logic_vector(Return_Upper_F_I_PKG(Firmware_Versioning_C_I_PKG) DOWNTO 0):= (OTHERS => '0');
				  F_BSAT_Mem_ID			: std_logic_vector(Return_Upper_F_I_PKG(Word_Width_C_I_PKG) DOWNTO 0):= (OTHERS => '0');
				  F_BSAT_Node_ID			: std_logic_vector(Return_Upper_F_I_PKG(Word_Width_C_I_PKG) DOWNTO 0):= (OTHERS => '0');
				  F_BSAT_Node_Info		: std_logic_vector(Return_Upper_F_I_PKG(Word_Width_C_I_PKG) DOWNTO 0):= (OTHERS => '0');
              HID_Count          	: natural := 0;
              Error_Count_Node   	: natural := 0;
              Error_Count_0      	: natural := 0;
              Error_Count_1			: natural := 0;
              Error_Count_U      	: natural := 0;
              Flash_AD_Width     	: natural := 24;
              Flash_Data_Width   	: natural := 16;
              Masking_HID        	: natural RANGE 0 TO 1 := 1;
              Feedback_HID       	: natural RANGE 0 TO 1 := 0;
              Masking_Node       	: natural RANGE 0 TO 1 := 1;
              Feedback_Node      	: natural RANGE 0 TO 1 := 1;
              Masking_Ports      	: natural RANGE 0 TO 1 := 1;
              Feedback_Ports     	: natural RANGE 0 TO 1 := 1;
              Masking_U          	: natural RANGE 0 TO 1 := 1;
              Feedback_U         	: natural RANGE 0 TO 1 := 1;
				  Board_Type_Length		: natural := 96;
				  Board_Number_Length	: natural := 96;
              DL_En              	: natural RANGE 0 TO 1 := 0
              );
   PORT      (
              CLK62_5                : IN  std_logic; -- Clock of the entity
              CLR_n                  : IN  std_logic; -- Inverted reset signal
              RAM_Control_Data_B     : IN  std_logic_vector(Return_Upper_F_I_PKG(Word_Width_TDP_RAM_C_I_PKG) DOWNTO 0);
				  MID_Info					 : IN  std_logic_Vector(Return_Upper_F_I_PKG(Word_Width_C_I_PKG) DOWNTO 0):= (OTHERS => '1');
              HID_TR                 : IN  std_logic_vector(Return_Upper_F_I_PKG(HID_Count) DOWNTO 0):= (OTHERS => '1');
              Error_TR_Node          : IN  std_logic_vector(Return_Upper_F_I_PKG(Error_Count_Node) DOWNTO 0):= (OTHERS => '1');
              Error_TR_Port_0		    : IN  std_logic_vector(Return_Upper_F_I_PKG(Error_Count_0) DOWNTO 0):= (OTHERS => '1');
              Error_TR_Port_1        : IN  std_logic_vector(Return_Upper_F_I_PKG(Error_Count_1) DOWNTO 0):= (OTHERS => '1');
              Error_TR_U             : IN  std_logic_vector(Return_Upper_F_I_PKG(Error_Count_U) DOWNTO 0):= (OTHERS => '1');
              Node_Mode              : IN  std_logic_vector(Return_Upper_F_I_PKG(Double_Word_Width_C_I_PKG) DOWNTO 0):= (OTHERS => '0');
              Flash_Control_Data     : IN  std_logic_vector(Return_Upper_F_I_PKG(16) DOWNTO 0):= (OTHERS => '1');
              LUT_Control_A          : IN  std_logic_vector(7 DOWNTO 0);
				  BSAT_MM_Board_Type     : IN  std_logic_vector(Return_Upper_F_I_PKG(Board_Type_Length) DOWNTO 0):= (OTHERS => '0');
				  BSAT_MM_Board_Number	 : IN	 std_logic_vector(Return_Upper_F_I_PKG(Board_Number_Length) DOWNTO 0):= (OTHERS => '0');
              Control_RAM_WREN_B     : OUT std_logic;
              Control_RAM_AD_B       : OUT std_logic_vector(8 DOWNTO 0);
              Control_RAM_Data_B     : OUT std_logic_vector(Return_Upper_F_I_PKG(Word_Width_TDP_RAM_C_I_PKG) DOWNTO 0);
              HID_Mask               : OUT std_logic_vector(Return_Upper_F_I_PKG(HID_Count) DOWNTO 0);
              Error_Mask_Node        : OUT std_logic_vector(Return_Upper_F_I_PKG(Error_Count_Node) DOWNTO 0);
              Error_Mask_Port_0		 : OUT std_logic_vector(Return_Upper_F_I_PKG(Error_Count_0) DOWNTO 0);
              Error_Mask_Port_1		 : OUT std_logic_vector(Return_Upper_F_I_PKG(Error_Count_1) DOWNTO 0);
              Error_Mask_U           : OUT std_logic_vector(Return_Upper_F_I_PKG(Error_Count_U) DOWNTO 0); 
              Error_FB_Port_0        : OUT std_logic_vector(Return_Upper_F_I_PKG(Error_Count_0) DOWNTO 0);
              Error_FB_Port_1        : OUT std_logic_vector(Return_Upper_F_I_PKG(Error_Count_1) DOWNTO 0);
              Error_FB_U             : OUT std_logic_vector(Return_Upper_F_I_PKG(Error_Count_U) DOWNTO 0);
              Node_Control_Access	 :	OUT std_logic_vector(Return_Upper_F_I_PKG(Identifier_Words_Needed_F_I_PKG(Double_Word_Width_C_I_PKG, ON_C_I_PKG, Word_Width_C_I_PKG)) DOWNTO 0);
				  Node_Control           : OUT std_logic_vector(Return_Upper_F_I_PKG(Double_Word_Width_C_I_PKG) DOWNTO 0);
				  Control_Flash_RD_Access: OUT std_logic_vector(Return_Upper_F_I_PKG(Identifier_Words_Needed_F_I_PKG(Double_Word_Width_C_I_PKG, ON_C_I_PKG, Word_Width_C_I_PKG)) DOWNTO 0);
				  Control_Flash_RD_AD	 : OUT std_logic_vector(Return_Upper_F_I_PKG(Double_Word_Width_C_I_PKG) DOWNTO 0);
				  Control_Flash_WR_Access:	OUT std_logic_vector(Return_Upper_F_I_PKG(Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG, ON_C_I_PKG, Word_Width_C_I_PKG)) DOWNTO 0);
				  Control_Flash_WR_AD	 :	OUT std_logic_vector(Return_Upper_F_I_PKG(Double_Word_Width_C_I_PKG) DOWNTO 0);
				  Control_Flash_Data		 :	OUT std_logic_vector(Return_Upper_F_I_PKG(Word_Width_C_I_PKG) DOWNTO 0);
				  Control_DL_WR_Access	 :	OUT std_logic_vector(Return_Upper_F_I_PKG(Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG, ON_C_I_PKG, Word_Width_C_I_PKG)) DOWNTO 0);
				  Control_DL_WR_Data  	 : OUT std_logic_vector(Return_Upper_F_I_PKG(Word_Width_C_I_PKG) DOWNTO 0);
				  BSAT_Safety_Counters	 : OUT std_logic_vector(Return_Upper_F_I_PKG(Byte_Width_C_I_PKG) DOWNTO 0)
             ); 
END BSAT_TDP_RAM_Control;


--------------------------------------------------------------------------
--------------------------------------------------------------------------

ARCHITECTURE Universal OF BSAT_TDP_RAM_Control IS

   -----------------------
   -- Constant Declaration
   ----------------------- 
   -- Explanation: With the help of the following two constants the whole TDP RAM access is controlled. There
   --              exist two constants: one for the read and one for the write access. They stand for the maximal
   --              accesses- which means, the theoretically needed accesses to the RAM. For example: it is possible
   --              that a designer needs the hardware identification (normally it is the case)- then this access is
   --              somewhere in this array.- Where does not matter with the exception that you want absolute control
   --              over the RAM timing of every access. How do those constructs work?- "RD_Definition" and "WR_Definition"
   --              are two multidimensional arrays. Index 0 stands for the physical address in the RAM LUT. It has
   --              nothing in common with the logical address of the data words which can be seen by the machine software.
   --              The physical addresses are translated in the LUT to the logical addresses, so that the logical
   --              addresses can be changed without touching the node design. We  just need to exchange the memory
   --              initialization file (Node_System_LUT_Map.hex). Index 1 is the number of needed words for this data
   --              type in the actual implementation. For example think of 18 used "ERROR_A" bits. If we have a word
   --              width of 16, we need two words in the memory for the file of these bits. So the element in the array
   --              would be: (Error_A_Mask_Base, Words_ERR_A), where Words_ERR_A = 2; This means it makes absolutely no
   --              sense to access all the reserved memory addresses, because two are enough. With the help of the generics
   --              the two constants RD_Definition and WR_Definition are completely defined at the time of the synthesis.
   --              At this point another mechanism is activated: The functions defined in the Indel_Package. They are
   --              invoked and do the following job: All the defined accesses which need zero words are removed from
   --              the array. This means nothing else than we are optimizing our RAM access. All the unneeded addresses
   --              are removed. You can see it in the following paragraph:
   --              RD_Definition ((HID_Mask_Base,Words_HID),(Error_B_Mask_Base,Words_ERR_B)). If Words_HID = 0 then we
   --              receive the following result:
   --              RD_Optimized((Error_B_Mask_Base,Words_ERR_B)). Further with the help of the constant Words_ERR_B we
   --              know exactly how many accesses are needed and so we have optimized our RAM Controller. We do not
   --              define the array in the Indel_Package, because otherwise in a design with more than one node a single
   --              node can no longer be tuned.
   --              Attention:
   --              Based on the fact that the structure is built up during synthesis- the elaboration is very strict:
   --              For example if you use a generic for the definition and you can not guarantee that the Accessor is
   --              logically directly related to the invocating generic, the assignments are not resolved.


   -- Please update the array with the needed entries. This base array is valid for BSAT only.
	CONSTANT RD_Definition	: ram_selector_t_i_pkg:=
				(															--Identifier_Words_Needed_F_I_PKG(Count,					Enable,					Word_Width: natural)
				(BSAT_MM_Node_Control_Base_C_I_PKG,				Identifier_Words_Needed_F_I_PKG(Double_Word_Width_C_I_PKG, ON_C_I_PKG,		Word_Width_C_I_PKG)),
				(BSAT_MM_HID_Base_C_I_PKG,							Identifier_Words_Needed_F_I_PKG(HID_Count,				Feedback_HID,			Word_Width_C_I_PKG)),
				(BSAT_MM_HID_Mask_Base_C_I_PKG,					Identifier_Words_Needed_F_I_PKG(HID_Count,				Masking_HID,			Word_Width_C_I_PKG)),
				(BSAT_MM_Error_Node_Mask_Base_C_I_PKG,			Identifier_Words_Needed_F_I_PKG(Error_Count_Node,		Masking_Node,			Word_Width_C_I_PKG)),
				(BSAT_MM_Error_0_Base_C_I_PKG,					Identifier_Words_Needed_F_I_PKG(Error_Count_0,			Feedback_Ports,		Word_Width_C_I_PKG)),
				(BSAT_MM_Error_0_Mask_Base_C_I_PKG,				Identifier_Words_Needed_F_I_PKG(Error_Count_0,			Masking_Ports,			Word_Width_C_I_PKG)),
				(BSAT_MM_Error_1_Base_C_I_PKG,					Identifier_Words_Needed_F_I_PKG(Error_Count_1,			Feedback_Ports,		Word_Width_C_I_PKG)),
				(BSAT_MM_Error_1_Mask_Base_C_I_PKG,				Identifier_Words_Needed_F_I_PKG(Error_Count_1,			Masking_Ports,			Word_Width_C_I_PKG)),
				(BSAT_MM_Error_U_Base_C_I_PKG,					Identifier_Words_Needed_F_I_PKG(Error_Count_U,			Feedback_U,				Word_Width_C_I_PKG)),
				(BSAT_MM_Error_U_Mask_Base_C_I_PKG,				Identifier_Words_Needed_F_I_PKG(Error_Count_U,			Masking_U,				Word_Width_C_I_PKG)),
				(BSAT_MM_Safety_Counter_Base_C_I_PKG,			Identifier_Words_Needed_F_I_PKG(Byte_Width_C_I_PKG,	ON_C_I_PKG,				Word_Width_C_I_PKG)),
				(BSAT_MM_Node_Flash_RD_AD_Base_C_I_PKG,		Identifier_Words_Needed_F_I_PKG(Double_Word_Width_C_I_PKG,ON_C_I_PKG,		Word_Width_C_I_PKG)),
				(BSAT_MM_Node_Flash_WR_AD_Base_C_I_PKG,		Identifier_Words_Needed_F_I_PKG(Double_Word_Width_C_I_PKG,ON_C_I_PKG,		Word_Width_C_I_PKG)),
				(BSAT_MM_Node_DL_WR_Data_Base_C_I_PKG,			Identifier_Words_Needed_F_I_PKG(Flash_Data_Width,		ON_C_I_PKG,				Word_Width_C_I_PKG)),
				(BSAT_MM_Node_Flash_WR_Data_Base_C_I_PKG,		Identifier_Words_Needed_F_I_PKG(Flash_Data_Width,		ON_C_I_PKG,				Word_Width_C_I_PKG))
            );


   -- Please update the array with the needed entries. This base array is valid for BSAT only.
   CONSTANT WR_Definition	: ram_selector_t_i_pkg:=
            (													--Identifier_Words_Needed_F_I_PKG(Count,								Enable,															Word_Width: natural)
				(BSAT_MM_UID_Base_C_I_PKG,					Identifier_Words_Needed_F_I_PKG(Firmware_Versioning_C_I_PKG,	ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_Node_ID_Base_C_I_PKG,			Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG,				ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_MEM_ID_Base_C_I_PKG,				Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG,				ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_MID_BASE_C_I_PKG,					Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG,				ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_Node_Mode_Base_C_I_PKG,			Identifier_Words_Needed_F_I_PKG(Double_Word_Width_C_I_PKG,		ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_HID_Base_C_I_PKG,					Identifier_Words_Needed_F_I_PKG(HID_Count,							ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_Error_Node_Base_C_I_PKG,		Identifier_Words_Needed_F_I_PKG(Error_Count_Node,					ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_Error_0_Base_C_I_PKG,			Identifier_Words_Needed_F_I_PKG(Error_Count_0,						ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_Error_1_Base_C_I_PKG,			Identifier_Words_Needed_F_I_PKG(Error_Count_1,						ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_Error_U_Base_C_I_PKG,			Identifier_Words_Needed_F_I_PKG(Error_Count_U,						ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_Node_Flash_RD_Data_Base_C_I_PKG,	Identifier_Words_Needed_F_I_PKG(Flash_Data_Width,				ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_HID_Status_Base_C_I_PKG,		Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG,				Return_NotZero_natural_F_I_PKG(HID_Count),			Word_Width_C_I_PKG)),
				(BSAT_MM_Node_Status_Base_C_I_PKG,		Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG,				Return_NotZero_natural_F_I_PKG(Error_Count_Node),	Word_Width_C_I_PKG)),
				(BSAT_MM_Port_0_Status_Base_C_I_PKG,	Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG,				Return_NotZero_natural_F_I_PKG(Error_Count_0),		Word_Width_C_I_PKG)),
				(BSAT_MM_Port_1_Status_Base_C_I_PKG,	Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG,				Return_NotZero_natural_F_I_PKG(Error_Count_1),		Word_Width_C_I_PKG)),
				(BSAT_MM_Port_U_Status_Base_C_I_PKG,	Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG,				Return_NotZero_natural_F_I_PKG(Error_Count_U),		Word_Width_C_I_PKG)),
				(BSAT_MM_Board_Type_Base_C_I_PKG,		Identifier_Words_Needed_F_I_PKG(Board_Type_Length,					ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_Board_Number_Base_C_I_PKG,		Identifier_Words_Needed_F_I_PKG(Board_Number_Length,				ON_C_I_PKG,														Word_Width_C_I_PKG)),
				(BSAT_MM_Node_Info_Base_C_I_PKG,			Identifier_Words_Needed_F_I_PKG(Word_Width_C_I_PKG,				ON_C_I_PKG,														Word_Width_C_I_PKG))
				);
				
	
		
		

   -- These constants represent the optimized memory array. All unused entries have been removed.
   CONSTANT RD_Optimized           : ram_selector_t_i_pkg:= Optimize_Array_F_I_PKG(RD_Definition,Length_Needed_F_I_PKG(RD_Definition));
   CONSTANT WR_Optimized           : ram_selector_t_i_pkg:= Optimize_Array_F_I_PKG(WR_Definition,Length_Needed_F_I_PKG(WR_Definition));
               
   CONSTANT RD_Defined_Length      : natural:= ((ABS(RD_Definition'length(1) - 1) + RD_Definition'length(1) - 1)/2);
   CONSTANT WR_Defined_Length      : natural:= ((ABS(WR_Definition'length(1) - 1) + WR_Definition'length(1) - 1)/2);
   
   CONSTANT RD_Elements            : natural:= Length_Needed_F_I_PKG(RD_Definition);
   CONSTANT WR_Elements            : natural:= Length_Needed_F_I_PKG(WR_Definition);
   
   CONSTANT Overwrite_Zero         : std_logic_vector(23 DOWNTO 0):= (OTHERS => '0');
   CONSTANT Zero_Interrupt         : std_logic_vector( 7 DOWNTO 0):= (OTHERS => '0');

   -- Combine status bits (currently only HID/Error count)
   CONSTANT HID_Status             : std_logic_vector(15 DOWNTO 0) := X"00" & std_logic_vector(to_unsigned(HID_Count, Byte_Width_C_I_PKG));
   CONSTANT Error_Node_Status      : std_logic_vector(Return_Upper_F_I_PKG(Error_Count_Width_C_I_PKG) DOWNTO 0) := std_logic_vector(to_unsigned(Error_Count_Node, Error_Count_Width_C_I_PKG));
   CONSTANT Error_0_Status         : std_logic_vector(Return_Upper_F_I_PKG(Error_Count_Width_C_I_PKG) DOWNTO 0) := std_logic_vector(to_unsigned(Error_Count_0,   Error_Count_Width_C_I_PKG));
   CONSTANT Error_1_Status         : std_logic_vector(Return_Upper_F_I_PKG(Error_Count_Width_C_I_PKG) DOWNTO 0) := std_logic_vector(to_unsigned(Error_Count_1,   Error_Count_Width_C_I_PKG));
   CONSTANT Error_U_Status         : std_logic_vector(Return_Upper_F_I_PKG(Error_Count_Width_C_I_PKG) DOWNTO 0) := std_logic_vector(to_unsigned(Error_Count_U,    Error_Count_Width_C_I_PKG));
   ---------------------------
   -- Constant Declaration END
   --------------------------- 

   
   ---------------------
   -- Signal Declaration
   ---------------------
   SIGNAL   WR_Accessor            : array_accessor_t_i_pkg(0 TO Return_Upper_F_I_PKG(Words_Needed_F_I_PKG(WR_Definition)));
   SIGNAL   RD_Array               : access_array_t_i_pkg(0 TO Return_Upper_F_I_PKG(Words_Needed_F_I_PKG(RD_Definition)));
   SIGNAL   WR_Array               : access_array_t_i_pkg(0 TO Return_Upper_F_I_PKG(Words_Needed_F_I_PKG(WR_Definition)));
   SIGNAL   WR_RD_n_Status_1_Int   : std_logic;
   SIGNAL   WR_RD_n_Status_2_Int   : std_logic;
   SIGNAL   WR_RD_n_Status_3_Int   : std_logic;
   SIGNAL   Count_1_Assign         : natural RANGE 0 TO 255;
   SIGNAL   Count_2_Assign         : natural RANGE 0 TO 255;
   SIGNAL   Count_Assign           : natural RANGE 0 TO 255;
   SIGNAL   Control_LUT_AD_B_Int   : std_logic_vector(8 DOWNTO 0);
   -------------------------
   -- Signal Declaration END
   -------------------------
   
   
   ------------------------------
   -- Shared Variable Declaration
   ------------------------------
   SHARED VARIABLE Count_D_1       : natural RANGE 0 TO 255;
   SHARED VARIABLE Count_D_2       : natural RANGE 0 TO 15;
   SHARED VARIABLE A_Count_D_1     : natural RANGE 0 TO 255;
   SHARED VARIABLE A_Count_D_2     : natural RANGE 0 TO 15;
   SHARED VARIABLE WR_RD_n_Int     : std_logic;
   ----------------------------------
   -- Shared Variable Declaration END
   ----------------------------------


BEGIN
  
   -- Concurrent 1
   WR_Array <= Arrange_Structure_F_I_PKG(WR_Accessor, WR_Optimized);
   
  
   ----------------------------------
   -- Inputs to the RAM, WRITE ACCESS
   ----------------------------------
   -- Remark: Just add the needed additional signals which should be stored in the RAM.
   -- Important: The order does not matter: There is a function that sorts the entries.

			--Node_To_Structure_F_I_PKG() returns Base + 18-bit Data in type array_accessor_t_i_pkg
			--Node_To_Structure_F_I_PKG(D_Input: std_logic_vector;   WR_Protect,						Access_Control: std_logic;			Base_AD,										Bit count,										Word_Width: natural)
		WR_Accessor(0 TO Return_Upper_F_I_PKG(Words_Needed_F_I_PKG(WR_Definition))) <= 
			Node_To_Structure_F_I_PKG(F_BSAT_UID,						WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_UID_Base_C_I_PKG,				Double_Word_Width_C_I_PKG,					Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(F_BSAT_Mem_ID,					WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Mem_ID_Base_C_I_PKG,			Word_Width_C_I_PKG,							Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(F_BSAT_Node_ID,					WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Node_ID_Base_C_I_PKG,			Word_Width_C_I_PKG,							Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(MID_Info,							WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_MID_BASE_C_I_PKG,				Word_Width_C_I_PKG,							Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Node_Mode,						WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Node_Mode_Base_C_I_PKG,		Double_Word_Width_C_I_PKG,					Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(HID_TR,							WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_HID_Base_C_I_PKG,				HID_Count,										Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Error_TR_Node,					WR_Protect_EN_n_TDP_C_I_PKG,	Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Error_Node_Base_C_I_PKG,		Error_Count_Node,								Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Error_TR_Port_0,				WR_Protect_EN_n_TDP_C_I_PKG,	Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Error_0_Base_C_I_PKG,			Error_Count_0,									Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Error_TR_Port_1,				WR_Protect_EN_n_TDP_C_I_PKG,	Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Error_1_Base_C_I_PKG,			Error_Count_1,									Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Error_TR_U,						WR_Protect_EN_n_TDP_C_I_PKG,	Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Error_U_Base_C_I_PKG,			Error_Count_U,									Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Flash_Control_Data,			WR_Protect_EN_n_TDP_C_I_PKG,	Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Node_Flash_RD_Data_Base_C_I_PKG,	Word_Width_C_I_PKG,					Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(HID_Status,						WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_HID_Status_Base_C_I_PKG,		Return_NotZero_natural_F_I_PKG(HID_Count)*Word_Width_C_I_PKG,						Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Error_Node_Status,				WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Node_Status_Base_C_I_PKG,	Return_NotZero_natural_F_I_PKG(Error_Count_Node)*Error_Count_Width_C_I_PKG,	Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Error_0_Status,					WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Port_0_Status_Base_C_I_PKG,	Return_NotZero_natural_F_I_PKG(Error_Count_0)*Error_Count_Width_C_I_PKG,		Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Error_1_Status,					WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Port_1_Status_Base_C_I_PKG,	Return_NotZero_natural_F_I_PKG(Error_Count_1)*Error_Count_Width_C_I_PKG,		Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(Error_U_Status,					WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Port_U_Status_Base_C_I_PKG,	Return_NotZero_natural_F_I_PKG(Error_Count_U)*Error_Count_Width_C_I_PKG,		Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(BSAT_MM_Board_Type,			WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Board_Type_Base_C_I_PKG,		Board_Type_Length,							Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(BSAT_MM_Board_Number,			WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Board_Number_Base_C_I_PKG,	Board_Number_Length,							Word_Width_C_I_PKG) &
			Node_To_Structure_F_I_PKG(F_BSAT_Node_Info,				WR_Protect_EN_TDP_C_I_PKG,		Access_Control_EN_n_TDP_C_I_PKG,	BSAT_MM_Node_Info_Base_C_I_PKG,		Word_Width_C_I_PKG,							Word_Width_C_I_PKG);
   --------------------------------------
   -- Inputs to the RAM, WRITE ACCESS END
   --------------------------------------

  
   ------------------------------------------------
   -- Static data outputs from the RAM, READ ACCESS
   ------------------------------------------------
   -- Remark: Just add the needed additional signals which should be fetched from the RAM.
   -- Important: The order does not matter: There is a function that sorts the entries.
										--Structure_To_Node_F_I_PKG(D_Input,	Count,				Word_Width,				Index,																										Enable)
			Node_Control			<= Structure_To_Node_F_I_PKG(RD_Array,	Double_Word_Width_C_I_PKG,	Word_Width_C_I_PKG, Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Node_Control_Base_C_I_PKG),			ON_C_I_PKG);
			HID_Mask					<= Structure_To_Node_F_I_PKG(RD_Array,	HID_Count,			Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_HID_Mask_Base_C_I_PKG),							ON_C_I_PKG);
			Error_Mask_Node		<= Structure_To_Node_F_I_PKG(RD_Array,	Error_Count_Node,	Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Error_Node_Mask_Base_C_I_PKG),				ON_C_I_PKG);
			Error_FB_Port_0		<= Structure_To_Node_F_I_PKG(RD_Array,	Error_Count_0,		Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Error_0_Base_C_I_PKG),							ON_C_I_PKG);
			Error_Mask_Port_0		<= Structure_To_Node_F_I_PKG(RD_Array,	Error_Count_0,		Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Error_0_Mask_Base_C_I_PKG),					ON_C_I_PKG);
			Error_FB_Port_1		<= Structure_To_Node_F_I_PKG(RD_Array,	Error_Count_1,		Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Error_1_Base_C_I_PKG),							ON_C_I_PKG);
			Error_Mask_Port_1		<= Structure_To_Node_F_I_PKG(RD_Array,	Error_Count_1,		Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Error_1_Mask_Base_C_I_PKG),					ON_C_I_PKG);
			Error_FB_U				<= Structure_To_Node_F_I_PKG(RD_Array,	Error_Count_U,		Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Error_U_Base_C_I_PKG),							ON_C_I_PKG);
			Error_Mask_U			<= Structure_To_Node_F_I_PKG(RD_Array,	Error_Count_U,		Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Error_U_Mask_Base_C_I_PKG),					ON_C_I_PKG);
			Control_Flash_RD_AD	<= Structure_To_Node_F_I_PKG(RD_Array,	Double_Word_Width_C_I_PKG, Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Node_Flash_RD_AD_Base_C_I_PKG),	ON_C_I_PKG);
			BSAT_Safety_Counters	<= Structure_To_Node_F_I_PKG(RD_Array,	Byte_Width_C_I_PKG,	Word_Width_C_I_PKG, Handle_Base_F_I_PKG(RD_Optimized,	BSAT_MM_Safety_Counter_Base_C_I_PKG),				ON_C_I_PKG);
			Control_Flash_WR_AD	<= Structure_To_Node_F_I_PKG(RD_Array,	Double_Word_Width_C_I_PKG, Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Node_Flash_WR_AD_Base_C_I_PKG),	ON_C_I_PKG);
			Control_Flash_Data	<= Structure_To_Node_F_I_PKG(RD_Array,	Flash_Data_Width,	Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Node_Flash_WR_Data_Base_C_I_PKG),			ON_C_I_PKG);
			Control_DL_WR_Data	<= Structure_To_Node_F_I_PKG(RD_Array,	Flash_Data_Width, Word_Width_C_I_PKG,	Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Node_DL_WR_Data_Base_C_I_PKG), 				ON_C_I_PKG);
   ----------------------------------------------------
   -- Static data outputs from the RAM, READ ACCESS END
   ----------------------------------------------------

 
   --------------------------------------------------
   -- Write Protect outputs from the RAM, READ ACCESS
   --------------------------------------------------
   -- Remark: Just add the needed Write Protect signals which should be fetched from the RAM.
   -- Important: The order does not matter: There is a function that sorts the entries.
   -- Write_Protect_Bit_Example <= Structure_To_WriteProtection_F_I_PKG(RD_Array, Example_Count, Word_Width_C_I_PKG, Handle_Base_F_I_PKG(RD_Optimized, Example_Base_C_I_PKG), ON_C_I_PKG);
   ------------------------------------------------------
   -- Write Protect outputs from the RAM, READ ACCESS END
   ------------------------------------------------------


   ---------------------------------------------------
   -- Access Control outputs from the RAM, READ ACCESS
   ---------------------------------------------------
   -- Remark: Just add the needed Access Control signals which should be fetched from the RAM.
   -- Important: The order does not matter: There is a function that sorts the entries.
   Control_DL_WR_Access <= Structure_To_AccessControl_F_I_PKG(RD_Array, Word_Width_C_I_PKG, Word_Width_C_I_PKG, Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Node_DL_WR_Data_Base_C_I_PKG), ON_C_I_PKG); -- Access control on data word
   Node_Control_Access <= Structure_To_AccessControl_F_I_PKG(RD_Array, Double_Word_Width_C_I_PKG, Word_Width_C_I_PKG, Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Node_Control_Base_C_I_PKG), ON_C_I_PKG); -- Access control ob BSAT Node Control address for DL.
   Control_Flash_RD_Access <= Structure_To_AccessControl_F_I_PKG(RD_Array, Double_Word_Width_C_I_PKG, Word_Width_C_I_PKG, Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Node_Flash_RD_AD_Base_C_I_PKG), ON_C_I_PKG); -- Access control on address
   Control_Flash_WR_Access <= Structure_To_AccessControl_F_I_PKG(RD_Array, Word_Width_C_I_PKG, Word_Width_C_I_PKG, Handle_Base_F_I_PKG(RD_Optimized, BSAT_MM_Node_Flash_WR_Data_Base_C_I_PKG), ON_C_I_PKG); -- Access control on data word
   -------------------------------------------------------
   -- Access Control outputs from the RAM, READ ACCESS END
   -------------------------------------------------------


   -----------------------------
   -- Select the correct address
   -----------------------------
   AD_Counter: PROCESS(CLK62_5, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
        Count_D_1 := 0;
        Count_D_2 := 0;
        WR_RD_n_Int := '0';
        WR_RD_n_Status_1_Int <= '0';
        A_Count_D_1:= 0;
        A_Count_D_2:= 0;
        Control_LUT_AD_B_Int <= (OTHERS => '0');
      ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
         IF (Count_D_2 = A_Count_D_2) THEN
            IF (Count_D_1 = A_Count_D_1) THEN
               Count_D_1 := 0;
               WR_RD_n_Int := NOT(WR_RD_n_Int);
            ELSE
               Count_D_1 := (Count_D_1 + 1);
            END IF;
            Count_D_2 := 0;
         ELSE
            Count_D_2 := (Count_D_2 + 1);
         END IF;
         IF (WR_RD_n_Int = '0') THEN
            A_Count_D_1:= (RD_Optimized'length(1) - 1);
            A_Count_D_2:= (RD_Optimized(Count_D_1,1) - 1);
            Control_LUT_AD_B_Int <= STD_LOGIC_VECTOR(TO_UNSIGNED(RD_Optimized(Count_D_1,0) + Count_D_2, Control_LUT_AD_B_Int'LENGTH)); -- logical (FPGA internal) address
         ELSE
            A_Count_D_1:= (WR_Optimized'length(1) - 1);
            A_Count_D_2:= (WR_Optimized(Count_D_1,1) - 1);
            Control_LUT_AD_B_Int <= STD_LOGIC_VECTOR(TO_UNSIGNED(WR_Optimized(Count_D_1,0) + Count_D_2, Control_LUT_AD_B_Int'LENGTH));
         END IF;
      END IF;   
      WR_RD_n_Status_1_Int <= WR_RD_n_Int;
   END PROCESS AD_Counter;
	
	
	-- In contrast to the GinLink Slaves we do not have a LUT RAM in the BSAT slaves. This limitation is needed otherwise we could not use the dual boot feature in a MAX10 device (the RAM can not be initialized, whe we believe in Altera/ Intel).
	AD_LUT: PROCESS(CLK62_5, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
			Control_RAM_AD_B <= (OTHERS => '0');
		ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
			Control_RAM_AD_B <= Control_LUT_AD_B_Int;
		END IF;
	END PROCESS AD_LUT;
   ---------------------------------
   -- Select the correct address END
   ---------------------------------
   
   
   ----------------
   -- WR_RD_n Delay
   ----------------
   WR_RD_n_Delay: PROCESS(CLK62_5, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Control_RAM_WREN_B <= '0';
         WR_RD_n_Status_2_Int <= '0';
         WR_RD_n_Status_3_Int <= '0';
      ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
         WR_RD_n_Status_2_Int <= WR_RD_n_Status_1_Int;
         WR_RD_n_Status_3_Int <= WR_RD_n_Status_2_Int;
         Control_RAM_WREN_B <= WR_RD_n_Status_1_Int;
      END IF;
   END PROCESS WR_RD_n_Delay;
   --------------------
   -- WR_RD_n Delay END 
   --------------------

   
   -----------------
   -- Assign Counter
   -----------------
   Assign_Counter: PROCESS(CLK62_5, CLR_n)
   BEGIN
      IF (CLR_n = '0')THEN
         Count_Assign <= 0;
      ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
         IF ((Count_D_1 = A_Count_D_1) AND (Count_D_2 = A_Count_D_2)) THEN
            Count_Assign <= 0;
         ELSE
            Count_Assign <= (Count_Assign + 1);
         END IF;
      END IF;
   END PROCESS Assign_Counter;
   ---------------------
   -- Assign Counter END
   ---------------------
   
   
   --------------
   -- Count Delay
   --------------
   Count_Delay: PROCESS(CLK62_5, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Count_1_Assign <= 0;
         Count_2_Assign <= 0;
      ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
         Count_1_Assign <= Count_Assign;
         Count_2_Assign <= Count_1_Assign;
      END IF;
   END PROCESS Count_Delay;
   ------------------
   -- Count Delay END 
   ------------------

   
   -------------
   -- RAM Access
   -------------
   -- This process reads or writes from/to the TDP_RAM.
   -- It is capable to handle every request within one cycle.
   TDP_Access: PROCESS(CLK62_5, CLR_n)
   BEGIN
      IF (CLR_n = '0') THEN
         Control_RAM_Data_B <= (OTHERS => '0');
         RD_Array <= (OTHERS => (OTHERS => '0'));
      ELSIF (CLK62_5'EVENT AND CLK62_5 = '1') THEN
         IF (WR_RD_n_Status_1_Int = '0') THEN
            Control_RAM_Data_B <= (OTHERS => '0');
         ELSE
            Control_RAM_Data_B <= WR_Array(Count_Assign);
         END IF;
         IF (WR_RD_n_Status_3_Int = '0') THEN
				RD_Array(Count_2_Assign) <= RAM_Control_Data_B;
         END IF;
      END IF;
   END PROCESS TDP_Access;
   -----------------
   -- RAM Access END
   -----------------

END Universal;