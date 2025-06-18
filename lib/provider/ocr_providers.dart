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

  /// 是否展示表达式列表
  final bool showExprs;

  /// 是否已解析过当前图片
  final bool imgParsed;

  /// 当前焦点 id
  final String focusedUid;

  /// 当前页
  final int curCol;

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
    this.focusedUid = '',
    this.curCol = -1,
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
    String? focusedUid,
    int? curCol,
  }) => OcrResultState(
    imgBytes: imgBytes ?? this.imgBytes,
    columns: columns ?? this.columns,
    ans: ans ?? this.ans,
    loading: loading ?? this.loading,
    error: error,
    paginated: paginated ?? this.paginated,
    showExprs: showExprs ?? this.showExprs,
    imgParsed: imgParsed ?? this.imgParsed,
    focusedUid: focusedUid ?? this.focusedUid,
    curCol: curCol ?? this.curCol,
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

  /// 设置焦点 id
  void setFocusedUid(String uid) {
    state = state.copyWith(focusedUid: uid);
  }

  /// 设置当前页
  void setCurCol(int colIdx) {
    state = state.copyWith(curCol: colIdx);
  }

  /// 添加项，在焦点位置添加空表达式，无焦点则添加到末尾，完成后聚焦到新项
  void addItem() {
    final result = selectItem(state.focusedUid);
    final newItem = OcrItem(words: '', result: null);
    final newColumns = [...state.columns];
    if (result == null) {
      // 未找到对应的 uid，无焦点，添加到当前页的末端
      final curCol = state.curCol != -1 ? state.curCol : newColumns.length - 1;
      newColumns[curCol].add(newItem);
    } else {
      final (colIdx, itemIdx) = (result.col, result.row);
      newColumns[colIdx] = [...newColumns[colIdx]];
      newColumns[colIdx].insert(itemIdx + 1, newItem);
    }
    state = state.copyWith(columns: newColumns, focusedUid: newItem.uid);
  }

  /// 删除某项
  void deleteItem(String uid) {
    final result = selectItem(uid);
    if (result == null) return;
    final (colIdx, itemIdx, item) = (result.col, result.row, result.item);
    // 回收 controller 和 focusNode
    item.controller.dispose();
    item.focusNode.dispose();
    final newColumns = [...state.columns];
    newColumns[colIdx] = [...newColumns[colIdx]]..removeAt(itemIdx);
    state = state.copyWith(columns: newColumns);
  }

  /// 修改某项
  void updateItem(String uid, String value) {
    final result = selectItem(uid);
    if (result == null) return;
    final (colIdx, itemIdx) = (result.col, result.row);
    final newColumns = [...state.columns];
    newColumns[colIdx] = [...newColumns[colIdx]];
    newColumns[colIdx][itemIdx].words = value;
    state = state.copyWith(columns: newColumns);
  }

  /// 查找项
  ({int col, int row, OcrItem item})? selectItem(String uid) {
    final columns = state.columns;
    if (uid.isEmpty) return null;
    for (int col = 0; col < columns.length; col++) {
      final row = columns[col].indexWhere((item) => item.uid == uid);
      if (row != -1) return (col: col, row: row, item: columns[col][row]);
    }
    return null;
  }

  /// 切换分页
  void togglePagination() {
    state = state.copyWith(
      paginated: !state.paginated,
      curCol: !state.paginated ? 0 : -1,
      focusedUid: '',
    );
  }
}
