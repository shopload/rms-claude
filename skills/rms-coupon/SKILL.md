---
name: rms-coupon
description: "楽天RMS クーポン管理。クーポンの検索・取得（search, get）、発行（issue）、更新（update）、表示切替（patch）、削除（delete）。クーポンの作成・変更・削除、クーポン一覧の確認が必要なときに使用する。"
metadata:
  requires:
    bins: ["rms-cli"]
  cliHelp: "rms-cli coupon --help"
---

# coupon（クーポン管理）

**CRITICAL — 開始前に必ず [`../rms-shared/SKILL.md`](../rms-shared/SKILL.md) を読むこと。認証・リスクレベル・--data の使い方が書かれている。**

## コアコンセプト

- **出力フィールドは PascalCase** — coupon は XML API（json タグなし）。`--jq` フィールドは PascalCase（例: `.Coupons.CouponList[].CouponCode`）。
- **`--data` のフィールド名も PascalCase** — 書き込み系（issue/update/patch/delete）の `--data` に渡す JSON キーも Go の構造体フィールド名（PascalCase）を使う。
- **CouponStatus**: 1=有効, 2=未開始（開始日前）, 3=終了

## API仕様・挙動上の注意点（`coupon issue` / `coupon update` の前に確認）

法令遵守・楽天ガイドライン・自店舗の割引上限などの**ポリシー判断**は [`docs/coupon-policy.md`](../../docs/coupon-policy.md) を参照すること（`rms-coupon-issuer` サブエージェントも同ファイルを参照する設計になっている。SKILL.mdにポリシー本文を重複させない）。ここでは、守らないと**意図と異なる挙動になる／登録がエラーになる**API・CLIレベルの技術仕様のみを扱う。

### 対象商品指定クーポンの値引きカウント方式

値引額の計算方法が「店内全商品クーポン」と「対象商品指定クーポン」で異なるため、設定を誤ると店舗の想定外の値引きが発生する。

| クーポン種類 | クーポン利用回数をカウントする対象 |
|---|---|
| 店内全商品クーポン（`ItemType: 0`） | 「注文回数」。対象注文（決済）1回につき1回適用 |
| 対象商品指定クーポン（`ItemType: 1`） | 「対象商品点数」。対象商品1個につき1回適用（複数個購入なら複数回適用） |

- **典型的な誤設定**：対象商品を3個買ったら1,000円OFFのつもりで `MemberAvailMaxCount`（1ユーザあたり利用回数上限）を無制限にすると、3個購入時に1,000円×3＝3,000円OFFになってしまう。対象商品指定クーポンでは、この上限は「注文回数」ではなく「クーポン適用可能な対象商品点数」を意味する。
- **推奨設定**：
  - 値引き額（率）を大きくしたい場合 → `MemberAvailMaxCount` を1回など少なめに設定する（1個目のみ値引き、2個目以降は対象外）。
  - 利用回数を多くしたい場合 → 1点あたりの値引き額を小さくし、重複適用されても損失が出ない額に調整する（例: 100円引き×上限なしなら、100個購入で計10,000円引き）。
- 「利用金額条件」「購入個数条件」を満たすと、買い物かご内の対象商品**全て**が値引き対象になる（3個目以降だけが対象になるわけではない）。「○○円ごとに使える」「○○個ごとに使える」という設定はできない。

### 対象商品指定時の追加要件

`ItemType: 1`（対象商品指定）で発行する場合、以下の**いずれか**を満たす必要がある。

- クーポン有効期間を14日以内に設定する
- クーポンの全利用回数上限（`IssueCount`）を1,000回以下に設定する
- 会員ランクの獲得条件（`MultiRankCond`）を指定する

その他の制約:
- 対象商品は最大5,000件まで。
- `DiscountType: 1`（定額値引き）の場合、対象商品の販売価格（通常購入価格と定期購入初回価格のうち安い方）未満の商品は登録・編集時にエラー商品として自動除外される（SKUごとに価格が異なる場合は最低価格が判定対象）。送料無料を選ぶ場合は対象商品指定はできない。
- 新規登録・内容変更した商品がクーポン対象に反映されるまで最大24時間かかることがある。

### クーポン獲得条件フィールド

`IssueRequestCoupon` の獲得条件系フィールドと、設定を誤ると意図通りに動かない制約。

| フィールド | 内容 | 制約 |
|---|---|---|
| `MultiRankCond` | 会員ランク（複数指定可） | 他の獲得条件（購入履歴・性別・年齢・誕生月・居住地）と**同時指定不可** |
| `PurchaseHistoryCond` | 店舗購入履歴 | 過去最大730日が対象。`Type: 2`（購入履歴あり）指定時は `DynamicPeriod`（1/3/6/12/24ヵ月）と `PurchaseCount.Minimum/Maximum`（1〜10、または上限なし）が必須 |
| `GenderCond` | 性別 | 販売方法条件が「定期購入商品のみ」の場合は設定不可 |
| `AgeRangeCond` | 年齢 | `LowerBound`/`UpperBound` は10〜100の範囲。販売方法条件が「定期購入商品のみ」の場合は設定不可 |
| `BirthmonthCond` | 誕生月 | 販売方法条件が「定期購入商品のみ」の場合は設定不可 |
| `MultiPrefectureCond` | 居住地（都道府県、複数指定可） | ユーザーの登録住所であり、お届け先都道府県とは異なる場合がある |

購入履歴・属性データはリアルタイム反映ではなく、最大48〜72時間程度の遅延がある。有効期間の設計（何時間の余裕を見るべきか）や、獲得条件付きクーポンを訴求する際の免責文言の要否は `docs/coupon-policy.md` を参照。

### 登録時の入力仕様

- クーポン名・説明文に機種依存文字・外字は使用不可（文字化けの原因）。
- 有効期間開始日時：登録画面を開いた時点から最短60分後・最長30日後まで選択可能。有効期間は最大3ヵ月以内（対象商品指定時はさらに上記「対象商品指定時の追加要件」を満たす必要あり）。
- 利用金額条件・購入個数条件の判定対象は「商品価格＋税」の合計額（送料・決済手数料は含まない）。利用金額条件が値引き額以下になる組み合わせ（例：1,000円以上購入で2,000円OFF）は登録時に確認画面が表示される。
- 送料無料クーポンを使う場合、事前に送料区分の設定状況を確認する（未設定だとユーザーが利用できない）。

### 実行前チェックリスト（issue / update）

1. `docs/coupon-policy.md` の「自店舗の運用ルール」「楽天市場の出店者向けガイドライン」を確認し、割引率・禁止事項・訴求文言などポリシー面で問題ないか確認する。
2. `ItemType: 1`（対象商品指定）の場合、`MemberAvailMaxCount` の意味（対象商品点数カウント）を踏まえて値引き総額が意図通りか確認し、追加要件（有効期間14日以内／`IssueCount<=1000`／会員ランク指定のいずれか）を満たしているか確認する。
3. 獲得条件系フィールドを使う場合、会員ランクと他条件の同時指定不可、定期購入限定時の性別/年齢/誕生月不可、といった制約に違反していないか確認する。
4. `coupon search` で既存クーポンとの重複・整合性（連続開催・命名規則など）を確認する。
5. 上記いずれかに抵触・懸念がある場合は実行せず、理由を明示してユーザーに確認を取る。

## クーポン検索

```bash
# 全件取得
rms-cli coupon search --data '{}'

# 名前で絞り込み
rms-cli coupon search --data '{"couponName":"OFF","hits":20}'

# コード・名前・割引・終了日を抽出（null-safe）
rms-cli coupon search --data '{}' \
  --jq '(.Coupons.CouponList // []) | .[] | {code: .CouponCode, name: .CouponName, discount: .DiscountFactor, end: .CouponEndDate}'

# ステータスで絞り込み（1=有効, 2=未開始, 3=終了）
rms-cli coupon search --data '{}' \
  --jq '(.Coupons.CouponList // []) | .[] | select(.CouponStatus == 1) | {code: .CouponCode, name: .CouponName}'
```

主な検索パラメータ（`--data` で渡す）: `couponName`, `couponCode`, `couponStartDate`, `couponEndDate`, `hits`（件数）, `page`

## クーポン取得

```bash
# --coupon-code フラグを使う（--coupon-id ではない）
rms-cli coupon get --coupon-code "XXXX-XXXX-XXXX-XXXX"

# クーポン詳細を抽出
rms-cli coupon get --coupon-code "XXXX-XXXX-XXXX-XXXX" \
  --jq '{code: .Coupon.CouponCode, name: .Coupon.CouponName, status: .Coupon.CouponStatus, discount: .Coupon.DiscountFactor}'
```

## クーポン発行（新規作成）

`--data` のキーは Go 構造体フィールド名（PascalCase）。

```bash
# ドライランで確認（全商品・100円OFF・無制限発行の例）
rms-cli coupon issue --dry-run --data '{
  "IssueRequestCoupon": {
    "CouponName": "100円OFFクーポン",
    "CouponStartDate": "2026-09-01T00:00:00+09:00",
    "CouponEndDate": "2026-09-30T23:59:59+09:00",
    "IssueCount": 0,
    "ItemType": 4,
    "DiscountType": 1,
    "DiscountFactor": 100,
    "MemberAvailMaxCount": 0,
    "GenderCond": "NONE",
    "MultiRankCond": {"RankCond": [0]},
    "MultiPrefectureCond": {"PrefectureCond": ["NONE"]},
    "CombineFlag": 0,
    "DisplayFlag": 1,
    "OtherConditions": {
      "OtherCondition": [
        {"ConditionTypeCode": "RS001", "StartValue": "0"},
        {"ConditionTypeCode": "RS001", "StartValue": "1"},
        {"ConditionTypeCode": "RS002", "StartValue": "99"}
      ]
    }
  }
}'

# 発行（2点以上で300円OFFの例 — RS004 で「2点以上」条件を追加）
rms-cli coupon issue --data '{
  "IssueRequestCoupon": {
    "CouponName": "当店2点以上購入で300円OFFクーポン",
    "CouponStartDate": "2026-09-01T00:00:00+09:00",
    "CouponEndDate": "2026-09-30T23:59:59+09:00",
    "IssueCount": 0,
    "ItemType": 4,
    "DiscountType": 1,
    "DiscountFactor": 300,
    "MemberAvailMaxCount": 0,
    "GenderCond": "NONE",
    "MultiRankCond": {"RankCond": [0]},
    "MultiPrefectureCond": {"PrefectureCond": ["NONE"]},
    "CombineFlag": 0,
    "DisplayFlag": 1,
    "OtherConditions": {
      "OtherCondition": [
        {"ConditionTypeCode": "RS001", "StartValue": "0"},
        {"ConditionTypeCode": "RS001", "StartValue": "1"},
        {"ConditionTypeCode": "RS002", "StartValue": "99"},
        {"ConditionTypeCode": "RS004", "StartValue": "2"}
      ]
    }
  }
}'
```

主な `IssueRequestCoupon` フィールド:

| フィールド | 型 | 説明 |
|---|---|---|
| `CouponName` | string | クーポン名（必須） |
| `CouponStartDate` | string | 開始日時（例: `2026-09-01T00:00:00+09:00`） |
| `CouponEndDate` | string | 終了日時 |
| `IssueCount` | uint32 | 発行枚数（**0=無制限**） |
| `ItemType` | int | **4=全商品**, 1=特定商品 |
| `DiscountType` | int | **1=割引額（円）**, 2=割引率（%） |
| `DiscountFactor` | uint32 | 割引額（円）または割引率（%） |
| `MemberAvailMaxCount` | int | 1人あたり使用上限（0=無制限） |
| `GenderCond` | string | 性別条件（`"NONE"` で条件なし） |
| `MultiRankCond` | object | 会員ランク条件（`{"RankCond":[0]}` で条件なし） |
| `MultiPrefectureCond` | object | 都道府県条件（`{"PrefectureCond":["NONE"]}` で条件なし） |
| `OtherConditions` | object | その他条件。`RS004` の `StartValue` でN点以上購入条件を設定 |

## クーポン全項目更新

既存クーポンの全フィールドを更新。事前に `coupon get` で現在値を取得してから変更すること。

```bash
# ドライランで確認
rms-cli coupon update --dry-run --data '{
  "UpdateRequestCoupon": {
    "CouponCode": "XXXX-XXXX-XXXX-XXXX",
    "CouponName": "変更後クーポン名",
    "CouponStartDate": "2026-09-01T00:00:00+09:00",
    "CouponEndDate": "2026-09-30T23:59:59+09:00",
    "IssueCount": 500,
    "ItemType": 0,
    "DiscountType": 2,
    "DiscountFactor": 200,
    "MemberAvailMaxCount": 1
  }
}'

# 実行
rms-cli coupon update --data @updated-coupon.json
```

## クーポン表示切替（patch）

**注意**: `patch` は**表示フラグ（DisplayFlag）の切替のみ**対応。割引率変更等は `update` を使う。

```bash
# ドライランで確認（DisplayFlag: 0=非表示, 1=表示）
rms-cli coupon patch --dry-run --data '{"Coupon":{"CouponCode":"XXXX-XXXX-XXXX-XXXX","DisplayFlag":0}}'

# 実行
rms-cli coupon patch --data '{"Coupon":{"CouponCode":"XXXX-XXXX-XXXX-XXXX","DisplayFlag":0}}'
```

## クーポン削除（高リスク）

`--data` の `CouponCode` フィールドでクーポンコードを指定する（`--coupon-id` フラグは使えない）。

```bash
# ドライランで確認
rms-cli coupon delete --dry-run --data '{"CouponCode":"XXXX-XXXX-XXXX-XXXX"}'

# ユーザー確認後に実行
rms-cli coupon delete --yes --data '{"CouponCode":"XXXX-XXXX-XXXX-XXXX"}'
```

## コマンド一覧

| コマンド | リスク | 説明 |
|---|---|---|
| `coupon search` | read | クーポン検索 |
| `coupon get` | read | クーポン取得（`--coupon-code` フラグ） |
| `coupon issue` | write | クーポン発行（`IssueRequestCoupon` で指定） |
| `coupon update` | write | クーポン全項目更新（`UpdateRequestCoupon` で指定） |
| `coupon patch` | write | 表示フラグのみ切替（`Coupon.DisplayFlag`） |
| `coupon delete` | **high-risk-write** | クーポン削除（`--data '{"CouponCode":"..."}'`） |
