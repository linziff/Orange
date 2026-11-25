import 'config_entry.dart';

/// Remote online-support configuration.
///
/// Supports the legacy self-hosted API/WebSocket fields and a remotely
/// delivered Crisp Website ID. Crisp is rendered inside the app by the
/// platform WebView integration; it must not be opened with url_launcher.
class OnlineSupportInfo extends ConfigEntry {
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String? crispWebsiteId;

  const OnlineSupportInfo({
    required String url,
    required String description,
    this.apiBaseUrl = '',
    this.wsBaseUrl = '',
    this.crispWebsiteId,
    Map<String, dynamic>? metadata,
  }) : super(url: url, description: description, metadata: metadata);

  factory OnlineSupportInfo.fromJson(Map<String, dynamic> json) {
    return OnlineSupportInfo(
      url: json['url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      apiBaseUrl: json['apiBaseUrl'] as String? ?? '',
      wsBaseUrl: json['wsBaseUrl'] as String? ?? '',
      crispWebsiteId: (json['crispWebsiteId'] ?? json['websiteId']) as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
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

  bool get hasCrisp => crispWebsiteId?.trim().isNotEmpty == true;

  /// Legacy endpoint validation. Crisp-only entries do not require these.
  bool validate() {
    if (hasCrisp) return true;
    return _isValidUrl(apiBaseUrl) &&
        _isValidUrl(wsBaseUrl) &&
        _isValidHttpUrl(apiBaseUrl) &&
        _isValidWebSocketUrl(wsBaseUrl);
  }

  List<String> getValidationErrors() {
    if (hasCrisp) return const [];
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

  bool _isValidUrl(String value) {
    try {
      final uri = Uri.parse(value);
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _isValidHttpUrl(String value) {
    try {
      final uri = Uri.parse(value);
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (_) {
      return false;
    }
  }

  bool _isValidWebSocketUrl(String value) {
    try {
      final uri = Uri.parse(value);
      return uri.scheme == 'ws' || uri.scheme == 'wss';
    } catch (_) {
      return false;
    }
  }

  @override
  String toString() =>
      'OnlineSupportInfo(crisp: $hasCrisp, apiBaseUrl: $apiBaseUrl, wsBaseUrl: $wsBaseUrl)';
}
