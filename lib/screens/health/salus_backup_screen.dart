import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/salus_backup_service.dart';
import '../../widgets/salus_widgets.dart';

/// Local, portable, encrypted backup. Does not require or claim cloud sync.
class SalusBackupScreen extends StatefulWidget {
  const SalusBackupScreen({super.key});
  @override
  State<SalusBackupScreen> createState() => _SalusBackupScreenState();
}

class _SalusBackupScreenState extends State<SalusBackupScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _message;
  final _service = const SalusBackupService();

  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_busy) return;
    if (_password.text.length < 12 || _password.text != _confirm.text) {
      setState(() => _message = 'Enter and confirm a matching password with at least 12 characters.');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      await _service.exportEncrypted(_password.text);
      if (mounted) setState(() => _message =
        'Encrypted backup saved to your chosen location. Keep the file and password safe.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Backup was not completed: $e');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _restore() async {
    if (_busy) return;
    if (_password.text.length < 12) {
      setState(() => _message = 'Enter the password for the backup file (12+ characters).');
      return;
    }
    final approved = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('Restore Salus history?'),
      content: const Text('This will replace matching saved Salus records with the backup values. '
        'Your existing app may need to be closed and reopened after restoring. '
        'Current device connections and account credentials may require reauthorization.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Choose backup')),
      ],
    ));
    if (approved != true || !mounted) return;
    setState(() { _busy = true; _message = null; });
    try {
      final count = await _service.restoreEncrypted(_password.text);
      if (mounted) setState(() => _message =
        '$count saved records restored. Completely close and reopen Salus to load them.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Nothing restored: $e');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup & Restore')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const SalusSectionTitle(title: 'Protect your Salus data', eyebrow: 'Portable encrypted backup'),
      const SizedBox(height: 8),
      const Text('Save a password-protected .salus file in Documents, an SD card, or a cloud folder '
        'you choose. Files outside Salus survive uninstalling the app. Backups are manual in this beta.',
        style: TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 14),
      SalusPaper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Backup password', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _password, obscureText: !_showPassword,
          decoration: InputDecoration(labelText: 'Password (12+ characters)',
            suffixIcon: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility)))),
        const SizedBox(height: 8),
        TextField(controller: _confirm, obscureText: !_showPassword,
          decoration: const InputDecoration(labelText: 'Confirm password (for new backups)')),
      ])),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _busy ? null : _save,
        icon: const Icon(Icons.save_alt), label: Text(_busy ? 'Working…' : 'Create encrypted backup')),
      const SizedBox(height: 9),
      OutlinedButton.icon(onPressed: _busy ? null : _restore,
        icon: const Icon(Icons.restore), label: const Text('Restore from .salus file')),
      if (_message != null) Padding(padding: const EdgeInsets.only(top: 14),
        child: Text(_message!, style: const TextStyle(color: AppTheme.textSecondary))),
      const SizedBox(height: 18),
      const Text('Backed up: your saved Salus profile, labs, health snapshots, '
        'direct-device measurements, food logs, meal calendar, recipes, workouts, and settings. '
        'External Health Connect history remains with its original provider. '
        'ChatGPT sign-in and external photo files are not bundled; reconnect or retain those separately.',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      const SizedBox(height: 10),
      const Text('Warning: there is no password recovery. Do not keep your only backup on the app itself.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ]),
  );
}
