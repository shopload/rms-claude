# rms-claude

楽天RMS WEB SERVICE を **Claude Code** から操作するための CLIバイナリ・スキル・エージェントを配布する。

インストール後は Claude Code のチャットで「在庫を確認して」「クーポンを発行して」と指示するだけで、RMS APIを通じた操作が行える。

---

## セットアップ（初回のみ）

### 1. 前提条件の確認

以下がインストール済みであることを確認する。

| ツール | 確認コマンド | 入手先 |
|---|---|---|
| Claude Code | `claude --version` | https://claude.ai/download |
| Node.js / npm | `node --version` | https://nodejs.org/ |

> Node.js は `npx skills` コマンドの実行に必要。

### 2. rms-cli バイナリのインストール

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/shopload/rms-claude/main/scripts/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/shopload/rms-claude/main/scripts/install.ps1 | iex
```

インストールが完了したら確認する。

```bash
rms-cli --version
```

> インストール先を変えたい場合は環境変数 `RMS_CLI_INSTALL_DIR` で指定する。

### 3. 認証情報の登録

楽天RMSの**サービスシークレット**と**ライセンスキー**を登録する。

```bash
rms-cli auth login \
  --profile my-shop \
  --service-secret <サービスシークレット> \
  --license-key <ライセンスキー>
```

`--profile` は複数ショップを切り替えるための識別名（任意の文字列でよい）。登録後に確認する。

```bash
rms-cli auth status
```

### 4. スキルのインストール

プロジェクトのルートディレクトリ（Claude Code で開いているフォルダ）で実行する。

```bash
rms-cli skills install
```

内部で `npx skills` を使い、Claude Code がRMS操作に使うスキルをプロジェクトに追加する。

### 5. エージェントのインストール（任意）

より高度な自動化を使う場合はエージェントも追加する。

```bash
mkdir -p .claude/agents
base="https://raw.githubusercontent.com/shopload/rms-claude/main/agents"
curl -fsSL "$base/rms-inquiry-responder.md" -o .claude/agents/rms-inquiry-responder.md
curl -fsSL "$base/rms-coupon-issuer.md"     -o .claude/agents/rms-coupon-issuer.md
curl -fsSL "$base/rms-defect-report.md"     -o .claude/agents/rms-defect-report.md
```

---

## Claude Code での使い方

セットアップ後は Claude Code のチャットに日本語で指示するだけでよい。

```
# 商品を探す
今月追加した商品を10件見せて

# 在庫を確認・更新する
SKU「ABC-001」の在庫数を教えて

# 注文を処理する
未確認の注文一覧を出して、出荷準備ができているものを確認済みにして

# クーポンを発行する
送料無料クーポンを今週末向けに発行して

# 問い合わせに返信する
未回答の問い合わせを確認して、返信案を作って
```

Claude Code が自動的に適切なスキル・エージェントを選んでRMS APIを呼び出す。

---

## スキル一覧

| スキル | できること |
|---|---|
| `rms-shared` | 認証・プロファイル切り替え・共通操作 |
| `rms-item` | 商品の検索・登録・更新・削除、在庫管理 |
| `rms-order` | 注文の検索・確認・出荷更新・キャンセル |
| `rms-coupon` | クーポンの発行・更新・削除 |
| `rms-cabinet` | 商品画像・ファイルのアップロードと管理 |
| `rms-inquiry` | 問い合わせの一覧取得・返信・既読・完了マーク |
| `rms-shop` | 店舗情報・レイアウト・カテゴリ・送料設定 |

## エージェント一覧

| エージェント | できること |
|---|---|
| `rms-inquiry-responder` | 未回答の問い合わせを確認し、返信案を日本語で起草 |
| `rms-coupon-issuer` | API制約・過去履歴をチェックしてクーポン発行プランを提案 |
| `rms-defect-report` | 不具合写真付き問い合わせから内部報告書を生成 |

---

## CLIコマンドリファレンス

Claude Code を介さず `rms-cli` を直接操作する場合の例。

```bash
# ヘルプを確認
rms-cli --help
rms-cli item --help

# 商品を検索
rms-cli item search --title "サンプル" --hits 5

# 書き込みは --dry-run で内容を確認してから実行
rms-cli item upsert my-item-code --genre-id 100000 --dry-run
rms-cli item upsert my-item-code --genre-id 100000

# 破壊的な操作は --yes が必須
rms-cli item delete my-manage-number --yes

# 複数ショップを切り替える
rms-cli --profile shop-b item search --title "サンプル"
```
