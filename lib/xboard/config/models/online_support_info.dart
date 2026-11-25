import 'config_entry.dart';

/// 在线客服信息
///
/// 同时兼容旧版自建客服 API/WebSocket 和由远程 JSON 下发的 Crisp Website ID。
class OnlineSupportInfo extends ConfigEntry {
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String? crispWebsiteId;

  const OnlineSupportInfo({
    required String url,
    required String description,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    this.crispWebsiteId,
    Map<String, dynamic>? metadata,
  }) : super(url: url, description: description, metadata: metadata);

  /// 从远程 JSON 创建在线客服信息。
  /// 支持 crispWebsiteId 与 websiteId 两种字段名，便于平滑迁移。
  factory OnlineSupportInfo.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String? ?? '';
    final apiBaseUrl = json['apiBaseUrl'] as String? ?? url;
    final wsBaseUrl = json['wsBaseUrl'] as String? ?? _webSocketUrl(apiBaseUrl);
    final websiteId = (json['crispWebsiteId'] ?? json['websiteId']) as String?;
    return OnlineSupportInfo(
      url: url,
      description: json['description'] as String? ?? '',
      apiBaseUrl: apiBaseUrl,
      wsBaseUrl: wsBaseUrl,
      crispWebsiteId: websiteId,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert the legacy HTTP(S) URL into its matching WS(S) URL.
  /// Invalid/empty values are retained as empty so normal validation can
  /// report the configuration problem rather than inventing a host.
  static String _webSocketUrl(String value) {
    try {
      final uri = Uri.parse(value);
      if (uri.host.isEmpty) return '';
      if (uri.scheme == 'https') return uri.replace(scheme: 'wss').toString();
      if (uri.scheme == 'http') return uri.replace(scheme: 'ws').toString();
    } catch (_) {
      return '';
    }
    return '';
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json.addAll({
      'apiBaseUrl': apiBaseUrl,
      'wsBaseUrl': wsBaseUrl,
      if (crispWebsiteId != null && crispWebsiteId!.isNotEmpty)
        'crispWebsiteId': crispWebsiteId,
    });
    return json;
  }

  /// 验证URL格式
  bool validate() {
    return _isValidUrl(apiBaseUrl) &&
        _isValidUrl(wsBaseUrl) &&
        _isValidHttpUrl(apiBaseUrl) &&
        _isValidWebSocketUrl(wsBaseUrl);
  }

  /// 获取验证错误信息
  List<String> getValidationErrors() {
    final errors = <String>[];

    if (apiBaseUrl.isEmpty) {
      errors.add('API base URL cannot be empty');
    } else if (!_isValidUrl(apiBaseUrl)) {
      errors.add('Invalid API base URL format: $apiBaseUrl');
    } else if (!_isValidHttpUrl(apiBaseUrl)) {
      errors.add('API base URL must use http or https protocol: $apiBaseUrl');
    }

    if (wsBaseUrl.isEmpty) {
      errors.add('WebSocket base URL cannot be empty');
    } else if (!_isValidUrl(wsBaseUrl)) {
      errors.add('Invalid WebSocket URL format: $wsBaseUrl');
    } else if (!_isValidWebSocketUrl(wsBaseUrl)) {
      errors.add('WebSocket base URL must use ws or wss protocol: $wsBaseUrl');
    }

    return errors;
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _isValidHttpUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (_) {
      return false;
    }
  }

  bool _isValidWebSocketUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'ws' || uri.scheme == 'wss';
    } catch (_) {
      return false;
    }
  }

  @override
  String toString() {
    return 'OnlineSupportInfo(apiBaseUrl: $apiBaseUrl, wsBaseUrl: $wsBaseUrl, '
        'crispWebsiteId: ${crispWebsiteId ?? 'not configured'})';
  }
}
