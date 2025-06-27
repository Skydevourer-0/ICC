import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icc/utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:icc/provider/ocr_providers.dart';

/// OCR 图像页面，负责选择图像并展示的逻辑
class OcrImagePage extends ConsumerWidget {
  const OcrImagePage({super.key});

  /// 图像选择
  static Future<void> _pickImage(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    // 关闭弹窗
    Navigator.pop(context);
    // 定义 notifier
    final notifier = ref.read(ocrResultProvider.notifier);
    // 使用 ImagePicker 选择图像
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked != null) {
      notifier.setLoading(true);
      final bytes = await picked.readAsBytes();
      notifier.setImage(bytes);
      notifier.setLoading(false);
    }
  }

  /// 选择图像来源
  static void pickImageSource(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择图像来源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () => _pickImage(context, ref, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () => _pickImage(context, ref, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 预览图像
  static void showImagePreview(BuildContext context, WidgetRef ref) {
    final imgBytes = ref.read(ocrResultProvider).imgBytes;
    // 若没有图像数据，提示用户选择图像
    if (imgBytes == null || imgBytes.isEmpty) {
      return pickImageSource(context, ref);
    }
    showGeneralDialog(
      context: context,
      pageBuilder:
          (_, __, ___) => Container(
            color: Colors.black,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(child: Image.memory(imgBytes)),
            ),
          ),
    );
  }

  /// 解析图像得到表达式列表
  static Future<void> parseImage(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(ocrResultProvider.notifier);
    try {
      await notifier.parse();
      notifier.setShowExprs(true);
    } catch (e) {
      if (context.mounted) {
        OcrUtils.showErrorDialog(context, e.toString(), title: '解析失败');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocrState = ref.watch(ocrResultProvider);

    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width * 0.8;
    final height = screenSize.height * 0.6;

    return Center(
      child: GestureDetector(
        onTap: () => showImagePreview(context, ref),
        // 长按重新选择图像
        onLongPress: () => pickImageSource(context, ref),
        child:
            ocrState.imgBytes == null || ocrState.imgBytes!.isEmpty
                ? Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('点击上传图片', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
                : ClipRRect(
                  borderRadius: BorderRadius.circular(16), // 设置圆角半径
                  child: Image.memory(
                    ocrState.imgBytes!,
                    width: width,
                    height: height,
                    fit: BoxFit.contain,
                  ),
                ),
      ),
    );
  }
}
