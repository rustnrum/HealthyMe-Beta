import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../services/chatgpt_connection_service.dart';
import '../../services/salus_ai_service.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../ai_coach_screen.dart';

/// Camera-first nutrition estimates. Food photo must be deliberately sent;
/// estimated values are visibly labeled and never treated as verified facts.
class FoodPhotoAnalysisScreen extends ConsumerStatefulWidget {
  const FoodPhotoAnalysisScreen({super.key});
  @override
  ConsumerState<FoodPhotoAnalysisScreen> createState() => _FoodPhotoAnalysisScreenState();
}

class _FoodPhotoAnalysisScreenState extends ConsumerState<FoodPhotoAnalysisScreen> {
  final _picker = ImagePicker();
  final _ai = const SalusAiService();
  final _account = const ChatGptConnectionService();
  String? _path;
  String? _error;
  bool _busy = false;
  String _slot = 'Lunch';
  List<AiEstimatedFood>? _foods;
  final Set<int> _selected = {};
  double _portion = 1;
  String _notes = '';
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _account.account().then((value) {
      if (mounted) setState(() => _connected = value != null);
    });
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    try {
      final photo = await _picker.pickImage(source: source,
          imageQuality: 68, maxWidth: 1100);
      if (photo == null) return;
      if (mounted) setState(() {
        _path = photo.path;
        _foods = null;
        _selected.clear();
        _error = null;
        _notes = '';
        _portion = 1;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Cannot open camera or gallery: $error');
    }
  }

  Future<void> _analyze() async {
    if (_busy || _path == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final response = await _ai.ask('Identify each food in this plate and estimate '
          'its nutrients and approximate grams. Do not invent unseen ingredients.',
          imagePath: _path);
      final foods = AiEstimatedFood.parse(response);
      final parsedNotes = response.contains('"notes"')
          ? 'Visual estimate only. Confirm ingredients and amounts before logging.'
          : 'Visual estimate. Hidden ingredients and oil cannot be seen.';
      if (mounted) setState(() {
        _foods = foods;
        _notes = parsedNotes;
        _selected.addAll(List.generate(foods.length, (i) => i));
        if (foods.isEmpty) _error = 'No recognizable foods. Retake the photo.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _log() async {
    if (_busy || _foods == null || _selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      for (final i in _selected.toList()..sort()) {
        final f = _foods![i];
        await ref.read(dietLogStateProvider.notifier).addFood(FoodLogEntry(
          id: '', eatenAt: now, slot: _slot, name: f.name,
          portion: '${(f.grams * _portion).round()} g (photo estimate)',
          calories: f.calories * _portion,
          protein: f.protein * _portion,
          carbs: f.carbs * _portion,
          fat: f.fat * _portion,
          sourceName: 'AI photo estimate (unverified)',
        ));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estimated foods added to today’s log.')));
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save: $error');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  String _n(double v, [String suffix = '']) => '${(v * _portion).round()}$suffix';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Analyze food photo')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
      const Text('PHOTO NUTRITION', style: TextStyle(
          color: AppTheme.mint, letterSpacing: 1.6, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      if (_path != null) ClipRRect(borderRadius: BorderRadius.circular(19),
        child: Image.file(File(_path!), height: 242, fit: BoxFit.cover,
          errorBuilder: (a,b,c) => const SizedBox(height: 100,
            child: Center(child: Text('Could not preview photo')))))
      else Container(height: 190,
        decoration: BoxDecoration(color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(20)),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.camera_alt_outlined, size: 56, color: AppTheme.mint),
          SizedBox(height: 10),
          Text('Take a photo of your meal', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 18)),
        ])),
      const SizedBox(height: 13),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _pick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : () => _pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery'))),
      ]),
      const SizedBox(height: 12),
      if (!_connected) Card(child: Padding(padding: const EdgeInsets.all(15),
        child: Column(children: [
          const Text('Connect ChatGPT to recognize food photos.',
            style: TextStyle(color: AppTheme.textPrimary)),
          TextButton.icon(onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => const AiCoachScreen()));
            final account = await _account.account();
            if (mounted) setState(() => _connected = account != null);
          }, icon: const Icon(Icons.login), label: const Text('Connect ChatGPT')),
        ])))
      else SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: _busy || _path == null ? null : _analyze,
        icon: _busy ? const SizedBox(width: 17, height: 17,
            child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
        label: Text(_busy ? 'Analyzing photo…' : 'Analyze with ChatGPT'))),
      if (_error != null) Padding(padding: const EdgeInsets.all(10),
        child: Text(_error!, style: const TextStyle(color: AppTheme.amber))),
      if (_foods != null && _foods!.isNotEmpty) ...[
        const SizedBox(height: 20),
        const Text('Recognized foods', style: TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 5),
        Text(_notes, style: const TextStyle(color: AppTheme.amber, fontSize: 12)),
        for (var i = 0; i < _foods!.length; i++) CheckboxListTile(
          value: _selected.contains(i),
          onChanged: (v) => setState(() {
            if (v == true) { _selected.add(i); } else { _selected.remove(i); }
          }),
          title: Text(_foods![i].name,
            style: const TextStyle(color: AppTheme.textPrimary)),
          subtitle: Text('≈ ${_n(_foods![i].grams, ' g')} • '
              '${_n(_foods![i].calories, ' kcal')} • '
              '${_n(_foods![i].protein, ' g protein')}',
            style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        const SizedBox(height: 12),
        const Text('Adjust estimated portion', style: TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        Wrap(spacing: 6, children: [
          for (final amount in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
            ChoiceChip(label: Text('${amount}×'), selected: _portion == amount,
              onSelected: (_) => setState(() => _portion = amount)),
        ]),
        const SizedBox(height: 10),
        const Text('Meal', style: TextStyle(color: AppTheme.textPrimary)),
        Wrap(spacing: 7, children: [
          for (final name in salusMealSlots)
            ChoiceChip(label: Text(name), selected: _slot == name,
              onSelected: (_) => setState(() => _slot = name)),
        ]),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Estimated total · selected items', style: TextStyle(
              color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Text('${_n(_selected.fold<double>(0, (sum, i) => sum + _foods![i].calories), ' kcal')} '
                ' • ${_n(_selected.fold<double>(0, (sum, i) => sum + _foods![i].protein), ' g protein')}',
              style: const TextStyle(fontSize: 18,
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ]))),
        const SizedBox(height: 8),
        const Text('These are AI estimates, not verified nutrition facts. '
            'Cooking oils, ingredients and true weight may be missing.',
          style: TextStyle(color: AppTheme.amber, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _busy || _selected.isEmpty ? null : _log,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add selected foods to today'))),
      ],
    ])),
  );
}
