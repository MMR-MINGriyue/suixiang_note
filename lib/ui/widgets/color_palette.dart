import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/tokens.dart';

/// 8 色标签板（与 tag_manage_page 同源）；文件夹抽屉网格换色用
const kPalette = <String>[
  '#4C6FFF', // 靛蓝
  '#2FBF8F', // 湖绿
  '#F5A623', // 暖橙
  '#E5484D', // 珊瑚红
  '#9B6CFF', // 紫
  '#2D9CDB', // 天蓝
  '#E8A0BF', // 粉
  '#8D9106', // 橄榄
];

Color hexToColor(String hex, {Color fallback = T.brandPrimary}) =>
      parseHexColor(hex, fallback: fallback);

/// 新建/换色共用：8 色板选择行
class ColorPickerRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const ColorPickerRow(
      {super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kPalette
          .map((hex) => GestureDetector(
                onTap: () => onSelect(hex),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hexToColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected == hex
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : T.inkPrimary)
                            : Colors.transparent,
                        width: 2.5),
                  ),
                  child: selected == hex
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : null,
                ),
              ))
          .toList(),
    );
  }
}
