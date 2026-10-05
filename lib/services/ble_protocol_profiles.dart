class BleProtocolProfile {
  final String id;
  final String label;
  final Set<String> requiredServices;
  final List<String> capabilities;
  final String note;

  const BleProtocolProfile({
    required this.id,
    required this.label,
    required this.requiredServices,
    required this.capabilities,
    required this.note,
  });

  bool matches(Set<String> services) =>
      requiredServices.every(services.contains);
}

class BleCapabilityReport {
  final List<String> standardCapabilities;
  final BleProtocolProfile? protocolProfile;

  const BleCapabilityReport({
    required this.standardCapabilities,
    this.protocolProfile,
  });

  List<String> get allCapabilities => <String>{
        ...standardCapabilities,
        ...?protocolProfile?.capabilities,
      }.toList();
}

class BleProtocolProfiles {
  static const String bluetoothBaseSuffix =
      '-0000-1000-8000-00805f9b34fb';

  // Protocol fingerprint, not a manufacturer/UI dependency.
  static const String ringUartService =
      '6e40fff0-b5a3-f393-e0a9-e50e24dcca9e';
  static const String ringBigDataService =
      'de5bf728-d711-4e47-af26-65e3012a5dc7';

  static const profiles = <BleProtocolProfile>[
    BleProtocolProfile(
      id: 'ring-uart-v1',
      label: 'Open ring UART protocol',
      requiredServices: {ringUartService},
      capabilities: [
        'Heart rate',
        'SpO₂',
        'Steps',
        'Sleep',
        'HRV',
      ],
      note:
          'This service fingerprint has a known request/response protocol. '
          'Salus may send transport requests to read metrics, but does not '
          'write health values or change device settings.',
    ),
  ];

  static const Map<String, List<String>> _standardServiceCapabilities = {
    '0000180d-0000-1000-8000-00805f9b34fb': ['Heart rate'],
    '00001822-0000-1000-8000-00805f9b34fb': ['SpO₂'],
    '0000181d-0000-1000-8000-00805f9b34fb': ['Weight'],
    '0000181b-0000-1000-8000-00805f9b34fb': [
      'Weight',
      'Body fat',
      'Body composition',
    ],
    '00001809-0000-1000-8000-00805f9b34fb': ['Temperature'],
    '00001810-0000-1000-8000-00805f9b34fb': ['Blood pressure'],
    '0000180f-0000-1000-8000-00805f9b34fb': ['Battery'],
    '0000180a-0000-1000-8000-00805f9b34fb': ['Device information'],
  };

  static String normalizeUuid(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.length == 4) {
      return '0000$value$bluetoothBaseSuffix';
    }
    if (value.length == 8) {
      return '$value$bluetoothBaseSuffix';
    }
    return value;
  }

  static BleCapabilityReport analyze(Iterable<String> serviceUuids) {
    final services = serviceUuids.map(normalizeUuid).toSet();
    final standard = <String>[];

    for (final entry in _standardServiceCapabilities.entries) {
      if (services.contains(entry.key)) {
        standard.addAll(entry.value);
      }
    }

    BleProtocolProfile? matched;
    for (final profile in profiles) {
      if (profile.matches(services)) {
        matched = profile;
        break;
      }
    }

    return BleCapabilityReport(
      standardCapabilities: standard.toSet().toList(),
      protocolProfile: matched,
    );
  }
}
