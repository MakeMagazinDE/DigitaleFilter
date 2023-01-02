// Make: 6/22 Digital filtern und oszillieren
// Einfache Hochpass- und Tiefpassfilter mit ESP32
//
// siehe zum Interrupt-Handling beim ESP32 auch:
// https://techtutorialsx.com/2017/09/30/esp32-arduino-external-interrupts/
// und
// https://techtutorialsx.com/2017/10/07/esp32-arduino-timer-interrupts/

const int dac_pin = 25;
const int adc_pin = 34;
int32_t led_count;

// ############################################################################
// ###                             Timer-Interrupt                          ###
// ############################################################################

// Statt eines Semaphors vom Boolean-Typ verwenden wir hier eine
// Zähler-Variable. Dies hat den Vorteil, dass das Hauptprogramm
// auch mehrere Interrupts lang unterbrochen werden kann,
// ohne dass Filteroperationen verlorengehen.

volatile int irq_sema;
hw_timer_t * timer = NULL;
portMUX_TYPE timerMux = portMUX_INITIALIZER_UNLOCKED;

void IRAM_ATTR onTimer() {
  // Interrupt-Service Routine: Semaphor setzen
  portENTER_CRITICAL_ISR(&timerMux);
  irq_sema++;
  portEXIT_CRITICAL_ISR(&timerMux);
}

// ############################################################################
// ###                          Setup Timer-Interrupt                       ###
// ############################################################################

void setup() {
  pinMode(32, OUTPUT);
  Serial.begin(115200);
  // Interrupt-Timer initialisieren
  timer = timerBegin(0, 80, true);
  timerAttachInterrupt(timer, &onTimer, true);
  // Sampling rate in µs einstellen, 1000 = 1ms, 10000000 = 1 Sekunde
  timerAlarmWrite(timer, 100, true); // 10 kHz Sampling
  timerAlarmEnable(timer);
  // ADC einstellen
  analogSetClockDiv(4); 
  analogSetAttenuation(ADC_11db); // Eingangsbereich 0..2,6V
  led_count = 0;
}

// ############################################################################
// ###                  Tiefpass- und Hochpass-Filter                       ###
// ############################################################################

// Um Gleitkomma-Operationen zu vermeiden, arbeiten wir hier mit
// einem festen 8-Bit-"Nachkomma", das Ergebnis muss also um 8 Bit nach
// rechts verschoben werden.
// Überschlägige Frequenzberechnung bei 10kHz Samplingrate:
// f = kf * 6,23 Hz 
// Mit kf = 1  (1/256 = "0,003906") beträgt die -3dB-Grenzfrequenz also 6,23 Hz,
// mit kf = 10 (10/256 = "0,078") etwa 63 Hz,
// mit kf = 20 (20/256 = "0,078") etwa 126 Hz usw.
// kf-Werte über "0.5" = 128 sind wenig sinnvoll. 

int32_t lpfilter_6db(int32_t inp) {
  static int32_t delayed;
  int32_t k2 = 20;  // 128 = "0.5", 20 = "0,078"
  int32_t diff = ((inp << 8) - delayed) * k2; 
  delayed = delayed + (diff >> 8);
  return (delayed >> 8); // Differenz ergibt Hochpass
}

int32_t hpfilter_6db(int32_t inp) {
  static int32_t delayed;
  int32_t k2 = 20;  // 128 = "0.5", 20 = "0,078"
  int32_t diff = ((inp << 8) - delayed) * k2; 
  delayed = delayed + (diff >> 8);
  return inp - (delayed >> 8);
}

int32_t lpfilter_12db(int32_t inp) {
  static int32_t delayed_1, delayed_2;
  int32_t k2 = 20;  // 128 = "0.5", 20 = "0,078"
  int32_t diff = ((inp << 8) - delayed_1) * k2; 
  delayed_1 = delayed_1 + (diff >> 8);
  diff = (delayed_1 - delayed_2) * k2; 
  delayed_2 = delayed_2 + (diff >> 8);  
  return (delayed_2 >> 8);
}

int32_t biquad_filt(int32_t inp, int32_t kf, int32_t kq) {
  static int32_t bp_del, lp_del, hp;
  hp = (inp << 8) - ((bp_del * kq) >> 8) - lp_del;
  bp_del = bp_del + ((hp * kf) >> 8);
  lp_del = lp_del + ((bp_del * kf) >> 8);
  // Hochpass in hp,
  // Bandpass in bp_del,
  // Tiefpass in lp_del
  return (bp_del >> 8);  
}

// ############################################################################
// ###                                MAIN LOOP                             ###
// ############################################################################

void loop() {
  int32_t dac_val, adc_val;

  // Dieser Teil wird ausgeführt, wenn der 
  // Interrupt die Semaphore irq_sema gesetzt hat
  if (irq_sema > 0) {
    portENTER_CRITICAL(&timerMux);
    irq_sema--;  // Semaphor zurücksetzen
    portEXIT_CRITICAL(&timerMux);

    adc_val = analogRead(adc_pin) >> 4; // auf 8 Bit bringen
    // Da der "Gleichspannungsanteil" durch ein Hochpassfilter entfernt
    // wird und der DAC keine negativen Spannungen ausgeben kann, 
    // muss hier ein Offset von 128 (halber Maximalwert 
    // des DAC-Bereiches) hinzuaddiert werden:
    
    // dac_val = hpfilter_6db(adc_val) + 128;  // Hochpassfilter
    // dacWrite(dac_pin, dac_val + 128); //

    // Tiefpassfilter lässt "Gleichspannungsanteil" vom ADC 
    // unverändert durch, deshalb kein DAC-Offset nötig:
    
    // dac_val = lpfilter_6db(adc_val); // Tiefpassfilter 6dB/Okt.
    // dacWrite(dac_pin, dac_val); //

    // Das 12dB/Oktave-Filter besteht aus zwei hintereinandergeschalteten
    // 6-dB-Filtern:
    
    // dac_val = lpfilter_12db(adc_val); // Tiefpassfilter 12dB/Okt.
    // dacWrite(dac_pin, dac_val); //

    // Biquad-12dB-Filter, hier als Bandpass
    
    dac_val = biquad_filt(adc_val, 32, 80);  // 32 = 100 Hz, hohe Güte
    dacWrite(dac_pin, dac_val + 128); // Bandpass und Hochpass mit Offset 128!

    // schnell blinkende LED zur Interrupt-Kontrolle
    led_count++;
    if (led_count == 1000) 
      digitalWrite(32, HIGH);
    if (led_count > 2000) { 
      digitalWrite(32, LOW);
      led_count = 0;
    }
  }
}
