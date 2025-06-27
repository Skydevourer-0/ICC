import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

/// 适用于 Hive 的 OcrItem 适配器
@HiveType(typeId: 0)
class OcrItemAdapter extends TypeAdapter<OcrItem> {
  @override
  final int typeId = 0;

  @override
  OcrItem read(BinaryReader reader) {
    return OcrItem(
      words: reader.readString(),
      result: reader.readBool() ? reader.readDouble() : null,
    );
  }

  @override
  void write(BinaryWriter writer, OcrItem item) {
    writer.writeString(item.words);
    if (item.result == null) {
      writer.writeBool(false);
    } else {
      writer.writeBool(true);
      writer.writeDouble(item.result!);
    }
  }
}
