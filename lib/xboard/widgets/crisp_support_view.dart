import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Crisp support rendered inside the QNDXX application.
/// No navigation is handed to an external browser.
class CrispSupportView extends StatefulWidget {
  const CrispSupportView({
    super.key,
    required this.websiteId,
    this.title = '在线客服',
  });

  final String websiteId;
  final String title;

  @override
  State<CrispSupportView> createState() => _CrispSupportViewState();
}

class _CrispSupportViewState extends State<CrispSupportView> {
  static const _loadTimeout = Duration(seconds: 25);

  InAppWebViewController? _controller;
  Timer? _timeoutTimer;
  bool _isLoading = true;
  bool _hasError = false;
  int _progress = 0;
  int _attempt = 0;

  bool get _platformSupported => switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS ||
        TargetPlatform.windows =>
          true,
        _ => false,
      };

  String get _html {
    // JSON encoding makes the remotely supplied ID a safe JavaScript string.
    final websiteId = jsonEncode(widget.websiteId.trim());
    return '''
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <meta name="color-scheme" content="light dark">
  <title>QNDXX Support</title>
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
  </style>
</head>
<body>
  <script>
    window.CRISP_WEBSITE_ID = $websiteId;
    window.\$crisp = [];
    window.\$crisp.push(["safe", true]);
    window.\$crisp.push(["on", "session:loaded", function() {
      window.flutter_inappwebview.callHandler("crispLoaded");
    }]);
    var crispScript = document.createElement("script");
    crispScript.src = "https://client.crisp.chat/l.js";
    crispScript.async = true;
    crispScript.onerror = function() {
      window.flutter_inappwebview.callHandler("crispLoadFailed");
    };
    document.head.appendChild(crispScript);
  </script>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();
    _startLoadTimeout();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startLoadTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_loadTimeout, () {
      if (mounted && _isLoading) {
        _showError();
      }
    });
  }

  void _showError() {
    _timeoutTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  void _markReady() {
    _timeoutTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = false;
      _progress = 100;
    });
  }

  void _retry() {
    setState(() {
      _attempt++;
      _isLoading = true;
      _hasError = false;
      _progress = 0;
      _controller = null;
    });
    _startLoadTimeout();
  }

  Widget _message(String message, {Widget? action}) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.support_agent, size: 42),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: 16),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_platformSupported) {
      return _message('当前平台暂不支持内嵌在线客服');
    }
    if (widget.websiteId.trim().isEmpty) {
      return _message('在线客服配置缺失，请稍后重试');
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          InAppWebView(
            key: ValueKey(_attempt),
            initialData: InAppWebViewInitialData(
              data: _html,
              mimeType: 'text/html',
              encoding: 'utf-8',
              baseUrl: WebUri('https://client.crisp.chat/'),
            ),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              thirdPartyCookiesEnabled: true,
              supportZoom: false,
              transparentBackground: false,
              mediaPlaybackRequiresUserGesture: false,
            ),
            onWebViewCreated: (controller) async {
              _controller = controller;
              await controller.addJavaScriptHandler(
                handlerName: 'crispLoaded',
                callback: (_) {
                  _markReady();
                  return true;
                },
              );
              await controller.addJavaScriptHandler(
                handlerName: 'crispLoadFailed',
                callback: (_) {
                  _showError();
                  return false;
                },
              );
            },
            onLoadStart: (_, __) {
              if (mounted && !_hasError) {
                setState(() {
                  _isLoading = true;
                  _progress = 0;
                });
                _startLoadTimeout();
              }
            },
            onProgressChanged: (_, progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onReceivedError: (_, request, error) {
              if (request.isForMainFrame == true) _showError();
            },
            onReceivedHttpError: (_, request, response) {
              if (request.url.host.endsWith('crisp.chat') &&
                  (response.statusCode ?? 0) >= 400) {
                _showError();
              }
            },
          ),
          if (_isLoading)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                value: _progress > 0 && _progress < 100
                    ? _progress / 100
                    : null,
              ),
            ),
          if (_hasError)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 42),
                        const SizedBox(height: 12),
                        const Text(
                          '在线客服加载失败，请检查网络后重试',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重新加载'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
