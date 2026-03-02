library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Top_Level is
        port (
        iReset              : in std_logic; 
        iClk                : in std_logic;
        clk_out             : out std_logic;
        btn0                : in std_logic;
        btn1                : in std_logic;
        btn2                : in std_logic;
        btn3                : in std_logic;
        LCD_SDA             : inout std_logic;
        LCD_SCL             : inout std_logic;
        oADCSDA             : inout std_logic;
        oADCSCL             : inout std_logic;
        waveform_gen        : in std_logic;
        lowpass_in          : in std_logic;
        lowpass_o           : out std_logic;
        LED0                   : out std_logic;
        LED1                    : out std_logic;
        LED2                    : out std_logic;
        LED3                    : out std_logic
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

    component ADC_I2C_user_logic is
        Port ( 
            iclk                : in STD_LOGIC;
            ChannelSel          : in std_LOGIC_VECTOR(1 downto 0);
            EightBitDataFromADC : out std_LOGIC_VECTOR(7 downto 0);
            dataready           : out std_logic;
            oADCSDA             : inout STD_LOGIC;
            oADCSCL             : inout STD_LOGIC
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
          freq_in   : in std_logic_vector(7 downto 0); 
          pwm_out   : out std_logic
       );
    end component;



component ModeSM_P3 is
        Port (
            iClk				: in std_logic;
            Reset		    	: in std_logic;	
            Btn1                : in std_logic;
            Btn2                : in std_logic;
            Btn3                : in std_logic;
            ADC_Mode            : out std_LOGIC_VECTOR(1 downto 0);
            PWM_Mode            : out std_logic;
            Pencile             : out std_logic;
            LED0                : out std_logic;
            LED1                : out std_logic;
            LED2                : out std_logic;
            LED3                : out std_logic
        );
    end component;


component btn_debounce_toggle is
	generic ( CNTR_MAX: STD_LOGIC_VECTOR(15 downto 0) := X"FFFF"); 
    Port ( BTN_I 				: in   STD_LOGIC;
           CLK 				: in   STD_LOGIC;
           BTN_O 				: out  STD_LOGIC;
           TOGGLE_O	   	: out  STD_LOGIC;
		   PULSE_O 		   : out  STD_LOGIC);
	end component;


    -- ==========================================
    -- INTERNAL SIGNALS
    -- ==========================================
    signal EightBitDataFromADC  : std_logic_vector (7 downto 0);
    signal dataready            : std_logic;
    signal SourceSel            : std_logic_vector (1 downto 0);
    signal clockActive          : std_logic := '1'; -- Defaulted to 1 so LCD updates
    signal N_out_sig            : std_logic_vector (17 downto 0);

    -- STATE MACHINE SIGNALS
    type state_type is (Light, Res, Temp, Sample);
    signal current_state : state_type := Light;
    signal btn1_prev     : std_logic := '0';
    signal btn1_rise     : std_logic := '0';
    signal state_val     : std_logic_vector(1 downto 0);

   signal btn0_o       : std_logic;
   signal btn1_o       : std_logic;
   signal btn2_o       : std_logic;
    
    

begin

    -- ==========================================
    -- COMPONENT INSTANTIATIONS
    -- ==========================================
    inst_adc_i2c : ADC_I2C_user_logic
        port map(
            iclk                => iClk,
            ChannelSel          => state_val, -- Example: using btn 1 and 2 for channel
            EightBitDataFromADC => EightBitDataFromADC,
            dataready           => dataready,
            oADCSDA             => oADCSDA,
            oADCSCL             => oADCSCL
        );

    inst_lcd_i2c : I2C_LCD_Controller
        port map(
            iclk        => iClk,
            reset_n     => btn0_o,
            SourceSel   => SourceSel,
            ClockActive => clockActive,
            LCD_SDA     => LCD_SDA,
            LCD_SCL     => LCD_SCL
        );

    inst_clock_gen : clock_generator
        port map (
            clk     => iClk,
            reset   => btn0_o,
            N       => N_out_sig,
            clk_out => clk_out
        );

    inst_N_Maker : N_Maker
        port map (
            clk     => iClk,
            reset   => btn0_o,
            ADC_in  => EightBitDataFromADC,
            N_out   => N_out_sig
        );
        
        
       inst_ModeSM_P3 : ModeSM_P3
        port map (
            iClk     => iClk,
            reset   => btn0_o,
            ADC_Mode  => state_val,
            Btn1     => btn1_o,
            Btn2     => btn2,
            Btn3     => btn3,
            LED0     =>  LED0,
            LED1     =>LED1,
            LED2     =>LED2,
            LED3     =>LED3
           -- N_out   => N_out_sig
        );  
        
        debounce_bnt0 : entity work.btn_debounce_toggle
        generic map ( CNTR_MAX => X"0FFF" )
        port map (
            BTN_I    => btn0,
            CLK      => iClk,
            BTN_O    => open,
            TOGGLE_O => open,
            PULSE_O  => btn0_o
        );

    -- Debounce DT (Encoder B)
    debounce_bnt1 : entity work.btn_debounce_toggle
        generic map ( CNTR_MAX => X"0FFF" )
        port map (
            BTN_I    => btn1,
            CLK      => iClk,
            BTN_O    => open,
            TOGGLE_O => open,
            PULSE_O  => btn1_o
        );

    -- Debounce SW (Encoder push button)
    debounce_bnt2 : entity work.btn_debounce_toggle
        generic map ( CNTR_MAX => X"0FFF" )
        port map (
            BTN_I    => btn2,
            CLK      => iClk,
            BTN_O    => open,
            TOGGLE_O => open,
            PULSE_O  => btn2_o
        );

   

end Structural;