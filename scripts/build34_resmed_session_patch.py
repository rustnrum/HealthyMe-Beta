from pathlib import Path
import re


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 34 ResMed session patch: {message}')

# ---------------------------------------------------------------------------
# Dart direct metric bridge: pass optional first-pairing code to native layer.
# ---------------------------------------------------------------------------
direct = Path('lib/services/direct_metric_service.dart')
text = direct.read_text()

old_sig = """  Future<DirectMetricReadResult> readAndStore(
    BleDeviceCandidate device, {
    String? protocolId,
    Duration duration = const Duration(seconds: 14),
  }) async {
"""
new_sig = """  Future<DirectMetricReadResult> readAndStore(
    BleDeviceCandidate device, {
    String? protocolId,
    Duration duration = const Duration(seconds: 14),
    String? cpapPasskey,
  }) async {
"""
if 'String? cpapPasskey,' not in text:
    if old_sig not in text:
        fail('readAndStore signature anchor missing')
    text = text.replace(old_sig, new_sig, 1)

old_map = """        'protocolId': resolvedProtocolId,
        'durationMs': duration.inMilliseconds,
      },
"""
new_map = """        'protocolId': resolvedProtocolId,
        'durationMs': duration.inMilliseconds,
        'cpapPasskey': cpapPasskey,
      },
"""
if "'cpapPasskey': cpapPasskey" not in text:
    if old_map not in text:
        fail('native call map anchor missing')
    text = text.replace(old_map, new_map, 1)

direct.write_text(text)

# ---------------------------------------------------------------------------
# CPAP dashboard: optional 4-digit code is only needed for first secure pair.
# Stored session credentials are reused automatically on future syncs.
# ---------------------------------------------------------------------------
cpap = Path('lib/screens/cpap_screen.dart')
text = cpap.read_text()

state_anchor = """  final _therapy = CpapTherapyService();

  List<SavedDirectDevice> _devices = const [];
"""
state_new = """  final _therapy = CpapTherapyService();
  final _passkeyController = TextEditingController();

  List<SavedDirectDevice> _devices = const [];
"""
if '_passkeyController' not in text:
    if state_anchor not in text:
        fail('passkey controller anchor missing')
    text = text.replace(state_anchor, state_new, 1)

init_anchor = """  @override
  void initState() {
    super.initState();
    _load();
  }

"""
dispose_block = init_anchor + """  @override
  void dispose() {
    _passkeyController.dispose();
    super.dispose();
  }

"""
if '_passkeyController.dispose()' not in text:
    if init_anchor not in text:
        fail('dispose anchor missing')
    text = text.replace(init_anchor, dispose_block, 1)

call_anchor = """        protocolId: 'cpap-family',
        duration: const Duration(seconds: 20),
      );
"""
call_new = """        protocolId: 'cpap-family',
        duration: const Duration(seconds: 24),
        cpapPasskey: _passkeyController.text.trim().isEmpty
            ? null
            : _passkeyController.text.trim(),
      );
"""
if 'cpapPasskey: _passkeyController.text.trim().isEmpty' not in text:
    if call_anchor not in text:
        fail('CPAP secure call anchor missing')
    text = text.replace(call_anchor, call_new, 1)

button_anchor = """                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
"""
button_new = """                  const SizedBox(height: 12),
                  TextField(
                    controller: _passkeyController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'ResMed 4-digit code',
                      helperText: 'First secure pairing only. Leave blank after Salus has paired.',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
"""
if "labelText: 'ResMed 4-digit code'" not in text:
    if button_anchor not in text:
        fail('secure pairing UI anchor missing')
    text = text.replace(button_anchor, button_new, 1)

text = text.replace(
    "_checking ? 'Listening…' : 'Probe live CPAP data'",
    "_checking ? 'Syncing…' : 'Secure sync CPAP data'",
)
text = text.replace(
    "'${device.name} • ResMed read-only probe'",
    "'${device.name} • secure read-only therapy sync'",
)
text = text.replace(
    "'Live ResMed probe'",
    "'ResMed session diagnostics'",
)
text = text.replace(
    "'Raw BLE observations are diagnostic only until Salus maps them to verified therapy fields.'",
    "'Salus only sends secure-session and read-only Get requests. It does not change therapy settings.'",
)

cpap.write_text(text)

print('Salus build 34 ResMed secure read-only session patch applied.')
