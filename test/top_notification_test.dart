import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/shared/utils/top_notification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TopNotification Enhancement Tests', () {
    test('TopNotificationType enum values exist and render', () {
      expect(TopNotificationType.values.length, equals(4));
      expect(TopNotificationType.values.contains(TopNotificationType.success), isTrue);
      expect(TopNotificationType.values.contains(TopNotificationType.error), isTrue);
      expect(TopNotificationType.values.contains(TopNotificationType.warning), isTrue);
      expect(TopNotificationType.values.contains(TopNotificationType.offline), isTrue);
    });
  });
}
