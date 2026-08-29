# night-run — 夜間自律タスク実行システム

`docs/night-run-design.md` に基づく実装。GitHub Issueのタスクを、人が寝ている間に実装〜PR作成まで自律的に進める。設計上の背景・未確定事項の解消方針は設計書と `AGENTS.md`/`CLAUDE.md` の安全ルールを参照。

タスクの起点はNotionではなくGitHub Issue（`.claude/skills/github-task-intake/`で起票）にしている。エンジニアのみで運用する前提なら、Notionの非対話認証（サーバー間トークン）を別途用意する手間がなく、`gh`のトークンをそのまま使い回せるため。

**このシステムは実在するリポジトリ（`kajiLabTeam/kakureru`）へ実際にPRを作成する。初回は必ずドライラン（下記）を通してから本番投入すること。**

## 全体の流れ

1. （ホスト・このMac、通常のClaude Codeセッション）`.claude/skills/night-run-hearing/` のヒアリングSkillで締切・タスクを確定し、`night-run/state/night-run-state.json` を書き出す
2. （ホスト）`night-run/run.sh start` でサンドボックスコンテナを起動する（この一手だけは人間が明示的に実行する）
3. （コンテナ内）`night_runner.py` がタスクを1件ずつ、クリーンな`claude -p`インスタンスで実装〜PR作成まで回す
4. 朝、`night-run/state/night-run-state.json` の各タスクの `status` と `night-run/state/summary.txt` を確認する

## 初回セットアップ

### 1. Dockerイメージのビルド

```sh
night-run/run.sh build
```

### 2. 認証情報の準備（ホスト側の環境変数。コミットしない）

`claude -p` の認証は次の**どちらか一方**でよい。

| 変数 | 用途 | 取得方法 |
|---|---|---|
| `ANTHROPIC_API_KEY` | コンテナ内の `claude -p` の認証(APIキー方式) | Anthropic Consoleで発行するAPIキー。従量課金でサブスクリプションとは別会計 |
| `CLAUDE_CODE_OAUTH_TOKEN` | コンテナ内の `claude -p` の認証(サブスクリプション方式) | `claude setup-token` で発行する長期トークン。追加の課金なしでサブスクリプションの利用枠を使う代わりに、**レート制限は人間の対話利用ペースを想定したものなので、1晩で複数タスクを回すと途中で制限に達しやすい**(その場合はnight_runner.pyのbackoffで数回リトライした上でそのタスクは`failed`として安全に終わる。締切までに終わらないタスクが出うる、という程度のリスク) |

`GH_TOKEN` は必須。

| 変数 | 用途 | 取得方法 |
|---|---|---|
| `GH_TOKEN` | `git push` / `gh pr create` / `gh issue view` の認証 | `kajiLabTeam/kakureru` への書き込み権限を持つGitHub Personal Access Token（`repo`スコープ）。ホストで既に`gh auth login`済みなら `gh auth token` の値をそのまま使ってもよい |

値はプロジェクトのファイルには書かない。ホームディレクトリなど**git管理外の場所**に環境変数ファイルを作り、使うたびに`source`する運用を推奨する(例: `~/.night-run-secrets.env`、`chmod 600`)。

```sh
# ~/.night-run-secrets.env (例)
export CLAUDE_CODE_OAUTH_TOKEN="..."   # または ANTHROPIC_API_KEY
export GH_TOKEN="..."
```

```sh
source ~/.night-run-secrets.env && night-run/run.sh start
```

### 3. ホスト側で `gh` を使えるようにする（ヒアリングSkill・起票Skill用）

`.claude/skills/night-run-hearing/`（issue実在確認）と `.claude/skills/github-task-intake/`（issue起票）は、コンテナの外・このホストの通常セッションで動く。ホストにも `gh` CLI がインストール・認証済みである必要がある。

```sh
brew install gh
gh auth login
```

### 4. 一度、night-run一式を `main` にマージする

`night_runner.py` はタスクの合間に `git reset --hard origin/main` する（`git_cleanup()`）。**このリポジトリ自身がその対象なので、`night-run/` 一式が `main` に入っていないと、次のタスクへ進む際に消えてしまう。** 初回は普通のPRフローでこのディレクトリ一式を `main` にマージしてから使うこと。

## ドライラン（本番投入前に必須）

設計書9.6節。締切を数分後に短縮し、軽量なタスク（既存コードの小さな修正）1件で通しで動かす。

1. ヒアリングSkillを実行する際、「何時まで」の質問に対して**現在時刻から5〜10分後**を答える
2. タスクは1件、既存コードの小さな修正など軽量なものにする
3. `night-run/run.sh start` → `night-run/run.sh logs` で経過を見る
4. 確認すること:
   - `init-firewall.sh` の自己検証（`example.com`拒否/`api.github.com`許可）が通ること
   - ソフトカットオフ（新規タスク非着手）とハードリミット（強制終了）が期待通りのタイミングで効くこと
   - 締切超過時に診断用ブランチが作られ、`night-run-state.json`の該当タスクが`failed`になり、draft PRの本文にTODOプレースホルダーではなく実際の進捗が入っていること
   - 正常完走した場合、`gh pr view`での実在確認（9.8節）を経て`done`になっていること
5. 問題があれば該当箇所を直し、もう一度ドライランする。**通るまで本番の締切・タスクでは実行しない**

## 本番実行

```sh
# 1. ヒアリングSkillで night-run/state/night-run-state.json を作る(このセッションで会話する)
# 2. 起動
night-run/run.sh start
# 3. 経過を見る(閉じてもコンテナは動き続ける)
night-run/run.sh logs
# 途中経過はホストから直接読める(bind mountされているため)
cat night-run/state/night-run-state.json
tail -f night-run/state/alerts.log
```

止めたいときは `night-run/run.sh stop`。**進行中のタスクは中断され、`done`にならない**（次に`run.sh start`し直すとstateの`pending`/`in_progress`から再開を試みるが、`in_progress`のまま止まったタスクは`main()`が拾わないので、手動で`status`を`pending`に戻すか診断ブランチの内容を確認してから判断すること — 常駐化・自動復旧は今回のスコープ外）。

## スコープ外（今回は実装していない）

- esa用MCPサーバー（設計書7章、任意扱い）
- `night_runner.py`自体の常駐化・クラッシュ時の自動再起動（設計書9.1節）。`run.sh start`はターミナルを閉じても動き続けるが、コンテナやホストが落ちた場合の自動復旧はない
- Slack Webhook等への実際の通知送信（`notify_human()`に拡張ポイントだけ用意。今は `alerts.log` への追記のみ）

## トラブルシュート

- **タスク中に`flutter pub get`が失敗する**: 新しいパッケージを追加するタスクで、そのパッケージの配信元CDNのIPが`init-firewall.sh`の許可リストにない可能性がある。`pub.dev`/`storage.googleapis.com`のIPは起動時に一度だけ解決しており、実行中にIPが変わると通信がブロックされうる（この方式の既知の制約）。`night-run/run.sh stop && night-run/run.sh rm && night-run/run.sh start`でコンテナを作り直す（`init-firewall.sh`が再実行されIPを再解決する）
- **`gh pr create`/`gh issue view`が権限エラーで失敗する**: `GH_TOKEN`のスコープ（`repo`。issueの読み書きも含まれる）と対象リポジトリへの権限を確認する
- **コンテナがすぐ落ちる**: `night-run/run.sh logs`で`[init-firewall]`のFATALログを確認する。ネットワーク許可リストの設定ミスであることが多い
