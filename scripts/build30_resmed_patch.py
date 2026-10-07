from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 30 ResMed patch: {message}')


profiles = Path('lib/services/ble_protocol_profiles.dart')
text = profiles.read_text()

if 'resMedAdvertisedService' not in text:
    anchor = '''  static const String no1Service =
      '000055ff-0000-1000-8000-00805f9b34fb';
'''
    replacement = anchor + '''  static const String resMedAdvertisedService =
      '0000fd56-0000-1000-8000-00805f9b34fb';
  static const String resMedDeviceService =
      '948652e2-d03b-11e8-a8d5-f2801f1b9fd1';
'''
    if anchor not in text:
        fail('service constant anchor missing')
    text = text.replace(anchor, replacement, 1)

old_profile = '''    BleProtocolProfile(
      id: 'cpap-family',
      label: 'Respiratory / CPAP device',
      deviceKind: 'CPAP / respiratory',
      nameHints: [
        'airsense',
        'aircurve',
        'dreamstation',
        'cpap',
        'bipap',
        'bpap',
        'prisma',
        'luna g3',
      ],
      capabilities: ['Therapy data'],
'''
new_profile = '''    BleProtocolProfile(
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
      capabilities: ['Therapy data'],
'''
if new_profile not in text:
    if old_profile not in text:
        fail('CPAP profile anchor missing')
    text = text.replace(old_profile, new_profile, 1)

profiles.write_text(text)


connections = Path('lib/screens/connections_screen.dart')
text = connections.read_text()
if "'resmed'," not in text:
    anchor = '''      'aircurve',
      'dreamstation',
'''
    replacement = '''      'aircurve',
      'resmed',
      'dreamstation',
'''
    if anchor not in text:
        fail('Connections ResMed hint anchor missing')
    text = text.replace(anchor, replacement, 1)
connections.write_text(text)


sources = Path('lib/screens/sources_screen.dart')
text = sources.read_text()
if "'resmed'," not in text:
    anchor = '''      'aircurve',
      'dreamstation',
'''
    replacement = '''      'aircurve',
      'resmed',
      'dreamstation',
'''
    if anchor not in text:
        fail('debug scanner ResMed hint anchor missing')
    text = text.replace(anchor, replacement, 1)
sources.write_text(text)


tests = Path('test/ble_protocol_profiles_test.dart')
text = tests.read_text()
if 'ResMed name is classified as CPAP health hardware' not in text:
    closing = text.rfind('\n}')
    if closing < 0:
        fail('test file closing brace missing')

    block = '''

  test('ResMed name is classified as CPAP health hardware', () {
    final report = BleProtocolProfiles.analyze(
      const [],
      name: 'ResMed 681683',
    );
    expect(report.protocolProfile?.id, 'cpap-family');
    expect(report.deviceKind, 'CPAP / respiratory');
    expect(report.allCapabilities, contains('Therapy data'));
  });

  test('ResMed advertised service identifies CPAP', () {
    final report = BleProtocolProfiles.analyze(
      const [BleProtocolProfiles.resMedAdvertisedService],
      name: 'Unnamed BLE device',
    );
    expect(report.protocolProfile?.id, 'cpap-family');
    expect(report.deviceKind, 'CPAP / respiratory');
  });

  test('ResMed proprietary GATT service identifies CPAP', () {
    final report = BleProtocolProfiles.analyze(
      const [BleProtocolProfiles.resMedDeviceService],
      name: 'Unnamed BLE device',
    );
    expect(report.protocolProfile?.id, 'cpap-family');
    expect(report.deviceKind, 'CPAP / respiratory');
  });
'''
    text = text[:closing] + block + text[closing:]

tests.write_text(text)

print('Salus build 30 ResMed / CPAP classification patch applied.')
