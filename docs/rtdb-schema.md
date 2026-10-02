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
      endsAt              releasedAt + gameDurationSec（放出後から数える。issue #119）
      endedAt
      pendingDemonUid     ホストが指名した、鬼になる予定の人のuid（本人が受諾したらnullに戻す）
      demonRevokeUid      ホストが取り消した、鬼を辞めさせる予定の人のuid（本人が受諾したらnullに戻す）
    setting/
      gameArea            [{lat, lng}, ...] 3点以上
      releaseWaitSec
      gameDurationSec     鬼ごっこの時間（鬼放出後）。放出待ちの時間は含まない
      photoIntervalSec
      fugitiveInfoDelaySec  鬼の放出後、逃走者が鬼の位置を見られるまでの秒数（既定0＝すぐ見える）
      senseDistanceRadiusM
      meetingPointLat
      meetingPointLng
    users/
      {uid}/
        displayName
        role              "FUGITIVE" | "DEMON"
        pressureOffset
        pressureSensorAvailable  気圧センサーの有無(true/false)。判定前は未設定
        usesTethering     待機画面の「テザリングで接続している」の自己申告(true/false。未設定は**ON**扱い。参加者の多くがテザリング前提のため)。再戦でも保持する。下の「テザリングのホットスポットの除外」参照
        becameDemonAt
        lastPhotoAt
        joinedAt
        fcmToken
        online            false なら退出済み。未設定(古いデータ)は参加中扱い。下の「退出してもデータは消さない」参照
        leftAt            退出した時刻(ServerValue.timestamp)。入り直すと消える
    locations/
      {uid}/              高頻度更新。users と分離する
        lat
        lng
        altitude
        accuracy           GPSの測位精度(m)。悪い測位の足切り(issue #46)に使う
        pressure
        updatedAt
        wifiScan/          直近のWi-Fiスキャン結果（WifiScanRepositoryが書く）
          bssidRssi/       {bssid}: rssi。電波の強い上位40件だけを残す(自分のホットスポットは除いてから絞る)
          hotspotBssid     usesTethering がONの人だけが書く、接続中のWi-Fi(=自分のホットスポット)のBSSID(小文字)。未接続・取得できないときは無し
          scannedAt
    visible/
      {uid}/              Functions が書き出す派生データ
        {targetUid}/
          lat
          lng
          role
    catches/
      {catchId}/            鬼が「捕まえた」を押すと書く(下の「捕獲の流れ」参照)
        demonUserId         捕まえた鬼のuid
        fugitiveUserId      捕まった逃走者のuid
        caughtAt            ServerValue.timestamp。取り消しの期限はここから10秒
        catchPhotoId        捕まえた瞬間の写真のID(撮らなければ無し)
    catchPhotos/
      {photoId}/            捕まえた瞬間の写真。ルームの全員が見られる
        catchId             どの捕獲の写真か(catches/{catchId})
        demonUid            撮った鬼のuid
        fugitiveUid         捕まった逃走者のuid
        takenAt             ServerValue.timestamp。画像本体はR2の photos/{photoId}(足元写真と同じ置き場)
    photos/
      {photoId}/
        uid                 撮影者のuid
        takenAt             撮影時刻(ServerValue.timestamp)。画像本体はR2([docs/photo-storage.md](photo-storage.md)参照)
    sightings/
      {photoId}/            目撃写真(逃走者が撮った、見つけた鬼の写真)。ルームの全員がいつでも見られる(下の「目撃写真」参照)
        uid                 撮影者のuid
        takenAt             ServerValue.timestamp。画像本体はR2の photos/{photoId}(足元写真と同じ置き場)
        place               撮った場所の説明(任意)。作る仕組みはまだ無く、今は書かない。あれば表示だけする
    events/
      {pushKey}/          分析用のイベントログ。追記のみで上書きしない(下の「events」参照)
        type                "game_started" | "released" | "catch" | "catch_undone" | "became_demon" | "game_ended" | "photo_taken" | "mission_claimed"
        at                  ServerValue.timestamp
        uid                 出来事の主体のuid
        displayName         記録した時点の uid の表示名。users/{uid} が後から欠けても誰だったか辿れるようにする
        targetUid           相手のuid(無ければ省略)
        lat / lng           位置(あれば)
        accuracy            GPSの精度(m、あれば)
        pressure            気圧(hPa、あれば)
        indoor              屋内ならtrue(catchのみ)
    missions/
      {missionId}/          逃走者だけが受けるお題(アクセスポイント)。ホストの端末が書く(下の「ミッションとごほうび」参照)
        round               何回目か(1 = 放出から5分 / 2 = 放出から15分。3回目は無い)
        createdAt           ServerValue.timestamp
        expiresAt           作った時刻 + 制限時間(5分)。ホストのサーバー時刻の補正値から計算する
        finishedAt          すべての地点が取られて早く終わった時刻(サーバー時刻のミリ秒)。期限切れで終わったときは無し
        spots/
          {spotId}/         アクセスポイント1か所("s0", "s1", …)。数は鬼の人数 + 1、互いに50m以上離す
            lat / lng       地点
            radiusM         判定の半径(15)
            claimedBy       先に取った人のuid。未取得は無し。1地点に1人、1人1地点まで
            claimedAt       取った時刻(サーバー時刻のミリ秒)
            reward          取った人が引いたごほうび("block_clues" | "big_demon_icon" | "skip_foot_photo")。引く前は無し
    effects/
      {effectId}/           ごほうびの効果。引いた瞬間に1件足す(ルーム単位。キーは "{missionId}_{spotId}"。下の「ミッションとごほうび」参照)
        type                "block_clues" | "big_demon_icon" | "skip_foot_photo"
        byUid               引いた人のuid
        startedAt           発動した時刻(サーバー時刻のミリ秒)
        durationMs          効いている時間(30000)。skip_foot_photo は 0(回数もの)
        skipSlot            skip_foot_photo で飛ばす撮影スロットの番号(skip_foot_photo のみ。次の1回だけ)
    taunts/
      {tauntId}/            (予約。まだ書かない)逃走者から鬼への挑発
        fromUid             送った人のuid
        at                  ServerValue.timestamp

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
- `rooms/{roomId}` 自体には一括の `.read`/`.write` を付けない。RTDBのルールは上位ノードで許可すると下位ノードでの制限を上書きしてしまう（カスケードする）ため、`meta`/`setting`/`users`/`locations`/`visible`/`catches`/`catchPhotos`/`photos`/`events`/`sightings` それぞれに個別にルールを付けている
- `users/{uid}`・`locations/{uid}` は本人（`auth.uid === $uid`）以外は書き込み不可
- `visible/{uid}` はクライアント書き込みを禁止（Cloud Functions が Admin SDK 経由で書く想定）し、読み取りは本人のみ
- `roomCodes/{code}` は新規作成は誰でも可能だが、既存コードへの上書き・削除はそのルームのホスト（`meta/hostUserId` と `auth.uid` が一致する人）のみ
- `catches/{catchId}` と `catchPhotos/{photoId}` は、捕獲の当事者（鬼・捕まった逃走者）だけが書ける（下の「`catches` / `catchPhotos` のルール」参照）

`meta` / `setting` / `photos` / `sightings` の書き込みロジック（誰がホストか、誰が捕獲を報告できるか等）は、対応する Dart 側の実装が入ってから、その仕様に合わせてルールを絞り込むこと。それまでは認証済みなら誰でも読み書きできる暫定ルールになっている。

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

### 退出してもデータは消さない

プレイテスト(roomCode 5189)で、`events` / `photos` には6人分のuidがあるのに `users` / `locations` にはホストしか残っていなかった。原因は `RoomRepository.leaveRoom` が「ホームに戻る」・戻る操作・待機画面の破棄のたびに `users/{uid}` と `locations/{uid}` を `remove()` していたこと。アプリを閉じただけの人は破棄処理が走らないので残り、同じ試合でも残る人と消える人が出た(4371は全員残っていた)。さらに、消えた後に届いた `pressureSensorAvailable` の書き込みで `users/{uid}` が「`pressureSensorAvailable: true` だけ」のノードとして復活していた。

そのため現在は:

- `leaveRoom` は `users/{uid}` に `online: false` と `leftAt` を `update()` するだけで、`users/{uid}` / `locations/{uid}` を削除しない。`onDisconnect` は使っていない(使うとしても削除ではなく `online: false` を書く形にする)
- 画面側は `Room.fromMap` で `online == false` の人を参加者から除く。人数・結果画面・鬼の選出・「逃走者が残っているか」の判定から退出者が消える挙動は以前と同じ。入り直す(`joinRoom`)と `online: true` に戻り `leftAt` は消える
- `users/{uid}` への書き込みは `createRoom` / `joinRoom` / `reportSensorAvailability` とも `update()` で行い、ノードごと置き換える `set()` を使わない(先に書かれた `pressureOffset` 等を消さないため)。例外は `createRoom` 失敗時のロールバックだけ
- 退出者の `locations/{uid}`(最後の位置・Wi-Fiスキャン)は残る。消えないぶん古い値が残り続ける点に注意

**ルームの掃除方針(未実装)**: 退出で消さない代わりに、**作成から7日以上たったルームを `rooms/{roomId}` ごと(と対応する `roomCodes/{code}` を)削除する**。個々の `users/{uid}` を消すことはしない。実装はPhase 2のCloud Functions(Admin SDK)かスクリプトで行う予定で、現時点では何も消えない。

### テザリングのホットスポットの除外(issue #142)

SIMなしの研究室端末を各自のスマホのテザリングにつないで遊ぶと、自分のホットスポットが端末のすぐ横で常に最強のAPになる。さらに他の参加者のホットスポットも「人と一緒に動くAP」としてスキャンに入り、固定APを前提にしたWi-Fiの手がかり(近い/遠い・最寄り・メーター・電波の一致)がブレる。

- 待機画面のトグルがONの人(`users/{uid}/usesTethering` が `false` 以外。未設定はON扱いで、定義は `RoomUser` の `defaultUsesTethering`)だけ、`WifiScanRepository.sendScan` がスキャンのたびに接続中のBSSIDを読み、`wifiScan/hotspotBssid` として書く。自分の `bssidRssi` からもこのBSSIDを除いてから送る。ホットスポットのBSSIDはランダムMACで接続ごとに変わりうるため、固定のリストにはしない
  - `usesTethering` は購読せず、**スキャンのたびに読み直す**。購読だと、ゲーム開始直後の最初のスキャンが最初の値より先に届いたときにホットスポット入りのまま送ってしまうため。読めなければ直前の値を使う
  - 接続先が**ランダムMAC(ローカル管理ビットが立ったBSSID)でなければ共有しない**。ONのままテザリングが切れて構内Wi-Fiにつなぎ直った、わざとONにした、といった場合に固定APを全員の計算から消さないため。スマホのホットスポットはAndroid(10以降)もiPhoneもランダムMACを使う
  - 一瞬の切断などで1回取れなかっただけなら、直前に取れた `hotspotBssid` を送り続ける。OFFにしたら送らない
- 受け取る側は、`clueBssidRssiProvider`(`lib/features/wifi/clue_scans.dart` の `clueBssidRssiByUid`)で**退出していない参加者**の `hotspotBssid` を集め、全員のスキャンから除く。近い/遠い・最寄り・メーター・電波の一致はすべてこの結果から計算する。テザリングを使っていない人の端末でも除く。退出者の分を使わないのは、`locations/` が退出しても残るため(古い値がルームの続く限り残り続ける)
- 自動判定にしていないのは、構内Wi-Fiにつないでいる人の接続先が**固定AP**だから。接続先を一律に除くと、正規のAPを全員の比較から消してしまう
- 既定をONにしても、テザリングを使わない人に害は無い。構内Wi-Fiの固定APはランダムMACでないので共有されず、Wi-Fiに未接続なら接続先が取れない
- `hotspotBssid` が無い(旧バージョンの端末・OFFにした人)ときは何も除かず、従来どおりに動く

### オフライン永続化

`main.dart` で `Firebase.initializeApp` の直後、他のFirebase利用より前に `enableDatabasePersistence`(`lib/core/utils/database_persistence.dart`)を1回だけ呼び、`setPersistenceEnabled(true)` にしている。通信が切れている間の書き込みは端末に溜まり、再接続時に送られる。二重呼び出しは関数内のフラグで防いでいる。

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

### 捕獲の流れ: 鬼が書き、捕まった本人が役割を書き換える(issue #140)

以前は逃走者の自己申告(「鬼になる」)で `catches` を書いていたため `demonUserId` が特定できずnullだった。いまは鬼が「捕まえた」を押して書くので、`demonUserId` には必ず鬼のuidが入る(古いデータのnullは読み取り側で許容している)。

1. 鬼が「捕まえた」で相手と屋内/屋外を選び、撮影画面で**写真を撮った時点で** `RoomRepository.reportCatch` で `catches/{catchId}` を書く(撮らずに戻ったら何も書かず、選択からやり直す)。写真APIが未設定の環境では撮影画面を出さず、選択した時点で書く。`users/{uid}` は本人しか書けないため、逃走者の役割はここでは変えない
2. 捕まった本人の端末が `catches` を購読していて、自分宛ての捕獲を見つけたら `acceptCaught` で自分の `role` を `DEMON` にする(`useCaughtByDemon`)
3. 捕まった本人は `caughtAt` から10秒(`lib/features/room/catch_rules.dart` の `catchUndoWindow`)の間だけ `undoCatch` で取り消せる。**捕獲を先に消し、役割を後で `FUGITIVE` に戻す**(逆だと、戻った瞬間に残っている捕獲を見てまた鬼になる)。写真が付いていれば `catchPhotos/{photoId}` も消す。さらに削除がサーバーに届いた後、その `catchId` を指す `catchPhotos` を探し直して消す(下の「取り消しと写真送信の行き違い」参照)
4. 期限を過ぎた捕獲だけを、各端末が「AがBを捕まえた」と全員に知らせる。期限はサーバー時刻で判定する
5. 鬼が写真を撮って送ると、R2へ上げた後に `catchPhotos/{photoId}` を書き、`catches/{catchId}/catchPhotoId` をトランザクションで付ける。捕獲が既に取り消されていたら写真のメタデータを消して送信を失敗扱いにする

`restartRoom` は `catches` / `catchPhotos` を消さないので、読む側は必ず `meta/startedAt` 以降のものだけに絞る(`catchesOfCurrentGame`)。

### `catches` / `catchPhotos` のルール(issue #144)

鬼が他人の捕獲を書く形になったため、ルールで当事者以外の書き込みを塞いでいる。読み取りは従来どおり認証済みなら誰でも可。

| 操作 | 許可される条件 |
|---|---|
| `catches/{catchId}` の作成 | `demonUserId` が書き込む本人 / `caughtAt` がサーバー時刻(`now`) / `fugitiveUserId` が同じルームの `users` にいて本人ではない / 本人もそのルームの `users` にいる / その `catchId` がまだ無い / `catchPhotoId` を含まない |
| `catches/{catchId}` の削除(取り消し) | その捕獲の `demonUserId` か `fugitiveUserId` が本人 |
| `catches/{catchId}` の更新(写真の紐づけ) | その捕獲の `demonUserId` が本人で、`demonUserId` / `fugitiveUserId` / `caughtAt` が変わらない(実質 `catchPhotoId` だけ) |
| `catchPhotos/{photoId}` の作成 | `demonUid` が書き込む本人 / `takenAt` がサーバー時刻 / `fugitiveUid` が同じルームの `users` にいて本人ではない / 本人もそのルームの `users` にいる / その `photoId` がまだ無い |
| `catchPhotos/{photoId}` の削除 | その写真の `demonUid` か `fugitiveUid` が本人(`undoCatch` は捕まった側が消すため) |
| `catchPhotos/{photoId}` の更新 | 不可 |

- 項目は上のスキーマにあるものだけ。型(文字列・数値)と必須項目を `.validate` で確かめ、それ以外の子は拒否する
- **取り消しの期限(10秒)はルールでは判定しない**。ルールで時刻を比べると、端末とサーバーの時計のずれで正当な取り消しまで弾かれるため。期限はクライアント(`undoCatch` のサーバー時刻による確認)の責務
- 存在しない捕獲への「nullのまま」の書き込み(`attachCatchPhoto` のトランザクションが、取り消し済みの捕獲に対して確定する形)は許可している。これを拒否すると、取り消し済みの判定が権限エラーに化けるため
- `catchPhotos` の作成時に、対応する捕獲が存在するかは見ていない。見ると、取り消しと写真送信が行き違ったときに `CatchAlreadyUndoneException` ではなく権限エラーになるため(孤立レコードの扱いは下の「取り消しと写真送信の行き違い」)
- `undoCatch` は捕獲の削除を手元に先に反映するので、拒否が返る前に「あなたは鬼になった」の全画面が閉じる。そのため取り消しの実行と失敗のSnackBarは全画面ではなく `GamePage` 側(`useUndoCatch`)で行う

### 取り消しと写真送信の行き違い(issue #145)

`undoCatch` は「`catches/{catchId}/catchPhotoId` を読む → その写真と捕獲を消す」の順で動く。読んだ後・消す前に `attachCatchPhoto` が確定すると、そこで書かれた `catchPhotos` は削除の対象に入らず、捕獲だけが消えて写真のメタデータが取り残される。

**方針: 取り消しの後に探し直して消す**(issueの案A)。

- `undoCatch` は捕獲の削除がサーバーに届いた後、`catchPhotos` を1回読み、`catchId` がその捕獲で `fugitiveUid` が自分のものを消す(ルール上、捕まった側が消せるのは自分が当事者の写真だけ)
- これで取りこぼしは無い。削除より前に確定した `attachCatchPhoto` の写真は必ず読める。削除より後に来た `attachCatchPhoto` は、トランザクションで捕獲が無いのを見て自分で写真を消す
- `catchId` のインデックス(`.indexOn`)は付けず、一覧を読んで端末側で絞る。1ルームの捕獲写真は少なく、ルールの変更・デプロイを増やさないため
- 探し直しに失敗しても取り消しは成功扱いにする(取り消し自体は済んでいる)。残るのは画面に出ない小さなレコードだけで(写真一覧は `catchPhotosForGallery` が確定した捕獲の `catchId` で絞る)、画像本体はR2で7日後に消える。ルームごとの削除を実装するときに、まとめて片付く
- 捕獲の存在を `attachCatchPhoto` 側で同じトランザクション内に確かめる案(案B)は、`catchPhotos` と `catches` が別ノードで原子的に書けず、窓の短さに対して手間が見合わないため採らない

**確かめ方**: `rules-test/` に Firebase Local Emulator Suite で動かすテストがある(本番には触れない。Java と Node.js が要る)。

```sh
cd rules-test
npm install
npm test
```

ルールを変えたら、デプロイ(`firebase deploy --only database`)の前にこれを通すこと。

### 目撃写真: `sightings`

逃走者が鬼を見つけたときに撮って共有する写真。地図の右下のボタンから開くシートに、時系列のチャット風に並べる(足元写真の写真タブとは分ける)。

- 画像本体は足元写真と同じR2の `photos/{photoId}` に置き、圧縮も同じ(長辺1080px・画質80から、`pickCameraPhotoWithinLimit`)。足元写真(`photos`)・捕まえた瞬間(`catchPhotos`)との区別はこのメタデータの置き場所だけで行う
- 書き込みは画像のアップロードが成功した後に限る(`RoomRepository.addSighting`)。順序が逆だと、送れなかった写真が一覧に出るため
- 足元写真と違い、**撮ったかどうかに関係なくルームの全員(鬼も)がいつでも見られる**。撮れるのは逃走者だけ(画面側で「撮る」ボタンを逃走者にだけ出す。ルールでは絞っていない)
- `restartRoom` は `sightings` を消さないので、読む側は `meta/startedAt` 以降のものだけに絞る(`sightingsOfCurrentGame`、`lib/features/room/sighting_rules.dart`)
- `place` は任意。場所の文字列を作る仕組みはまだ無いので今は書かず、書かれていれば表示するだけ
- ルールは `photos` / `events` と同じ、認証済みなら読み書きできる暫定ルール。**`database.rules.json` をデプロイしないと読み書きできない**(ルートが `.read/.write: false` のため)

### ルーム設定画面: `setting` の書き込みはホスト限定になっていない

`setting` は現状 `auth != null` で誰でも書き込める暫定ルールのままなので、`RoomRepository.updateSetting` をホスト以外が呼んでも**権限エラーにはならない**。`meta`/`photos` と同じ「Dart側の実装が入ってから絞り込む」対象として先送りしてきた項目の一つ。

今回、ルーム設定画面を追加するにあたりルールを絞る案（`meta.hostUserId` と一致する人だけ `setting` を書けるようにする）も検討したが、鬼の決定のときと同じ理由（`meta.hostUserId` 自体が誰でも書き換えられるため、host限定ルールを足しても実効性が薄く権限昇格の抜け道になりうる）で見送った。代わりに、設定画面自体をホストにしか開かせない（`RoomWaitingPage` の「設定」ボタンをホストにのみ表示）というクライアント側の制御だけにしている。

**既知のリスク**: 改造クライアントを使えば、ホスト以外でも `setting` を書き換えられる。`meta.hostUserId` を書き込み不可・不変にするルールが入ったら、`setting`・`meta`・`pendingDemonUid` の host限定ルールをまとめて追加すること。

### `events`: プレイテスト分析用のイベントログ

ゲーム後に「最初の捕獲までの時間」「捕獲人数」「各逃走者が捕まるまでの時間」「屋内/屋外での捕獲回数」を、エクスポートしたJSONから手で集計するための追記専用ログ。書き込みは `EventLogRepository`(`lib/features/room/repository/event_log_repository.dart`)が fire-and-forget で行い、失敗してもゲーム進行は止めない。ルールは認証済みなら読み書き可の暫定ルール。

| type | 書く端末 | 記録するタイミング | uid |
|---|---|---|---|
| `game_started` | ホスト | `RoomRepository.startGame` 完了時 | ホスト |
| `released` | ホストのみ | `GameAlerts` が鬼放出を検知した時 | ホスト |
| `catch` | 捕まえた鬼 | 「捕まえた」のシートで相手と屋内/屋外を選び、`reportCatch` が成功した時 | 捕まえた鬼(`targetUid` は捕まった逃走者) |
| `catch_undone` | 捕まった本人 | 期限内に「取り消す」を押し、`undoCatch` が成功した時 | 取り消した逃走者(`targetUid` は捕まえた鬼) |
| `became_demon` | 指名された本人 | `acceptDemonNomination` で鬼になった時(開始前の初期鬼) | 鬼になった人 |
| `game_ended` | ホストのみ | `GameAlerts` がゲーム終了を検知した時 | ホスト |
| `photo_taken` | 撮影者 | 足元写真のアップロード成功時 | 撮影者 |
| `mission_claimed` | 取った逃走者 | アクセスポイントを先着で取れた時(`claimMission`) | 取った逃走者(引いたごほうびは `missions/{missionId}/spots/{spotId}/reward`) |

- `released` / `game_ended` は全端末で同じ判定が回るため、重複を避けてホスト端末だけが書く。`at` は「ホスト端末が検知した時刻」で、バックグラウンド等で遅れうる。正確な予定時刻は `meta/releasedAt` / `meta/endsAt` を使うこと。ホストのアプリが閉じていると記録されない
- `catch` の `lat`/`lng`/`accuracy` は、その時点で鬼が最後に送った `locations/{uid}` の値。`pressure` は端末の最新の気圧(取れなければ `locations/{uid}/pressure`)
- 各イベントには記録時点の `displayName` を入れる。呼び出し側が渡さなければ `users/{uid}/displayName` を読んで補い、読めなければ省く(イベント自体は記録する)
- `meta/endedAt` は `finishRoom` がどこからも呼ばれていないため現状書かれない。終了時刻は `game_ended` イベントか `meta/endsAt`(全員捕獲で早期終了した場合は最後の `catch`)から求める

### ミッションとごほうび(`missions` / `effects`)

逃走者だけが受けるお題(アクセスポイントへ行く)と、達成したときに引けるごほうび(鬼への妨害など)。

**ミッションはホストの端末が作る**(サーバーが無いため)。`MissionController`(`lib/features/mission/view_model/mission_view_model.dart`)が `GameAlerts` と同じく画面と無関係に1秒ごとに回り、ホスト(`meta/hostUserId`)の端末だけが `missionRoundToCreate`(`lib/features/mission/mission_rules.dart`)を見て書く。時刻の定数は `lib/features/mission/mission_timing.dart` に1か所にまとめてある。

- 鬼の放出(`releasedAt`)から5分で1回目、15分で2回目。3回目は無い。ゲームが先に終わったら2回目も出さない
- 同時に出すのは1件だけ。制限時間は5分。すべての地点が取られたらその場で終わる(`finishedAt`)
- 地点の数は鬼の人数 + 1。エリアの中からランダムに、互いに50m以上離して選ぶ
- ホストのアプリが落ちている間はミッションが出ない(ゲームは続く)
- 書いた直後に購読へ戻ってくるまでの二重書き込みは、端末側で5秒の間隔を置いて防いでいる。ホストが2台に増えることはない(`hostUserId` は1人)ので、ルールでの排他はしていない

**1地点に先着1人は `missions/{missionId}` への `runTransaction` で決める**(`MissionRepository.claimMission` → `claimSpotUpdate`)。`spots/{spotId}/claimedBy` が無く、期限内で終わっておらず、自分がまだ別の地点を取っていないときだけ自分のuidを入れる。すべて埋まったら同じトランザクションで `finishedAt` を入れる。RTDBはトランザクションをサーバーで直列にするため、2台が同じ地点を同時に押しても確定するのは1台だけで、遅れた方はサーバーの値で呼び直されて中止し「ほかの人に取られた」になる。取れた人だけがごほうびを抽選して `spots/{spotId}/reward` と `effects/{missionId}_{spotId}` を書く(`rooms/{roomId}` への一括書き込みはルール上できないので2回に分ける)。`claimedAt` と効果の `startedAt` は `ServerValue.timestamp` ではなくサーバー時刻の補正値で書く(トランザクションの中で使うと仮の値と確定値が食い違うため)。

- **ごほうびの書き込みは何度やり直しても1つにまとまる**: `reward` は「まだ無いときだけ書く」トランザクションで、既にあればそれを使う。効果はキーを地点ごとにして、同じく「まだ無いときだけ書く」。取り合いに勝った後、ごほうびを書く前に通信が切れたりアプリが落ちたりすると「取ったのに効果が出ない」状態になるが、カードに「ごほうびを受け取る」が出て(`claimedBy` が自分で `reward` が無いとき)、`MissionRepository.completeClaim` で受け取り直せる
- **到着はGPSで判定する**: いちばん近い空いている地点に対して、精度30m以内の読み取りで半径15m以内が2回続いたら「着いた」。精度が30mより悪ければ判定せず「GPSの電波が弱い」と出す
- **押す瞬間にも範囲内かを確かめる**: いまの読み取りで範囲の外に出ていたら引けない(`canClaimAccessPoint`)。GPSの精度が悪くなっただけなら引ける(ブレでボタンが消えないように)
- **お知らせは逃走者にだけ、音なし・振動だけ**: 出た・のこり1分・終わったの3種類(`dueMissionNotices`)。アプリを開いていれば画面上のバナー、閉じていればOSの通知(チャンネル `kakureru_mission`、`playSound: false`)
- **デバッグ用**: `flutter run --dart-define=DEBUG_MISSION=true` で起動したときだけ「着いたことにする」が出る(距離の判定だけ飛ばし、トランザクションはふつうに走る)。リリースビルドでは出ない

**効果はuidごとではなくルーム単位**に持つ。鬼に効く効果(`block_clues` / `big_demon_icon`)は全員の端末で同じ見え方にする必要があるため。`skip_foot_photo` だけは `byUid` の本人に効く。

- 残り時間は `startedAt + durationMs` から**サーバー時刻**で数える(端末の時計がずれていても全員の帯が揃う)
- `skip_foot_photo` は、引いた時点で撮影タイムが来ていてまだ撮っていなければ(撮影バナーが出ていれば)そのスロット、そうでなければ次のスロットを1回だけ飛ばす。**引いた瞬間に決めて `skipSlot` に書く**(`footPhotoSlotToSkip`)。読む側で `lastPhotoAt` から計算し直すと、引いた後に撮り直したときに飛ばす回が撮影済みのスロットへずれるため。飛ばしたスロットの写真一覧は、撮っていない扱いのままぼかしになる
- `block_clues` が効いている間、鬼の端末では手がかりカードとチップのWi-Fiの判定を隠し、最初に選ぶ相手も「Wi-Fiで最も近い相手」にしない(選ばれるチップで誰が近いかが分かってしまうため)
- `restartRoom` は `missions` / `effects` を消さないので、読む側は `meta/startedAt` 以降のものだけに絞る

**ルールは暫定**: `missions` / `effects` は `photos` / `events` と同じく認証済みなら誰でも読み書きできる。締め直し(`claimedBy` を一度しか書けなくする、`effects` を取った本人しか書けなくする等)は別のissueで行う。
