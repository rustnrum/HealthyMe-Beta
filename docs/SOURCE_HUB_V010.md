# Healthy Me v0.10 Source Hub

## Product rule

Healthy Me owns metric routing. Health Connect is an import transport, not a
user-selectable data source.

A provider is selectable for a metric only when Healthy Me has actually read a
record for that metric whose Health Connect `DataOrigin` identifies that
provider. Direct Bluetooth discovery alone does not make a device selectable.

## Health Connect provenance

Android Health Connect records carry `DataOrigin.packageName`. The Flutter
`health` plugin exposes the Android data origin through `HealthDataPoint`
`sourceName` / `sourceId`. Healthy Me keeps that provider identity and displays
it as `Garmin Connect`, `Samsung Health`, `iMoni`, `QRing`, etc. Brand mappings
are display-only and do not control routing behavior.

## Routing behavior

- Automatic: choose the freshest actual provider for the metric.
- Manual: use only the selected provider.
- If a manually selected provider has no current records, return no metric data;
  never silently substitute another provider.
- Steps are totaled from one resolved provider rather than using Health Connect's
  cross-provider aggregate, so the displayed number and displayed source stay
  aligned.
- Health Connect transport/package pseudo-sources are never offered in the
  metric picker.

## Source Hub UI

The main Data Sources screen shows:

1. Health Connect import status as plumbing only.
2. Actual record providers and the metrics Healthy Me has seen from each.
3. Per-metric source routing.
4. Nearby Bluetooth devices in a compact list.

Raw Bluetooth addresses, UUIDs, manufacturer bytes and GATT characteristic
properties are hidden under Advanced diagnostics.

## Bluetooth rule

Bluetooth behavior is capability/protocol based, not manufacturer based.
Manufacturer or advertised device names may be shown only for identification.
A known service fingerprint can identify a device class such as a smart ring,
but it remains non-selectable until Healthy Me has an implemented reader for
that metric.


## Android 2026 phone-step attribution

Health Connect can attribute on-device Steps to an app-scoped Synthetic Package Name
(SPN) beginning with `com.android.healthconnect.phone.`. Healthy Me treats that as
a real provider and displays it as **Your phone**. It is not filtered as the Health
Connect transport.
