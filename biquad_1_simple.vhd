--------------------------------------------------------------------------------
-- Biquad-Filter, einfach, ohne Multiplizierer
-- Frequenzeinstellung durch Anzahl der Oversampling-Ticks
-- Idee und Implementierung (c) C. Meyer 3/2014
--------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity biquad_1_simple is
	GENERIC (
		-- SHIFTS bestimmt Frequenzbereich (Bandpass-Mittenfrequenz) und Schrittweite, 
		-- mit 10 => bis 2 kHz bei KF_x = 255, 750 Hz bei 100,  Auflösung 7,5 Hz
		-- mit  9 => bis 4 kHz bei KF_x = 255, 1,5 kHz bei 100, Auflösung  15 Hz 
		-- mit  8 => bis 8 kHz bei KF_x = 255, 3 kHz bei 100,   Auflösung  30 Hz
		SHIFTS: Integer range 0 to 11:= 8;	
		-- KQ bestimmt Peaking jedes einzelnen Filters, 
		-- 0 = kein Peak, 1 = leicht bis 4 = sehr stark (Vorsicht, Übersteuerung!)
	   KQ: Integer range 0 to 4:= 1 
		);
	PORT (
		SYSCLK	: in std_logic;
		SYNC		: in std_logic;							-- Sampling-Tick 48 kHz
		INP	: in std_logic_vector (15 downto 0);	-- Audiodaten
		KF	: in std_logic_vector (7 downto 0);			-- Frequenzeinstellung
		HP: OUT std_logic_vector (15 downto 0);		-- Hochpass Ausgang
		LP: OUT std_logic_vector (15 downto 0);		-- Tiefpass Ausgang
		BP: OUT std_logic_vector (15 downto 0)			-- Bandpass Ausgang
);
end entity biquad_1_simple;

architecture behave of biquad_1_simple is

	signal inp_arr, lp_input_arr, lp_added_arr, bp_input_arr, pb_kq_arr,
		lp_arr, bp_arr, hp_arr: std_logic_vector (27 downto 0):= (others => '0');

	signal kf_arr:std_logic_vector (8 downto 0):= (others => '0');

	signal tick_count: std_logic_vector (8 downto 0):= (others => '0');
	signal delay_tick: std_logic:= '0';
	signal prescaler: std_logic:= '0';
begin
	
counters: process (SYSCLK)
begin
	if rising_edge(SYSCLK) then
		delay_tick <= '0';
		prescaler <= not prescaler;	-- Vorteiler wg. zweistufiger Delay-Pipeline
		if prescaler = '1' then
			if tick_count(8) = '0' then
				if tick_count < kf_arr then
					delay_tick <= '1';
				end if;
				tick_count <= tick_count +1;
			end if;
		end if;
		
		if SYNC = '1' then
			tick_count <= (others => '0');
			prescaler <= '0';
			
			kf_arr <= '0' & KF;	-- immer positiv
			inp_arr <= INP(15) & INP & "00000000000"; -- Eingangswerte skaliert mit 1 Bit Headroom
			LP <= lp_added_arr(27 downto 12);
			HP <= hp_arr(27 downto 12);
			BP <= bp_arr(27 downto 12);
		end if;
	end if;
end process;

-- KQ-Faktor:
-- Q = 2     mit KQ = 0 (shift left 1), neutrales Filter ohne Peak
-- Q = 1     mit KQ = 1 (kein Shift), Filter mit leichtem Peak
-- Q = 0.5   mit KQ = 2
-- Q = 0.25  mit KQ = 3 ausgeprägter Peak (Vorsicht vor Übersteuerung!)
-- Q = 0.125 mit KQ = 4 sehr starker Peak (Vorsicht vor Übersteuerung!)
pb_kq_arr <= to_stdlogicvector((to_bitvector(bp_arr) sla 1) sra KQ); 

hp_arr <= inp_arr - lp_added_arr - pb_kq_arr; 
bp_input_arr <= to_stdlogicvector(to_bitvector(hp_arr) sra SHIFTS); -- kf-Multiplier 1, 1/256 = 32 Hz
lp_input_arr <= to_stdlogicvector(to_bitvector(bp_arr) sra SHIFTS); -- kf-Multiplier 2, 1/256 = 32 Hz
lp_added_arr <= lp_arr + lp_input_arr;


delay_register: process (SYSCLK)
begin
	if rising_edge(SYSCLK) then
		-- zwei 24-Bit-Integratoren updaten
		if delay_tick = '1' then	
			bp_arr <= bp_arr + bp_input_arr;
			lp_arr <= lp_added_arr;
		end if;
	end if;
end process;

end behave;