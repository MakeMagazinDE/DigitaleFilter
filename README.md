![GitHub Logo](http://www.heise.de/make/icons/make_logo.png)

Maker Media GmbH


![Aufmacher](https://github.com/MakeMagazinDE/DigitaleFilter/blob/main/aufm_kl.JPG)

# Digital filtern und oszillieren



Signalverarbeitung in Kürzewürze: Mit nur drei Programmzeilen kann man Messwerte filtern und interpolieren, mit fünf Zeilen Sinus- und Cosinusschwingungen erzeugen und mit sieben ein Bandpassfilter realisieren - ganz ohne Fließkomma- oder gar Trigonometrie-Funktionen, sondern nur mit Bit-Shifts und Ganzzahl-Multiplikationen. Unsere Programmschnipsel eignen sich prima für kleine Mikrocontroller und kompakte FPGA-Implementationen und kommen ohne den sonst üblichen mathematischen Overkill aus.

Alle Beispiele für den ESP32 sind im Arduino-Sketch **filter_osc.ino** enthalten, einzelne Teile sind durch Entfernen der "//" zu aktivieren.

Zusätzlich stellen wir einige VHDL-Dateien zur Implementierung der Filter und eines Oszillators auf einem FPGA zur Verfügung.
