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

### 3. RMSでAPIキーを申請し、権限を付与する

rms-cli は楽天RMSの各種WEB Service APIを**サービスシークレット**と**ライセンスキー**で呼び出す。事前にRMSメンバーズステーション側でAPI利用を申請し、使うスキルに応じたWEB Serviceを許可しておく必要がある。

1. [R-Login（RMSログイン）](https://glogin.rms.rakuten.co.jp/)から、店舗ID・ユーザーID・パスワードでRMSにログインする（2段階認証）。
2. RMSのグローバルメニューから `店舗様向け情報・サービス` → `WEB APIサービス` を開き、利用規約に同意して申し込む（初回のみ）。
3. `利用設定` → `WEB API` → `利用機能一覧` の `利用機能編集` を開き、使用するスキルに合わせて以下のWEB Serviceを「利用中」に変更する（未使用のAPIは利用中にしない＝最小権限の原則）。

   | スキル | 必要なWEB Service | 用途 |
   |---|---|---|
   | `rms-shared` | （追加権限不要・認証共通） | 認証・プロファイル切り替え |
   | `rms-item` | 商品管理API / 在庫情報管理API | 商品の検索・登録・更新・削除、在庫管理 |
   | `rms-order` | 受注管理API | 注文の検索・確認・出荷更新・キャンセル |
   | `rms-coupon` | クーポンAPI | クーポンの発行・更新・削除 |
   | `rms-cabinet` | キャビネットAPI | 商品画像・ファイルのアップロードと管理 |
   | `rms-inquiry` | 問い合わせ管理API（InquiryManagementAPI） | 問い合わせの一覧取得・返信・既読・完了マーク |
   | `rms-shop` | 店舗様式API / カテゴリAPI / ジャンル（navigation）API | 店舗情報・レイアウト・カテゴリ・送料設定 |

   APIによっては参照権限と更新権限が別に申請できる場合がある。`rms-cli`で書き込み系コマンド（`[write]` / `[high-risk-write]`、例: `item upsert`, `inventory upsert-variant`, `coupon issue`, `order confirm-order` 等）を使う予定がある場合は、参照だけでなく更新権限も有効化しておくこと。申請直後は反映まで時間がかかる場合がある。
4. 内容を確認・登録すると**サービスシークレット**が発行される。**ライセンスキー**は同画面、またはシステム連携先ごとのアクセス許可設定（RMSメニューの `システム連携` ）で確認・発行できる。開発ベンダー経由で利用する場合は `システム連携` からベンダーへのアクセス許可設定も必要になる。

> RMSの画面構成はRakuten側の仕様変更により変わることがある。上記メニュー名で見つからない場合は、RMSトップの検索窓で「WEB API」と検索するか、WEB APIサービスデスクの問い合わせフォーム（RMSにログイン後 `お問い合わせ` から遷移）を利用する。

### 4. 認証情報の登録

取得したサービスシークレットとライセンスキーを rms-cli に登録する。

```bash
rms-cli auth login \
  --profile my-shop \
  --service-secret <サービスシークレット> \
  --license-key <ライセンスキー>
```

`--profile` は複数ショップを切り替えるための識別名（任意の文字列でよい）。登録後に確認する。

```bash
rms-cli auth status --verify
```

`--verify` を付けると実際にAPIへ疎通確認を行う。`401`/`403` エラーになる場合は、手順3で対象APIの権限が正しく許可されているか、反映が完了しているかを確認する。

### 5. スキルのインストール

プロジェクトのルートディレクトリ（Claude Code で開いているフォルダ）で実行する。

```bash
rms-cli skills install
```

内部で `npx skills` を使い、Claude Code がRMS操作に使うスキルをプロジェクトに追加する。

### 6. エージェントのインストール（任意）

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
