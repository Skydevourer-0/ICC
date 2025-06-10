import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img_lib;
import 'package:icc/model/ocr_item.dart';
import 'package:icc/services/ocr_service.dart';

import "dart:io";
import 'package:logging/logging.dart';

class OcrApi {
  /// 图像预处理：缩放宽度到 800，灰度化，转 base64
  static String preprocessImage(Uint8List imgBytes) {
    // 使用 image 库解码图片
    final image = img_lib.decodeImage(imgBytes);
    if (image == null) {
      throw Exception('图片解码失败');
    }

    // 按比例缩放到宽度800
    final newWidth = 800;
    final newHeight = (image.height * newWidth / image.width).round();
    final resized = img_lib.copyResize(
      image,
      width: newWidth,
      height: newHeight,
    );
    // 灰度化
    final grayImage = img_lib.grayscale(resized);
    // 编码为 jpg bytes
    final jpgBytes = img_lib.encodeJpg(grayImage);
    // 转 base64
    final base64Str = base64Encode(jpgBytes);

    return base64Str;
  }

  /// 处理用户传入的图片字节，调用 OCR 服务返回结果
  static Future<List<List<OcrItem>>> parseImage(
    Uint8List imgBytes,
  ) async {
    final base64Image = preprocessImage(imgBytes);
    final ocrService = OcrService(base64Image);
    return await ocrService.run();
  }

  /// 计算接口，传入 OCR 识别结果，返回带结果和总和
  static Map<String, dynamic> calculate(
    List<List<OcrItem>> columns,
  ) {
    final ans = OcrService.regexCalculate(columns);
    return {'data': columns, 'ans': ans};
  }
}

Future<void> main(List<String> args) async {
  Logger.root.level = Level.ALL; // 设置日志级别
  Logger.root.onRecord.listen((record) {
    print(
      '[${record.level.name}] ${record.loggerName}: ${record.time}: ${record.message}',
    );
  });
  final logger = Logger('OCRApi');

  // ① 取得图片文件路径：命令行参数或默认示例图
  final imagePath = 'tmp/test.jpg';
  final imageFile = File(imagePath);

  if (!await imageFile.exists()) {
    stderr.writeln('❌ 找不到图片文件 $imagePath');
    exit(1);
  }

  // ② 读取图片字节
  final Uint8List imgBytes = await imageFile.readAsBytes();

  // ③ 调用 OCR 接口：解析图片
  logger.info('🔍 调用 OCRApi.parseImage...');
  final columns = await OcrApi.parseImage(imgBytes);

  if (columns.isEmpty) {
    logger.severe('🫥 OCR 结果为空');
    exit(0);
  }

  // 打印分列后的文本结果
  logger.info('✅ OCR 识别文本（按列顺序）：');
  // print(JsonEncoder.withIndent('  ').convert(columns));

  // ④ 调用计算
  logger.info('\n🧮 调用 OCRApi.calculate...');
  final calc = OcrApi.calculate(columns);

  // ⑤ 打印最终结果
  logger.info('\n📄 完整 JSON 输出（含每项计算结果 + 总和）:');
  logger.info(calc);
}
