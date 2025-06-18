import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icc/provider/ocr_providers.dart';
import 'package:icc/widgets/ocr_image.dart';

/// OCR 表达式页面，负责识别图像中的表达式，展示和计算表达式结果
class OcrExprsPage extends ConsumerStatefulWidget {
  const OcrExprsPage({super.key});

  @override
  ConsumerState<OcrExprsPage> createState() => _OcrExprsPageState();

  /// 计算表达式结果
  static Future<void> calculateResult(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final notifier = ref.read(ocrResultProvider.notifier);
    try {
      await notifier.recalculate();
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('计算失败'),
                content: Text(e.toString()),
              ),
        );
      }
    }
  }
}

class _OcrExprsPageState extends ConsumerState<OcrExprsPage> {
  /// 滚动控制
  final ScrollController _scrollController = ScrollController();

  /// 回收控制器
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildListView(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ocrResultProvider);
    final notifier = ref.read(ocrResultProvider.notifier);

    // 不存在 colIndex，则为列表模式，新建 flat 列表
    // 否则直接获取指定列的列表
    print('build时 当前页：${state.curCol}');
    final list =
        state.curCol == -1
            ? state.columns.expand((col) => col).toList()
            : state.columns[state.curCol];

    // 计算文本框宽度
    final viewWidth = MediaQuery.of(context).size.width;
    final textFieldWidth = (viewWidth - 80) * 0.8;
    final resultFieldWidth = (viewWidth - 80) * 0.2;

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.35,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final uid = item.uid;

        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => notifier.deleteItem(uid),
            ),
            SizedBox(
              width: textFieldWidth,
              child: Focus(
                focusNode: item.focusNode,
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    print('当前页: ${state.curCol}');
                    notifier.setFocusedUid(uid);
                    print('当前页: ${state.curCol}');
                  }
                },
                child: TextField(
                  controller: item.controller,
                  onTap:
                      () => Scrollable.ensureVisible(
                        item.focusNode.context!,
                        duration: const Duration(milliseconds: 300),
                        alignment: 0.5,
                      ),
                  onChanged: (val) => notifier.updateItem(uid, val),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('='),
            ),
            SizedBox(
              width: resultFieldWidth,
              child: Text(item.result?.toStringAsFixed(2) ?? ''),
            ),
          ],
        );
      },
    );
  }

  Widget _exprsList(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ocrResultProvider);
    final notifier = ref.read(ocrResultProvider.notifier);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    } else if (state.imgBytes == null) {
      return const Center(child: Text("请先选择图像进行识别"));
    } else if (state.paginated) {
      // 二维模式，分页展示元素
      return PageView.builder(
        itemCount: state.columns.length,
        onPageChanged: (index) => notifier.setCurCol(index),
        itemBuilder: (context, index) {
          return _buildListView(context, ref);
        },
      );
    } else {
      // 一维模式，将所有元素放在一个列表中
      return _buildListView(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrResultProvider);
    final notifier = ref.read(ocrResultProvider.notifier);

    // 添加回调函数，build 结束后调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusedUid = ocrState.focusedUid;
      if (focusedUid.isEmpty) return;
      final item = notifier.selectItem(focusedUid)?.item;
      // 聚焦到焦点 item
      if (item != null && !item.focusNode.hasFocus) {
        item.focusNode.requestFocus();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR 表达式识别'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_search),
            tooltip: '预览图片',
            onPressed: () => OcrImagePage.showImagePreview(context, ref),
          ),
          IconButton(
            icon: Icon(
              ocrState.paginated ? Icons.view_carousel : Icons.view_agenda,
            ),
            tooltip: ocrState.paginated ? '分页' : '列表',
            onPressed: () => notifier.togglePagination(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '总计: ${ocrState.ans.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: _exprsList(context, ref),
          ),
        ],
      ),
    );
  }
}
