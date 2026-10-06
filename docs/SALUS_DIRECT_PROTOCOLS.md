# Salus direct protocol readers — Build 27

Build 27 adds read-only device-family readers for hardware observed during Salus testing.

## COLMI / QRing R02 family

The reader uses the ring's command UART and Big Data services directly. It asks the device for battery, today's step buckets, today's periodic heart-rate log, the ring firmware's HRV proxy, retained sleep/stages, and retained SpO2 history.

The firmware HRV value is stored as **Ring HRV proxy** and is deliberately not routed into Salus' HRV metric because it is not beat-to-beat RMSSD.

The wire format is implemented in Salus from public protocol documentation. The MIT-licensed openring project was used as a cross-check for command numbers, packet framing, and history layouts.

## Garmin Multi-Link

The reader uses the Garmin Multi-Link service and 2810/2820 receive/send pair observed on the vivoactive 6. It establishes the Multi-Link/GFDI channel and registers realtime services for heart rate, steps, RR/HRV, SpO2, and respiration. Salus stores only metrics that actually arrive from the watch.

This Build 27 Garmin reader is a realtime reader. Historical Garmin sleep and wellness FIT download is a separate GFDI file-sync layer and is not claimed by this build.
