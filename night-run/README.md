# night-run — 夜間自律タスク実行システム

`docs/night-run-design.md` に基づく実装。GitHub Issueのタスクを、人が寝ている間に実装〜PR作成まで自律的に進める。設計上の背景・未確定事項の解消方針は設計書と `AGENTS.md`/`CLAUDE.md` の安全ルールを参照。

タスクの起点はNotionではなくGitHub Issue（`.claude/skills/github-task-intake/`で起票）にしている。エンジニアのみで運用する前提なら、Notionの非対話認証（サーバー間トークン）を別途用意する手間がなく、`gh`のトークンをそのまま使い回せるため。

**このシステムは実在するリポジトリ（`kajiLabTeam/kakureru`）へ実際にPRを作成する。初回は必ずドライラン（下記）を通してから本番投入すること。**

## 使い方（日常運用）

night-runは3つのSkillと1つのスクリプトの組み合わせ。**コマンドを覚える必要はなく、日本語で自然に頼めば発動する。**

| 場面 | 使うもの |
|---|---|
| 直したい/作りたいことを思いついたとき | 「issueを起票して」→ `github-task-intake` Skillが観点を確認しながらissue化する |
| その日確定したissueをまとめて夜間に回したいとき | 「夜間実行して、6時まで」→ `night-run-hearing` Skillが対象issue・締切を確認 → `night-run/run.sh start`で起動 |
| 実行中/翌朝に様子を見たいとき | 「night-runどうなってる」→ `night-run-status` Skillが完了/失敗/draft PRを棚卸しして報告 |

1サイクルの例:

1. 「issueを起票して。○○の不具合を直したい」 → Engineer/PM/PO/Designer(該当すればGame Designer)の観点を確認しながらissueが作られる
2. issueが十分たまったら「夜間実行して、6時まで」 → 対象issueと締切を確認 → 承認すると`night-run/run.sh start`で起動(コンテナはターミナルを閉じても動き続ける)
3. 翌朝「night-runどうなってる」 → 各issueの結果(done/failed)とPR URLが出る。**draft PRは必ず人間がレビューしてからマージする**(自動マージはしない設計)

## 初回セットアップ（メンバーごとに1回）

night-runは**メンバーごとに個別の認証情報**を使う(誰が実行したかがgit/GitHub側の記録に残る)。以下をそれぞれ自分のマシンで行う。

### 1. `gh` CLIのインストール・認証

```sh
brew install gh
gh auth login
```

これでヒアリング・起票Skill(ホスト側で動く部分)が使えるようになる。

### 2. Dockerイメージのビルド（初回、以後は`night-run/`が更新されたら都度）

```sh
night-run/run.sh build
```

### 3. 夜間実行(コンテナ内の`claude -p`)用の認証トークンを用意する

**方式A: サブスクリプションのトークンを使う(追加課金なし。個人のPro/Max等がある場合)**

```sh
claude setup-token
```

ブラウザでの認証後、長期トークンが表示される。これを`CLAUDE_CODE_OAUTH_TOKEN`として使う。**サブスクリプションの枠は対話利用と共有で、しかも夜間実行の1タスクは人間の数十プロンプト分に相当する**。特にProは5時間ローリング枠+週次上限が厳しく、無制限に回すと翌日の対話利用分まで使い切る。そのため既定では「sonnet・effort medium・**1タスク60分/$8で頭打ち**」に制限してある(タスク数そのものは締切まで無制限。下の「Pro契約での運用」参照)。枠に当たったタスクは`failed`ではなく**持ち越し(pendingのまま)**になり、次回の実行がそのまま続きを再開する。

**方式B: APIキーを使う（[Anthropic Console](https://console.anthropic.com/)で発行、従量課金）**

`ANTHROPIC_API_KEY`として使う。方式A/Bはどちらか一方でよい。

### 4. 秘密情報ファイルを作る(プロジェクトの外・git管理外)

```sh
cat > ~/.night-run-secrets.env <<'EOF'
export CLAUDE_CODE_OAUTH_TOKEN="上で発行した値"   # または export ANTHROPIC_API_KEY="..."
export GH_TOKEN="$(gh auth token)"
EOF
chmod 600 ~/.night-run-secrets.env
```

`GH_TOKEN`は`gh auth login`済みのトークンをそのまま流用している(`repo`スコープがあればOK。専用の絞ったPATを別途発行してもよい)。

以後、night-runを使うときは毎回このファイルを`source`する:

```sh
source ~/.night-run-secrets.env && night-run/run.sh start
```

### 5. 一度、night-run一式を `main` にマージする

`night_runner.py` はタスクの合間に `git reset --hard origin/main` する（`git_cleanup()`）。**このリポジトリ自身がその対象なので、`night-run/` 一式が `main` に入っていないと、次のタスクへ進む際に消えてしまう。** 初回は普通のPRフローでこのディレクトリ一式を `main` にマージしてから使うこと(このメッセージが読めている時点で、この手順は既に済んでいるはず)。

## ドライラン（`night-run/`本体に手を入れたら再実施）

2026-08-30に一度実施済み(issue #12、締切10分後・軽量タスク1件で完走・draft PR #18を確認)。`night-run/`配下のスクリプト自体を変更したときは、以下の手順でもう一度確認すること。設計書9.6節。

0. `night-run/run.sh build` でイメージを作り直す(`night-run/docker/`配下——特にCLIのバージョン——を変えた場合は必須)
1. ヒアリングSkillを実行する際、「何時まで」の質問に対して**現在時刻から5〜10分後**を答える
2. タスクは1件、既存コードの小さな修正など軽量なものにする
3. `night-run/run.sh start` → `night-run/run.sh logs` で経過を見る
4. 確認すること:
   - 起動ログに `night-run開始: model=sonnet / effort=medium / ...` が出ること(モデル・effortが意図した値になっているか)
   - `このCLIは --effort に対応していない` という警告が出ていないこと(出ていたらイメージのCLIが古い)
   - `init-firewall.sh` の自己検証（`example.com`拒否/`api.github.com`許可）が通ること
   - ソフトカットオフ（新規タスク非着手）とハードリミット（強制終了）が期待通りのタイミングで効くこと
   - 締切超過時に診断用ブランチが作られ、`night-run-state.json`の該当タスクが`failed`になり、draft PRの本文にTODOプレースホルダーではなく実際の進捗が入っていること
   - 正常完走した場合、`gh pr view`での実在確認（9.8節）を経て`done`になっていること
5. 問題があれば該当箇所を直し、もう一度ドライランする。**通るまで本番の締切・タスクでは実行しない**

## Pro契約での運用(消費量の設定)

night-runの1タスクは、`claude -p`のセッションを実装〜レビュー〜PR作成まで走らせる(2026-09-13の実績で1タスクあたり6〜32分)。**Claude Proの枠は対話利用と共有**なので、上限なしで回すと一晩で使い切る。既定値はProを基準に置いてある。

方針は「**夜は締切まで使い切ってよい。ただし1タスクが夜を丸ごと食わないようにする**」。タスク数に上限は置かず、1タスク単位で時間と金額の両方を頭打ちにしている。

| 設定 | 既定値 | 意味 |
|---|---|---|
| `model` | `sonnet` | 使用モデル。**ProにOpusは含まれない**。CLIの既定任せにすると契約・CLIバージョンによって変わるため明示する |
| `effort` | `medium` | 1リクエストあたりの思考量(`low`/`medium`/`high`/`xhigh`/`max`) |
| `autocompact` | `150k` | 文脈がこの大きさを超えたら要約へ置き換える(`auto`、または100k〜1M。空で指定しない)。1タスクは最大60分走るので、放っておくと文脈が伸び続け、その全部を毎リクエスト読み直すことになる |
| `reviewer_model` | (空) | reviewerサブエージェントのモデル。空なら実装と同じモデルを継承する |
| `max_tasks_per_run` | `0`(無制限) | 1回の実行で着手するタスク数。締切(`deadline`)まで回し続ける。件数で抑えたい場合だけ指定する |
| `max_review_rounds` | `2` | reviewerサイクルの最大ラウンド数。ここに到達したらdraft PRで打ち切る |
| **`max_task_minutes`** | **`60`** | **1タスクの実行時間上限**。超えたらそのタスクだけ打ち切ってdraft PRへ退避し、次のタスクへ進む(0で無制限) |
| `max_budget_usd_per_task` | `8` | `claude -p --max-budget-usd` に渡す値(0で指定しない) |
| `max_total_budget_usd` | `50` | 実行全体の上限。暴走時のバックストップで、通常は届かない(0で無制限) |

**「1タスクで全部使わせない」を金額だけに頼らないこと。** サブスクリプション認証ではコストが報告されないことがあり、その場合`total_cost_usd`は記録されず`--max-budget-usd`も`max_total_budget_usd`も効かない。**サブスクで確実に効くのは`max_task_minutes`(時間)** で、これがあるから1タスクの実行時間は必ず有限になる(この上限を入れるまでは、1タスクのタイムアウトが「締切までの残り全部」だったため、重いタスク1件がその夜を丸ごと使えた)。

打ち切られたタスクは`failed`(`failure_reason: task_time_cap_exceeded`)になり、作業は退避ブランチとdraft PRに残る。**レートリミットによる持ち越し(下記)とは別物**で、こちらは人が中身を見て続けるか判断する。

### 設定の書き場所と優先順位

`環境変数 > state の "limits" > 既定値` の順で解決する。通常はヒアリングSkillが契約プランに応じて`night-run-state.json`へ書き出すので、手で設定する必要はない。

```json
{
  "deadline": "2026-09-16T06:00:00+09:00",
  "hard_limit": "2026-09-16T07:30:00+09:00",
  "limits": { "model": "sonnet", "effort": "medium", "autocompact": "150k",
              "max_tasks_per_run": 0,
              "max_review_rounds": 2, "max_task_minutes": 60,
              "max_budget_usd_per_task": 8, "max_total_budget_usd": 50 },
  "tasks": [ ... ]
}
```

その場限りで上書きしたいときだけ環境変数を使う(`NIGHT_RUN_MODEL` / `NIGHT_RUN_EFFORT` / `NIGHT_RUN_AUTOCOMPACT` / `NIGHT_RUN_REVIEWER_MODEL` / `NIGHT_RUN_MAX_TASKS` / `NIGHT_RUN_MAX_REVIEW_ROUNDS` / `NIGHT_RUN_MAX_TASK_MINUTES` / `NIGHT_RUN_MAX_BUDGET_USD` / `NIGHT_RUN_MAX_TOTAL_BUDGET_USD`)。例:

```sh
source ~/.night-run-secrets.env && NIGHT_RUN_MAX_TASKS=1 night-run/run.sh start
```

**環境変数はstateの設定より強い**。`run.sh`/`entrypoint.sh`は「ホスト側で明示的にexportされている変数だけ」をコンテナへ渡すので、シェルに残った古い値が黙って効くことはない(渡した場合は起動ログに出る)。

### 枠に当たったときの挙動(持ち越し)

レートリミットを検知すると、まず解除時刻をエラー本文から読む(`Claude AI usage limit reached|<epoch>` 形式やISO8601)。

- **解除時刻が分かり、締切までに実作業の時間(15分以上)が残る** → その時刻+2分まで待って再開する
- **解除が締切より後 / 時刻が読めずbackoffの回数上限に達した** → **待たずに持ち越す**

持ち越したタスクは`failed`ではなく`status: "pending"`のまま残り、`deferred_reason`・`deferred_at`・`rate_limit_reset_at`が記録される。作業途中は診断ブランチへ退避され、次回の実行では`build_prompt`の再開ノートからそのブランチを参照して続きから進む。**翌晩は`night-run/run.sh start`をそのまま実行すればよい**(`--retry-failed`は不要。あれは本当に失敗したタスク用)。

持ち越しが発生した時点でその回の実行は終了する(枠が空いていないのに次のタスクへ進んでも同じところで止まるだけのため)。

### 1回の実行の結果

実行の終わりに`night-run-state.json`へ`run_summary`が書かれ、`summary.txt`にも出る。

```
完了: 2件 / 失敗: 0件 / 持ち越し: 1件 / 未着手: 3件
今回の実行: 3件に着手 / 消費 $7.20 / 終了理由: レートリミットのため中断しました。...
設定: model=sonnet / effort=medium / reviewer=実装と同じモデル / 1回のタスク数上限=無制限 / 1タスク60分 / ...
```

## コマンド早見表

```sh
source ~/.night-run-secrets.env && night-run/run.sh start   # 起動
night-run/run.sh logs                                       # ログを追う(閉じてもコンテナは動き続ける)
cat night-run/state/night-run-state.json                    # 途中経過(ホストから直接読める)
tail -f night-run/state/alerts.log                          # 異常があればここに出る
```

止めたいときは `night-run/run.sh stop`。**進行中のタスクは中断され、`done`にならない**（次に`run.sh start`し直すとstateの`pending`/`in_progress`から再開を試みるが、`in_progress`のまま止まったタスクは`main()`が拾わないので、手動で`status`を`pending`に戻すか診断ブランチの内容を確認してから判断すること — 常駐化・自動復旧は今回のスコープ外）。

## state ファイルのタスクエントリ

`night-run-state.json` の `tasks[]` 各要素は、実行が進むにつれてフィールドが増えていく。主なもの:

| フィールド | 内容 |
|---|---|
| `title` / `issue_url` | タスク名・起点issue |
| `status` | `pending` / `in_progress` / `done` / `failed` |
| `branch` / `step` / `review_round` | 作業ブランチと進捗段階(`update_step.py`が書く) |
| `pr_status` / `pr_url` | `done`時の最終ステータス(`success`=ready / `draft`)とPR URL |
| `completed_summary` / `remaining_summary` | タスク側の自己申告サマリ |
| `failure_reason` / `diagnostic_branch` | `failed`時の理由と退避ブランチ(持ち越し時も退避ブランチは記録される) |
| `deferred_reason` / `deferred_at` / `rate_limit_reset_at` | レートリミットで次回へ持ち越したときの理由・時刻・枠の解除予定時刻。`status`は`pending`のまま。done/failedに達した時点で消える |
| `total_cost_usd` | そのタスクで発生した`claude -p`の全試行(リトライを含む)のコスト(USD)の累積合計 |
| `usage` | 同、トークン使用量の累積合計(input/output/cacheの内訳を含む`usage`オブジェクト。キーごとに数値を合算) |

`total_cost_usd`/`usage`は成功(`done`)・失敗(`failed`)(レートリミットで`MAX_RETRY_ATTEMPTS`回リトライしても解消せずgive-upした場合を含む)どちらの経路でも、`claude -p`の出力(envelope)がJSONとしてパースできた場合は記録される。**JSON自体が壊れていてenvelopeが取れなかった場合はその試行分は記録されない**(パース前なのでコストの実額が分からないため)。`total_cost_usd`が数値でない・`usage`がオブジェクトでないなど値の型が不正な場合も、例外にはせず単にその試行分の記録をスキップする。

**リトライをまたいだ累積**: レートリミットでbackoffリトライが発生した場合、各試行が完了するたびにその試行のコスト/usageを直ちに加算し、ディスクへ保存する。そのため`total_cost_usd`/`usage`はタスク全体(打ち切られて捨てられた試行を含む)で実際に使われた総コストに一致する(以前は最後に完了した試行1回分しか記録せず、途中のリトライがTIMEOUT/hard_limitで打ち切られると直前の試行のコストごと失われる問題があったため、リトライのたびに逐次加算・保存する方式に変更した)。この値は`status`を手動で`pending`に戻して同じタスクを再実行した場合もリセットされず、前回までの実行分に上乗せされていく(そのタスクに実際に費やした総コストを知るという目的には合致するが、「再実行後の増分だけ」を見たい場合は前回終了時点の値を別途控えておくこと)。

### stateのトップレベル

| フィールド | 内容 |
|---|---|
| `deadline` / `hard_limit` / `hard_limit_buffer_minutes` | 締切とバッファ(ヒアリング時に確定した絶対時刻) |
| `limits` | 消費量の設定(上の「Pro契約での運用」参照)。省略時は既定値 |
| `run_summary` | 直近の実行の結果。`tasks_started` / `spent_usd`(その実行で増えた分) / `stopped_reason` / `limits_description` |
| `last_updated` | 最終更新時刻(`save_state`が自動で入れる) |

## スコープ外（今回は実装していない）

- esa用MCPサーバー（設計書7章、任意扱い）
- `night_runner.py`自体の常駐化・クラッシュ時の自動再起動（設計書9.1節）。`run.sh start`はターミナルを閉じても動き続けるが、コンテナやホストが落ちた場合の自動復旧はない
- Slack Webhook等への実際の通知送信（`notify_human()`に拡張ポイントだけ用意。今は `alerts.log` への追記のみ）

## トラブルシュート

- **タスク中に`flutter pub get`が失敗する**: 新しいパッケージを追加するタスクで、そのパッケージの配信元CDNのIPが`init-firewall.sh`の許可リストにない可能性がある。`pub.dev`/`storage.googleapis.com`のIPは起動時に一度だけ解決しており、実行中にIPが変わると通信がブロックされうる（この方式の既知の制約）。`night-run/run.sh stop && night-run/run.sh rm && night-run/run.sh start`でコンテナを作り直す（`init-firewall.sh`が再実行されIPを再解決する）
- **朝になってもタスクが`pending`のまま残っている**: 異常ではなく、締切到達・レートリミットでの持ち越し・上限到達のいずれか。`night-run/state/summary.txt`の「終了理由」を見る。続きをやらせたいときは`night-run/run.sh start`をそのまま実行する(`--retry-failed`は不要)。**Proの枠は対話利用と共有なので、夜に使い切った分だけ翌日の自分の作業が止まりやすくなる**点は承知の上で運用すること
- **1タスクが`task_time_cap_exceeded`で失敗している**: 1タスクの実行時間上限(既定60分)に達した。draft PRと退避ブランチに途中までの作業が残っているので中身を確認する。そのタスクが本来重い(複数issueをまとめた等)なら`limits`の`max_task_minutes`を上げるか、issueを分割する
- **`gh pr create`/`gh issue view`が権限エラーで失敗する**: `GH_TOKEN`のスコープ（`repo`。issueの読み書きも含まれる）と対象リポジトリへの権限を確認する
- **コンテナがすぐ落ちる**: `night-run/run.sh logs`で`[init-firewall]`のFATALログを確認する。ネットワーク許可リストの設定ミスであることが多い
