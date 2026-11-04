import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suixiang_note/core/app_info.dart';

/// 版本号一致性守卫。
///
/// 关于页曾经写死「v1.0」，而工程已经跑到 1.8 —— 用户看到的版本号和
/// 实际安装的包不是一回事，报 bug 时对不上号。现在版本号只有一个来源
/// （core/app_info.dart），本测试负责保证它和 pubspec.yaml 不脱节，
/// 且 CI 每次 push 都会跑，脱节会直接红。
void main() {
  test('kAppVersion 与 pubspec.yaml 的 version 完全一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml 里找不到 version 行');
    expect(
      kAppVersion,
      match!.group(1),
      reason: 'lib/core/app_info.dart 的 kAppVersion 与 pubspec.yaml 不一致：'
          '改版本号时两处必须同时改（否则关于页显示的版本是错的）',
    );
  });

  test('kAppVersionShort 去掉 build number 后只剩 x.y.z', () {
    expect(kAppVersionShort, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(kAppVersion.contains('+'), isTrue,
        reason: 'pubspec version 应带 +buildNumber，否则 Android 无法升级安装');
  });
}
