import 'package:flutter/material.dart';

class OcrUtils {
  /// 显示错误信息弹窗
  static void showErrorDialog(
    BuildContext context,
    String message, {
    String title = '错误',
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(title: Text(title), content: Text(message)),
    );
  }
}
