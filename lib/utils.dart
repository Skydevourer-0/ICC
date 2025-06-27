import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

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

  /// 日志信息颜色
  static String _logColor(Level level) {
    switch (level) {
      case Level.SEVERE:
        return '\x1B[31m'; // 红色
      case Level.WARNING:
        return '\x1B[33m'; // 黄色
      case Level.INFO:
        return '\x1B[32m'; // 绿色
      case Level.FINE:
      case Level.FINER:
      case Level.FINEST:
        return '\x1B[34m'; // 蓝色
      default:
        return '\x1B[0m'; // 默认
    }
  }

  /// 设置日志打印
  static void setupLogging() {
    Logger.root.level = Level.ALL; // 设置日志级别
    Logger.root.onRecord.listen((record) {
      final color = _logColor(record.level);
      const reset = '\x1B[0m'; // 重置颜色
      print(
        '$color[${record.level.name}] ${record.loggerName}: ${record.time}: ${record.message}$reset',
      );
    });
  }

  /// 加载页面
  static Widget loadingPage() {
    return Positioned.fill(
      child: Container(
        color: Colors.black45,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
