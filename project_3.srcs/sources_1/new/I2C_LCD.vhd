----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/17/2026 01:55:01 PM
-- Design Name: 
-- Module Name: I2C_LCD - Behavioral
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
use IEEE.NUMERIC_STD.ALL;


entity I2C_LCD is
  generic (
  addr		: std_logic_vector(6 downto 0) := "1001000"	-- PCF8591 address 0x90
  );
  Port ( 
  clk		: in std_logic;
  rst		: in std_logic;
  sda		: inout std_logic;
  scl		: inout std_logic;
  data		: in std_logic_vector(7 downto 0)
  
  );
end I2C_LCD;

architecture Behavioral of I2C_LCD is
signal data_UB	: std_logic_vector(3 downto 0);
signal data_LB	: std_logic_vector(3 downto 0);
begin
data_UB <= data(7 downto 4);
data_LB	<= data(3 downto 0);

end Behavioral;
