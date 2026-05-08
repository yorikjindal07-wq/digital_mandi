import 'dart:convert';

import 'package:flutter/services.dart';

class IndiaLocations {
  IndiaLocations._();

  static const String assetPath = 'assets/data/india_locations.json';

  static Future<Map<String, List<String>>>? _cache;

  static const Map<String, List<String>> fallbackStatesAndCities = {
    'Andhra Pradesh': [
      'Visakhapatnam',
      'Vijayawada',
      'Tirupati',
      'Kurnool',
      'Rajahmundry',
    ],
    'Arunachal Pradesh': [
      'Itanagar',
      'Naharlagun',
      'Pasighat',
      'Tawang',
      'Bomdila',
    ],
    'Assam': ['Guwahati', 'Dibrugarh', 'Silchar', 'Jorhat', 'Tezpur'],
    'Bihar': ['Patna', 'Gaya', 'Muzaffarpur', 'Bhagalpur', 'Purnia'],
    'Chhattisgarh': ['Raipur', 'Bilaspur', 'Durg', 'Jagdalpur', 'Korba'],
    'Goa': ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar'],
    'Haryana': ['Karnal', 'Gurgaon', 'Faridabad', 'Hisar', 'Rohtak'],
    'Himachal Pradesh': ['Shimla', 'Dharamshala', 'Solan', 'Mandi', 'Kullu'],
    'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Hazaribagh'],
    'Karnataka': ['Bengaluru', 'Mysuru', 'Hubballi', 'Mangaluru', 'Belagavi'],
    'Kerala': [
      'Thiruvananthapuram',
      'Kochi',
      'Kozhikode',
      'Thrissur',
      'Kottayam',
    ],
    'Madhya Pradesh': ['Bhopal', 'Indore', 'Jabalpur', 'Gwalior', 'Ujjain'],
    'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Kolhapur'],
    'Manipur': ['Imphal', 'Thoubal', 'Bishnupur', 'Churachandpur', 'Ukhrul'],
    'Meghalaya': ['Shillong', 'Tura', 'Jowai', 'Nongpoh', 'Williamnagar'],
    'Mizoram': ['Aizawl', 'Lunglei', 'Champhai', 'Serchhip', 'Kolasib'],
    'Nagaland': ['Kohima', 'Dimapur', 'Mokokchung', 'Wokha', 'Tuensang'],
    'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Sambalpur', 'Berhampur'],
    'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda'],
    'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Bikaner'],
    'Sikkim': ['Gangtok', 'Namchi', 'Gyalshing', 'Mangan', 'Singtam'],
    'Tamil Nadu': [
      'Chennai',
      'Coimbatore',
      'Madurai',
      'Tiruchirappalli',
      'Salem',
    ],
    'Telangana': [
      'Hyderabad',
      'Warangal',
      'Karimnagar',
      'Nizamabad',
      'Khammam',
    ],
    'Tripura': ['Agartala', 'Udaipur', 'Dharmanagar', 'Kailashahar', 'Belonia'],
    'Uttar Pradesh': ['Lucknow', 'Kanpur', 'Varanasi', 'Agra', 'Prayagraj'],
    'Uttarakhand': ['Dehradun', 'Haridwar', 'Haldwani', 'Rudrapur', 'Nainital'],
    'West Bengal': ['Kolkata', 'Siliguri', 'Durgapur', 'Asansol', 'Kharagpur'],
    'Andaman and Nicobar Islands': [
      'Port Blair',
      'Diglipur',
      'Havelock Island',
    ],
    'Chandigarh': ['Chandigarh'],
    'Dadra and Nagar Haveli and Daman and Diu': ['Silvassa', 'Daman', 'Diu'],
    'Delhi': ['New Delhi', 'Dwarka', 'Rohini', 'Najafgarh', 'Karol Bagh'],
    'Jammu and Kashmir': [
      'Srinagar',
      'Jammu',
      'Anantnag',
      'Baramulla',
      'Kathua',
    ],
    'Ladakh': ['Leh', 'Kargil', 'Diskit', 'Nubra', 'Padum'],
    'Lakshadweep': ['Kavaratti', 'Minicoy', 'Andrott'],
    'Puducherry': ['Puducherry', 'Karaikal', 'Yanam', 'Mahe'],
  };

  static Future<Map<String, List<String>>> loadStatesAndCities() {
    return _cache ??= _loadFromAsset();
  }

  static Future<Map<String, List<String>>> _loadFromAsset() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final map = <String, List<String>>{};
      for (final entry in decoded.entries) {
        final cities =
            (entry.value as List<dynamic>)
                .map((city) => city.toString())
                .where((city) => city.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        map[entry.key] = cities;
      }

      final keys = map.keys.toList()..sort();
      return {for (final key in keys) key: map[key]!};
    } catch (_) {
      return fallbackStatesAndCities;
    }
  }
}
