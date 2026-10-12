# Salus Build 74 – Global layer isolation test

This is a *controlled diagnostic build*, not proof that the red tint is fixed.
Build 70 had no `MaterialApp.builder` full-screen Stack. Build 72 introduced
one for its global voice launcher. All screens began displaying red with
Build 72; disabling Impeller (Build 73) did not change it.

Build 74 removes only that new global root Stack while retaining the voice
assistant through each major module's Scaffold floating action button and
the existing `/voice` route. No new medical measurements, no DB resets,
no changes to signing identity or app package ID. All saved data stays intact.

Expected outcome to test on device: the red should disappear if the shared
full-screen wrapper caused the rendering/compositing problem. If it remains,
collect `adb logcat` and investigate OS-level debug overdraw / retained overlays
and remaining shared Flutter rendering, rather than claiming success.
