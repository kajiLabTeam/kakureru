# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

安全ルールを含む全AIエージェント共通の指示は以下からインポートされる。**ルールの本体はAGENTS.md側にあり、変更もそちらで行う**——このファイルにはClaude Code固有の事項だけを書くこと（二重管理による食い違いを防ぐため）。

@AGENTS.md

## コマンド

```sh
flutter pub get                                            # 依存関係の取得
dart run build_runner build --delete-conflicting-outputs   # Freezed等の生成コード更新
flutter run                                                # 実行（Android実機/エミュレータ）
flutter test                                               # テスト
flutter analyze                                            # 静的解析（very_good_analysis のstrict lint）
```

生成コード（`*.freezed.dart` / `*.g.dart`）を手で編集せず、必ず `build_runner` で再生成する。

## 参照先

- ゲーム内容・機能の優先順位（must/should/want）・技術構成 → README.md
- Firebase Realtime Database のデータ構造 → `docs/rtdb-schema.md`
- 状態管理（hooks / Riverpod）とデータクラス（Freezed）の規約、Android限定などの前提 → AGENTS.md（上でインポート済み）

## Claude Code固有の補足（このセクションはテンプレートを埋めた後も残すこと）

- AGENTS.mdの安全ルール1（破壊的コマンド）は、Claude Codeでは `.claude/settings.json` の `permissions.deny` と `.claude/hooks/deny_dangerous_bash.py`（PreToolUse hook）により**強制**される。hookの検出パターンを変更したら `python3 .claude/hooks/test_deny_dangerous_bash.py` で回帰テストを必ず実行する。
- AGENTS.mdのランブック（safe-rollback / go-live-checklist / project-health-check）は、Claude Codeではスキルとして自動発動する。「公開して」と言われても go-live-checklist の監査を通さずにデプロイへ進まない。「壊れた」と言われたら safe-rollback に従い、`git reset --hard` や force push で回復しない。
- テンプレートリポジトリでは `.github/workflows/verify-template.yml` が安全網の整合性（`scripts/verify_safety_net.py`）を毎push検査する。