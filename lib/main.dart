// import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:icc/provider/ocr_providers.dart';
import 'package:icc/widgets/ocr_image.dart';

class OcrHomePage extends ConsumerWidget {
  const OcrHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final ocrState = ref.watch(ocrResultProvider);
    // final notifier = ref.read(ocrResultProvider.notifier);

    return Scaffold(body: OcrImagePage());
  }
}
