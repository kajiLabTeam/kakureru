# GPS位置が安定しない原因調査と対策(issue #46)

## 背景

実際にはほぼ同じ場所にいるのに、地図上のピンが近辺のあちこちに飛び回る。GPS単体の測位誤差(特に屋内)がそのままRTDBへ書き込まれ、他の参加者の画面にノイズとして表示されていることが原因。

## 1. 現状の設定と問題点の整理

### geolocatorの設定

- 位置取得(バックグラウンドisolate、`lib/features/location/repository/location_task_handler.dart` の `_getWithGeolocator`):
  `Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: LocationAccuracy.high))` のみ。
  - `distanceFilter`・`intervalDuration` は未設定
  - **`distanceFilter` はそもそも `getCurrentPosition()` には効かない**(geolocatorの実装上、`distanceFilter`/`intervalDuration` は `getPositionStream()` 用のオプションであり、単発取得の `getCurrentPosition()` では無視される)。現在のアーキテクチャ(4秒ごとに単発取得)を維持する限り、このオプションを設定しても意味を持たない
- 取得間隔(メインisolate、`lib/features/location/repository/location_repository.dart`): `ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.repeat(4000))` で4秒間隔
- `Position.accuracy` は取得も送信もしていなかった(`sendCurrentPosition` が送るのは `lat`/`lng`/`altitude` のみ)。精度に関わらずすべての測位結果がそのままRTDBに書き込まれていた

### 平滑化処理

- 平滑化処理はどこにも入っていなかった(このissueの前提どおり)。1回ごとの生の測位結果がそのまま `rooms/{roomId}/locations/{uid}` に書き込まれ、購読側にそのまま伝播していた

### 屋内でのGPS誤差

- 屋外・見晴らしの良い場所ではAndroidのGPS(+ Wi-Fi/セルによる補助測位)の誤差はおおむね5〜20m程度
- 屋内やビルの谷間では衛星信号が反射・減衰し、誤差が数十m〜100m超に悪化することが珍しくない。この誤差が全て `Position.accuracy` に反映される(値が大きいほど信頼できない)
- 4秒ごとに独立して単発取得しているため、同じ場所にいても取得のたびに誤差が異なる方向へ振れ、「ピンが飛び回る」体感になる

## 2. 対策案の比較

| 対策 | メリット | デメリット | 適合度 |
|---|---|---|---|
| **移動平均による平滑化** | 実装が単純。突発的なノイズを均せる | 直近N件の履歴を保持する必要がある(状態を持つ)。実際に移動し始めても平均に引きずられて追従が遅れる(鬼ごっこでは「今どこにいるか」が重要なため、遅延は体感を悪化させうる)。静止中でも悪い値が混ざれば平均自体がずれる(悪い値を除外する仕組みと併用しないと効果が限定的) | 中 |
| **カルマンフィルタ** | 理論上は速度モデルを持てるため、平均より追従性と平滑性を両立できる。ノイズ特性が既知なら最適 | プロセスノイズ・観測ノイズの分散をチューニングする必要があり、実機での試行錯誤が前提。実装・検証コストが高く、**このサンドボックスには実機が無くパラメータの妥当性を確認できない**。歩行速度中心の単純な移動にはオーバースペックになりがち | 低(今回は見送り) |
| **一定距離以下の変化を無視する(デッドバンド)** | 実装が単純で状態も「直前に採用した1点」だけで済む。静止中の微小なブレを確実に抑えられる。純粋関数として書きやすく、テストしやすい | 閾値未満のゆっくりした実移動が無視される(閾値を超えるまで反映されない)。閾値のチューニングが要実機 | 高 |
| **geolocatorの`distanceFilter`を使う** | プラグイン側で完結し実装コストが低い(本来は) | **単発取得(`getCurrentPosition`)には効かない**。効かせるには `getPositionStream()` へアーキテクチャを変更する必要があり、取得間隔(4秒)の仕組み自体を作り変えることになる。このissueのスコープ外(「位置取得の間隔を変えること自体を目的にした変更はしない」)であり、対策として直接採用するのは見送り | 低(今回は見送り) |
| **`Position.accuracy`が悪い測位結果を捨てる** | 実装が単純。屋内などで精度が大きく落ちた「そもそも信頼できない」測位を根本から除外できる。純粋関数として書きやすい | 精度が慢性的に悪い環境(屋内奥など)では更新が止まりがちになる。閾値のチューニングが要実機 | 高 |

### 採用: デッドバンド + accuracyによる足切りの組み合わせ

理由:

- **「静止中にピンが飛び回る」という報告された症状に対して、最短距離で効く組み合わせ**。accuracyの悪い測位(屋内で悪化した測位)をそもそも捨て、残った測位についても直前の採用位置から一定距離未満の変化は無視することで、両方の経路のノイズを抑えられる
- どちらも**状態を最小限(直前に採用した1点の緯度経度)しか持たない純粋関数**として書け、実機無しでも境界値も含めてテストで検証しきれる。移動平均やカルマンフィルタのような「履歴やノイズモデルのチューニングが実機前提」の手法に比べ、このサンドボックス環境でも実装の正しさを保証しやすい
- カルマンフィルタは理論上優れるが、実機での分散パラメータ調整ができない今の開発環境では「動くはずだが検証できない」実装になるリスクが高く、必要以上に複雑にしないという方針(AGENTS.mdの「過剰実装をしない」判断とも整合)で見送った
- `distanceFilter` は現行のアーキテクチャ(4秒ごとの単発取得)には効果が無いため、対策として採用しなかった
- 移動平均は追従の遅延というトレードオフがあり、鬼ごっこでは「今の位置」がゲーム性に直結するため見送った。デッドバンド+accuracy足切りの組み合わせで体感上の症状(静止中の飛び回り)は十分に抑えられると判断した

## 3. 実装内容

- `lib/features/location/repository/location_smoothing.dart`(新規): 純粋関数 `shouldAcceptLocationUpdate` を切り出した。新しい測位結果を採用するかどうかを、(1) accuracyが閾値を超えていないか、(2) 直前に採用した位置からの移動距離がデッドバンド以上か、の2条件で判定する。テスト: `test/features/location/repository/location_smoothing_test.dart`
- `lib/features/location/repository/location_task_handler.dart`: `sendCurrentPosition` が `Position.accuracy` もメインisolateへ送るように変更(`'accuracy': position.accuracy`)
- `lib/features/location/repository/location_repository.dart`: `_taskDataCallback` で `shouldAcceptLocationUpdate` を呼び、不採用ならRTDBへの書き込み自体をスキップする。採用した場合のみ直前位置(`_lastAcceptedLat`/`_lastAcceptedLng`)を更新し、`accuracy` もRTDBへ書き込む。`startSendingLocation` のたびに直前位置をリセットする(ゲームをまたいで古い基準が残らないように)
- `lib/features/location/model/user_location.dart`: `accuracy`(double?)フィールドを追加(Freezed。`dart run build_runner build --delete-conflicting-outputs` で再生成済み)
- `docs/rtdb-schema.md`: `locations/{uid}` に `accuracy` ノードを追記

## 4. 実機でしか確認できない点

このサンドボックスには実機が無く、以下は**ロジックの正しさ(境界値含む)はテストで確認済みだが、実際の値の妥当性(ちょうど良い加減か)は実機でしか確認できない**。「直したつもり」であり「直ったことを確認した」わけではないことを明記する。

| パラメータ | 場所 | 初期値(提案) | 実機で調整すべき理由 |
|---|---|---|---|
| `maxAcceptableAccuracyM`(accuracy足切りの閾値) | `LocationFilterThresholds.maxAcceptableAccuracyM` | 30.0 m | 実際に遊ぶ環境(屋外広場/建物近く等)でのAndroid端末のaccuracy分布を見て、「捨てすぎて更新が止まる」と「悪い測位を通しすぎる」のバランスを取る必要がある |
| `deadbandDistanceM`(デッドバンドの閾値) | `LocationFilterThresholds.deadbandDistanceM` | 8.0 m | 小さすぎるとノイズを抑えきれず、大きすぎるとゆっくりした実移動(忍び足で近づく等)が反映されなくなる。鬼ごっこでの実際の移動速度・センスするべき距離感(`senseDistanceRadiusM`)とのバランスで実機調整が必要 |

## スコープ外(意図的に扱っていない)

- 鬼視点のGPS曖昧化(issue #39, グリッド方式): 表示精度を意図的に粗くする話であり、本issueの「測位そのもののノイズを減らす」話とは別軸
- Wi-Fi・気圧・BLEの判定ロジック
- 位置取得の間隔(4秒)自体の変更: 対策として直接必要ではなかったため変更していない
