// ─────────────────────────────────────────────────────────────────────────
// models/weather_model.dart
// Weather data model with serialization
//
// ✅ FEATURES:
//   - Complete weather information
//   - JSON serialization for caching
//   - Null-safe design
//   - Production-ready
// ─────────────────────────────────────────────────────────────────────────

class WeatherData {
  final String city;
  final double temperature; // °C or °F based on settings
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity; // 0-100 %
  final int pressure; // hPa
  final String condition; // e.g., "Clouds", "Rain", "Clear"
  final String description; // e.g., "light rain"
  final double windSpeed; // m/s
  final int windDegree; // 0-360 degrees
  final int cloudiness; // 0-100 %
  final double rainVolume; // mm
  final int visibility; // meters
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime timestamp;

  WeatherData({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.pressure,
    required this.condition,
    required this.description,
    required this.windSpeed,
    required this.windDegree,
    required this.cloudiness,
    required this.rainVolume,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.timestamp,
  });

  // ─────────────────────────────────────────────────────────────────────
  // JSON SERIALIZATION FOR DATABASE CACHING
  // ─────────────────────────────────────────────────────────────────────

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'temperature': temperature,
      'feelsLike': feelsLike,
      'tempMin': tempMin,
      'tempMax': tempMax,
      'humidity': humidity,
      'pressure': pressure,
      'condition': condition,
      'description': description,
      'windSpeed': windSpeed,
      'windDegree': windDegree,
      'cloudiness': cloudiness,
      'rainVolume': rainVolume,
      'visibility': visibility,
      'sunrise': sunrise.toIso8601String(),
      'sunset': sunset.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from JSON
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      city: json['city'] as String? ?? 'Unknown',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (json['feelsLike'] as num?)?.toDouble() ?? 0.0,
      tempMin: (json['tempMin'] as num?)?.toDouble() ?? 0.0,
      tempMax: (json['tempMax'] as num?)?.toDouble() ?? 0.0,
      humidity: json['humidity'] as int? ?? 0,
      pressure: json['pressure'] as int? ?? 0,
      condition: json['condition'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
      windDegree: json['windDegree'] as int? ?? 0,
      cloudiness: json['cloudiness'] as int? ?? 0,
      rainVolume: (json['rainVolume'] as num?)?.toDouble() ?? 0.0,
      visibility: json['visibility'] as int? ?? 0,
      sunrise: DateTime.parse(json['sunrise'] as String? ?? DateTime.now().toIso8601String()),
      sunset: DateTime.parse(json['sunset'] as String? ?? DateTime.now().toIso8601String()),
      timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // COPY WITH METHOD
  // ─────────────────────────────────────────────────────────────────────

  WeatherData copyWith({
    String? city,
    double? temperature,
    double? feelsLike,
    double? tempMin,
    double? tempMax,
    int? humidity,
    int? pressure,
    String? condition,
    String? description,
    double? windSpeed,
    int? windDegree,
    int? cloudiness,
    double? rainVolume,
    int? visibility,
    DateTime? sunrise,
    DateTime? sunset,
    DateTime? timestamp,
  }) {
    return WeatherData(
      city: city ?? this.city,
      temperature: temperature ?? this.temperature,
      feelsLike: feelsLike ?? this.feelsLike,
      tempMin: tempMin ?? this.tempMin,
      tempMax: tempMax ?? this.tempMax,
      humidity: humidity ?? this.humidity,
      pressure: pressure ?? this.pressure,
      condition: condition ?? this.condition,
      description: description ?? this.description,
      windSpeed: windSpeed ?? this.windSpeed,
      windDegree: windDegree ?? this.windDegree,
      cloudiness: cloudiness ?? this.cloudiness,
      rainVolume: rainVolume ?? this.rainVolume,
      visibility: visibility ?? this.visibility,
      sunrise: sunrise ?? this.sunrise,
      sunset: sunset ?? this.sunset,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // UTILITY METHODS
  // ─────────────────────────────────────────────────────────────────────

  /// Get weather emoji based on condition
  String getWeatherEmoji() {
    switch (condition.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
      case 'drizzle':
        return '🌧️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
      case 'sand':
      case 'ash':
      case 'squall':
      case 'tornado':
        return '🌫️';
      default:
        return '🌡️';
    }
  }

  /// Check if it's raining
  bool isRaining() {
    return condition.toLowerCase().contains('rain') ||
        rainVolume > 0;
  }

  /// Check if temperature is extreme
  bool isExtremeCold() => temperature < 0;
  bool isExtremeHot() => temperature > 35;

  /// Check if conditions are good for farming
  bool isGoodForFarming() {
    return !isRaining() &&
        humidity >= 40 &&
        humidity <= 80 &&
        temperature >= 10 &&
        temperature <= 35;
  }

  /// Get time difference from now (for cache age)
  Duration timeSinceUpdate() {
    return DateTime.now().difference(timestamp);
  }

  /// Check if data is fresh (less than 30 minutes old)
  bool isFresh() {
    return timeSinceUpdate().inMinutes < 30;
  }

  @override
  String toString() {
    return '$city: ${temperature.toStringAsFixed(1)}°C, $description';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is WeatherData &&
        other.city == city &&
        other.temperature == temperature &&
        other.condition == condition &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return city.hashCode ^ temperature.hashCode ^ condition.hashCode ^ timestamp.hashCode;
  }
}