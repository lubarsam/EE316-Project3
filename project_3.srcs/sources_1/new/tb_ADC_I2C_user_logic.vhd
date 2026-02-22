----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/15/2026 04:39:52 PM
-- Design Name: 
-- Module Name: tb_ADC_I2C_user_logic - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_ADC_I2C_user_logic is
--  Port ( );
end tb_ADC_I2C_user_logic;

architecture Behavioral of tb_ADC_I2C_user_logic is

component ADC_I2C_user_logic is							-- Modified from SPI usr logic from last year
    Port ( iclk : in STD_LOGIC;
		   ChannelSel : in std_LOGIC_VECTOR(1 downto 0);
		   EightBitDataFromADC: out std_LOGIC_VECTOR(7 downto 0);
		   dataready : out std_logic;
           oADCSDA : inout STD_LOGIC;
           oADCSCL : inout STD_LOGIC
			  );
end component;

signal iclk                 : STD_LOGIC:='0';
signal ChannelSel           : std_LOGIC_VECTOR(1 downto 0);
signal EightBitDataFromADC  : std_LOGIC_VECTOR(7 downto 0);
signal dataready            : std_logic;
signal oADCSDA              : STD_LOGIC;
signal oADCSCL              : STD_LOGIC;

begin
iclk <= not iclk after 4 ns;
UUT: ADC_I2C_user_logic							-- Modified from SPI usr logic from last year
    Port map( iclk              => iclk,
		   ChannelSel           => ChannelSel,
		   EightBitDataFromADC  => EightBitDataFromADC,
		   dataready            => dataready,
           oADCSDA              => oADCSDA,
           oADCSCL              => oADCSCL
			  );

process
begin
ChannelSel <= "01";
wait for 1 ms;

wait;
end process;
    


end Behavioral;
