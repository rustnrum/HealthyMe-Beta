import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/salus_ai_service.dart';
import 'salus87_ui.dart';

/// Genuine opt-in AI analysis of the facts supplied by Home.
/// No remote request happens without informed consent; cache once per day.
class SalusHomeAiCard extends StatefulWidget {
  final String dayKey;
  final String evidence;
  final String localSummary;
  const SalusHomeAiCard({super.key, required this.dayKey,
    required this.evidence, required this.localSummary});

  @override
  State<SalusHomeAiCard> createState() => _SalusHomeAiCardState();
}

class _SalusHomeAiCardState extends State<SalusHomeAiCard> {
  static const _enabledKey = 'salus_ai_daily_health_consent_v1';
  static const _dateKey = 'salus_ai_daily_health_date_v1';
  static const _resultKey = 'salus_ai_daily_health_result_v1';
  bool _enabled = false;
  bool _busy = false;
  bool _loaded = false;
  String _date = '';
  String _result = '';
  String? _error;

  @override
  void initState() { super.initState(); _restore(); }

  @override
  void didUpdateWidget(covariant SalusHomeAiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dayKey != oldWidget.dayKey && _enabled && !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generate();
      });
    }
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = p.getBool(_enabledKey) ?? false;
      _date = p.getString(_dateKey) ?? '';
      _result = p.getString(_resultKey) ?? '';
      _loaded = true;
    });
    if (_enabled && _date != widget.dayKey) _generate();
  }

  Future<void> _enable() async {
    final consent = await showDialog<bool>(context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable daily AI health review?'),
        content: const Text('With your permission, Salus will send the measurements'
          ' shown in your daily summary to the connected AI service for an'
          ' explanation. This may use API credits. It runs at most once per day'
          ' automatically; you can refresh manually. AI cannot diagnose illness.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('I agree')),
        ],
      ));
    if (consent != true || !mounted) return;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_enabledKey, true);
    if (!mounted) return;
    setState(() => _enabled = true);
    await _generate();
  }

  Future<void> _generate() async {
    if (!_enabled || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final day = widget.dayKey;
      final evidence = widget.evidence;
      final response = await const SalusAiService().ask(
        'Review only the following verified or explicitly missing Salus data.'
        ' Write a concise daily wellness review, 90-150 words. Clearly state'
        ' uncertainty, prioritize concrete changes in real measured trends,'
        ' and provide 1-2 safe practical actions. Do not fabricate comparisons,'
        ' diagnoses, or treatment advice. Do not assume unrecorded values are zero.'
        ' Date: $day.\n$evidence');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dateKey, day);
      await prefs.setString(_resultKey, response);
      if (mounted) setState(() { _date = day; _result = response; });
    } catch (e) {
      if (mounted) setState(() => _error = 'AI unavailable: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDetails() async {
    final hasToday = _enabled && _date == widget.dayKey && _result.isNotEmpty;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (sheet) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
          Text(hasToday ? 'AI daily review' : 'Daily measurements summary',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(hasToday ? _result : widget.localSummary),
          const SizedBox(height: 14),
          const Text('Information used', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(widget.evidence),
          const SizedBox(height: 14),
          const Text('Wellness interpretation only, not a diagnosis.'),
          if (_enabled) Wrap(spacing: 12, children: [
            TextButton.icon(onPressed: () {
              Navigator.pop(sheet); _generate();
            }, icon: const Icon(Icons.refresh), label: const Text('Refresh AI review')),
            TextButton.icon(onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_enabledKey, false);
              await prefs.remove(_resultKey);
              await prefs.remove(_dateKey);
              if (!mounted) return;
              setState(() { _enabled = false; _result = ''; _date = ''; });
              if (sheet.mounted) Navigator.pop(sheet);
            }, icon: const Icon(Icons.block_outlined),
              label: const Text('Disable AI')),
          ]),
        ]),
      )));
  }

  @override
  Widget build(BuildContext context) {
    final hasToday = _enabled && _date == widget.dayKey && _result.isNotEmpty;
    return S87Panel(accent: S87.purple,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: S87.purple, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(hasToday ? 'AI Insight' : 'Daily Insight',
            style: const TextStyle(color: S87.ink, fontSize: 19,
              fontWeight: FontWeight.w800))),
          TextButton(onPressed: _openDetails,
            child: const Text('Details', style: TextStyle(color: S87.blue))),
          const Icon(Icons.chevron_right_rounded, color: S87.blue),
        ]),
        const SizedBox(height: 10),
        Text(hasToday ? _result : widget.localSummary,
          maxLines: 5, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: S87.ink, fontSize: 16, height: 1.38)),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 9),
          child: LinearProgressIndicator()),
        if (_loaded && !_enabled) TextButton.icon(onPressed: _enable,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Enable real AI review')),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: S87.orange, fontSize: 13)),
          TextButton(onPressed: _generate, child: const Text('Retry AI review')),
        ],
        if (hasToday) const Text('AI-generated · Check the underlying records',
          style: TextStyle(color: S87.muted, fontSize: 12)),
      ]),
    );
  }
}
