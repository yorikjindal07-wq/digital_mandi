// ─────────────────────────────────────────────
// screens/weather_screen.dart
// Offline weather approximation using preloaded
// historical seasonal data for Indian regions.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

// Preloaded seasonal data per region
const Map<String, Map<String, dynamic>> _weatherData = {
  'Punjab': {
    'summer': {'temp': '38–44°C', 'rain': '15–30mm', 'humidity': '30–50%', 'advice': 'Irrigate wheat before harvest. Watch for aphids in heat.'},
    'kharif': {'temp': '28–35°C', 'rain': '60–120mm', 'humidity': '65–85%', 'advice': 'Good for rice and maize. Monitor for blast disease.'},
    'winter': {'temp': '4–18°C',  'rain': '20–50mm',  'humidity': '50–70%', 'advice': 'Ideal for wheat. Frost risk after Dec. Apply irrigation.'},
  },
  'Haryana': {
    'summer': {'temp': '40–46°C', 'rain': '10–25mm', 'humidity': '25–45%', 'advice': 'Keep fields mulched. Drip irrigate vegetables.'},
    'kharif': {'temp': '30–36°C', 'rain': '50–100mm', 'humidity': '60–80%', 'advice': 'Paddy transplanting season. Monitor for BPH.'},
    'winter': {'temp': '3–15°C',  'rain': '15–40mm',  'humidity': '45–65%', 'advice': 'Wheat sowing time. Good mustard season.'},
  },
  'Maharashtra': {
    'summer': {'temp': '35–42°C', 'rain': '5–20mm',  'humidity': '20–40%', 'advice': 'Irrigate sugarcane weekly. Protect cotton seedlings.'},
    'kharif': {'temp': '26–32°C', 'rain': '100–300mm','humidity': '70–90%', 'advice': 'Soybean and cotton main season. Watch for bollworm.'},
    'winter': {'temp': '15–28°C', 'rain': '0–15mm',   'humidity': '40–60%', 'advice': 'Rabi sorghum and chickpea. Good for onion.'},
  },
  'Uttar Pradesh': {
    'summer': {'temp': '38–45°C', 'rain': '10–30mm', 'humidity': '30–50%', 'advice': 'Mango flowering period. Protect from heat stress.'},
    'kharif': {'temp': '28–34°C', 'rain': '80–200mm','humidity': '70–90%', 'advice': 'Paddy season. Drain fields for weeding. Sugarcane irrigation.'},
    'winter': {'temp': '5–20°C',  'rain': '10–30mm',  'humidity': '50–75%', 'advice': 'Wheat, mustard, pea season. Apply DAP at sowing.'},
  },
};

const List<String> _seasons = ['summer', 'kharif', 'winter'];
const Map<String, String> _seasonEmojis = {
  'summer': '☀️',
  'kharif': '🌧️',
  'winter': '❄️',
};
const Map<String, String> _seasonLabels = {
  'summer': 'Summer (Mar–Jun)',
  'kharif': 'Kharif (Jul–Oct)',
  'winter': 'Winter (Nov–Feb)',
};

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  String _selectedRegion = 'Punjab';
  String _selectedSeason = 'kharif';

  @override
  Widget build(BuildContext context) {
    final l10n   = context.watch<AppProvider>().l10n;
    final scheme = Theme.of(context).colorScheme;
    final data   = _weatherData[_selectedRegion]![_selectedSeason]!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n['weather'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Offline notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:        Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing historical seasonal averages. Connect to internet for live forecasts.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Region picker
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value:      _selectedRegion,
                    hint:       const Text('Select Region'),
                    items: _weatherData.keys.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedRegion = v);
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Season tabs
            Row(
              children: _seasons.map((s) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSeason = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedSeason == s
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _seasonEmojis[s]!,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s[0].toUpperCase() + s.substring(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _selectedSeason == s
                                ? Colors.white
                                : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),

            const SizedBox(height: 20),

            // Season label
            Text(
              '${_seasonEmojis[_selectedSeason]} ${_seasonLabels[_selectedSeason]}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 16),

            // Weather stats
            Row(
              children: [
                Expanded(child: _WeatherStatCard(
                  icon: Icons.thermostat,
                  label: 'Temperature',
                  value: data['temp'] as String,
                  color: Colors.deepOrange,
                )),
                const SizedBox(width: 12),
                Expanded(child: _WeatherStatCard(
                  icon: Icons.water_drop_rounded,
                  label: 'Rainfall',
                  value: data['rain'] as String,
                  color: Colors.blue,
                )),
              ],
            ),
            const SizedBox(height: 12),
            _WeatherStatCard(
              icon: Icons.water,
              label: 'Humidity',
              value: data['humidity'] as String,
              color: Colors.teal,
              fullWidth: true,
            ),

            const SizedBox(height: 16),

            // Farming advice
            Card(
              color: scheme.primary.withOpacity(0.07),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.agriculture, color: scheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Seasonal Farming Advice',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data['advice'] as String,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Monthly calendar card
            _MonthlyCalendar(region: _selectedRegion),
          ],
        ),
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
  final String   label, value;
  final Color    color;
  final bool     fullWidth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
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
    final scheme = Theme.of(context).colorScheme;
    final now    = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Farming Calendar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap:  true,
              physics:     const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   3,
                childAspectRatio: 2.2,
                mainAxisSpacing:  8,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                              : scheme.onSurface.withOpacity(0.6),
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


// ─────────────────────────────────────────────
// screens/history_screen.dart
// Shows all past disease detection reports
// stored locally in SQLite.