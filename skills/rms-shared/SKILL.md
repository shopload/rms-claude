---
name: rms-shared
description: "rms-cli のセットアップ・認証タスクに使用する。auth login/status/logout、プロファイル管理（複数ショップの切り替え）、資格情報の不足・エラー対処、doctor による接続診断。他の rms-* スキルを使う前に必ず本スキルを読むこと。"
metadata:
  requires:
    bins: ["rms-cli"]
  cliHelp: "rms-cli --help"
---

# rms-cli 共有ルール

本スキルは `rms-cli` を通じて楽天RMS WEB SERVICEを操作する際の認証・共通ルールを定める。

## セットアップ（初回）

```bash
# 1. プロファイルを作成して認証情報を登録する
rms-cli auth login --profile <name> --service-secret <secret> --license-key <key>

# 2. 動作確認（APIを呼んで実際に確認する）
rms-cli auth status --verify

# 3. ショップ情報の確認
rms-cli whoami
```

`serviceSecret` と `licenseKey` は楽天RMSのメンバーズステーションで確認できる。

## 認証クイックリファレンス

| ユーザーの意図 | コマンド |
|---|---|
| 初回セットアップ | `rms-cli auth login --profile <name> --service-secret <s> --license-key <k>` |
| 現在の認証情報を確認（ローカルのみ） | `rms-cli auth status` |
| APIへの疎通を確認 | `rms-cli auth status --verify` |
| 現在のショップを確認 | `rms-cli whoami` |
| 認証情報を削除 | `rms-cli auth logout [--profile <name>]` |
| 接続の総合診断 | `rms-cli doctor` |

## プロファイル管理（複数ショップ）

複数の楽天ショップを扱う場合、プロファイルで切り替える。

```bash
# プロファイルを追加
rms-cli profile add <name> --service-secret <s> --license-key <k> [--label "店舗A"]

# 一覧表示
rms-cli profile list

# アクティブプロファイルを切り替え
rms-cli profile use <name>

# 特定プロファイルで一時的にコマンドを実行
rms-cli --profile <name> item search --title "sample"

# プロファイルを削除
rms-cli profile remove <name>
```

**重要**: ユーザーが明示的に依頼しない限り、プロファイルを切り替えたり削除したりしてはならない。プロファイルの切り替えは、以降の全コマンドが操作するショップを変更する。

## 環境変数による認証

設定ファイルよりも環境変数が優先される。

```bash
RMS_SERVICE_SECRET=<secret> RMS_LICENSE_KEY=<key> rms-cli item search --title "test"
```

## リスクレベルと安全操作

各コマンドの `--help` にリスクレベルが表示される：

| レベル | 表示 | 動作 |
|---|---|---|
| 読み取り | `[read]` | 常に実行可能 |
| 書き込み | `[write]` | 常に実行可能 |
| 高リスク書き込み | `[high-risk-write]` | `--yes` フラグが必須 |

`--yes` なしで `[high-risk-write]` を呼ぶと exit 非ゼロで失敗する。**必ずユーザーに確認を取ってから `--yes` を付けて再実行すること。** 絶対に黙って `--yes` を付けて再試行してはならない。

```bash
# 事前確認（APIは呼ばない）
rms-cli item delete --manage-number abc123 --dry-run

# ユーザー確認後に実行
rms-cli item delete --manage-number abc123 --yes
```

## `--dry-run`（必ず活用する）

`--dry-run` を付けると HTTP リクエストの詳細（URL・メソッド・ボディ）を表示するがAPIは呼ばない。書き込み・高リスク操作の前に必ず使ってユーザーに内容を確認させること。

## `--data`（複雑な構造体の渡し方）

型がフラットなスカラーでないフィールド（ネスト構造、スライス、マップ）はフラグではなく `--data` で渡す。`--help` に「These fields have no flag — set them via `--data`」と表示される。

```bash
# リテラルJSON
rms-cli inventory bulk-get --data '{"inventories":[{"manageNumber":"abc","variantId":"00001"}]}'

# ファイルから読む
rms-cli item upsert --data @request.json

# stdinから読む
cat request.json | rms-cli item upsert --data -
```

フラグと `--data` を同時に指定した場合、フラグが優先される（`--data` は未設定フィールドを補完する）。

## `--jq`（出力フィルタリング）

**重要: フィールド名は API 種別によって異なる**。

| サービス | API 形式 | `--jq` フィールド名 | 例 |
|---|---|---|---|
| coupon, shop | XML（json タグなし） | **PascalCase** | `.Coupons.CouponList[].CouponCode` |
| item, inventory, order, cabinet | JSON（json タグあり） | **camelCase** | `.results[].item.manageNumber` |

**`--jq` を使う前に必ず `--jq` なしで生レスポンスを確認してフィールド名を把握すること。**

```bash
# まず生レスポンスで構造を確認する（必須）
rms-cli coupon search --data '{}'

# 確認後、正しい PascalCase フィールド名で jq を書く
rms-cli coupon search --data '{}' \
  --jq '.Coupons.CouponList[] | {code: .CouponCode, name: .CouponName}'
```

**注意**: リストフィールドが `null`（結果なし）の場合は `cannot iterate over: null` エラーになる。`// []` で null-safe にする:

```bash
# NG: フィールドが null だと失敗する
--jq '.Coupons.CouponList[] | .CouponCode'

# OK: null の場合は空配列として扱う
--jq '(.Coupons.CouponList // []) | .[] | .CouponCode'
```

## エラーエンベロープ

失敗時は構造化エラーが **stderr** に出力され、exit 非ゼロで終了する：

```json
{
  "type": "api_error",
  "subtype": "unauthorized",
  "message": "...",
  "hint": "...",
  "http_status": 401,
  "request_id": "..."
}
```

- `type` / `subtype` — エラー分類（次のアクションを判断するために使う）
- `hint` — 修正方法のヒント（必ず参照する）
- `http_status` 401 / 403 → 認証情報を確認して `rms-cli auth status --verify` を実行
- `http_status` 429 → レート制限。リトライは指数バックオフで
- `http_status` 5xx → 楽天側の一時エラー。再試行可

## コマンド探索

```bash
rms-cli <service> --help                 # サービスのメソッド一覧（リスクレベル付き）
rms-cli <service> <method> --help        # フラグ・型・--data 対象フィールドの確認
rms-cli api GET <path>                   # 型付きコマンドがないエンドポイントへの生リクエスト
```
