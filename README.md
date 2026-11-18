# 自律成長型 AI ルールシステム (Sakurai Philosophy × Claude Code Instinct)

日々の対話・開発作業から得た「教訓・知見（Instinct）」を自動で蓄積し、次回以降の作業時にプロンプトへ自動注入して AI を自己成長させる Claude Code 向けのローカル完結型フレームワークです。

---

## 1. 目的と効果

### ■ 目的
- **対話の「使い捨て」をなくす**: 試行錯誤して辿り着いた仕様・プロンプト・デバッグの教訓を揮発させず、1行1件のルールとして永続化する。
- **指示の再入力コストをゼロにする**: 同じ注意（「操作レスポンスを最優先にして」「Dry-runしてから消して」等）を何度も人間が入力する手間を排す。
- **手元の知見をチーム資産へ昇格させる**: 個人で実際に何度も効果を発揮したルールだけを抽出し、将来的にチーム共有ルールへ安全に昇格させる。

### ■ 期待される効果
1. **桜井哲学の実装品質（手触り・テンポの維持）**:
   「遅さは罪」「骨（プログラム）と筋肉（パラメータ）の分離」「リスクとリターン」といったゲーム制作・ソフト開発の重要原則が、作業の要所（ジャンプ実装、UI設計、削除コマンド等）で自動適用されます。
2. **コンテキストの省エネ（贅肉の削ぎ落とし）**:
   長大なプロンプトを常時読み込ませるのではなく、**トリガーに合致したルールだけをピンポイントで注入**するため、推論速度の低下やトークン浪費を防ぎます。
3. **ローカル完結＆安全性の担保**:
   外部サービスへの通信を行わず、ローカルのファイル（`.jsonl`）だけで動作します。さらに PreToolUse フックにより、破壊的コマンド（`rm -rf /` 等）やシークレット情報（APIキー、`.env` 等）の漏洩を機械的に遮断します。

---

## 2. ディレクトリ構成

```text
sakurai-skills/
├── .claude-plugin/
│   ├── plugin.json               # プラグイン定義
│   └── marketplace.json          # この repo 自体を marketplace として配布するための定義
├── hooks/
│   ├── hooks.json                # フック登録（UserPromptSubmit / PreToolUse）
│   ├── user_prompt_submit.sh     # プロンプト評価・ルール注入・計測フック
│   └── pre_tool_use.sh           # 破壊的操作・機密ファイル保護フック（exit 2 でブロック）
├── skills/
│   └── record-rule/SKILL.md      # 振り返り・ルール追加用スキル
├── rules.jsonl                   # 同梱ルール（1行1件のJSON Lines）
├── references/                   # 桜井政博のエッセンス明文化（NotebookLM 解析結果・カテゴリ A〜M）
│   ├── work_stance.md            # A 仕事の姿勢
│   ├── game-essence.md           # B ゲーム性
│   ├── planning-design.md        # C 企画・ゲーム設計
│   ├── specifications.md         # D 仕様
│   ├── team_management.md        # E チーム運営
│   ├── graphics.md               # F グラフィック
│   ├── motion.md                 # G モーション
│   ├── effects.md                # H エフェクト
│   ├── sound.md                  # I サウンド
│   ├── ui.md                     # J UI
│   ├── programming.md            # K プログラム・テクニカル
│   ├── pr_marketing.md           # L 広報
│   └── grab_bag.md               # M 雑談・クリエイターの流儀
├── CLAUDE.md                     # 運用ガイドライン（リポジトリ開発用。プラグインとしては配布されない）
└── README.md
```

実行時データは `${CLAUDE_PLUGIN_DATA}`（プラグイン更新で消えない場所）に置きます。

| ファイル | 内容 |
|---|---|
| `rules.local.jsonl` | `record-rule` で追記した自分用ルール（同梱 `rules.jsonl` と合わせて注入対象） |
| `rule_metrics.json` | ルールごとの発火回数・セッションヒット数 |

### references/ について

`references/` は、NotebookLM で桜井政博の発言・著作等を解析して得たエッセンスをカテゴリ別（A〜M）に明文化した一次資料です。
`rules.jsonl` のルール（`rule_004`〜`rule_021`）はここから「トレードオフのある判断」だけを1〜2文に圧縮したもので、各 directive 末尾の `（桜井哲学：B ゲーム性）` 等がカテゴリを指します。
詳細な根拠・背景を確認したいときは、該当カテゴリのファイルを参照してください。

> 現状 A（仕事の姿勢）は reference のみで、対応する rule は未作成です。


---

## 3\. セットアップ手順

### ステップ 1: プラグインのインストール

```
/plugin marketplace add https://github.com/ichiro16go/sakurai-skills
/plugin install sakurai-skills@sakurai-skills
```

ローカル開発中は、リポジトリ直下を指定して試せます。

```
claude --plugin-dir /path/to/sakurai-skills
```

hooks は `hooks/hooks.json` 経由で自動登録されるため、`settings.json` の編集は不要です。

### ステップ 2: 動作確認（テスト）

1. **注入テスト**: トリガー（例:「ジャンプ」）に反応してルールが標準出力に注入されるか確認します。

```
echo '{"prompt": "ジャンプ処理を作って"}' | CLAUDE_PLUGIN_ROOT=$PWD CLAUDE_PLUGIN_DATA=/tmp/sakurai-data hooks/user_prompt_submit.sh
```

*→* *[自律成長ルール注入]* *というヘッダーと該当 directive が出力されれば成功です。*

2. **安全ガードテスト**: 破壊的コマンドが正しく阻止されるか確認します。

```
echo '{"tool_input": {"command": "rm -rf /"}}' | hooks/pre_tool_use.sh; echo $?
```

*→* *[BLOCKED]* *と表示され、終了ステータス* *2* *（ツール実行ブロック）になれば安全ガードが有効です。*

---

## 4\. 日常の運用フロー

### ① 作業中の自動注入（何もしなくてOK）

ユーザーがプロンプトを入力すると、`user_prompt_submit.sh` が裏でキーワード（`trigger`）を走査します。 合致したルールがあれば、AI の回答生成前に指示が自動注入され、`${CLAUDE_PLUGIN_DATA}/rule_metrics.json` にヒット実績が記録されます。

### ② ターンの終了・区切りでの「記録」

機能の実装やデバッグが一段落した際、Claude Code に向かって以下のように伝えます。

&gt; **ユーザー**: 「今の作業の学びを記録して」 または `/record-rule`

Claude は会話から以下の形式で 1行ルール案 を作成して提示します：

```
{"id": "rule_004", "trigger": ["ヒットストップ", "打撃感"], "directive": "打撃時は1〜3フレームの静止（ヒットストップ）を挟み、強攻撃ほど長めにして手応えを強調すること", "scope": "game_dev", "status": "active"}

```

ユーザーが「OK」または「y」と返答すると、`${CLAUDE_PLUGIN_DATA}/rules.local.jsonl` に追記されます（同梱 `rules.jsonl` はプラグイン更新で上書きされるため）。
ルール化の際は `references/` の該当カテゴリを根拠として確認し、directive 末尾に `（桜井哲学：<カテゴリ>）` を付けます。

---

## 5\. ルール作成の鉄則（桜井政博の哲学より）

* **「平凡な正論」は記録しない**: 「わかりやすいコードを書く」「バグに気をつける」といった一般論はノイズになるため禁止。 **「〇〇のときは、あえて××を捨てて△△を最優先する」** というトレードオフのある判断のみを残す。
* **「遅さは罪」・贅肉を削ぎ落とす**: directive は長文にせず、1〜2文で完結させる（AI が即座に解釈できる密度にする）。
* **秘密情報・個人情報の排除**: 特定の社内URL、IP、認証キー、実名などは抽象化して記録する。

---

## 6\. ルールの昇格・メンテナンス（複数セッション計測）

`${CLAUDE_PLUGIN_DATA}/rule_metrics.json` には、ルールごとの活用セッション履歴が蓄積されます。

```
"rule_001": {
  "hit_count": 8,
  "session_hits": ["sess_01", "sess_02", "sess_03"],
  "last_triggered": "2026-11-17T09:30:00"
}

```

* **チーム昇格の目安**: `session_hits` が **3セッション以上** に達したルールは「普遍的に役立つ教訓」として認定し、チーム共通のプロンプトやコーディング規約へ昇格提案を行います。
* **定期的な棚卸し（淘汰）**: 長期間発火していないルールや、状況が変わって不要になったルールは `status: "archived"` に変更するか、該当 jsonl から削除してコンテキストの鮮度を維持します。

