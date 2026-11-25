import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Crisp support rendered inside the QNDXX application.
///
/// The Website ID must come from the remotely fetched onlineSupport config.
/// This widget intentionally does not use url_launcher or external browsers.
class CrispSupportView extends StatelessWidget {
  const CrispSupportView({
    super.key,
    required this.websiteId,
    this.title = '在线客服',
  });

  final String websiteId;
  final String title;

  String get _html {
    final safeId = websiteId.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
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
    window.CRISP_WEBSITE_ID = "$safeId";
    window.\$crisp = [];
    window.\$crisp.push(["safe", true]);
  </script>
  <script src="https://client.crisp.chat/l.js" async></script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (websiteId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('在线客服暂不可用，请稍后重试')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: InAppWebView(
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
      ),
    );
  }
}
