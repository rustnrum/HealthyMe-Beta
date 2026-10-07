class BleProtocolProfile {
  final String id;
  final String label;
  final String deviceKind;
  final Set<String> requiredServices;
  final Set<String> anyServices;
  final List<String> nameHints;
  final List<String> capabilities;
  final String note;
  final bool dataReaderReady;

  const BleProtocolProfile({
    required this.id,
    required this.label,
    required this.deviceKind,
    this.requiredServices = const {},
    this.anyServices = const {},
    this.nameHints = const [],
    required this.capabilities,
    required this.note,
    this.dataReaderReady = false,
  });

  bool matches(String name, Set<String> services) {
    final normalizedName = name.trim().toLowerCase();
    final requiredMatch = requiredServices.isEmpty ||
        requiredServices.every(services.contains);
    if (!requiredMatch) return false;

    final serviceMatch = anyServices.isNotEmpty &&
        anyServices.any(services.contains);
    final nameMatch = nameHints.isNotEmpty &&
        nameHints.any(normalizedName.contains);

    if (requiredServices.isNotEmpty && anyServices.isEmpty) return true;
    if (serviceMatch) return true;
    if (nameMatch) return true;
    return false;
  }
}

class BleCapabilityReport {
  final List<String> standardCapabilities;
  final BleProtocolProfile? protocolProfile;
  final String deviceKind;

  const BleCapabilityReport({
    required this.standardCapabilities,
    this.protocolProfile,
    required this.deviceKind,
  });

  List<String> get allCapabilities => <String>{
        ...standardCapabilities,
        ...?protocolProfile?.capabilities,
      }.toList();
}

class BleProtocolProfiles {
  static const String bluetoothBaseSuffix =
      '-0000-1000-8000-00805f9b34fb';

  static const String ringUartService =
      '6e40fff0-b5a3-f393-e0a9-e50e24dcca9e';
  static const String ringBigDataService =
      'de5bf728-d711-4e47-af26-65e3012a5dc7';
  static const String huamiFee0 =
      '0000fee0-0000-1000-8000-00805f9b34fb';
  static const String huamiFee1 =
      '0000fee1-0000-1000-8000-00805f9b34fb';
  static const String no1Service =
      '000055ff-0000-1000-8000-00805f9b34fb';
  static const String resMedAdvertisedService =
      '0000fd56-0000-1000-8000-00805f9b34fb';
  static const String resMedDeviceService =
      '948652e2-d03b-11e8-a8d5-f2801f1b9fd1';

  static const profiles = <BleProtocolProfile>[
    BleProtocolProfile(
      id: 'ring-uart-v1',
      label: 'QRing / Yawell ring family',
      deviceKind: 'Ring',
      requiredServices: {ringUartService},
      capabilities: [
        'Heart rate',
        'SpO2',
        'Steps',
        'Sleep',
        'HRV',
        'Raw motion',
        'Battery',
      ],
      note:
          'Known direct BLE ring protocol. Salus can identify the UART/big-data family without the vendor app; metric decoding is enabled per protocol reader.',
    ),
    BleProtocolProfile(
      id: 'huami-zepp-family',
      label: 'Xiaomi / Amazfit / Huami family',
      deviceKind: 'Watch / band',
      anyServices: {huamiFee0, huamiFee1},
      nameHints: ['amazfit', 'xiaomi', 'mi band', 'zepp'],
      capabilities: ['Steps', 'Sleep', 'Heart rate', 'Workouts', 'Battery'],
      note:
          'Known Huami/Zepp BLE family. Some models require an authentication key before health history can be read.',
    ),
    BleProtocolProfile(
      id: 'no1-f1-family',
      label: 'NO.1 / compatible watch family',
      deviceKind: 'Watch / band',
      anyServices: {no1Service},
      capabilities: ['Steps', 'Sleep', 'Heart rate', 'Battery'],
      note: 'Known BLE watch protocol family with direct activity/history commands.',
    ),
    BleProtocolProfile(
      id: 'garmin-family',
      label: 'Garmin watch family',
      deviceKind: 'Watch',
      nameHints: [
        'garmin',
        'fenix',
        'forerunner',
        'venu',
        'instinct',
        'vivoactive',
        'vívoactive',
        'vivosmart',
      ],
      capabilities: [
        'Steps',
        'Sleep',
        'Heart rate',
        'Resting heart rate',
        'HRV',
        'SpO2',
        'Respiratory rate',
        'Workouts',
      ],
      note:
          'Garmin-family candidate by advertised identity. Direct Garmin/GFDI history decoding is a separate reader; these are potential device metrics, not proof that every model exposes all of them.',
    ),
    BleProtocolProfile(
      id: 'fitcloud-family',
      label: 'FitCloud watch family',
      deviceKind: 'Watch',
      nameHints: ['fitcloud'],
      capabilities: [
        'Steps',
        'Sleep',
        'Heart rate',
        'Resting heart rate',
        'SpO2',
        'Workouts',
      ],
      note:
          'FitCloud-family candidate. Many rebranded watches share this protocol; exact reader support depends on the device revision.',
    ),
    BleProtocolProfile(
      id: 'moyoung-dafit-family',
      label: 'Moyoung / Da Fit watch family',
      deviceKind: 'Watch',
      nameHints: ['moyoung', 'da fit', 'dafit'],
      capabilities: ['Steps', 'Sleep', 'Heart rate', 'SpO2', 'Workouts'],
      note:
          'Moyoung/Da Fit family candidate. Many brand names share this protocol.',
    ),
    BleProtocolProfile(
      id: 'cpap-family',
      label: 'Respiratory / CPAP device',
      deviceKind: 'CPAP / respiratory',
      anyServices: {
        resMedAdvertisedService,
        resMedDeviceService,
      },
      nameHints: [
        'resmed',
        'airsense',
        'aircurve',
        'dreamstation',
        'cpap',
        'bipap',
        'bpap',
        'prisma',
        'luna g3',
      ],
      capabilities: [
        'Usage time',
        'AHI',
        'Leak rate',
        'Therapy pressure',
        'Mask on/off',
      ],
      note:
          'Respiratory-device candidate. Salus identifies CPAP therapy metrics separately from wearable metrics. Direct therapy-session decoding is not enabled yet.',
    ),
  ];

  static const Map<String, List<String>> _standardServiceCapabilities = {
    '0000180d-0000-1000-8000-00805f9b34fb': ['Heart rate'],
    '00001822-0000-1000-8000-00805f9b34fb': ['SpO2'],
    '0000181d-0000-1000-8000-00805f9b34fb': ['Weight'],
    '0000181b-0000-1000-8000-00805f9b34fb': [
      'Weight',
      'Body fat',
      'Body composition',
    ],
    '00001809-0000-1000-8000-00805f9b34fb': ['Temperature'],
    '00001810-0000-1000-8000-00805f9b34fb': ['Blood pressure'],
    '00001808-0000-1000-8000-00805f9b34fb': ['Glucose'],
    '00001814-0000-1000-8000-00805f9b34fb': ['Cadence'],
    '00001816-0000-1000-8000-00805f9b34fb': ['Cycling cadence'],
    '00001826-0000-1000-8000-00805f9b34fb': ['Workout telemetry'],
    '0000180f-0000-1000-8000-00805f9b34fb': ['Battery'],
    '0000180a-0000-1000-8000-00805f9b34fb': ['Device information'],
  };

  static String normalizeUuid(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.length == 4) return '0000$value$bluetoothBaseSuffix';
    if (value.length == 8) return '$value$bluetoothBaseSuffix';
    return value;
  }

  static BleCapabilityReport analyze(
    Iterable<String> serviceUuids, {
    String name = '',
  }) {
    final services = serviceUuids.map(normalizeUuid).toSet();
    final standard = <String>[];

    for (final entry in _standardServiceCapabilities.entries) {
      if (services.contains(entry.key)) standard.addAll(entry.value);
    }

    BleProtocolProfile? matched;
    for (final profile in profiles) {
      if (profile.matches(name, services)) {
        matched = profile;
        break;
      }
    }

    return BleCapabilityReport(
      standardCapabilities: standard.toSet().toList(),
      protocolProfile: matched,
      deviceKind: matched?.deviceKind ?? _inferKind(name, standard),
    );
  }

  static String _inferKind(String name, List<String> capabilities) {
    final value = name.toLowerCase();
    if (capabilities.contains('Weight') ||
        capabilities.contains('Body composition') ||
        value.contains('scale')) {
      return 'Scale';
    }
    if (value.contains('ring')) return 'Ring';
    if (value.contains('watch') || value.contains('band')) return 'Watch / band';
    if (capabilities.contains('Blood pressure')) return 'Blood pressure monitor';
    if (capabilities.contains('Glucose')) return 'Glucose meter';
    if (capabilities.contains('Heart rate')) return 'Heart-rate sensor';
    return 'Bluetooth device';
  }
}
