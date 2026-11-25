import '../models/online_support_info.dart';

/// Online support configuration access, including remotely delivered Crisp IDs.
class OnlineSupportService {
  final List<OnlineSupportInfo> _configs;

  OnlineSupportService(this._configs);

  List<OnlineSupportInfo> getAllConfigs() => List.unmodifiable(_configs);

  OnlineSupportInfo? getFirstAvailableConfig() =>
      _configs.isNotEmpty ? _configs.first : null;

  String? getApiBaseUrl() {
    for (final config in _configs) {
      if (!config.hasCrisp && config.apiBaseUrl.trim().isNotEmpty) {
        return config.apiBaseUrl;
      }
    }
    return null;
  }

  String? getWebSocketBaseUrl() {
    for (final config in _configs) {
      if (!config.hasCrisp && config.wsBaseUrl.trim().isNotEmpty) {
        return config.wsBaseUrl;
      }
    }
    return null;
  }

  /// Returns the first configured Crisp Website ID from remote JSON.
  String? getCrispWebsiteId() {
    for (final config in _configs) {
      final id = config.crispWebsiteId?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  /// Indicates whether the legacy self-hosted chat backend is configured.
  /// Crisp is handled by the embedded WebView and must not start legacy APIs.
  bool hasAvailableConfig() =>
      _configs.any((config) => !config.hasCrisp && config.validate());

  Map<String, dynamic> getConfigStats() => {
        'totalConfigs': _configs.length,
        'hasApiConfig': getApiBaseUrl()?.isNotEmpty == true,
        'hasWebSocketConfig': getWebSocketBaseUrl()?.isNotEmpty == true,
        'hasCrispWebsiteId': getCrispWebsiteId() != null,
      };

  bool validateAllConfigs() => _configs.every((config) => config.validate());

  List<String> getAllValidationErrors() {
    final errors = <String>[];
    for (var i = 0; i < _configs.length; i++) {
      errors.addAll(
        _configs[i].getValidationErrors().map((error) => 'config[$i]: $error'),
      );
    }
    return errors;
  }

  @override
  String toString() =>
      'OnlineSupportService(configs: ${_configs.length}, hasCrisp: ${getCrispWebsiteId() != null})';
}
