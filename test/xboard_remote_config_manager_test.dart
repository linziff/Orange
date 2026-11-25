import 'package:flutter_test/flutter_test.dart';
import 'package:fl_clash/xboard/config/core/config_settings.dart';
import 'package:fl_clash/xboard/config/fetchers/remote_config_manager.dart';
import 'package:fl_clash/xboard/config/models/subscription_info.dart';
import 'package:fl_clash/xboard/config/parsers/configuration_parser.dart';

void main() {
  test('parses the QNDXX remote JSON provider and panelType', () {
    final parsed = ConfigurationParser().parseFromJson({
      'panelType': 'xboard',
      'panels': {
        'QNDXX': [
          {
            'url': 'https://www.toufq.com',
            'description': '面板-1',
          },
          {
            'url': 'https://www.qndxx.uk',
            'description': '面板-2',
          },
        ],
      },
      'update': [],
      'onlineSupport': [],
      'subscription': {
        'urls': [],
      },
    }, 'QNDXX');

    expect(parsed.panelType, 'xboard');
    expect(parsed.panels.currentProviderPanels.length, 2);
  });

  group('XBoard subscription endpoint preference', () {
    test('selects v1 when encryption is not preferred and v2 when preferred', () {
      final subscription = SubscriptionInfo.fromJson({
        'enableEncrypt': true,
        'urls': [
          {
            'url': 'https://panel.example',
            'description': 'test panel',
            'supportEncrypt': true,
            'endpoints': {
              'v1': {
                'path': '/api/v1/subscription/{token}',
                'requiresToken': true,
                'method': 'GET',
                'description': 'plain',
                'isEncrypt': false,
              },
              'v2': {
                'path': '/api/v2/subscription-encrypt/{token}',
                'requiresToken': true,
                'method': 'GET',
                'description': 'encrypted',
                'isEncrypt': true,
              },
            },
          },
        ],
      });

      expect(
        subscription.buildSubscriptionUrl('token', forceEncrypt: false),
        'https://panel.example/api/v1/subscription/token?flag=flclash',
      );
      expect(
        subscription.buildSubscriptionUrl('token', forceEncrypt: true),
        'https://panel.example/api/v2/subscription-encrypt/token?flag=flclash',
      );
    });
  });

  group('RemoteConfigManager custom JSON sources', () {
    test('parses snake_case encryption key and configured priority', () {
      final source = RemoteSourceConfig.fromJson({
        'name': 'gitee',
        'url': 'https://gitee.example/config.txt',
        'encryption_key': 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        'priority': 95,
      });

      expect(source.encryptionKey, isNotEmpty);
      expect(source.priority, 95);
    });

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
