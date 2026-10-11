"""Build 57 UI/readiness refinement on top of committed Build 56.

Idempotent strict anchors. Keep all installed user data, native Garmin code,
source attribution, package ID, and signing configuration untouched.
"""
from pathlib import Path


def replace(path: str, old: str, new: str) -> None:
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if new in s:
        return
    if s.count(old) != 1:
        raise RuntimeError(f'Unexpected {path} anchor count {s.count(old)}: {old[:90]!r}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')


home = 'lib/screens/home_screen.dart'
replace(home, "import '../services/recovery_service.dart';",
        "import '../services/recovery_service.dart';\nimport '../services/home_insight_service.dart';")
replace(home, "import '../widgets/salus_widgets.dart';",
        "import '../widgets/salus_widgets.dart';\nimport '../widgets/salus_sync_quick_action.dart';")
replace(home, '    final recovery = RecoveryService.build(app);',
        '    final recovery = RecoveryService.build(app);\n    final insight = HomeInsightService.build(app);')
replace(home, '''                subtitle: _recoverySubtitle(recovery.score),''',
        '''                subtitle: recovery.score == null
                    ? '${recovery.confidence}% data coverage · tap to see what is missing'
                    : recovery.label == 'Preliminary'
                        ? recovery.summary
                        : _recoverySubtitle(recovery.score),''')
replace(home, '''            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 134,''',
'''            const SizedBox(height: 12),
            SalusPaper(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 17, color: AppTheme.mint),
                      SizedBox(width: 7),
                      Text('Last 24 hours · Insight',
                          style: TextStyle(color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(insight.message, style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13, height: 1.35)),
                  const SizedBox(height: 5),
                  Text(insight.source, style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 134,''')
replace(home, '''                      SalusQuickAction(
                        icon: Icons.sync_rounded,
                        label: 'Sync',
                        onTap: () => _sync(ref),
                      ),''',
'''                      SalusSyncQuickAction(onTap: () => _sync(ref)),''')
# Display actual successful import time or the recorded error, never fake a "synced" banner.
replace(home, '''                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}''',
'''                  ),
                  if (h.lastSync != null || h.error != null) ...[
                    const SizedBox(height: 8),
                    Text(h.error != null
                        ? 'Sync issue: ${h.error}'
                        : 'Last successful import: ${h.lastSync!.hour.toString().padLeft(2, '0')}:${h.lastSync!.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}''')

rec='lib/services/recovery_service.dart'
replace(rec, "'Recovery is building. Salus needs more overnight or morning check-in data before showing a number.'",
        "'No scored overnight signals or completed check-in yet. Open Recovery to see what is missing.'")
replace(rec, '''    if (dailyScore == null &&
        objectiveWeight < _minimumObjectiveCoverage) {
      return RecoveryReport(
        score: null,
        confidence: objectiveConfidence,
        band: RecoveryBand.noData,
        label: 'Building',
        summary:
            'More overnight signals are needed before Salus shows a reliable recovery number.',
        contributors: contributors,
      );
    }''',
'''    if (dailyScore == null &&
        objectiveWeight < _minimumObjectiveCoverage) {
      // Two independent objective contributors can offer an early estimate,
      // visibly marked preliminary with low coverage. A single favorable
      // sleep reading must NEVER be presented as a full readiness score.
      if (objectiveScored.length >= 2 && objectiveScore != null) {
        return RecoveryReport(
          score: objectiveScore,
          confidence: objectiveConfidence,
          band: RecoveryBand.noData,
          label: 'Preliminary',
          summary: 'Preliminary · only $objectiveWeight% signal coverage. Tap to review.',
          contributors: contributors,
        );
      }
      final available = objectiveScored.isEmpty
          ? 'No overnight metrics'
          : objectiveScored.map((entry) => entry.name.toLowerCase()).join(' + ');
      return RecoveryReport(
        score: null,
        confidence: objectiveConfidence,
        band: RecoveryBand.noData,
        label: 'Building',
        summary: '$available provides only $objectiveWeight% of needed recovery coverage. Add another source or complete the morning check-in.',
        contributors: contributors,
      );
    }''')
replace('pubspec.yaml','version: 0.21.18+56','version: 0.21.19+57')

# Historical tests used an exact version string; retain assertions for this
# version rather than letting the previous-build source contract fail.
for path in Path('test').glob('*.dart'):
    before=path.read_text(encoding='utf-8')
    after=before.replace('version: 0.21.18+56','version: 0.21.19+57')
    if after!=before:
        path.write_text(after,encoding='utf-8')

print('Build 57: one timestamped home insight, transparent preliminary recovery, real syncing icon, actual last-import feedback, version bumped.')
