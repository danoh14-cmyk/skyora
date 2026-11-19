import 'package:flutter_test/flutter_test.dart';
import 'package:skyora/kma_service.dart';

void main() {
  test('forecast categories are grouped per hour', () {
    final items = [
      {'fcstDate': '20261119', 'fcstTime': '2100', 'category': 'TMP', 'fcstValue': '1'},
      {'fcstDate': '20261119', 'fcstTime': '2100', 'category': 'SKY', 'fcstValue': '4'},
      {'fcstDate': '20261119', 'fcstTime': '2100', 'category': 'PTY', 'fcstValue': '0'},
      {'fcstDate': '20261119', 'fcstTime': '2100', 'category': 'PCP', 'fcstValue': '강수없음'},
    ];
    final result = KmaService.parseForecastItems(items);
    expect(result, hasLength(1));
    expect(result.first.temp, 1);
    expect(result.first.condition, '흐림');
    expect(result.first.precipitation, 0);
  });
  test('base time candidates fall back to yesterday when necessary', () {
    final result = KmaService.candidateBases(DateTime(2026, 11, 19, 0, 10));
    expect(result.first.day, 18);
    expect(result.first.hour, 23);
  });
}
