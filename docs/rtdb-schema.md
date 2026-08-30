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
        leftAt              離脱時刻(ソフト離脱)。nullなら在室中。詳細は下記
        fcmToken
    locations/
      {uid}/              高頻度更新。users と分離する
        lat
        lng
        altitude
        pressure
        updatedAt
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
        userId
        storagePath
        submittedAt

roomCodes/
  {code}/                 4桁コード → roomId の逆引き
    roomId
    createdAt
```

## 設計の意図

- **離脱は `users/{uid}` を消さず `leftAt` を立てるだけのソフト離脱**にしている。同じuid(同じ端末、匿名認証はアンインストールしない限りuidが保持される)で5分以内に再度 `joinRoom` すれば、role等の状態を維持したまま復帰できる（issue #11の追加要望）。5分を過ぎた場合や別端末での参加は、通常の新規参加として上書きされる。`leftAt` を過ぎても自動削除はしない（次の参加時の上書き、またはルーム終了まで残る）
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

**Phase 1 の間の既知の制約**: 削除処理が無いため、遊び終わったあとも `roomCodes/{code}` が残り続ける。4桁コードは10000通りしかないので、開発中に何度もルームを作り直していると枯渇しうる。Phase 2 実装までは、開発中に溜まった `roomCodes` / `rooms` を手動（Firebase Console）または簡単なクリーンアップスクリプトで消す運用が必要。

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

### `catches/{catchId}/demonUserId` はnull許容

逃走者の自己申告（「捕まった」ボタン）で記録する `catches` には、誰が捕まえたか（`demonUserId`）を確実には特定できない。Phase 1では「捕まえた鬼を選択させるUI」は作らず、`demonUserId: null` を許容する形にした。捕獲した鬼を明示的に記録したくなったら、選択UIを別途追加すること。

### ルーム設定画面: `setting` の書き込みはホスト限定になっていない

`setting` は現状 `auth != null` で誰でも書き込める暫定ルールのままなので、`RoomRepository.updateSetting` をホスト以外が呼んでも**権限エラーにはならない**。`meta`/`catches`/`photos` と同じ「Dart側の実装が入ってから絞り込む」対象として先送りしてきた項目の一つ。

今回、ルーム設定画面を追加するにあたりルールを絞る案（`meta.hostUserId` と一致する人だけ `setting` を書けるようにする）も検討したが、鬼の決定のときと同じ理由（`meta.hostUserId` 自体が誰でも書き換えられるため、host限定ルールを足しても実効性が薄く権限昇格の抜け道になりうる）で見送った。代わりに、設定画面自体をホストにしか開かせない（`RoomWaitingPage` の「設定」ボタンをホストにのみ表示）というクライアント側の制御だけにしている。

**既知のリスク**: 改造クライアントを使えば、ホスト以外でも `setting` を書き換えられる。`meta.hostUserId` を書き込み不可・不変にするルールが入ったら、`setting`・`meta`・`pendingDemonUid` の host限定ルールをまとめて追加すること。


