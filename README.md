# rms-claude

[shopload/rms-cli](https://github.com/shopload/rms-cli) の公開配布リポジトリ。
楽天RMS WEB SERVICE を Claude Code から操作するための **CLIバイナリ・エージェント・スキル** を配布する。

## インストール（rms-cli バイナリ）

### インストールスクリプト（推奨）

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/shopload/rms-claude/main/scripts/install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/shopload/rms-claude/main/scripts/install.ps1 | iex
```

インストール先を変えたい場合は `RMS_CLI_INSTALL_DIR` 環境変数で指定する。

### gh release download（手動）

```bash
# macOS / Linux（自動判定）
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
gh release download --repo shopload/rms-claude \
  --pattern "rms-cli_${OS}_${ARCH}" --dir /tmp
chmod +x "/tmp/rms-cli_${OS}_${ARCH}"
sudo mv "/tmp/rms-cli_${OS}_${ARCH}" /usr/local/bin/rms-cli
rms-cli --version
```

```powershell
# Windows（自動判定）
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
gh release download --repo shopload/rms-claude `
  --pattern "rms-cli_windows_$arch.exe" --dir $env:TEMP
Move-Item "$env:TEMP\rms-cli_windows_$arch.exe" rms-cli.exe
```

特定バージョンを指定する場合は `--tag v0.2.0` を追加する。

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

詳細は [AGENTS.md](https://github.com/shopload/rms-cli/blob/main/AGENTS.md) を参照。
