import 'package:flutter/material.dart';

/// OCR 识别项模型，包含识别文本和计算结果
class OcrItem {
  String words;
  double? result;

  /// 唯一标识符
  final String uid = UniqueKey().toString();

  /// words 控制器
  final TextEditingController controller = TextEditingController();

  /// 焦点
  final FocusNode focusNode = FocusNode();

  OcrItem({required this.words, this.result}) {
    controller.text = words;
  }

  factory OcrItem.fromMap(Map<String, dynamic> m) =>
      OcrItem(words: m['words'] as String, result: m['result'] as double?);

  Map<String, dynamic> toMap() => {'words': words, 'result': result};

  @override
  String toString() {
    return '{words: $words, result: $result}';
  }
}
