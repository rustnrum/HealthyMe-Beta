from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 35 ResMed pairing patch: {message}')


# ---------------------------------------------------------------------------
# Dart bridge: submit the AirSense four-digit code into the still-open native
# pairing session. The initial secure sync deliberately starts with no code so
# the machine can display its one-time code first.
# ---------------------------------------------------------------------------
direct = Path('lib/services/direct_metric_service.dart')
text = direct.read_text()

anchor = """  static bool isTherapyOnlyProtocol(String? protocolId) =>
      protocolId == 'cpap-family';
"""
block = """  static bool isValidCpapPasskey(String value) =>
      RegExp(r'^\\d{4}$').hasMatch(value.trim());

  Future<bool> submitCpapPasskey(String deviceId, String passkey) async {
    final code = passkey.trim();
    if (deviceId.isEmpty || !isValidCpapPasskey(code)) return false;
    final accepted = await _channel.invokeMethod<bool>(
      'submitCpapPasskey',
      <String, dynamic>{
        'deviceId': deviceId,
        'cpapPasskey': code,
      },
    );
    return accepted ?? false;
  }

""" + anchor
if 'Future<bool> submitCpapPasskey' not in text:
    if anchor not in text:
        fail('DirectMetricService pairing-submit anchor missing')
    text = text.replace(anchor, block, 1)
direct.write_text(text)


# ---------------------------------------------------------------------------
# CPAP screen: start sync first, then allow the user to enter and submit the
# one-time code while the original BLE/RPC request remains alive.
# ---------------------------------------------------------------------------
cpap = Path('lib/screens/cpap_screen.dart')
text = cpap.read_text()

state_anchor = """  bool _loading = true;
  bool _checking = false;
  bool _argsLoaded = false;
"""
state_new = """  bool _loading = true;
  bool _checking = false;
  bool _submittingPasskey = false;
  bool _argsLoaded = false;
"""
if 'bool _submittingPasskey = false;' not in text:
    if state_anchor not in text:
        fail('CPAP submitting state anchor missing')
    text = text.replace(state_anchor, state_new, 1)

start_old = """    setState(() {
      _checking = true;
      _status = null;
    });
"""
start_new = """    _passkeyController.clear();
    setState(() {
      _checking = true;
      _status =
          'Opening ResMed pairing session. When the AirSense shows a 4-digit code, enter it below without stopping sync.';
    });
"""
if "Opening ResMed pairing session." not in text:
    if start_old not in text:
        fail('CPAP sync-start state anchor missing')
    text = text.replace(start_old, start_new, 1)

call_old = """        protocolId: 'cpap-family',
        duration: const Duration(seconds: 24),
        cpapPasskey: _passkeyController.text.trim().isEmpty
            ? null
            : _passkeyController.text.trim(),
      );
"""
call_new = """        protocolId: 'cpap-family',
        duration: const Duration(seconds: 70),
        cpapPasskey: null,
      );
"""
if 'duration: const Duration(seconds: 70)' not in text:
    if call_old not in text:
        fail('CPAP secure-read call anchor missing')
    text = text.replace(call_old, call_new, 1)

method_anchor = """  @override
  Widget build(BuildContext context) {
"""
method_block = """  Future<void> _submitPairingCode() async {
    final device = _selected;
    final code = _passkeyController.text.trim();
    if (device == null || !_checking || _submittingPasskey) return;
    if (!DirectMetricService.isValidCpapPasskey(code)) {
      setState(() => _status = 'Enter the 4-digit code currently shown on the AirSense.');
      return;
    }

    setState(() => _submittingPasskey = true);
    try {
      final accepted = await _direct.submitCpapPasskey(device.id, code);
      if (!mounted) return;
      setState(() {
        _status = accepted
            ? 'Pairing code sent. Keep the AirSense screen open while Salus completes the secure session.'
            : 'No active ResMed pairing request was found. Start secure sync again and enter the new code while it is displayed.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Could not submit ResMed pairing code: $error');
    } finally {
      if (mounted) setState(() => _submittingPasskey = false);
    }
  }

""" + method_anchor
if 'Future<void> _submitPairingCode()' not in text:
    if method_anchor not in text:
        fail('CPAP submit method insertion anchor missing')
    text = text.replace(method_anchor, method_block, 1)

ui_old = """                  TextField(
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
                      onPressed: _checking ? null : _checkForData,
                      icon: _checking
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        _checking ? 'Syncing…' : 'Secure sync CPAP data',
                      ),
                    ),
                  ),
"""
ui_new = """                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _checkForData,
                      icon: _checking
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        _checking ? 'Secure session in progress…' : 'Start secure CPAP sync',
                      ),
                    ),
                  ),
                  if (_checking) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passkeyController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Code shown on AirSense',
                        helperText: 'Wait for the CPAP to display its code, enter it here, then tap Submit code.',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _submittingPasskey ||
                                !DirectMetricService.isValidCpapPasskey(
                                  _passkeyController.text,
                                )
                            ? null
                            : _submitPairingCode,
                        icon: _submittingPasskey
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.key_rounded, size: 18),
                        label: Text(
                          _submittingPasskey ? 'Submitting…' : 'Submit pairing code',
                        ),
                      ),
                    ),
                  ],
"""
if "'Start secure CPAP sync'" not in text:
    if ui_old not in text:
        fail('CPAP pairing UI anchor missing')
    text = text.replace(ui_old, ui_new, 1)

cpap.write_text(text)


# ---------------------------------------------------------------------------
# Native protocol reader: turn first pairing into a two-stage transaction.
# StartKeyExchange happens first; the AirSense then shows its code. We keep the
# GATT/RPC session open and accept the code through a second MethodChannel call.
# ---------------------------------------------------------------------------
reader = Path('scripts/SalusProtocolReader.kt.template')
text = reader.read_text()
text = text.replace('SALUS_PROTOCOL_METRICS_V034', 'SALUS_PROTOCOL_METRICS_V035')
text = text.replace(
    'Local protocol readers plus a read-only ResMed AirSense 11 secure session reader.',
    'Local protocol readers plus a two-stage read-only ResMed AirSense 11 secure session reader.',
)

companion_anchor = """        private val RESMED_SRP_G = BigInteger.valueOf(2L)

        private const val GARMIN_GFDI = 1
"""
companion_new = """        private val RESMED_SRP_G = BigInteger.valueOf(2L)
        private val ACTIVE_CPAP_PAIRINGS =
            java.util.concurrent.ConcurrentHashMap<String, (String) -> Boolean>()

        fun submitCpapPasskey(deviceId: String, passkey: String): Boolean {
            val code = passkey.trim()
            if (!Regex("^[0-9]{4}$").matches(code)) return false
            val key = deviceId.replace(":", "").lowercase()
            val handler = ACTIVE_CPAP_PAIRINGS[key] ?: return false
            return handler(code)
        }

        private const val GARMIN_GFDI = 1
"""
if 'ACTIVE_CPAP_PAIRINGS' not in text:
    if companion_anchor not in text:
        fail('native pairing registry anchor missing')
    text = text.replace(companion_anchor, companion_new, 1)

state_anchor = """        private var cpapAuthenticated = false
        private var cpapPairingRequired = false
        private var cpapRpcId = 100
"""
state_new = """        private var cpapAuthenticated = false
        private var cpapPairingRequired = false
        private var cpapAwaitingPasskey = false
        private var cpapRpcId = 100
"""
if 'private var cpapAwaitingPasskey = false' not in text:
    if state_anchor not in text:
        fail('native awaiting-passkey state anchor missing')
    text = text.replace(state_anchor, state_new, 1)

begin_old = """private fun beginCpapSession() {
            if (completed.get() || cpapSessionStarted) return
            cpapSessionStarted = true
            val tx = cpapTx
            val rx = cpapRx
            if (tx == null || rx == null) {
                notes.add("ResMed FIG TX/RX characteristics were not found on this firmware.")
                return
            }

            val prefs = activity.getSharedPreferences("salus_resmed_session_v1", 0)
            val key = device.address.replace(":", "").lowercase()
            val clientId = prefs.getString("${key}_clientId", null)
            val masterHex = prefs.getString("${key}_masterPairKey", null)
            val master = masterHex?.let { hexToBytesOrNull(it) }
            if (!clientId.isNullOrBlank() && master?.size == 32) {
                cpapMasterPairKey = master
                sendCpapRpc(
                    "RequestSession",
                    JSONObject().put("clientId", clientId),
                    encrypted = false,
                )
                return
            }

            val code = cpapPasskey?.trim().orEmpty()
            if (!Regex("^[0-9]{4}$").matches(code)) {
                cpapPairingRequired = true
                finish()
                return
            }
            startCpapKeyExchange(code)
        }

        private fun startCpapKeyExchange(passkey: String) {
            var a: BigInteger
            do {
                a = BigInteger(256, cpapRandom)
            } while (a == BigInteger.ZERO || a >= RESMED_SRP_N)
            val public = RESMED_SRP_G.modPow(a, RESMED_SRP_N)
            cpapSrpPrivate = a
            cpapSrpPublic = public
            notes.add("Starting ResMed secure pairing exchange.")
            sendCpapRpc(
                "StartKeyExchange",
                JSONObject().put("clientPk", bytesToHex(srpPad(public)).uppercase()),
                encrypted = false,
            )
        }

        """
begin_new = """private fun beginCpapSession() {
            if (completed.get() || cpapSessionStarted) return
            cpapSessionStarted = true
            val tx = cpapTx
            val rx = cpapRx
            if (tx == null || rx == null) {
                notes.add("ResMed FIG TX/RX characteristics were not found on this firmware.")
                return
            }

            val prefs = activity.getSharedPreferences("salus_resmed_session_v1", 0)
            val key = device.address.replace(":", "").lowercase()
            val clientId = prefs.getString("${key}_clientId", null)
            val masterHex = prefs.getString("${key}_masterPairKey", null)
            val master = masterHex?.let { hexToBytesOrNull(it) }
            if (!clientId.isNullOrBlank() && master?.size == 32) {
                cpapMasterPairKey = master
                sendCpapRpc(
                    "RequestSession",
                    JSONObject().put("clientId", clientId),
                    encrypted = false,
                )
                return
            }

            startCpapKeyExchange()
        }

        private fun startCpapKeyExchange() {
            cpapPairingRequired = true
            cpapAwaitingPasskey = false
            val pairingKey = device.address.replace(":", "").lowercase()
            ACTIVE_CPAP_PAIRINGS.remove(pairingKey)
            var a: BigInteger
            do {
                a = BigInteger(256, cpapRandom)
            } while (a == BigInteger.ZERO || a >= RESMED_SRP_N)
            val public = RESMED_SRP_G.modPow(a, RESMED_SRP_N)
            cpapSrpPrivate = a
            cpapSrpPublic = public
            notes.add("Starting ResMed secure pairing exchange; waiting for the AirSense one-time code.")
            sendCpapRpc(
                "StartKeyExchange",
                JSONObject().put("clientPk", bytesToHex(srpPad(public)).uppercase()),
                encrypted = false,
            )
        }

        private fun continueCpapKeyExchange(
            serverPk: String,
            salt: String,
            passkey: String,
        ) {
            if (completed.get()) return
            val proof = computeCpapSrpProof(serverPk, salt, passkey) ?: run {
                finish("Could not compute the ResMed pairing proof.")
                return
            }
            sendCpapRpc(
                "ConfirmKeyExchange",
                JSONObject().put("clientConfirmation", bytesToHex(proof).uppercase()),
                encrypted = false,
            )
        }

        private fun clearStoredCpapCredentials() {
            val prefs = activity.getSharedPreferences("salus_resmed_session_v1", 0)
            val key = device.address.replace(":", "").lowercase()
            prefs.edit()
                .remove("${key}_clientId")
                .remove("${key}_masterPairKey")
                .apply()
            cpapMasterPairKey = null
            cpapPendingNonce = null
            cpapSessionKey = null
            cpapAuthenticated = false
        }

        """
if 'private fun continueCpapKeyExchange(' not in text:
    if begin_old not in text:
        fail('native begin/key-exchange anchor missing')
    text = text.replace(begin_old, begin_new, 1)

error_old = """            if (message.has("error")) {
                val error = message.optJSONObject("error")
                if (method == "Get") {
"""
error_new = """            if (message.has("error")) {
                val error = message.optJSONObject("error")
                if (method == "RequestSession" || method == "CheckSessionIntegrity") {
                    clearStoredCpapCredentials()
                    notes.add("Stored ResMed credentials were rejected; starting a fresh pairing exchange.")
                    startCpapKeyExchange()
                    return
                }
                if (method == "Get") {
"""
if 'Stored ResMed credentials were rejected; starting a fresh pairing exchange.' not in text:
    if error_old not in text:
        fail('native RPC error anchor missing')
    text = text.replace(error_old, error_new, 1)

start_branch_old = """                "StartKeyExchange" -> {
                    if (resultObject == null) return
                    val serverPk = resultObject.optString("serverPk")
                    val salt = resultObject.optString("salt")
                    val passkey = cpapPasskey?.trim().orEmpty()
                    if (serverPk.isBlank() || salt.isBlank() || passkey.length != 4) {
                        finish("ResMed key exchange did not return the expected pairing fields.")
                        return
                    }
                    val proof = computeCpapSrpProof(serverPk, salt, passkey) ?: run {
                        finish("Could not compute the ResMed pairing proof.")
                        return
                    }
                    sendCpapRpc(
                        "ConfirmKeyExchange",
                        JSONObject().put("clientConfirmation", bytesToHex(proof).uppercase()),
                        encrypted = false,
                    )
                }
"""
start_branch_new = """                "StartKeyExchange" -> {
                    if (resultObject == null) return
                    val serverPk = resultObject.optString("serverPk")
                    val salt = resultObject.optString("salt")
                    if (serverPk.isBlank() || salt.isBlank()) {
                        finish("ResMed key exchange did not return the expected pairing fields.")
                        return
                    }

                    val initialCode = cpapPasskey?.trim().orEmpty()
                    if (Regex("^[0-9]{4}$").matches(initialCode)) {
                        continueCpapKeyExchange(serverPk, salt, initialCode)
                        return
                    }

                    cpapPairingRequired = true
                    cpapAwaitingPasskey = true
                    val pairingKey = device.address.replace(":", "").lowercase()
                    ACTIVE_CPAP_PAIRINGS[pairingKey] = { code ->
                        if (completed.get() || !cpapAwaitingPasskey ||
                            !Regex("^[0-9]{4}$").matches(code)
                        ) {
                            false
                        } else {
                            mainHandler.post {
                                if (!completed.get() && cpapAwaitingPasskey) {
                                    cpapAwaitingPasskey = false
                                    ACTIVE_CPAP_PAIRINGS.remove(pairingKey)
                                    continueCpapKeyExchange(serverPk, salt, code)
                                }
                            }
                            true
                        }
                    }
                    notes.add("AirSense one-time pairing code is being displayed; waiting for Salus code submission.")
                }
"""
if 'AirSense one-time pairing code is being displayed' not in text:
    if start_branch_old not in text:
        fail('native StartKeyExchange response anchor missing')
    text = text.replace(start_branch_old, start_branch_new, 1)

confirm_success_old = """                    prefs.edit()
                        .putString("${key}_clientId", clientId)
                        .putString("${key}_masterPairKey", bytesToHex(master))
                        .apply()
                    cpapSessionKey = sha256(master, nonce)
                    cpapAuthenticated = true
                    requestCpapReadOnlyData()
"""
confirm_success_new = """                    prefs.edit()
                        .putString("${key}_clientId", clientId)
                        .putString("${key}_masterPairKey", bytesToHex(master))
                        .apply()
                    cpapSessionKey = sha256(master, nonce)
                    cpapAuthenticated = true
                    cpapPairingRequired = false
                    cpapAwaitingPasskey = false
                    requestCpapReadOnlyData()
"""
if 'cpapPairingRequired = false\n                    cpapAwaitingPasskey = false\n                    requestCpapReadOnlyData()' not in text:
    if confirm_success_old not in text:
        fail('native ConfirmKeyExchange success anchor missing')
    text = text.replace(confirm_success_old, confirm_success_new, 1)

integrity_old = """                "CheckSessionIntegrity" -> {
                    val accepted = resultObject?.optBoolean("confirmation", false) == true
                    val master = cpapMasterPairKey
                    val nonce = cpapPendingNonce
                    if (!accepted || master == null || nonce == null) {
                        finish("Stored ResMed session credentials were rejected. Enter a fresh 4-digit pairing code to pair Salus again.")
                        return
                    }
                    cpapSessionKey = sha256(master, nonce)
                    cpapAuthenticated = true
                    requestCpapReadOnlyData()
                }
"""
integrity_new = """                "CheckSessionIntegrity" -> {
                    val accepted = resultObject?.optBoolean("confirmation", false) == true
                    val master = cpapMasterPairKey
                    val nonce = cpapPendingNonce
                    if (!accepted || master == null || nonce == null) {
                        clearStoredCpapCredentials()
                        notes.add("Stored ResMed session credentials were rejected; starting a fresh pairing exchange.")
                        startCpapKeyExchange()
                        return
                    }
                    cpapSessionKey = sha256(master, nonce)
                    cpapAuthenticated = true
                    requestCpapReadOnlyData()
                }
"""
if 'clearStoredCpapCredentials()\n                        notes.add("Stored ResMed session credentials were rejected' not in text:
    if integrity_old not in text:
        fail('native CheckSessionIntegrity anchor missing')
    text = text.replace(integrity_old, integrity_new, 1)

finish_anchor = """            if (ringHrvProxyCount > 0) {
                metrics["Ring HRV proxy"] =
                    ringHrvProxySum.toDouble() / ringHrvProxyCount.toDouble()
            }

            try {
"""
finish_new = """            if (ringHrvProxyCount > 0) {
                metrics["Ring HRV proxy"] =
                    ringHrvProxySum.toDouble() / ringHrvProxyCount.toDouble()
            }

            val pairingKey = device.address.replace(":", "").lowercase()
            ACTIVE_CPAP_PAIRINGS.remove(pairingKey)
            cpapAwaitingPasskey = false

            try {
"""
if 'ACTIVE_CPAP_PAIRINGS.remove(pairingKey)' not in text[text.index('private fun finish('):]:
    if finish_anchor not in text:
        fail('native finish cleanup anchor missing')
    text = text.replace(finish_anchor, finish_new, 1)

text = text.replace(
    '"Secure ResMed pairing is required. Put the AirSense in Bluetooth pairing mode, enter the 4-digit code shown on its screen, then run Secure sync again."',
    '"ResMed pairing timed out before the one-time code was submitted. Start secure sync again and enter the code while it is still displayed."',
)

reader.write_text(text)
print('Salus build 35 ResMed two-stage pairing patch applied.')
