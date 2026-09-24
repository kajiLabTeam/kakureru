# Firebase Realtime Database スキーマ

kakureru のデータ構造。実装時はこの構造に合わせ、対応する Dart のモデルは Freezed で定義する（[AGENTS.md](../AGENTS.md) の規約）。

## 構造

```
rooms/
  {roomId}/
    meta/
      status              "WAITING" | "PLAYING" | "FINISHED"
      hostUserId
      roomCode
      basePressure        ホストの気圧（キャリブレーション基準）
      createdAt
      startedAt           サーバー時刻で確定
      releasedAt          startedAt + releaseWaitSec
      endsAt              startedAt + gameDurationSec
      endedAt
      pendingDemonUid     ホストが指名した、鬼になる予定の人のuid（本人が受諾したらnullに戻す）
      demonRevokeUid      ホストが取り消した、鬼を辞めさせる予定の人のuid（本人が受諾したらnullに戻す）
    setting/
      gameArea            [{lat, lng}, ...] 3点以上
      releaseWaitSec
      gameDurationSec
      photoIntervalSec
      fugitiveInfoDelaySec
      senseDistanceRadiusM
      meetingPointLat
      meetingPointLng
    users/
      {uid}/
        displayName
        role              "FUGITIVE" | "DEMON"
        pressureOffset
        pressureSensorAvailable  気圧センサーの有無(true/false)。判定前は未設定
        becameDemonAt
        lastPhotoAt
        joinedAt
        fcmToken
    locations/
      {uid}/              高頻度更新。users と分離する
        lat
        lng
        altitude
        accuracy           GPSの測位精度(m)。悪い測位の足切り(issue #46)に使う
        pressure
        updatedAt
        wifiScan/          直近のWi-Fiスキャン結果（WifiScanRepositoryが書く）
          bssidRssi/       {bssid}: rssi。電波の強い上位40件だけを残す
          scannedAt
    visible/
      {uid}/              Functions が書き出す派生データ
        {targetUid}/
          lat
          lng
          role
    catches/
      {catchId}/
        demonUserId
        fugitiveUserId
        caughtAt
    photos/
      {photoId}/
        uid                 撮影者のuid
        takenAt             撮影時刻(ServerValue.timestamp)。画像本体はR2([docs/photo-storage.md](photo-storage.md)参照)

roomCodes/
  {code}/                 4桁コード → roomId の逆引き
    roomId
    createdAt
```

## 設計の意図

- **`locations/` を `users/` から分離**しているのは更新頻度が違うため。位置は数秒おきに書き換わるが、プロフィールやロールはほとんど変わらない。同じノードに混ぜると、購読側が不要な再描画を強いられる
- **`visible/` は Cloud Functions が書き出す派生データ**。クライアントに `locations/` 全体を読ませず、「その人が見てよい相手の位置」だけを配る。距離判定をクライアント側でやると、改造クライアントが生の位置を全部読めてしまうため
- **`startedAt` はサーバー時刻で確定**させる。端末時計のずれでカウントダウンが人によって異なるのを防ぐ
- **`roomCodes/` は逆引き専用**。4桁コードから `roomId` を引くためだけに存在し、ルーム本体とは別ツリーに置く

## Security Rules

ルールは `database.rules.json`（リポジトリ直下）で管理し、`firebase deploy --only database` でデプロイする。コンソール上で直接編集しない（差分がレビューできなくなるため）。

現状のルールは、この設計意図のうち既に決まっている部分だけを反映している:

- 全体のデフォルトは `auth != null`（未認証アクセスは拒否）。認証は起動時の匿名サインイン（`lib/main.dart`）が前提
- `rooms/{roomId}` 自体には一括の `.read`/`.write` を付けない。RTDBのルールは上位ノードで許可すると下位ノードでの制限を上書きしてしまう（カスケードする）ため、`meta`/`setting`/`users`/`locations`/`visible`/`catches`/`photos` それぞれに個別にルールを付けている
- `users/{uid}`・`locations/{uid}` は本人（`auth.uid === $uid`）以外は書き込み不可
- `visible/{uid}` はクライアント書き込みを禁止（Cloud Functions が Admin SDK 経由で書く想定）し、読み取りは本人のみ
- `roomCodes/{code}` は新規作成は誰でも可能だが、既存コードへの上書き・削除はそのルームのホスト（`meta/hostUserId` と `auth.uid` が一致する人）のみ

`meta` / `setting` / `catches` / `photos` の書き込みロジック（誰がホストか、誰が捕獲を報告できるか等）は、対応する Dart 側の実装が入ってから、その仕様に合わせてルールを絞り込むこと。それまでは認証済みなら誰でも読み書きできる暫定ルールになっている。

APIキー自体はアクセス制御に使われない（プロジェクトを識別するだけ）ため、ここでの Security Rules と、Google Cloud Console 側のAPIキー制限（アプリ制限・API制限）の両方が必須。

### 一括書き込み・一括読み取りが使えない理由

RTDBの `.read`/`.write` 権限は、**アクセス先のパス自身か、その祖先にルールが無いと許可されない**。子ノードに個別ルールを付けていても、それは子ノードへ直接アクセスする場合にしか効かず、親への一括アクセスを救済してはくれない。

`rooms/{roomId}` 自体には `.read`/`.write` を付けていない（`meta`/`setting`/`users`/…にだけ個別に付けている、上の「カスケードする」の項参照）。そのため:

- `rooms/{roomId}` へ `set()`/`update()` で `{meta: {...}, setting: {...}, users: {...}}` のように複数の子を一括で書き込む操作は、`meta`/`setting`/`users/{uid}` それぞれに書き込み権限があっても**必ず権限エラーになる**（実際に本番環境で検証済み）
- 同様に `rooms/{roomId}` を丸ごと読み取る操作（一括GET・`onValue` を room直下に張る等）も**必ず権限エラーになる**（データがある/ないに関わらず、検証済み）

これはカスケードバグ修正（`rooms/{roomId}` 直下の一括 `.read`/`.write` を撤去したこと）の意図した副作用であり、バグではない。子ごとに権限を絞った結果として、子ごとに個別アクセスする以外の手段が塞がれている。

**実装への影響**: `rooms/{roomId}` 配下を扱うコードは、`meta` / `setting` / `users/{uid}` を必ず個別のパスで読み書きする。
- 書き込み: `RoomRepository.createRoom` は `rooms/{roomId}/meta` → `setting` → `users/{uid}` の順で個別に `set()` する（`roomCodes` のホスト限定ルールが `meta/hostUserId` を参照するため、`meta` を最初に確定させる）
- 読み取り: `RoomRepository.watchRoom` は `meta` / `setting` / `users` を個別に `onValue` 購読し、クライアント側で `Room` に合成する

### ルーム終了(解散)は Phase 1 ではステータス変更のみ

ホストが解散時に他ユーザーの `users/{uid}` を削除できるようにルールを緩めることは行わない。`users/{uid}` の書き込みを本人以外にも許可すると、`role` や `pressureOffset` を第三者が書き換えられる穴になるため。

そのため `RoomRepository.finishRoom` は `meta/status` を `"FINISHED"` にし `meta/endedAt` を記録するだけで、`users` / `setting` / それ以外の `meta` / `roomCodes` の実データは削除しない。これらの削除は **Phase 2 の `finishGame` Cloud Function**（Admin SDK でルールをバイパスして全参加者分をまとめて消せる）に任せる。

**参加時のガード**: 残り続けるコードで終わった部屋に入ってしまわないよう、`RoomRepository.joinRoom` は `roomCodes/{code}` を引いた後に `rooms/{roomId}/meta` を読み、(1) `meta` が無い（ルームだけ手動削除された等）なら `notFound`、(2) そのルームが終了済みなら `finished` として参加させない。終了したかどうかの判定は画面側と同じ `isGameOver`（`status` が `"FINISHED"` / `endsAt` を過ぎた / `PLAYING` 中に逃走者が0人）に任せる——判定をここで書き直すと、片方だけ条件が増えたときに「画面では終わっているのに参加できる」ズレが生まれるため。`finishRoom` はまだどこからも呼ばれておらず、遊び終えた部屋は `status` が `"PLAYING"` のままなので、実際に効くのは残り2つ（時間切れ・全員捕まった）である。逃走者の有無を見るために `PLAYING` のときだけ `rooms/{roomId}/users` も読む。なおこのガードは完全な保証ではない: 読み取りから `users/{uid}` の書き込みまでの間に最後の逃走者が捕まるレースは残る（`rooms/{roomId}` をまたぐ原子的な読み書きが上記の理由でできないため）。

**Phase 1 の間の既知の制約**: 削除処理が無いため、遊び終わったあとも `roomCodes/{code}` が残り続ける。4桁コードは9000通り(1000〜9999)しかないので、開発中に何度もルームを作り直していると枯渇しうる。Phase 2 実装までは、開発中に溜まった `roomCodes` / `rooms` を手動（Firebase Console）または簡単なクリーンアップスクリプトで消す運用が必要。

### Phase 1 の暫定措置: `locations/` をルームメンバーに開放

Phase 1 は Cloud Functions を使わずクライアント側だけで実装する方針のため、`visible/` に書き込む主体（本来は Cloud Functions）が存在しない。`visible/` 方式を厳密に適用すると、鬼と逃走者が互いの位置を確認できる must 機能自体が実装不能になる。

そのため `locations/{uid}` の読み取りを「本人のみ」ではなく「そのルームの `users/{auth.uid}` が存在する（=同じルームのメンバーである）」に緩めている:

```
"locations": {
  ".read": "auth != null && root.child('rooms').child($roomId).child('users').child(auth.uid).exists()"
}
```

**既知のリスク**: 位置の公開範囲（`senseDistanceRadiusM` による距離制限、`fugitiveInfoDelaySec` による解禁タイミング）はクライアント側のロジックでしか制御されていない。ルール上は同室メンバーであれば誰でも `locations/` の生データを即座に読めるため、改造クライアントを使えば、本来まだ見えないはずの相手の位置（解禁前・射程外）を読み取れてしまう。正規のアプリ経由なら見えないが、ルールとしては防げていない。

**Phase 3 で `visible/` 方式へ切り替える予定**。Cloud Functions が距離・解禁タイミングを判定して `visible/{uid}/{targetUid}` にだけ書き出すようになったら、`locations/{uid}` の `.read` は再び「本人のみ」に戻し、`locations/` への直接アクセスをクライアントから完全に断つこと。

### 鬼の決定: `meta/pendingDemonUid` 経由の自己申告方式

`users/{uid}` は本人以外書き込み不可のため、ホストが他人の `role` を直接書き換えることはできない（試すと権限エラーになる）。対応として以下の2案を検討した:

- **案A**: `users/{uid}/role` にだけホスト書き込みを許可するルールを追加する
- **案B**（採用）: ホストは `meta/pendingDemonUid` に指名先のuidを書くだけにし、指名された本人が自分で `role` を `"DEMON"` に更新して `pendingDemonUid` をクリアする

案Aを見送った理由: `meta` 自体が現状 `auth != null` で誰でも書ける暫定ルールのままなので、`meta/hostUserId` も誰でも書き換えられる。この状態で「ホストなら他人の`role`を書ける」ルールを足すと、参加者が先に `hostUserId` を自分に書き換えてから他人の `role` を書き換えられてしまう（権限昇格）。`hostUserId` を書き込み不可・不変にするルールとセットならAも安全にできるが、それは別のルール設計判断になるため、Phase 1では「本人しか自分の`role`を書けない」という既存の制約を一切崩さない案Bを採用した。

**既知のトレードオフ**: 指名された本人のアプリがその瞬間バックグラウンド等で `meta` の変化を受け取れないと、`pendingDemonUid` が一時的に残ったままになる(セキュリティ上の問題ではなく、単なる反映待ちの遅延)。

**取り消しと受諾のレース対策**: ホストの `cancelDemonNomination`(`pendingDemonUid` への素の `set(null)`)と、本人の `acceptDemonNomination` は別々のリクエストなので、素の読み取り→書き込みだと「本人が受諾処理を始めた直後にホストが取り消す」と、取り消しは `pendingDemonUid` に反映されても `role` が `DEMON` のまま取り残されるレースがあった。`acceptDemonNomination` は `pendingDemonUid` への `runTransaction` で「読んだ時点の値が依然自分のuidであるときだけ `null` に書き換える」を原子的に行い、それが成立した(=取り消しや指名し直しに割り込まれていない)場合だけ `role` を書くことでこれを防いでいる。この経路はRTDBのトランザクション機構自体に依存するため、リポジトリ内にエミュレータ/モック環境が無く自動テストでは検証できない(手動確認方法は実装コメント参照)。

### 鬼の取り消し: `meta/demonRevokeUid` 経由の自己申告方式(issue #60)

指名を受諾済み(`role == "DEMON"`)になった後で、ホストがその指名を取り消したい(逃走者へ戻したい)場合も、`users/{uid}` を本人以外書けない制約は変わらないため、`pendingDemonUid` と対になる同じ自己申告方式を使う: ホストは `meta/demonRevokeUid` に対象者のuidを書くだけにし(`RoomRepository.revokeDemon`)、対象者本人が自分で `role` を `"FUGITIVE"` に戻し `becameDemonAt` をクリアして `demonRevokeUid` をクリアする(`RoomRepository.acceptDemonRevoke`。`RoomWaitingPage` の該当 `useEffect` 参照)。

`pendingDemonUid`(受諾前の指名の取り消し)と `demonRevokeUid`(受諾後の取り消し)はフィールドも操作も別なので、`RoomWaitingPage` のホスト向けチップは対象者の `role` で経路を分けている: まだ `DEMON` になっていなければ `pendingDemonUid` 側の「取り消す」(`cancelDemonNomination`)、既に `DEMON` なら `demonRevokeUid` 側の「取り消す」(`revokeDemon`)。

### 「同じメンバーでもう一回」(`RoomRepository.restartRoom`)

ゲーム終了画面のホストが同じ部屋で再戦するときの巻き戻し。新規ノードは追加せず、既存フィールドを次のように書き戻す:

- `meta/status` を `WAITING` に戻し、`startedAt` / `releasedAt` / `endsAt` / `endedAt` / `pendingDemonUid` / `demonRevokeUid` をクリアする(すべて `restartRoom` が `rooms/{roomId}/meta` への1回の `update` でまとめて書く)
- 各参加者の `role` を `FUGITIVE` に、`becameDemonAt` をクリアする

保持する(書き換えない)のは `setting` 配下すべてと、各参加者の `pressureOffset` / `pressureSensorAvailable`。参加者自体も退室させない。

`role`/`becameDemonAt` のリセットを `restartRoom` に含めなかったのは、鬼の決定と同じ制約のため: `users/{uid}` は本人しか書き込めないルールなので、ホストが他の参加者の `role` をまとめて書き換えることはできない。代わりに、各端末が `roomStreamProvider` で観測した `status` が `WAITING` になっていることを検知し、自分の役割が鬼だった場合にだけ `resetOwnRoleForRestart` で自分の `role`/`becameDemonAt` を書き戻す(`lib/features/room/restart_recovery.dart` の `useRestartRecovery`)。

この検知はホストが結果画面(`GameResultPage`)にいる間だけでなく `GamePage` からも行う。ホストが「同じメンバーでもう一回」を押した瞬間、他の参加者はまだ `isGameOver` を検知できておらず `GamePage` に留まっている場合がある(バックグラウンド化・ネットワーク遅延等)ため、結果画面を経由できなかった端末も待機画面に戻せるようにするため。

判定は「`PLAYING` から `WAITING` への変化」という**遷移ベースではなく、「いま `WAITING` である」という状態ベース**(`useEffect`)で行う。`ref.listen` は `fireImmediately` を付けない限り登録後の変化にしか反応しないため、遷移ベースだと「`endsAt` 到達で `GameResultPage` をマウントした直後にホストが再戦を押し、最初に受け取るスナップショットが既に `WAITING`」「一時的な切断で `roomStreamProvider`(autoDispose)が再購読された」「バックグラウンドから復帰した」といったケースで永久に発火しなくなる。`GamePage`/`GameResultPage` はどちらも開始済みのゲームからしか到達しないため、そこで `WAITING` を観測するのは巻き戻し以外にあり得ず、状態ベースでも誤検知しない。同じ罠は `RoomWaitingPage` の遷移・鬼指名受諾でも一度踏んでおり(`room_waiting_page.dart` の `useEffect` のコメント参照)、書き方を揃えてある。

**既知の残存リスク**: `GamePage`/`GameResultPage`のどちらも開いていない端末(アプリを完全に閉じている、プロセスが切られている等)は、この検知自体が実行されないため、巻き戻り後も`role`が`DEMON`のまま残り続ける。状態ベースにしたことで「後からアプリを開いて結果画面/ゲーム画面に着地した」場合は救えるようになったが、巻き戻り後に直接 `RoomWaitingPage` へ入り直した端末は依然として取りこぼす。

この取りこぼしは、**同じ「オフライン端末の取りこぼし」でも鬼の決定(`pendingDemonUid` 自己申告方式)のそれとは復旧可能性が全く違う**ので注意すること:

- 鬼決定の取りこぼし → `pendingDemonUid` が残るだけで `role` は変わらない。待機画面に「鬼が1人も指名されていません」(`room_waiting_page.dart`)が出て、ホストが「取り消す」「鬼にする」で指名し直せる。つまり**異常が見えるし直せる**。
- 巻き戻しの取りこぼし → 参加者Pが `DEMON` のまま残る。このとき:
  - `demonCount == 1` になるため `hasStartableRoleComposition(demonCount: 1, totalUserCount: n) == true` となり、「ゲーム開始」が**警告も出ないまま押せてしまう**。キャリブレーション結果(`basePressure` / `pressureOffset`)は仕様どおり保持されるので `allCalibrated` も真になり、**部屋は完全に正常に見える**。その状態で次戦が始まり、鬼役のPは自分が鬼だと知らない(そもそもアプリを開いていない)。
  - ホスト向けの操作チップは、既に `DEMON` の参加者にも `demonRevokeUid` 経由の「取り消す」を表示するようになった(issue #60。上記「鬼の取り消し」参照)ため、ホストがこの状態に気付けば手動で逃走者へ戻せる。ただし**「正当に指名された鬼」と「前ラウンドの残骸」をUI側が自動で見分けているわけではない**(見分ける手段が無い問題自体は次段落で述べる通り未解決)。参加者一覧が「鬼が1人だけ・警告なし」に見えている以上、ホストが疑わなければこの取り消しボタンを押す理由もなく、気付かなければ従来通り取りこぼされる。
  - ホストが気付かずに別の人を「鬼にする」と、鬼が2人の状態で始まる。

つまり「部屋が正常に見えたまま壊れた状態で次戦が始まり、ホストが気付けば直せるが、気付く手がかりが無い」という実害になる(issue #60でホスト側の修正手段自体は解消したが、検知手段が無い問題は残る)。

`RoomWaitingPage` 側で「巻き戻し後に自分が `DEMON` のまま残っている」ケースを自己修復させる案も検討したが、現状は**「正当に指名された鬼」と「前ラウンドの残骸」を区別する手段が無い**ため見送った: `acceptDemonNomination` の直後も `status == WAITING` かつ `role == DEMON` かつ `pendingDemonUid == null` で、残骸と全く同じ状態になる。無条件に自分を `FUGITIVE` へ戻す実装は、正当に指名された鬼を毎回逃走者へ戻してしまい取りこぼしより有害。区別するには `meta/roundId`(または `restartRoom` が書く `meta/restartedAt` + `acceptDemonNomination` が書く `becameDemonAt` の突き合わせ。現状 `acceptDemonNomination` は `becameDemonAt` を書いていないので初期鬼を取りこぼす)の導入が必要で、これはスキーマ追加になる。

根本的に直すには `meta/roundId` の導入か、Cloud Functions側でのロールリセット(Phase 2以降)が必要。Phase 1の「Cloud Functionsを使わずクライアント側だけで実装する」という既存方針(このファイル冒頭「Phase 1の暫定措置」参照)のもとでは、上記の実害を許容している。

### `catches/{catchId}/demonUserId` はnull許容

逃走者の自己申告（「捕まった」ボタン）で記録する `catches` には、誰が捕まえたか（`demonUserId`）を確実には特定できない。Phase 1では「捕まえた鬼を選択させるUI」は作らず、`demonUserId: null` を許容する形にした。捕獲した鬼を明示的に記録したくなったら、選択UIを別途追加すること。

### ルーム設定画面: `setting` の書き込みはホスト限定になっていない

`setting` は現状 `auth != null` で誰でも書き込める暫定ルールのままなので、`RoomRepository.updateSetting` をホスト以外が呼んでも**権限エラーにはならない**。`meta`/`catches`/`photos` と同じ「Dart側の実装が入ってから絞り込む」対象として先送りしてきた項目の一つ。

今回、ルーム設定画面を追加するにあたりルールを絞る案（`meta.hostUserId` と一致する人だけ `setting` を書けるようにする）も検討したが、鬼の決定のときと同じ理由（`meta.hostUserId` 自体が誰でも書き換えられるため、host限定ルールを足しても実効性が薄く権限昇格の抜け道になりうる）で見送った。代わりに、設定画面自体をホストにしか開かせない（`RoomWaitingPage` の「設定」ボタンをホストにのみ表示）というクライアント側の制御だけにしている。

**既知のリスク**: 改造クライアントを使えば、ホスト以外でも `setting` を書き換えられる。`meta.hostUserId` を書き込み不可・不変にするルールが入ったら、`setting`・`meta`・`pendingDemonUid` の host限定ルールをまとめて追加すること。


