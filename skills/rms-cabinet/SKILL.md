---
name: rms-cabinet
description: "楽天RMS キャビネット（ファイル・画像ストレージ）管理。ファイルの検索・アップロード・更新・削除（cabinet）、フォルダの作成・取得・ファイル一覧、ゴミ箱からの復元。商品画像や店舗画像のアップロード・管理が必要なときに使用する。"
metadata:
  requires:
    bins: ["rms-cli"]
  cliHelp: "rms-cli cabinet --help"
---

# cabinet（ファイル・画像管理）

**CRITICAL — 開始前に必ず [`../rms-shared/SKILL.md`](../rms-shared/SKILL.md) を読むこと。認証・リスクレベル・--data の使い方が書かれている。**

## コアコンセプト

- **Cabinet** — 楽天RMSの画像・ファイルストレージ。商品画像や店舗バナー等を管理する。
- **folderId** — フォルダの識別子（string 型）。ファイルはフォルダに格納される。基本フォルダのIDは `"0"`。
- **fileId** — ファイルの識別子（int 型）。
- **出力フィールドは PascalCase** — cabinet は XML API（json タグなし）のため `--jq` フィールドは PascalCase。null-safe に `// []` を使うこと。

## 使用容量の確認

```bash
rms-cli cabinet usage-get

# 容量サマリーだけ抽出
rms-cli cabinet usage-get \
  --jq '{maxSpace: .CabinetUsageGetResult.MaxSpace, useSpace: .CabinetUsageGetResult.UseSpace, availSpace: .CabinetUsageGetResult.AvailSpace}'
```

## フォルダ一覧取得

`folder-get` は**全フォルダの一覧**を返す（特定フォルダの指定不可）。

```bash
# 全フォルダ一覧
rms-cli cabinet folder-get

# フォルダID・名前・ファイル数だけ抽出
rms-cli cabinet folder-get \
  --jq '(.CabinetFoldersGetResult.Folders.Folder // []) | .[] | {id: .FolderId, name: .FolderName, files: .FileCount}'

# ページネーション
rms-cli cabinet folder-get --offset "0" --limit "50"
```

## フォルダ内ファイル一覧

```bash
# 基本フォルダ（folderId="0"）のファイル一覧
rms-cli cabinet folder-files-get --folder-id "0"

# ファイルID・名前・URLだけ抽出
rms-cli cabinet folder-files-get --folder-id "0" --limit "20" \
  --jq '(.CabinetFolderFilesGetResult.Files.File // []) | .[] | {id: .FileId, name: .FileName, url: .FileUrl}'
```

## ファイル検索

`files-search` は `--data` ではなく直接フラグで絞り込む。

```bash
# ファイル名で検索（部分一致）
rms-cli cabinet files-search --file-name "banner"

# フォルダIDで絞り込み
rms-cli cabinet files-search --folder-id 12345

# ファイルIDで検索
rms-cli cabinet files-search --file-id 85665840

# URLだけ抽出（null-safe）
rms-cli cabinet files-search --folder-id 12345 --limit "50" \
  --jq '(.CabinetFilesSearchResult.Files.File // []) | .[] | {id: .FileId, name: .FileName, url: .FileUrl}'
```

主なフラグ: `--file-name`, `--file-id`, `--folder-id`, `--file-path`, `--folder-path`, `--limit`, `--offset`

## ファイルアップロード

ファイルアップロードはマルチパートのため `--file` フラグを使う（`--data` ではなく）。

```bash
rms-cli cabinet files-insert --folder-id 12345 --file ./product-image.jpg
```

## フォルダ作成

```bash
rms-cli cabinet folder-insert --data '{"folderModel":{"folderName":"商品画像","directoryName":"products"}}'
```

## ファイル更新

```bash
rms-cli cabinet file-update --file-id 67890 --file ./updated-image.jpg
```

## ファイル削除（高リスク）

```bash
# ドライランで確認
rms-cli cabinet files-delete --dry-run --data '{"fileIdList":[67890,67891]}'

# ユーザー確認後に実行
rms-cli cabinet files-delete --data '{"fileIdList":[67890,67891]}' --yes
```

## ゴミ箱操作

```bash
# ゴミ箱のファイル一覧
rms-cli cabinet trashbox-files-get \
  --jq '(.CabinetTrashboxFilesGetResult.Files.File // []) | .[] | {id: .FileId, name: .FileName}'

# ゴミ箱からファイルを復元
rms-cli cabinet trashbox-file-revert --file-id 67890
```

## よくある操作パターン

### フォルダ一覧を確認して画像をアップロードする

```bash
# 1. フォルダ一覧でID確認
rms-cli cabinet folder-get \
  --jq '(.CabinetFoldersGetResult.Folders.Folder // []) | .[] | {id: .FolderId, name: .FolderName}'

# 2. 画像をアップロード
rms-cli cabinet files-insert --folder-id 12345 --file ./item-photo.jpg

# 3. アップロードした画像URLを確認
rms-cli cabinet folder-files-get --folder-id "12345" \
  --jq '(.CabinetFolderFilesGetResult.Files.File // []) | .[] | select(.FileName == "item-photo.jpg") | .FileUrl'
```

## コマンド一覧

| コマンド | リスク | 説明 |
|---|---|---|
| `cabinet usage-get` | read | 使用容量確認 |
| `cabinet folder-get` | read | 全フォルダ一覧取得 |
| `cabinet folder-files-get` | read | フォルダ内ファイル一覧 |
| `cabinet files-search` | read | ファイル検索（--file-name, --folder-id 等） |
| `cabinet trashbox-files-get` | read | ゴミ箱ファイル一覧 |
| `cabinet folder-insert` | write | フォルダ作成 |
| `cabinet files-insert` | write | ファイルアップロード（--file フラグ） |
| `cabinet file-update` | write | ファイル更新（--file フラグ） |
| `cabinet trashbox-file-revert` | write | ゴミ箱から復元 |
| `cabinet files-delete` | **high-risk-write** | ファイル削除 |
