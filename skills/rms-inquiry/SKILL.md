---
name: rms-inquiry
description: "楽天RMS 問い合わせ管理（InquiryManagementAPI）。問い合わせ一覧の取得（get-inquiries）、件数確認（get-counts）、個別取得（get-inquiry）、返信作成（create-reply）、完了/未完了マーク、既読マーク、添付ファイルの取得・アップロード。お客様からの問い合わせ対応・確認が必要なときに使用する。"
metadata:
  requires:
    bins: ["rms-cli"]
  cliHelp: "rms-cli inquiry --help"
---

# inquiry（問い合わせ管理）

**CRITICAL — 開始前に必ず [`../rms-shared/SKILL.md`](../rms-shared/SKILL.md) を読むこと。認証・リスクレベル・--data の使い方が書かれている。**

## コアコンセプト

- **出力フィールドは camelCase** — inquiry は JSON API（json タグあり）。`--jq` フィールドは camelCase（例: `.list[].inquiryNumber`）。
- **`fromDate` / `toDate` は必須** — 省略すると 400 エラー。フォーマットは `yyyy-MM-ddTHH:mm:ss`（タイムゾーンなし、コロンあり）。
- **期間は最大31日以内** — `fromDate` と `toDate` の差が31日を超えると 400 エラー。

## 問い合わせ一覧取得

```bash
# 直近7日間の問い合わせ一覧（フォーマットに注意: タイムゾーンなし）
rms-cli inquiry get-inquiries \
  --from-date "$(date -v-7d +%Y-%m-%dT00:00:00)" \
  --to-date "$(date +%Y-%m-%dT23:59:59)" \
  --limit 20

# 未返信のみ
rms-cli inquiry get-inquiries \
  --from-date "$(date -v-7d +%Y-%m-%dT00:00:00)" \
  --to-date "$(date +%Y-%m-%dT23:59:59)" \
  --no-merchant-reply

# 問い合わせ番号・お客様名・内容だけ抽出
rms-cli inquiry get-inquiries \
  --from-date "$(date -v-7d +%Y-%m-%dT00:00:00)" \
  --to-date "$(date +%Y-%m-%dT23:59:59)" \
  --jq '.list[] | {no: .inquiryNumber, user: .userName, msg: .message, completed: .isCompleted}'

# ページネーション（1ページ最大100件、最大10000件まで）
rms-cli inquiry get-inquiries \
  --from-date "2026-07-01T00:00:00" \
  --to-date "2026-07-31T23:59:59" \
  --limit 100 --page 2
```

主なフラグ:

| フラグ | 必須 | 説明 |
|---|---|---|
| `--from-date` | **必須** | 開始日時（`yyyy-MM-ddTHH:mm:ss`、タイムゾーンなし） |
| `--to-date` | **必須** | 終了日時（同上、fromDate との差は31日以内） |
| `--limit` | 任意 | 取得件数（1〜100、デフォルト10） |
| `--page` | 任意 | ページ番号（1〜10000、デフォルト1） |
| `--no-merchant-reply` | 任意 | 未返信のみ取得 |

## 件数確認

```bash
# 直近7日間の件数
rms-cli inquiry get-counts \
  --from-date "$(date -v-7d +%Y-%m-%dT00:00:00)" \
  --to-date "$(date +%Y-%m-%dT23:59:59)"

# 未返信のみ件数
rms-cli inquiry get-counts \
  --from-date "$(date -v-7d +%Y-%m-%dT00:00:00)" \
  --to-date "$(date +%Y-%m-%dT23:59:59)" \
  --no-merchant-reply
```

## 個別取得

```bash
# 問い合わせ番号を positional 引数で渡す（--data ではない）
rms-cli inquiry get-inquiry "356763-20260705-49336778t"

# レスポンスは .result 内にラップされている
rms-cli inquiry get-inquiry "356763-20260705-49336778t" \
  --jq '{no: .result.inquiryNumber, user: .result.userName, msg: .result.message, replies: (.result.replies | length)}'
```

## 返信作成

`shopId` は **認証情報（serviceSecret の `{shopId}-{serviceCode}` 形式）から自動注入** される。明示的に指定したい場合は `--shop-id` または `--data` に含める。

```bash
# ドライランで確認（shopId が自動注入されていることを --dry-run で確認できる）
rms-cli inquiry create-reply --dry-run --data '{
  "inquiryNumber": "356763-20260705-49336778t",
  "message": "ご連絡ありがとうございます。..."
}'

# 実行
rms-cli inquiry create-reply --data '{
  "inquiryNumber": "356763-20260705-49336778t",
  "message": "ご連絡ありがとうございます。..."
}'
```

## 完了・未完了マーク

```bash
# 完了にする
rms-cli inquiry complete-inquiries --data '{"inquiryNumbers":["356763-20260705-49336778t"]}'

# 未完了に戻す
rms-cli inquiry incomplete-inquiries --data '{"inquiryNumbers":["356763-20260705-49336778t"]}'
```

## 既読マーク

```bash
rms-cli inquiry mark-inquiries-read --data '{"inquiryNumbers":["356763-20260705-49336778t"]}'
```

## よくある操作パターン

### 未返信の問い合わせをまとめて確認する

```bash
rms-cli inquiry get-inquiries \
  --from-date "$(date -v-30d +%Y-%m-%dT00:00:00)" \
  --to-date "$(date +%Y-%m-%dT23:59:59)" \
  --no-merchant-reply \
  --jq '.list[] | {no: .inquiryNumber, user: .userName, type: .type, msg: .message}'
```

### 問い合わせに返信して完了にする

```bash
# 1. 内容確認
rms-cli inquiry get-inquiry --data '{"inquiryNumber":"XXX-XXXXXXXX-XXXXXXXXt"}'

# 2. 返信（ドライランで確認：shopId が自動注入されていることを確認）
rms-cli inquiry create-reply --dry-run --data '{"inquiryNumber":"XXX-XXXXXXXX-XXXXXXXXt","message":"ご連絡ありがとうございます。..."}'

# 3. 返信実行（shopId は自動注入されるため指定不要）
rms-cli inquiry create-reply --data '{"inquiryNumber":"XXX-XXXXXXXX-XXXXXXXXt","message":"ご連絡ありがとうございます。..."}'

# 4. 完了マーク
rms-cli inquiry complete-inquiries --data '{"inquiryNumbers":["XXX-XXXXXXXX-XXXXXXXXt"]}'
```

## 添付ファイルの取得・表示

問い合わせやスレッドには `attachments` フィールドがあり、各要素は `{label, path}` のペア。

```bash
# 添付ファイルの有無を確認（get-inquiry レスポンスから）
rms-cli inquiry get-inquiry "356763-20260705-49336778t" \
  --jq '.result.attachments'

# get-inquiries の各メッセージにも attachments がある（スレッド内各返信含む）
rms-cli inquiry get-inquiries --from-date ... --to-date ... \
  --jq '.list[] | select(.attachments | length > 0) | {no: .inquiryNumber, attachments: .attachments}'
```

`get-attachment` はバイナリを `{"Body":"<base64>"}` 形式で返す。画像・ファイルをローカル保存する手順:

```bash
# 1. get-inquiry で path と label を確認
ATTACH_PATH=$(rms-cli inquiry get-inquiry "356763-20260705-49336778t" \
  --jq '.result.attachments[0].path' | tr -d '"')
ATTACH_LABEL=$(rms-cli inquiry get-inquiry "356763-20260705-49336778t" \
  --jq '.result.attachments[0].label' | tr -d '"')

# 2. ダウンロードして保存（base64 デコード）
rms-cli inquiry get-attachment --path "$ATTACH_PATH" --label "$ATTACH_LABEL" \
  | jq -r '.Body' | base64 -d > "/tmp/$ATTACH_LABEL"

# 3. 保存先を確認
ls -lh "/tmp/$ATTACH_LABEL"
```

4. **画像の表示**: 保存後、`Read` ツールで `/tmp/<label>` を読む。Claude Code の `Read` ツールは JPEG/PNG 等の画像ファイルをそのままインライン表示する。**chrome-devtools や HTML 生成は使わないこと** — ローカルファイルの表示には機能しない。

複数添付がある場合はインデックスを変えて繰り返す（`attachments[0]`, `attachments[1]`, ...）。

## コマンド一覧

| コマンド | リスク | 説明 |
|---|---|---|
| `inquiry get-inquiries` | read | 問い合わせ一覧取得 |
| `inquiry get-counts` | read | 問い合わせ件数確認 |
| `inquiry get-inquiry` | read | 問い合わせ個別取得 |
| `inquiry get-attachment` | read | 添付ファイル取得（バイナリ→base64 JSON） |
| `inquiry create-reply` | write | 返信作成 |
| `inquiry mark-inquiries-read` | write | 既読マーク |
| `inquiry complete-inquiries` | write | 完了マーク |
| `inquiry incomplete-inquiries` | write | 未完了マーク |
| `inquiry upload-attachment` | write | 添付ファイルアップロード |
