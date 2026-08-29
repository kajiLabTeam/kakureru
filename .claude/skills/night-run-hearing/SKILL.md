---
name: night-run-hearing
description: 夜間に人の確認なしでタスクを実装〜PR作成まで自律実行させたいときのヒアリング。「夜間実行して」「夜間タスクをお願い」「寝てる間に実装しておいて」「朝までにこれ終わらせておいて」「オーバーナイトで進めて」といった依頼で発動する。このSkillは対話で締切・タスクを確定してnight-run-state.jsonを書き出すところまでで、実際の自律実行(Dockerサンドボックス内でのコード実装・PR作成)はここでは行わない。
---

# night-run ヒアリング

night-run システム（`night-run/README.md`、設計書 `docs/night-run-design.md`）の対話フェーズ。目的は「何時まで・何を」を確定させ、`night-run/state/night-run-state.json` を書き出すことだけ。**実際の実装・PR作成はこのSkillの範囲外**（別途 `night-run/run.sh start` で起動するサンドボックスコンテナが行う）。この境界を崩さない——ここで実装作業に踏み込まない。

このSkill中の選択肢が2〜4個に絞れる質問（Step 3の依存解消方法、Step 5の最終確認など）は、自由文入力を求めずに `AskUserQuestion` ツールでクリック選択できる形で聞く。

## Step 1: 締切時刻を確認する

「何時まで作業してよいか」を聞く（「6時まで」のように時刻だけ言われる想定）。現在時刻から見て一番近い未来の該当時刻に変換する。手計算せず、Bashで確認する。

```sh
python3 - <<'EOF'
import datetime
from zoneinfo import ZoneInfo

jst = ZoneInfo("Asia/Tokyo")
now = datetime.datetime.now(jst)
hour = 6  # ユーザーが言った時刻に置き換える
candidate = now.replace(hour=hour, minute=0, second=0, microsecond=0)
if candidate <= now:
    candidate += datetime.timedelta(days=1)
print(candidate.isoformat())
EOF
```

変換結果を「〇月〇日 6:00までですね」と復唱して確認する。

続けて「締切を過ぎてから完走まで待つ猶予（バッファ）」を確認する。特に指定がなければ90分をデフォルトとして提案する。締切+バッファを `hard_limit` として、こちらも絶対時刻で確定させる（このシステムは実行中に都度計算し直さない。ここで確定した値をそのまま書き出す）。

## Step 2: タスクのissueを確認する

やってほしいタスクのGitHub issue番号またはURL（複数可）を聞く。タイトルしか分からない場合は `gh issue list --search "<キーワード>"` で探す。それぞれ `gh issue view <番号>` で実在確認し、内容(タイトル・本文)を読む。見つからないものはその場でユーザーに確認する（番号違い・未起票など。`github-task-intake` Skillで先に起票することを案内してもよい）。**ここで実在確認できなかったタスクは、実行フェーズには絶対に持ち越さない。**

## Step 3: タスク間の依存関係を確認する

「このタスクの変更が前提になる、他のタスクはありますか？」と確認する。依存ありと申告されたら、`AskUserQuestion` で以下のどちらかをその場で選んでもらい解消する（設計書7.2節）。**実行フェーズのタスクリストに未解決の依存を残さない。**

- **同じ夜にまとめて1ブランチで進める**: 依存する複数タスクを1つの実装単位（state上は1エントリ、PRも1つ）として扱う
- **別の夜に回す**: 依存先のタスクは今夜のリストに含めない（stateに書き出さない）

## Step 4: 内容を要約提示する

各タスクについて、issueの内容を要約してユーザーに提示する。

## Step 5: 実行確認

すべてを踏まえて `AskUserQuestion` で「この内容で実行してよいか」を最終確認する（選択肢: 実行する / 修正したい、など）。実行しない場合は該当ステップに戻ってやり直す。**「実行する」が選ばれるまでstateファイルは書き出さない。**

## Step 6: state ファイルを書き出す

`night-run/state/night-run-state.json` を以下のスキーマで書き出す（`night-run/state/` ディレクトリが無ければ作成する）。

```json
{
  "deadline": "2026-08-30T06:00:00+09:00",
  "hard_limit": "2026-08-30T07:30:00+09:00",
  "hard_limit_buffer_minutes": 90,
  "tasks": [
    { "title": "タスクA", "issue_url": "https://github.com/kajiLabTeam/kakureru/issues/12", "status": "pending", "branch": "night-run/2026-08-29/task-1" },
    { "title": "タスクB + タスクC(依存によりまとめて実施)", "issue_url": "https://github.com/kajiLabTeam/kakureru/issues/13", "status": "pending", "branch": "night-run/2026-08-29/task-2" }
  ]
}
```

- `issue_url` はStep 2で実在確認した実際のissue URLを入れる(タスクプロンプト側がタイトルの曖昧一致ではなく、この番号で直接`gh issue view`できるようにするため)。依存タスクをまとめた場合は、実装の起点となる方のissue URLを入れる
- `branch` はこの時点で確定させる。`night-run/<ヒアリング当日の日付YYYY-MM-DD>/task-<連番>` とする（日本語タイトルをそのままブランチ名にしない。ASCIIで一意にするため。日付を入れるのは、Dockerの作業ボリュームは夜をまたいで使い回す想定なので、`task-1`のような連番だけだと前回の夜のブランチ名と衝突しうるため）
- `status` は全タスク `"pending"` で書き出す
- `depends_on` フィールドは書かない（Step 3で解消済みのため）
- `hard_limit`・`deadline` は必ず絶対時刻(ISO8601)。ランタイム側では計算し直さない

書き出したら、このSkillの役目は終わり。**対話セッションはここで終了する**（実装作業には進まない）。

## Step 7: 次の手順を案内する

以下を案内して終える。実際にコンテナを起動するのは、ユーザー自身が明示的に行う一手として残す（このSkillからは起動しない）。

- 初回、または `night-run/` を直近で変更した場合は、**`night-run/` 一式が `main` にマージ済みか**を確認するよう伝える（`git_cleanup()` が毎回 `origin/main` に戻すため、マージされていないと次のタスクへ進む際に消える）
- 本番の締切で使うのが初めてなら、まず `night-run/README.md` のドライラン手順を一度通すよう案内する
- 準備ができたら `night-run/run.sh start` で起動すること、`night-run/run.sh logs` で経過を追えること、`night-run/state/night-run-state.json` と `night-run/state/alerts.log` はホストから直接読めることを伝える
