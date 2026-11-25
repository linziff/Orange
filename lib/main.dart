import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/plugins/tile.dart';
import 'package:fl_clash/plugins/vpn.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/xboard/config/xboard_config.dart';
import 'package:fl_clash/xboard/config/utils/config_file_loader.dart'; // 配置文件加载器
import 'package:fl_clash/xboard/infrastructure/network/domain_racing_service.dart'; // 域名竞速服务
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'clash/core.dart';
import 'clash/lib.dart';
import 'common/common.dart';
import 'models/models.dart';
import 'package:fl_clash/xboard/features/remote_task/remote_task_manager.dart'; // 导入远程任务管理器

import 'package:flutter_xboard_sdk/flutter_xboard_sdk.dart'; // 导入域名服务

// 定义一个全局变量来持有 RemoteTaskManager 实例，方便在整个应用生命周期中访问和管理
RemoteTaskManager? remoteTaskManager;

Future<void> main() async {
  globalState.isService = false;
  WidgetsFlutterBinding.ensureInitialized(); // 确保 Flutter 绑定已初始化

  // 先设置网络覆盖与生命周期监听，避免远程服务初始化阻塞首帧。
  HttpOverrides.global = FlClashHttpOverrides();
  WidgetsBinding.instance.addObserver(AppLifecycleObserver());

  // 本地 XBoard 配置初始化不应阻塞应用窗口；失败时仍允许用户看到登录界面。
  unawaited(_initializeXBoardServices().timeout(
    const Duration(seconds: 12),
    onTimeout: () => print('[Main] XBoard 配置初始化超时，先显示应用界面'),
  ).catchError((e) {
    print('[Main] XBoard 服务初始化失败，应用继续启动: $e');
  }));

  // 远程任务管理器完全属于后台能力，绝不等待它完成。
  unawaited(Future<void>(() async {
    try {
      remoteTaskManager = await RemoteTaskManager.create()
          .timeout(const Duration(seconds: 8));
      remoteTaskManager?.initialize();
      remoteTaskManager?.start();
      print('[Main] RemoteTaskManager 后台初始化完成');
    } catch (e) {
      print('[Main] RemoteTaskManager 不可用，跳过: $e');
      remoteTaskManager = null;
    }
  }));

  final version = await system.version.timeout(
    const Duration(seconds: 8),
    onTimeout: () => 'unknown',
  );

  // Core/平台插件初始化有超时保护；任何单项失败都不能让窗口永久灰屏。
  try {
    await clashCore.preload().timeout(const Duration(seconds: 12));
  } catch (e) {
    print('[Main] Clash Core 预加载失败或超时，界面继续启动: $e');
  }
  try {
    await globalState.initApp(version).timeout(const Duration(seconds: 12));
  } catch (e) {
    print('[Main] 本地状态初始化失败或超时，界面继续启动: $e');
  }
  try {
    await android?.init().timeout(const Duration(seconds: 8));
  } catch (e) {
    print('[Main] Android 插件初始化失败或超时: $e');
  }
  try {
    await window?.init(version).timeout(const Duration(seconds: 8));
  } catch (e) {
    print('[Main] 桌面窗口插件初始化失败或超时: $e');
  }

  runApp(const ProviderScope(
    child: Application(),
  ));
}

/// 加载安全配置（证书路径、UA、解密密钥等）
Future<void> _loadSecurityConfig() async {
  try {
    // 加载证书配置
    final certConfig = await ConfigFileLoaderHelper.getCertificateConfig();
    final certPath = certConfig['path'] as String?;
    final certEnabled = certConfig['enabled'] as bool? ?? true;
    
    if (certEnabled && certPath != null && certPath.isNotEmpty) {
      // 直接使用配置中的证书路径（已经是相对于项目根目录的完整路径）
      DomainRacingService.setCertificatePath(certPath);
      print('[Main] 证书路径配置: $certPath');
    }
    
    // 其他安全配置可以在这里加载
    // 如 UA、解密密钥等
    
  } catch (e) {
    print('[Main] 加载安全配置失败（使用默认值）: $e');
  }
}

/// 初始化XBoard配置模块和域名服务
Future<void> _initializeXBoardServices() async {
  try {
    print('[Main] 开始初始化XBoard配置模块...');
    
    // 1. 从配置文件加载配置（开源友好：用户只需修改 xboard.config.yaml）
    final configSettings = await ConfigFileLoader.loadFromFile();
    print('[Main] 配置文件加载成功，Provider: ${configSettings.currentProvider}');
    
    // 2. 加载安全配置（UA、证书、解密密钥等）
    await _loadSecurityConfig();
    print('[Main] 安全配置加载成功');
    
    // 3. 初始化V2配置模块
    await XBoardConfig.initialize(settings: configSettings);
    print('[Main] XBoard配置模块初始化成功');
    
    // SDK 初始化已移至 xboardSdkProvider，由 Riverpod 统一管理
    // 在 Application.initState 中会预热 SDK
    print('[Main] SDK 将在应用启动后由 xboardSdkProvider 初始化');
    
  } catch (e) {
    print('[Main] XBoard服务初始化失败: $e');
    // 没有域名就失败，不需要降级
    rethrow;
  }
}


// 创建一个 AppLifecycleObserver 类来处理应用生命周期事件
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当应用被完全终止时（例如，从任务管理器中划掉），释放资源
    if (state == AppLifecycleState.detached) {
      remoteTaskManager?.dispose();
      XBoardSDK.instance.dispose(); // 释放SDK资源
      print('应用生命周期状态改变: $state, 所有服务资源已释放。');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _service(List<String> flags) async {
  globalState.isService = true;
  WidgetsFlutterBinding.ensureInitialized();
  final quickStart = flags.contains("quick");
  final clashLibHandler = ClashLibHandler();
  await globalState.init();

  tile?.addListener(
    _TileListenerWithService(
      onStop: () async {
        await app?.tip(appLocalizations.stopVpn);
        clashLibHandler.stopListener();
        await vpn?.stop();
        exit(0);
      },
    ),
  );

  vpn?.handleGetStartForegroundParams = () {
    final traffic = clashLibHandler.getTraffic();
    return json.encode({
      "title": clashLibHandler.getCurrentProfileName(),
      "content": "$traffic"
    });
  };

  vpn?.addListener(
    _VpnListenerWithService(
      onDnsChanged: (String dns) {
        print("handle dns $dns");
        clashLibHandler.updateDns(dns);
      },
    ),
  );
  if (!quickStart) {
    _handleMainIpc(clashLibHandler);
  } else {
    commonPrint.log("quick start");
    await ClashCore.initGeo();
    app?.tip(appLocalizations.startVpn);
    final homeDirPath = await appPath.homeDirPath;
    final version = await system.version;
    final clashConfig = globalState.config.patchClashConfig.copyWith.tun(
      enable: true,
    );
    Future(() async {
      final profileId = globalState.config.currentProfileId;
      if (profileId == null) {
        return;
      }
      final params = await globalState.getSetupParams(
        pathConfig: clashConfig,
      );
      final res = await clashLibHandler.quickStart(
        InitParams(
          homeDir: homeDirPath,
          version: version,
        ),
        params,
        globalState.getCoreState(),
      );
      debugPrint(res);
      if (res.isNotEmpty) {
        await vpn?.stop();
        exit(0);
      }
      await vpn?.start(
        clashLibHandler.getAndroidVpnOptions(),
      );
      clashLibHandler.startListener();
    });
  }
}

_handleMainIpc(ClashLibHandler clashLibHandler) {
  final sendPort = IsolateNameServer.lookupPortByName(mainIsolate);
  if (sendPort == null) {
    return;
  }
  final serviceReceiverPort = ReceivePort();
  serviceReceiverPort.listen((message) async {
    final res = await clashLibHandler.invokeAction(message);
    sendPort.send(res);
  });
  sendPort.send(serviceReceiverPort.sendPort);
  final messageReceiverPort = ReceivePort();
  clashLibHandler.attachMessagePort(
    messageReceiverPort.sendPort.nativePort,
  );
  messageReceiverPort.listen((message) {
    sendPort.send(message);
  });
}

@immutable
class _TileListenerWithService with TileListener {
  final Function() _onStop;

  const _TileListenerWithService({
    required Function() onStop,
  }) : _onStop = onStop;

  @override
  void onStop() {
    _onStop();
  }
}

@immutable
class _VpnListenerWithService with VpnListener {
  final Function(String dns) _onDnsChanged;

  const _VpnListenerWithService({
    required Function(String dns) onDnsChanged,
  }) : _onDnsChanged = onDnsChanged;

  @override
  void onDnsChanged(String dns) {
    super.onDnsChanged(dns);
    _onDnsChanged(dns);
  }
}
