---
name: rms-order
description: "楽天RMS 受注管理。注文の検索・取得（search-order, get-order）、注文確認（confirm-order）、配送情報の更新（update-order-shipping, update-order-shipping-async）、注文キャンセル（cancel-order）、メモ・備考・注文者情報・送付先の更新。注文処理、出荷対応、受注データの確認が必要なときに使用する。"
metadata:
  requires:
    bins: ["rms-cli"]
  cliHelp: "rms-cli order --help"
---

# order（受注管理）

**CRITICAL — 開始前に必ず [`../rms-shared/SKILL.md`](../rms-shared/SKILL.md) を読むこと。認証・リスクレベル・--data の使い方が書かれている。**

## コアコンセプト

- **orderNumber** — 注文番号。楽天が発行する注文の識別子。
- **注文ステータス（orderProgress）** — 100:注文確認待ち, 200:楽天処理中, 300:発送待ち, 400:変更確定待ち, 500:発送済, 600:支払い手続き中, 700:支払い完了
- **日時フォーマット** — `2024-01-15T00:00:00+0900` の形式（コロンなし `+0900`）。`+09:00` は 400 エラーになるので注意。
- **検索可能期間** — 過去730日以内の注文のみ。730日より古い日付を指定すると 400 エラーになる。EndDatetime は StartDatetime から 63 日以内。
- **出力フィールドは camelCase** — order は JSON API（json タグあり）のため、`--jq` で使うフィールド名は camelCase（例: `.orderNumberList[]`）。coupon の PascalCase とは異なる。
- **`--date-type` は必ず明示する** — 省略すると `dateType: 0` が送られ、**エラーにならず常に0件が返る**。特に `orderProgressList` でステータス絞り込みをする際、実際には該当注文があるのに「滞留なし」と誤読する事故になる。通常は `--date-type 1`（注文日）を付ける。`--dry-run` で `"dateType":0` になっていないか確認できる。
- **0件時のレスポンス** — 検索結果0件のとき `PaginationResponseModel` は `{}` になり `orderNumberList` は存在しない。`--jq` は `// 0` / `// []` で null 安全に書く。

## 注文検索

`--data` で渡すフィールド: `orderProgressList`（ステータスリスト）, `subStatusIdList`, `orderTypeList`, `paginationRequestModel`

```bash
# 基本的な期間検索
rms-cli order search-order \
  --start-datetime "2024-01-01T00:00:00+0900" \
  --end-datetime "2024-01-31T23:59:59+0900" \
  --date-type 1

# ステータス絞り込み（発送待ちの注文）
rms-cli order search-order \
  --start-datetime "2024-01-01T00:00:00+0900" \
  --end-datetime "2024-01-31T23:59:59+0900" \
  --date-type 1 \
  --data '{"orderProgressList":[300]}'

# 注文番号のリストだけ取り出す
rms-cli order search-order \
  --start-datetime "2024-01-01T00:00:00+0900" \
  --end-datetime "2024-01-31T23:59:59+0900" \
  --date-type 1 \
  --jq '(.orderNumberList // [])[]'

# ページネーション
rms-cli order search-order \
  --start-datetime "2024-01-01T00:00:00+0900" \
  --end-datetime "2024-01-31T23:59:59+0900" \
  --data '{"paginationRequestModel":{"requestRecordsAmount":100,"requestPage":1}}'
```

`--date-type`: 1=注文日, 2=注文確認日, 3=発送日, 4=発送完了日

### 主な検索フラグ

| フラグ | 型 | 説明 |
|---|---|---|
| `--start-datetime` | string | 検索開始日時（必須） |
| `--end-datetime` | string | 検索終了日時（必須） |
| `--date-type` | int | 日付種別。**実質必須**（未指定だと `dateType: 0` が送られ常に0件になる。「1がデフォルト」ではない） |
| `--search-keyword` | string | フリーワード |
| `--orderer-mail-address` | string | 注文者メールアドレス |
| `--settlement-method` | int | 決済方法 |

## 注文詳細取得

```bash
# 1件取得（version は 3〜10、最新は 10）
rms-cli order get-order --data '{"orderNumberList":["123456-20240115-000001"],"version":10}'

# 複数件まとめて取得（最大100件）
rms-cli order get-order --data '{"orderNumberList":["ORDER-001","ORDER-002"],"version":10}'

# 決済情報の取得
rms-cli order get-payment --data '{"orderNumberList":["123456-20240115-000001"]}'
```

### get-order レスポンス構造と商品・SKU情報の取り出し方

**CRITICAL**: `get-order` のレスポンスは**混在ケース**。リスト型フィールドは **PascalCase**（`OrderModelList`, `PackageModelList`, `ItemModelList`, `SkuModelList`）、スカラーフィールドは **camelCase**（`manageNumber`, `itemName`, `variantId`）。`orderModelList`（小文字始まり）でアクセスすると null になる。

```bash
# 注文内の商品・SKU情報を取り出す（manageNumber と variantId）
rms-cli order get-order --data '{"orderNumberList":["123456-20240115-000001"],"version":10}' \
  --jq '.OrderModelList[].PackageModelList[].ItemModelList[] | {manageNumber: .manageNumber, itemName: .itemName, variantId: .SkuModelList[0].variantId, skuInfo: .SkuModelList[0].skuInfo}'

# 全注文の商品一覧をフラットに取り出す
rms-cli order get-order --data '{"orderNumberList":["ORDER-001","ORDER-002"],"version":10}' \
  --jq '[.OrderModelList[].PackageModelList[].ItemModelList[] | {manageNumber: .manageNumber, itemName: .itemName, variantId: .SkuModelList[0].variantId}]'
```

レスポンスの構造（抜粋）:
```
.OrderModelList[]              ← PascalCase（注文ごと）
  .orderNumber                 ← camelCase
  .PackageModelList[]          ← PascalCase（荷物ごと）
    .ItemModelList[]           ← PascalCase（商品行ごと）
      .manageNumber            ← camelCase ← item/inventory コマンドの主キー
      .itemName                ← camelCase
      .SkuModelList[]          ← PascalCase
        .variantId             ← camelCase ← inventory get-variant の第2引数
        .skuInfo               ← camelCase（色・サイズなどの表示テキスト）
```

## 注文確認

注文ステータスを「注文確認待ち(100)」から先に進める。

```bash
rms-cli order confirm-order --data '{"orderNumberList":["123456-20240115-000001"]}'
```

## 配送情報の更新

### 通常（同期）

```bash
rms-cli order update-order-shipping --data '{
  "orderShippingModelList": [{
    "orderNumber": "123456-20240115-000001",
    "shippingDate": "2024-01-16",
    "shippingNumber": "1234567890",
    "deliveryCompany": "yamato"
  }]
}'
```

### 非同期（大量処理向け）

```bash
# リクエスト送信（resultIdが返る）
rms-cli order update-order-shipping-async --data '{
  "orderShippingModelList": [{...}]
}'

# 結果確認
rms-cli order get-result-update-order-shipping-async --result-id "<resultId>"
```

## 注文情報の更新

```bash
# メモ更新
rms-cli order update-order-memo --order-number "xxx" --memo "対応済み"

# 備考更新
rms-cli order update-order-remarks --order-number "xxx" --remarks "配送変更依頼あり"

# 注文者情報更新
rms-cli order update-order-orderer --order-number "xxx" --data '{"ordererModel":{...}}'

# 送付先更新
rms-cli order update-order-sender --order-number "xxx" --data '{"senderModel":{...}}'

# 配送先更新（発送後）
rms-cli order update-order-sender-after-shipping --order-number "xxx" --data '{"senderModel":{...}}'

# 配送方法更新
rms-cli order update-order-delivery --order-number "xxx" --data '{"deliveryModel":{...}}'

# サブステータス更新
rms-cli order update-order-sub-status --order-number "xxx" --sub-status-id 1

# 利用可能なサブステータス一覧
rms-cli order get-sub-status-list
```

## 注文キャンセル（高リスク）

```bash
# 事前確認
rms-cli order cancel-order --order-number "xxx" --dry-run

# ユーザー確認後に実行
rms-cli order cancel-order --order-number "xxx" --yes

# 発送後のキャンセル
rms-cli order cancel-order-after-shipping --order-number "xxx" --yes
```

## クーポン計算

```bash
rms-cli order simulate-coupon-amount --order-number "xxx" --data '{"couponId":"xxx"}'
```

## よくある操作パターン

### 当日の未確認注文を確認する

```bash
TODAY=$(date +%Y-%m-%d)
rms-cli order search-order \
  --start-datetime "${TODAY}T00:00:00+0900" \
  --end-datetime "${TODAY}T23:59:59+0900" \
  --date-type 1 \
  --data '{"orderProgressList":[100]}' \
  --jq '(.orderNumberList // [])'
```

### 発送待ち注文を取得して配送情報を更新する

```bash
# 発送待ち(300)の注文を検索（過去30日）
SINCE=$(date -v-30d +%Y-%m-%dT%H:%M:%S+0900)
TODAY=$(date +%Y-%m-%dT%H:%M:%S+0900)
rms-cli order search-order \
  --start-datetime "$SINCE" \
  --end-datetime "$TODAY" \
  --date-type 1 \
  --data '{"orderProgressList":[300]}' \
  --jq '(.orderNumberList // [])'

# 配送情報を更新（ドライランで確認してから）
rms-cli order update-order-shipping --dry-run --data '{...}'
rms-cli order update-order-shipping --data '{...}'
```

## コマンド一覧

| コマンド | リスク | 説明 |
|---|---|---|
| `order search-order` | read | 注文検索 |
| `order get-order` | read | 注文詳細取得 |
| `order get-payment` | read | 決済情報取得 |
| `order get-sub-status-list` | read | サブステータス一覧 |
| `order simulate-coupon-amount` | read | クーポン金額計算 |
| `order get-result-update-order-shipping-async` | read | 非同期配送更新の結果取得 |
| `order confirm-order` | write | 注文確認 |
| `order update-order-shipping` | write | 配送情報更新 |
| `order update-order-shipping-async` | write | 配送情報更新（非同期） |
| `order update-order-memo` | write | メモ更新 |
| `order update-order-remarks` | write | 備考更新 |
| `order update-order-orderer` | write | 注文者情報更新 |
| `order update-order-sender` | write | 送付先更新 |
| `order update-order-sender-after-shipping` | write | 送付先更新（発送後） |
| `order update-order-delivery` | write | 配送方法更新 |
| `order update-order-sub-status` | write | サブステータス更新 |
| `order cancel-order` | **high-risk-write** | 注文キャンセル |
| `order cancel-order-after-shipping` | **high-risk-write** | 注文キャンセル（発送後） |
