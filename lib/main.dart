import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icc/model/ocr_item.dart';
import 'package:icc/provider/ocr_providers.dart';
import 'package:icc/utils.dart';
import 'package:icc/widgets/ocr_image.dart';
import 'package:icc/widgets/ocr_exprs.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OcrHomePage extends ConsumerStatefulWidget {
  const OcrHomePage({super.key});

  @override
  ConsumerState<OcrHomePage> createState() => _OcrHomePageState();
}

/// OCR 首页，包含监听器
class _OcrHomePageState extends ConsumerState<OcrHomePage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用进入后台时，保存 OCR 状态
    if (state == AppLifecycleState.paused) {
      ref.read(ocrResultProvider.notifier).saveState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const OcrImagePage();
  }
}

void main() async {
  // 注册 Hive 进行数据持久化存储
  WidgetsFlutterBinding.ensureInitialized(); // 确保 Flutter 引擎已初始化
  await Hive.initFlutter();
  Hive.registerAdapter(OcrItemAdapter());
  // 设置日志打印
  OcrUtils.setupLogging();
  // 启动应用
  runApp(
    ProviderScope(
      child: MaterialApp(
        home: OcrHomePage(),
        routes: {'/ocr_exprs': (context) => const OcrExprsPage()},
      ),
    ),
  );
}
