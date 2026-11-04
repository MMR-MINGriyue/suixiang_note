import 'package:flutter/widgets.dart';

/// 一帧编辑状态（文本 + 光标）
class EditState {
  final String text;
  final TextSelection selection;
  const EditState(this.text, this.selection);
}

class _Frame {
  final String text;
  final TextSelection selection;
  final int at;
  const _Frame(this.text, this.selection, this.at);

  EditState get state => EditState(text, selection);
}

/// 文本编辑历史（撤销 / 重做）
///
/// 设计取舍：
/// - **连续输入合并成一帧**。若每敲一个字压一帧，撤销 20 个字要点 20 次，
///   比手动删还慢。判据：间隔 <700ms 且「纯插入、光标只前进」。
///   取 700ms 而非更短——中文输入法候选上屏比拉丁字母慢，阈值太小会把
///   一个词的输入拆成好几次撤销。
/// - **明确动作立即断帧**（coalesce=false）：点「加粗」、粘贴、整体替换
///   必须一步撤掉，不能和前面的打字黏在一起。
/// - 上限 100 帧：长文不无限吃内存。
class EditHistory {
  EditHistory(String initial, {this.capacity = 100})
      : _frames = [_Frame(initial, TextSelection.collapsed(offset: initial.length), 0)];

  final int capacity;
  final List<_Frame> _frames;
  int _cursor = 0;

  static const int mergeWindowMs = 700;

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _frames.length - 1;
  EditState get current => _frames[_cursor].state;

  void record(String text, TextSelection selection, {bool coalesce = true}) {
    final last = _frames[_cursor];
    if (last.text == text) return;

    if (coalesce && _cursor == _frames.length - 1) {
      final gap = DateTime.now().millisecondsSinceEpoch - last.at;
      final pureInsert = text.length > last.text.length &&
          selection.start >= last.selection.start;
      if (gap < mergeWindowMs && pureInsert) {
        _frames[_cursor] = _Frame(text, selection, last.at);
        return;
      }
    }

    if (_cursor < _frames.length - 1) {
      _frames.removeRange(_cursor + 1, _frames.length);
    }
    _frames.add(_Frame(text, selection, DateTime.now().millisecondsSinceEpoch));
    _cursor++;
    if (_frames.length > capacity) {
      _frames.removeAt(0);
      _cursor--;
    }
  }

  EditState? undo() {
    if (!canUndo) return null;
    return _frames[--_cursor].state;
  }

  EditState? redo() {
    if (!canRedo) return null;
    return _frames[++_cursor].state;
  }

  void reset(String text) {
    _frames
      ..clear()
      ..add(_Frame(text, TextSelection.collapsed(offset: text.length), 0));
    _cursor = 0;
  }
}
