import 'dart:convert';
import 'dart:ui' show TextRange;

import 'package:flutter/services.dart' show rootBundle;

/// 汉字 → 拼音离线索引（首字母 + 全拼 双表，构建期打好打进 assets）
///
/// **为什么自己打表**：常见 pinyin 包（lpinyin 2.0.3 等）把 sdk 锁在
/// `>=2.12 <3.0.0`，在当前 Dart 3.x 上根本装不进依赖图。与其引一个拉不动的
/// 包，不如用 `tool/gen_pinyin.py`（pypinyin）离线生成两张表打进 assets：
/// 运行时只是一次 O(1) 查表，零依赖、零 IO、零 GC 抖动。
///
/// **两张表，分工明确**：
/// - 首字母表（21KB，20992 字，99.7% 覆盖）：用户真实检索习惯的主路径
///   （「sg」找「手工」），一个字母一字，命中判定最便宜。
/// - 全拼表（84KB，同覆盖）：v2.7.0 应用户要求加入——输「shougong」也能找到
///   「手工」。只作为首字母 miss 之后的第二跳，不做任何前缀树/分词优化：
///   个人笔记量级（百~千条）下每次查询多扫一遍字符串完全可接受。
class PinyinSearch {
  static const String assetPath = 'assets/pinyin/first_letter.txt';
  static const String fullPath = 'assets/pinyin/full_pinyin.txt';
  static const int base = 0x4E00; // CJK 统一汉字起始
  static const int length = 0x9FFF - 0x4E00 + 1; // 20992

  /// 首字母表：一字一字母（'?' = 未映射）
  static String? _table;

  /// 全拼表：一字一音节（'?' = 未映射，多音字取 pypinyin 首选读音）
  static List<String>? _full;

  /// 首字母表是否就绪。未就绪时 [matches] 自动退化，不会崩。
  static bool get isReady => _table != null;

  /// 全拼表是否就绪。缺失只影响全拼第二跳，不影响首字母。
  static bool get isFullReady => _full != null;

  /// 从 asset 载入（启动时调一次）。两张表各自独立载入：全拼缺失只丢第二跳，
  /// 首字母缺失丢拼音层，都不该让搜索整体失效（退化为字面匹配）。
  static Future<void> ensureLoaded() async {
    if (_table == null) {
      try {
        await loadFromString(await rootBundle.loadString(assetPath));
      } catch (_) {
        _table = null;
      }
    }
    if (_full == null) {
      try {
        await loadFullFromString(await rootBundle.loadString(fullPath));
      } catch (_) {
        _full = null;
      }
    }
  }

  /// 直接灌入首字母表文本（测试用，也供 [ensureLoaded] 复用）
  ///
  /// 这里 `\r` 必须剔掉：Windows 上 git 若按 CRLF 检出该文件，每行都会多一个
  /// 字符，长度校验失败 → 静默退化成纯字面搜索。`.gitattributes` 已锁 LF，
  /// 这里是第二道防线（也不吃亏：一次 replaceAll 而已）。
  static Future<void> loadFromString(String raw) async {
    final buf = StringBuffer();
    for (final line in const LineSplitter().convert(raw)) {
      if (line.startsWith('#')) continue;
      buf.write(line.replaceAll('\r', ''));
    }
    final table = buf.toString();
    if (table.length == length) _table = table;
  }

  /// 直接灌入全拼表文本（空格分隔的音节流，与首字母表同一套 \r 防线）
  static Future<void> loadFullFromString(String raw) async {
    final buf = StringBuffer();
    for (final line in const LineSplitter().convert(raw)) {
      if (line.startsWith('#')) continue;
      buf.write(line.replaceAll('\r', ''));
      buf.write(' ');
    }
    final toks = buf.toString().trim().split(RegExp(r'\s+'));
    // 空 raw 会得到 ['']，长度不等 → 拒绝，保持 null 退化
    if (toks.length == length) _full = List.unmodifiable(toks);
  }

  /// 整串转首字母：汉字取表内字母，ASCII 字母转小写保留，其余丢弃
  static String initials(String text) {
    final table = _table;
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final cu = text.codeUnitAt(i);
      if (cu >= base && cu < base + length) {
        final letter = table == null ? '?' : table[cu - base];
        if (letter != '?') buf.write(letter);
      } else if ((cu >= 65 && cu <= 90) || (cu >= 97 && cu <= 122)) {
        buf.writeCharCode(cu >= 65 && cu <= 90 ? cu + 32 : cu);
      }
    }
    return buf.toString();
  }

  /// 整串转全拼音节流：汉字取表内音节（未映射跳过），ASCII 字母转小写保留
  ///
  /// 例：fullPinyin('手工皮具2') == 'shougoupiju2'。跨音节的子串
  /// （如 'ougo'）也能 contains 命中——这与首字母路径的行为一致
  /// （'gg' 之类同样跨字命中），对检索是有益的宽松而非缺陷。
  static String fullPinyin(String text) {
    final full = _full;
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final cu = text.codeUnitAt(i);
      if (cu >= base && cu < base + length) {
        if (full != null) {
          final s = full[cu - base];
          if (s != '?') buf.write(s);
        }
      } else if ((cu >= 65 && cu <= 90) || (cu >= 97 && cu <= 122)) {
        buf.writeCharCode(cu >= 65 && cu <= 90 ? cu + 32 : cu);
      }
    }
    return buf.toString();
  }

  /// 是否命中：[query] 空串视为命中；依次试字面（大小写不敏感）→
  /// 拼音首字母 → 全拼（后两者仅当查询本身不含汉字）
  static bool matches(String text, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (text.toLowerCase().contains(q)) return true;
    if (_hasCjk(q)) return false;
    if (initials(text).contains(q)) return true;
    if (_full == null) return false;
    return fullPinyin(text).contains(q);
  }

  /// 标题或正文任一命中
  static bool matchesAny(String title, String content, String query) =>
      matches(title, query) || matches(content, query);

  /// 命中区间（代码元坐标），供 UI 上色。
  ///
  /// 字面命中按子串切；拼音命中要把「sg / shougong」映射回「手工」这些
  /// **汉字字符**，所以先把文本压成「字母流 + 原字符下标」再反查。
  /// 两条拼音路径共用一个映射器，只是字母流的粒度不同（首字母 1:1，
  /// 全拼 1:N）。
  static List<TextRange> ranges(String text, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || text.isEmpty) return const <TextRange>[];

    final hits = <TextRange>[];

    // ① 字面子串
    final lower = text.toLowerCase();
    var from = 0;
    while (hits.length < 20) {
      final i = lower.indexOf(q, from);
      if (i < 0) break;
      hits.add(TextRange(start: i, end: i + q.length));
      from = i + q.length;
    }

    // ② 拼音（含汉字的查询不必再试，汉字不在字母流里）：
    //    先首字母（便宜），miss 再全拼（贵）
    if (!_hasCjk(q)) {
      for (final useFull in const [false, true]) {
        final (letters, offsets) = _letterStream(text, useFull);
        final stream = letters.join();
        var start = 0;
        while (hits.length < 20) {
          final i = stream.indexOf(q, start);
          if (i < 0) break;
          hits.add(TextRange(
              start: offsets[i], end: offsets[i + q.length - 1] + 1));
          start = i + q.length;
        }
      }
    }

    return _merge(hits);
  }

  /// 文本 → (字母流, 每个字母对应的原字符下标)。
  ///
  /// [useFull] = false：汉字贡献 1 个首字母；true：贡献整个音节（多字母同
  /// 下标），ASCII 字母两条路径都贡献 1。表未就绪时汉字侧静默跳过。
  static (List<String>, List<int>) _letterStream(String text, bool useFull) {
    final letters = <String>[];
    final offsets = <int>[];
    final table = useFull ? null : _table;
    final full = useFull ? _full : null;
    for (var i = 0; i < text.length; i++) {
      final cu = text.codeUnitAt(i);
      if (cu >= base && cu < base + length) {
        String? piece;
        if (useFull) {
          final s = full?[cu - base];
          piece = (s == null || s == '?') ? null : s;
        } else {
          final letter = table?[cu - base];
          piece = (letter == null || letter == '?') ? null : letter;
        }
        if (piece != null) {
          for (var j = 0; j < piece.length; j++) {
            letters.add(piece[j]);
            offsets.add(i);
          }
        }
      } else if ((cu >= 65 && cu <= 90) || (cu >= 97 && cu <= 122)) {
        letters.add(String.fromCharCode(cu >= 65 && cu <= 90 ? cu + 32 : cu));
        offsets.add(i);
      }
    }
    return (letters, offsets);
  }

  static bool _hasCjk(String s) {
    for (var i = 0; i < s.length; i++) {
      final cu = s.codeUnitAt(i);
      if (cu >= base && cu < base + length) return true;
    }
    return false;
  }

  /// 合并重叠 / 相邻区间，按起点升序（TextSpan 拼接必须有序且不回退）
  static List<TextRange> _merge(List<TextRange> hits) {
    if (hits.length <= 1) return hits;
    hits.sort((a, b) => a.start.compareTo(b.start));
    final out = <TextRange>[hits.first];
    for (final r in hits.skip(1)) {
      final last = out.last;
      if (r.start <= last.end) {
        if (r.end > last.end) {
          out[out.length - 1] = TextRange(start: last.start, end: r.end);
        }
      } else {
        out.add(r);
      }
    }
    return out;
  }
}
