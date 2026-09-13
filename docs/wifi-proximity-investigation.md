# Wi-Fi近接判定の調査・修正レポート(issue #45)

「実機2台で近くにいるのに『遠い』と判定される」という報告を受けて、
`lib/features/wifi/repository/proximity_calculator.dart` の判定ロジックと、
その入力を作る `lib/features/wifi/repository/wifi_scan_repository.dart` を
コード確認ベースで調査した。**このサンドボックスには実機が無く、Wi-Fi
スキャンAPIやAndroidのスキャンスロットリングの実際の挙動は再現できていない。
そのため以下の結論は「コードから読み取れる事実」と「未検証の仮説」を明確に
分けて書く。**

## 1. 調査結果

issueの実装メモに挙げられた6項目について、それぞれの結論。

### 1-1. `startScan()`が実際に成功しているか(スキャンスロットリングの影響)

**仮説(未検証)。** `WifiScanRepository._triggerScan()` は

```dart
final can = await WiFiScan.instance.canStartScan();
if (can != CanStartScan.yes) return;
await WiFiScan.instance.startScan();
```

という実装で、`canStartScan()` が `yes` 以外を返した場合は**何もログを残さず
黙ってこの周期のスキャンをスキップする**。AGENTS.mdの前提は「参加者全員が
開発者オプションでスロットルを解除して遊ぶ」だが、

- 参加者が解除し忘れる
- OSアップデートで設定がリセットされる
- 端末上の別アプリが同時にWi-Fiスキャンを行い、スロットルの4回/2分の
  枠を消費する

といったケースでは、スロットル解除の前提が崩れ、`_scanInterval`(10秒)通りに
実行されず、スキャン自体がスキップされ続ける可能性がある。この場合
RTDBの`wifiScan`が更新されなくなり、相手からは「近くにいるのに(古いデータの
せいで)遠い/検知なし」に見えることがありうる。

**この経路が実際に発生しているかはログが無いと切り分けられない**ため、今回
`_triggerScan()` にスキップ理由を記録する`debugPrint`を追加した(2章参照)。
原因の特定ではなく、次回以降のログから切り分けられるようにする対策。

### 1-2. `onScannedResultsAvailable`が期待通り発火しているか

**未検証。** コード上は`WiFiScan.instance.onScannedResultsAvailable`を
`startScanning()`内で購読しているだけで、発火しなかった場合の
タイムアウト検知やフォールバックは無い。`wifi_scan`パッケージ自体の
内部実装(プラットフォームチャンネル経由)はこのリポジトリの外にあり、
実機無しでは「実際に発火しているか」を直接確認する手段が無い。

`scannedAt`(RTDBに書き込んでいるサーバー時刻)を使えば「最後にイベントが
発火してから何秒経っているか」をログや表示で確認できるが、現状
`scannedAt`は書き込むだけで、判定側(`calculateProximity`や各種Provider)は
一切参照していない(1-6節・3章参照)。

### 1-3. 相手のwifiScanデータがRTDBから取得できているか

**取得できている(コード上は問題なし)。** `WifiScanRepository`は
`rooms/$roomId/locations/$_uid/wifiScan`に書き込み、`wifi_view_model.dart`側は
既存の`locationViewModelProvider`(`rooms/{roomId}/locations`の購読)経由で
自分・相手両方の`UserLocation.wifiScan`を受け取る。データ経路自体に欠陥は
見当たらない。

### 1-4. 共通AP数が3個未満になっていないか

これは環境(可視AP数)依存であり、実機無しでは値を確認できない。ただし
1-6節の「上位20件への絞り込み」が共通AP数を実際より少なく見せる方向に
働くことはコードから明確に確認できたため、**この絞り込みが「共通AP数
不足に見える」主要因の一つ**と考えられる(優先度高、下記2章で修正)。

### 1-5. -80dBmの足切り後に判定できるだけのAPが残っているか

`filterWeakSignals`の`-80dBm`カットオフ自体は`classifyProximity`より前段の
話であり、単体では「近いのに遠い」の直接原因にはなりにくい(近ければ多くの
APがカットオフを超える強度で見えるはずなので)。ただし、1-6の絞り込みで
送信前に上位20件しか残らない状態だと、その20件の中に-80dBm境界の弱いAPが
多く混ざっていた場合、実効的に使えるAP数がさらに減る可能性はある。**この
項目単独での実機データが無いため、閾値そのものを変更するのは見送り、
2章のログ追加で実測してから再検討する。**

### 1-6. 送信APを上位20個に絞る変更(`selectTopAccessPoints`, count=20)が判定に悪影響を与えていないか

**原因を特定できた(最有力仮説)。** 悪影響を与えている。

`WifiScanRepository`は自分の生スキャン結果を`selectTopAccessPoints(count: 20)`で
**RSSIが強い順の上位20件だけ**に絞ってからRTDBへ書き込む。この絞り込みは
自分・相手それぞれの端末で**独立に**行われる。

問題は、可視APが20件を超える環境(密集した集合住宅・オフィス街・駅周辺など、
このゲームが行われうる場所として現実的)で、2人がほぼ同じ場所にいて本来は
ほぼ同じBSSID集合が見えているはずでも、**RSSIの順位が20位前後で入れ替わる
ことは十分にありうる**という点にある。RSSIは各端末のアンテナ向き・持ち方・
歩行中のマルチパス等で数dB単位で揺らぐため、21位のAPが片方の端末では
19位に食い込み、逆にもう片方では21位のまま切り捨てられる、といったことが
起きる。

この結果、**本来ほぼ同じはずの2つのBSSID集合が、独立した上位20件への
絞り込みによって非対称に削られ、送信されたデータ上のJaccard係数・共通AP数が
実態より大きく下がる**。`test/features/wifi/proximity_calculator_test.dart`の
「送信前の上位N件絞り込みがproximity判定に与える影響(issue #45)」グループに、
30個のAPを完全に共有しているのに上位20件への絞り込みだけで
「近い」→「検知なし」まで悪化する例を再現している。

これは`classifyProximity`自体のバグではなく、**その手前でデータを間引く
`selectTopAccessPoints`の運用(count=20)がclassifyProximityへの入力を歪めて
いる**という構造の問題であり、コードを読むだけで再現・検証できたため、
「実機でしか確認できない」仮説ではなく確定した原因として扱い、2章で修正した。

### 1-7. `_scanInterval`(10秒)と、ヒステリシスのコメントが前提とする「約25秒間隔」との食い違い

**古いコメントの残り(ドキュメントバグ)と確認できた。** `git log`で確認すると、
`_scanInterval`はissue #8対応で「Wi-Fiデータが最大25秒遅れる」問題を受けて
25秒→10秒に短縮済み(コミット: `fix:取得APを20個に絞った` 以前の変更)。
しかし`proximity_calculator.dart`の`proximityHysteresisGraceDuration`および
`applyProximityHysteresis`のドキュメントコメント、`wifi_view_model.dart`の
`WifiProximityLevelsNotifier`のコメントには、短縮前の「約25秒間隔」という
記述がそのまま残っていた。

実際の間隔(10秒、かつ両端末は非同期)と45秒の猶予(grace duration)の関係を
計算すると、10秒間隔なら45秒の猶予は4回分以上のスキップを吸収できる計算に
なり、45秒という値自体を今回変更する必要は無いと判断した(**数値の変更では
なく、コメントの記述だけを実態に合わせて修正した**。2章参照)。

なお、Androidのスキャンスロットリングが実際に発生した場合(1-1節)は
実効間隔がさらに開く可能性があるため、「45秒あれば必ず足りる」という保証は
無い。これは閾値のチューニングでなく1-1節のログで先に実態を掴むべき問題と
考え、今回は閾値変更を見送った。

## 2. 実装した修正

いずれもこのissueのスコープ内(Wi-Fi判定ロジックとその周辺のみ)で、
RTDBのデータ形(`bssidRssi: Map<String, int>`)自体は変えていない。

1. **`selectTopAccessPoints`のデフォルト件数、および`WifiScanRepository._maxApCount`を20→40に変更**
   (`lib/features/wifi/repository/proximity_calculator.dart`,
   `lib/features/wifi/repository/wifi_scan_repository.dart`)。
   1-6節で特定した「独立した上位20件絞り込みによる非対称な欠落」の影響を
   小さくするための変更。40件でも境界の入れ替わりが理論上ゼロになるわけ
   ではないが、境界に入るAP数(可視AP数)が20件を大きく超えるような環境の
   発生率は40件しきい値の方が20件よりずっと低いと考えられる。RTDBへの
   書き込みサイズは最大で約2倍になるが、1エントリがBSSID文字列+整数RSSIの
   小さなデータであるため実用上問題になるサイズ増ではない。
   - テスト: `test/features/wifi/proximity_calculator_test.dart`
     「送信前の上位N件絞り込みがproximity判定に与える影響(issue #45)」で、
     20件絞り込みでは「近い」が「検知なし」に悪化し、40件(=新デフォルト)
     では悪化しないことを回帰テストとして固定した。
   - **実機での確認が必要**: 可視APが20件を超えるかどうかは実際の
     プレイ環境に依存する。40件という数値も「20より安全」という定性的な
     判断であり、実プレイ環境でのAP数分布に基づく再チューニングが望ましい。
     3章のログ提案を使って実測してから、必要なら値を調整すること。

2. **`WifiScanRepository._triggerScan()`に、スキャンがスキップされたことを
   示す`debugPrint`ログを追加**(`lib/features/wifi/repository/wifi_scan_repository.dart`)。
   1-1節の「スロットリングで`startScan()`が呼ばれていない」仮説を、実機ログ
   から切り分けられるようにするための変更。これ自体は判定ロジックの修正
   ではなく、次に同様の報告があったときに原因を特定するための計測。
   - テストなし(単なるログ出力の追加であり、`debugPrint`の呼び出しは
     既存の`writeOrLogFailure`と同様、動作に影響しない副作用のみのため)。
     動作確認は実機で`flutter logs`等から`[WifiScanRepository] scan skipped`
     が出ていないか確認する形になる。

3. **ドキュメントコメントの修正**(`lib/features/wifi/repository/proximity_calculator.dart`
   の`proximityHysteresisGraceDuration`・`applyProximityHysteresis`、
   `lib/features/wifi/view_model/wifi_view_model.dart`の
   `WifiProximityLevelsNotifier`): 1-7節で確認した「約25秒間隔」という
   古い記述を、実際の値(10秒)に修正。閾値(45秒)自体は変更していない。
   - 挙動を変えないコメントのみの修正のため、テストは追加していない。

## 3. 見送った項目

- **`ProximityThresholds`の各閾値(`jaccardCloseThreshold=0.50`,
  `rssiDiffCloseThresholdDbm=8`など)自体の変更は見送った。** これらは
  7/22の実測データ(`test/features/wifi/proximity_calculator_test.dart`の
  「classifyProximity (7/22実測値)」グループが根拠データ)を基に決められた
  値であり、issue本文にもある通り「静止した状態での手動スキャン」という
  条件下でのものである。ゲーム中の自動スキャン(歩行中・非同期)での実測
  データが無い状態で数値だけを変えるのは、根拠のない当て推量になり
  「直したつもり」と「直ったことを確認した」を混ぜることになるため、今回は
  実施しなかった。1-6節の絞り込み修正と2-2節のログ追加で実測データを
  取ってから、必要なら別途チューニングすることを推奨する。
- **`filterWeakSignals`の`-80dBm`カットオフの変更は見送った。** 1-5節の
  通り、単独では「近いのに遠い」の直接原因と断定できる材料が無く、
  こちらも実測データに基づいて判断すべき項目のため。
- **`scannedAt`を使ったデータ鮮度チェック(古すぎるwifiScanを判定から除外
  する等)の追加は見送った。** GPSの安定性はissue #46の担当とスコープ分けが
  明記されているため、Wi-Fi側で新たに鮮度判定ロジックを追加するのは
  スコープ拡大と判断し、今回は3章のログ提案に留めた。将来的にやる場合は
  RTDBのデータ形は変えずに済む(`scannedAt`は既に送信済み)。

## 4. 実機で確認すべきポイント

- **`_maxApCount`を40に増やした変更**: 実際のプレイ環境(密集地・郊外など
  複数パターン)で、可視APの総数と、絞り込み前後でのJaccard係数・共通AP数の
  変化を比較する。可視APが40件を大きく超える環境がある場合は、さらに値を
  見直す必要がある。
- **スキャンスキップのログ(`[WifiScanRepository] scan skipped: canStartScan=...`)**:
  実プレイ中(特に「開発者オプションでスロットル解除」を徹底した状態と、
  していない状態の両方)でこのログが出るかどうかを確認する。頻発するようなら
  1-1節のスロットリング仮説が濃厚。
- **ヒステリシスコメント修正後の45秒猶予**が、実際のスキャン間隔(スロット
  リングが起きていない前提の10秒間隔)に対して十分かどうかを、実際に
  近接・離脱を繰り返しながら確認する。

## 5. 追加すべきログの提案

いずれも未実装(このissueのスコープでは"提案"のみ)。

1. `calculateProximity`を呼び出す側(`_rawWifiProximityLevelsProvider`)で、
   判定に使った`commonApCount`・`jaccardIndex`・`averageRssiDiffDbm`と
   結果のレベルを、対象uidごとに定期的にログへ残す。実プレイ中の
   「近いのに遠い」の再現時に、どの指標が原因で`far`/`notDetected`に
   なったのかを事後解析できるようにする。
2. `_triggerScan()`のスキップログ(本レポートで追加済み)に加えて、
   `startScanning()`側でも「最後に`onScannedResultsAvailable`が発火してから
   の経過時間」を、次にRTDBへ書き込むタイミングで一緒にログすると、
   1-2節の「発火していない」仮説も切り分けやすくなる。
3. RTDB書き込み時に`bssidRssi`の件数(絞り込み後)をログに残すと、
   実環境で可視APが40件をどの程度超えているかが分かり、`_maxApCount`の
   再チューニングの材料になる。

## 6. テスト・静的解析

- `flutter test`: 全件グリーン(既存226件 + 今回追加分)。
- `flutter analyze`: 既存のリポジトリ全体の情報レベル(info)の指摘は
  今回の変更前後で増えていない(むしろ1件減少)。今回変更したファイルに
  新規の警告・エラーは無い。
