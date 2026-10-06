import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/salus_widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  final _name = TextEditingController();

  int _page = 0;
  String _sex = 'Male';
  DateTime? _birthday;
  double _heightIn = 64;
  double _weightLb = 200;
  double _goalWeightLb = 170;
  String _goal = 'Fat loss';
  String _activity = 'Mostly seated';
  bool _heightMetric = false;
  bool _weightMetric = false;

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 35),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (value != null) setState(() => _birthday = value);
  }

  void _next() {
    if (_page == 0 && (_name.text.trim().isEmpty || _birthday == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your name and date of birth first.')),
      );
      return;
    }

    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final profile = UserProfile(
      completed: true,
      firstName: _name.text.trim(),
      sex: _sex,
      birthday: _birthday,
      heightIn: _heightIn,
      startingWeightLb: _weightLb,
      manualCurrentWeightLb: _weightLb,
      goalWeightLb: _goalWeightLb,
      primaryGoal: _goal,
      activityLevel: _activity,
    );

    ref.read(appStateProvider.notifier).saveProfile(profile);
    ref.read(appStateProvider.notifier).logManualWeight(_weightLb);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SalusPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                page: _page,
                onBack: _page == 0
                    ? null
                    : () => _controller.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (value) => setState(() => _page = value),
                  children: [
                    _profilePage(),
                    _heightPage(),
                    _weightPage(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 10, 26, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_page == 2 ? 'Enter Salus' : 'Continue'),
                        const SizedBox(width: 10),
                        Icon(_page == 2 ? Icons.check_rounded : Icons.arrow_forward_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 6, 26, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 255,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -26,
                  top: -25,
                  width: 250,
                  height: 270,
                  child: Opacity(
                    opacity: 0.86,
                    child: Image.asset(
                      SalusAssets.profileHero,
                      fit: BoxFit.cover,
                      alignment: Alignment.topRight,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  top: 28,
                  child: _SalusWordmark(),
                ),
                const Positioned(
                  left: 0,
                  bottom: 4,
                  right: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create your\nSalus profile',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 42,
                          height: 0.98,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1.5,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'A few simple details to personalize your wellness journey.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _pickBirthday,
            child: Container(
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, color: AppTheme.textSecondary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _birthday == null
                          ? 'Date of birth'
                          : '${_birthday!.month}/${_birthday!.day}/${_birthday!.year}',
                      style: TextStyle(
                        color: _birthday == null ? AppTheme.textMuted : AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Sex', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _ChoiceChipButton(label: 'Male', selected: _sex == 'Male', onTap: () => setState(() => _sex = 'Male'))),
              const SizedBox(width: 10),
              Expanded(child: _ChoiceChipButton(label: 'Female', selected: _sex == 'Female', onTap: () => setState(() => _sex = 'Female'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heightPage() {
    final feet = (_heightIn ~/ 12);
    final inches = (_heightIn.round() % 12);
    final cm = (_heightIn * 2.54).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Height', style: TextStyle(color: AppTheme.textPrimary, fontSize: 38, fontWeight: FontWeight.w500, letterSpacing: -1.1)),
          const SizedBox(height: 7),
          const Text('Set your starting point.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          Center(
            child: _UnitToggle(
              left: 'ft',
              right: 'cm',
              rightSelected: _heightMetric,
              onChanged: (value) => setState(() => _heightMetric = value),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 340,
            child: Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: _HeightRulerPainter())),
                Positioned(
                  left: 32,
                  top: 102,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _heightMetric ? '$cm' : '$feet',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 62, height: 0.95, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _heightMetric ? 'CM' : 'FEET',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                      ),
                      if (!_heightMetric) ...[
                        const SizedBox(height: 12),
                        Text('$inches', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 52, height: 0.95, fontWeight: FontWeight.w600)),
                        const Text('INCH', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 18,
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    color: AppTheme.textPrimary.withValues(alpha: 0.82),
                    size: 230,
                  ),
                ),
              ],
            ),
          ),
          Slider(
            min: 48,
            max: 84,
            divisions: 36,
            value: _heightIn,
            label: _heightMetric ? '$cm cm' : '$feet ft $inches in',
            onChanged: (value) => setState(() => _heightIn = value),
          ),
        ],
      ),
    );
  }

  Widget _weightPage() {
    final shownWeight = _weightMetric ? _weightLb / 2.2046226218 : _weightLb;
    final shownGoal = _weightMetric ? _goalWeightLb / 2.2046226218 : _goalWeightLb;
    final unit = _weightMetric ? 'kg' : 'lb';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Weight', style: TextStyle(color: AppTheme.textPrimary, fontSize: 38, fontWeight: FontWeight.w500, letterSpacing: -1.1)),
          const SizedBox(height: 7),
          const Text('This becomes your starting weight.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 22),
          Center(
            child: _UnitToggle(
              left: 'lb',
              right: 'kg',
              rightSelected: _weightMetric,
              onChanged: (value) => setState(() => _weightMetric = value),
            ),
          ),
          const SizedBox(height: 15),
          const SizedBox(height: 65, width: double.infinity, child: CustomPaint(painter: _WeightRulerPainter())),
          Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: shownWeight.toStringAsFixed(_weightMetric ? 1 : 0), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 62, fontWeight: FontWeight.w600, letterSpacing: -1.8)),
                  TextSpan(text: '  ${unit.toUpperCase()}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          Slider(
            min: 90,
            max: 400,
            divisions: 310,
            value: _weightLb.clamp(90, 400).toDouble(),
            onChanged: (value) => setState(() => _weightLb = value),
          ),
          Center(
            child: Opacity(
              opacity: 0.92,
              child: Image.asset(SalusAssets.deviceScale, width: 145, height: 110, fit: BoxFit.contain, filterQuality: FilterQuality.high),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(child: Text('Goal weight', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w700))),
              Text('${shownGoal.toStringAsFixed(_weightMetric ? 1 : 0)} $unit', style: const TextStyle(color: AppTheme.cyan, fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          Slider(
            min: 90,
            max: 400,
            divisions: 310,
            value: _goalWeightLb.clamp(90, 400).toDouble(),
            onChanged: (value) => setState(() => _goalWeightLb = value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Primary goal'),
            items: const [
              DropdownMenuItem(value: 'Fat loss', child: Text('Fat loss')),
              DropdownMenuItem(value: 'Build strength', child: Text('Build strength')),
              DropdownMenuItem(value: 'Improve fitness', child: Text('Improve fitness')),
              DropdownMenuItem(value: 'Maintain health', child: Text('Maintain health')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _goal = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _activity,
            decoration: const InputDecoration(labelText: 'Typical activity'),
            items: const [
              DropdownMenuItem(value: 'Mostly seated', child: Text('Mostly seated')),
              DropdownMenuItem(value: 'Lightly active', child: Text('Lightly active')),
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Very active', child: Text('Very active')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _activity = value);
            },
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int page;
  final VoidCallback? onBack;

  const _TopBar({required this.page, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack == null
                ? null
                : IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20)),
          ),
          const Spacer(),
          Text('Questions ${page + 1}/3', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13.5, fontWeight: FontWeight.w600)),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _SalusWordmark extends StatelessWidget {
  const _SalusWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.cyan, width: 1.3),
            boxShadow: [BoxShadow(color: AppTheme.cyan.withValues(alpha: 0.18), blurRadius: 18)],
          ),
          child: const Icon(Icons.circle, color: AppTheme.cyan, size: 9),
        ),
        const SizedBox(width: 14),
        const Text('S A L U S', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w500, letterSpacing: 4.0)),
      ],
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChipButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.surfaceMuted : AppTheme.surfaceHigh.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppTheme.cyan.withValues(alpha: 0.55) : AppTheme.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppTheme.textPrimary : AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  const _UnitToggle({required this.left, required this.right, required this.rightSelected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppTheme.surfaceHigh, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          Expanded(child: _segment(left, !rightSelected, () => onChanged(false))),
          Expanded(child: _segment(right, rightSelected, () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A333A) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.4)) : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: selected ? AppTheme.textPrimary : AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _HeightRulerPainter extends CustomPainter {
  const _HeightRulerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = AppTheme.border.withValues(alpha: 0.7);
    final active = Paint()..color = AppTheme.cyan.withValues(alpha: 0.85);
    for (var i = 0; i <= 34; i++) {
      final y = i * size.height / 34;
      final major = i % 5 == 0;
      canvas.drawLine(Offset(0, y), Offset(major ? 28 : 16, y), line..strokeWidth = major ? 1.4 : 0.8);
    }
    final markerY = size.height * 0.50;
    canvas.drawLine(Offset(0, markerY), Offset(size.width * 0.42, markerY), active..strokeWidth = 1.5);
    final glow = Paint()
      ..shader = RadialGradient(colors: [AppTheme.cyan.withValues(alpha: 0.13), Colors.transparent]).createShader(
        Rect.fromCircle(center: Offset(size.width * 0.28, markerY), radius: 120),
      );
    canvas.drawCircle(Offset(size.width * 0.28, markerY), 120, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeightRulerPainter extends CustomPainter {
  const _WeightRulerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()..color = AppTheme.textSecondary.withValues(alpha: 0.58);
    final centerX = size.width / 2;
    for (var i = 0; i <= 50; i++) {
      final x = i * size.width / 50;
      final major = i % 5 == 0;
      canvas.drawLine(Offset(x, major ? 12 : 22), Offset(x, 48), line..strokeWidth = major ? 1.3 : 0.8);
    }
    final marker = Paint()
      ..color = AppTheme.textPrimary
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(centerX, 5), Offset(centerX, 60), marker);

    final glow = Paint()
      ..shader = LinearGradient(colors: [Colors.transparent, AppTheme.blue.withValues(alpha: 0.20), Colors.transparent]).createShader(
        Rect.fromCenter(center: Offset(centerX, 32), width: size.width * 0.58, height: 55),
      );
    canvas.drawRect(Rect.fromCenter(center: Offset(centerX, 32), width: size.width * 0.58, height: 55), glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
