--------------------------------------------------------------------------------
-- FILTER 1. Ordnung als Hoch- oder Tiefpass
-- by Carsten Meyer, cm@ct.de, 10/2011
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;
--use IEEE.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

entity highpass_6 is
	generic (
		FREQU: Integer range 0 to 7:=3 	-- 1=5500, 2=2250, 3=1050, 4=510, 5=255, 6=125, 7=62 Hz
		);
	port (
		SYSCLK	: in std_logic;
		SYNC		: in std_logic;
		INP	: in std_logic_vector (15 downto 0);	-- input wave data
		OUT_6 : out std_logic_vector(15 downto 0);
		OUT_12 : out std_logic_vector(15 downto 0)
	);
end entity highpass_6;

architecture behave of highpass_6 is
	
	signal in_temp_6, out_temp_6, adder_6, diff_6: std_logic_vector (24 downto 0) := (others => '0');

begin

in_temp_6(23 downto 8) <= INP;
in_temp_6(24) <= INP(15);


--OUT_6 <= diff_6(23 downto 8);	-- Hochpass 6 dB/Okt., nicht ganz pegelfest bei abrupten starken Sprüngen
--OUT_6 <= out_temp_6(23 downto 8);	-- Tiefpass 6 dB/Okt.
--diff_6 <= in_temp_6 - out_temp_6;	-- hier bei Tiefpass

-- Bei Überlauf Hochpass-Ausgang begrenzen auf Integer-Maximalwerte
OUT_6 <= x"7FFF" when diff_6(24 downto 23) = "01" -- positiver Überlauf
		else x"8000" when diff_6(24 downto 23) = "10"	-- negativer Überlauf
		else diff_6(23 downto 8); -- kein überlauf

adder_6 <= to_stdlogicvector(to_bitvector(diff_6) sra FREQU);


delay_register: process (SYSCLK)
begin
	if rising_edge(SYSCLK) then
	  
		diff_6 <= in_temp_6 - out_temp_6; -- hier bei Hochpass
		if SYNC = '1' then
			out_temp_6 <= out_temp_6 + adder_6;
		end if;
	end if;
end process;

end behave;