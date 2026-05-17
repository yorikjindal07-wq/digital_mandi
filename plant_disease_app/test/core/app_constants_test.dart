import 'package:digital_mandi/core/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConstants', () {
    test('validates known crop and disease labels', () {
      expect(AppConstants.isValidDisease('early_blight'), isTrue);
      expect(AppConstants.isValidDisease('unknown_disease'), isFalse);
      expect(AppConstants.isValidCrop('tomato'), isFalse);
      expect(AppConstants.isValidCrop('rice'), isTrue);
    });

    test('returns label indexes for configured lists', () {
      expect(AppConstants.getDiseaseIndex('healthy'), greaterThanOrEqualTo(0));
      expect(AppConstants.getCropIndex('rice'), greaterThanOrEqualTo(0));
    });

    test('does not build backend URIs when backend base url is absent', () {
      expect(AppConstants.hasBackendBaseUrl, isFalse);
      expect(AppConstants.backendUri('/api/v1/chat'), isNull);
    });
  });
}
