import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:icc/model/ocr_item.dart';

class OcrPdfService {
  final List<List<OcrItem>> oriColumns;
  final List<List<(String, String)>> columns;
  final double ans;

  pw.Font? fontFamily;
  double? colWidth;
  double? fontSize;

  OcrPdfService(this.oriColumns, this.ans)
    : columns = _preprocessColumns(oriColumns) {
    if (oriColumns.isEmpty) throw Exception("列表为空");
  }

  static List<List<(String, String)>> _preprocessColumns(
    List<List<OcrItem>> columns,
  ) {
    return columns.map((col) {
      return col.map((item) {
        final words =
            item.words.replaceAll(RegExp(r'[*X×]'), 'x').split('=').first;
        final result =
            item.result != null ? '= ${item.result!.toStringAsFixed(2)}' : '';
        return (words, result);
      }).toList();
    }).toList();
  }

  Future<void> _initConfig() async {
    // 设置中文字体
    fontFamily = await PdfGoogleFonts.notoSansSCRegular();
    final margin = 20.0 * 2; // 四周边距均为 20*2
    // 计算每列宽度
    final pageWidth = PdfPageFormat.a4.landscape.width;
    final usableWidth = pageWidth - margin;
    final colCount = columns.where((col) => col.isNotEmpty).length;
    colWidth = usableWidth / colCount - 30;
    // 计算字体大小
    final pageHeight = PdfPageFormat.a4.landscape.height;
    // 22 为标题字号，1.2 为行高系数
    final usableHeight = pageHeight - margin - 22 * 1.2;
    final rowCount = columns.map((c) => c.length).reduce(max);
    fontSize = (usableHeight / rowCount - 5) / 1.2;
    fontSize = fontSize!.clamp(8, 20);
  }

  /// 构造每一行的 words + result
  pw.Widget _buildRowItem((String, String) item) {
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

  // 构造每一列的 widget
  pw.Widget _buildColumnWidget(List<(String, String)> col) {
    if (col.isEmpty) return pw.SizedBox.shrink();
    return pw.Container(
      width: colWidth,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [...col.map(_buildRowItem)],
      ),
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
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        build:
            (context) => [
              pw.Text(
                '总计: ${ans.toStringAsFixed(2)}',
                style: pw.TextStyle(font: fontFamily, fontSize: 22),
              ),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 30,
                runSpacing: 10,
                children: [for (var col in columns) _buildColumnWidget(col)],
              ),
            ],
      ),
    );

    // 使用打印插件进行保存、打印、预览或分享
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ocr_result.pdf',
    );
  }
}
