import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icc/provider/ocr_providers.dart';
import 'package:icc/widgets/ocr_image.dart';
import 'package:icc/widgets/ocr_exprs.dart';

import 'package:logging/logging.dart';

class OcrHomePage extends ConsumerWidget {
  const OcrHomePage({super.key});

  Widget floatingButton(BuildContext context, WidgetRef ref) {
    final ocrState = ref.watch(ocrResultProvider);
    final notifier = ref.read(ocrResultProvider.notifier);

    if (!ocrState.showExprs) {
      return FloatingActionButton(
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
        FloatingActionButton(
          onPressed: () => notifier.export(ocrState.columns),
          child: const Icon(Icons.file_download),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          onPressed: () => notifier.setShowExprs(false),
          child: const Icon(Icons.image),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          onPressed: () => notifier.addItem(),
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          onPressed: () async {
            await OcrExprsPage.calculateResult(context, ref);
          },
          child: const Text('计算'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocrState = ref.watch(ocrResultProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Stack(
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
          ],
        ),
      ),
      floatingActionButton: floatingButton(context, ref),
    );
  }
}

void main() {
  // 设置日志打印
  Logger.root.level = Level.ALL; // 设置日志级别
  Logger.root.onRecord.listen((record) {
    print(
      '[${record.level.name}] ${record.loggerName}: ${record.time}: ${record.message}',
    );
  });
  runApp(ProviderScope(child: MaterialApp(home: OcrHomePage())));
}
