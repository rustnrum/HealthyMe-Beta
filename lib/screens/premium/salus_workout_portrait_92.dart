import 'package:flutter/material.dart';

/// The user's explicit profile selection controls presentation only.
/// This widget does not infer gender from names, photos, or medical readings.
class SalusWorkoutPortrait92 extends StatelessWidget {
  const SalusWorkoutPortrait92({
    super.key,
    required this.profileSex,
    required this.profileCompleted,
    this.width = 128,
    this.height = 96,
  });

  final String profileSex;
  final bool profileCompleted;
  final double width;
  final double height;

  static String? assetFor({required String sex, required bool completed}) {
    if (!completed) return null;
    switch (sex.trim().toLowerCase()) {
      case 'male':
        return 'assets/premium/salus_workout_male_92.jpg';
      case 'female':
        return 'assets/premium/salus_workout_female_92.jpg';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(sex: profileSex, completed: profileCompleted);
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: const Color(0xFF1C2D3B),
          child: asset == null
              ? const Center(child: Icon(Icons.fitness_center_rounded,
                  size: 40, color: Color(0xFF42B5EB)))
              : Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stack) =>
                      const Center(child: Icon(Icons.fitness_center_rounded,
                        size: 40, color: Color(0xFF42B5EB))),
                ),
        ),
      ),
    );
  }
}
