---
name: rms-shop
description: "楽天RMS ショップ設定・レイアウト管理。ショップ基本情報の取得（get-shop-master）、ショップステータス・営業時間・休業日の設定、レイアウト（共通・画像・テキスト）の取得・更新、ナビボタン、スマホページ（SP）設定、送料設定、カテゴリ管理（category-api）、楽天ジャンル情報取得（navigation）。ショップの見た目や設定の確認・変更が必要なときに使用する。"
metadata:
  requires:
    bins: ["rms-cli"]
  cliHelp: "rms-cli shop --help"
---

# shop / category-api / navigation（ショップ管理）

**CRITICAL — 開始前に必ず [`../rms-shared/SKILL.md`](../rms-shared/SKILL.md) を読むこと。認証・リスクレベル・--data の使い方が書かれている。**

## コアコンセプト

- **shop** — ショップの基本情報・レイアウト・設定を管理するサービス。多くの write 操作は重要な変更なので必ず `--dry-run` で確認してからユーザーの承認を得ること。
- **出力フィールドは PascalCase** — shop は XML API（json タグなし）のため `--jq` フィールドは PascalCase（例: `.Result.ShopMaster.ShopName`）。
- **category-api** — ショップカテゴリツリーの管理と、商品とカテゴリのマッピング。JSON API のため **camelCase**（例: `.categorySetKeyList`）。
- **navigation** — 楽天ジャンル（楽天が定めるカテゴリ体系）の情報取得。商品のジャンル属性確認に使う。

## ショップ基本情報

```bash
# ショップマスタ情報取得（PascalCase）
rms-cli shop get-shop-master

# 名前とURL抽出
rms-cli shop get-shop-master --jq '{name: .Result.ShopMaster.ShopName, url: .Result.ShopMaster.ShopUrl}'

# ショップステータス確認（<statusKey> は位置引数）
# statusKey 例: socialGiftParticipation, pcTopMigration
rms-cli shop get-shop-status "socialGiftParticipation"

# ショップステータス更新（<statusKey> は位置引数）
rms-cli shop edit-shop-status "socialGiftParticipation" --dry-run --data '{...}'
rms-cli shop edit-shop-status "socialGiftParticipation" --data '{...}'
```

## 営業時間・定休日

```bash
# 営業カレンダーと営業時間の取得
rms-cli shop get-shop-calendar-and-business-hours

# 休業日設定の取得
rms-cli shop get-shop-holiday

# 営業カレンダーと営業時間の更新
rms-cli shop edit-shop-calendar-and-business-hours --dry-run --data '{...}'
rms-cli shop edit-shop-calendar-and-business-hours --data '{...}'

# 休業日の設定
rms-cli shop edit-shop-holiday --dry-run --data '{...}'
rms-cli shop edit-shop-holiday --data '{...}'
```

## レイアウト管理

### 共通レイアウト

```bash
rms-cli shop get-shop-layout-common
rms-cli shop edit-shop-layout-common --dry-run --data '{...}'
rms-cli shop edit-shop-layout-common --data '{...}'
```

### 画像レイアウト

```bash
rms-cli shop get-shop-layout-image
rms-cli shop edit-shop-layout-image --dry-run --data '{...}'
rms-cli shop edit-shop-layout-image --data '{...}'
```

### テキストエリア（大）

```bash
rms-cli shop get-layout-text-large
rms-cli shop edit-layout-text-large --dry-run --data '{...}'
rms-cli shop edit-layout-text-large --data '{...}'
```

### その他レイアウト取得

```bash
rms-cli shop get-layout-text-small      # テキストエリア（小）
rms-cli shop get-layout-category-map    # カテゴリマップ
rms-cli shop get-layout-item-map        # アイテムマップ
rms-cli shop get-layout-loss-leader     # 目玉商品
```

## 看板・ナビボタン

```bash
# 看板
rms-cli shop get-signboard
rms-cli shop edit-signboard --dry-run --data '{...}'
rms-cli shop edit-signboard --data '{...}'

# ナビボタン
rms-cli shop get-navi-button
rms-cli shop edit-navi-button --dry-run --data '{...}'
rms-cli shop edit-navi-button --data '{...}'

# ナビボタン情報
rms-cli shop get-navi-button-info
rms-cli shop edit-navi-button-info --dry-run --data '{...}'
rms-cli shop edit-navi-button-info --data '{...}'
```

## スマホページ（SP）設定

```bash
rms-cli shop get-sp-big-banner          # ビッグバナー
rms-cli shop get-sp-small-banner        # スモールバナー
rms-cli shop get-sp-category-page       # カテゴリページ
rms-cli shop get-sp-item-page           # アイテムページ
rms-cli shop get-sp-medama-category     # 目玉カテゴリ
rms-cli shop get-sp-medama-item         # 目玉アイテム

# 更新（全て edit-sp-* で対応）
rms-cli shop edit-sp-big-banner --dry-run --data '{...}'
```

## 送料設定

```bash
rms-cli shop get-shop-area-soryo        # エリア別送料
rms-cli shop get-soryo-kbn              # 送料区分
rms-cli shop get-delivery-set-info      # 配送セット情報
rms-cli shop get-delivery-drop-off      # 宅配便受け取り設定
rms-cli shop get-delvdate-master        # 配送日数マスタ
rms-cli shop get-operation-lead-time    # 対応リードタイム
rms-cli shop get-ship-from              # 発送元

rms-cli shop edit-shop-area-soryo --dry-run --data '{...}'
rms-cli shop edit-shop-area-soryo --data '{...}'
```

## カテゴリ管理（category-api）

category-api は JSON API のため出力は **camelCase**。

### カテゴリセット・ツリー

```bash
# カテゴリセット一覧取得（positional arg なし）
rms-cli category-api get-category-set-lists
# → .categorySetKeyList でセットIDリストを取得

# カテゴリツリー取得（<categorySetId> は位置引数）
rms-cli category-api get-category-tree "0"

# カテゴリツリーのUpsert
rms-cli category-api upsert-category-tree "0" --dry-run --data '{"children":[...]}'
rms-cli category-api upsert-category-tree "0" --data '{"children":[...]}'
```

### ショップカテゴリ

```bash
# ショップカテゴリの取得（<categoryId> は位置引数）
rms-cli category-api get-shop-category "0000000111"

# ショップカテゴリの新規作成（位置引数なし）
rms-cli category-api insert-shop-category --data '{...}'

# ショップカテゴリの更新（<categoryId> は位置引数）
rms-cli category-api update-shop-category "0000000111" --data '{...}'
```

### 商品とカテゴリのマッピング

```bash
# 商品のカテゴリマッピングを取得（<manageNumber> は位置引数）
rms-cli category-api get-item-mapping "ABC-001"

# カテゴリマッピングをUpsert（<manageNumber> は位置引数、categoryIds を --data で指定）
rms-cli category-api upsert-item-mapping "ABC-001" --data '{"categoryIds":["0000000111"]}'

# カテゴリマッピングを削除（高リスク）（<manageNumber> は位置引数）
rms-cli category-api delete-item-mapping "ABC-001" --yes
```

## 楽天ジャンル情報（navigation）

navigation は**楽天が定めるジャンル体系**（楽天ジャンルID）の取得。ショップの独自カテゴリとは別物。商品の `genreId` 確認・属性辞書参照に使う。

```bash
# ジャンルデータのバージョン確認
rms-cli navigation get-version

# ジャンル情報取得（<genreId> は int の位置引数）
rms-cli navigation get-genre 100371

# ジャンルの属性一覧取得
rms-cli navigation get-genre-attributes 100371

# 属性の辞書値取得（<genreId> <attributeId> の位置引数）
rms-cli navigation get-genre-attribute-dictionary-values 100371 "color"
```

## よくある操作パターン

### ショップの現在の設定を確認する

```bash
# 基本情報
rms-cli shop get-shop-master --jq '{name: .Result.ShopMaster.ShopName, url: .Result.ShopMaster.ShopUrl}'

# 営業ステータス
rms-cli shop get-shop-status "socialGiftParticipation"

# 営業時間
rms-cli shop get-shop-calendar-and-business-hours
```

### レイアウトを更新する際のフロー

```bash
# 1. 現在の設定を取得して構造を確認
rms-cli shop get-shop-layout-common

# 2. ドライランで変更内容を確認
rms-cli shop edit-shop-layout-common --dry-run --data @updated-layout.json

# 3. ユーザーの承認を得てから実行
rms-cli shop edit-shop-layout-common --data @updated-layout.json
```

### 商品をカテゴリに割り当てる

```bash
# 1. カテゴリセットIDを確認
rms-cli category-api get-category-set-lists --jq '.categorySetKeyList'

# 2. カテゴリツリーを確認
rms-cli category-api get-category-tree "0"

# 3. 商品をカテゴリに割り当て
rms-cli category-api upsert-item-mapping "ABC-001" --data '{"categoryIds":["0000000111"]}'
```

## コマンド一覧

| コマンド | リスク | 説明 |
|---|---|---|
| `shop get-shop-master` | read | ショップマスタ情報（PascalCase） |
| `shop get-shop-status <statusKey>` | read | ショップステータス（位置引数） |
| `shop get-shop-calendar-and-business-hours` | read | 営業カレンダー・営業時間 |
| `shop get-shop-holiday` | read | 休業日設定 |
| `shop get-shop-layout-common` | read | 共通レイアウト |
| `shop get-shop-layout-image` | read | 画像レイアウト |
| `shop get-layout-text-large` | read | テキストエリア（大） |
| `shop get-layout-text-small` | read | テキストエリア（小） |
| `shop get-navi-button` | read | ナビボタン |
| `shop get-navi-button-info` | read | ナビボタン情報 |
| `shop get-signboard` | read | 看板 |
| `shop edit-shop-status <statusKey>` | write | ショップステータス更新（位置引数） |
| `shop edit-shop-calendar-and-business-hours` | write | 営業時間更新 |
| `shop edit-shop-holiday` | write | 休業日更新 |
| `shop edit-shop-layout-common` | write | 共通レイアウト更新 |
| `shop edit-shop-layout-image` | write | 画像レイアウト更新 |
| `shop edit-layout-text-large` | write | テキストエリア（大）更新 |
| `shop edit-navi-button` | write | ナビボタン更新 |
| `shop edit-navi-button-info` | write | ナビボタン情報更新 |
| `shop edit-signboard` | write | 看板更新 |
| `category-api get-category-set-lists` | read | カテゴリセット一覧（camelCase） |
| `category-api get-category-tree <categorySetId>` | read | カテゴリツリー取得 |
| `category-api get-shop-category <categoryId>` | read | ショップカテゴリ取得 |
| `category-api get-item-mapping <manageNumber>` | read | 商品カテゴリマッピング取得 |
| `category-api upsert-category-tree <categorySetId>` | write | カテゴリツリー更新 |
| `category-api insert-shop-category` | write | ショップカテゴリ作成 |
| `category-api update-shop-category <categoryId>` | write | ショップカテゴリ更新 |
| `category-api upsert-item-mapping <manageNumber>` | write | 商品カテゴリマッピング更新 |
| `category-api delete-item-mapping <manageNumber>` | **high-risk-write** | 商品カテゴリマッピング削除 |
| `navigation get-version` | read | ジャンルデータバージョン |
| `navigation get-genre <genreId>` | read | ジャンル情報取得 |
| `navigation get-genre-attributes <genreId>` | read | ジャンル属性一覧 |
| `navigation get-genre-attribute-dictionary-values <genreId> <attributeId>` | read | 属性辞書値取得 |
