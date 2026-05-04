import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../domain/fx_models.dart';

class BenchmarkRatesApi {
  BenchmarkRatesApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<BenchmarkRates> fetch() async {
    final now = DateTime.now().toUtc();
    final ecbStart = DateTime.utc(now.year - 10, now.month, now.day);

    debugPrint('[rates] fetch start');
    final cbr = await _fetchCbrLatest();
    final eurUsdHistory = await _fetchEcbEurUsdHistory(ecbStart);

    if (eurUsdHistory.length < 2) {
      throw StateError('ECB returned too few EUR/USD observations');
    }

    final latest = eurUsdHistory.last;
    final previous = eurUsdHistory[eurUsdHistory.length - 2];
    final cbrCross = cbr.eurRub / cbr.usdRub;

    return BenchmarkRates(
      usdRub: cbr.usdRub,
      eurRub: cbr.eurRub,
      eurUsd: latest.value,
      asOf: latest.date,
      ecbAsOf: latest.date,
      cbrAsOf: cbr.date,
      eurUsdDayChangePct: _pct(latest.value, previous.value),
      eurUsdWeekMedianDeviationPct: _medianDeviation(eurUsdHistory, 5),
      eurUsdMonthMedianDeviationPct: _medianDeviation(eurUsdHistory, 22),
      eurUsdYearMedianDeviationPct: _medianDeviation(eurUsdHistory, 260),
      lower3y: _percentileValue(_tail(eurUsdHistory, 260 * 3), 0.25),
      upper3y: _percentileValue(_tail(eurUsdHistory, 260 * 3), 0.75),
      lower5y: _percentileValue(_tail(eurUsdHistory, 260 * 5), 0.25),
      upper5y: _percentileValue(_tail(eurUsdHistory, 260 * 5), 0.75),
      lower10y: _percentileValue(eurUsdHistory, 0.10),
      upper10y: _percentileValue(eurUsdHistory, 0.90),
      eurUsdCbrCross: cbrCross,
      eurUsdSourceSpreadPct: _pct(latest.value, cbrCross),
      sourceLabel: 'ECB EUR/USD · CBR USD/RUB EUR/RUB',
      corridorLabel: 'ECB P25–P75, 10 лет P10–P90',
    );
  }

  Future<_CbrRates> _fetchCbrLatest() async {
    final uri = Uri.https('www.cbr.ru', '/scripts/XML_daily.asp');
    debugPrint('[rates][CBR] GET $uri');
    final response = await _client.get(uri).timeout(const Duration(seconds: 20));
    debugPrint('[rates][CBR] status=${response.statusCode} bytes=${response.bodyBytes.length}');
    if (response.statusCode != 200) {
      throw StateError('CBR HTTP ${response.statusCode}');
    }

    final body = _decodeWindows1251(response.bodyBytes);
    final document = XmlDocument.parse(body);
    final root = document.rootElement;
    final date = root.getAttribute('Date') ?? '';

    return _CbrRates(
      date: date,
      usdRub: _cbrRate(document, 'USD'),
      eurRub: _cbrRate(document, 'EUR'),
    );
  }

  Future<List<_RatePoint>> _fetchEcbEurUsdHistory(DateTime start) async {
    final uri = Uri.https(
      'data-api.ecb.europa.eu',
      '/service/data/EXR/D.USD.EUR.SP00.A',
      {
        'startPeriod': _date(start),
        'format': 'csvdata',
      },
    );
    debugPrint('[rates][ECB] GET $uri');
    final response = await _client.get(uri).timeout(const Duration(seconds: 20));
    debugPrint('[rates][ECB] status=${response.statusCode} bytes=${response.bodyBytes.length}');
    if (response.statusCode != 200) {
      throw StateError('ECB HTTP ${response.statusCode}');
    }

    final lines = response.body
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return [];

    final header = _splitCsv(lines.first);
    final dateIndex = header.indexOf('TIME_PERIOD');
    final valueIndex = header.indexOf('OBS_VALUE');
    if (dateIndex == -1 || valueIndex == -1) {
      throw StateError('ECB CSV schema changed');
    }

    final points = <_RatePoint>[];
    for (final line in lines.skip(1)) {
      final row = _splitCsv(line);
      if (row.length <= max(dateIndex, valueIndex)) continue;
      final value = double.tryParse(row[valueIndex]);
      if (value == null) continue;
      points.add(_RatePoint(date: row[dateIndex], value: value));
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  static double _cbrRate(XmlDocument document, String code) {
    for (final valute in document.findAllElements('Valute')) {
      final charCode = valute.getElement('CharCode')?.innerText;
      if (charCode != code) continue;

      final unitRate = valute.getElement('VunitRate')?.innerText;
      final value = valute.getElement('Value')?.innerText;
      final raw = unitRate ?? value;
      if (raw == null) break;

      final parsed = double.tryParse(raw.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }

    throw StateError('CBR rate $code not found');
  }

  static double _medianDeviation(List<_RatePoint> points, int days) {
    final latest = points.last.value;
    final window = points.length <= days ? points : points.sublist(points.length - days);
    return _pct(latest, _median(window.map((point) => point.value).toList()));
  }

  static double _percentileValue(List<_RatePoint> points, double percentile) {
    return _percentile(points.map((point) => point.value).toList(), percentile);
  }

  static List<_RatePoint> _tail(List<_RatePoint> points, int count) {
    if (points.length <= count) return points;
    return points.sublist(points.length - count);
  }

  static double _median(List<double> values) => _percentile(values, 0.5);

  static double _percentile(List<double> values, double percentile) {
    if (values.isEmpty) throw StateError('No values for percentile');
    final sorted = [...values]..sort();
    final index = (sorted.length - 1) * percentile;
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sorted[lower];
    final weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  static double _pct(double current, double baseline) {
    if (baseline == 0) return 0;
    return (current / baseline - 1) * 100;
  }

  static String _date(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static List<String> _splitCsv(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
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
    0xA1: 0x040E,
    0xA2: 0x045E,
    0xAA: 0x0404,
    0xAF: 0x0407,
    0xB2: 0x0406,
    0xB3: 0x0456,
    0xBA: 0x0454,
    0xBF: 0x0457,
  };
}

class _CbrRates {
  const _CbrRates({
    required this.date,
    required this.usdRub,
    required this.eurRub,
  });

  final String date;
  final double usdRub;
  final double eurRub;
}

class _RatePoint {
  const _RatePoint({required this.date, required this.value});

  final String date;
  final double value;
}
