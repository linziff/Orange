import '../models/online_support_info.dart';

/// 在线客服服务
///
/// 负责访问旧版客服服务配置，以及远程下发的 Crisp Website ID。
class OnlineSupportService {
  final List<OnlineSupportInfo> _configs;

  OnlineSupportService(this._configs);

  List<OnlineSupportInfo> getAllConfigs() => List.unmodifiable(_configs);

  OnlineSupportInfo? getFirstAvailableConfig() =>
      _configs.isNotEmpty ? _configs.first : null;

  String? getApiBaseUrl() => getFirstAvailableConfig()?.apiBaseUrl;

  String? getWebSocketBaseUrl() => getFirstAvailableConfig()?.wsBaseUrl;

  /// Crisp 网站 ID 由远程 onlineSupport JSON 下发。
  String? getCrispWebsiteId() {
    for (final config in _configs) {
      final id = config.crispWebsiteId?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  bool hasAvailableConfig() => _configs.isNotEmpty;

  Map<String, dynamic> getConfigStats() {
    final stats = <String, dynamic>{
      'totalConfigs': _configs.length,
      'hasApiConfig': getApiBaseUrl() != null,
      'hasWebSocketConfig': getWebSocketBaseUrl() != null,
      'hasCrispWebsiteId': getCrispWebsiteId() != null,
    };

    final httpCount = _configs.where((c) => c.apiBaseUrl.startsWith('http://')).length;
    final httpsCount = _configs.where((c) => c.apiBaseUrl.startsWith('https://')).length;
    final wsCount = _configs.where((c) => c.wsBaseUrl.startsWith('ws://')).length;
    final wssCount = _configs.where((c) => c.wsBaseUrl.startsWith('wss://')).length;

    stats['protocolDistribution'] = {
      'http': httpCount,
      'https': httpsCount,
      'ws': wsCount,
      'wss': wssCount,
    };
    return stats;
  }

  bool validateAllConfigs() => _configs.every((config) => config.validate());

  List<String> getAllValidationErrors() {
    final errors = <String>[];
    for (var i = 0; i < _configs.length; i++) {
      errors.addAll(
        _configs[i].getValidationErrors().map((e) => 'config[$i]: $e'),
      );
    }
    return errors;
  }

  @override
  String toString() => 'OnlineSupportService(configs: ${_configs.length}, '
      'hasApiConfig: ${getApiBaseUrl() != null}, '
      'hasWebSocketConfig: ${getWebSocketBaseUrl() != null}, '
      'hasCrispWebsiteId: ${getCrispWebsiteId() != null})';
}
