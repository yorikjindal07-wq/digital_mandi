import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/india_locations.dart';
import '../models/weather_model.dart';
import '../providers/app_provider.dart';
import '../services/weather_service.dart';

const Map<String, Map<String, dynamic>> _weatherData = {
  'Punjab': {
    'summer': {
      'temp': '38-44°C',
      'rain': '15-30mm',
      'humidity': '30-50%',
      'advice': 'Irrigate wheat before harvest. Watch for aphids in heat.',
    },
    'kharif': {
      'temp': '28-35°C',
      'rain': '60-120mm',
      'humidity': '65-85%',
      'advice': 'Good for rice and maize. Monitor for blast disease.',
    },
    'winter': {
      'temp': '4-18°C',
      'rain': '20-50mm',
      'humidity': '50-70%',
      'advice': 'Ideal for wheat. Frost risk after Dec. Apply irrigation.',
    },
  },
  'Haryana': {
    'summer': {
      'temp': '40-46°C',
      'rain': '10-25mm',
      'humidity': '25-45%',
      'advice': 'Keep fields mulched. Drip irrigate vegetables.',
    },
    'kharif': {
      'temp': '30-36°C',
      'rain': '50-100mm',
      'humidity': '60-80%',
      'advice': 'Paddy transplanting season. Monitor for BPH.',
    },
    'winter': {
      'temp': '3-15°C',
      'rain': '15-40mm',
      'humidity': '45-65%',
      'advice': 'Wheat sowing time. Good mustard season.',
    },
  },
  'Maharashtra': {
    'summer': {
      'temp': '35-42°C',
      'rain': '5-20mm',
      'humidity': '20-40%',
      'advice': 'Irrigate sugarcane weekly. Protect cotton seedlings.',
    },
    'kharif': {
      'temp': '26-32°C',
      'rain': '100-300mm',
      'humidity': '70-90%',
      'advice': 'Soybean and cotton main season. Watch for bollworm.',
    },
    'winter': {
      'temp': '15-28°C',
      'rain': '0-15mm',
      'humidity': '40-60%',
      'advice': 'Rabi sorghum and chickpea. Good for onion.',
    },
  },
  'Uttar Pradesh': {
    'summer': {
      'temp': '38-45°C',
      'rain': '10-30mm',
      'humidity': '30-50%',
      'advice': 'Mango flowering period. Protect from heat stress.',
    },
    'kharif': {
      'temp': '28-34°C',
      'rain': '80-200mm',
      'humidity': '70-90%',
      'advice': 'Paddy season. Drain fields for weeding. Sugarcane irrigation.',
    },
    'winter': {
      'temp': '5-20°C',
      'rain': '10-30mm',
      'humidity': '50-75%',
      'advice': 'Wheat, mustard, pea season. Apply DAP at sowing.',
    },
  },
};

const List<String> _seasons = ['summer', 'kharif', 'winter'];
const Map<String, String> _seasonEmojis = {
  'summer': '☀️',
  'kharif': '🌧️',
  'winter': '❄️',
};
const Map<String, String> _seasonLabels = {
  'summer': 'Summer (Mar-Jun)',
  'kharif': 'Kharif (Jul-Oct)',
  'winter': 'Winter (Nov-Feb)',
};

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  String _selectedState = 'Punjab';
  String _selectedCity = 'Ludhiana';
  String _selectedSeason = 'kharif';
  WeatherData? _liveWeather;
  List<WeatherData> _threeDayForecast = const [];
  bool _isLoading = true;
  String? _error;
  late final TextEditingController _cityController;

  List<String> get _citySuggestions =>
      IndiaLocations.statesAndCities[_selectedState] ?? const <String>[];

  Future<void> _loadWeather() async {
    final liveWeatherCity = _cityController.text.trim().isEmpty
        ? _selectedCity
        : _cityController.text.trim();
    final languageCode = context.read<AppProvider>().languageCode;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final current = await WeatherService.getWeather(
        liveWeatherCity,
        languageCode: languageCode,
      );
      final forecast = await WeatherService.instance.getThreeDayForecast(
        liveWeatherCity,
        languageCode: languageCode,
      );

      setState(() {
        _liveWeather = current;
        _threeDayForecast = forecast;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _threeDayForecast = const [];
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: _selectedCity);
    _loadWeather();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    final scheme = Theme.of(context).colorScheme;
    final seasonalData = _weatherData[_selectedState]?[_selectedSeason];
    final irrigationAdvice = _liveWeather == null
        ? null
        : WeatherService.instance.getIrrigationAdvice(_liveWeather!);
    final diseaseRisk = _liveWeather == null
        ? null
        : WeatherService.instance.getDiseaseRiskAssessment(_liveWeather!);

    return Scaffold(
      appBar: AppBar(title: Text(l10n['weather'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NoticeBanner(scheme: scheme),
            const SizedBox(height: 18),
            _buildLiveWeatherSection(
              context,
              scheme,
              irrigationAdvice,
              diseaseRisk,
            ),
            const SizedBox(height: 16),
            _buildStateSelector(),
            const SizedBox(height: 12),
            _buildCitySelector(),
            const SizedBox(height: 18),
            _buildSeasonTabs(context, scheme),
            const SizedBox(height: 18),
            Text(
              '${_seasonEmojis[_selectedSeason]} ${_seasonLabel(l10n, _selectedSeason)}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (seasonalData != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _WeatherStatCard(
                      icon: Icons.thermostat,
                      label: l10n['temperature'],
                      value: seasonalData['temp'] as String,
                      color: const Color(0xFFE95D52),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WeatherStatCard(
                      icon: Icons.water_drop_rounded,
                      label: l10n['rainfall'],
                      value: seasonalData['rain'] as String,
                      color: const Color(0xFF2C78D0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _WeatherStatCard(
                icon: Icons.water,
                label: l10n['humidity'],
                value: seasonalData['humidity'] as String,
                color: const Color(0xFF2F8F46),
                fullWidth: true,
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.agriculture, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            l10n['seasonal_farming_advice'],
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        seasonalData['advice'] as String,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.55),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MonthlyCalendar(region: _selectedState),
            ] else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    l10n['seasonal_offline_notice'],
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWeatherSection(
    BuildContext context,
    ColorScheme scheme,
    String? irrigationAdvice,
    String? diseaseRisk,
  ) {
    final l10n = context.watch<AppProvider>().l10n;
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            l10n['weather_load_error'],
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    if (_liveWeather == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${l10n['live_weather']} - ${_liveWeather!.city}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _liveWeather!.getWeatherEmoji(),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_liveWeather!.temperature.toStringAsFixed(1)}°C',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _liveWeather!.description,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _WeatherChip(
                      icon: Icons.water_drop_rounded,
                      label: l10n['humidity'],
                      value: '${_liveWeather!.humidity}%',
                      color: const Color(0xFF2C78D0),
                    ),
                    _WeatherChip(
                      icon: Icons.air_rounded,
                      label: l10n['wind'],
                      value:
                          '${_liveWeather!.windSpeed.toStringAsFixed(1)} m/s',
                      color: const Color(0xFF2F8F46),
                    ),
                  ],
                ),
                if (_threeDayForecast.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    l10n['next_3_days'],
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 196,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _threeDayForecast.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        return _ForecastCard(
                          forecast: _threeDayForecast[index],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: scheme.primary.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n['live_farming_alerts'],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${l10n['irrigation']}: $irrigationAdvice',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 6),
                Text(
                  '${l10n['disease_risk']}: $diseaseRisk',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateSelector() {
    final l10n = context.watch<AppProvider>().l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedState,
            hint: Text(l10n['select_state']),
            items: IndiaLocations.statesAndCities.keys
                .map(
                  (state) => DropdownMenuItem(value: state, child: Text(state)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedState = value;
                _selectedCity =
                    IndiaLocations.statesAndCities[value]?.first ?? '';
                _cityController.text = _selectedCity;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCitySelector() {
    final l10n = context.watch<AppProvider>().l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _citySuggestions.contains(_selectedCity)
                  ? _selectedCity
                  : null,
              decoration: InputDecoration(labelText: l10n['suggested_city']),
              items: _citySuggestions
                  .map(
                    (city) => DropdownMenuItem(value: city, child: Text(city)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedCity = value;
                  _cityController.text = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: l10n['city'],
                hintText: l10n['city_hint'],
                prefixIcon: const Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadWeather,
                icon: const Icon(Icons.refresh),
                label: Text(l10n['load_live_weather']),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonTabs(BuildContext context, ColorScheme scheme) {
    final l10n = context.watch<AppProvider>().l10n;
    return Row(
      children: _seasons
          .map(
            (season) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedSeason = season),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedSeason == season
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _seasonEmojis[season]!,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _seasonTabLabel(l10n, season),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedSeason == season
                              ? Colors.white
                              : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  String _seasonLabel(AppL10n l10n, String season) {
    switch (season) {
      case 'summer':
        return l10n['summer_label'];
      case 'kharif':
        return l10n['kharif_label'];
      case 'winter':
        return l10n['winter_label'];
      default:
        return _seasonLabels[season] ?? season;
    }
  }

  String _seasonTabLabel(AppL10n l10n, String season) {
    switch (season) {
      case 'summer':
        return l10n['summer'];
      case 'kharif':
        return l10n['kharif'];
      case 'winter':
        return l10n['winter'];
      default:
        return season;
    }
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF8A5A16).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2A52A).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE2A52A).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_sync,
              size: 18,
              color: Color(0xFFE2A52A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n['weather_notice'],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color.withValues(alpha: 0.9),
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherStatCard extends StatelessWidget {
  const _WeatherStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    value,
                    maxLines: fullWidth ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final WeatherData forecast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDay(forecast.timestamp),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            forecast.getWeatherEmoji(),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            '${forecast.tempMax.toStringAsFixed(0)}° / ${forecast.tempMin.toStringAsFixed(0)}°',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 34,
            child: Text(
              forecast.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          const Spacer(),
          Text(
            '${l10n['rainfall']} ${forecast.rainVolume.toStringAsFixed(1)} mm',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _formatDay(DateTime date) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[date.weekday - 1];
  }
}

class _MonthlyCalendar extends StatelessWidget {
  const _MonthlyCalendar({required this.region});

  final String region;

  static const _months = [
    {'m': 'Jan', 'activity': 'Wheat growth'},
    {'m': 'Feb', 'activity': 'Mustard harvest'},
    {'m': 'Mar', 'activity': 'Rabi harvest'},
    {'m': 'Apr', 'activity': 'Summer veg'},
    {'m': 'May', 'activity': 'Field prep'},
    {'m': 'Jun', 'activity': 'Kharif sowing'},
    {'m': 'Jul', 'activity': 'Paddy transplant'},
    {'m': 'Aug', 'activity': 'Weed control'},
    {'m': 'Sep', 'activity': 'Kharif growth'},
    {'m': 'Oct', 'activity': 'Kharif harvest'},
    {'m': 'Nov', 'activity': 'Rabi sowing'},
    {'m': 'Dec', 'activity': 'Wheat growth'},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n['farming_calendar'],
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _months.length,
              itemBuilder: (_, i) {
                final isNow = (i + 1) == now.month;
                return Container(
                  decoration: BoxDecoration(
                    color: isNow
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _months[i]['m']!,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: isNow ? Colors.white : scheme.onSurface,
                        ),
                      ),
                      Text(
                        _months[i]['activity']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: isNow
                              ? Colors.white70
                              : scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
