import 'package:digital_mandi/models/weather_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WeatherData buildWeather({
    String condition = 'Clear',
    double rainVolume = 0,
    double temperature = 28,
    int humidity = 55,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return WeatherData(
      city: 'Ludhiana',
      temperature: temperature,
      feelsLike: temperature - 1,
      tempMin: temperature - 3,
      tempMax: temperature + 2,
      humidity: humidity,
      pressure: 1004,
      condition: condition,
      description: 'clear sky',
      windSpeed: 2.5,
      windDegree: 180,
      cloudiness: 10,
      rainVolume: rainVolume,
      visibility: 10000,
      sunrise: now.subtract(const Duration(hours: 6)),
      sunset: now.add(const Duration(hours: 6)),
      timestamp: now,
    );
  }

  group('WeatherData', () {
    test('serializes and deserializes consistently', () {
      final original = buildWeather();
      final restored = WeatherData.fromJson(original.toJson());

      expect(restored.city, original.city);
      expect(restored.temperature, original.temperature);
      expect(restored.feelsLike, original.feelsLike);
      expect(restored.condition, original.condition);
      expect(restored.timestamp, original.timestamp);
    });

    test('reports rain and emoji from weather condition', () {
      final rainy = buildWeather(condition: 'Rain', rainVolume: 4.2);
      final cloudy = buildWeather(condition: 'Clouds');

      expect(rainy.isRaining(), isTrue);
      expect(rainy.getWeatherEmoji(), isNotEmpty);
      expect(cloudy.getWeatherEmoji(), isNotEmpty);
    });

    test('evaluates farming suitability and freshness', () {
      final good = buildWeather(timestamp: DateTime.now());
      final stale = buildWeather(
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      );
      final tooHot = buildWeather(temperature: 41, humidity: 20);

      expect(good.isGoodForFarming(), isTrue);
      expect(good.isFresh(), isTrue);
      expect(stale.isFresh(), isFalse);
      expect(tooHot.isExtremeHot(), isTrue);
      expect(tooHot.isGoodForFarming(), isFalse);
    });
  });
}
