# Build 82: COLMI R02 HRV-index visibility, not an RMSSD conversion

The ring's native UART command 57 yields timestamped one-byte **firmware HRV proxy** readings. Salus already stores them as `Ring HRV proxy`, while the standard HRV screens and Recovery require validated `HRV` (RMSSD in milliseconds). Selecting the BLE ring for HRV does not transform that firmware index into RMSSD.

This build makes the saved ring-index trend, latest index, origin, timestamps and record count visible on HRV detail and Home. A forced refresh requests another BLE poll and reloads the records. If there are zero imported readings, the UI says so instead of claiming the ring has no data. Selecting a ring is allowed but the source sheet explains the distinction.

**No change** to the verified HRV metric, Recovery scoring thresholds, native BLE protocols, Health Connect access, data storage keys, device IDs, signing, Android package ID, theme or module navigation. The proprietary index is not medically validated and is deliberately not labeled `ms` or incorporated into Recovery.

If the QRing app shows HRV that does not enter Salus as index records, the next step is to compare a sanitized ring BLE command-57 diagnostic and firmware version with the QRing screen—not guess a conversion or overwrite clinical records.
