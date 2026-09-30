import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/bloodwork_result.dart';

class LabImportService {
  static List<BloodworkResult> parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final rows = const LineSplitter().convert(text);
    final results = <BloodworkResult>[];

    for (final raw in rows) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final parts = line.split(',').map((e) => e.trim()).toList();
      if (parts.length < 2) continue;

      final name = parts[0];
      final value = parts[1];

      if (name.toLowerCase() == 'testname' ||
          name.toLowerCase() == 'test' ||
          value.toLowerCase() == 'resultvalue') {
        continue;
      }

      results.add(
        BloodworkResult(
          testName: name,
          resultValue: value,
          unit: parts.length > 2 ? parts[2] : '',
          labSource: parts.length > 3 ? parts[3] : '',
        ),
      );
    }

    return results;
  }

  static List<BloodworkResult> parseXlsx(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final results = <BloodworkResult>[];

    for (final tableName in workbook.tables.keys) {
      final table = workbook.tables[tableName];
      if (table == null) continue;

      for (final row in table.rows) {
        if (row.length < 2) continue;

        final name = row[0]?.value?.toString().trim() ?? '';
        final value = row[1]?.value?.toString().trim() ?? '';
        if (name.isEmpty || value.isEmpty) continue;

        if (name.toLowerCase() == 'testname' ||
            name.toLowerCase() == 'test' ||
            value.toLowerCase() == 'resultvalue') {
          continue;
        }

        results.add(
          BloodworkResult(
            testName: name,
            resultValue: value,
            unit: row.length > 2
                ? (row[2]?.value?.toString().trim() ?? '')
                : '',
            labSource: row.length > 3
                ? (row[3]?.value?.toString().trim() ?? '')
                : '',
          ),
        );
      }
    }

    return results;
  }
}
