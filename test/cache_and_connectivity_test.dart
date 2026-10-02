import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sari_sari/core/services/connectivity_service.dart';
import 'package:sari_sari/core/services/local_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ConnectivityService & LocalCacheService Tests', () {
    test('ConnectivityService initializes with default online state', () {
      final conn = ConnectivityService.instance;
      expect(conn.isOnline, isTrue);
    });

    test('LocalCacheService checks TTL validity correctly', () async {
      final cache = LocalCacheService.instance;

      // Initially no sync time -> cache invalid
      final isValidInitial = await cache.isCacheValid('products');
      expect(isValidInitial, isFalse);

      // Mark fresh sync time -> cache valid
      await cache.updateLastSyncTime('products');
      final isValidAfterSync = await cache.isCacheValid('products');
      expect(isValidAfterSync, isTrue);

      final lastSyncTimeStr = await cache.getLastSyncTimeString('products');
      expect(lastSyncTimeStr, isNotNull);
    });
  });
}
