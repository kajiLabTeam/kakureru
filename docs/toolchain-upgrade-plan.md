# ツールチェーン更新(Flutter / compileSdk / KGP)の方針調査(issue #100)

## 背景

公開前監査 #92 の項目10を切り出したもの。Dependabot(#82〜#90)で
**permission_handler 13 と very_good_analysis 11 がどちらもビルド/解析を落とし**、
さらに `flutter build apk` 時に **KGP警告が5プラグイン**で出ている。
「いつ・どの順で上げるか」の方針が決まっていないのが現状なので、それを決めるための調査。

**このレポートは調査のみで、コードは変更していない。**
夜間実行のコンテナにはAndroid SDKも実機も無く、Flutterも 3.44.8 に固定されているため、
実際のアップグレードとビルド検証はこの環境ではできない。そのため以下は
**「検証できた事実」と「未検証の仮説」を明確に分けて書く**
(`docs/wifi-proximity-investigation.md:6-9` と同じ方針)。

ただし **この環境でも実際に検証できる経路が3つあり、本レポートの事実の大半はそこから取っている**。

1. **CIのログ**。`ci.yml:106` の `flutter build apk --debug` はAndroid SDK入りの
   GitHub Actionsランナーで実APKを組んでおり、Dependabotの各PRに対してすでに走っている。
   KGP警告もビルドエラーもここに出る(取得元のPR番号・ジョブIDを都度示す)
2. **`flutter pub outdated`**(コンテナで実行可能)
3. **`raw.githubusercontent.com` / `pub.dev` へのHTTP取得**。Flutter SDKの
   Gradle定数やパッケージの依存関係を直接読める

> **結論を先に**: 推奨は **案B(KGP先行)**。
> いま緑のPRを取り込む(順序に注意——**#88 は #105 より先**)→ KGP警告の残りを潰す →
> `compileSdk = 37` の明示 → permission_handler 13 → Flutter 3.47.5 → very_good_analysis 11。
> **実行手順の正は3節末尾の「案Bで最初にやること」**(8ステップ)で、他の箇所はその要約。
>
> 調査の過程で、**issue #92 / #100 の前提2つが誤りであることが実測で分かった**。
> 結論に直接効くので先に挙げる。
>
> - **Flutter 3.47.5 に上げても compileSdk は 36 のままで、permission_handler 13 は解けない**(F3)。
>   「Flutterを上げれば compileSdk 37 が付いてくる」は成り立たない。両者は**独立した作業**
> - **「上流未対応と見られる」とされた flutter_ble_peripheral / sensors_plus / wifi_scan には
>   新版があり、いまのFlutterのままでも pub の依存解決は通る**(F9)。PRが立たないのは
>   上流の都合ではなく、`dependabot.yml:14` の同時PR上限が滞留PRで埋まっているせいと
>   考えられる(1-4節。ここは推論)

---

## 1. 現状の整理

### 1-1. バージョン固定箇所の棚卸し

「どこを変えると何が動くのか」。main `393099b` 時点。

| ファイル:行 | 固定している値 | 変えると何が動くか |
|---|---|---|
| `.metadata:7-8` | `revision: "058e0af2c2b57e369d905a03ac9748b0ebf543c6"` / `channel: stable` | **ビルドには影響しない。** `flutter migrate` が参照する記録用。同`:4` に `should not be manually edited` とあり、手で書き換えず `flutter` コマンド経由で更新する。`:16-23` の `create_revision` / `base_revision` も同じSHA |
| `.github/workflows/ci.yml:19` | `FLUTTER_VERSION: "3.44.8"` | **CIのFlutter。** `:31`(checkジョブ)と `:85`(buildジョブ)の2箇所から参照。`:15-18` のコメントが固定理由(`dart format` の出力がSDKで変わること、KGP警告の5プラグイン)を書いている |
| `night-run/docker/Dockerfile:7` | `ARG FLUTTER_VERSION=3.44.8` | **夜間実行コンテナのFlutter。** `:37` の `git clone --branch "$FLUTTER_VERSION"` で使う。`:6` に「`.metadata` / ローカル `flutter --version` と一致させること」とある |
| `pubspec.yaml:21-22` | `environment: sdk: ^3.12.2` | **Dart SDKの下限。** これが pub の解決可能範囲を決める。`pubspec.lock` 末尾の実効値は `dart: ">=3.12.2 <4.0.0"` / `flutter: ">=3.44.0"` |
| `android/app/build.gradle.kts:20` | `compileSdk = flutter.compileSdkVersion` | **数値の明示が無く、値はFlutter SDKが供給する。** 実測では Flutter **3.44.8 も 3.47.5 も 36**(F3)。37にするには**ここに数値を直書きするしかない** |
| `android/app/build.gradle.kts:38-39` | `minSdk = flutter.minSdkVersion` / `targetSdk = flutter.targetSdkVersion` | 同じくFlutter供給。一般にはFlutter更新で黙って動く値だが、**3.44.8 → 3.47.5 では minSdk 24 / targetSdk 36 のまま不変**(F3)。この更新に限り確認不要 |
| `android/settings.gradle.kts:22` | AGP `9.0.1` | compileSdk 37 では「推奨上限36を超える」警告が出る(F4)。Gradle本体・Javaのバージョンとも連動 |
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

### 1-2. いま上げられない理由(すべて実測)

#### (a) very_good_analysis 11 → Flutter 3.47.5 が必要 — PR #87

`check` と `build` の両ジョブが `flutter pub get` の時点で落ちている(逐語引用):

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
コード側の修正では回避できない。

#### (b) permission_handler 13 → compileSdk 37。**Flutter更新では解けない** — PR #90

`check` は通る(Dart側だけなら問題ない)。落ちるのは `build` の `:app:checkDebugAarMetadata`。
**同じログに、性格の違うメッセージが2つ出ている点が重要**。以下は逐語引用(ログの行頭タイムスタンプのみ除去)。

まず **Flutterのツール側**が、対処法を1つだけ示している:

```
Your project is configured to compile against Android SDK 36, but the following plugin(s) require to be compiled against a higher Android SDK version:
- permission_handler_android compiles against Android SDK 37
Fix this issue by compiling against the highest Android SDK version (they are backward compatible).
Add the following to /home/runner/work/kakureru/kakureru/android/app/build.gradle.kts:

    android {
        compileSdk = 37
        ...
    }
```

次に **AGP側**が、ビルドを実際に落としつつ別の助言を添えている:

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

読み分け:

- **必須なのは `android/app/build.gradle.kts:20` への `compileSdk = 37` の明示**。
  Flutterのメッセージはこれしか要求していない
- AGP 9.0.1 の上限36は **"maximum *recommended*"** であり、`Recommended action:` も**推奨**。
  **AGPの更新が必須だとはどちらのメッセージも言っていない**(ここまではログから読める事実＝F4。
  そのうえで実際にビルドが通るかどうかが仮説H1)
- **そして issue #92 / #100 が想定していた「Flutterを上げれば解ける」は成り立たない。**
  Flutter 3.47.5 の `compileSdkVersion` も 36 だから(F3)

→ #90 の最短経路は **「`compileSdk = 37` を1行足したPRを出し、CIのAPKビルドが通るか見る」**。
AGP 9.0.1 のまま警告付きで通るかどうかは、**実機もAndroid SDKも無しに、この経路で判定できる**。

#### (c) KGP警告 — 実測で「5」の内訳が分かった

`ci.yml:106` の `flutter build apk --debug` のログに出る警告を、PRごとに読み比べた結果:

| 出典(ジョブ) | 変更内容 | KGP警告に出るプラグイン | 件数 |
|---|---|---|---|
| **#82**(依存は不変＝**main相当の基準**) | — | device_info_plus, flutter_ble_peripheral, flutter_foreground_task, sensors_plus, wifi_scan | **5** |
| **#88** | device_info_plus 11.5.0 → 13.2.0 | flutter_ble_peripheral, flutter_foreground_task, sensors_plus, wifi_scan | **4** |
| **#89** | flutter_foreground_task 10.0.0 → 11.0.3 | device_info_plus, flutter_ble_peripheral, sensors_plus, wifi_scan | **4** |
| **#105**(`deviceId` 削除。`device_info_plus` を**直接依存から**外す) | — | device_info_plus, flutter_ble_peripheral, flutter_foreground_task, sensors_plus, wifi_scan | **5**(不変) |
| **#85** | geolocator 13.0.4 → 14.0.2 | device_info_plus, flutter_ble_peripheral, flutter_foreground_task, **package_info_plus**, sensors_plus, wifi_scan | **6** |

警告本文(逐語):

```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): ...
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
```

読み取れること:

- **device_info_plus 13.2.0(#88)と flutter_foreground_task 11.0.3(#89)は、どちらもKGP警告を実際に解消している。**
  #92 の「#88 / #89 は KGP 対応版の可能性があるので先に試す価値あり」という見立ては**当たっていた**
- この2本を両方入れれば **5 → 3**(flutter_ble_peripheral, sensors_plus, wifi_scan)まで減る
- **#105 はKGP警告を1件も減らさない。** 詳細は1-3節。直接依存から外れても、
  `vibration` 経由で推移依存として残るため
- **geolocator 14(#85)は逆に警告を1件増やす。** geolocator 14 が新たに `package_info_plus` を
  推移的に引き込み、それがKGPを `apply` している。CIは緑だが、KGPの観点では**後退**

> **比較の前提**: #82 / #85 / #90 のログは 2026-09-20、#88 / #89 は 09-21、#105 は 09-21 夜の実行で、
> ベースとなるmainが厳密には同一ではない。ただし各PRの変更対象プラグインと警告の増減が
> 1対1で対応しているため、上記の読み取りは成立する。

### 1-3. #105 は device_info_plus を消さない(#88 の扱いに直結)

「未使用の `deviceId` を削除する」PR #105 が `device_info_plus` を依存ごと消すなら、
#88 は不要になる——と考えたくなるが、**実測では消えない**。

`gh pr diff 105` の `pubspec.lock` 差分は、依存の**種別が変わるだけ**である:

```
   device_info_plus:
-    dependency: "direct main"
+    dependency: transitive
```

`flutter pub deps --style=compact` で経路が確認できる:

```
- vibration 3.2.0 [flutter plugin_platform_interface vibration_platform_interface]
- vibration_platform_interface 0.1.2 [flutter plugin_platform_interface device_info_plus]
```

**`vibration` → `vibration_platform_interface` → `device_info_plus`** という推移依存があり、
`pubspec.yaml` から直接依存を消してもビルドには入り続ける。
1-2(c)の表のとおり、**#105 自身のCIビルドでもKGP警告は5件のまま**で device_info_plus が残っている。

さらに pub.dev を引くと:

- `vibration` は 3.1.8 / 3.2.0 / **3.2.1(#86 の対象)** いずれも `vibration_platform_interface: ^0.1.1` に依存
- `vibration_platform_interface` は最新の 0.1.2 でも `device_info_plus: >=9.0.2 <14.0.0` に依存

つまり **`vibration` を使い続ける限り device_info_plus は外れない**。#86 を入れても変わらない。

**実務上の結論(順序が効く)**:

- `device_info_plus` のKGPを解消するには、**推移依存であっても 13.2.0 に上げる必要がある**。
  上の制約 `>=9.0.2 <14.0.0` は 13.2.0 を許すので、上げること自体は可能
- ただし **#105 が先に入ると device_info_plus は直接依存でなくなり、Dependabotが #88 を
  自動クローズすると考えられる(仮説H9)**。そうなると 13.2.0 へ上げる手段が
  「`flutter pub upgrade` で lock を動かす」等に変わり、ひと手間増える
- → **#88 を #105 より先にマージする**のが素直。lock が 13.2.0 になった状態で
  #105 が種別だけを transitive に変えるので、KGP解消が保たれる

### 1-4. 残る3プラグインには、実は新版が出ている

#92 は「残る flutter_ble_peripheral / wifi_scan / sensors_plus は上流未対応と見られる」と
見立てていたが、このコンテナ(Flutter 3.44.8)で `flutter pub outdated` を実行した結果は違った。

| パッケージ | 現在 | Resolvable(いまのFlutterで解決可能) | Latest |
|---|---|---|---|
| flutter_ble_peripheral | 2.1.1 | **3.1.0** | 3.1.0 |
| sensors_plus | 6.1.2 | **7.1.0** | 7.1.0 |
| wifi_scan | 0.4.1+2 | **0.5.0** | 0.5.0 |
| (比較)permission_handler | 11.4.0 | 13.0.2 | 13.0.2 |

**3つとも `Resolvable` 列が `Latest` と一致している**——つまり現在の `sdk: ^3.12.2` 制約の下で、
**Flutterを上げないまま pub の依存解決は通る**。

ただし **`Resolvable` が保証するのはそこまで**で、Androidビルド側(AARメタデータの
`compileSdk` 要求、Gradle/AGP互換)は一切見ていない。**同じ出力の中に反例がある**:
`permission_handler` も `Resolvable` は 13.0.2 だが、実際には
`:app:checkDebugAarMetadata` でビルドが落ちる(F2)。

それでも「上流未対応で手が出せない」という前提は、**少なくとも依存解決の段階では成り立たない**。
先へ進めるかどうかは、実際にPRを出してAPKビルドを見るまで分からない。

その新版がKGP警告を解消するかどうかは未検証(仮説H2)。ただし
**確かめる方法は用意されている**——上げてPRを出せば `ci.yml:106` のAPKビルドが警告を出力するので、
#88 / #89 と同じやり方でログを読めば**実機なしで判定できる**。

**なぜこの3つにDependabot PRが無いのか**は、`.github/dependabot.yml:14` の
`open-pull-requests-limit: 5`(pubエコシステム)が原因と考えられる。
現在 pub のPRは #85, #86, #87, #88, #89, #90 が開いており、枠が埋まっている。
Dependabotが枠の上限を見るのは新規PRの作成時なので、**枠が埋まっている間は新版が出ていても
PRが立たない**——という説明が成り立つ。ただしこれは推論であり、断定はできない(下の括弧)。

- もしそうなら、「対応版が出たことに気づく経路として効く」という `.github/dependabot.yml:3-6` の
  狙いが、**滞留したPRによって機能しなくなっている**ことになる
- 対策は枠を空けること(＝3節の第1ステップ)。上限値を上げる手もあるが、まず滞留の解消が先
- (現在6本開いており上限5を超えている理由は特定できていない。Dependabotが上限を見るのは
  新規作成時なので、作成後に本数が変動したものと思われる。上限超過の説明がつかない以上、
  **この因果は推論の域を出ない**。確実なのは「新版が3本出ているのにPRが無い」という事実だけで、
  枠を空ければ原因がこれだったのかどうかも同時に分かる)

---

## 2. 事実と仮説の切り分け

### 2-1. 検証できた事実(出典つき)

| # | 事実 | 出典・確認方法 |
|---|---|---|
| F1 | very_good_analysis 11.0.0 は Dart SDK `^3.13.0` を要求し、pub が Flutter **3.47.5** を名指しする。現在は Dart 3.12.2 | #87 の check / build ログ |
| F2 | permission_handler 13.0.2 は `:app` に **compileSdk 37以上**を要求し、現在は android-36 でビルドしている。Flutterのツールは対処として **`android/app/build.gradle.kts` に `compileSdk = 37` を足すことだけ**を指示している | #90 の build ログ(job 106095302778) |
| F3 | **Flutter 3.47.5 の `compileSdkVersion` は 36 で、3.44.8 と同値。`minSdkVersion` 24 / `targetSdkVersion` 36 も両バージョンで同一** | `flutter/flutter` タグ 3.44.8 / 3.47.5 の `packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt:23,26,34` を `raw.githubusercontent.com` から取得して比較 |
| F4 | AGP 9.0.1 の **推奨**compileSdk上限は36(`maximum recommended`)。ただし更新が**必須**とはログのどこにも書かれていない | #90 の build ログ |
| F5 | main相当(#82)のKGP警告は **5プラグイン** | #82 の build ログ |
| F6 | **device_info_plus 13.2.0 はKGP警告を解消する** | #88 の build ログ(警告からdevice_info_plusが消える) |
| F7 | **flutter_foreground_task 11.0.3 はKGP警告を解消する** | #89 の build ログ |
| F8 | **geolocator 14.0.2 は `package_info_plus` を持ち込み、KGP警告を6件に増やす** | #85 の build ログ |
| F9 | flutter_ble_peripheral 3.1.0 / sensors_plus 7.1.0 / wifi_scan 0.5.0 は、**現在のFlutter 3.44.8のまま pub の依存解決が通る**(`Resolvable` = `Latest`)。**ビルドが通るかは別問題**——同じ出力で permission_handler 13.0.2 も `Resolvable` だが、実際にはF2のとおり落ちる | コンテナでの `flutter pub outdated` |
| F10 | #88, #89, #82, #83, #84, #85, #86, #105 は `check` も `build` も **SUCCESS** | `gh pr checks` |
| F11 | #83〜#86, #90 の `review` ジョブの失敗は **コードの問題ではない**(`Workflow initiated by non-human actor: dependabot (type: Bot)` でブロックされている) | #90 の review ログ |
| F12 | `ci.yml:45` は `--no-fatal-infos` なので、**vga 11 でinfoが増えてもCIは赤くならない**(新しいerror/warningだけが落とす) | `ci.yml:40-45` |
| F13 | **PR #105 は `device_info_plus` をビルドから外さない。** `pubspec.yaml` の直接依存を消すだけで、lock 上は `transitive` に変わり、`vibration → vibration_platform_interface 0.1.2 → device_info_plus` の経路で残る。**#105 自身のCIビルドでもKGP警告は5件のまま** | `gh pr diff 105`、`flutter pub deps --style=compact`、#105 の build ログ(job 106476077840) |
| F14 | `vibration_platform_interface` は最新 0.1.2 でも `device_info_plus: >=9.0.2 <14.0.0` に依存する(＝13.2.0 は許容される)。`vibration` は 3.2.1(#86)でも依存先は同じ | pub.dev API |
| F15 | #83 / #84 の対象である `actions/setup-java@v4` / `actions/cache@v4` には、既に **Node.js 20 非推奨の警告**が出ている | #90 の build ログ末尾 |

### 2-2. 未検証の仮説

| # | 仮説 | 外れたときどうなるか | 確かめ方 |
|---|---|---|---|
| H1 | **AGP 9.0.1 のまま `compileSdk = 37` を明示すれば、警告付きでAPKビルドは通る** | 外れるとAGPの更新(＋連動してGradle / google-services)が先に必要になり、#90 は1行では済まなくなる | **`compileSdk = 37` を1行足したPRを出し、`ci.yml:106` のAPKビルドを見るだけ。実機不要**。案Bで最初に潰すべき仮説 |
| H2 | flutter_ble_peripheral 3.1.0 / sensors_plus 7.1.0 / wifi_scan 0.5.0 はKGP警告を解消する | 外れるとKGP警告が残る。**KGPを解消しないだけでなく、permission_handler 13 と同様に `compileSdk` 要求でビルド自体が落ちる可能性もある**(F9の注記) | 1本ずつPRを出してAPKビルドログを読む。KGPが減ったかも、ビルドが通るかも、同じログで分かる。実機不要 |
| H3 | H1が外れた場合に備え、**compileSdk 37 を正式に扱えるAGPが既にリリースされている** | 外れると permission_handler 13 は上流待ちになる | AGPのリリースノート / Google Maven の `maven-metadata.xml`。**このコンテナからは `dl.google.com` に到達できず未確認** |
| H4 | KGP警告がエラーに変わるのは Flutter 3.47 より後である | 外れると 3.47 へ上げた時点でAPKビルドが落ちる。ただし復旧路はある(3節の推奨理由を参照) | Flutterのリリースノート / `migrate-to-built-in-kotlin` のドキュメント |
| H5 | 3プラグインのKGP対応後に `android.builtInKotlin` / `android.newDsl`(`android/gradle.properties:4,6`)を `true` にできる | 外れてもビルドは壊れない(フラグは `false` のままでよい)。移行の完了だけが先送りになる | KGPが0件になった後に切り替えてAPKビルド。実機不要 |
| H6 | flutter_foreground_task 11(メジャー更新)が、実機のフォアグラウンドサービス(位置・センサーの常時取得)で従来どおり動く | CIは緑でも**実機で位置更新が止まる**可能性がある。このアプリの根幹機能 | **実機確認が必須**(この環境では不可) |
| H7 | geolocator 14(メジャー更新)が実機の測位で従来どおり動く | 同上。`docs/gps-location-stability.md` の平滑化まわりに影響しうる | 実機確認 |
| H8 | Flutter更新に伴う `dart format` の出力差分が、既存コードに広く発生する | `ci.yml:15-16` が明記している既知のリスク。外れれば差分が小さくて済むだけ | Flutter更新PRの `dart format` ジョブ |
| H9 | #105 が先にマージされると、device_info_plus が直接依存でなくなるためDependabotが **#88 を自動クローズする** | **外れても損はしない**(#88 の順序を気にしなくてよくなるだけ)。当たった場合だけ、13.2.0 へ上げ直す手間が増える | **検証しないのが最善**——#88 を先にマージすれば当たり外れに関係なく済む。あえて確かめるなら #105 を先に入れて #88 の状態を見る |

**F3により、以前「Flutterを上げれば minSdk が黙って上がるかもしれない」という懸念は
3.47.5 に関しては消えている**(24で不変)。より先のバージョンへ上げるときは再確認が要る。

---

## 3. 更新の順序案(比較)

**F3(Flutter 3.47.5 でも compileSdk は36)により、3つの軸はほぼ独立**になった。

- **KGP** … プラグインを上げる。**いまのFlutterのままでも着手できる**(F9)
- **compileSdk 37 → permission_handler 13** … `build.gradle.kts:20` に1行。Flutterと無関係
- **Flutter 3.47.5 → very_good_analysis 11** … 上2つと無関係

したがって論点は主に「どれを**先に**やるか」であり、**確定した強制順序は無い**。
ただし H4(KGP警告がエラー化するFlutterのバージョン)が外れた場合に限り、
「KGP → Flutter」の順序が強制される。推奨案がこの順になっているのはそのためでもある。

| | **案A: Flutter先行** | **案B: KGP先行(推奨)** | **案C: compileSdk先行** |
|---|---|---|---|
| **順序** | ① Flutter 3.47.5(`.metadata`/`ci.yml:19`/`Dockerfile:7`)→ ② vga 11(#87)→ ③ compileSdk 37 → permission_handler 13(#90)→ ④ KGP | ① 緑のPRを取り込む(#82,#83,#84,#86 → **#88 → #105**)→ ② #89 → ③ KGP残り3つ → ④ compileSdk 37 → #90 → ⑤ Flutter 3.47.5 → #87 → ⑥ #85 | ① compileSdk 37 → permission_handler 13(#90)→ ② Flutter 3.47.5 → vga 11 → ③ KGP |
| **最初の一手で解けるブロッカー** | vga 11(#87) | KGP警告 5→4(F6)＋Dependabotの枠が空く(1-4。枠が原因かは推論) | permission_handler 13(#90) |
| **最初の一手の大きさ** | **中**。Android SDK値は動かない(F3)が、`.metadata`/CI/Dockerfileの3箇所同時＋`dart format` 差分(H8)が1本に載る | **小**。1PR＝1プラグイン。どれも既にCIで緑(F10)か、CIログで即判定できる(H2) | **小**。`build.gradle.kts:20` に1行。ただしH1が外れるとAGP/Gradle更新へ膨らむ |
| **依拠する仮説(進行順)** | ①でH4, H8 | ①でH9 → ②でH6 → ③でH2(外れてもCIログで即分かる)→ ④でH1 | ①で**H1**(外れるとH3へ連鎖) |
| **CIだけで検証できるか** | 可。ただし失敗時に**どの要素が原因か切り分けにくい** | **可**。1ステップ＝1PRで、APKビルドとKGP警告ログが毎回判定する | 可。1行なので切り分けは容易 |
| **失敗したときの戻し方** | Flutter更新PR全体をまとめて revert。中間状態が無い | **1本ずつ revert できる** | 1行を revert |
| **最大のリスク** | H4が外れると、**Flutter更新PRの中でKGPがエラー化する**。同じPRにformat差分も同居しているため、何が原因で落ちたのか読み解くコストが高い | ③が空振り(H2)しても、①②の成果(KGP 5→3、枠の解放、Node 20非推奨の解消)は残る | ブロッカーは1つ解けるが、**期限のあるKGP(H4)に一切手を付けないまま時間が経つ** |
| **評価** | 一手で動くが、切り分けと巻き戻しが最も苦しい | **各ステップが独立に検証・巻き戻し可能**。期限のある項目を先に潰す | 安いが、KGPを後回しにする点が弱い。**案Bの④として取り込める** |

### 推奨: 案B(KGP先行)

決め手は3つ。

1. **KGPだけが「期限のある」項目だから。** 警告本文は
   `Future versions of Flutter will fail to build if your app uses plugins that apply KGP.`
   と言っており、放置すると**いずれFlutterを上げられなくなる**。
   一方 compileSdk 37 も vga 11 も、こちらの都合で先送りできる(困るのはDependabot PRが
   滞留することだけ)。**期限のあるものから潰す。**
2. **ステップごとに実機なしで判定できる。** `ci.yml:106` がAPKを実際に組み、KGP警告を
   ログに出す。F6/F7 がまさにこの方法で得られた実測である。
   案Bの①〜④は**全ステップをこの環境から検証できる**(H6/H7の実機確認を除く)。
3. **巻き戻しが1本単位になる。** AGENTS.md 安全ルール1が禁じる破壊的操作を使わず、
   `git revert` 1本で戻せる粒度を保てる。案A①は Flutter 3箇所＋`dart format` 差分が
   1本のPRに同居するため、この粒度が作れない。

なお **案Aを避ける理由は「復旧できなくなるから」ではない**。仮にH4が外れて 3.47 で
KGPがエラー化しても、F9のとおりプラグインを上げれば前進方向で復旧できる。
避けたいのは**復旧不能**ではなく、**Flutter更新とプラグイン更新が同一PRに同居して
切り分けが効かなくなること**である。

### 案Bで最初にやること(1PRずつ)

1. **#82 / #83 / #84 / #86 をマージ**(全部緑。#83/#84 はNode 20非推奨の解消も兼ねる — F15)
2. **#88(device_info_plus 13.2.0)をマージ。** KGP 5 → 4(F6)
3. **その後で #105(`deviceId` 削除)をマージ。** 順序を逆にすると #88 が自動クローズされ、
   device_info_plus のKGP解消がやりにくくなる(1-3節)
4. **#89(flutter_foreground_task 11)を実機確認のうえマージ**(H6)。ここまででKGP警告は 5 → 3
5. flutter_ble_peripheral 3.1.0 / sensors_plus 7.1.0 / wifi_scan 0.5.0 を**1本ずつ**上げ、
   各PRのAPKビルドログでKGP警告が減るかを確認(H2の検証)。0件になったら
   `android/gradle.properties:4,6` のフラグを `true` にできるか試す(H5)
6. **`android/app/build.gradle.kts:20` に `compileSdk = 37` を明示するPR**(H1の検証)。
   通れば #90(permission_handler 13)をマージ。落ちたらAGPの調査へ(H3)
7. **Flutter 3.47.5**(`.metadata` / `ci.yml:19` / `Dockerfile:7` の3箇所同時)→ #87(vga 11)
8. **#85(geolocator 14)** … `package_info_plus` のKGP(F8)を受け入れるかを判断してから

**6 と 7 は互いに独立**(F3のとおり compileSdk と Flutter は連動しない)なので、
手が足りれば並行できる。

---

## 4. 開いているDependabot PRの扱い

| PR | 内容 | CI(check / build) | 判定 | 理由 |
|---|---|---|---|---|
| **#82** | actions/checkout 6 → 7 | 緑 / 緑 | **すぐ取り込む** | 影響がCIに閉じている。全ジョブ緑 |
| **#83** | actions/setup-java 4 → 6 | 緑 / 緑 | **すぐ取り込む** | `setup-java@v4` に既にNode 20非推奨の警告が出ている(F15)。上げるほうが安全 |
| **#84** | actions/cache 4 → 6 | 緑 / 緑 | **すぐ取り込む** | 同上 |
| **#86** | vibration 3.2.0 → 3.2.1 | 緑 / 緑 | **すぐ取り込む** | パッチ更新。KGP警告に影響なし(依存先の `vibration_platform_interface` は変わらない — F14) |
| **#88** | device_info_plus 11.5.0 → 13.2.0 | 緑 / 緑 | **すぐ取り込む(#105 より先に)** | KGP警告を解消する(F6)。**#105 は device_info_plus を消さない**(F13)ので、#88 は不要にならない。ただし #105 が先に入ると直接依存でなくなりDependabotが自動クローズしうるため、**順序が重要**(1-3節。この自動クローズ自体は未検証の仮説H9) |
| **#89** | flutter_foreground_task 10.0.0 → 11.0.3 | 緑 / 緑 | **実機確認のうえ取り込む** | KGP警告を解消する(F7)＝案Bの本命の1本。ただしメジャー更新で、位置・センサーの常時取得を担うフォアグラウンドサービスそのもの(H6)。CI緑だけで入れない |
| **#85** | geolocator 13.0.4 → 14.0.2 | 緑 / 緑 | **待つ**(KGP片付け後) | CIは緑だが `package_info_plus` を持ち込んでKGP警告を6件に増やす(F8)。KGPを潰し切る前に入れると逆行する。加えてメジャー更新で測位挙動に直結(H7)。なお上流は既に 14.0.3 が出ており、Dependabotのrebaseで対象版は動きうる |
| **#87** | very_good_analysis 10.3.0 → 11.0.0 | **赤 / 赤** | **待つ**(Flutter 3.47.5 後) | Dart 3.13.0 が要る(F1)。こちらでは解決不能。取り込むのはFlutter更新の直後。infoが増えてもCIは落ちない(F12)ので、Flutterさえ上がれば素直に入るはず |
| **#90** | permission_handler 11.4.0 → 13.0.2 | 緑 / **赤** | **待つ**(`compileSdk = 37` の明示後) | `build.gradle.kts:20` に `compileSdk = 37` を足せば解ける見込み(F2)。**Flutter更新では解けない**(F3)。AGP更新が要るかは未確定(F4, H1) |

**閉じるべきPRは1本も無い**。開いたままにしておけばDependabotがrebaseし続ける。
ただし `open-pull-requests-limit: 5`(`.github/dependabot.yml:14`)の枠を塞いでおり、
**新しい更新の検知を止めている可能性が高い**(1-4節。断定はできない)。
#82,#83,#84,#86,#88 を取り込めば枠が空き、
`flutter_ble_peripheral` / `sensors_plus` / `wifi_scan` の新版(F9)が
Dependabot経由でも見えるようになる。

**注意**: #83〜#86 と #90 の `review` ジョブが赤いのは、`Workflow initiated by non-human actor:
dependabot (type: Bot)` によるブロックであって、**コードの問題ではない**(F11)。
マージ可否の判断材料にしないこと。

---

## 5. このレポートで決まっていないこと

次に着手する人が最初に調べるべき順。**上2つはこの環境からでも確かめられる**。

1. **AGP 9.0.1 のまま `compileSdk = 37` が通るか**(H1)。`android/app/build.gradle.kts:20` に
   1行足したPRを出し、`ci.yml:106` のAPKビルドを見るだけ。**最も安く、#90 の行方が決まる**
2. **3プラグインの新版がKGPを解消するか**(H2)。同じくPRを出してビルドログを読む
3. **H1が外れた場合に、compileSdk 37 を扱えるAGPが出ているか**(H3)。
   このコンテナからは `dl.google.com` に到達できず未確認。AGPのリリースノートを見るのが早い
4. **KGP警告がエラーになるFlutterのバージョン**(H4)。案Bを採るならリスクは下がるが、
   期限を知っておく価値はある

実作業(プラグイン更新・compileSdk更新・Flutter更新)は**別issue**に切ること。
このレポートは方針の確定までを担当範囲とする(#100 のスコープ)。
