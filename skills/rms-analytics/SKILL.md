---
name: rms-analytics
description: "楽天RMS 売上診断・分析。受注データから売上/客単価/商品別ランキング/併売率を集計し、クーポンの取得数・利用数から効果を測定し、カタログの在庫切れ・非公開比率や売れ筋の在庫リスクを点検する。「売上を上げたい」「売上を分析して」「クーポンは効いているか」「何が売れているか」といった診断・改善提案が必要なときに使用する。"
metadata:
  requires:
    bins: ["rms-cli", "jq"]
  cliHelp: "rms-cli order --help"
---

# analytics（売上診断）

**CRITICAL — 開始前に必ず [`../rms-shared/SKILL.md`](../rms-shared/SKILL.md) を読むこと。認証・リスクレベル・--data の使い方が書かれている。**

本スキルは既存の order / item / inventory / coupon サービスを**読み取り専用で組み合わせて**売上を診断する手順書。新しいAPIは使わない。書き込みは行わない。

## APIで取れるもの・取れないもの

**先にこの境界を認識すること。** 誤った断定を避けるために重要。

| 取れる | 取れない（RMS WEB SERVICE の範囲外） |
|---|---|
| 受注明細（金額・商品・点数・ステータス） | **アクセス人数・PV** |
| 商品マスタ（画像枚数・公開状態・在庫切れ） | **転換率（CVR）** |
| 在庫数 | 検索順位・流入キーワード |
| クーポンの取得数・利用数 | レビュー件数・評点 |
| 問い合わせ件数 | 広告（RPP等）の費用対効果 |

つまり **「売れていない」原因が①流入不足なのか ②流入はあるが買われていないのか は本スキルでは切り分けられない**。
アクセス系はR-カルテ／データ分析（RMS管理画面）側にある。診断結果を報告するときは、この限界を必ず明示すること。断定しない。

## 事前に知っておくべきAPI制約

これを知らずに組むと必ず失敗する。

| 制約 | 内容 |
|---|---|
| 検索期間 | `order search-order` は **StartDatetime から63日以内**。730日より前は 400 |
| 日時形式 | order は `+0900`（コロンなし）。`+09:00` は 400 |
| 明細取得の上限 | `order get-order` は **1回100件まで**。101件以上は分割必須 |
| レスポンスの混在ケーシング | `get-order` のリスト型は **PascalCase**（`OrderModelList`/`PackageModelList`/`ItemModelList`/`SkuModelList`）、スカラーは camelCase（`orderNumber`/`totalPrice`）。`orderModelList` は null になる |
| 在庫取得 | `inventory bulk-get` は `manageNumber` **と** `variantId` の両方が必須。片方だけだと 400 |
| レート制限 | `item search` を商品ごとにループすると **429** になる。件数だけ要るときは `--hits 1` で `numFound` を読む |
| coupon のケーシング | coupon は XML API のため入出力とも **PascalCase**（`.Coupons.CouponList[]`） |

## 手順1 — 売上トレンド（まず全体像）

30日単位で3期比較して、伸びているのか落ちているのかを先に確定させる。63日制限があるので窓は分ける。

```bash
# 各期間の注文件数だけ先に取る（軽い）
for range in "2026-07-07 2026-08-06" "2026-06-07 2026-07-06" "2026-05-08 2026-06-06"; do
  set -- ${=range}   # zsh: 単語分割を明示（bashなら set -- $range）
  echo "=== $1 .. $2 ==="
  rms-cli order search-order \
    --start-datetime "${1}T00:00:00+0900" \
    --end-datetime "${2}T23:59:59+0900" \
    --date-type 1 \
    --data '{"paginationRequestModel":{"requestRecordsAmount":1000,"requestPage":1}}' \
    --jq '{orders: .PaginationResponseModel.totalRecordsAmount}'
done
```

`--date-type`: 1=注文日, 2=注文確認日, 3=発送日, 4=発送完了日。売上診断は基本 **1（注文日）**。

## 手順2 — 明細を取ってKPIを出す

注文番号を取り、100件ずつに割って `get-order` する。

```bash
WORK=$(mktemp -d)
rms-cli order search-order \
  --start-datetime "2026-07-07T00:00:00+0900" \
  --end-datetime "2026-08-06T23:59:59+0900" \
  --date-type 1 \
  --data '{"paginationRequestModel":{"requestRecordsAmount":1000,"requestPage":1}}' \
  --jq '.orderNumberList' > "$WORK/ord.json"

# 100件ずつのリクエストボディを作る
TOTAL=$(jq 'length' "$WORK/ord.json")
i=0; n=0
while [ "$i" -lt "$TOTAL" ]; do
  jq -c ".[$i:$((i+100))]" "$WORK/ord.json" \
    | jq -R '{orderNumberList: (.|fromjson), version: 10}' > "$WORK/req$n.json"
  rms-cli order get-order --data "@$WORK/req$n.json" \
    --jq '[.OrderModelList[] | {on: .orderNumber, dt: .orderDatetime, prog: .orderProgress,
           total: .totalPrice,
           items: [.PackageModelList[].ItemModelList[]
                   | {mn: .manageNumber, name: .itemName, units: .units, price: .price}]}]' \
    > "$WORK/d$n.json"
  i=$((i+100)); n=$((n+1))
done

# KPI サマリ
jq -s 'add | {orders: length,
              revenue: (map(.total)|add),
              aov: ((map(.total)|add)/length|round),
              units: (map(.items|map(.units)|add)|add),
              single: (map(select(.items|length==1))|length),
              multi:  (map(select(.items|length>1))|length)}' "$WORK"/d*.json
```

出す指標：**注文件数 / 売上 / 客単価(AOV) / 販売点数 / 単品注文率**。
単品注文率は併売施策の効果を測る基準線になるので必ず取る。

## 手順3 — 商品別ランキングと売上集中度

```bash
jq -s 'add | [.[].items[]] | group_by(.mn)
  | map({mn: .[0].mn, name: (.[0].name[0:40]),
         units: (map(.units)|add), rev: (map(.units*.price)|add)})
  | sort_by(-.rev) | .[0:15]' "$WORK"/d*.json
```

**見るポイント**：上位1商品が売上の何％を占めるか。集中度が高い店では、下位商品を触るより**その1商品への投資（画像追加・カラー展開・在庫確保）が最もROIが高い**。逆に集中商品の在庫切れは売上崩壊に直結するので手順6で必ず在庫を確認する。

## 手順4 — クーポン効果測定

**この店で何が効いて何が効かないかを、憶測ではなく実績で判定する。**

```bash
rms-cli coupon search --data '{"Hits":100}' \
  --jq '[(.Coupons.CouponList // [])[]
         | {name: .CouponName, start: .CouponStartDate, end: .CouponEndDate,
            off: .DiscountFactor, dtype: .DiscountType,
            get: .GetCount, used: .AvailCount,
            cond: [(.OtherConditions.OtherCondition // [])[]
                   | (.ConditionTypeCode + "=" + .StartValue)]}]
        | sort_by(.end) | reverse'
```

- `GetCount` = 取得された枚数、`AvailCount` = 実際に使われた枚数。
- **`used / get` = 利用率が唯一の効果指標**。取得数が多くても利用率が低いクーポンは失敗。
- 同一条件のクーポンを時系列で並べ、利用率を比較して勝ちパターンを特定する。

### 条件コード（`OtherConditions.ConditionTypeCode`）

| コード | 意味 | 備考 |
|---|---|---|
| `RS003` | **利用金額条件**（最低購入金額・円） | `StartValue` に金額。例 `RS003=3000` = 3,000円以上 |
| `RS004` | **購入個数条件**（N点以上） | `StartValue` に点数。例 `RS004=2` = 2点以上 |
| `RS001` / `RS002` | 発行時に既定で付与される条件 | 意味は公式ドキュメント未確認。**既存クーポンの値をそのまま踏襲すること**（勝手に変えない） |

`RS003` / `RS004` は実際の発行済みクーポンのデータから確認済み。`RS001`/`RS002` は用途未確認のため、新規発行時は `coupon get` で直近クーポンの値をコピーする。

### 診断の定石

- **購入個数条件（RS004）は単品注文率が高い店では機能しない。** 単品率が高いのに2点縛りクーポンを出していたら、それが原因で利用率が落ちている可能性が高い。金額条件（RS003）を**客単価のすぐ上**に置く方が、単品客を排除せずに客単価を押し上げられる。
- 無条件クーポンの利用率が比較対象のベースラインになる。

## 手順5 — カタログ健全性

商品ごとにループせず、`--hits 1` の `numFound` だけでクロス集計する（429回避）。

```bash
echo "全商品:";              rms-cli item search --hits 1 --jq '{n: .numFound}'
echo "公開中:";              rms-cli item search --hits 1 --is-hidden-item false --jq '{n: .numFound}'
echo "在庫切れ(全体):";      rms-cli item search --hits 1 --is-item-stockout true --jq '{n: .numFound}'
echo "在庫切れ かつ 公開中:" ; rms-cli item search --hits 1 --is-item-stockout true --is-hidden-item false --jq '{n: .numFound}'
```

**「在庫切れ かつ 公開中」が本当の問題**。ここが多いと、露出を食いつぶして機会損失と離脱を生む。在庫切れ商品が非公開化されているなら運用は健全なので、そう報告する（総数だけ見て誤って問題視しない）。

売れ筋商品の作り込みも比較する。画像枚数・バリエーション数は売上上位商品ほど厚くあるべきで、**「売れているのに作り込みが薄い商品」が最大の伸びしろ**。

```bash
rms-cli item search --manage-number "<manageNumber>" --hits 1 \
  --jq '.results[0].item
        | {title: (.title[0:30]), hide: .hideItem, imgs: (.images|length),
           video: (if .video then 1 else 0 end),
           variants: (.variants|length), created, updated}'
```

## 手順6 — 売れ筋の在庫リスク

上位商品の在庫を取り、販売ペースと突き合わせて枯渇時期を出す。

```bash
rms-cli inventory bulk-get --data '{"inventories":[
  {"manageNumber":"<mn1>","variantId":"<mn1のvariantId>"},
  {"manageNumber":"<mn2>","variantId":"<mn2のvariantId>"}
]}' --jq '[.inventories[] | {mn: .manageNumber, vid: .variantId, qty: .quantity}]'
```

`variantId` は手順2で取った `SkuModelList[].variantId`、または `item search` の `.variants` のキーから取る。
**30日販売点数 ÷ 在庫数** で残り日数を概算し、1ヶ月を切る売れ筋は補充対象として名指しで挙げる。

## レポートの書き方

診断結果は「一般論の羅列」にしないこと。以下を守る。

1. **数字を先に出す** — 注文件数・売上・客単価・単品率・トレンドを表で提示してから解釈する。
2. **その店のデータから言えることだけ書く** — 業界平均や一般的なEC論を持ち込まない。根拠は必ず取得した数値。
3. **施策は「今日できる順」に並べる** — 影響度×着手コストで優先順位を付け、上位3つに絞る。10個並べない。
4. **失敗している施策を名指しする** — クーポン利用率など、実績が negative な施策は続けている限り損失。代替案とセットで指摘する。
5. **限界を明示する** — アクセス数・転換率が取れないことを必ず添える。「流入が足りないのか、流入はあるが売れていないのか」は本診断では切り分けられない。
6. **書き込みは提案までにとどめ、実行はユーザーの承認を得てから**。クーポンの停止・発行は `rms-coupon` スキルの手順とポリシーに従う。

## 関連スキル

| スキル | 用途 |
|---|---|
| [`../rms-order/SKILL.md`](../rms-order/SKILL.md) | 受注検索・明細取得の詳細 |
| [`../rms-item/SKILL.md`](../rms-item/SKILL.md) | 商品検索・在庫の詳細 |
| [`../rms-coupon/SKILL.md`](../rms-coupon/SKILL.md) | クーポン発行・停止（ポリシー確認を含む） |
