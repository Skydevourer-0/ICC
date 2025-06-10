/// OCR 识别项模型，包含识别文本和计算结果
class OcrItem {
  String words;
  double? result;
  OcrItem({required this.words, this.result});

  factory OcrItem.fromMap(Map<String, dynamic> m) =>
      OcrItem(words: m['words'] as String, result: m['result'] as double?);

  Map<String, dynamic> toMap() => {'words': words, 'result': result};

  @override
  String toString() {
    return '{words: $words, result: $result}';
  }
}
