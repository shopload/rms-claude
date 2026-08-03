---
name: rms-item
description: "楽天RMS 商品・在庫管理。商品の検索・取得・登録・更新・削除（item）、バリアント在庫の参照・更新・一括取得（inventory）、商品セット管理（item-bundle）、定期購入商品（purchase-item）。商品情報の操作、在庫数の確認・変更、バリアント（SKU）管理が必要なときに使用する。"
metadata:
  requires:
    bins: ["rms-cli"]
  cliHelp: "rms-cli item --help"
---

# item / inventory（商品・在庫）

**CRITICAL — 開始前に必ず [`../rms-shared/SKILL.md`](../rms-shared/SKILL.md) を読むこと。認証・リスクレベル・--data の使い方が書かれている。**

## コアコンセプト

- **manageNumber** — 商品の管理番号（ショップ独自のID）。ほぼ全てのコマンドで主キーになる。
- **variantId** — バリアント（SKU）の識別子。同一商品の色・サイズなどのバリエーション。
- **バリアントと在庫は分離** — 商品情報（item）と在庫数（inventory）は別サービスで管理される。商品を作っても在庫を登録しないと「在庫なし」になる。
- **出力フィールドは camelCase** — item/inventory は JSON API（json タグあり）のため、`--jq` で使うフィールド名は camelCase（例: `.results[].item.manageNumber`, `.nextCursorMark`）。coupon とは異なる。

## 商品管理（item）

### 検索

```bash
# タイトルで検索
rms-cli item search --title "キーワード" --hits 20

# 管理番号で検索
rms-cli item search --manage-number "ABC-001"

# 非表示商品を含めて検索し、manageNumber だけ取り出す
rms-cli item search --is-hidden-item "true" --jq '.results[].item.manageNumber'

# カーソルマークでページネーション
rms-cli item search --hits 100 --jq '.nextCursorMark'
# → 次ページ: --cursor-mark <前回のnextCursorMark>
```

主なフラグ: `--title`, `--manage-number`, `--item-number`, `--category-id`, `--genre-id`, `--hits`（件数）, `--offset`, `--cursor-mark`, `--is-hidden-item`, `--sort-key`, `--sort-order`

### 1件取得

```bash
rms-cli item item-get --manage-number "ABC-001"
```

### 複数件一括取得

```bash
rms-cli item bulk-get --data '{"manageNumbers":["ABC-001","ABC-002"]}'
```

### 登録・更新（Upsert）

`<manage-number>` が存在すれば更新、なければ登録。フィールド数が多いため `--data` を使う。最初の位置引数が manage-number になる。

```bash
# 商品登録・更新（フィールド構造は事前に既存商品の item-get で確認する）
rms-cli item upsert "ABC-001" --data @item-request.json

# ドライラン（APIは呼ばない）
rms-cli item upsert "ABC-001" --data @item-request.json --dry-run
```

### 部分更新（Patch）

変更したいフィールドだけ指定できる。存在しないフィールドは変更されない。`<manage-number>` は位置引数で指定し、`--data` のキーは直接のフィールド名（camelCase）を使う。

```bash
# 商品を非表示にする（hideItem: true=非表示, false=表示）
rms-cli item patch "ABC-001" --data '{"hideItem":true}'

# タイトルだけ変更
rms-cli item patch "ABC-001" --data '{"title":"新しいタイトル"}'
```

### 削除（高リスク）

```bash
# 事前確認（<manage-number> は位置引数）
rms-cli item delete "ABC-001" --dry-run

# ユーザー確認後に実行
rms-cli item delete "ABC-001" --yes
```

### 在庫連動設定

```bash
# 在庫連動設定の取得（<manage-number> は位置引数）
rms-cli item inventory-related-settings-get "ABC-001"

# 在庫連動設定の更新（同様に位置引数）
rms-cli item inventory-related-settings-update "ABC-001" \
  --data '{"unlimitedInventoryFlag":false}'
```

## 在庫管理（inventory）

### バリアント在庫の一括取得

```bash
rms-cli inventory bulk-get --data '{
  "inventories": [
    {"manageNumber": "ABC-001", "variantId": "00001"},
    {"manageNumber": "ABC-001", "variantId": "00002"}
  ]
}'
```

### バリアント在庫の範囲取得（在庫数フィルタ）

在庫数の範囲で絞り込む。`--min-quantity`/`--max-quantity` フラグのみ対応（少なくとも一方が必須）。**結果が1000件を超えると400エラー**になるため、範囲を絞ること。

```bash
# 在庫がちょうど12個のバリアントを取得
rms-cli inventory bulk-get-range --min-quantity 12 --max-quantity 12

# 在庫50〜100個のバリアントを取得
rms-cli inventory bulk-get-range --min-quantity 50 --max-quantity 100
```

### バリアント取得・一覧

```bash
# 1バリアント取得
rms-cli inventory get-variant "ABC-001" "00001"

# 商品の全バリアント一覧
rms-cli inventory get-variant-list "ABC-001"
```

### バリアント在庫の登録・更新

モードは `ABSOLUTE`（絶対値設定）または `RELATIVE`（増減指定）。新規SKUは必ず `ABSOLUTE` を使う。

```bash
# 在庫を50個に設定（ABSOLUTE = 絶対値）
rms-cli inventory upsert-variant "ABC-001" "00001" --mode ABSOLUTE --quantity 50

# 在庫を5個増やす（RELATIVE = 増減）
rms-cli inventory upsert-variant "ABC-001" "00001" --mode RELATIVE --quantity 5

# リードタイムも設定（normalDeliveryTimeId はShopAPIで確認）
rms-cli inventory upsert-variant "ABC-001" "00001" --mode ABSOLUTE --quantity 50 \
  --data '{"operationLeadTime":{"normalDeliveryTimeId":18762}}'
```

### バリアント在庫の一括更新

最大400件まで一括更新。mode は `ABSOLUTE` または `RELATIVE`。

```bash
rms-cli inventory bulk-upsert --data '{
  "inventories": [
    {"manageNumber": "ABC-001", "variantId": "00001", "mode": "ABSOLUTE", "quantity": 100},
    {"manageNumber": "ABC-002", "variantId": "00001", "mode": "ABSOLUTE", "quantity": 50}
  ]
}'
```

### バリアント削除（高リスク）

```bash
rms-cli inventory delete-variant "ABC-001" "00001" --yes
```

## 商品セット管理（item-bundle）

```bash
rms-cli item-bundle --help
```

## 定期購入商品（purchase-item）

```bash
rms-cli purchase-item --help
```

## よくある操作パターン

### 商品の在庫を確認して更新する

```bash
# 1. 商品情報を確認
rms-cli item item-get --manage-number "ABC-001"

# 2. バリアント一覧を確認
rms-cli inventory get-variant-list "ABC-001"

# 3. 在庫数を確認
rms-cli inventory get-variant "ABC-001" "00001"

# 4. 在庫を更新
rms-cli inventory upsert-variant "ABC-001" "00001" --mode ABSOLUTE --quantity 100
```

### 複数商品の在庫をまとめて確認する

```bash
# 商品検索してmanageNumberを取得
rms-cli item search --category-id "xxx" --hits 50 --jq '[.results[].item.manageNumber]'

# bulk-getで一括取得（--data でリストを渡す）
rms-cli inventory bulk-get --data '{"inventories":[...]}'
```

## コマンド一覧

| コマンド | リスク | 説明 |
|---|---|---|
| `item search` | read | 商品検索 |
| `item item-get` | read | 商品1件取得 |
| `item bulk-get` | read | 商品複数件取得 |
| `item upsert` | write | 商品登録・更新 |
| `item patch` | write | 商品部分更新 |
| `item delete` | **high-risk-write** | 商品削除 |
| `item inventory-related-settings-get` | read | 在庫連動設定取得 |
| `item inventory-related-settings-update` | write | 在庫連動設定更新 |
| `inventory bulk-get` | read | 在庫一括取得 |
| `inventory bulk-get-range` | read | 在庫範囲取得 |
| `inventory get-variant` | read | バリアント取得 |
| `inventory get-variant-list` | read | バリアント一覧 |
| `inventory upsert-variant` | write | バリアント登録・更新 |
| `inventory bulk-upsert` | write | バリアント一括更新 |
| `inventory delete-variant` | **high-risk-write** | バリアント削除 |
