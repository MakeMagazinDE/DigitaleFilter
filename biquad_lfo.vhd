--------------------------------------------------------------------------------
-- Oszillierendes Biquad-Filter, einfach, ohne Multiplizierer
-- Frequenzeinstellung durch Anzahl der Oversampling-Ticks
-- Idee und Implementierung (c) C. Meyer 3/2014
--------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity biquad_lfo is
	generic (
		-- SHIFTS bestimmt Frequenzbereich und Schrittweite, 
		-- mit 12 und KF = 100 => 189 Hz
		-- mit 13 und KF = 100 => 94,7 Hz
		-- mit 14 und KF = 100 => 47,3 Hz
		-- mit 15 und KF = 100 => 23,6 Hz, für 6,8 Hz KF = 29 = $1D
		-- höhere SHIFTs halbieren, kleinere verdoppeln Frequenz
		SHIFTS: Integer range 0 to 15:= 15	
		);
	port (
		SYSCLK	: in std_logic;
		SYNC		: in std_logic;							-- Sampling-Tick 48 kHz
		KF	: in std_logic_vector (7 downto 0);			-- Frequenzeinstellung
		SINE: OUT std_logic_vector (11 downto 0);			-- Sinus Ausgang
		COSINE: OUT std_logic_vector (11 downto 0)			-- Cosinus Ausgang
);
end entity biquad_lfo;

architecture behave of biquad_lfo is

	signal sine_extd, inp_sine_extd, shifted_sine_extd: std_logic_vector (27 downto 0):= (others => '0');
	signal inp_cosine_extd, cosine_extd: std_logic_vector (27 downto 0):= x"7FF0000"; -- voller Pegel

	signal kf_8:std_logic_vector (8 downto 0):= (others => '0');

	signal tick_count: std_logic_vector (8 downto 0):= (others => '0');
	signal delay_tick: std_logic:= '0';
	signal toggle: std_logic:= '0';
--	signal prescaler: std_logic_vector (1 downto 0):= (others => '0');

begin
	
counters: process (SYSCLK)
begin
	if rising_edge(SYSCLK) then
		delay_tick <= '0';
		toggle <= not toggle;	-- Vorteiler wg. zweistufiger Delay-Pipeline
		if toggle = '1' then
			if tick_count(8) = '0' then
				if tick_count < kf_8 then
					delay_tick <= '1';
				end if;
				tick_count <= tick_count +1;
			end if;
		end if;
		
		if SYNC = '1' then
--			prescaler <= prescaler +1;
			tick_count <= (others => '0');
			toggle <= '0';
			kf_8 <= '0' & KF;	-- immer positiv
			SINE <= x"800" + sine_extd(27 downto 16);
			COSINE <= x"800" + cosine_extd(27 downto 16);
		end if;
--		if prescaler = 0 then
--			tick_count <= (others => '0');
--			toggle <= '0';
--			kf_8 <= '0' & KF;	-- immer positiv
--			SINE <= sine_extd(23 downto 12);
--			COSINE <= cosine_extd(23 downto 12);
--		end if;
	end if;
end process;

inp_cosine_extd <= to_stdlogicvector(to_bitvector(inp_sine_extd) sra SHIFTS); -- kf-Multiplier 1, 1/256 = 32 Hz
shifted_sine_extd <= to_stdlogicvector(to_bitvector(cosine_extd) sra SHIFTS); -- kf-Multiplier 2, 1/256 = 32 Hz
inp_sine_extd <= shifted_sine_extd + sine_extd;


delay_register: process (SYSCLK)
begin
	if rising_edge(SYSCLK) then
		-- zwei 24-Bit-Integratoren updaten
		if delay_tick = '1' then	
			cosine_extd <= cosine_extd - inp_cosine_extd;
			sine_extd <= inp_sine_extd;
		end if;
	end if;
end process;

end behave;