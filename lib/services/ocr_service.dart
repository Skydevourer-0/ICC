import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_caption_calculator/model/ocr_item.dart';
import 'package:logging/logging.dart';

final _logger = Logger('OCRService');

class OcrService {
  // base64 编码图像字符串
  final String imgData;

  OcrService(this.imgData);

  static const String _apiKey = String.fromEnvironment("API_KEY");
  static const String _secretKey = String.fromEnvironment("SECRET_KEY");

  /// 获取 Access Token
  static Future<String?> getAccessToken() async {
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
  static List<List<dynamic>>? sortOcrResults(List<dynamic>? results) {
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

  /// 计算算式
  static double regexCalculate(List<List<OcrItem>> columns) {
    final mulSigns = r'[xX\*\×]';
    final floatPattern = r'\d+(?:\.\d+)?(?:[a-zA-Z\u4e00-\u9fa5]*)';
    final exprRegex = RegExp(
      // 可选的前缀说明
      r"^[\s\u4e00-\u9fa5]*"
      // 主表达式：匹配一个或多个数字（可带小数和单位），中间用乘号连接
      "($floatPattern\\s*(?:$mulSigns\\s*$floatPattern)+)"
      // 可选的等号和结果
      r"(?:\s*=\s*(\d+(?:\.\d+)?)?)?$",
    );

    double sum = 0.0;

    for (final col in columns) {
      for (final item in col) {
        final text = item.words;
        final match = exprRegex.firstMatch(text);
        if (match == null) continue;
        // 提取表达式和给定结果
        final expr = match.group(1)!;
        final givenResultStr = match.group(2);

        final numRegex = RegExp(r'\d+(?:\.\d+)?');
        final nums =
            numRegex
                .allMatches(expr)
                .map((m) => double.parse(m.group(0)!))
                .toList();

        if (nums.length < 2) continue;

        try {
          double product = 1.0;
          for (final n in nums) {
            product *= n;
          }
          if (givenResultStr != null) {
            final givenResult = double.parse(givenResultStr);
            if ((product - givenResult).abs() > 0.2) {
              _logger.warning(
                '计算结果与给定结果不符: $expr = $product, 给定: $givenResultStr',
              );
              continue;
            }
          }
          item.result = product;
          sum += product;
        } catch (e, st) {
          _logger.warning('计算乘法算式 $expr 失败: $e', e, st);
        }
      }
    }

    return sum;
  }

  /// 调用百度 OCR API，返回识别文本数组
  Future<List<List<OcrItem>>> run() async {
    final token = await getAccessToken();
    if (token == null) {
      _logger.severe('获取 Access Token 失败');
      return [];
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
        return [];
      }

      final jsonResp = json.decode(response.body);
      final wordsResult = jsonResp['words_result'] as List<dynamic>?;

      final sortedResults = sortOcrResults(wordsResult);
      if (sortedResults == null) {
        _logger.warning('OCR结果为空');
        return [];
      }

      return [
        for (final col in sortedResults)
          [
            for (final item in col) OcrItem.fromMap({'words': item['words']}),
          ],
      ];
    } catch (e, st) {
      _logger.severe('OCR结果解析失败: $e', e, st);
      return [];
    }
  }
}
