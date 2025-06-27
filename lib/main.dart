import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
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

  Widget floatingButton(BuildContext context) {
    final ocrState = ref.watch(ocrResultProvider);
    final notifier = ref.read(ocrResultProvider.notifier);

    if (!ocrState.showExprs) {
      return FloatingActionButton(
        shape: const CircleBorder(),
        onPressed: () async {
          return ocrState.imgParsed
              ? notifier.setShowExprs(true)
              : await OcrImagePage.parseImage(context, ref);
        },
        child:
            ocrState.imgParsed ? const Icon(Icons.calculate) : const Text('解析'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpeedDial(
          icon: Icons.more_horiz,
          activeIcon: Icons.close,
          spaceBetweenChildren: 8,
          spacing: 12,
          direction: SpeedDialDirection.up,
          children: [
            SpeedDialChild(
              onTap: () => notifier.setShowExprs(false),
              child: const Icon(Icons.image),
              label: '选择图片',
            ),
            SpeedDialChild(
              onTap: () async {
                try {
                  await notifier.export();
                } catch (e) {
                  if (context.mounted) {
                    OcrUtils.showErrorDialog(
                      context,
                      e.toString(),
                      title: '导出失败',
                    );
                  }
                }
              },
              child: const Icon(Icons.file_download),
              label: '下载表格',
            ),
          ],
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          shape: const CircleBorder(),
          onPressed: () => notifier.addItem(),
          child: const Icon(Icons.playlist_add),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          shape: const CircleBorder(),
          onPressed: () async {
            await OcrExprsPage.calculateResult(context, ref);
          },
          child: const Text('计算'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrResultProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 图片上传页
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: ocrState.showExprs ? -MediaQuery.of(context).size.height : 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height,
            child: OcrImagePage(),
          ),
          // 表达式页
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: ocrState.showExprs ? 0 : MediaQuery.of(context).size.height,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height,
            child: OcrExprsPage(),
          ),
          // 加载页
          if (ocrState.loading)
            // 显示加载指示器
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      floatingActionButton: floatingButton(context),
    );
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
  runApp(ProviderScope(child: MaterialApp(home: OcrHomePage())));
}
