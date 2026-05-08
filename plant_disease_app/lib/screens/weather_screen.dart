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
  Map<String, List<String>> _statesAndCities =
      IndiaLocations.fallbackStatesAndCities;
  WeatherData? _liveWeather;
  List<WeatherData> _threeDayForecast = const [];
  bool _isLoading = true;
  String? _error;
  late final TextEditingController _cityController;

  List<String> get _citySuggestions =>
      _statesAndCities[_selectedState] ?? const <String>[];

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
    _loadLocations();
    _loadWeather();
  }

  Future<void> _loadLocations() async {
    final locations = await IndiaLocations.loadStatesAndCities();
    if (!mounted) return;

    setState(() {
      _statesAndCities = locations;

      if (!_statesAndCities.containsKey(_selectedState)) {
        _selectedState = _statesAndCities.keys.first;
      }

      final cities = _statesAndCities[_selectedState] ?? const <String>[];
      if (!cities.contains(_selectedCity) && cities.isNotEmpty) {
        _selectedCity = cities.first;
        _cityController.text = _selectedCity;
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<AppProvider>().l10n;
    final lang = context.watch<AppProvider>().languageCode;
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
                        _weatherText(lang, seasonalData['advice'] as String),
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
    final lang = context.watch<AppProvider>().languageCode;
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
                  '${l10n['irrigation']}: ${irrigationAdvice == null ? '' : _weatherText(lang, irrigationAdvice)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 6),
                Text(
                  '${l10n['disease_risk']}: ${diseaseRisk == null ? '' : _weatherText(lang, diseaseRisk)}',
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
            items: _statesAndCities.keys
                .map(
                  (state) => DropdownMenuItem(value: state, child: Text(state)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final nextCities = _statesAndCities[value] ?? const <String>[];
              setState(() {
                _selectedState = value;
                _selectedCity = nextCities.isNotEmpty ? nextCities.first : '';
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
    final lang = context.watch<AppProvider>().languageCode;
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
            _formatDay(lang, forecast.timestamp),
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

  String _formatDay(String lang, DateTime date) {
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const hi = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
    const pa = ['ਸੋਮ', 'ਮੰਗਲ', 'ਬੁੱਧ', 'ਵੀਰ', 'ਸ਼ੁੱਕਰ', 'ਸ਼ਨੀ', 'ਐਤ'];
    const mr = ['सोम', 'मंगळ', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
    const te = ['సోమ', 'మంగళ', 'బుధ', 'గురు', 'శుక్ర', 'శని', 'ఆది'];

    if (lang == 'hi') {
      return hi[date.weekday - 1];
    }
    if (lang == 'pa') {
      return pa[date.weekday - 1];
    }
    if (lang == 'mr') {
      return mr[date.weekday - 1];
    }
    if (lang == 'te') {
      return te[date.weekday - 1];
    }
    return en[date.weekday - 1];
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
    final lang = context.watch<AppProvider>().languageCode;
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
                        _weatherMonthLabel(lang, _months[i]['m']!),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: isNow ? Colors.white : scheme.onSurface,
                        ),
                      ),
                      Text(
                        _weatherText(lang, _months[i]['activity']!),
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

String _weatherMonthLabel(String lang, String month) {
  const hi = {
    'Jan': 'जन',
    'Feb': 'फर',
    'Mar': 'मार्च',
    'Apr': 'अप्रै',
    'May': 'मई',
    'Jun': 'जून',
    'Jul': 'जुल',
    'Aug': 'अग',
    'Sep': 'सित',
    'Oct': 'अक्टू',
    'Nov': 'नव',
    'Dec': 'दिस',
  };
  const pa = {
    'Jan': 'ਜਨ',
    'Feb': 'ਫ਼ਰ',
    'Mar': 'ਮਾਰਚ',
    'Apr': 'ਅਪ੍ਰੈ',
    'May': 'ਮਈ',
    'Jun': 'ਜੂਨ',
    'Jul': 'ਜੁਲ',
    'Aug': 'ਅਗ',
    'Sep': 'ਸਤੰ',
    'Oct': 'ਅਕਤੂ',
    'Nov': 'ਨਵੰ',
    'Dec': 'ਦਸੰ',
  };

  if (lang == 'hi') {
    return hi[month] ?? month;
  }
  if (lang == 'pa') {
    return pa[month] ?? month;
  }
  if (lang == 'mr') {
    switch (month) {
      case 'Jan':
        return 'जाने';
      case 'Feb':
        return 'फेब्रु';
      case 'Mar':
        return 'मार्च';
      case 'Apr':
        return 'एप्रि';
      case 'May':
        return 'मे';
      case 'Jun':
        return 'जून';
      case 'Jul':
        return 'जुलै';
      case 'Aug':
        return 'ऑग';
      case 'Sep':
        return 'सप्टें';
      case 'Oct':
        return 'ऑक्टो';
      case 'Nov':
        return 'नोव्हें';
      case 'Dec':
        return 'डिसें';
    }
  }
  if (lang == 'te') {
    switch (month) {
      case 'Jan':
        return 'జన';
      case 'Feb':
        return 'ఫిబ్ర';
      case 'Mar':
        return 'మార్చి';
      case 'Apr':
        return 'ఏప్రి';
      case 'May':
        return 'మే';
      case 'Jun':
        return 'జూన్';
      case 'Jul':
        return 'జులై';
      case 'Aug':
        return 'ఆగ';
      case 'Sep':
        return 'సెప్';
      case 'Oct':
        return 'అక్టో';
      case 'Nov':
        return 'నవం';
      case 'Dec':
        return 'డిసెం';
    }
  }
  return month;
}

String _weatherText(String lang, String text) {
  const hi = {
    'Irrigate wheat before harvest. Watch for aphids in heat.':
        'कटाई से पहले गेहूं की सिंचाई करें। गर्मी में एफिड पर नजर रखें।',
    'Good for rice and maize. Monitor for blast disease.':
        'धान और मक्का के लिए अच्छा समय है। ब्लास्ट रोग पर नजर रखें।',
    'Ideal for wheat. Frost risk after Dec. Apply irrigation.':
        'गेहूं के लिए अच्छा समय है। दिसंबर के बाद पाला पड़ सकता है। सिंचाई करें।',
    'Keep fields mulched. Drip irrigate vegetables.':
        'खेत में मल्च रखें। सब्जियों में ड्रिप सिंचाई करें।',
    'Paddy transplanting season. Monitor for BPH.':
        'धान रोपाई का मौसम है। BPH पर नजर रखें।',
    'Wheat sowing time. Good mustard season.':
        'गेहूं बुवाई का समय है। सरसों के लिए अच्छा मौसम है।',
    'Irrigate sugarcane weekly. Protect cotton seedlings.':
        'गन्ने की साप्ताहिक सिंचाई करें। कपास की नन्ही पौध की रक्षा करें।',
    'Soybean and cotton main season. Watch for bollworm.':
        'सोयाबीन और कपास का मुख्य मौसम है। बॉलवर्म पर नजर रखें।',
    'Rabi sorghum and chickpea. Good for onion.':
        'रबी ज्वार और चना के लिए अच्छा समय है। प्याज के लिए भी ठीक है।',
    'Mango flowering period. Protect from heat stress.':
        'आम में फूल आने का समय है। गर्मी के तनाव से बचाएं।',
    'Paddy season. Drain fields for weeding. Sugarcane irrigation.':
        'धान का मौसम है। निराई के लिए खेत का पानी निकालें। गन्ने की सिंचाई करें।',
    'Wheat, mustard, pea season. Apply DAP at sowing.':
        'गेहूं, सरसों और मटर का मौसम है। बुवाई के समय DAP दें।',
    'Heavy rain expected. Skip irrigation for 2-3 days.':
        'भारी बारिश की संभावना है। 2-3 दिन सिंचाई रोकें।',
    'Light rain detected. Reduce irrigation amount.':
        'हल्की बारिश मिली है। सिंचाई की मात्रा कम करें।',
    'High humidity. Skip irrigation today.': 'नमी अधिक है। आज सिंचाई न करें।',
    'Hot and dry conditions. Increase irrigation frequency.':
        'गर्मी और सूखा है। सिंचाई की आवृत्ति बढ़ाएं।',
    'Normal conditions. Regular irrigation schedule recommended.':
        'सामान्य स्थिति है। नियमित सिंचाई कार्यक्रम रखें।',
    'High risk: favorable conditions for fungal diseases.':
        'उच्च जोखिम: फफूंदी रोगों के लिए अनुकूल मौसम।',
    'Low risk: dry conditions reduce disease spread.':
        'कम जोखिम: सूखी स्थिति रोग फैलाव कम करती है।',
    'Moderate risk: normal disease pressure.': 'मध्यम जोखिम: सामान्य रोग दबाव।',
    'Wheat growth': 'गेहूं बढ़वार',
    'Mustard harvest': 'सरसों कटाई',
    'Rabi harvest': 'रबी कटाई',
    'Summer veg': 'गर्मी सब्जियां',
    'Field prep': 'खेत तैयारी',
    'Kharif sowing': 'खरीफ बुवाई',
    'Paddy transplant': 'धान रोपाई',
    'Weed control': 'खरपतवार नियंत्रण',
    'Kharif growth': 'खरीफ बढ़वार',
    'Kharif harvest': 'खरीफ कटाई',
    'Rabi sowing': 'रबी बुवाई',
  };

  const pa = {
    'Irrigate wheat before harvest. Watch for aphids in heat.':
        'ਕਟਾਈ ਤੋਂ ਪਹਿਲਾਂ ਗੇਂਹੂਂ ਨੂੰ ਪਾਣੀ ਦਿਓ। ਗਰਮੀ ਵਿੱਚ ਐਫਿਡ ਤੇ ਨਜ਼ਰ ਰੱਖੋ।',
    'Good for rice and maize. Monitor for blast disease.':
        'ਧਾਨ ਅਤੇ ਮੱਕੀ ਲਈ ਚੰਗਾ ਸਮਾਂ ਹੈ। ਬਲਾਸਟ ਰੋਗ ਤੇ ਨਜ਼ਰ ਰੱਖੋ।',
    'Ideal for wheat. Frost risk after Dec. Apply irrigation.':
        'ਗੇਂਹੂਂ ਲਈ ਵਧੀਆ ਸਮਾਂ ਹੈ। ਦਸੰਬਰ ਤੋਂ ਬਾਅਦ ਪਾਲੇ ਦਾ ਖਤਰਾ ਹੈ। ਸਿੰਚਾਈ ਕਰੋ।',
    'Keep fields mulched. Drip irrigate vegetables.':
        'ਖੇਤ ਵਿੱਚ ਮਲਚ ਰੱਖੋ। ਸਬਜ਼ੀਆਂ ਲਈ ਡ੍ਰਿਪ ਸਿੰਚਾਈ ਕਰੋ।',
    'Paddy transplanting season. Monitor for BPH.':
        'ਧਾਨ ਰੋਪਾਈ ਦਾ ਮੌਸਮ ਹੈ। BPH ਤੇ ਨਜ਼ਰ ਰੱਖੋ।',
    'Wheat sowing time. Good mustard season.':
        'ਗੇਂਹੂਂ ਬਿਜਾਈ ਦਾ ਸਮਾਂ ਹੈ। ਸਰੋਂ ਲਈ ਚੰਗਾ ਮੌਸਮ ਹੈ।',
    'Irrigate sugarcane weekly. Protect cotton seedlings.':
        'ਗੰਨੇ ਨੂੰ ਹਫ਼ਤੇਵਾਰ ਪਾਣੀ ਦਿਓ। ਕਪਾਹ ਦੇ ਪੌਦਿਆਂ ਦੀ ਰੱਖਿਆ ਕਰੋ।',
    'Soybean and cotton main season. Watch for bollworm.':
        'ਸੋਯਾਬੀਨ ਅਤੇ ਕਪਾਹ ਦਾ ਮੁੱਖ ਮੌਸਮ ਹੈ। ਬੋਲਵਰਮ ਤੇ ਨਜ਼ਰ ਰੱਖੋ।',
    'Rabi sorghum and chickpea. Good for onion.':
        'ਰਬੀ ਜਵਾਰ ਅਤੇ ਚਣੇ ਲਈ ਵਧੀਆ ਸਮਾਂ ਹੈ। ਪਿਆਜ਼ ਲਈ ਵੀ ਠੀਕ ਹੈ।',
    'Mango flowering period. Protect from heat stress.':
        'ਅੰਬ ਵਿੱਚ ਫੁੱਲ ਆਉਣ ਦਾ ਸਮਾਂ ਹੈ। ਗਰਮੀ ਦੇ ਤਣਾਅ ਤੋਂ ਬਚਾਓ।',
    'Paddy season. Drain fields for weeding. Sugarcane irrigation.':
        'ਧਾਨ ਦਾ ਮੌਸਮ ਹੈ। ਨਿਰਾਈ ਲਈ ਖੇਤ ਦਾ ਪਾਣੀ ਕੱਢੋ। ਗੰਨੇ ਨੂੰ ਪਾਣੀ ਦਿਓ।',
    'Wheat, mustard, pea season. Apply DAP at sowing.':
        'ਗੇਂਹੂਂ, ਸਰੋਂ ਅਤੇ ਮਟਰ ਦਾ ਮੌਸਮ ਹੈ। ਬਿਜਾਈ ਵੇਲੇ DAP ਦਿਓ।',
    'Heavy rain expected. Skip irrigation for 2-3 days.':
        'ਭਾਰੀ ਮੀਂਹ ਦੀ ਸੰਭਾਵਨਾ ਹੈ। 2-3 ਦਿਨ ਸਿੰਚਾਈ ਨਾ ਕਰੋ।',
    'Light rain detected. Reduce irrigation amount.':
        'ਹਲਕਾ ਮੀਂਹ ਹੈ। ਸਿੰਚਾਈ ਦੀ ਮਾਤਰਾ ਘਟਾਓ।',
    'High humidity. Skip irrigation today.': 'ਨਮੀ ਵੱਧ ਹੈ। ਅੱਜ ਸਿੰਚਾਈ ਨਾ ਕਰੋ।',
    'Hot and dry conditions. Increase irrigation frequency.':
        'ਗਰਮੀ ਅਤੇ ਸੁੱਕਾ ਹੈ। ਸਿੰਚਾਈ ਦੀ ਵਾਰੰਵਾਰਤਾ ਵਧਾਓ।',
    'Normal conditions. Regular irrigation schedule recommended.':
        'ਹਾਲਤ ਆਮ ਹੈ। ਨਿਯਮਿਤ ਸਿੰਚਾਈ ਰੱਖੋ।',
    'High risk: favorable conditions for fungal diseases.':
        'ਉੱਚ ਖਤਰਾ: ਫੰਗਸ ਰੋਗਾਂ ਲਈ ਅਨੁਕੂਲ ਹਾਲਤ।',
    'Low risk: dry conditions reduce disease spread.':
        'ਘੱਟ ਖਤਰਾ: ਸੁੱਕੀ ਹਾਲਤ ਰੋਗ ਫੈਲਾਅ ਘਟਾਉਂਦੀ ਹੈ।',
    'Moderate risk: normal disease pressure.': 'ਦਰਮਿਆਨਾ ਖਤਰਾ: ਆਮ ਰੋਗ ਦਬਾਅ।',
    'Wheat growth': 'ਗੇਂਹੂਂ ਵਾਧਾ',
    'Mustard harvest': 'ਸਰੋਂ ਕਟਾਈ',
    'Rabi harvest': 'ਰਬੀ ਕਟਾਈ',
    'Summer veg': 'ਗਰਮੀ ਸਬਜ਼ੀਆਂ',
    'Field prep': 'ਖੇਤ ਤਿਆਰੀ',
    'Kharif sowing': 'ਖਰੀਫ ਬਿਜਾਈ',
    'Paddy transplant': 'ਧਾਨ ਰੋਪਾਈ',
    'Weed control': 'ਖਰਪਤਵਾਰ ਕੰਟਰੋਲ',
    'Kharif growth': 'ਖਰੀਫ ਵਾਧਾ',
    'Kharif harvest': 'ਖਰੀਫ ਕਟਾਈ',
    'Rabi sowing': 'ਰਬੀ ਬਿਜਾਈ',
  };

  if (lang == 'hi') {
    return hi[text] ?? text;
  }
  if (lang == 'pa') {
    return pa[text] ?? text;
  }
  if (lang == 'mr') {
    switch (text) {
      case 'Irrigate wheat before harvest. Watch for aphids in heat.':
        return 'कापणीपूर्वी गव्हाला पाणी द्या. उष्णतेत मावा कीडीकडे लक्ष ठेवा.';
      case 'Good for rice and maize. Monitor for blast disease.':
        return 'तांदूळ आणि मका यासाठी चांगला काळ आहे. ब्लास्ट रोगावर लक्ष ठेवा.';
      case 'Ideal for wheat. Frost risk after Dec. Apply irrigation.':
        return 'गव्हासाठी उत्तम काळ आहे. डिसेंबरनंतर दवाचा धोका असतो. सिंचन करा.';
      case 'Keep fields mulched. Drip irrigate vegetables.':
        return 'शेतात मल्च ठेवा. भाज्यांना ठिबक सिंचन द्या.';
      case 'Paddy transplanting season. Monitor for BPH.':
        return 'धान रोपांची लागवड सुरू आहे. BPH वर लक्ष ठेवा.';
      case 'Wheat sowing time. Good mustard season.':
        return 'गहू पेरणीचा काळ आहे. मोहरीसाठी चांगला हंगाम आहे.';
      case 'Irrigate sugarcane weekly. Protect cotton seedlings.':
        return 'ऊसाला आठवड्याला पाणी द्या. कापसाच्या रोपांचे संरक्षण करा.';
      case 'Soybean and cotton main season. Watch for bollworm.':
        return 'सोयाबीन आणि कापसाचा मुख्य हंगाम आहे. बोंडअळीवर लक्ष ठेवा.';
      case 'Rabi sorghum and chickpea. Good for onion.':
        return 'रब्बी ज्वारी आणि हरभऱ्यासाठी चांगला काळ आहे. कांद्यासाठीही योग्य आहे.';
      case 'Mango flowering period. Protect from heat stress.':
        return 'आंब्याच्या फुलोऱ्याचा काळ आहे. उष्णतेच्या ताणापासून संरक्षण करा.';
      case 'Paddy season. Drain fields for weeding. Sugarcane irrigation.':
        return 'धानाचा हंगाम आहे. निंदणीसाठी शेतातील पाणी काढा. ऊसाला पाणी द्या.';
      case 'Wheat, mustard, pea season. Apply DAP at sowing.':
        return 'गहू, मोहरी आणि वाटाण्याचा हंगाम आहे. पेरणीवेळी DAP द्या.';
      case 'Heavy rain expected. Skip irrigation for 2-3 days.':
        return 'मुसळधार पावसाची शक्यता आहे. 2-3 दिवस सिंचन टाळा.';
      case 'Light rain detected. Reduce irrigation amount.':
        return 'हलका पाऊस झाला आहे. सिंचनाचे प्रमाण कमी करा.';
      case 'High humidity. Skip irrigation today.':
        return 'आर्द्रता जास्त आहे. आज सिंचन टाळा.';
      case 'Hot and dry conditions. Increase irrigation frequency.':
        return 'उष्ण आणि कोरडी हवा आहे. सिंचनाची वारंवारता वाढवा.';
      case 'Normal conditions. Regular irrigation schedule recommended.':
        return 'परिस्थिती सामान्य आहे. नियमित सिंचनाचे वेळापत्रक ठेवा.';
      case 'High risk: favorable conditions for fungal diseases.':
        return 'उच्च धोका: बुरशीजन्य रोगांसाठी अनुकूल स्थिती.';
      case 'Low risk: dry conditions reduce disease spread.':
        return 'कमी धोका: कोरडी स्थिती रोगांचा प्रसार कमी करते.';
      case 'Moderate risk: normal disease pressure.':
        return 'मध्यम धोका: सामान्य रोगदाब.';
      case 'Wheat growth':
        return 'गहू वाढ';
      case 'Mustard harvest':
        return 'मोहरी कापणी';
      case 'Rabi harvest':
        return 'रब्बी कापणी';
      case 'Summer veg':
        return 'उन्हाळी भाजीपाला';
      case 'Field prep':
        return 'शेत तयारी';
      case 'Kharif sowing':
        return 'खरीप पेरणी';
      case 'Paddy transplant':
        return 'धान रोपलागवड';
      case 'Weed control':
        return 'तण नियंत्रण';
      case 'Kharif growth':
        return 'खरीप वाढ';
      case 'Kharif harvest':
        return 'खरीप कापणी';
      case 'Rabi sowing':
        return 'रब्बी पेरणी';
      default:
        return text;
    }
  }
  if (lang == 'te') {
    switch (text) {
      case 'Irrigate wheat before harvest. Watch for aphids in heat.':
        return 'కోతకు ముందు గోధుమకు నీరు ఇవ్వండి. వేడిలో మావు పురుగులను గమనించండి.';
      case 'Good for rice and maize. Monitor for blast disease.':
        return 'వరి మరియు మక్కకు ఇది మంచి సమయం. బ్లాస్ట్ వ్యాధిని గమనించండి.';
      case 'Ideal for wheat. Frost risk after Dec. Apply irrigation.':
        return 'గోధుమకు ఇది మంచి కాలం. డిసెంబర్ తర్వాత మంచు ప్రమాదం ఉంది. నీరు ఇవ్వండి.';
      case 'Keep fields mulched. Drip irrigate vegetables.':
        return 'పొలంలో మల్చ్ ఉంచండి. కూరగాయలకు డ్రిప్ నీటిపారుదల చేయండి.';
      case 'Paddy transplanting season. Monitor for BPH.':
        return 'వరి నాట్లు వేయే కాలం. BPH ను గమనించండి.';
      case 'Wheat sowing time. Good mustard season.':
        return 'గోధుమ విత్తే సమయం. ఆవాల కోసం కూడా మంచిది.';
      case 'Irrigate sugarcane weekly. Protect cotton seedlings.':
        return 'చెరకు కి వారానికి ఒకసారి నీరు ఇవ్వండి. పత్తి మొక్కలను రక్షించండి.';
      case 'Soybean and cotton main season. Watch for bollworm.':
        return 'సోయాబీన్ మరియు పత్తి ప్రధాన కాలం. బోల్‌వార్మ్ ను గమనించండి.';
      case 'Rabi sorghum and chickpea. Good for onion.':
        return 'రబీ జొన్న మరియు సెనగకు మంచి కాలం. ఉల్లికి కూడా అనుకూలం.';
      case 'Mango flowering period. Protect from heat stress.':
        return 'మామిడి పుష్పించే కాలం. వేడి ఒత్తిడి నుండి రక్షించండి.';
      case 'Paddy season. Drain fields for weeding. Sugarcane irrigation.':
        return 'వరి కాలం. కలుపు తీయడానికి పొలంలో నీరు బయటకు పంపండి. చెరకు కి నీరు ఇవ్వండి.';
      case 'Wheat, mustard, pea season. Apply DAP at sowing.':
        return 'గోధుమ, ఆవాలు, బఠాణీ కాలం. విత్తే సమయంలో DAP వేయండి.';
      case 'Heavy rain expected. Skip irrigation for 2-3 days.':
        return 'భారీ వర్షం వచ్చే అవకాశం ఉంది. 2-3 రోజులు నీటిపారుదల ఆపండి.';
      case 'Light rain detected. Reduce irrigation amount.':
        return 'తేలికపాటి వర్షం పడింది. నీటిపారుదల మొత్తాన్ని తగ్గించండి.';
      case 'High humidity. Skip irrigation today.':
        return 'ఆర్ద్రత ఎక్కువగా ఉంది. ఈ రోజు నీటిపారుదల అవసరం లేదు.';
      case 'Hot and dry conditions. Increase irrigation frequency.':
        return 'వేడిగా మరియు ఎండగా ఉంది. నీటిపారుదల తరచుదనాన్ని పెంచండి.';
      case 'Normal conditions. Regular irrigation schedule recommended.':
        return 'పరిస్థితులు సాధారణంగా ఉన్నాయి. క్రమమైన నీటిపారుదల షెడ్యూల్ పాటించండి.';
      case 'High risk: favorable conditions for fungal diseases.':
        return 'అధిక ప్రమాదం: శిలీంధ్ర వ్యాధులకు అనుకూల పరిస్థితులు.';
      case 'Low risk: dry conditions reduce disease spread.':
        return 'తక్కువ ప్రమాదం: ఎండ పరిస్థితులు వ్యాధి వ్యాప్తిని తగ్గిస్తాయి.';
      case 'Moderate risk: normal disease pressure.':
        return 'మోస్తరు ప్రమాదం: సాధారణ వ్యాధి ఒత్తిడి.';
      case 'Wheat growth':
        return 'గోధుమ పెరుగుదల';
      case 'Mustard harvest':
        return 'ఆవాల కోత';
      case 'Rabi harvest':
        return 'రబీ కోత';
      case 'Summer veg':
        return 'వేసవి కూరగాయలు';
      case 'Field prep':
        return 'పొలం సిద్ధం';
      case 'Kharif sowing':
        return 'ఖరీఫ్ విత్తడం';
      case 'Paddy transplant':
        return 'వరి నాటు';
      case 'Weed control':
        return 'కలుపు నియంత్రణ';
      case 'Kharif growth':
        return 'ఖరీఫ్ పెరుగుదల';
      case 'Kharif harvest':
        return 'ఖరీఫ్ కోత';
      case 'Rabi sowing':
        return 'రబీ విత్తడం';
      default:
        return text;
    }
  }
  return text;
}
