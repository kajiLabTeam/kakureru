# CIワークフロー・依存メンテナンスの雛形集

claude-project-setupスキルのStep 3（GitHub利用時）で `.github/workflows/ci.yml` や `.github/dependabot.yml` を生成する際の参照テンプレート。**そのままコピーせず、Step 1で検出した実際のコマンド（lint/test/build）に必ず置き換える**こと。検出できていないコマンドをCIに書くと、初回から赤いバツが付き続けて「CIは壊れているのが普通」という最悪の学習をユーザーに与えてしまう。lintが無いならlintジョブを削る。

## 共通の方針

- トリガーは `pull_request` と `push`（デフォルトブランチ）の両方。PRを使わない運用でもpushで検査が走るようにする。
- ジョブは「lint」「test」「依存の脆弱性チェック」の3種を基本とし、検出できたものだけ入れる。加えて「シークレットスキャン」（後述）は技術スタックに依存しないので、**検出結果に関係なく常に入れる**。

## Dart / Flutter

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test
```

注意点：

- **`flutter analyze` は info レベルの指摘だけでも終了コード1を返す**（実測確認済み）。`--fatal-infos` を足す必要はない。逆に info では落としたくない場合に `--no-fatal-infos` を付ける。`very_good_analysis` のような厳しいルールセットを入れている場合、既存コードの指摘でCIが初回から真っ赤になることがあるので、導入時は先にローカルで `flutter analyze` を通してから有効化する
- `dart format --set-exit-if-changed` は整形漏れでCIを落とす指定。`flutter analyze` はフォーマットを見ないので、整形も強制したい場合のみ入れる
- 純Dartパッケージ（`pubspec.yaml` に `flutter: sdk: flutter` が無い）なら `subosito/flutter-action` ではなく `dart-lang/setup-dart@v1` を使い、コマンドを `dart pub get` / `dart analyze` / `dart test` に読み替える
- 上記はコード検査のみ。Android APK や iOS のビルドまでCIで行う場合は、Android なら `actions/setup-java` の追加、iOS なら `macos-latest` ランナー（課金が重い）と署名証明書の設定が別途必要になるので、必要になるまで入れない
- 依存の脆弱性チェックは Node の `npm audit` や Rust の `cargo audit` に相当する公式コマンドが pub には無い。Dependabot（後述）の `package-ecosystem: "pub"` に任せる

## シークレットスキャン（常に入れる）

security-guidanceプラグインは「Claudeがコードを書くとき」、go-live-checklistは「公開の直前」を見るが、人間がGitHub上で直接コミットした秘密情報を継続的に見張る層はCIにしか置けない。gitleaks CLI（MITライセンス・シークレット設定不要）をdockerで直接実行するジョブを `ci.yml` に追加する。

```yaml
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0        # コミット履歴全体を検査する
      - run: |
          docker run --rm -v "$GITHUB_WORKSPACE:/repo:ro" \
            ghcr.io/gitleaks/gitleaks:v8.30.1 \
            detect --source /repo --config /repo/.gitleaks.toml --redact -v
```

あわせて、リポジトリ直下に誤検知の許可リストとして `.gitleaks.toml` を置く。`--config` を付けずデフォルトルールのまま運用すると、誤検知が出たときに対処する手段が無く、CIが赤いまま放置される→そのうち「secret-scanのジョブを外そう」という誘惑につながる（安全網を弱める典型パターン）。

```toml
title = "gitleaks config"

[extend]
useDefault = true   # gitleaks同梱のデフォルト検出ルールを継承し、allowlistだけ追加する

[allowlist]
description = "誤検知として確認済みのパターン"
paths = [
  # 例: '''testdata/fixtures/.*''',
]
regexes = [
  # 例: '''EXAMPLE_PLACEHOLDER_[A-Z0-9]+''',
]
```

allowlistへの追記は、本物の秘密情報でないことを確認した場合のみに限ることをCLAUDE.mdの運用ルールに明記する。

注意点：

- **CLI直接実行を既定とする理由**: gitleaks-action（PRコメント等の便利機能付き）もあるが、v2以降は独自ライセンスで、**Organizationのリポジトリではライセンスキーの申請（無料だがフォーム送信が必要）と `GITLEAKS_LICENSE` シークレットの設定が要る**。設定ゼロで動くCLIを既定にする。個人アカウントのリポジトリでPRコメントが欲しい場合のみ `gitleaks/gitleaks-action@v2` への置き換えを検討する。
- **イメージは `ghcr.io/gitleaks/gitleaks` を使う（Docker Hubの `zricethezav/gitleaks` ではない）**: 同一イメージのミラーだが、Docker Hubは匿名pullをIPあたり100回/6時間に制限しており、GitHub Actions runnerの共有IPでは混雑時に失敗しうる。ghcr.ioはGitHub自身のレジストリで、Actionsからの匿名pullはこの制限を受けない。
- **バージョンはDependabotが追従しない**: `run:` 内のdocker image指定はDependabotの監視対象外なので、`project-health-check` スキルの定期点検で最新版との差を手動確認する運用にする。**更新前に配布元のライセンスが変わっていないかも確認する**（`gitleaks-action` がv2.0.0でMITから独自ライセンスに変わり、Organizationでの利用にライセンスキー登録を要求するようになった前例がある）。ライセンスが変わっていたら自動で追従せず、利用条件の変化をユーザーに伝えて判断を仰ぐ。
- イメージのバージョンはタグで固定し、`:latest` を使わない。`--redact` を付けて、検出した秘密情報の値そのものがCIログに出ないようにする。
- 検出があった場合にやるべきことは「履歴の掃除」より先に「**そのキーの無効化・再発行**」。この順序をCLAUDE.mdの運用ルールに書いておく（go-live-checklistのStep 2と同じ方針）。

あわせて、GitHub本体のシークレット防御も案内する（CIより手前で効く層）：

- **Secret scanning / Push protection**: リポジトリの Settings → Code security and analysis で有効化。秘密情報を含むpush自体をGitHub側が拒否してくれる。**公開リポジトリでは無料**。プライベートリポジトリでは GitHub Advanced Security（有料）が必要なので、契約が無ければ上のgitleaksジョブが実質的な代替になる——どちらが効いているかをStep 6の報告で明確にする。

## Dependabot（`.github/dependabot.yml`）

依存パッケージの脆弱性・更新を、誰も見ていなくてもGitHub側から自動でPRとして届けてくれる仕組み。Dart/Flutterのエコシステム名は `pub`。GitHub Actionsを使うなら `github-actions` のエントリも足しておくと、上のCIで使うaction自体の更新も追従できる。

```yaml
version: 2
updates:
  - package-ecosystem: npm          # 検出したエコシステムに置き換える
    directory: /
    schedule:
      interval: weekly
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```

## ブランチ保護（CIを「強制」に変える設定）

CIワークフローを置いただけでは「失敗しても取り込める」状態のまま。デフォルトブランチへの直pushを防ぎ、CI成功をマージ条件にするには、リポジトリ側の設定が必要になる。これはリポジトリ内のファイルでは完結しないので、次のどちらかを案内する。

- **GitHub UIから**: リポジトリの Settings → Rules → Rulesets で、デフォルトブランチを対象に「Require a pull request before merging」と「Require status checks to pass」（上のCIの `check` ジョブを指定）を有効にする。
- **gh CLIから**（ユーザーの合意を得てから実行する）:

```bash
gh api repos/{owner}/{repo}/rulesets -X POST --input - <<'EOF'
{
  "name": "protect-default-branch",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "pull_request", "parameters": { "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false, "require_last_push_approval": false, "required_review_thread_resolution": false } },
    { "type": "required_status_checks", "parameters": { "strict_required_status_checks_policy": false, "required_status_checks": [ { "context": "check" } ] } }
  ]
}
EOF
```

`required_approving_review_count` はチームに他のレビュアーがいるなら1以上に、1人開発なら0にする。無料プランのプライベートリポジトリではルールセット/ブランチ保護が使えない場合がある——その場合は設定できない事実を隠さず、「直pushをしない」を運用ルールとしてCLAUDE.mdに書くにとどめる。