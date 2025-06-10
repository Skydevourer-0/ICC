import 'dart:typed_data';
import 'package:icc/model/ocr_item.dart';
import 'package:icc/api/ocr_api.dart';

/// OCR 数据仓库，负责与后端交互
class OcrRepository {
  /// 调用 OCR 接口，返回分列数据和总和
  Future<(List<List<OcrItem>>, double)> parseAndCalc(Uint8List? imgBytes) async {
    if (imgBytes == null || imgBytes.isEmpty) {
      throw ArgumentError('图像数据不能为空');
    }
    final columns = await OcrApi.parseImage(imgBytes);
    final calcRes = OcrApi.calculate(columns);
    final ans = calcRes['ans'] as double;
    return (columns, ans);
  }

  /// 重新计算
  Future<(List<List<OcrItem>>, double)> recalculate(
    List<List<OcrItem>> columns,
  ) async {
    final calcRes = OcrApi.calculate(columns);
    final ans = calcRes['ans'] as double;
    return (columns, ans);
  }
}
