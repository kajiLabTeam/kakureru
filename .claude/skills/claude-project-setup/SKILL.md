---
name: claude-project-setup
description: このFlutterプロジェクトにClaude Code用の.claude/環境を対話形式でセットアップする。settings.jsonの権限・hooks設定、必要に応じたカスタムskill・command・subagentの雛形作成、CLAUDE.mdのビルド/実行/テストコマンド欄の穴埋めを行う。「セットアップして」「環境構築して」「init」「このプロジェクトでClaude Codeを使えるようにして」「開発を始めたいので準備して」といった依頼で積極的に使うこと。ビルトインの/initはCLAUDE.mdのドキュメント生成に特化しているが、権限設定やskill/command/agentの追加が絡む場合は必ずこちらを使う。
---

# Claude Project Setup

Claude Codeが最初から気持ちよく働けるように `.claude/` 環境を整えるスキル。目的は「テンプレートを埋める」ことではなく、**そのプロジェクト固有の開発フローに合った設定を対話で見極めて反映する**こと。

このスキルは **Flutter / Dart プロジェクト・エンジニアが常駐する体制**を前提に絞り込んである。他スタックや非エンジニア運用の分岐は削除済みなので、前提が変わったら書き足すこと。

## 進め方の全体像

1. プロジェクトを自動検出する
2. 検出できなかった部分・曖昧な部分をユーザーに確認しながら埋める
3. `.claude/settings.json` を作る/更新する、あわせて `.gitignore` を整備する
4. 繰り返し作業があれば、Skill・Command・Subagent のどれが適切かを判断して雛形を作る
5. `CLAUDE.md` のビルド/実行/テストコマンド欄を埋める
6. 変更点をまとめて提示する

一度に全部をヒアリングせず段階を踏む。**自動検出できることは検出し、分からないことだけ聞く**バランスを保つ。

## Step 1: プロジェクトを自動検出する

- `pubspec.yaml`（`dependencies` に `flutter: sdk: flutter` があればFlutter、無ければ純Dart。lockfileは `pubspec.lock`。`dependencies` と `dev_dependencies` の中身から、状態管理・コード生成などプロジェクトの性格を読み取る）
- `analysis_options.yaml`（`include:` 行がどのlintルールセットを使っているか——`flutter_lints` / `very_good_analysis` 等——まで読む）
- 対応プラットフォーム（`android/` `ios/` `web/` `macos/` `windows/` `linux/` のうちどれが存在するか。`.metadata` の `migration.platforms` と実際のディレクトリがずれていることがあるので、**ディレクトリの実在を正とする**）
- 既存の `.claude/` 配下（`settings.json`, `skills/`, `commands/`, `agents/`）と `CLAUDE.md` の有無・内容
- 既存の `.gitignore` の内容（Step 3で追記する際、重複させたり意図を無視して上書きしたりしないため）

Dart/Flutterは他スタックと検出のしかたが違う。`package.json` の `scripts` に相当する「コマンド定義欄」が `pubspec.yaml` に無く、**コマンドは規約で決まっている**（`flutter pub get` / `flutter analyze` / `flutter test`、純Dartなら `dart` に読み替え）。したがって pubspec.yaml の存在自体が実行コマンドの確定を意味するので、**ここはユーザーに聞かなくてよい**。

一方で「コマンドはあるが実際に動くか怪しい」状態は起こりうるので、黙って無視せずギャップとして扱う。典型例：

- `analysis_options.yaml` の `include:` が指すパッケージが `dev_dependencies` に無い → 解析自体が `include_file_not_found` で動かない
- lintパッケージが `dev_dependencies` ではなく `dependencies` に入っている → 動きはするがリリースビルドに不要な依存が乗る

`flutter doctor` を実行して環境側の欠落（Xcode未インストール、Android SDKライセンス未同意、接続デバイス無し等）も確認しておく。ここで見つけた欠落はStep 6で報告する——**`.claude/` のセットアップと開発環境の構築は別物**であり、このスキルは前者しか行わない。後者が欠けているなら、事実として伝える。

## Step 2: 対話で補完する

自動検出で埋まらなかった項目は AskUserQuestion などでユーザーに確認する。まとめて聞きすぎず、自然な流れで聞いていく。AskUserQuestionが使えない文脈（サブエージェント等）では通常の会話文で同じ内容を聞けばよい——手段より「ユーザーに確認する」目的を優先する。

「検出はできたが実際に動くか怪しい」項目は、ユーザーに直すよう強制する必要はない。気づいたことをStep 5のCLAUDE.mdやStep 6の報告で一言触れておけば十分——**プロジェクトの状態を偽って「動く」と書かないこと**が大事。

### 使うAIツールの確認

Claude Code以外のAIコーディングツール（Codex、Cursor等）も併用するかを確認する。併用する場合、`.claude/settings.json` のdenyやhookはそれらのツールでは**一切強制されない**（安全ルールはルート `AGENTS.md` 経由の指示ベースになる）ため、次の2点をセットアップに反映する：

- CI・ブランチ保護（Step 3の「GitHubを使う場合」）の優先度を一段上げる——ツールに依存しない唯一の強制層になるため、GitHubを使わない構成なら再考を促す
- 運用ルールをCLAUDE.mdに書くときは、安全に関わるものは `AGENTS.md` 側に書く（CLAUDE.mdはClaude Codeしか読まない。AGENTS.mdの冒頭に書かれた一本化の方針に従う）

Step 6の報告でも、Claude Codeと他ツールで守られる範囲が違うこと（READMEの「使うAIツールによる強制力の違い」）を必ず伝える。

### 繰り返し行う作業の洗い出し

リリースビルドの手順、特定フォーマットでのコードレビュー、コード生成（`build_runner`）を伴う定型作業、決まった構成のドキュメント生成など、**繰り返す作業**を聞き出す。挙がったら Skill / Command / Subagent のどれが自然かを判断する。判断は主体的に行ってよく、迷う場合だけ聞く。目安：

- **Command（`.claude/commands/*.md`）**: 1アクションで完結する定型操作。引数を受け取ってすぐ実行に移る、手続きが短くほぼ分岐のないもの。「/build-apk」「/gen」のようなショートカット向き。
- **Skill（`.claude/skills/*/SKILL.md`）**: 複数ステップにまたがる再利用可能なワークフロー。状況に応じた判断が必要だったり、スクリプトや参照資料を伴うもの。トリガー文言で自動発動してほしい場合もこちら。
- **Subagent（`.claude/agents/*.md`）**: 特定の役割に特化し、ツールセットを絞ったり別文脈で動かしたいもの。「コードレビュー専任」「リサーチ専任」など。

組み合わせても構わない（Skillの中からSubagentを呼ぶ等）。作りたいものが無ければスキップしてよい——使いもしない雛形を量産しても意味がない。

## Step 3: `.claude/settings.json` を作る/更新する

安全に許可してよいコマンドを `permissions.allow` に提案する。Flutterなら `Bash(flutter test:*)`, `Bash(flutter analyze:*)`, `Bash(flutter pub get:*)`, `Bash(flutter pub add:*)`, `Bash(dart format:*)` や、読み取り系のgitコマンド（`git status`, `git diff`, `git log` 等）のように、実行しても状態を壊さない・すぐ終わるコマンドを中心に許可する。破壊的な操作（`rm -rf`, `git push --force` など）は決して自動で許可リストに入れない。

`flutter run`（実機・エミュレータ・ブラウザ上でアプリを起動し続ける）のようにプロセスを常駐させるコマンドは、壊れはしないが「終了しないプロセスを勝手に立ち上げてよいか」という別種の判断が入るので、機械的に許可リストへ入れず、必要そうなら一言確認してから加える。

### deny ベースラインの扱い

`settings.json` には危険な操作（`rm -rf`, `git push --force`, `git reset --hard`, `git clean` 等）と秘密情報の読み取り（`.env`, 秘密鍵, `~/.ssh` 等）をブロックする `permissions.deny` のベースラインが入っている。さらに、permissionルールは前方一致でフラグ後置の変種（例: `git push origin main --force`）をすり抜けるため、コマンドをトークン解析してフラグ位置に関係なくブロックする `PreToolUse` hook（`.claude/hooks/deny_dangerous_bash.py`、回帰テスト同梱）も設定済み。

ベースラインは初期値であって聖域ではない。このブロックはエンジニアの正当なワークフロー（rebase後の `git push --force-with-lease`、実験を捨てる `git reset --hard`、`git clean` 等）とぶつかることがあるので、**ユーザーから明示的な依頼があれば、そのルールを外すと何が守れなくなるかを説明した上で個別に緩和してよい**。典型例: force-with-lease だけ許可したい → hookの `--force` 判定を「`--force-with-lease` は除外」に修正し、denyの `Bash(git push --force:*)` はそのまま残す（with-leaseはprefix不一致なので通る）。

緩和は**依頼されたルール単位**で行い、「邪魔だから」と一括で消さない。**セットアップの対話で先回りして緩和を提案する必要はない**——実際にブロックに当たってから調整すれば十分。

hookの検出パターンを変更した場合は `.claude/hooks/test_deny_dangerous_bash.py` のテストケースを更新し、`python3 .claude/hooks/test_deny_dangerous_bash.py` で回帰テストを必ず実行する（緩和した挙動も「ブロックされないこと」をテストとして固定する）。

### hooks とプラグイン

`hooks` はユーザーから明示的な要望（「コミット前に必ず `flutter analyze` を走らせたい」等）があれば追加し、無ければ触らない。要望のないhookを勝手に仕込むと意図しない動作を引き起こす。

既存の `settings.json` がある場合は中身を読み、上書きではなくマージする形で編集する。特に `enabledPlugins` のような既存フィールドを消さないよう注意する。

`enabledPlugins` の `"security-guidance@claude-plugins-official"`（編集時のパターン警告・ターン終了時のLLM差分レビュー・commit時のコードベース横断レビューの3層）と `"commit-commands@claude-plugins-official"`（`/commit` `/commit-push-pr` 等）は、判断を挟まず常に `true` にする。

GitHubでチーム開発をするかを確認し、する場合は `"github@claude-plugins-official"` と `"pr-review-toolkit@claude-plugins-official"` を `true` にする。個人開発でGitHubを使わない、PRレビューをClaude Codeに任せる予定が無い場合は無効のままでよい。

以下は検出結果から判断できるので、こちらで決めてよい（迷う場合だけ聞く）：

- **`context7@claude-plugins-official`**: バージョン固有の最新ドキュメントを取得する。`pubspec.yaml` の依存が一定数あるなら有効化してよい。Flutterはバージョン間の差異が大きいので基本的に有効。
- **`feature-dev@claude-plugins-official`**: 複数ファイル・複数レイヤーにまたがるアプリなら価値が高い。単一画面の習作程度なら見送ってよい。
- **`frontend-design@claude-plugins-official`**: React/Vue等のWebフロントエンド向けで、**Flutterのウィジェットツリーは対象外**。有効化しても使う場面が少ないので、Web版も併せて作るのでなければ無効のままでよい。

有効化した場合はStep 6で「何を・なぜ有効にしたか」を必ず報告する——ユーザーが把握しないまま静かに増えていくのが一番良くない。

### GitHubを使う場合: CI・依存メンテナンス・ブランチ保護

hookやセキュリティレビューのプラグインは「Claude Codeのセッションの中」でしか効かない。別環境やGitHub上での直接編集はすり抜けるので、リポジトリ側にも検査の層を作る。雛形と注意点は [references/ci-workflow-examples.md](references/ci-workflow-examples.md) を読んでから作業すること。やることは3つ：

1. **`.github/workflows/ci.yml` の生成**: Step 1で検出したコマンドからCIを作る。検出できていないコマンドを想像で書かない——初回から失敗し続けるCIは無いより悪い。スタックに依存しないシークレットスキャン（gitleaks）のジョブは常に入れる。あわせてGitHubのSecret scanning / Push protectionの有効化も案内する。
2. **`.github/dependabot.yml` の生成**: `package-ecosystem: "pub"` で依存の更新をPRとして届けさせる。届いたPRを誰がどう処理するかの運用文をStep 5でCLAUDE.mdに残す。
3. **ブランチ保護の案内**: CIを置いただけでは失敗しても取り込めてしまう。デフォルトブランチへの直push禁止とCI成功のマージ条件化を、GitHub UIの手順（または合意の上で `gh` CLI）で案内する。リポジトリ内のファイルでは完結しないので、案内した/できたかをStep 6の報告に含める。

既にCIが存在するなら重複して作らず、不足しているジョブの追加を提案する程度にとどめる。

### `.gitignore` の整備

- 技術スタックを問わず追加してよいもの: `.env` / `.env.*`（秘密情報の誤コミット防止）、`.DS_Store`（macOS）、`.claude/settings.local.json`（個人用のローカル設定であり、コミット対象の `.claude/settings.json` とは役割が違う）
- Dart/Flutter: `.dart_tool/`, `/build/`, `.flutter-plugins-dependencies`, `*.iml` / `.idea/`（JetBrains系IDEを使わない場合）。ただし **`flutter create` が生成する `.gitignore` にこれらは最初から含まれている**ので、実際には追記不要なことがほとんど——重複行を足す前に必ず既存の内容を確認する

既存の `.gitignore` に同じ内容がある行は重複させず、既存の記述は消さずに末尾へ追記する形でマージする。何を追加したかはStep 6の報告に含める。

## Step 4: 雛形ファイルを作成する

Step 2 で作ると決めたものについて雛形を作成する。雛形止まりにせず、対話で分かった具体的な手順や判断基準を可能な限り書き込む。中身が空の雛形は使われないまま放置される。

- Command: `.claude/commands/<name>.md`（frontmatterに `description`、本文に実行手順）
- Skill: `.claude/skills/<name>/SKILL.md`（frontmatterに `name` と `description`。`description` にはトリガー条件を具体的に書く）
- Subagent: `.claude/agents/<name>.md`（frontmatterに `name`, `description`, 必要なら `tools` の絞り込み）

**ストアへのリリース**に関わる雛形を作る場合は、次を本文に組み込む。モバイルアプリは公開後の取り消しが効かず、`applicationId` / bundle ID は変更するとストア上は別アプリ扱いになるため：

- 手順の冒頭に「`flutter analyze` と `flutter test` を実行し、失敗したらリリースを中止する」ステップを置く
- バージョン番号（`pubspec.yaml` の `version:`）の更新規則と、署名鍵の保管場所を明記する。**署名鍵を紛失するとアプリを更新できなくなる**ので、鍵そのものは絶対にリポジトリに入れない
- 「前のバージョンに戻す方法」（ストアの段階的リリース停止・以前のビルドの再有効化等）をユーザーから聞き出して明記する。壊れたときに参照されるのはこの記述と `safe-rollback` スキルなので、ここが空だと切り戻せない

## Step 5: `CLAUDE.md` を更新する

`CLAUDE.md` の以下のプレースホルダーを、Step 1・2で判明した内容で置き換える。すでに具体的な記述がある項目は上書きしない。

```
- **Build/run/test commands** — how to install dependencies, start the app, run tests, and lint
- **Architecture overview** — the high-level structure and how components interact
- **Key conventions** — any naming, formatting, or workflow rules specific to this project
```

Flutterでは Build/run/test は規約で決まっているので、`flutter pub get` / `flutter run -d <device>` / `flutter test` / `flutter analyze` をそのまま書けばよい。あわせて次を書くと後で効く：

- **採用しているlintルールセット**（`very_good_analysis` 等）と、意図的に無効化したルールがあればその理由
- **対応プラットフォーム**（Step 1で確認した実在ディレクトリ）。iOS対応が無いのに `flutter build ipa` を試みるような無駄を防ぐ
- コード生成を使っているなら `dart run build_runner build --delete-conflicting-outputs` の実行タイミング

アーキテクチャ概要やコンベンションまで踏み込むかは成熟度次第——コードがまだ無いなら無理に埋めず、分かる範囲（技術スタックの選定理由など）だけ書く。

## Step 6: 変更点をまとめて提示する

作成・変更したファイルの一覧と、それぞれの狙いを短くまとめて伝える。特にpermissionsやhooksなど動作に影響する変更は、何を許可したか明示する。有効化したプラグインは「何を・なぜ」を必ず含める。

Step 1で見つけた環境側の欠落（`flutter doctor` の警告、エミュレータ未作成等）があれば、**このスキルの範囲外であることを明示した上で**報告する。「セットアップ完了」とだけ伝えて実は `flutter run` できない、という状態を作らない。

あわせて、同梱の運用スキルの存在を紹介する。

- **`safe-rollback`**: 壊れたときに原因を自分で探さず「壊れたので戻したい」と伝えれば安全な手順で復旧する
- **`go-live-checklist`**: 「公開したい」と伝えれば公開前の監査が先に走る
- **`project-health-check`**: 「健康診断して」で依存更新・セキュリティアラート・CI失敗を棚卸しする
