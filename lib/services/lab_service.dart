import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/models.dart';

class LabService {
  static const common = [
    'A1C',
    'Fasting glucose',
    'Total cholesterol',
    'LDL cholesterol',
    'HDL cholesterol',
    'Triglycerides',
    'Vitamin D',
    'Ferritin',
    'Iron',
    'Hemoglobin',
    'Hematocrit',
    'Vitamin B12',
    'Folate',
    'TSH',
    'Free T4',
    'AST',
    'ALT',
    'Creatinine',
    'eGFR',
    'Sodium',
    'Potassium',
    'Magnesium',
    'hs-CRP',
    'Cortisol',
  ];

  static const male = [
    'Total testosterone',
    'Free testosterone',
    'SHBG',
    'Estradiol',
  ];

  static const female = [
    'Estradiol',
    'Progesterone',
    'FSH',
    'LH',
    'Total testosterone',
    'Free testosterone',
    'SHBG',
  ];

  static List<String> markersForSex(String sex) {
    final values = <String>{
      ...common,
      ...(sex == 'Female' ? female : male),
    }.toList()
      ..sort();
    return values;
  }

  static List<LabResult> parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty) return const [];

    final rows = lines
        .map((line) => _csvLine(line))
        .where((row) => row.any((value) => value.trim().isNotEmpty))
        .toList();

    return _rowsToLabs(rows);
  }

  static List<LabResult> parseXlsx(Uint8List bytes) {
    final book = Excel.decodeBytes(bytes);
    final all = <LabResult>[];

    for (final name in book.tables.keys) {
      final table = book.tables[name];
      if (table == null) continue;
      final rows = table.rows
          .map(
            (row) => row
                .map((cell) => cell?.value?.toString().trim() ?? '')
                .toList(),
          )
          .toList();
      all.addAll(_rowsToLabs(rows));
    }

    return all;
  }

  static List<LabResult> _rowsToLabs(List<List<String>> rows) {
    if (rows.isEmpty) return const [];

    final header = rows.first.map((e) => e.trim().toLowerCase()).toList();
    int find(List<String> names) {
      for (var i = 0; i < header.length; i++) {
        if (names.contains(header[i])) return i;
      }
      return -1;
    }

    final testIndex = find(['test', 'test name', 'testname', 'marker', 'lab']);
    final valueIndex = find(['result', 'result value', 'resultvalue', 'value']);
    final unitIndex = find(['unit', 'units']);
    final dateIndex = find(['date', 'collection date', 'collectiondate']);
    final sourceIndex = find(['source', 'lab source', 'labsource']);

    final hasHeader = testIndex >= 0 && valueIndex >= 0;
    final sourceRows = hasHeader ? rows.skip(1) : rows;

    String at(List<String> row, int index) {
      if (index < 0 || index >= row.length) return '';
      return row[index].trim();
    }

    final results = <LabResult>[];
    for (final row in sourceRows) {
      final test = hasHeader ? at(row, testIndex) : at(row, 0);
      final value = hasHeader ? at(row, valueIndex) : at(row, 1);
      if (test.isEmpty || value.isEmpty) continue;

      results.add(
        LabResult(
          id: '${DateTime.now().microsecondsSinceEpoch}_${results.length}',
          name: test,
          value: value,
          unit: hasHeader ? at(row, unitIndex) : at(row, 2),
          date: DateTime.tryParse(
            hasHeader ? at(row, dateIndex) : at(row, 3),
          ),
          source: hasHeader ? at(row, sourceIndex) : at(row, 4),
        ),
      );
    }

    return results;
  }

  static List<String> _csvLine(String line) {
    final result = <String>[];
    final field = StringBuffer();
    var quoted = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        result.add(field.toString());
        field.clear();
      } else {
        field.write(char);
      }
    }
    result.add(field.toString());
    return result;
  }
}
