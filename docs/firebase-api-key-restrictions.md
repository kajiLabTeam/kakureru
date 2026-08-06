# Firebase APIキー制限 手順書

対象プロジェクト: `kakureru-b8545`（Android専用、[AGENTS.md](../AGENTS.md) 参照）

## 前提

Firebase/Google CloudのAPIキーはアクセス制御に使われない。「どのFirebaseプロジェクトへのリクエストか」を識別するだけの文字列で、公開されても即座に不正アクセスにつながるものではない（`google-services.json` や `lib/firebase_options.dart` をリポジトリにコミットしてよいのはこのため）。

実際のアクセス制御は次の3層で行う。このうち本手順書が扱うのは1のみ。2・3はコード側で対応済み。

1. **APIキー制限**（本手順書） — このキーを使えるアプリ・使えるAPIを絞る
2. **Security Rules** — [`database.rules.json`](../database.rules.json) で、認証済みかつ本人のデータのみ読み書き可能にする
3. **Firebase Authentication** — 匿名サインイン（`lib/main.dart`）でリクエストごとに `auth.uid` を持たせる

APIキー制限だけに頼らないこと。上記1〜3は独立した防御層であり、どれか一つが漏れても他が残る設計にする。

## 手順1: 対象のAPIキーを特定する

1. `android/app/google-services.json` を開き、`client[0].api_key[0].current_key` の値を確認する（`AIzaSy` から始まる文字列）
2. https://console.cloud.google.com/apis/credentials?project=kakureru-b8545 を開く
3. 認証情報の一覧に、手順1と同じ値を持つAPIキーがある（通常「Android用キー（自動作成）」のような名前）。それを選択して編集画面を開く

このプロジェクトはAndroid専用アプリが1つだけなので、キーも1つのはず。複数ある場合は、`current_key` の値で一致するものだけを対象にする（無関係なキーを誤って制限しないこと）。

## 手順2: アプリケーションの制限

編集画面の「アプリケーションの制限」で **Androidアプリ** を選択し、「項目を追加」から以下を登録する。

| 項目 | 値 |
|---|---|
| パッケージ名 | `me.nenex.kakureru` |
| SHA-1証明書フィンガープリント | `51:E4:61:FB:22:1A:56:35:5D:19:73:06:31:7B:B6:C7:55:A5:20:39` |

この SHA-1 は `cd android && ./gradlew signingReport` の `:app:signingReport` タスクで取得したもの（2026-08-06時点）。

**注意**: 現在 `android/app/build.gradle.kts` の `release` ビルドタイプは `signingConfigs.getByName("debug")` を使っており（33〜35行目にTODOコメントあり）、`debug` / `release` / `profile` の全バリアントが同じデバッグ鍵で署名されている。そのためSHA-1は1つしか存在しない。

**今後リリース用の署名鍵（`.jks`）を作成したら**、その鍵の SHA-1 を `./gradlew signingReport` で再取得し、上記の表に**追加**すること（既存のデバッグ鍵の行は開発中は残してよい）。登録を忘れると、リリースビルドがAPIキー制限に弾かれてFirebaseにアクセスできなくなる。

## 手順3: APIの制限

同じ編集画面の「APIの制限」で「キーを制限」を選び、現在このアプリが使っているAPIだけを許可リストに追加する。

| API | 用途 |
|---|---|
| Identity Toolkit API (`identitytoolkit.googleapis.com`) | `firebase_auth` — 匿名サインイン |
| Token Service API (`securetoken.googleapis.com`) | `firebase_auth` — IDトークンの検証・更新 |
| Firebase Installations API (`firebaseinstallations.googleapis.com`) | `firebase_core` — アプリインスタンスの識別（内部依存） |
| Firebase Realtime Database API (`firebasedatabase.googleapis.com`) | `firebase_database` — RTDBの読み書き |

上記以外（Maps、Places等）はこのアプリで一切使っていないので許可リストに入れない。使っていないAPIを許可すると、キーが漏れた際の被害範囲が不要に広がる。

### 将来追加が必要なAPI

[`docs/rtdb-schema.md`](rtdb-schema.md) の `photos/{photoId}/storagePath` は、写真アップロード機能でCloud Storageを使う設計になっている。`pubspec.yaml` に `firebase_storage` を追加してこの機能を実装したら、このタイミングで以下もAPI制限リストに追加すること。

| API | 用途 |
|---|---|
| Firebase Storage API (`firebasestorage.googleapis.com`) | `firebase_storage` — 写真のアップロード・ダウンロード |

Cloud Storage側のSecurity Rules（`storage.rules`）も別途必要になる（RTDBの `database.rules.json` とは独立した設定）。

## 手順4: 保存と反映確認

「保存」をクリックする。反映まで数分かかることがある。反映後、アプリで匿名サインイン→RTDB読み書きが今まで通り動くことを確認する（制限を間違えると `google-services.json` は正しいのにFirebase呼び出しが403で失敗するようになるため）。

## この制限が防ぐこと・防がないこと

- **防ぐ**: このキーを他人が抜き取って、無関係なAndroidアプリや別のAPIから使う（例: 他プロジェクトのMaps APIの請求を肩代わりさせられる、等）
- **防がない**: 正規の `me.nenex.kakureru` アプリ自体からの不正なデータアクセス。これは [`database.rules.json`](../database.rules.json) の役割
