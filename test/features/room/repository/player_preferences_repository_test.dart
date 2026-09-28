import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/repository/player_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerPreferencesRepository', () {
    test('保存前はnullを返す', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PlayerPreferencesRepository();

      expect(await repo.loadDisplayName(), isNull);
    });

    test('保存した名前をそのまま復元できる', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PlayerPreferencesRepository();

      await repo.saveDisplayName('たろう');

      expect(await repo.loadDisplayName(), 'たろう');
    });

    test('保存し直すと最新の値で上書きされる', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PlayerPreferencesRepository();

      await repo.saveDisplayName('たろう');
      await repo.saveDisplayName('じろう');

      expect(await repo.loadDisplayName(), 'じろう');
    });

    test('プラグイン未実装でも例外を投げず、読み込みはnullで済ませる', () async {
      // モックを設定しない状態(プラグインが未実装な状況を模す)でも、
      // アプリの動作は止めない(保存に失敗するだけで済ませる)仕様であること。
      SharedPreferences.resetStatic();
      final repo = PlayerPreferencesRepository();

      await expectLater(repo.saveDisplayName('たろう'), completes);
      await expectLater(repo.loadDisplayName(), completes);
    });
  });

  group('手がかりの見方を見たか', () {
    test('保存前はfalse(初回は説明を出す)', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PlayerPreferencesRepository();

      expect(await repo.loadClueGuideSeen(), isFalse);
    });

    test('一度記録すればtrue', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PlayerPreferencesRepository();

      await repo.saveClueGuideSeen();

      expect(await repo.loadClueGuideSeen(), isTrue);
    });

    test('名前の保存とは独立している', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PlayerPreferencesRepository();

      await repo.saveDisplayName('たろう');

      expect(await repo.loadClueGuideSeen(), isFalse);
    });
  });
}
