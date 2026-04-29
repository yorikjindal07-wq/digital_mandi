import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/local_db.dart' as local_db;
import '../models/models.dart';

class WeatherService {
  WeatherService._();

  static final WeatherService instance = WeatherService._();
  static const int _cacheValidityMinutes = 30;

  final http.Client _client = http.Client();
  bool _loggedMissingWeatherConfig = false;

  static Future<WeatherData> getWeather(
    String city, {
    String languageCode = 'en',
  }) {
    return instance.getWeatherWithFallback(city, languageCode: languageCode);
  }

  Future<WeatherData> getWeatherByCity(
    String city, {
    String languageCode = 'en',
  }) async {
    if (city.trim().isEmpty) {
      throw ValidationException(message: 'City name cannot be empty');
    }

    if (!AppConstants.hasOpenWeatherApiKey) {
      _logMissingWeatherConfig();
      return _getCachedWeatherOrThrow(city);
    }

    try {
      final response = await _client
          .get(
            Uri.parse(
              AppConstants.getWeatherUrl(city, languageCode: languageCode),
            ),
          )
          .timeout(AppConstants.weatherApiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final weather = _parseWeatherResponse(data, fallbackCity: city);
        await _cacheWeatherData(city, weather);
        return weather;
      }

      if (response.statusCode == 401) {
        throw NetworkException(
          message: 'Invalid weather API key. Please check the configuration.',
        );
      }

      if (response.statusCode == 404) {
        throw ValidationException(message: 'City "$city" not found');
      }

      throw NetworkException(
        message: 'Failed to fetch weather. Status: ${response.statusCode}',
      );
    } on AppException {
      rethrow;
    } catch (e) {
      debugPrint('Weather fetch failed for $city: $e');
      return _getCachedWeather(city);
    }
  }

  Future<WeatherData> getWeatherByCoordinates(
    double latitude,
    double longitude, {
    String languageCode = 'en',
  }) async {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ValidationException(message: 'Invalid coordinates');
    }

    if (!AppConstants.hasOpenWeatherApiKey) {
      _logMissingWeatherConfig();
      throw NetworkException(
        message:
            'Weather API key not configured. Pass OPENWEATHER_API_KEY with --dart-define.',
      );
    }

    final response = await _client
        .get(
          Uri.parse(
            AppConstants.getWeatherUrlByCoordinates(
              latitude,
              longitude,
              languageCode: languageCode,
            ),
          ),
        )
        .timeout(AppConstants.weatherApiTimeout);

    if (response.statusCode != 200) {
      throw NetworkException(
        message: 'Failed to fetch weather. Status: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseWeatherResponse(data);
  }

  Future<List<WeatherData>> getForecast(
    String city, {
    String languageCode = 'en',
  }) async {
    if (city.trim().isEmpty) {
      throw ValidationException(message: 'City name cannot be empty');
    }

    if (!AppConstants.hasOpenWeatherApiKey) {
      _logMissingWeatherConfig();
      return const [];
    }

    final response = await _client
        .get(
          Uri.parse(
            AppConstants.getForecastUrl(city, languageCode: languageCode),
          ),
        )
        .timeout(AppConstants.weatherApiTimeout);

    if (response.statusCode != 200) {
      throw NetworkException(
        message: 'Failed to fetch forecast. Status: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final fallbackCity =
        (data['city'] as Map<String, dynamic>?)?['name'] as String? ?? city;
    final forecasts = data['list'] as List<dynamic>? ?? const [];

    return forecasts
        .whereType<Map<String, dynamic>>()
        .map(
          (forecast) =>
              _parseWeatherResponse(forecast, fallbackCity: fallbackCity),
        )
        .toList();
  }

  Future<List<WeatherData>> getThreeDayForecast(
    String city, {
    String languageCode = 'en',
  }) async {
    final forecast = await getForecast(city, languageCode: languageCode);
    if (forecast.isEmpty) return const [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final Map<String, List<WeatherData>> grouped = {};

    for (final item in forecast) {
      final day = DateTime(
        item.timestamp.year,
        item.timestamp.month,
        item.timestamp.day,
      );
      if (!day.isAfter(today)) continue;

      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <WeatherData>[]).add(item);
    }

    final keys = grouped.keys.toList()..sort();

    return keys.take(3).map((key) {
      final items = grouped[key]!;
      final representative = _pickRepresentativeForecast(items);
      final minTemp = items
          .map((item) => item.tempMin)
          .reduce((value, element) => value < element ? value : element);
      final maxTemp = items
          .map((item) => item.tempMax)
          .reduce((value, element) => value > element ? value : element);
      final avgHumidity =
          items.fold<int>(0, (sum, item) => sum + item.humidity) ~/
          items.length;
      final totalRain = items.fold<double>(
        0,
        (sum, item) => sum + item.rainVolume,
      );
      final avgWind =
          items.fold<double>(0, (sum, item) => sum + item.windSpeed) /
          items.length;

      return representative.copyWith(
        temperature: (minTemp + maxTemp) / 2,
        tempMin: minTemp,
        tempMax: maxTemp,
        humidity: avgHumidity,
        rainVolume: totalRain,
        windSpeed: avgWind,
      );
    }).toList();
  }

  WeatherData _pickRepresentativeForecast(List<WeatherData> items) {
    WeatherData representative = items.first;
    var bestDistance = 24;

    for (final item in items) {
      final distance = (item.timestamp.hour - 12).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        representative = item;
      }
    }

    return representative;
  }

  WeatherData _parseWeatherResponse(
    Map<String, dynamic> data, {
    String? fallbackCity,
  }) {
    final main = data['main'] as Map<String, dynamic>? ?? const {};
    final weatherList = data['weather'] as List<dynamic>? ?? const [];
    final weather =
        weatherList.isNotEmpty && weatherList.first is Map<String, dynamic>
        ? weatherList.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final wind = data['wind'] as Map<String, dynamic>? ?? const {};
    final rain = data['rain'] as Map<String, dynamic>? ?? const {};
    final clouds = data['clouds'] as Map<String, dynamic>? ?? const {};
    final sys = data['sys'] as Map<String, dynamic>? ?? const {};

    final timestampSeconds = (data['dt'] as num?)?.toInt();
    final timestamp = timestampSeconds != null
        ? DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000)
        : DateTime.now();
    final fallbackSunrise = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      6,
    );
    final fallbackSunset = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      18,
    );

    return WeatherData(
      city: data['name'] as String? ?? fallbackCity ?? 'Unknown',
      temperature: (main['temp'] as num?)?.toDouble() ?? 0.0,
      feelsLike:
          (main['feels_like'] as num?)?.toDouble() ??
          (main['temp'] as num?)?.toDouble() ??
          0.0,
      tempMin:
          (main['temp_min'] as num?)?.toDouble() ??
          (main['temp'] as num?)?.toDouble() ??
          0.0,
      tempMax:
          (main['temp_max'] as num?)?.toDouble() ??
          (main['temp'] as num?)?.toDouble() ??
          0.0,
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      pressure: (main['pressure'] as num?)?.toInt() ?? 0,
      condition: weather['main'] as String? ?? 'Unknown',
      description: weather['description'] as String? ?? '',
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
      windDegree: (wind['deg'] as num?)?.toInt() ?? 0,
      cloudiness: (clouds['all'] as num?)?.toInt() ?? 0,
      rainVolume: ((rain['1h'] ?? rain['3h']) as num?)?.toDouble() ?? 0.0,
      visibility: (data['visibility'] as num?)?.toInt() ?? 0,
      sunrise: DateTime.fromMillisecondsSinceEpoch(
        ((sys['sunrise'] as num?)?.toInt() ??
                (fallbackSunrise.millisecondsSinceEpoch ~/ 1000)) *
            1000,
      ),
      sunset: DateTime.fromMillisecondsSinceEpoch(
        ((sys['sunset'] as num?)?.toInt() ??
                (fallbackSunset.millisecondsSinceEpoch ~/ 1000)) *
            1000,
      ),
      timestamp: timestamp,
    );
  }

  Future<void> _cacheWeatherData(String city, WeatherData weather) async {
    try {
      await local_db.LocalDatabase.instance.cacheWeather(city, weather);
    } catch (e) {
      debugPrint('Weather cache write failed for $city: $e');
    }
  }

  Future<WeatherData> _getCachedWeather(String city) async {
    final cached = await local_db.LocalDatabase.instance.getCachedWeather(city);

    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp);
      if (age.inMinutes < _cacheValidityMinutes) {
        return cached;
      }
    }

    throw NetworkException(
      message:
          'Cannot fetch weather and no recent cached data is available. Check internet connection.',
    );
  }

  Future<WeatherData> _getCachedWeatherOrThrow(String city) async {
    try {
      return await _getCachedWeather(city);
    } catch (_) {
      throw NetworkException(
        message:
            'Weather API key not configured and no recent cached weather is available. Pass OPENWEATHER_API_KEY with --dart-define.',
      );
    }
  }

  Future<WeatherData> getWeatherWithFallback(
    String city, {
    String languageCode = 'en',
  }) async {
    try {
      return await getWeatherByCity(city, languageCode: languageCode);
    } catch (e) {
      debugPrint('Falling back to cached weather for $city: $e');
      return _getCachedWeather(city);
    }
  }

  void _logMissingWeatherConfig() {
    if (_loggedMissingWeatherConfig) return;
    _loggedMissingWeatherConfig = true;
    debugPrint(
      'Live weather is disabled until OPENWEATHER_API_KEY is provided with --dart-define.',
    );
  }

  String formatWeatherDisplay(WeatherData weather) {
    return '''
${weather.city}
${weather.temperature.toStringAsFixed(1)}°C (feels like ${weather.feelsLike.toStringAsFixed(1)}°C)
${weather.condition} - ${weather.description}
Humidity: ${weather.humidity}%
Wind: ${weather.windSpeed.toStringAsFixed(1)} m/s
Rain: ${weather.rainVolume.toStringAsFixed(1)}mm
''';
  }

  String getIrrigationAdvice(WeatherData weather) {
    final humidity = weather.humidity;
    final temp = weather.temperature;
    final rain = weather.rainVolume;

    if (rain > 5) {
      return 'Heavy rain expected. Skip irrigation for 2-3 days.';
    }
    if (rain > 0) {
      return 'Light rain detected. Reduce irrigation amount.';
    }
    if (humidity > 70) {
      return 'High humidity. Skip irrigation today.';
    }
    if (humidity < 40 && temp > 30) {
      return 'Hot and dry conditions. Increase irrigation frequency.';
    }
    if (temp > 35) {
      return 'Extreme heat. Water early morning and evening.';
    }
    return 'Normal conditions. Regular irrigation schedule recommended.';
  }

  String getDiseaseRiskAssessment(WeatherData weather) {
    final humidity = weather.humidity;
    final temp = weather.temperature;
    final rain = weather.rainVolume;

    if (humidity > 75 && temp > 15 && temp < 30 && rain > 2) {
      return 'High risk: favorable conditions for fungal diseases.';
    }
    if (humidity > 65) {
      return 'Medium risk: monitor for fungal infections.';
    }
    if (humidity < 50) {
      return 'Low risk: dry conditions reduce disease spread.';
    }
    return 'Moderate risk: normal disease pressure.';
  }

  void dispose() {
    _client.close();
  }
}
