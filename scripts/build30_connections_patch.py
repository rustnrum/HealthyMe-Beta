from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f'Salus build 30 connections patch: {message}')


app = Path('lib/app.dart')
text = app.read_text()

if "import 'screens/connections_screen.dart';" not in text:
    anchor = "import 'screens/ai_coach_screen.dart';\n"
    if anchor not in text:
        fail('app import anchor missing')
    text = text.replace(
        anchor,
        anchor + "import 'screens/connections_screen.dart';\n",
        1,
    )

if "SALUS_SHOW_DEVICE_DEBUG" not in text:
    anchor = "import 'widgets/morning_checkin_gate.dart';\n"
    if anchor not in text:
        fail('app debug-flag anchor missing')
    text = text.replace(
        anchor,
        anchor + "\nconst bool _showDeviceDebug = bool.fromEnvironment(\n"
        "  'SALUS_SHOW_DEVICE_DEBUG',\n"
        "  defaultValue: true,\n"
        ");\n",
        1,
    )

old_route = "        '/sources': (_) => const SourcesScreen(),\n"
new_routes = (
    "        '/sources': (_) => const ConnectionsScreen(),\n"
    "        '/sources-debug': (_) => _showDeviceDebug\n"
    "            ? const SourcesScreen()\n"
    "            : const ConnectionsScreen(),\n"
)
if new_routes not in text:
    if old_route not in text:
        fail('sources route anchor missing')
    text = text.replace(old_route, new_routes, 1)

app.write_text(text)

# Mark the existing verbose page explicitly as development-only.
sources = Path('lib/screens/sources_screen.dart')
text = sources.read_text()
text = text.replace(
    "appBar: AppBar(title: const Text('Devices & Sources')),",
    "appBar: AppBar(title: const Text('Device Debug')),",
    1,
)

if 'SALUS_BUILD30_DEBUG_BANNER' not in text:
    anchor = "        children: [\n          _buildIdentityCard(),\n"
    banner = """        children: [
          // SALUS_BUILD30_DEBUG_BANNER
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.amber.withValues(alpha: 0.24),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.bug_report_outlined,
                  color: AppTheme.amber,
                  size: 21,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'DEVELOPMENT ONLY\\nBluetooth inspection, protocol details, source routing and diagnostics live here. Normal users see the Connections screen.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.2,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildIdentityCard(),
"""
    if anchor not in text:
        fail('debug banner anchor missing')
    text = text.replace(anchor, banner, 1)

sources.write_text(text)

print('Salus build 30 normal Connections + hidden debug routing applied.')
