import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:icc/model/ocr_item.dart';
import 'package:image/image.dart' as img_lib;
import 'package:logging/logging.dart';

final _logger = Logger('OCRService');

class OcrService {
  /// 图像数据
  final Uint8List imgBytes;

  /// base64 编码图像字符串
  final String imgData;

  OcrService(this.imgBytes) : imgData = _preprocessImage(imgBytes);

  static const String _apiKey = String.fromEnvironment("API_KEY");
  static const String _secretKey = String.fromEnvironment("SECRET_KEY");

  /// 获取 Access Token
  Future<String?> _getAccessToken() async {
    final url = Uri.parse('https://aip.baidubce.com/oauth/2.0/token');

    final params = {
      'grant_type': 'client_credentials',
      'client_id': _apiKey,
      'client_secret': _secretKey,
    };
    try {
      final response = await http.post(url, body: params);
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['access_token'] as String?;
      } else {
        _logger.severe('获取Access Token失败，状态码: ${response.statusCode}');
      }
    } catch (e, st) {
      _logger.severe('接口鉴权失败: $e', e, st);
    }
    return null;
  }

  /// 对 OCR 结果进行排序（左列优先，同列上方优先）
  List<List<dynamic>>? _sortOcrResults(List<dynamic>? results) {
    if (results == null || results.isEmpty) return null;

    const int disThreshold = 100;

    List<List<dynamic>> columns = [];

    for (final item in results) {
      bool placed = false;
      final itemLeft = item['location']['left'] as int;
      for (final col in columns) {
        final colLeft = col[0]['location']['left'] as int;
        if ((itemLeft - colLeft).abs() < disThreshold) {
          col.add(item);
          placed = true;
          break;
        }
      }
      if (!placed) {
        columns.add([item]);
      }
    }

    columns.sort(
      (a, b) => (a[0]['location']['left'] as int).compareTo(
        b[0]['location']['left'] as int,
      ),
    );
    for (final col in columns) {
      col.sort(
        (a, b) => (a['location']['top'] as int).compareTo(
          b['location']['top'] as int,
        ),
      );
    }

    return columns;
  }

  /// 图像预处理：缩放宽度到 800，灰度化，转 base64
  static String _preprocessImage(Uint8List imgBytes) {
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

  /// 图像旋转
  static Future<Uint8List> rotateImage(Uint8List imgBytes, int angle) {
    return compute((Uint8List imgBytes) {
      // 使用 image 库解码图片
      final image = img_lib.decodeImage(imgBytes);
      if (image == null) {
        throw Exception('图片解码失败');
      }
      // 旋转图像
      final rotated = img_lib.copyRotate(image, angle: angle);
      // 编码为 jpg bytes
      final jpgBytes = img_lib.encodeJpg(rotated);
      return jpgBytes;
    }, imgBytes);
  }

  /// 计算算式
  static double regexCalculate(List<List<OcrItem>> columns) {
    final mulSigns = r'[xX\*\×]';
    final floatPattern = r'\d+(?:\.\d+)?(?:[a-zA-Z\u4e00-\u9fa5\(\)（）]*)';
    final exprRegex = RegExp(
      // 可选的前缀说明
      r"^[\s\u4e00-\u9fa5]*"
      // 主表达式：匹配一个或多个数字（可带小数和单位），中间用乘号连接
      "(?<expr>$floatPattern\\s*(?:$mulSigns\\s*$floatPattern)+)?"
      // 可选的等号和结果
      r"(?:\s*=\s*(?<result>\d+(?:\.\d+)?)?)?$",
    );

    double sum = 0.0;

    for (final col in columns) {
      for (final item in col) {
        final text = item.words;
        final match = exprRegex.firstMatch(text);
        if (match == null) continue;
        // 提取表达式和给定结果
        final expr = match.namedGroup('expr');
        final givenResultStr = match.namedGroup('result');

        try {
          double? product;
          if (expr != null) {
            product = 1;
            final numRegex = RegExp(r'\d+(?:\.\d+)?');
            final nums =
                numRegex
                    .allMatches(expr)
                    .map((m) => double.parse(m.group(0)!))
                    .toList();
            for (final n in nums) {
              product = product! * n;
            }
          }

          if (givenResultStr != null) {
            final givenResult = double.parse(givenResultStr);
            product ??= givenResult;
            if ((product - givenResult).abs() > 0.2) {
              _logger.warning(
                '计算结果与给定结果不符: $expr = $product, 给定: $givenResultStr',
              );
              continue;
            }
          }
          item.result = product;
          if (product != null) sum += product;
        } catch (e, st) {
          _logger.warning('计算乘法算式 $expr 失败: $e', e, st);
        }
      }
    }

    return sum;
  }

  /// 调用百度 OCR API，返回识别文本数组与计算结果
  Future<(List<List<OcrItem>>, double)?> run() async {
    final token = await _getAccessToken();
    if (token == null) {
      _logger.severe('获取 Access Token 失败');
      return null;
    }

    final url = Uri.parse(
      'https://aip.baidubce.com/rest/2.0/ocr/v1/handwriting?access_token=$token',
    );

    final payload = {
      'image': imgData,
      'detect_direction': 'false',
      'probability': 'false',
      'detect_alteration': 'false',
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: payload,
      );

      if (response.statusCode != 200) {
        _logger.severe('OCR请求失败，状态码：${response.statusCode}');
        return null;
      }

      final jsonResp = json.decode(response.body);
      final wordsResult = jsonResp['words_result'] as List<dynamic>?;

      final sortedResults = _sortOcrResults(wordsResult);
      if (sortedResults == null) {
        _logger.warning('OCR结果为空');
        return null;
      }
      // 构造识别结果列表
      final columns = [
        for (final col in sortedResults)
          [
            for (final item in col) OcrItem.fromMap({'words': item['words']}),
          ],
      ];
      // 计算列表中的算式结果
      double ans = regexCalculate(columns);
      return (columns, ans);
    } catch (e, st) {
      _logger.severe('OCR结果解析失败: $e', e, st);
      return null;
    }
  }
}
