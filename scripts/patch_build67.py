"""Build 67: COLMI HRV proxy history (timestamped), ring transport diagnostics.

The command 57 response is a split array: header index 0, subsequent pages
with a slot offset at byte 2 and values at bytes 3..14. Do not treat the
firmware-derived proxy as verified RMSSD, HRV in milliseconds, or AFib evidence.
No firmware changes, new vendor pairing or changes to Garmin/notifications.
"""
from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if new in s:
        return
    if s.count(old) != 1:
        raise RuntimeError(f'{path}: patch anchor expected once, got {s.count(old)}: {old[:90]}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')


replace('pubspec.yaml', 'version: 0.21.28+66', 'version: 0.21.29+67')

replace('native/android/SalusProtocolReader.kt',
'''        private var ringHrvPageCount = 0
        private var ringHrvProxySum = 0
        private var ringHrvProxyCount = 0''',
'''        // Firmware HRV is a relative, one-byte-per-slot proxy, NOT RMSSD.
        private val ringHrvLog = SalusRingHrvLogDecoder()
        private var ringStepPacketCount = 0
        private var ringStepComplete = false''')

replace('native/android/SalusProtocolReader.kt',
'''            if (ringHrvProxyCount > 0) {
                metrics["Ring HRV proxy"] =
                    ringHrvProxySum.toDouble() / ringHrvProxyCount.toDouble()
            }''',
'''            // Do not average slot-index and sentinel bytes into an invented
            // point-in-time HRV measurement. Valid proxy buckets are stored as
            // individually timestamped history, never clinical HRV.
            if (mode == "ring") {
                notes.add("Ring HRV proxy: ${ringHrvLog.decoded} timed buckets; " +
                    "${ringHrvLog.invalidPackets} rejected packets.")
                if (!ringStepComplete) {
                    notes.add("Ring step history incomplete: " +
                        "$ringStepPacketCount data packets, no final record.")
                }
            }''')

replace('native/android/SalusProtocolReader.kt',
'''                        } else {
                            emptyMap<String, Int>()
                        },''',
'''                        } else if (mode == "ring") {
                            mapOf(
                                "ringHrvProxySamples" to ringHrvLog.decoded,
                                "ringHrvPages" to ringHrvLog.pageCount,
                                "ringHrvInvalidPackets" to ringHrvLog.invalidPackets,
                                "ringStepPackets" to ringStepPacketCount,
                                "ringStepsComplete" to if (ringStepComplete) 1 else 0,
                            )
                        } else {
                            emptyMap<String, Int>()
                        },''')

replace('native/android/SalusProtocolReader.kt',
'''                    if (packet.size >= 13) {
                        var calories = u16(packet, 7)''',
'''                    if (packet.size >= 13) {
                        ringStepPacketCount++
                        var calories = u16(packet, 7)''')

replace('native/android/SalusProtocolReader.kt',
'''                        if (recordCount > 0 && recordIndex >= recordCount - 1) {
                            metrics["Steps"] = ringStepTotal.toDouble()''',
'''                        if (recordCount > 0 && recordIndex >= recordCount - 1) {
                            ringStepComplete = true
                            metrics["Steps"] = ringStepTotal.toDouble()''')

replace('native/android/SalusProtocolReader.kt',
'''                57 -> {
                    val index = packet[1].toInt() and 0xff
                    if (index == 0xff) return
                    if (index == 0) {
                        ringHrvPageCount =
                            if (packet.size > 2) packet[2].toInt() and 0xff else 0
                        for (page in 1..ringHrvPageCount) {
                            mainHandler.postDelayed(
                                { ringSend(57, byteArrayOf(page.toByte())) },
                                page * 120L,
                            )
                        }
                        return
                    }
                    for (position in 3 until minOf(packet.size - 1, 15)) {
                        val value = packet[position].toInt() and 0xff
                        if (value != 0 && value != 0xff) {
                            ringHrvProxySum += value
                            ringHrvProxyCount += 1
                        }
                    }
                }''',
'''                57 -> {
                    val index = packet[1].toInt() and 0xff
                    val midnight = dayTimestamp(0)
                    val expectedBefore = ringHrvLog.expectedPage
                    val readings = ringHrvLog.parse(
                        packet, midnight, System.currentTimeMillis(),
                    )
                    for (reading in readings) {
                        addHistoryMetric(
                            "Ring HRV proxy", reading.value.toDouble(), reading.timestampMs,
                        )
                    }
                    // Sequential requests prevent burst writes to the BLE UART.
                    // Never send firmware/settings commands, just history pages.
                    val nextPage = ringHrvLog.expectedPage
                    val accepted = index == 0 && ringHrvLog.headerReceived ||
                        index > 0 && nextPage > expectedBefore
                    if (accepted && nextPage in 1..ringHrvLog.pageCount &&
                        !completed.get()) {
                        mainHandler.postDelayed(
                            { if (!completed.get()) ringSend(57, byteArrayOf(nextPage.toByte())) },
                            160L,
                        )
                    }
                }''')

# A single ring-only section displaying the last decoded proxy time buckets.
replace('lib/screens/device_information_screen.dart',
'''  List<DirectMetricSample> _observed = const [];
  bool _loading = false;''',
'''  List<DirectMetricSample> _observed = const [];
  List<DirectMetricSample> _ringHrvHistory = const [];
  bool _loading = false;''')

replace('lib/screens/device_information_screen.dart',
'''    setState(() {
      _info = cached;
      _observed = sorted;
    });''',
'''    final ringHrv = samples.where((s) =>
        s.deviceId == widget.device.id && s.metric == 'Ring HRV proxy').toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    setState(() {
      _info = cached;
      _observed = sorted;
      _ringHrvHistory = ringHrv;
    });''')

replace('lib/screens/device_information_screen.dart',
'''          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('A received measurement confirms data transport, not ''' ,
'''          if (widget.device.protocolId == 'ring-uart-v1')
            _section('Ring HRV firmware proxy history', Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Experimental firmware values. NOT validated RMSSD, '
                    'milliseconds, AFib detection or a Recovery input.',
                    style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
                const SizedBox(height: 10),
                if (_ringHrvHistory.isEmpty)
                  const Text('No timed HRV proxy buckets received yet. '
                      'Sync the ring in Connections, then reopen this screen.'),
                for (final sample in _ringHrvHistory.take(24))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('${_date(sample.capturedAt)}  •  '
                        '${sample.value.toStringAsFixed(0)} (firmware proxy)'),
                  ),
              ],
            )),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('A received measurement confirms data transport, not ''')
