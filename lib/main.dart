// import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icc/provider/ocr_providers.dart';
// import 'package:icc/provider/ocr_providers.dart';
import 'package:icc/widgets/ocr_image.dart';
import 'package:icc/widgets/ocr_exprs.dart';

import 'package:logging/logging.dart';

class OcrHomePage extends ConsumerWidget {
  const OcrHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocrState = ref.watch(ocrResultProvider);
    final notifier = ref.read(ocrResultProvider.notifier);

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
      floatingActionButton:
          ocrState.showExprs
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    onPressed: () => notifier.setShowExprs(false),
                    child: const Icon(Icons.arrow_upward),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    onPressed: () {
                      final focusedCol = ocrState.focusedCol;
                      final focusedItem = ocrState.focusedItem;
                      if (focusedCol != -1 && focusedItem != -1) {
                        // 分页模式，且存在焦点
                        notifier.addItem(focusedCol, itemIdx: focusedItem);
                      } else if (focusedItem != -1) {
                        // 列表模式，且存在焦点
                        // 将一维索引转换为列和项索引
                        final pos = OcrExprsPage.getColAndItemIdx(
                          ocrState.columns,
                          focusedItem,
                        );
                        notifier.addItem(pos.key, itemIdx: pos.value);
                      } else {
                        // 不存在焦点
                        // 列表模式下，将元素添加到最后一列
                        final colIdx =
                            focusedCol != -1
                                ? focusedCol
                                : ocrState.columns.length - 1;
                        notifier.addItem(colIdx);
                      }
                    },
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    onPressed: () async {
                      await OcrExprsPage.calculateResult(context, ref);
                    },
                    child: const Text('计算'),
                  ),
                ],
              )
              : FloatingActionButton(
                onPressed: () async {
                  return ocrState.imgParsed
                      ? notifier.setShowExprs(true)
                      : await OcrImagePage.parseImage(context, ref);
                },
                child:
                    ocrState.imgParsed
                        ? const Icon(Icons.arrow_downward)
                        : const Text('解析'),
              ),
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
