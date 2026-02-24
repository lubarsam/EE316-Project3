library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Top_Level is
        port (
		iReset				: in std_logic; 
		iClk				: in std_logic;
		clk_out					: out std_logic
        );
end Top_Level;

architecture Structural of Top_Level is

component I2C_LCD_Controller is
    Port (
        iclk        : in  std_logic;
        reset_n     : in  std_logic;

        SourceSel   : in  std_logic_vector(1 downto 0); -- 00=LDR, 01=TEMP, 10=POT
        ClockActive : in  std_logic;

        LCD_SDA     : inout std_logic;
        LCD_SCL     : inout std_logic
    );
end component;

component ADC_I2C_user_logic is							-- Modified from SPI usr logic from last year
    Port ( iclk : in STD_LOGIC;
		   ChannelSel : in std_LOGIC_VECTOR(1 downto 0);
		   EightBitDataFromADC: out std_LOGIC_VECTOR(7 downto 0);
		   dataready : out std_logic;
           oADCSDA : inout STD_LOGIC;
           oADCSCL : inout STD_LOGIC
			  );
end component;

component clock_generator is
    Port (
        clk         : in  STD_LOGIC; -- 125 MHz
        reset       : in  STD_LOGIC;
        N           : in  STD_LOGIC_VECTOR(17 downto 0);
        clk_out     : out STD_LOGIC
         
    );
end component;

component N_Maker is
    Port (
        clk     : in  STD_LOGIC; -- 125 MHz
        reset   : in  STD_LOGIC;
        ADC_in  : in  STD_LOGIC_VECTOR(7 downto 0);  -- 0 to 255
        N_out   : out STD_LOGIC_VECTOR(17 downto 0)  -- 41666 to 125000
    );
end component;

component pwm_gen is
   generic(
      N  : integer := 8;    -- Resolution (8-bit)
      N2 : integer := 255   -- Max counter value (2^8 - 1)
   );
   port(
      clk       : in std_logic;
      reset     : in std_logic;
      freq_in    : in std_logic_vector(7 downto 0); 
      pwm_out   : out std_logic
   );
end component;

-- ADC signals
signal ADCChannelSel		: std_logic_vector (1 downto 0);
signal EightBitDataFromADC	: std_logic_vector (7 downto 0);
signal dataready			: std_logic;
signal oADCSDA				: std_logic;
signal oADCSCL				: std_logic;

-- LCD signals
signal SourceSel			: std_logic_vector (1 downto 0);
signal clockActive			: std_logic;
signal LCD_SDA				: std_logic;
signal LCD_SCL				: std_logic;

-- clock gen signals
signal N_out					: std_logic_vector (17 downto 0);
begin

inst_adc_i2c : ADC_I2C_user_logic
	port map(
	iclk				=> iClk,
	ChannelSel			=> ADCChannelSel,
	EightBitDataFromADC	=> EightBitDataFromADC,
	dataready			=> dataready,
	oADCSDA				=> oADCSDA,
	oADCSCL				=> oADCSCL
	);

inst_lcd_i2c : I2C_LCD_Controller
	port map(
	iclk				=> iClk,
	reset_n				=> iReset,
	SourceSel			=> SourceSel,
	ClockActive			=> clockActive,
	LCD_SDA				=> LCD_SDA,
	LCD_SCL				=> LCD_SCL
	);

inst_clock_gen : clock_generator
	port map (
	clk					=> iClk,
	reset				=> iReset,
	N					=> N_out,
	clk_out				=> clk_out
	);

inst_N_Maker : N_Maker
	port map (
	clk					=> iClk,
	reset				=> iReset,
	ADC_in				=> EightBitDataFromADC,
	N_out				=> N_out
	);
	
inst_pwm_gen : pwm_gen
	port map (
	clk					=> clk_out,
	reset				=> iReset,
	freq_in				=> open,
	pwm_out				=> open
	);
end Structural;