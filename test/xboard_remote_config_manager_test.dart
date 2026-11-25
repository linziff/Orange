import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/config/core/config_settings.dart';
import 'package:fl_clash/xboard/config/fetchers/remote_config_manager.dart';

void main() {
  group('RemoteConfigManager custom JSON sources', () {
    test('registers primary and backup sources in priority order', () {
      final manager = RemoteConfigManager.fromSettings(
        const RemoteConfigSettings(
          sources: [
            RemoteSourceConfig(
              name: 'backup',
              url: 'https://backup.example/config.json',
              priority: 90,
            ),
            RemoteSourceConfig(
              name: 'primary',
              url: 'https://primary.example/config.json',
              priority: 100,
            ),
          ],
        ),
      );

      expect(manager.sourceCount, 2);
      expect(manager.sourceNames, ['primary', 'backup']);
    });

    test('keeps legacy redirect and gitee source names supported', () {
      final manager = RemoteConfigManager.fromSettings(
        const RemoteConfigSettings(
          sources: [
            RemoteSourceConfig(
              name: 'redirect',
              url: 'https://redirect.example/config.json',
              priority: 100,
            ),
            RemoteSourceConfig(
              name: 'gitee',
              url: 'https://gitee.example/config.txt',
              encryptionKey: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
              priority: 90,
            ),
          ],
        ),
      );

      expect(manager.sourceNames, ['redirect', 'gitee']);
    });
  });
}
