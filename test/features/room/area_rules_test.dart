import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/area_rules.dart';

/// 使ってよい場所・ダメな場所の一覧(issue #108)のテスト。
///
/// 一覧はアプリに埋め込んだ固定値なので、ここで見るのは「うっかり壊れて
/// いないか」(空になっていない・重複していない・両方に同じ場所が載って
/// いない)と、ルールの要である「機械の有無で教室の可否が分かれる」こと。
void main() {
  test('どちらの一覧も空ではない', () {
    expect(allowedAreaRules, isNotEmpty);
    expect(forbiddenAreaRules, isNotEmpty);
  });

  test('同じ一覧の中に重複が無い', () {
    expect(allowedAreaRules.toSet().length, allowedAreaRules.length);
    expect(forbiddenAreaRules.toSet().length, forbiddenAreaRules.length);
  });

  test('「使ってよい」と「使用不可」に同じ場所が載っていない', () {
    final both = allowedAreaRules.toSet().intersection(
      forbiddenAreaRules.toSet(),
    );
    expect(both, isEmpty);
  });

  test('教室は機械の有無で可否が分かれる', () {
    expect(allowedAreaRules, contains('危なそうな機械がない教室'));
    expect(forbiddenAreaRules, contains('危なそうな機械がある教室'));
  });

  test('屋内の私的な場所・危ない場所は使用不可に入っている', () {
    expect(
      forbiddenAreaRules,
      containsAll(<String>['トイレ', '各研究室内', '更衣室', '学生寮', '警備室', '駐車場']),
    );
  });
}
