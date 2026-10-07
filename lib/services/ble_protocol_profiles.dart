class BleProtocolProfile {
  final String id;
  final String label;
  final String deviceKind;
  final Set<String> requiredServices;
  final Set<String> anyServices;
  final List<String> nameTokens;
  final List<String> capabilities;
  final String note;
  final bool dataReaderReady;

  const BleProtocolProfile({
    required this.id,
    required this.label,
    required this.deviceKind,
    this.requiredServices = const {},
    this.anyServices = const {},
    this.nameTokens = const [],
    required this.capabilities,
    required this.note,
    this.dataReaderReady = false,
  });

  bool matches(String name, Set<String> services) {
    if (requiredServices.isNotEmpty &&
        !requiredServices.every(services.contains)) {
      return false;
    }
    if (anyServices.any(services.contains)) return true;

    final tokens = name
        .trim()
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9áéíóúüñ]+'))
        .where((token) => token.isNotEmpty)
        .toSet();
    return nameTokens.any(tokens.contains);
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
  static const String garminService =
      '6a4e2800-667b-11e3-949a-0800200c9a66';
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
      nameTokens: ['qring', 'colmi', 'yawell', 'r02', 'r03', 'r06'],
      capabilities: [
        'Heart rate',
        'SpO2',
        'Steps',
        'Sleep',
        'HRV',
        'Raw motion',
        'Battery',
      ],
      note: 'Built-in direct ring reader.',
      dataReaderReady: true,
    ),
    BleProtocolProfile(
      id: 'garmin-family',
      label: 'Garmin watch family',
      deviceKind: 'Watch',
      anyServices: {garminService},
      nameTokens: [
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
        'Heart rate',
        'HRV',
        'SpO2',
        'Respiratory rate',
        'Active calories',
        'Body battery',
        'Stress',
      ],
      note:
          'Built-in Garmin realtime reader. Stored FIT history remains a separate capability.',
      dataReaderReady: true,
    ),
    BleProtocolProfile(
      id: 'cpap-family',
      label: 'Respiratory / CPAP device',
      deviceKind: 'CPAP / respiratory',
      anyServices: {
        resMedAdvertisedService,
        resMedDeviceService,
      },
      nameTokens: [
        'resmed',
        'airsense',
        'aircurve',
        'dreamstation',
        'cpap',
        'bipap',
        'bpap',
        'prisma',
      ],
      capabilities: [
        'Usage time',
        'AHI',
        'Leak rate',
        'Therapy pressure',
        'Respiratory rate',
      ],
      note:
          'Built-in read-only therapy reader where the device protocol is supported.',
      dataReaderReady: true,
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

  static bool hasBuiltInReader(String? protocolId) =>
      protocolId != null &&
      profiles.any(
        (profile) => profile.id == protocolId && profile.dataReaderReady,
      );

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

    final tokens = name
        .trim()
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9áéíóúüñ]+'))
        .where((token) => token.isNotEmpty)
        .toSet();

    final cpapProfile =
        profiles.firstWhere((profile) => profile.id == 'cpap-family');
    final ringProfile =
        profiles.firstWhere((profile) => profile.id == 'ring-uart-v1');

    final strongCpapIdentity =
        cpapProfile.anyServices.any(services.contains) ||
        cpapProfile.nameTokens.any(tokens.contains);

    final strongRingIdentity =
        (services.contains(ringUartService) &&
            services.contains(ringBigDataService)) ||
        ringProfile.nameTokens.any(tokens.contains);

    if (strongCpapIdentity) {
      matched = cpapProfile;
    } else if (strongRingIdentity) {
      matched = ringProfile;
    } else {
      for (final profile in profiles) {
        if (profile.id == 'cpap-family' || profile.id == 'ring-uart-v1') {
          continue;
        }
        if (profile.matches(name, services)) {
          matched = profile;
          break;
        }
      }
    }

    return BleCapabilityReport(
      standardCapabilities: standard.toSet().toList(),
      protocolProfile: matched,
      deviceKind: matched?.deviceKind ?? _inferKind(name, standard),
    );
  }

  static bool looksLikeCpapName(String name) =>
      analyze(const [], name: name).protocolProfile?.id == 'cpap-family';

  static bool looksLikeRingName(String name) =>
      analyze(const [], name: name).protocolProfile?.id == 'ring-uart-v1';

  static String _inferKind(String name, List<String> capabilities) {
    final tokens = name
        .trim()
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9áéíóúüñ]+'))
        .where((token) => token.isNotEmpty)
        .toSet();

    if (capabilities.contains('Weight') ||
        capabilities.contains('Body composition') ||
        tokens.contains('scale')) {
      return 'Scale';
    }
    if (tokens.contains('ring')) return 'Ring';
    if (tokens.contains('watch') || tokens.contains('band')) {
      return 'Watch / band';
    }
    if (capabilities.contains('Blood pressure')) {
      return 'Blood pressure monitor';
    }
    if (capabilities.contains('Glucose')) return 'Glucose meter';
    if (capabilities.contains('Heart rate')) return 'Heart-rate sensor';
    return 'Bluetooth device';
  }
}
