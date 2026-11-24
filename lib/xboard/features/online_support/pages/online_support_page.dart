import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// QNDXX online customer support powered by Crisp.
/// The direct chatbox URL keeps the conversation inside the application.
class OnlineSupportPage extends StatelessWidget {
  const OnlineSupportPage({super.key});

  static const String _crispWebsiteId =
      '92f20590-a75f-4b50-a521-6d5fc7a356dd';

  static Uri get _crispUri => Uri.https(
        'go.crisp.chat',
        '/chat/embed/',
        {'website_id': _crispWebsiteId},
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_crispUri.toString())),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            supportZoom: false,
          ),
        ),
      ),
    );
  }
}
