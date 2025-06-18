import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icc/model/ocr_item.dart';
import 'package:icc/repository/ocr_repo.dart';
import 'package:icc/utils.dart';

/// OCR 识别结果 Provider，暴露的入口
final ocrResultProvider =
    StateNotifierProvider<OcrResultNotifier, OcrResultState>(
      (ref) => OcrResultNotifier(OcrRepository()),
    );

/// OCR 识别结果状态
class OcrResultState {
  /// 图像数据
  final Uint8List? imgBytes;

  /// 识别结果分列数据
  final List<List<OcrItem>> columns;

  /// 求和结果
  final double ans;

  /// 是否正在加载
  final bool loading;

  /// 错误信息
  final String? error;

  /// 是否分页
  final bool paginated;

  /// 是否展示表达式列表
  final bool showExprs;

  /// 是否已解析过当前图片
  final bool imgParsed;

  /// 当前焦点列
  final int focusedCol;

  /// 当前焦点索引
  final int focusedItem;

  /// 构造函数
  OcrResultState({
    required this.imgBytes,
    required this.columns,
    required this.ans,
    this.loading = false,
    this.error,
    this.paginated = false,
    this.showExprs = false,
    this.imgParsed = false,
    this.focusedCol = -1,
    this.focusedItem = -1,
  });

  /// 深度拷贝并更新某个字段
  OcrResultState copyWith({
    Uint8List? imgBytes,
    List<List<OcrItem>>? columns,
    double? ans,
    bool? loading,
    String? error,
    bool? paginated,
    bool? showExprs,
    bool? imgParsed,
    int? focusedCol,
    int? focusedItem,
  }) => OcrResultState(
    imgBytes: imgBytes ?? this.imgBytes,
    columns: columns ?? this.columns,
    ans: ans ?? this.ans,
    loading: loading ?? this.loading,
    error: error ?? this.error,
    paginated: paginated ?? this.paginated,
    showExprs: showExprs ?? this.showExprs,
    imgParsed: imgParsed ?? this.imgParsed,
    focusedCol: focusedCol ?? this.focusedCol,
    focusedItem: focusedItem ?? this.focusedItem,
  );
}

/// OCR 识别结果 StateNotifier，Provider 核心，负责处理状态逻辑
class OcrResultNotifier extends StateNotifier<OcrResultState> {
  final OcrRepository repo;
  OcrResultNotifier(this.repo)
    : super(OcrResultState(imgBytes: null, columns: [], ans: 0));

  /// 识别新的图片并计算结果
  Future<void> parse() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final (columns, ans) = await repo.parseAndCalc(state.imgBytes);
      state = state.copyWith(
        columns: columns,
        ans: ans,
        loading: false,
        imgParsed: true,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
      rethrow; // 重新抛出异常以便上层捕获
    }
  }

  /// 重新计算
  Future<void> recalculate() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final (columns, ans) = await repo.recalculate(state.columns);
      state = state.copyWith(columns: columns, ans: ans, loading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
      rethrow;
    }
  }

  /// 设置图像数据
  void setImage(Uint8List? bytes) {
    state = state.copyWith(
      imgBytes: bytes,
      columns: [],
      ans: 0,
      imgParsed: false,
    );
  }

  /// 设置加载状态
  void setLoading(bool loading) {
    state = state.copyWith(loading: loading);
  }

  /// 设置表达式显示
  void setShowExprs(bool showExprs) {
    state = state.copyWith(showExprs: showExprs);
  }

  /// 设置焦点列
  void setFocusedCol(int index) {
    state = state.copyWith(focusedCol: index);
  }

  /// 设置焦点索引
  void setFocusedItem(int index) {
    state = state.copyWith(focusedItem: index);
  }

  /// 取消聚焦
  void unfocused() {
    state = state.copyWith(focusedCol: -1, focusedItem: -1);
  }

  /// 修改某项
  void updateItem(int colIdx, int itemIdx, String value) {
    final entry = OcrUtils.getColAndItemIdx(state.columns, colIdx, itemIdx);
    (colIdx, itemIdx) = (entry.key, entry.value);
    // 深度拷贝后修改指定项
    final newColumns = [...state.columns];
    newColumns[colIdx] = [...newColumns[colIdx]];
    newColumns[colIdx][itemIdx].words = value;
    state = state.copyWith(columns: newColumns);
  }

  /// 删除某项
  void deleteItem(int colIdx, int itemIdx) {
    final entry = OcrUtils.getColAndItemIdx(state.columns, colIdx, itemIdx);
    (colIdx, itemIdx) = (entry.key, entry.value);
    final newColumns = [...state.columns];
    newColumns[colIdx] = [...newColumns[colIdx]]..removeAt(itemIdx);
    state = state.copyWith(columns: newColumns);
  }

  /// 添加项，在焦点位置添加空表达式，无焦点则添加到末尾
  void addItem() {
    var (colIdx, itemIdx) = (state.focusedCol, state.focusedItem);
    final entry = OcrUtils.getColAndItemIdx(state.columns, colIdx, itemIdx);
    (colIdx, itemIdx) = (entry.key, entry.value);
    final newColumns = [...state.columns];
    newColumns[colIdx] = [...newColumns[colIdx]];
    if (itemIdx != -1 && itemIdx < newColumns[colIdx].length) {
      newColumns[colIdx].insert(itemIdx, OcrItem(words: '', result: null));
    } else {
      // 默认添加到末尾
      newColumns[colIdx].add(OcrItem(words: '', result: null));
    }
    state = state.copyWith(columns: newColumns);
  }

  /// 切换分页
  void togglePagination() {
    state = state.copyWith(
      paginated: !state.paginated,
      focusedCol: !state.paginated ? 0 : -1,
      focusedItem: -1,
    );
  }
}
