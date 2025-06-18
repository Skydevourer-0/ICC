import 'package:icc/model/ocr_item.dart';

class OcrUtils {
  /// 将一维索引映射回列和项索引
  static MapEntry<int, int> getColAndItemIdx(
    List<List<OcrItem>> columns,
    int colIndex,
    int flatIndex,
  ) {
    if (colIndex != -1) {
      return MapEntry(colIndex, flatIndex);
    }
    int count = 0;
    for (int col = 0; col < columns.length; col++) {
      if (flatIndex < count + columns[col].length) {
        return MapEntry(col, flatIndex - count);
      }
      count += columns[col].length;
    }
    throw Exception('Index out of range');
  }
}
