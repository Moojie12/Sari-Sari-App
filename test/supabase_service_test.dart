import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sari_sari/core/services/supabase_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockPostgrestQueryBuilder extends Mock implements PostgrestQueryBuilder {}
class MockPostgrestFilterBuilder<T> extends Mock implements PostgrestFilterBuilder<T> {}
class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}

void main() {
  late SupabaseService service;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // Initialize Supabase with mock storage to avoid platform channel errors
    await Supabase.initialize(
      url: 'https://mock.supabase.co',
      publishableKey: 'mock-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  setUp(() {
    // We can't easily inject the mock into the singleton service,
    // so we'll test what we can without deep mocking
    service = SupabaseService();
  });

  group('SupabaseService', () {
    test('Service is a singleton', () {
      final instance1 = SupabaseService();
      final instance2 = SupabaseService();
      expect(instance1, same(instance2));
    });

    test('getOrCreateUserProfile method exists', () {
      expect(service.getOrCreateUserProfile, isA<Function>());
    });

    test('updateUserProfile method exists', () {
      expect(service.updateUserProfile, isA<Function>());
    });

    test('getProductsWithInventory method exists', () {
      expect(service.getProductsWithInventory, isA<Function>());
    });

    test('createOrderWithItems method exists', () {
      expect(service.createOrderWithItems, isA<Function>());
    });

    test('createPreOrderWithItems method exists', () {
      expect(service.createPreOrderWithItems, isA<Function>());
    });

    test('convertPreOrderToOrder method exists', () {
      expect(service.convertPreOrderToOrder, isA<Function>());
    });
  });
}
