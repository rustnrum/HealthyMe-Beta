import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/chatgpt_connection_service.dart';
import '../services/salus_ai_service.dart';

/// ChatGPT account is optional. No AI reply is fabricated while disconnected.
class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});
  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _accountService = const ChatGptConnectionService();
  final _ai = const SalusAiService();
  final _messages = <Map<String, String>>[];
  Map<String, dynamic>? _account;
  bool _busy = false;
  String? _error;
  String _tab = 'Chat';

  @override
  void initState() { super.initState(); _loadAccount(); }
  Future<void> _loadAccount() async {
    final account = await _accountService.account();
    if (mounted) setState(() => _account = account);
  }
  @override
  void dispose() { _controller.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _connect() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await _accountService.connect();
      if (mounted) setState(() => _account = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _disconnect() async {
    await _accountService.disconnect();
    if (mounted) setState(() { _account = null; _messages.clear(); _error = null; });
  }

  Future<void> _send([String? preset]) async {
    if (_busy || _account == null) return;
    final question = (preset ?? _controller.text).trim();
    if (question.isEmpty) return;
    final past = List<Map<String, String>>.from(_messages);
    setState(() {
      _controller.clear();
      _messages.add({'role': 'user', 'text': question});
      _busy = true;
      _error = null;
    });
    try {
      final reply = await _ai.ask(question, prior: past);
      if (mounted) setState(() => _messages.add({'role': 'assistant', 'text': reply}));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
          }
        });
      }
    }
  }

  Widget _connectCard() => Card(child: Padding(
    padding: const EdgeInsets.all(22),
    child: Column(children: [
      const Icon(Icons.auto_awesome, size: 42, color: AppTheme.mint),
      const SizedBox(height: 10),
      const Text('Connect Salus AI', style: TextStyle(
        fontSize: 23, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
      const SizedBox(height: 8),
      const Text('Sign in through ChatGPT to ask questions and analyze meal photos. '
          'Use of your ChatGPT plan is optional and requires your authorization.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: _busy ? null : _connect,
        icon: const Icon(Icons.login),
        label: Text(_busy ? 'Opening ChatGPT sign-in…' : 'Continue with ChatGPT'))),
      const SizedBox(height: 10),
      const Text('Your health data is not automatically uploaded to ChatGPT. '
          'Salus only sends what you ask it to analyze.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
    ]),
  ));

  Widget _connectionStatus() => Card(child: Padding(
    padding: const EdgeInsets.all(13),
    child: Row(children: [
      const Icon(Icons.verified_user_outlined, color: AppTheme.mint),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ChatGPT connected', style: TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        Text((_account?['email'] ?? 'Signed in').toString(),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ])),
      TextButton(onPressed: _busy ? null : _disconnect, child: const Text('Disconnect')),
    ]),
  ));

  Widget _bubble(Map<String, String> msg) {
    final human = msg['role'] == 'user';
    return Align(alignment: human ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 370),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: human ? AppTheme.cyan.withValues(alpha: 0.2) : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppTheme.border)),
        child: Text(msg['text'] ?? '', style: const TextStyle(color: AppTheme.textPrimary)),
      ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Salus AI'), actions: [
      if (_messages.isNotEmpty) IconButton(
        tooltip: 'Clear this conversation',
        onPressed: _busy ? null : () => setState(() => _messages.clear()),
        icon: const Icon(Icons.delete_outline)),
    ]),
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(children: [
        const Align(alignment: Alignment.centerLeft, child: Text('YOUR WELLNESS COACH',
            style: TextStyle(color: AppTheme.textMuted, letterSpacing: 2))),
        const SizedBox(height: 12),
        if (_account == null) _connectCard() else _connectionStatus(),
        if (_error != null) Padding(padding: const EdgeInsets.all(8),
          child: Text(_error!, style: const TextStyle(color: AppTheme.amber))),
        if (_account != null) ...[
          const SizedBox(height: 7),
          Row(children: [for (final value in ['Chat', 'Nutrition', 'Training', 'Health'])
            Expanded(child: Padding(padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(label: Text(value), selected: _tab == value,
                onSelected: (_) => setState(() => _tab = value)))),
          ]),
          Expanded(child: ListView(controller: _scroll, children: [
            if (_messages.isEmpty) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 30),
                child: Text('Ask Salus about meals, healthy habits or training. '
                    'Medical decisions still belong with your healthcare team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary))),
              for (final suggestion in [
                'Help me plan a protein-rich dinner.',
                'What should I log after my workout?',
                'How can I improve my meal consistency?',
              ]) ListTile(title: Text(suggestion),
                trailing: const Icon(Icons.arrow_outward, size: 17),
                onTap: _busy ? null : () => _send(suggestion)),
            ],
            for (final msg in _messages) _bubble(msg),
            if (_busy) const Padding(padding: EdgeInsets.all(12),
              child: Align(alignment: Alignment.centerLeft,
                child: CircularProgressIndicator())),
          ])),
          Row(children: [
            Expanded(child: TextField(controller: _controller,
              decoration: InputDecoration(hintText: 'Ask Salus about $_tab…'),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send())),
            const SizedBox(width: 7),
            IconButton(onPressed: _busy ? null : () => _send(),
              icon: const Icon(Icons.send, color: AppTheme.mint)),
          ]),
          const Text('AI answers can be incorrect. Conversations here are not synced to ChatGPT history.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
        ] else const Spacer(),
      ]),
    )),
  );
}
