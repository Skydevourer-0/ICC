import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icc/model/ocr_item.dart';
import 'package:icc/repository/ocr_repo.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

final _logger = Logger('OcrResultNotifier');

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

  /// 是否已解析过当前图片
  final bool imgParsed;

  /// 当前焦点 id
  final String focusedUid;

  /// 当前页
  final int curPage;

  /// 构造函数
  OcrResultState({
    required this.imgBytes,
    required this.columns,
    required this.ans,
    this.loading = false,
    this.imgParsed = false,
    this.focusedUid = '',
    this.curPage = -1,
  });

  /// 深度拷贝并更新某个字段
  OcrResultState copyWith({
    Uint8List? imgBytes,
    List<List<OcrItem>>? columns,
    double? ans,
    bool? loading,
    bool? imgParsed,
    String? focusedUid,
    int? curPage,
  }) => OcrResultState(
    imgBytes: imgBytes ?? this.imgBytes,
    columns: columns ?? this.columns,
    ans: ans ?? this.ans,
    loading: loading ?? this.loading,
    imgParsed: imgParsed ?? this.imgParsed,
    focusedUid: focusedUid ?? this.focusedUid,
    curPage: curPage ?? this.curPage,
  );
}

/// OCR 识别结果 StateNotifier，Provider 核心，负责处理状态逻辑
class OcrResultNotifier extends StateNotifier<OcrResultState> {
  // Hive 数据库名称
  static const String _historyBoxName = 'ocr_state_history';
  // 最大历史记录数
  static const int _maxHistoryLength = 20;
  // OCR 仓库实例
  final OcrRepository repo;
  // 防抖计时器
  Timer? _debounce;

  OcrResultNotifier(this.repo)
    : super(
        OcrResultState(imgBytes: null, columns: [], ans: 0, loading: true),
      ) {
    loadState();
  }

  Future<Box<Map>> _openHistoryBox() async {
    return await Hive.openBox<Map>(_historyBoxName);
  }

  bool _isSameImage(Uint8List? a, Uint8List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.lengthInBytes != b.lengthInBytes) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Map<String, dynamic> _stateToMap(OcrResultState state) => {
    'imgBytes': state.imgBytes,
    'columns': state.columns,
    'ans': state.ans,
    'loading': state.loading,
    'imgParsed': state.imgParsed,
    'focusedUid': state.focusedUid,
    'curPage': state.curPage,
  };

  OcrResultState _mapToState(Map map) => OcrResultState(
    imgBytes: map['imgBytes'],
    columns:
        map['columns'].map<List<OcrItem>>((col) {
          return (col as List).cast<OcrItem>();
        }).toList() ??
        [],
    ans: map['ans'] ?? 0.0,
    loading: map['loading'] ?? false,
    imgParsed: map['imgParsed'] ?? false,
    focusedUid: map['focusedUid'] ?? '',
    curPage: map['curPage'] ?? -1,
  );

  /// 加载状态
  Future<void> loadState([String? timestamp]) async {
    try {
      final box = await _openHistoryBox();
      String? key = timestamp;
      if (key == null && box.isNotEmpty) {
        // 取最大值
        key = box.keys.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      }
      if (key != null) {
        final map = box.get(key);
        if (map != null) {
          state = _mapToState(map).copyWith(loading: false);
          return;
        }
      }
      throw StateError('历史记录不存在.');
    } catch (e, stack) {
      // 如果加载失败，返回默认状态
      _logger.severe('加载 OCR 状态失败: $e\n$stack');
      state = OcrResultState(imgBytes: null, columns: [], ans: 0);
    }
  }

  /// 加载历史图像
  Future<Uint8List?> loadImgBytes(String timestamp) async {
    try {
      final box = await _openHistoryBox();
      final map = box.get(timestamp);
      return map?['imgBytes'];
    } catch (e, stack) {
      _logger.severe('加载历史图像 [$timestamp] 失败: $e\n$stack');
      return null;
    }
  }

  /// 保存状态
  Future<void> saveState() async {
    try {
      // 打开 Hive 数据库
      final box = await _openHistoryBox();
      String key = DateTime.now().toIso8601String();
      if (box.isNotEmpty) {
        final latestKey = box.keys.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
        final latest = latestKey != null ? box.get(latestKey) : null;
        final curImgBytes = state.imgBytes;
        final lastImgBytes = latest?['imgBytes'];
        if (_isSameImage(curImgBytes, lastImgBytes)) {
          key = latestKey!;
        }
      }
      // 更新当前时间戳的记录
      final updated = _stateToMap(state);
      await box.put(key, updated);

      // 限制记录数量
      if (box.keys.length >= _maxHistoryLength) {
        final minKey = box.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
        await box.delete(minKey);
      }
    } catch (e, stack) {
      _logger.severe('保存 OCR 状态失败: $e\n$stack');
    }
  }

  /// 获取所有时间戳列表
  Future<List<String>> getAllTimestamps() async {
    final box = await _openHistoryBox();
    final keys = box.keys.cast<String>().toList()..sort();
    return keys.reversed.toList(); // 新的在上
  }

  /// 删除指定时间戳
  Future<void> deleteTimestamp(String timestamp) async {
    final box = await _openHistoryBox();
    await box.delete(timestamp);
  }

  /// 识别新的图片并计算结果
  Future<void> parse() async {
    state = state.copyWith(loading: true);
    try {
      final (columns, ans) = await repo.parseAndCalc(state.imgBytes);
      state = state.copyWith(columns: columns, ans: ans, imgParsed: true);
    } finally {
      state = state.copyWith(loading: false);
      await saveState();
    }
  }

  /// 重新计算
  Future<void> recalculate() async {
    state = state.copyWith(loading: true);
    try {
      final (columns, ans) = await repo.recalculate(state.columns);
      state = state.copyWith(columns: columns, ans: ans);
    } finally {
      state = state.copyWith(loading: false);
      await saveState();
    }
  }

  /// 导出文件
  Future<void> export() async {
    state = state.copyWith(loading: true);
    try {
      await repo.export(state.columns, state.ans);
    } finally {
      state = state.copyWith(loading: false);
      await saveState();
    }
  }

  /// 旋转图像
  Future<void> rotateImage(int angle) async {
    if (state.imgBytes == null || state.imgBytes!.isEmpty) {
      throw ArgumentError('图像数据不能为空');
    }
    state = state.copyWith(loading: true);
    try {
      final rotated = await repo.rotateImage(state.imgBytes!, angle);
      setImage(rotated);
    } finally {
      state = state.copyWith(loading: false);
    }
    saveState();
  }

  /// 设置图像数据
  void setImage(Uint8List? bytes) {
    state = OcrResultState(imgBytes: bytes, columns: [], ans: 0);
  }

  /// 设置加载状态
  void setLoading(bool loading) {
    state = state.copyWith(loading: loading);
  }

  /// 设置焦点 id
  void setFocusedUid(String uid) {
    state = state.copyWith(focusedUid: uid);
  }

  /// 设置当前页
  void setCurPage(int colIdx) {
    state = state.copyWith(curPage: colIdx);
  }

  /// 添加项，在焦点位置添加空表达式，无焦点则添加到末尾，完成后聚焦到新项
  void addItem() {
    final result = selectItem(state.focusedUid);
    final newItem = OcrItem(words: '', result: null);
    final newColumns = [...state.columns];
    if (result == null) {
      // 未找到对应的 uid，无焦点，添加到当前页的末端
      final curPage =
          state.curPage != -1 ? state.curPage : newColumns.length - 1;
      newColumns[curPage].add(newItem);
    } else {
      final (colIdx, itemIdx) = (result.col, result.row);
      newColumns[colIdx] = [...newColumns[colIdx]];
      newColumns[colIdx].insert(itemIdx + 1, newItem);
    }
    state = state.copyWith(columns: newColumns, focusedUid: newItem.uid);

    saveState();
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

    saveState();
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

    // 防抖更新
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      // 更新后保存状态
      saveState();
    });
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
}
