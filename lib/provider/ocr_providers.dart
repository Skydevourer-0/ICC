import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icc/model/ocr_item.dart';
import 'package:icc/repository/ocr_repo.dart';

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

  /// 构造函数
  OcrResultState({
    required this.imgBytes,
    required this.columns,
    required this.ans,
    this.loading = false,
    this.error,
    this.paginated = false,
  });

  /// 深度拷贝并更新某个字段
  OcrResultState copyWith({
    Uint8List? imgBytes,
    List<List<OcrItem>>? columns,
    double? ans,
    bool? loading,
    String? error,
    bool? paginated,
  }) => OcrResultState(
    imgBytes: imgBytes ?? this.imgBytes,
    columns: columns ?? this.columns,
    ans: ans ?? this.ans,
    loading: loading ?? this.loading,
    error: error ?? this.error,
    paginated: paginated ?? this.paginated,
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
      state = state.copyWith(columns: columns, ans: ans, loading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
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
    }
  }

  /// 设置图像数据
  void setImage(Uint8List? bytes) {
    state = state.copyWith(imgBytes: bytes, columns: [], ans: 0);
  }

  /// 设置加载状态
  void setLoading(bool loading) {
    state = state.copyWith(loading: loading);
  }

  /// 修改某项
  void updateItem(int colIdx, int itemIdx, OcrItem item) {
    // 深度拷贝后修改指定项
    final newColumns = [...state.columns];
    newColumns[colIdx] = [...newColumns[colIdx]];
    newColumns[colIdx][itemIdx] = item;
    state = state.copyWith(columns: newColumns);
  }

  /// 删除某项
  void deleteItem(int colIdx, int itemIdx) {
    final newColumns = [...state.columns];
    newColumns[colIdx] = [...newColumns[colIdx]]..removeAt(itemIdx);
    state = state.copyWith(columns: newColumns);
  }

  /// 添加项，坐标为可选参数
  void addItem(int colIdx, {int? itemIdx}) {
    final newColumns = [...state.columns];
    newColumns[colIdx] = [...newColumns[colIdx]];
    if (itemIdx != null && itemIdx < newColumns[colIdx].length) {
      newColumns[colIdx].insert(itemIdx, OcrItem(words: '', result: null));
    } else {
      // 默认添加到末尾
      newColumns[colIdx].add(OcrItem(words: '', result: null));
    }
    state = state.copyWith(columns: newColumns);
  }

  /// 切换分页
  void togglePagination() {
    state = state.copyWith(paginated: !state.paginated);
  }
}
