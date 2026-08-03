# rms-claude

楽天RMS WEB SERVICE を Claude Code から操作するための **CLIバイナリ・エージェント・スキル** を配布する。

## インストール（rms-cli バイナリ）

### インストールスクリプト

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/shopload/rms-claude/main/scripts/install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/shopload/rms-claude/main/scripts/install.ps1 | iex
```

インストール先を変えたい場合は `RMS_CLI_INSTALL_DIR` 環境変数で指定する。

## Claude Code エージェント・スキルのインストール

### エージェント（`.claude/agents/`）

```bash
# リポジトリをクローンしてコピー
gh repo clone shopload/rms-claude
cp rms-claude/.claude/agents/*.md .claude/agents/
```

| エージェント | 用途 |
|---|---|
| `rms-inquiry-responder` | 未回答の問い合わせを確認し、返信案を日本語で起草 |
| `rms-coupon-issuer` | クーポン発行プランを提案（API制約・過去履歴チェック付き） |
| `rms-defect-report` | 不具合写真付き問い合わせから内部不具合報告書を生成 |

### スキル（`skills/`）

```bash
gh repo clone shopload/rms-claude
cp -r rms-claude/skills/* <your-project>/skills/
```

| スキル | 用途 |
|---|---|
| `rms-shared` | 認証・プロファイル・共通パターン |
| `rms-item` | 商品検索・登録・更新・削除 + 在庫管理 |
| `rms-order` | 注文検索・確認・出荷・キャンセル |
| `rms-coupon` | クーポン発行・更新・削除 |
| `rms-cabinet` | 画像・ファイルのアップロード・管理 |
| `rms-inquiry` | 問い合わせ一覧・返信・既読・完了マーク |
| `rms-shop` | 店舗情報・レイアウト・カテゴリ・送料設定 |

## クイックスタート

```bash
# 1. 認証情報を登録
rms-cli auth login --profile my-shop --service-secret <secret> --license-key <key>

# 2. コマンドを確認
rms-cli --help
rms-cli item --help

# 3. 読み取り
rms-cli item search --title "サンプル" --hits 5

# 4. 書き込みは --dry-run で確認してから
rms-cli item upsert my-item-code --genre-id 100000 --dry-run

# 5. 破壊的操作は --yes が必須
rms-cli item delete my-manage-number --yes
```
