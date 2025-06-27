import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icc/provider/ocr_providers.dart';
import 'package:icc/widgets/ocr_image.dart';
import 'package:icc/utils.dart';

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
        OcrUtils.showErrorDialog(context, e.toString(), title: '计算失败');
      }
    }
  }
}

class _OcrExprsPageState extends ConsumerState<OcrExprsPage> {
  /// 滚动控制
  final ScrollController _scrollController = ScrollController();

  /// 是否分页
  bool _paginated = false;

  /// 回收控制器
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 切换分页模式
  void _togglePagination() {
    _paginated = !_paginated; // 切换分页状态
    final notifier = ref.read(ocrResultProvider.notifier);
    // 重置当前列索引
    notifier.setCurPage(_paginated ? 0 : -1);
    // 重置焦点 UID
    notifier.setFocusedUid('');
  }

  /// 构造列表视图
  Widget _buildListView(BuildContext context) {
    final state = ref.watch(ocrResultProvider);
    final notifier = ref.read(ocrResultProvider.notifier);

    // 不存在 colIndex，则为列表模式，新建 flat 列表
    // 否则直接获取指定列的列表
    final list =
        state.curPage == -1
            ? state.columns.expand((col) => col).toList()
            : state.columns[state.curPage];

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
                    notifier.setFocusedUid(uid);
                  }
                },
                child: TextField(
                  controller: item.controller,
                  onChanged: (val) => notifier.updateItem(uid, val),
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('='),
            ),
            SizedBox(
              width: resultFieldWidth,
              child: Text(
                item.result?.toStringAsFixed(2) ?? '',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _exprsList(BuildContext context) {
    final state = ref.watch(ocrResultProvider);
    final notifier = ref.read(ocrResultProvider.notifier);

    if (state.loading) {
      // 加载中，则返回空页面
      return const Center();
    } else if (state.imgBytes == null) {
      return const Center(child: Text("请先选择图像进行识别"));
    } else if (_paginated) {
      // 二维模式，分页展示元素
      return PageView.builder(
        itemCount: state.columns.length,
        onPageChanged: (index) => notifier.setCurPage(index),
        itemBuilder: (context, index) {
          return _buildListView(context);
        },
      );
    } else {
      // 一维模式，将所有元素放在一个列表中
      return _buildListView(context);
    }
  }

  Widget _floatingButton(BuildContext context) {
    final notifier = ref.read(ocrResultProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          shape: const CircleBorder(),
          onPressed: () async {
            try {
              await notifier.export();
            } catch (e) {
              if (context.mounted) {
                OcrUtils.showErrorDialog(context, e.toString(), title: '导出失败');
              }
            }
          },
          child: const Icon(Icons.file_download),
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
            icon: Icon(_paginated ? Icons.view_carousel : Icons.view_agenda),
            tooltip: _paginated ? '分页' : '列表',
            onPressed: () => _togglePagination(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '总计: ${ocrState.ans.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
              Expanded(child: _exprsList(context)),
            ],
          ),
          if (ocrState.loading) OcrUtils.loadingPage(),
        ],
      ),
      floatingActionButton: _floatingButton(context),
    );
  }
}
