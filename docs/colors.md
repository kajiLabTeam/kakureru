# カラーパレット

アプリで使う主な色のまとめ。**値の正本はコード**（下の「定義場所」）で、このファイルはそこから拾った一覧。色を変えたらここも更新する。

## 役割の色（赤・緑）

| 色 | コード | 用途 | 定義場所 |
|---|---|---|---|
| 赤（鬼） | `#E5484D` | ピン・点などの小さな面、エリア外警告 | `lib/features/room/role_theme.dart` |
| 赤（鬼・濃） | `#C0343A` | 白文字を載せるヘッダー帯、新着バッジ | `role_theme.dart` / `game_palette.dart` |
| 緑（逃走者） | `#4A9C5D` | ピン・点などの小さな面 | `role_theme.dart` |
| 緑（逃走者・濃） | `#3A7F4A` | 白文字を載せるヘッダー帯 | `role_theme.dart` |

濃い方があるのは、`#4A9C5D` の上の白文字がコントラスト 3.4:1 しかなく読みにくいため。白文字を載せる面には濃い方を使う。

## ベージュ系（画面の地・枠）

| 名前 | コード | 用途 |
|---|---|---|
| `gameBackground` | `#F5F3EE` | 画面の地（ベージュ） |
| `gameBorder` | `#E3E0D9` | カード・帯の枠線 |
| `gameSoftBorder` | `#EDEAE2` | カード内の小さな区切り |
| `gameTrack` | `#F1EFE9` | メーターの溝・中立のタグ |
| `gameSelected` | `#EAE7DF` | 選択中のタブ・無効ボタンの地 |
| `gameEmptyDot` | `#D8D5CC` | 塗られていない点・進捗バー |
| `gameHint` | `#F7F6F2` | 手がかりカード内の案内枠の下地 |

定義場所: `lib/features/room/view/game/game_palette.dart`

## 文字色

| 名前 | コード | 用途 |
|---|---|---|
| `gameInk` | `#1B1B19` | 本文。ゲーム系画面の `colorScheme.primary` |
| `gameInkSoft` | `#4A483F` | 灰色の見出し・説明文 |
| `gameMuted` | `#6B6A64` | 補助テキスト |
| `gameFaint` | `#8A8880` | さらに弱い補助テキスト |

## 注意（黄系）

| 名前 | コード | 用途 |
|---|---|---|
| `gameNoticeBackground` | `#FFF6E2` | 注意バナーの地 |
| `gameNoticeSoftBackground` | `#FFFAEF` | 注意枠の下地 |
| `gameNoticeBorder` | `#E8D5A8` | 注意の枠 |
| `gameNoticeInk` | `#6B5210` | 注意の本文 |
| `gameNoticeSubInk` | `#7A6528` | 注意の補足文 |
| `gameNoticeAccent` | `#8A6A16` | 注意のアイコン・強調 |

## アプリ全体のテーマ

`lib/core/theme/app_theme.dart`。シードカラーは `appInk` (`#2B2B2B`)、補助に `appMuted` (`#888888`)・`appFaintBorder` (`#EEEEEE`)。ホーム・設定・待機・結果の各画面は `game_tone_theme.dart` で上記ベージュ系に上書きされる。

## その他

- ガチャ画面: 熱の赤 `#B0272C`（`gachaHeatRed`）。赤・緑は役割の色と同じ `#E5484D` / `#4A9C5D`（`lib/features/mission/view/gacha/gacha_page.dart`）
- UIモック: `docs/ui-mockup-2a.html`
