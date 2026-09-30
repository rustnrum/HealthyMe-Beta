import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/bloodwork_result.dart';

class LabImportService {
  static List<BloodworkResult> parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final rows = _parseCsvRows(text);
    if (rows.isEmpty) return const [];

    final headerMap = _headerMap(rows.first);
    final hasHeader = headerMap.isNotEmpty;
    final dataRows = hasHeader ? rows.skip(1) : rows;

    return dataRows
        .map((row) => _resultFromRow(row, headerMap))
        .whereType<BloodworkResult>()
        .toList();
  }

  static List<BloodworkResult> parseXlsx(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final results = <BloodworkResult>[];

    for (final tableName in workbook.tables.keys) {
      final table = workbook.tables[tableName];
      if (table == null || table.rows.isEmpty) continue;

      final rows = table.rows
          .map(
            (row) => row
                .map((cell) => cell?.value?.toString().trim() ?? '')
                .toList(),
          )
          .toList();

      final headerMap = _headerMap(rows.first);
      final hasHeader = headerMap.isNotEmpty;
      final dataRows = hasHeader ? rows.skip(1) : rows;

      for (final row in dataRows) {
        final result = _resultFromRow(row, headerMap);
        if (result != null) results.add(result);
      }
    }

    return results;
  }

  static Map<String, int> _headerMap(List<String> row) {
    final map = <String, int>{};

    for (var i = 0; i < row.length; i++) {
      final value = row[i].trim().toLowerCase();
      if (['test', 'test name', 'testname', 'marker', 'lab'].contains(value)) {
        map['test'] = i;
      } else if (['result', 'result value', 'resultvalue', 'value']
          .contains(value)) {
        map['value'] = i;
      } else if (['unit', 'units'].contains(value)) {
        map['unit'] = i;
      } else if (['source', 'lab source', 'labsource', 'laboratory']
          .contains(value)) {
        map['source'] = i;
      } else if (['date', 'collection date', 'collectiondate']
          .contains(value)) {
        map['date'] = i;
      }
    }

    return map.containsKey('test') && map.containsKey('value') ? map : {};
  }

  static BloodworkResult? _resultFromRow(
    List<String> row,
    Map<String, int> headerMap,
  ) {
    String at(int? index) {
      if (index == null || index < 0 || index >= row.length) return '';
      return row[index].trim();
    }

    final name = headerMap.isEmpty ? at(0) : at(headerMap['test']);
    final value = headerMap.isEmpty ? at(1) : at(headerMap['value']);
    if (name.isEmpty || value.isEmpty) return null;

    final unit = headerMap.isEmpty ? at(2) : at(headerMap['unit']);
    final source = headerMap.isEmpty ? at(3) : at(headerMap['source']);
    final dateText = headerMap.isEmpty ? at(4) : at(headerMap['date']);

    return BloodworkResult(
      id: DateTime.now().microsecondsSinceEpoch.toString() + name.hashCode.toString(),
      testName: name,
      resultValue: value,
      unit: unit,
      labSource: source,
      collectionDate: DateTime.tryParse(dateText),
    );
  }

  static List<List<String>> _parseCsvRows(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var inQuotes = false;

    void finishField() {
      row.add(field.toString().trim());
      field = StringBuffer();
    }

    void finishRow() {
      finishField();
      if (row.any((cell) => cell.isNotEmpty)) rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < input.length; i++) {
      final char = input[i];

      if (char == '"') {
        final escaped =
            inQuotes && i + 1 < input.length && input[i + 1] == '"';
        if (escaped) {
          field.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        finishField();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        finishRow();
      } else {
        field.write(char);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) finishRow();
    return rows;
  }
}
