import 'dart:typed_data';
import 'package:icc/model/ocr_item.dart';
import 'package:icc/services/ocr_pdf_service.dart';
import 'package:icc/services/ocr_service.dart';

/// OCR 数据仓库，负责与后端交互
class OcrRepository {
  /// 调用 OCR 接口，返回分列数据和总和
  Future<(List<List<OcrItem>>, double)> parseAndCalc(
    Uint8List? imgBytes,
  ) async {
    if (imgBytes == null || imgBytes.isEmpty) {
      throw ArgumentError('图像数据不能为空');
    }
    final ocrService = OcrService(imgBytes);
    final res = await ocrService.run();
    return res ?? (throw Exception('识别计算结果为空'));
  }

  /// 重新计算
  Future<(List<List<OcrItem>>, double)> recalculate(
    List<List<OcrItem>> columns,
  ) async {
    final ans = OcrService.regexCalculate(columns);
    return (columns, ans);
  }

  /// 导出文件
  Future<void> export(List<List<OcrItem>> columns, double ans) async {
    final pdfService = OcrPdfService(columns, ans);
    return await pdfService.export();
  }
}
