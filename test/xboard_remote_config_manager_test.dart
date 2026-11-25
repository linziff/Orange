import 'package:fl_clash/xboard/core/utils/xboard_decrypt_helper.dart';
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
    expect(parsed.toJson()['panelType'], 'xboard');
  });

  group('XBoard subscription endpoint preference', () {
    test('selects v1 when encryption is not preferred and v2 when preferred', () {
      final subscription = SubscriptionInfo.fromJson({
        'enableEncrypt': true,
        'urls': [
          {
            'url': 'https://panel.example',
            'description': 'test panel',
            'endpoints': {
              'v1': {
                'path': '/api/v1/subscription/{token}',
                'requiresToken': true,
                'method': 'GET',
                'description': 'plain',
              },
              'v2': {
                'path': '/api/v2/subscription-encrypt/{token}',
                'requiresToken': true,
                'method': 'GET',
                'description': 'encrypted',
              },
            },
          },
        ],
      });

      expect(
        subscription.buildSubscriptionUrl('token', forceEncrypt: false),
        'https://panel.example/api/v1/subscription/token?flag=flclash',
      );
      expect(subscription.firstEncryptUrl, isNotNull);
      expect(
        subscription.buildSubscriptionUrl('token', forceEncrypt: true),
        'https://panel.example/api/v2/subscription-encrypt/token?flag=flclash',
      );
    });
  });

  test('falls back to the configured normal endpoint when encryption is preferred but unavailable', () {
    final urlInfo = SubscriptionUrlInfo.fromJson({
      'url': 'https://panel.example',
      'description': 'normal-only panel',
      'endpoints': {
        'v1': {
          'path': '/api/v1/subscription/{token}',
          'requiresToken': true,
          'method': 'GET',
          'description': 'plain',
          'isEncrypt': false,
        },
      },
    });

    expect(
      urlInfo.buildSubscriptionUrl('token', preferEncrypt: true),
      'https://panel.example/api/v1/subscription/token?flag=flclash',
    );
  });

  test('respects an explicit non-encrypted v2 endpoint flag', () {
    final subscription = SubscriptionInfo.fromJson({
      'enableEncrypt': true,
      'urls': [
        {
          'url': 'https://panel.example',
          'description': 'test panel',
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
              'description': 'backend explicitly marks this as plain',
              'isEncrypt': false,
            },
          },
        },
      ],
    });

    expect(subscription.firstEncryptUrl, isNull);
    expect(
      subscription.buildSubscriptionUrl('token', forceEncrypt: true),
      'https://panel.example/api/v1/subscription/token?flag=flclash',
    );
  });

  test('does not invent an encrypted endpoint when none is configured', () {
    final subscription = SubscriptionInfo.fromJson({
      'enableEncrypt': true,
      'urls': [
        {
          'url': 'https://panel.example',
          'description': 'test panel',
          'endpoints': {
            'custom': {
              'path': '/api/subscription/{token}',
              'requiresToken': true,
              'method': 'GET',
              'description': 'plain custom endpoint',
              'isEncrypt': false,
            },
          },
        },
      ],
    });

    expect(subscription.firstEncryptUrl, isNull);
    expect(
      subscription.buildSubscriptionUrl('token', forceEncrypt: true),
      'https://panel.example/api/subscription/token?flag=flclash',
    );
  });

  test('returns a clear failure when no decrypt key is configured', () {
    final result = XBoardDecryptHelper.smartDecrypt(
      'not-a-real-encrypted-payload',
      configuredKey: '',
    );

    expect(result.success, isFalse);
    expect(result.keyUsed, isNull);
    expect(result.message, '未配置订阅解密密钥');
  });

  test('parses snake_case remote retry and timeout settings', () {
    final settings = RemoteConfigSettings.fromJson({
      'sources': [
        {
          'name': 'backup',
          'url': 'https://backup.example/config.json',
          'timeout_seconds': 23,
          'priority': 90,
        },
      ],
      'max_retries': 5,
      'timeout_seconds': 17,
      'retry_delay_seconds': 4,
    });

    expect(settings.maxRetries, 5);
    expect(settings.timeout, const Duration(seconds: 17));
    expect(settings.retryDelay, const Duration(seconds: 4));
    expect(settings.sources.single.timeout, const Duration(seconds: 23));
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
