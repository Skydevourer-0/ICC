import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:icc/model/ocr_item.dart';

class OcrPdfService {
  final List<List<OcrItem>> columns;
  final List<List<(String, String)>> rows;
  final double ans;

  pw.Font? fontFamily;
  double? colWidth;
  double? fontSize;

  OcrPdfService(this.columns, this.ans) : rows = _preprocessColumns(columns) {
    if (columns.isEmpty) throw Exception("列表为空");
  }

  static List<List<(String, String)>> _preprocessColumns(
    List<List<OcrItem>> columns,
  ) {
    final cols = columns.where((col) => col.isNotEmpty).toList();
    if (cols.isEmpty) return [];
    final rowCount = cols.map((c) => c.length).reduce(max);
    return List.generate(
      rowCount,
      (rowIdx) => List.generate(cols.length, (colIdx) {
        if (rowIdx < cols[colIdx].length) {
          final item = cols[colIdx][rowIdx];
          final words =
              item.words.replaceAll(RegExp(r'[*X×]'), 'x').split('=').first;
          final result =
              item.result != null ? '= ${item.result!.toStringAsFixed(2)}' : '';
          return (words, result);
        } else {
          return ('', '');
        }
      }),
    );
  }

  Future<void> _initConfig() async {
    // 设置中文字体
    fontFamily = await PdfGoogleFonts.notoSansSCRegular();
    final margin = 10.0 * 2; // 四周边距均为 20*2
    // 计算每列宽度
    final pageWidth = PdfPageFormat.a4.landscape.width;
    final usableWidth = pageWidth - margin;
    final colCount = columns.where((col) => col.isNotEmpty).length;
    colWidth = usableWidth / colCount - 30;
    // 计算字体大小
    final pageHeight = PdfPageFormat.a4.landscape.height;
    // 20 为标题字号，1.2 为行高系数
    final usableHeight = pageHeight - margin - 20 * 1.2;
    final rowCount = rows.length;
    fontSize = (usableHeight / rowCount - 5) / 1.2;
    fontSize = fontSize!.clamp(8, 20) - 1;
  }

  /// 构造每个对象的 words + result
  pw.Widget _buildItem((String, String) item) {
    final (words, result) = item;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            words,
            softWrap: true,
            style: pw.TextStyle(font: fontFamily, fontSize: fontSize),
          ),
        ),
        pw.Text(
          result,
          textAlign: pw.TextAlign.left,
          style: pw.TextStyle(fontSize: fontSize),
        ),
      ],
    );
  }

  // 构造每一行的 widget
  pw.Widget _buildRowWidget(List<(String, String)> row) {
    if (row.isEmpty) return pw.SizedBox.shrink();
    return pw.Row(
      children: [
        for (final item in row)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 15),
            child: pw.Container(width: colWidth, child: _buildItem(item)),
          ),
      ],
    );
  }

  /// 将 OCR 列表导出为 A4 格式的 PDF 表格
  Future<void> export() async {
    // 初始化配置
    await _initConfig();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        build:
            (context) => [
              pw.Text(
                '总计: ${ans.toStringAsFixed(2)}',
                style: pw.TextStyle(font: fontFamily, fontSize: 20),
              ),
              pw.SizedBox(height: 10),
              ...rows.map((row) => _buildRowWidget(row)),
            ],
      ),
    );

    // 使用打印插件进行保存、打印、预览或分享
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ocr_result.pdf',
      format: PdfPageFormat.a4.landscape,
    );
  }
}
