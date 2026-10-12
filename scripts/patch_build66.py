"""Build 66: read-only firmware and capabilities diagnostics for any saved BLE device.

Adds a new isolated GATT device-information reader. Does not modify existing
Garmin, COLMI, CPAP, Health Connect, notification or stored health-data readers.
Safe to re-apply to source already committed at Build 66.
"""
from pathlib import Path


def replace(path, old, new):
    file = Path(path)
    current = file.read_text(encoding='utf-8')
    if new in current:
        return
    count = current.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: required unique anchor missing ({count}): {old[:100]}')
    file.write_text(current.replace(old, new, 1), encoding='utf-8')

replace('pubspec.yaml', 'version: 0.21.27+65', 'version: 0.21.28+66')

replace('native/android/MainActivity.kt',
'''                "inspectBle" -> {''',
'''                "readBleDeviceInfo" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId.isNullOrBlank()) {
                        result.error("BLE_DEVICE_ID_MISSING", "Bluetooth device id is required.", null)
                    } else if (!hasBluetoothPermission()) {
                        result.error("BLE_PERMISSION_DENIED", "Bluetooth permission is required.", null)
                    } else {
                        SalusBleDeviceInfoReader.read(this, deviceId, result)
                    }
                }
                "inspectBle" -> {''')

replace('lib/screens/connections_screen.dart',
"import '../services/ble_discovery_service.dart';",
"import '../services/ble_discovery_service.dart';\nimport 'device_information_screen.dart';")

replace('lib/screens/connections_screen.dart',
'''                onRemove: () => _remove(device),
                onOpen: () {''',
'''                onRemove: () => _remove(device),
                onInfo: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DeviceInformationScreen(device: device),
                )),
                onOpen: () {''')

replace('lib/screens/connections_screen.dart',
'''  final VoidCallback onRemove;
  final VoidCallback onOpen;

  const _SavedCard({''',
'''  final VoidCallback onRemove;
  final VoidCallback onInfo;
  final VoidCallback onOpen;

  const _SavedCard({''')
replace('lib/screens/connections_screen.dart',
'''    required this.onRemove,
    required this.onOpen,
  });''',
'''    required this.onRemove,
    required this.onInfo,
    required this.onOpen,
  });''')

replace('lib/screens/connections_screen.dart',
'''          IconButton(
            tooltip: 'Sync',
            onPressed: syncing ? null : onSync,''',
'''          IconButton(
            tooltip: 'Device information and capabilities',
            onPressed: onInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
          IconButton(
            tooltip: 'Sync',
            onPressed: syncing ? null : onSync,''')

# Saved device identity revision history is retained locally by a new service.
# The new reader is only invoked from the information screen, never during
# automatic connection, to avoid interrupting active watch notifications.
