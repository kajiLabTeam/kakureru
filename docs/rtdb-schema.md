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
        becameDemonAt
        lastPhotoAt
        joinedAt
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

- **`locations/` を `users/` から分離**しているのは更新頻度が違うため。位置は数秒おきに書き換わるが、プロフィールやロールはほとんど変わらない。同じノードに混ぜると、購読側が不要な再描画を強いられる
- **`visible/` は Cloud Functions が書き出す派生データ**。クライアントに `locations/` 全体を読ませず、「その人が見てよい相手の位置」だけを配る。距離判定をクライアント側でやると、改造クライアントが生の位置を全部読めてしまうため
- **`startedAt` はサーバー時刻で確定**させる。端末時計のずれでカウントダウンが人によって異なるのを防ぐ
- **`roomCodes/` は逆引き専用**。4桁コードから `roomId` を引くためだけに存在し、ルーム本体とは別ツリーに置く

## Security Rules

ルールは `database.rules.json`（リポジトリ直下）で管理し、`firebase deploy --only database` でデプロイする。コンソール上で直接編集しない（差分がレビューできなくなるため）。

現状のルールは、この設計意図のうち既に決まっている部分だけを反映している:

- 全体のデフォルトは `auth != null`（未認証アクセスは拒否）。認証は起動時の匿名サインイン（`lib/main.dart`）が前提
- `users/{uid}`・`locations/{uid}` は本人（`auth.uid === $uid`）以外は書き込み不可
- `visible/{uid}` はクライアント書き込みを禁止（Cloud Functions が Admin SDK 経由で書く想定）し、読み取りは本人のみ

`meta` / `setting` / `catches` / `photos` の書き込みロジック（誰がホストか、誰が捕獲を報告できるか等）は、対応する Dart 側の実装が入ってから、その仕様に合わせてルールを絞り込むこと。それまでは `rooms/{roomId}` 配下は認証済みなら誰でも読み書きできる暫定ルールになっている。

APIキー自体はアクセス制御に使われない（プロジェクトを識別するだけ）ため、ここでの Security Rules と、Google Cloud Console 側のAPIキー制限（アプリ制限・API制限）の両方が必須。


