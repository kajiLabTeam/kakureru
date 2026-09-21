# ツールチェーン更新(Flutter / compileSdk / KGP)の方針調査(issue #100)

公開前監査 #92 の項目10を切り出したもの。Dependabot(#82〜#90)で
**permission_handler 13 と very_good_analysis 11 がどちらもビルド/解析を落とし**、
さらに `flutter build apk` 時に **KGP警告が5プラグイン**で出ている。
「いつ・どの順で上げるか」の方針が決まっていないのが現状なので、それを決めるための調査。

**このレポートは調査のみで、コードは変更していない。**
夜間実行のコンテナにはAndroid SDKも実機も無く、Flutterも 3.44.8 に固定されているため、
実際のアップグレードとビルド検証はこの環境ではできない。そのため以下は
**「検証できた事実」と「未検証の仮説」を明確に分けて書く**
(`docs/wifi-proximity-investigation.md:6-9` と同じ方針)。

なお **CIのログは実機に近い検証結果として使える**。`ci.yml:106` の `flutter build apk --debug`
はAndroid SDK入りのGitHub Actionsランナーで実APKを組んでおり、Dependabotの各PRに対して
すでに走っている。本レポートの「事実」の多くはこのログの実測値である(取得元のPR番号を都度示す)。

> **結論を先に**: 推奨は **案B(プラグイン先行)**。
> ①いま緑のPRを取り込む → ②KGP警告の残り3プラグインを潰す → ③Flutter 3.47.5 へ上げる →
> ④AGP + compileSdk 37 → permission_handler 13、の順。
> 理由は「KGP警告を抱えたままFlutterを上げると、警告がエラーに変わったときに
> 戻す手段がFlutter巻き戻ししか無くなる」ため(4節)。

---

## 1. 現状の整理

### 1-1. バージョン固定箇所の棚卸し

「どこを変えると何が動くのか」。main `393099b` 時点。

| ファイル:行 | 固定している値 | 変えると何が動くか |
|---|---|---|
| `.metadata:7-8` | `revision: "058e0af2c2b57e369d905a03ac9748b0ebf543c6"` / `channel: stable` | **ビルドには影響しない。** `flutter migrate` が参照する記録用。同`:4` に `should not be manually edited` とあり、手で書き換えず `flutter` コマンド経由で更新する。`:16-23` の `create_revision` / `base_revision` も同じSHA |
| `.github/workflows/ci.yml:19` | `FLUTTER_VERSION: "3.44.8"` | **CIのFlutter。** `:31`(checkジョブ)と `:85`(buildジョブ)の2箇所から参照。`:14-18` のコメントが固定理由(`dart format` の出力がSDKで変わること、KGP警告の5プラグイン)を書いている |
| `night-run/docker/Dockerfile:7` | `ARG FLUTTER_VERSION=3.44.8` | **夜間実行コンテナのFlutter。** `:37` の `git clone --branch "$FLUTTER_VERSION"` で使う。`:6` に「`.metadata` / ローカル `flutter --version` と一致させること」とある |
| `pubspec.yaml:21-22` | `environment: sdk: ^3.12.2` | **Dart SDKの下限。** これが pub の解決可能範囲を決める。`pubspec.lock` 末尾の実効値は `dart: ">=3.12.2 <4.0.0"` / `flutter: ">=3.44.0"` |
| `android/app/build.gradle.kts:20` | `compileSdk = flutter.compileSdkVersion` | **数値の明示が無い。** 値はFlutter SDKが供給する。実測(#90 buildログ)では Flutter 3.44.8 で **android-36**。37にするには、Flutterを上げるか、ここに数値を直書きするかの二択 |
| `android/app/build.gradle.kts:38-39` | `minSdk = flutter.minSdkVersion` / `targetSdk = flutter.targetSdkVersion` | 同上。Flutterを上げると**黙って動く**ので、Flutter更新時は最低動作OS(minSdk)が上がっていないか確認が要る |
| `android/settings.gradle.kts:22` | AGP `9.0.1` | **compileSdk 37 の直接の壁**(1-2節)。Gradle本体・Javaのバージョンとも連動 |
| `android/settings.gradle.kts:26` | KGP `2.3.20` | アプリ側のKotlinバージョン。**プラグイン側のKGP警告とは別物**(警告はプラグインが自前でKGPを `apply` していることに対するもの) |
| `android/settings.gradle.kts:24` | google-services `4.3.15` | Firebase。AGP更新時に追従が要る可能性がある |
| `android/gradle.properties:4,6` | `android.newDsl=false` / `android.builtInKotlin=false` | **Built-in Kotlin移行の回避フラグ。** KGP警告の直接の関係先で、これを `true` にできる状態がKGP対応の終点 |
| `android/gradle/wrapper/gradle-wrapper.properties` | `gradle-9.1.0-all.zip` | Gradle本体。AGPを上げるときに一緒に動く |
| `android/app/build.gradle.kts:25-26,62` | `JavaVersion.VERSION_17` / `JvmTarget.JVM_17` | `ci.yml:77-81` の `setup-java` 17 と対。ここを動かすとCI側も直す |
| `pubspec.yaml:47` | `permission_handler: ^11.3.1`(解決 **11.4.0**) | #90 の対象 |
| `pubspec.yaml:82` | `very_good_analysis: ^10.3.0`(解決 **10.3.0**) | #87 の対象 |
| `analysis_options.yaml:14` | `include: package:very_good_analysis/analysis_options.yaml` | lintセットの本体。vga 11 でルールが増えるとinfo件数が動く |
| `.github/workflows/ci.yml:45` | `flutter analyze --no-fatal-infos` | `:41-44` のコメントどおり、既存info 315件があるため **info は落とさずerror/warningだけ見る**。つまり **vga 11 でinfoが増えてもCIは赤くならない**(解消は #79) |
| `.github/dependabot.yml:14,21` | `open-pull-requests-limit: 5`(pub / github-actions 各5) | 1-4節。**上流に新版が出ていても、枠が埋まっているとPRが立たない** |

**Flutterのバージョンが3箇所(`.metadata` / `ci.yml:19` / `Dockerfile:7`)に散っている**点に注意。
Flutterを上げるPRはこの3つを必ず同時に触る。`.metadata` だけは手編集しない。

### 1-2. いま上げられない理由(すべてCIログの実測)

#### (a) very_good_analysis 11 → Flutter 3.47.5 が必要 — PR #87

`check` と `build` の両ジョブが `flutter pub get` の時点で落ちている。

```
The current Dart SDK version is 3.12.2.
Because no versions of very_good_analysis match >11.0.0 <12.0.0 and
very_good_analysis 11.0.0 requires SDK version ^3.13.0,
very_good_analysis ^11.0.0 is forbidden.
So, because kakureru depends on very_good_analysis ^11.0.0, version solving failed.
You can try one of the following suggestions to make the pubspec resolve:
* Try using the Flutter SDK version: 3.47.5.
```

**必要なのはDart 3.13.0以上で、pub自身が対応するFlutterとして 3.47.5 を名指ししている。**
コード側の修正では回避できない(`pubspec.yaml:21-22` の `sdk: ^3.12.2` を上げても、
コンテナ/CIのFlutterが古ければ解決しない)。

#### (b) permission_handler 13 → compileSdk 37、**かつAGPの更新も必要** — PR #90

`check` は通る(Dart側だけなら問題ない)。落ちるのは `build` の `:app:checkDebugAarMetadata`。

```
1.  Dependency ':permission_handler_android' requires libraries and applications that
    depend on it to compile against version 37 or later of the Android APIs.

    :app is currently compiled against android-36.

    Also, the maximum recommended compile SDK version for Android Gradle
    plugin 9.0.1 is 36.

    Recommended action: Update this project's version of the Android Gradle
    plugin to one that supports 37, then update this project to use
    compileSdk of at least 37.
```

**issue #92 / #100 の記述は「compileSdk 37 が必要」までだったが、実際は2段構え。**
`android/settings.gradle.kts:22` の **AGP 9.0.1 は compileSdk 36 が上限**で、
compileSdk だけ 37 に上げてもAGP側の推奨上限を超える。
`android/app/build.gradle.kts:20` に `compileSdk = 37` と直書きするだけでは不十分で、
**AGPの更新(＋連動してGradle/google-services)が先に要る**。

#### (c) KGP警告 — 実測で「5」の内訳が分かった

`ci.yml:106` の `flutter build apk --debug` のログに出る警告を、PRごとに読み比べた結果:

| 出典 | 変更内容 | KGP警告に出るプラグイン | 件数 |
|---|---|---|---|
| **#82**(actions/checkout。**依存は不変＝main相当の基準**) | — | device_info_plus, flutter_ble_peripheral, flutter_foreground_task, sensors_plus, wifi_scan | **5** |
| **#88** | device_info_plus 11.5.0 → 13.2.0 | flutter_ble_peripheral, flutter_foreground_task, sensors_plus, wifi_scan | **4** |
| **#89** | flutter_foreground_task 10.0.0 → 11.0.3 | device_info_plus, flutter_ble_peripheral, sensors_plus, wifi_scan | **4** |
| **#85** | geolocator 13.0.4 → 14.0.2 | device_info_plus, flutter_ble_peripheral, flutter_foreground_task, **package_info_plus**, sensors_plus, wifi_scan | **6** |

読み取れること:

- **device_info_plus 13.2.0(#88)と flutter_foreground_task 11.0.3(#89)は、どちらもKGP警告を実際に解消している。**
  #92 の「#88 / #89 は KGP 対応版の可能性があるので先に試す価値あり」という見立ては**当たっていた**(実測で確認)
- この2本を両方入れれば **5 → 3**(flutter_ble_peripheral, sensors_plus, wifi_scan)まで減る
- **geolocator 14(#85)は逆に警告を1件増やす。** geolocator 14 が新たに `package_info_plus` を
  推移的に引き込み、それがKGPを `apply` している。CIは緑だが、KGPの観点では**後退**

警告本文:

```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): ...
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
```

### 1-3. 残る3プラグインには、実は新版が出ている

#92 は「残る flutter_ble_peripheral / wifi_scan / sensors_plus は上流未対応と見られる」と
見立てていたが、このコンテナ(Flutter 3.44.8)で `flutter pub outdated` を実行した結果は違った。

| パッケージ | 現在 | Resolvable(いまのFlutterで解決可能) | Latest |
|---|---|---|---|
| flutter_ble_peripheral | 2.1.1 | **3.1.0** | 3.1.0 |
| sensors_plus | 6.1.2 | **7.1.0** | 7.1.0 |
| wifi_scan | 0.4.1+2 | **0.5.0** | 0.5.0 |

**3つとも、Flutterを上げないまま新しいメジャー版に上げられる**(`Resolvable` 列が
`Latest` と一致している＝現在の `sdk: ^3.12.2` 制約の下で解決できる)。
「上流未対応で手が出せない」という前提は**成り立たない**。

ただし **その新版がKGP警告を解消するかどうかは未検証**(2節の仮説H3)。
確かめる方法は用意されている——上げてPRを出せば `ci.yml:106` のAPKビルドが警告を出力するので、
#88 / #89 と同じやり方でログを読めば**実機なしで判定できる**。

### 1-4. なぜこの3つにDependabot PRが無いのか

`.github/dependabot.yml:14` の `open-pull-requests-limit: 5`(pubエコシステム)が原因と考えられる。
現在 pub のPRは #85, #86, #87, #88, #89, #90 が開いており、枠が埋まっている。
**Dependabotは枠が空くまで新しいPRを作らない**ので、新版が出ていても気づけない。

- これは「Dependabotが検知する経路として効く」という `.github/dependabot.yml:3-6` の狙いが、
  **滞留したPRによって機能しなくなっている**状態
- 対策は枠を空けること(＝3節の第1ステップで緑のPRを取り込むこと)。上限値そのものを
  上げる手もあるが、**まず滞留を解消するほうが先**
- (現在6本開いており上限5を超えている理由は特定できていない。Dependabotが上限を見るのは
  新規作成時なので、作成後に本数が変動したものと思われる。いずれにせよ**いま新規PRが
  作られない状況にあること**は変わらない)

---

## 2. 事実と仮説の切り分け

### 検証できた事実(出典つき)

| # | 事実 | 出典 |
|---|---|---|
| F1 | very_good_analysis 11.0.0 は Dart SDK `^3.13.0` を要求し、pub が Flutter **3.47.5** を名指しする。現在は Dart 3.12.2 | #87 の check / build ログ |
| F2 | permission_handler 13.0.2 は `:app` に **compileSdk 37以上**を要求し、現在は android-36 でビルドしている | #90 の build ログ |
| F3 | **AGP 9.0.1 の推奨compileSdk上限は36**。37にするにはAGPの更新が先に要る | #90 の build ログ(同じメッセージ内) |
| F4 | main相当(#82)のKGP警告は **5プラグイン** | #82 の build ログ |
| F5 | **device_info_plus 13.2.0 はKGP警告を解消する** | #88 の build ログ(警告からdevice_info_plusが消える) |
| F6 | **flutter_foreground_task 11.0.3 はKGP警告を解消する** | #89 の build ログ |
| F7 | **geolocator 14.0.2 は `package_info_plus` を持ち込み、KGP警告を6件に増やす** | #85 の build ログ |
| F8 | flutter_ble_peripheral 3.1.0 / sensors_plus 7.1.0 / wifi_scan 0.5.0 は、**現在のFlutter 3.44.8のまま解決できる** | コンテナでの `flutter pub outdated` |
| F9 | #88, #89, #82, #83, #84, #85, #86 は `check` も `build` も **SUCCESS** | `gh pr checks` |
| F10 | #83〜#86, #90 の `review` ジョブの失敗は **コードの問題ではない**(`Workflow initiated by non-human actor: dependabot (type: Bot)` でブロックされている) | #90 の review ログ |
| F11 | `ci.yml:45` は `--no-fatal-infos` なので、**vga 11 でinfoが増えてもCIは赤くならない**(新しいerror/warningだけが落とす) | `ci.yml:40-45` |
| F12 | PR #105(未使用 `deviceId` の削除)は `pubspec.yaml` から **`device_info_plus` の依存ごと削除する** | #105 の diff |
| F13 | #83 / #84 の対象である `actions/cache@v4` / `actions/setup-java@v4` には、既に **Node.js 20 非推奨の警告**が出ている | #90 の build ログ末尾 |

### 未検証の仮説(この環境では確かめられない)

| # | 仮説 | 外れたときどうなるか |
|---|---|---|
| H1 | Flutter 3.47.5 の `flutter.compileSdkVersion` は 37 である | 外れると、Flutterを上げても F2 は解けない。`android/app/build.gradle.kts:20` に `compileSdk = 37` を**直書き**する必要が出る(Flutter更新とcompileSdk更新が独立した作業になる) |
| H2 | compileSdk 37 を正式に扱えるAGPが既にリリースされている | 外れると permission_handler 13(#90)は**上流待ちになり、こちらでは進められない** |
| H3 | flutter_ble_peripheral 3.1.0 / sensors_plus 7.1.0 / wifi_scan 0.5.0 はKGP警告を解消する | 外れるとKGP警告は3件残ったままになり、案Bの②が空振りする。**ただしPRを出せばCIのAPKビルドログで判定できる**(実機不要) |
| H4 | KGP警告がエラーに変わるのは Flutter 3.47 より後である | **外れると影響が最大**。3.47へ上げた瞬間にAPKビルドが落ち、Flutterを戻す以外に手が無くなる。案Bを推す最大の根拠(4節) |
| H5 | 3プラグインのKGP対応後に `android.builtInKotlin` / `android.newDsl`(`android/gradle.properties:4,6`)を `true` に戻せる | 外れてもビルドは壊れない(フラグは `false` のままでよい)。移行の完了だけが先送りになる |
| H6 | flutter_foreground_task 11(メジャー更新)が、実機のフォアグラウンドサービス(位置・センサーの常時取得)で従来どおり動く | CIは緑でも**実機で位置更新が止まる**可能性がある。このアプリの根幹機能なので実機確認が必須 |
| H7 | geolocator 14(メジャー更新)が実機の測位で従来どおり動く | 同上。`docs/gps-location-stability.md` の平滑化まわりに影響しうる |
| H8 | Flutter更新に伴う `dart format` の出力差分が、既存コードに広く発生する | `ci.yml:15-16` が明記している既知のリスク。外れれば差分が小さくて済むだけ |

---

## 3. 更新の順序案(比較)

| | **案A: Flutter先行** | **案B: プラグイン先行(推奨)** | **案C: Android先行** |
|---|---|---|---|
| **順序** | ① Flutter 3.47.5(`.metadata`/`ci.yml:19`/`Dockerfile:7`) → ② vga 11 → ③ AGP + compileSdk 37 → ④ permission_handler 13 → ⑤ KGP残り | ① いま緑のPRを取り込む(#82,#83,#84,#86,#89)＋#105 → ② KGP残り3つ(ble_peripheral/sensors_plus/wifi_scan)→ ③ Flutter 3.47.5 → ④ vga 11 → ⑤ AGP + compileSdk 37 → ⑥ permission_handler 13 → ⑦ geolocator 14 | ① AGP + compileSdk 37 → ② permission_handler 13 → ③ Flutter 3.47.5 → ④ vga 11 → ⑤ KGP残り |
| **最初の一手で外れるもの** | vga 11(#87)がすぐ解ける | KGP警告 5→3(F5,F6)。Dependabotの枠も空く(1-4) | permission_handler 13(#90)がすぐ解ける |
| **最初の一手の大きさ** | **大**。Flutter更新は `compileSdk`/`minSdk`/`targetSdk`(`build.gradle.kts:20,38-39`)が同時に動き、`dart format` 差分(H8)も載る。1本のPRが全方位に広がる | **小**。1PR＝1プラグイン。どれも既にCIで緑(F9)か、CIログで即判定できる(H3) | **中**。AGP/Gradle/google-services が連動。ただし変更箇所は `android/` に閉じる |
| **前提にしている仮説** | H1, H4, H8 | H3(外れてもCIログで即分かる)、H6 | **H2**(対応AGPの存在。外れると初手から進めない) |
| **CIだけで検証できるか** | ほぼ可(APKビルドまで回る)。ただし失敗時に**どの要素が原因か切り分けにくい** | **可**。1ステップ＝1PRで、`ci.yml:106` のAPKビルドとKGP警告ログが毎回判定してくれる | 可 |
| **失敗したときの戻し方** | Flutter更新PLUS全部をまとめて revert。中間状態が無い | **1本ずつ revert できる** | AGP PRを revert |
| **最大のリスク** | **H4が外れると詰む**。KGP 5件のままFlutterを上げ、警告がエラーに変わるとAPKが組めない。戻す手段はFlutterの巻き戻しだけ | ②が空振り(H3)しても、①の成果(5→3、枠の解放)は残る | H2が外れると**何も進まない**。情報が最も少ない |
| **評価** | 一手で大きく動くが、切り分けと巻き戻しが最も苦しい | **各ステップが独立に検証・巻き戻し可能**。最大リスク(H4)を先に潰す | 依拠する仮説が一番不確かで、初手の空振り確率が高い |

### 推奨: 案B(プラグイン先行)

決め手は3つ。

1. **H4のリスクを先に潰せる。** KGP警告の本文は
   `Future versions of Flutter will fail to build if your app uses plugins that apply KGP.`
   と言っている。5件抱えたままFlutterを3.47へ上げ(案A①)、そこが「Future version」だった場合、
   APKビルドが落ちる。しかもKGPを直すには結局プラグインを上げる必要があり、
   **Flutterを戻すしか復旧経路が無い**。案Bはこの順序を逆にするだけでリスクを消せる。
2. **ステップごとに実機なしで判定できる。** `ci.yml:106` がAPKを実際に組み、KGP警告を
   ログに出す。#88/#89 の実測(F5,F6)がまさにこの方法で得られた。
   案Bの①②は**全ステップをこの環境から検証できる**(H6/H7の実機確認を除く)。
3. **巻き戻しが1本単位になる。** AGENTS.md 安全ルール1が禁じている破壊的操作を使わずに、
   `git revert` 1本で戻せる粒度を保てる。案Aの①は1本のPRに
   Flutter・compileSdk・minSdk・format差分が同居するため、この粒度が作れない。

**案Bで最初にやること(1PRずつ)**:

1. #82 / #83 / #84 / #86 をマージ(全部緑。#83/#84 はNode 20非推奨の解消も兼ねる — F13)
2. #105(`deviceId` 削除)をマージ。これで `device_info_plus` が依存から消え、**#88 は不要になる**(F12。次節)
3. #89(flutter_foreground_task 11)を**実機確認のうえ**マージ(H6)。ここまででKGP警告は 5 → 3
4. flutter_ble_peripheral 3.1.0 / sensors_plus 7.1.0 / wifi_scan 0.5.0 を1本ずつ上げ、
   **各PRのAPKビルドログでKGP警告が減るかを確認**(H3の検証)。0件になったら
   `android/gradle.properties:4,6` のフラグを `true` に戻せるか試す(H5)
5. KGPが片付いてから Flutter 3.47.5(3箇所同時)→ vga 11(#87)→ AGP + compileSdk 37 →
   permission_handler 13(#90)→ geolocator 14(#85)

---

## 4. 開いているDependabot PRの扱い

| PR | 内容 | CI(check / build) | 判定 | 理由 |
|---|---|---|---|---|
| **#82** | actions/checkout 6 → 7 | 緑 / 緑 | **すぐ取り込む** | 影響がCIに閉じている。全ジョブ緑 |
| **#83** | actions/setup-java 4 → 6 | 緑 / 緑 | **すぐ取り込む** | `setup-java@v4` に既にNode 20非推奨の警告が出ている(F13)。上げるほうが安全 |
| **#84** | actions/cache 4 → 6 | 緑 / 緑 | **すぐ取り込む** | 同上 |
| **#86** | vibration 3.2.0 → 3.2.1 | 緑 / 緑 | **すぐ取り込む** | パッチ更新。KGP警告に影響なし |
| **#88** | device_info_plus 11.5.0 → 13.2.0 | 緑 / 緑 | **#105 が入るなら閉じてよい** | #105 が `pubspec.yaml` から `device_info_plus` の依存ごと削除する(F12)。**依存が消えればKGP警告からも消える**ので、13.2.0 に上げる意味が無くなる。#105 が見送られた場合のみ、KGP解消(F5)を目的にマージする |
| **#89** | flutter_foreground_task 10.0.0 → 11.0.3 | 緑 / 緑 | **実機確認のうえ取り込む** | KGP警告を解消する(F6)＝案Bの本命の1本。ただしメジャー更新で、位置・センサーの常時取得を担うフォアグラウンドサービスそのもの(H6)。CI緑だけで入れない |
| **#85** | geolocator 13.0.4 → 14.0.2 | 緑 / 緑 | **待つ**(KGP片付け後) | CIは緑だが `package_info_plus` を持ち込んでKGP警告を6件に増やす(F7)。KGPを潰し切る前に入れると逆行する。加えてメジャー更新で測位挙動に直結(H7) |
| **#87** | very_good_analysis 10.3.0 → 11.0.0 | **赤 / 赤** | **待つ**(Flutter 3.47.5 後) | Dart 3.13.0 が要る(F1)。こちらでは解決不能。取り込むのはFlutter更新の直後。なおinfoが増えてもCIは落ちない(F11)ので、Flutterさえ上がれば素直に入るはず |
| **#90** | permission_handler 11.4.0 → 13.0.2 | 緑 / **赤** | **待つ**(AGP + compileSdk 37 後) | compileSdk 37 が要る(F2)＋AGP 9.0.1 が上限36(F3)。**AGPの更新が先**。H2が未確認なので、着手前にまず対応AGPの有無を調べる |

**いずれも「閉じる」必要は無い**(#88 を除く)。開いたままにしておけばDependabotがrebaseし続ける。
ただし `open-pull-requests-limit: 5`(`.github/dependabot.yml:14`)の枠を塞いでおり、
**新しい更新の検知を止めている**(1-4節)。緑の4本(#82,#83,#84,#86)を取り込むだけで
枠が空き、`flutter_ble_peripheral` / `sensors_plus` / `wifi_scan` の新版(F8)が
Dependabot経由でも見えるようになる。

**注意**: #83〜#86 と #90 の `review` ジョブが赤いのは、`Workflow initiated by non-human actor:
dependabot (type: Bot)` によるブロックであって、**コードの問題ではない**(F10)。
マージ可否の判断材料にしないこと。

---

## 5. このレポートで決まっていないこと

次に着手する人が最初に調べるべき順:

1. **compileSdk 37 を扱えるAGPのバージョン**(H2)。ここが分からないと #90 は動かせない。
   AGPリリースノートを見るのが最短
2. **Flutter 3.47.5 の `flutter.compileSdkVersion`**(H1)。37 なら `android/app/build.gradle.kts:20`
   は触らずに済む。36 のままなら数値の直書きが要る
3. **KGP警告がエラーになるFlutterのバージョン**(H4)。案Bを採るならリスクは下がるが、
   期限を知っておく価値はある
4. **#105 をマージするかどうか**。#88 の扱いがこれで決まる

実作業(Flutter更新・compileSdk更新・プラグイン更新)は**別issue**に切ること。
このレポートは方針の確定までを担当範囲とする(#100 のスコープ)。
