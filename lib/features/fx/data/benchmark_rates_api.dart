import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../domain/fx_engine.dart';
import '../domain/fx_models.dart';

class BenchmarkRatesApi {
  BenchmarkRatesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void close() => _client.close();

  Future<RatesSnapshot> fetch() async {
    final now = DateTime.now();
    final historyStart = DateTime(now.year - 10, now.month, now.day);
    final cbr = await _fetchCbr();
    final ecbHistory = await _fetchEcbEurUsdHistory(historyStart);
    if (ecbHistory.isEmpty) {
      throw StateError('ECB returned no EUR/USD observations');
    }
    final latestEcb = ecbHistory.last;
    return RatesSnapshot(
      usdRub: cbr.usdRub,
      eurRub: cbr.eurRub,
      bynRub: cbr.bynRub,
      eurUsd: latestEcb.value,
      cbr: FeedStatus(sourceDate: cbr.date, fetchedAt: DateTime.now()),
      ecb: FeedStatus(sourceDate: latestEcb.date, fetchedAt: DateTime.now()),
      ranges: FxEngine.calculateRanges(ecbHistory),
    );
  }

  Future<_CbrRates> _fetchCbr() async {
    final uri = Uri.https(
      'www.cbr.ru',
      '/scripts/XML_daily.asp',
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('CBR HTTP ${response.statusCode}');
    }

    final body = _decodeWindows1251(response.bodyBytes);
    final document = XmlDocument.parse(body);
    final root = document.rootElement;
    final sourceDate = _parseCbrDate(root.getAttribute('Date') ?? '');
    return _CbrRates(
      date: sourceDate,
      usdRub: _cbrRate(document, 'USD'),
      eurRub: _cbrRate(document, 'EUR'),
      bynRub: _cbrRate(document, 'BYN'),
    );
  }

  Future<List<RatePoint>> _fetchEcbEurUsdHistory(
    DateTime start, {
    DateTime? end,
  }) async {
    final uri = Uri.https(
      'data-api.ecb.europa.eu',
      '/service/data/EXR/D.USD.EUR.SP00.A',
      {
        'startPeriod': _date(start),
        if (end != null) 'endPeriod': _date(end),
        'format': 'csvdata',
      },
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('ECB HTTP ${response.statusCode}');
    }

    final lines = response.body
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return [];

    final header = _splitCsvLine(lines.first);
    final dateIndex = header.indexOf('TIME_PERIOD');
    final valueIndex = header.indexOf('OBS_VALUE');
    if (dateIndex == -1 || valueIndex == -1) {
      throw StateError('ECB CSV schema changed');
    }

    final points = <RatePoint>[];
    for (final line in lines.skip(1)) {
      final row = _splitCsvLine(line);
      if (row.length <= max(dateIndex, valueIndex)) continue;
      final value = double.tryParse(row[valueIndex]);
      final date = DateTime.tryParse(row[dateIndex]);
      if (value == null || date == null) continue;
      points.add(RatePoint(date: date, value: value));
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  static double _cbrRate(XmlDocument document, String code) {
    for (final valute in document.findAllElements('Valute')) {
      final charCode = valute.getElement('CharCode')?.innerText;
      if (charCode != code) continue;

      final unitRate = valute.getElement('VunitRate')?.innerText;
      if (unitRate != null && unitRate.trim().isNotEmpty) {
        final parsed = double.tryParse(unitRate.replaceAll(',', '.'));
        if (parsed != null) return parsed;
      }

      final value = valute.getElement('Value')?.innerText;
      final nominal = valute.getElement('Nominal')?.innerText;
      final parsedValue = double.tryParse((value ?? '').replaceAll(',', '.'));
      final parsedNominal = double.tryParse(
        (nominal ?? '1').replaceAll(',', '.'),
      );
      if (parsedValue != null && parsedNominal != null && parsedNominal != 0) {
        return parsedValue / parsedNominal;
      }
    }
    throw StateError('CBR rate $code not found');
  }

  static DateTime _parseCbrDate(String value) {
    final parts = value.split('.');
    if (parts.length != 3) throw StateError('CBR date format changed');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  static String _date(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  static String _decodeWindows1251(List<int> bytes) {
    final codeUnits = bytes.map((byte) {
      if (byte < 0x80) return byte;
      if (byte >= 0xC0) return 0x0410 + byte - 0xC0;
      if (byte >= 0xE0) return 0x0430 + byte - 0xE0;
      return _windows1251Extra[byte] ?? byte;
    }).toList();
    return String.fromCharCodes(codeUnits);
  }

  static const _windows1251Extra = {
    0xA8: 0x0401,
    0xB8: 0x0451,
    0x80: 0x0402,
    0x81: 0x0403,
    0x82: 0x201A,
    0x83: 0x0453,
    0x84: 0x201E,
    0x85: 0x2026,
    0x86: 0x2020,
    0x87: 0x2021,
    0x88: 0x20AC,
    0x89: 0x2030,
    0x8A: 0x0409,
    0x8B: 0x2039,
    0x8C: 0x040A,
    0x8D: 0x040C,
    0x8E: 0x040B,
    0x8F: 0x040F,
    0x90: 0x0452,
    0x91: 0x2018,
    0x92: 0x2019,
    0x93: 0x201C,
    0x94: 0x201D,
    0x95: 0x2022,
    0x96: 0x2013,
    0x97: 0x2014,
    0x99: 0x2122,
    0x9A: 0x0459,
    0x9B: 0x203A,
    0x9C: 0x045A,
    0x9D: 0x045C,
    0x9E: 0x045B,
    0x9F: 0x045F,
  };
}

class _CbrRates {
  const _CbrRates({
    required this.date,
    required this.usdRub,
    required this.eurRub,
    required this.bynRub,
  });

  final DateTime date;
  final double usdRub;
  final double eurRub;
  final double bynRub;
}
