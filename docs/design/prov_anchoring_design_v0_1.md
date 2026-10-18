# (2.5) 来歴の固定（provenance anchoring）— 設計 v0.1

**日付:** 2026-09-20
**著者:** masaomi（起草は Claude Fable 5.1、このセッション）
**状態:** **凍結 v0.1.10（2026-09-21、operator 決定）。現在 v0.1.14 —— 凍結後の個別改訂を 4 件反映（§14 の先頭 4 行。v0.1.14 は計算資源の欄（§6.2、2026-10-17 実装）。v0.1.11 は U1b の実装が突き当たった事実 2 件、v0.1.12 は 2026-10-11/12 の operator 決定 3 件——発行の関門としての immutable、CPU と OS、ZK 証明の検証——で §6.1 に集めた。v0.1.13 は同じ日の operator 決定で、v0.1.12 の関門を撤回し、Tier 3 の route B の線を D11 の元の形に戻した。いずれも review の巡ではない）。** これ以降、設計 review の巡は回さない。理由は §14 の凍結の記に書いた——
round 5〜8 は名目上は設計 review だったが、産出物の 9 割近くが adapter の実装修正であり、設計の review に test が走っていること
自体がその徴候だった。残る懸案は review の巡ではなく**実装の queue** に置く。設計に変更が要るときは、実装が突き当たった事実を
持って個別に改訂する。以下は凍結時点の状態の記録（round 8

（3 席回答、全員 REVISE）の (b) を反映——境界の欄の有無を key で見る（JSON の `false` が素通りしていた）、文字列の欄に object が来たら「無い」扱い（Ruby の描画が署名に入り interpreter で等級が変わっていた）、段の `input_list`/`output_list` と拡張の `checksums[]` も境界へ、`sha256` は欄の有無で見る、`scm_extension` が object でなければ空にせず取り除く（**round 7 の境界規則が自分で作った欠陥**）、述語の返り値を anchor が log に出さない規則を §6 に明記。code は adapter 0.3.7 / predicate 0.3.7、test 77 本緑。v0.1.9: round 7（4 席全員回答、全員 REVISE）の (b) を反映——正規化を経路ごとの列挙から**束が入る境界の一箇所**に移した。`script[]` の裸の文字列は実物の nf-prov が書く読める申告なので例外として明記（v0.1.8 の文が実装と食い違っていた）。checksum の経路には locator が要る（道具・runtime も入力に揃える）。読めない項目は container と package の両方の経路を弱める。同強の SCM 宣言が食い違えば記録しない。読めない digest も食い違い扱い。`record_version` を 0.2 に。code は adapter 0.3.6 / predicate 0.3.6、test 72 本緑。v0.1.8: round 6（3 席回答、全員 REVISE）の (b) を反映——「読めない項目を落とさない」を **object でない要素**まで広げ、項目を読むすべての場所に一つの規則として当てる。checksum と版の枝より「何も名指さない」の判定を前に置く。container の経路も digest の形で固定。`.x` は全候補を走査。拡張 block は全部を統合。`scripts_total / scripts_with_checksum` を記録の欄に。code は adapter 0.3.5 / predicate 0.3.5、test 67 本緑。v0.1.7: round 5 の subprocess 席で唯一返答した opus5 の (b) 5 件を反映——読めない項目を落とさず absent として数える、scheme 無しの digest は registry の形のときだけ image、SCM extension の複数は最弱、runtime の重複削減は predicate の規則そのもの。code は adapter 0.3.4 / predicate 0.3.4、test 58 本緑。v0.1.6: round 5 の persona 3 席の (b) を反映——script[] は全項目の checksum で pin、v/V 始まりの候補も拒否語を見る、範囲の印はどの語にあっても ranged、§8 json の言い方と submission_key の組成。code は adapter 0.3.3 / predicate 0.3.3、test 53 本緑。round 5 の記録は L2 `review_r5_prov_anchoring_v0_1_5_20260921`。v0.1.5: round 4（REVISE、5 席全員回答）の残り H1–H4 を反映——H1 code（範囲の印の語、拒否語の位置、runtime の重複、image 参照の形、checksum の形、例外の cause）、H2 §6/§7 idempotency は submission_key から、H3 script の checksum で workflow が immutable に届く、H4 §7/§8/§9/§10-14 の文言。round 4 の記録は L2 `review_r4_prov_anchoring_v0_1_4_20260921`。v0.1.4: round 3（REVISE）の (a)/(b) を 5 件 G1–G5 に束ねて反映——G1 §5 版の規則・DOI・runtime、G2 §6 null 欄と正準化規則の署名、G3 §7/§10-14 読み口を place route に、G4 §8 検証者の言えること、G5 §6/§13.4-1 誤り文と拡張 checksum の結合。round 3 の記録は L2 `review_r3_prov_anchoring_v0_1_3_20260921`。v0.1.3 まで: round 2 の (a)/(b) を 5 件の直しに束ねて反映——F1 §5/§13.4-1 帳簿の直し（段の同一性・重複除去・継承の数え方・版の規則・locator の上限）、F2 §13.4-3 内部入力の順序規則、F3 §6/§7 記録と core の変更 4 件、F4 §7/§8 検証者の読み口と誤り符号、F5 言い回し。code は adapter 0.3.0 / predicate 0.3.0 / tier2 0.4.1 で反映済、test 41 本緑。round 1 の記録は L2 `review_r1_prov_anchoring_v0_1_1_20260920`、round 2 は `review_r2_prov_anchoring_v0_1_2_20260920`。改訂履歴は §14）
**前提の文書:** KairosChain L2 `genomicschain_business_model_direction_20260919`（事業上の位置づけ、§3 が主張の境界の正本）、
GenomicsChain L2 `service_2_5_dev_plan_notes_20260920`（コードの現状）、`docs/demos/service_2_5_principle_20260920/demo.html`（原理）、
記憶 `warranty-scope`（言葉づかいの規則）、`genomicschain_core` design v0.4.1（package は v0.5.0。SubmitCore の経路。文書は KairosChain 側、コードは `submit_core.rb` の注釈が写し）

---

## 0. 一行で

顧客の pipeline が出した**来歴の束**（BioCompute Object か Workflow Run RO-Crate）を、顧客自身の鍵で署名して anchor に固定し、
束の digest・固定度の等級（束の locator が第三者に何を許すか）・署名者・時刻だけを記録する。束と値は顧客の手元に残る。
固定が主張するのは「この束はこの時刻にこの digest だった」と「等級は N」の 2 つで、「再構築できる」とは言わない。

## 1. この設計が新しく作るもの、作らないもの

```
作る                                          作らない（既にある / 範囲外）
─────────────────────────────────────────    ─────────────────────────────────────────
入力アダプタ  束 → 正規化した来歴 (§4)        SubmitCore の経路（digest 再計算・署名検証・
固定度の述語  正規化 → 等級 (§5)                bearer 束縛・重複回復）— genomicschain_core v0.5.0。
verdict_spec/prov.rb  署名される同一性 (§6)     ただし core に 4 か所だけ手を入れる（§7: 登録の汎用化、
prov_attestation.schema.json  記録の形 (§6)     idempotency の fallback、attestor の ttl、store_proof! の proof_ttl）
gc_prov_submit  anchor 側の tool (§7)         6 等級の目盛り — genomicschain_tier2/pin_strength.rb
gc_prov_proof   anchor の公開読み口 (§7, §8)   anchor の proof 保管 — Synoptis（TTL は §6 で明示する）
gc_prov_check   顧客側の tool (§7)            第二の機関目撃者 — v0.2 (§10)
gc_prov_verify  検証者側の tool (§7)          束の形式そのもの — IEEE 2791-2020 / WRROC を使う
gc_prov_write   書き出し器・補完器 (§4.1)      再構築と実行 — (iii)、別会社。価格 — 事業側
client の --tier prov (§7)
```

## 2. 用語

| 語 | 意味 |
|---|---|
| 束（bundle） | pipeline の来歴を書いた 1 ファイル。`bco.json`（BioCompute Object, IEEE 2791-2020）または `ro-crate-metadata.json`（Workflow Run RO-Crate。規格の最新は 0.6 だが、nf-prov 1.7.0 が書くのは profile 0.1 — §13）。Nextflow の `nf-prov` plugin がどちらも出す（Nextflow 25.10 以上） |
| digest | 束の canonical JSON の SHA-256。正準化の規則は名前で記録に載せる（`bundle_digest_canonicalization: kairos-sorted-json-0.1`）: 鍵を byte 順に再帰的に並べ替え、空白なし、文字列は JSON の最小 escape（非 ASCII はそのまま UTF-8）、整数はそのまま、小数は Ruby の `Float#to_s`。`KairosMcp::Manifest.canonical_json_sha256` がその実装。小数の `Float#to_s` は Ruby の実装に依るので、この規則は **Ruby 以外の実装では小数を含む束で digest が一致しないことがある**——v0.1 の限界として明記し、RFC 8785（JCS）への移行を v0.2 の候補にする理由の一つ（§10-12）。検証者は file の sha256 ではなく、この規則で digest を取り直す |
| 等級（grade） | 束に書かれた環境が第三者に何を許すかの目盛り。`immutable / versioned / ranged / floating / local_path / absent` の 6 段。Tier-2 と同じ |
| 固定（anchor） | digest・等級・署名者・時刻を Synoptis proof として anchor に記録すること |
| 提出者（submitter） | 束に署名した鍵の持ち主。**顧客**。proof の `submitter_pubkey` |
| 目撃者（attester） | proof を発行した anchor（MMP id）。GenomicsChain。proof の `attester_id` |
| 検証者（verifier） | 束と proof id を受け取り、digest と等級を計算し直して proof と突き合わせる第三者。サービス (2.5) の役務 |

## 3. 全体像

```
顧客の環境                         anchor (meeting.genomicschain.io)            検証者
────────────────────              ─────────────────────────────────           ──────────────────
Nextflow + nf-prov
   │ bco.json / ro-crate-metadata.json
   ▼
gc_prov_check（網なし）
   digest, 等級, signed_params
   │
   ▼
gc_submit_client --tier prov
   顧客の ed25519 鍵で
   {mcp_tool_name, params, nonce,
    chain_tip_hash} に署名
   │  HTTPS, 顧客の pubkey に束縛した Bearer
   ▼                              gc_prov_submit
                                    束を verbatim 受領 → digest 再計算
                                    → 等級を再導出 → 署名と一致を確認
                                    → Synoptis proof 発行
   ◀── proof_id, claim ──────────   束は保存しない（記録は同一性と数だけ）
   │
   │ 束 + proof_id を渡す（顧客の判断）
   └────────────────────────────────────────────────────────────────────▶ gc_prov_verify
                                                                            digest・等級を再計算
                                    ◀── gc_prov_proof(proof_id) ────────     envelope の manifest と照合
                                                                            「確かめられたこと／
                                                                              確かめていないこと」を出力
```

原理デモとの対応: デモの節 2 = `gc_prov_check`、節 3 = `gc_submit_client` + `gc_prov_submit`、節 4 = `gc_prov_verify`、節 5 = (iii)（この設計の外）。

## 4. 入力アダプタ — 束を正規化する

**目的:** BCO と WRROC は形が違うが、等級を出すのに要る情報は同じ 7 種類。アダプタは束を読んで、この 7 種類だけを持つ
正規化した来歴（`NormalizedProvenance`）に落とす。**digest は正規化前の束から取る**（束は verbatim が主語。正規化は等級のためだけ）。

固定して記録する条件は記憶 `warranty-scope` の 7 つ。各条件が束のどこから来るか:

| 条件 | BCO (IEEE 2791-2020) の出所 | WRROC の出所（規格 0.6。nf-prov は profile 0.1 を書く、§13） | 等級の出し方（§5） |
|---|---|---|---|
| 入力データ | `io_domain.input_subdomain[].uri` / `.sha1_checksum`（規格の欄は SHA-1）。SHA-256 は `extension_domain` の `genomicschain_extension.checksums[]` を locator で結合（§13.4-1、補完器が書く） | `CreateAction.object` の `File.sha256` / `contentUrl` | checksum の欄あり→immutable。無ければ locator だけで: DOI→versioned、URL→floating、path→local_path。**locator の文字列だけで immutable にはならない**（§5）。locator の読めない項目も落とさず `absent` として数える（round 5） |
| コード（workflow 本体） | `execution_domain.script[]`（全項目）、`extension_domain` SCM (repo, commit)。各 script の SHA-256 は `genomicschain_extension.checksums[]` を script の locator で結合（round 4） | `ComputationalWorkflow` の `url` / `version` / `codeRepository` | commit hash（40/64 hex）→immutable。`script[]` の**すべて**の項目に checksum の欄→immutable、一つでも欠ければ（commit hash が無い限り）floating——並び順に依らない（round 5、3 席: 最初の 1 項目だけ読むと配列の順が署名される等級を決めた。SCM の無い束——`gc_prov_write` が shell / R から書く束、local 起動の Nextflow——が floating 止まりにならない経路、round 4）。記録には `scripts_total / scripts_with_checksum` も残す。SCM extension が複数あれば**最弱**の宣言を取る（commit hash > symbolic な名前 > commit 無し。round 5、opus5: 最初の 1 件だけ読むと、hash と branch 名の並び順が署名される等級を決めた）。それ以外の名前→floating（tag か branch かは束に無い。tag らしさは等級の外の欄 `workflow_ref` に）。hash の形で判定するのは名前の推測ではない: hash はその木を自らの hash で名指すので、形が内容を決める |
| ライブラリ・ツール | `execution_domain.software_prerequisites[]`（workflow 全体）と `pipeline_steps[].prerequisite[]`（段ごと） (name, version, uri, sha1_checksum)。SHA-256 は入力と同じく `genomicschain_extension.checksums[]` を uri で結合（round 3） | `SoftwareApplication.softwareVersion`、`ContainerImage.sha256` / `tag` | 二経路。版は package の経路: checksum→immutable、release の形の版→versioned（規則は §5 に言葉で）、範囲→ranged、それ以外→floating。image は container の経路: digest→immutable、tag→versioned、なし/latest→floating。name も uri も読めない項目は落とさず `absent`（段の自分の宣言として数え、継承させない。round 5） |
| 参照ゲノム | `external_data_endpoints[]` または input のうち参照とわかるもの | `File` のうち `FormalParameter` 名が参照を指すもの | データと同じ。**参照かどうかは名前の推測**→ `reference_detection: heuristic` と記録 |
| パラメータ | `parametric_domain[]` (param, value, step) | `PropertyValue` (name, value) | 存在の有無のみ。等級には入れず `params_count / params_total` を数える |
| 乱数シード | パラメータのうち `seed` を含む名前で値を持つもの | 同左 | 存在の有無のみ。`seed_recorded: true/false`（false は「seed 無し」ではなく「記録に無い」）。名前の推測なので等級の横の `seed` 欄に出し、署名しない（§5、round 2） |
| 実行環境の版 | `execution_domain.script_driver` と、同名の `software_prerequisites` 項目（版・uri・checksum。SHA-256 は extension の `checksums[]` を uri で結合）。同名の項目が複数あれば、各項目を §5 の規則で等級づけして**最弱**の項目を取る（script[] も同じ向き: 全項目の checksum が要る）（並び順に依らない。round 4: 最初の 1 行だけ読むと並び順が署名される等級を決めた） | `SoftwareApplication`(Nextflow) の `softwareVersion`、`agent` | checksum の欄あり→immutable。locator が **OCI image 参照そのもの**（`docker://…@sha256:…`、または scheme 無しなら registry の形——先頭成分に `.` か port、あるいは `/` の無い一成分）で digest つき→immutable。URL や path の末尾に `@sha256:` を足しても上がらない（round 3 で絶対 path、round 5 で `tools/awk@sha256:…` の相対 path を実測）。release の形の版→versioned、範囲→ranged、それ以外の版→floating、なし→absent。重複の削減は predicate の `runtime_grade` そのものを呼ぶ（adapter に写しを持たない。round 5: 写しを通るか否かが load 順で変わり、署名される等級が束の bytes でなく entry point で決まっていた） |

**拡張 block の読み方（round 6）。** `extension_domain` に `genomicschain_extension` が複数あるとき、先頭の 1 件だけを読むと
checksum の集合が配列の順に依存する（補完器が producer の block と別に自分の block を書く運用で起きる）。全 block を統合して読み、
`checksums[]` は連結する。producer を名乗る block が複数あって食い違うときは、どちらも記録しない——順序に選ばせない。
同じ locator に異なる digest が二つ与えられていたら、その locator は **pin されていない**ものとして扱い、notes に残す。
束が一つの file について二つのことを言っているとき、どちらが勝つかを配列の順が決めてはならない。**読めない digest も同じ**
（round 7）: `sha256` の欄があって 64 桁 hex でないものは**失敗した申告**であって、無いのとは違う。良い digest と読めない digest が
並んだときも pin しない——これを無視すると、でたらめを書いた束が、確かめられる食い違いを書いた束より上に来る。`sha256` の欄が
そもそも無い項目は digest について何も言っていないので無視する——**欄の有無で見る**ので、`null` や空文字で書かれた `sha256` は
「読めない申告」であって「無い」ではない（round 8、codex: 空欄なら pin が残り、`"?"` なら外れる、という食い違いがあった）。なお、ここで pin しないのは**拡張が与える SHA-256** であって、
項目自身の `sha1_checksum` 欄は別の申告なので生き残る（round 7、codex: notes の文言が広すぎた）。

SCM の宣言も同じ規則に従う（round 7）。**同じ強さの宣言が複数あって食い違うとき**——比べるのは `scm_repository`・`scm_commit`・
`scm_path` の三つ組で、どれか一つでも違えば食い違い——は、どちらも記録しない。最弱を採る規則だけでは同率のときに配列の順が決め手になってしまい、それは上と同じ形の
逆転である。

### 4.1 束を出す側（producer）は差し替え可能にする — Nextflow に縛らない（09-20 追記）

利用者の指摘: nf-prov を唯一の入口にすると「全部の計算を Nextflow で書く」という第三者依存が生じる。
アダプタが読むのは **形式（BCO / WRROC）**であって nf-prov ではないので、束を出す側は複数持てる。

| producer | 対象 | 自動度 | 到達できる固定度 | 状態 |
|---|---|---|---|---|
| Nextflow + nf-prov（既定） | Nextflow で回す pipeline | 全自動（config に 1 block。fixture の `prov.config` は 13 行） | **そのままでは `absent`**（U0 実測 §13: container もツールの版も checksum も束に無い）。`gc_prov_write --from-nextflow-run` で補うと、tag だけなら versioned、digest と checksum まで取れば immutable | v0.1。U0 済（2026-09-20、fixture あり） |
| `gc_prov_write`（汎用の最小書き出し器。§13 以降は nf-prov 束の補完器も兼ねる） | shell・R・Python・SUSHI/ezRun など、実行系を問わない。Nextflow の実行 dir を渡せば nf-prov の束を補う | 半自動: 段の一覧（コマンド）を顧客が書き、ツールの版・container digest・入出力の checksum・パラメータ・seed・実行系の版は script が集める | 記録した分だけ。checksum を取れば immutable、取らなければ floating 止まり（floating を超えられない、の意。入力が相対 path なら全体は `local_path` まで落ちる——v0.1.11 で実測） — 等級がそのまま見せる | **U1b 済（2026-09-21）**。writer 0.1.0、`bin/gc_prov_write.rb` ＋ `lib/genomicschain_prov/writer*`。Tier-3 の実行系（local / thoa）が自分の実行を束にするのにも使う |
| SUSHI/ezRun の書き出し器 | FGCZ の SUSHI で回した解析 | 全自動（SUSHI 側に Ruby で足す） | SUSHI が持つ版情報の範囲 | v0.2 候補。SUSHI は自前なので足せる |
| 他の実行系が自分で出す WRROC | Galaxy、CWL（cwlprov → WRROC）、WfExS | 実行系まかせ | 実行系の記録の範囲 | WRROC アダプタ（U6）で読む。Snakemake・WDL は出す物があるか未確認 |

原則: **束は公開標準（BCO / WRROC）で、顧客はそれを持って GenomicsChain から離れられる。** 逆向きの縛りも作らない。
`gc_prov_write` が出す最小の BCO は必須 domain だけを埋め、値は入れず checksum を入れる（§4 の表と同じ 7 種類）。

**v0.1 は BCO だけ実装し、WRROC は v0.2。** 理由: BCO の `execution_domain` は上の表の 3 行に平らに対応し、WRROC は JSON-LD の
`@graph` を辿る必要がある。どちらも同じ `NormalizedProvenance` に落ちるので、後から足しても §5 以降は変わらない。
**U0 で確認済（2026-09-20、§13）:** nf-prov 1.7.0 の `bco.json` は SCM extension（repo・commit・path）を書き、`sha1_checksum` は
入力 0/8・出力 0/16 で書かない。ツールの版と container は欄ごと無い。U0 は「nf-core/demo の test profile を 1 本走らせて
bco.json を取る」で、fixture は `genomicschain_prov/test/fixtures/nfcore_demo_1_2_0/`。

```ruby
# genomicschain_prov/lib/genomicschain_prov/normalized.rb — U1 で実装した形（2026-09-20）。
# software / containers を最上位に置くのは、BCO がツールを workflow 単位（software_prerequisites）で持つため。
# inputs[]['internal'] は §13.4-3 の内部入力の規則。notes はアダプタが「無い」と見た事実（値は作らない）。
NormalizedProvenance = Struct.new(
  :format,          # 'bco' | 'wrroc'
  :format_version,  # BCO の spec_version URL / WRROC の conformsTo profile
  :producer,        # {'name','version'} か nil（束が名乗らなければ nil。nf-prov は名乗らない）
  :workflow,        # {'name','version','repository','commit','ref_kind','path','script',
                    #  'scripts_total','scripts_with_checksum','checksum'}——後ろ三つは round 6–7 で足した。
                    #  scripts_total / scripts_with_checksum は §6 の署名欄でもある
  :runtime,         # {'engine','version','locator','checksum'} か nil
  :software,        # [{'name','version','locator','checksum','stage'}] runtime を除く全ツール
  :containers,      # [{'ref','name','stage'}] software のうち locator が OCI image 参照のもの、
                    #  および読めない項目（どちらの経路だったか分からないので両方を弱める、round 7）
  :stages,          # [{'id','step_number','name','description','inputs','outputs','software','container'}]
                    #   id は step_number で並べ替えた後の位置（1 始まり）。段ごとの項目の 'stage' はこの id
  :inputs,          # [{'name','locator','checksum','internal','reference_hint'}]
  :outputs,         # [{'name','locator','checksum','mediatype'}]
  :params_total, :params_count, :seed_recorded,
  :notes,           # [String]
  keyword_init: true
) do
  def inputs_external = inputs.reject { |i| i['internal'] }   # 等級に入る入力
  def inputs_internal = inputs.select { |i| i['internal'] }   # 数だけ記録する入力（§13.4-3）
end
```

## 5. 固定度の述語 — 正規化した来歴から等級を出す（「再構築十分性」とは呼ばない: 等級は locator が第三者に何を許すかであって、再構築できることではない）

**規則は決定的である。** 同じ束から同じ等級が出る。顧客が自分で走らせて同じ答えを得られること（Tier-2 と同じ理由: 争えるが、水掛け論にならない）。

```
各項目 → 6 等級（image は pin_strength.rb の container。版は下の「版の規則」。checksum の欄があれば immutable。
        │        入力の locator は文字列だけでは immutable にならない——locator 全体が DOI→versioned、URL→floating、
        │        path→local_path。部分文字列は名前であって識別子ではない（round 2: `#sha256:`、round 3: `10.1234/` の dir））
        ▼
段 = pipeline_steps を step_number で並べ替えた後の**位置**（1 始まり）。step_number が重複・欠落・非整数（JSON の整数か、
   任意の `-` に数字が続く文字列以外。`2.0` は非整数）なら FormatError。object でない要素が並んでいても FormatError（落とすと stages_total が
   縮んで最弱の段が消えうる、round 3）（round 2: 番号そのものを id にすると、重複した段が宣言を共有してしまう）
        │
        ▼
段ごとの環境 = **その段が自分で宣言した項目**について、package の経路と container の経路の**強い方**
   （§10-8: 経路は二つ、一方で足りる）。自分で何も宣言しない段だけが workflow 全体の項目（BCO の
   software_prerequisites）を**代わりに**使う——継承は代替であって加算ではない（round 2: 加算にすると
   workflow 全体の 1 本が N/N と読め、何も言わない段を持ち上げた）。段が一部でも自分で宣言すると、その段では workflow
   全体の宣言は両経路とも使われない——段ごとの bare name 1 本の申告が、継承していた等級より下げうる（round 3 で実測:
   workflow 全体に digest 固定の image、段 3 だけ版なしの awk → 段 3 は floating）。補完器は段ごとにだけ書くので
   この混在は起きない。経路ごとの代替（container は container を、package は package を継承）に変えるかは §10-15。
   段が 0 本なら環境は absent（暗黙の段は作らない）
        │
        ▼
分類の等級（immutable > versioned > ranged > floating > local_path > absent）
   environment = 段の**最弱**（round 1: 1 段だけの digest 固定で全体を上げない）
   inputs / workflow / runtime = 項目の最弱。software / container も分類として最弱を記録する（直す場所が分かるように）
        │
        ▼
全体の等級 (grade_overall) = environment・inputs・workflow・runtime の 4 つの最弱
        │
        ▼
数（分母つき）: stages_total / stages_with_environment（代替込み）/ stages_with_own_environment（自分で宣言した段。
               claim に載るのはこちら）, software_total / software_immutable / ..., containers_total / ...,
               inputs_total / inputs_with_checksum / inputs_internal, outputs_total / outputs_with_checksum,
               params_count / params_total
```

**版の規則（言葉で。predicate 0.3.7 の `version_grade`）。** BCO の `version` は自由文なので、空白で語に切って次の順で読む。
語の区切りは Unicode の空白（NBSP・全角空白も。round 4）。
(1) **拒否**: `latest / unknown / head / master / main / dev / devel / nightly / snapshot / stable / current / trunk / none / null /
unversioned`（前後に数字がついてもよい: `dev3`、`0latest`）が語として丸ごとあれば、文字列全体が **floating**（`1.0 latest` も `latest 1.0` も）。
**数字で始まる**候補の語（任意の v/V を挟んでもよい——round 5: `v1.0-SNAPSHOT` が tool 名として素通りした）を `- + . _ ~` で切った要素にこれらがあっても同じで、候補の走査より先に判定する（`0-unknown`、`1.0-SNAPSHOT`、`v1.0-SNAPSHOT`、`2.0.dev3`、`1.0latest`、`1.0 0-unknown`）。
それ以外の文字で始まる語は tool 名なので要素の拒否は当てない（`python3-dev 3.11.4` は versioned——round 4）。
(1') **範囲**: `< > ! *` がどの語にあっても、`~`/`^` で始まる語があっても、候補のどれかに `,` があっても、文字列全体が **ranged**（`> 1.0`、`GATK > 4`、`GATK> 4`、`1.0 *`、`1.0 >=2`——round 4: 印だけの語を tool 名として飛ばすと `> 1.0` が `>=1.0` より一段上に署名された。round 5: 印が tool 名に密着した `GATK> 4` も同じ）。`,` は語の中にあっても範囲の印ではない（`GNU bash, version 5.2.21`）。
(2) **候補**: 数字を含む語だけ、並び順に。各候補から Debian 型の epoch `N:` と末尾の `,` を落とす。数字の無い語は tool 名なので飛ばす
（`GATK 4.5.0.0`、`GNU bash, version 5.2.21` → 候補は `5.2.21` だけ。`GATK 4.5.0.0, HTSJDK 3.0.5` → 候補は二つ、どちらも versioned）。
(3') **全体印**: `x` だけの要素を持つ候補が**どれか一つでも**あれば、候補を採る前に文字列全体が **ranged**（`1.x`、`1.x.2`、
`1.x 1.0` も `1.0 1.x` も同じ——round 6: 採用候補だけを見ていたため、同じ申告の並べ替えで ranged と versioned に分かれた）。
範囲の印 (1') と同じ扱いで、位置に依らない。
(3) 候補を左から順に: 「任意の v/V、数字を `.` で繋いだ列、任意個の `- + . _ ~` 区切りの接尾」の形なら
**versioned**（`1.4-r122`、`0.12.1--hdfd78af_0`、`2.3~rc1`、`V1.2.0`）。どれでもなければ**次の候補へ**（`python3 3.11.4`:
`python3` は release の形ではなく、`3.11.4` がそう——tool 名を添えた申告が bare の版より下がることはない、round 3）。
(4) 候補が尽きれば floating（`HEAD`、`r122`、`5.2.21(1)-release`）。候補が一つも無いときは、範囲の印が文字列にあれば ranged（`*`、`GATK >`）、なければ floating。
round 2 の customer-skeptic 席が最初の正規表現で `GATK 4.5.0.0` と `bash 5.2.21` が floating に落ち、`0-unknown` と `1.x.2` が
versioned に通ることを、round 3 の opus5 席が `python3 3.11.4` が floating に落ちることを、skeptic 席が `GNU bash, version 5.2.21`
が ranged に流れることを、round 4 の codex と skeptic 席が `>= 1.0` が versioned に通ることを実測した。

- **最弱で決める理由:** 「再構築できるか」は一番弱い環に決まる。平均や多数決は、弱い環を隠す。最弱の規則は**必須の環**に当てる。
  環境だけは container か package 一覧のどちらか一方で作り直せる（代替経路がある）ので、**段ごとに**二つの強い方を取り、
  段の最弱を環境の等級とする（09-20 決定、round 1 で段ごとに改訂）。同じ tool が版と image の両方を名乗るなら、版は package の
  経路、image は container の経路で別々に等級づけする——実際に動いた `:latest` の image を正直に書くと等級が下がる、という
  逆の誘因を作らないため。
- **分類が空なら absent。** 何も申告しない producer が floating を申告した producer より上に来ないため。段の網羅は数で見せ、
  claim にも載せる——載せるのは **`stages_with_own_environment/stages_total`**（自分で宣言した段の数）で、代替込みの
  `stages_with_environment` は記録には載るが claim には載せない。workflow 全体に 1 本だけ宣言した tool が全段を覆うという
  申告は可能だが、claim は `0/N` と読める（round 2）。その真偽は `bundle_truthfulness` の外（v0.2 の検証者が `.command.run` と
  突き合わせる、§10-13）。
- **producer が選ぶ文字列は等級を上げない。** 入力が immutable になるのは checksum の欄だけ——欄の中身が hex の digest（sha1 40 桁、sha256 64 桁）のときだけで、それ以外は欄が無いものとして数え、notes に残す（round 4: `"?"` が immutable に通った）。locator に `#sha256:…` のような
  hash らしい部分文字列があっても、それは名前であって検査ではない（round 2 で実測: `inputs_with_checksum 0` のまま immutable に
  なっていた）。DOI も同じ: locator **全体**が DOI（`10.NNNN/…`、`doi:`、`doi.org/` の URL）のときだけ versioned で、
  `/data/10.1234/x.fa` の `10.1234/` は dir の名前（round 3 で実測: dir 名で local_path が versioned に上がっていた）。
  tier2 の `data_locator` は repo 内の設定値を読む道具なので部分文字列を hash や DOI と読むが、prov は使わない——
  入力の locator は prov 自身の規則（DOI 全体 / URL / path）で読む。runtime も同じ: locator が OCI image 参照そのものの
  ときだけ digest を見る（URL の末尾の `@sha256:` は名前）。**scheme の無い digest つきの名前は、registry の形をしているときだけ
  image と読む**——先頭の成分に `.` か port があるか（`ghcr.io/org/img@sha256:…`、`localhost:5000/img@sha256:…`）、`/` を含まない
  一成分（`ubuntu@sha256:…`）のとき。`tools/awk@sha256:…` は repo 相対の path と見分けがつかないので image ではない。Docker Hub の
  名前空間を image として書きたければ `docker://` を付ける（round 5、opus5 で実測: round 3 が絶対 path を塞いだあと、相対 path が
  container の経路を immutable にしていた）。用心は digest の形にだけ掛ける——理由は下の「緩みは緩みとして明記する」に書いた。
- **読めない項目は落とさない——最弱として数える。** locator も name も読めない `input_subdomain` / `prerequisite` の項目は、
  従来 adapter が捨てていた。`inputs_total` は署名される数なので、捨てると分母が縮み、**欄を書かない producer が、同じ欄を正直に
  書いた producer より上の等級になる**（round 5、opus5 で実測: checksum つき 1 本 + locator 無し 1 本の束が `inputs_with_checksum 1/1`・
  `immutable`、二本目を path で書くと `1/2`・`local_path`）。落とさず `absent` として等級づけ、数にも入れる。段の
  `prerequisite[]` も同じ: 読めない項目 1 本はその段の**自分の宣言**であって沈黙ではないので、workflow 全体の宣言を継承しない
  （継承すると floating の段が immutable に上がっていた）。object でない段を `FormatError` にする §5 の理由——「落とすと
  stages_total が縮んで最弱の段が消えうる」——と同じ理屈を、同じ記録の他の分母にも適用する。

  **この規則は、束が入ってくる境界で一度だけ適用する**（round 7）。round 5 は見つかった経路ごとに、round 6 は列挙した 5 配列に
  当てた。どちらも「当て忘れた場所」を残した——round 6 は `parametric_domain[]`、SCM の block、runtime が同じ配列を自分で走査する
  箇所を落としていた。そこで正規化は `load` の直後に一箇所だけ置き、**そこを通った後の束には object でない要素がどの配列にも無い**
  状態にする。以後どの場所も当て忘れようがない。対象は `script[]`、`software_prerequisites[]`、各段の `prerequisite[]`、
  `input_subdomain[]`、`output_subdomain[]`、`parametric_domain[]`、`extension_domain[]`（その中の `scm_extension` も）。
  正規化は再 parse した私用の複製に対して行い、digest の主語は**元の bytes**（§4）なので署名される対象は触らない。
  段の `input_list` / `output_list` も対象に入れる（round 8、codex が再現）——署名される分母には直結しないが、§13.4-3 の内部入力の
  判定が読む証拠であり、object で書かれると要素が落ちて**弱い入力が等級から消えていた**。拡張の `checksums[]` も同様に境界で正規化する。
  欄の有無は **key の有無**で見る（round 8、opus5 と codex）: Ruby の真偽で見ると JSON の `false` が素通りし、`"script": false` が
  文字列 `"false"` として下流に届いて `scripts_total: 1` を署名していた。
  **文字列の欄も境界で守る**（round 8、opus5）: 文字列が来るべき欄に object が書かれていたとき、`to_s` で Ruby の描画結果を
  署名される同一性に入れてはならない。`Hash#inspect` の書式は Ruby 3.4 で変わったので、**同じ束の bytes が interpreter によって
  違う等級になる**。文字列か数値でなければ「無い」として扱う。
  **例外の例外**: `scm_extension` が object でないときは空にせず**取り除く**。空にすると「何も名指さない SCM 宣言」として最弱選択に
  入り、別の block にある正しい commit hash を押しのけてしまう（round 8、cursor。round 7 の境界規則が自分で作った欠陥）。読めない
  要素を残すのは、それが分母か段の自分の宣言を支えている場合であって、SCM の block はそのどちらでもない。

  **例外は `script[]` の裸の文字列** 一つだけで、これは読める申告である。実物の nf-prov 1.7.0 の束が `script` を文字列の配列で
  書いている（U0 の fixture がそれ）。よって文字列は object の形に持ち上げて locator として読み、**文字列でない非 object**
  （整数、真偽値、配列）だけを空の項目にする。v0.1.8 はここを「裸の文字列は locator として読まない」と 5 配列すべてについて書いて
  いたが、実装は `script[]` でそうしておらず、**文が実装と食い違っていた**（round 7、3 席が指摘）。正しい規則は上のとおりで、
  食い違っていたのは文の側である。規格が配列と定める欄が object や scalar で書かれていたら `FormatError`——`Array()` は Hash を
  対の配列に変えてしまい、それが項目として署名される分母に入る（round 7）。
- **checksum も版も、何を digest したかを名指していなければ等級を上げない。** 「何も名指さない項目は absent」の判定は、checksum の枝と
  版の枝より**前**に置く（round 6）。取得先の無い digest は第三者に何も許さず、等級が測っているのはまさにそれである。同様に、
  name も uri も無く version だけがある項目は、道具を名指していないので `versioned` ではなく `absent`。
  **checksum の経路には locator が要る**（round 7）: 入力は round 6 で既にそうなっていたが、道具と runtime は locator が無くても
  checksum で `immutable` に届いていた。同じ形について二つの関数が違うことを言っていたので、道具と runtime も揃える——名前だけの
  道具に checksum が付いていても `floating` 止まり。**数え方も等級に合わせる**: `inputs_with_checksum` は locator のある項目だけを
  数える（等級は absent なのに coverage には入る、という食い違いがあった）。
- **読めない項目は、二つの経路の両方を弱める。** 段の環境は container と package の**強い方**で決まる（§10-8）。読めない
  `prerequisite` を package の経路にだけ置くと、正直に書いた `docker://b:latest` を読めない要素に差し替えたとき container の経路に
  強い image だけが残り、**段の等級が上がる**（round 7、codex が再現）。読めない項目はどちらの経路だったか分からないので、両方に
  空の項目として入れる。結果、省略した束は正直な束より下（`absent` < `floating`）になる。
- **container の経路も digest の形で固定する。** tier2 の `PinStrength.container` は digest の**部分文字列**を pin と読む——repo の
  設定値を読む道具としては正しいが、署名される等級には使えない。`docker://tool:latest#@sha256:<64 桁>` が immutable に届いていた
  （round 6、codex が再現）。runtime と同じく、参照**全体**が image の digest 参照のときだけ immutable とし、digest らしい末尾を
  持つだけの参照は floating で打ち止める。
- **`.x` のような全体印は、どの候補にあっても全体に効く。** 候補を左から見て最初に release の形に合ったものを採ると、`1.x 1.0` は
  ranged、`1.0 1.x` は versioned になっていた（round 6、codex が再現）。同じ申告の並べ替えで等級が変わるので、`.x` は候補を採る前に
  全候補を走査する。範囲の印（`< > ! *`）が既にそうなっているのと同じ扱い。
- **拒否語が道具の名前と衝突する場合も、緩みとして明記する**（round 7、opus5）。拒否語（`latest`、`head`、`main`、`stable` など）は
  語全体として現れれば文字列全体を floating にする。そのため `head (GNU coreutils) 8.32` は floating、より不完全な `8.32` は
  versioned になる——「tool 名を添えた申告が bare の版より下がることはない」という §5 自身の原則と衝突している。承知のうえで
  こちらを採る: 拒否語を数字を含む語だけに限ると `latest 1.0` が versioned に通ってしまい、**producer が選んだ「latest」が署名
  される等級を上げる**。下振れ（正直な banner が過小評価される）と上振れ（曖昧な申告が過大評価される）なら、この設計は下振れを
  選ぶ。緩みの向きを明記しておく。
- **digest の形で残した緩みは、緩みとして明記する。** `/` を含まない一成分（`ubuntu@sha256:…`）は image として通す。これは Docker
  Hub の official image の形であり、意図した残余である。`tag` の形（`OCI_TAGGED`）には registry の形の検査を掛けていない——`tag` の
  経路は最大でも versioned までしか届かず、`biocontainers/fastqc:0.11.9` のような正直な申告を落とす損の方が大きいため。用心を
  digest の形にだけ掛けるのは、そこだけが immutable に届くからである（round 6、opus5 の指摘で文を実装に合わせた）。
- **署名される等級に名前の推測は入れない。** 参照ゲノム（`reference`）も、symbolic な ref の tag らしさ（`workflow_ref`）も、
  乱数シードの有無（`seed`。名前に seed を含む param の存在で見る推測）も、等級の横の欄に `detection: heuristic` として出す。
  seed は round 2 まで署名される数に入っていた（`seed_recorded`）。記録の `not_checked` に `seed_identification` を足す（§6）。
- **分類ごとの等級も記録する理由:** 全体が `floating` でも「入力は全部 checksum つき、container だけ `:latest`」と分かれば、顧客は直せる。全体だけでは直す場所が分からない。
- **参照ゲノムの検出は推測**なので、その分類は `grade_overall` に入れず、別欄 `reference`（`grade`・`detection: heuristic`・`count`）として出す。推測を署名される同一性に混ぜない。参照らしい入力も入力としては inputs の等級に入る（推測が外れても署名される等級は変わらない）。
- **等級が言わないこと:** 実際に再構築できるか。`immutable` でも取得先が消えていれば再構築できない。等級は「束に書かれた locator が第三者に何を許すか」であって、locator の先が生きているかではない。束に書かれた checksum は書かれたまま数え、取り直さない。記録の `not_checked` 欄に `locator_reachability` と `checksum_values_as_written` を書く。

## 6. 記録 — 署名される同一性と proof の中身

Tier-2 と同じ構造。**束が主語、同一性は束から導出、server が導出し直して署名と突き合わせる。** 顧客の言い分は一つも取らない。

```
Tier-1  digest subject = report.json        identity = report の欄
Tier-2  digest subject = adjudication       identity = adjudication から導出
Tier-3  digest subject = jobspec_json       identity = verdict_result
prov    digest subject = 束 (verbatim)      identity = 束から導出（アダプタ + 述語）
```

**署名される欄（`SIGNED_IDENTITY_FIELDS`）:**

```
subject_ref                 "prov:sha256:<bundle_digest>"  — 束が自分を名指す。顧客の文字列を claim に入れない
bundle_format               bco | wrroc
bundle_format_version       spec_version / conformsTo（束の自己申告。規格 schema への適合は検査しない → not_checked）
bundle_digest               canonical JSON sha256（server が再計算）
bundle_digest_canonicalization, outputs_digest_rule
                            digest を出した規則の名前（`kairos-sorted-json-0.1`、`gc-outputs-rows-0.1`）。署名する（round 3: 署名の外だと、
                            v0.2 で JCS に移ったあと検証者が v0.1 の束を「不一致」と印刷する）。等級と digest を決める手順の版は
                            **すべて署名し、それ以外は署名しない**
producer_name, producer_version   束の GenomicsChain extension が名乗る producer（無ければ null。nf-prov は名乗らない）
adapter_version, predicate_version, pin_strength_version
                            等級を出した手順の版: アダプタ（prov-adapter-bco-0.3.7）、述語（prov-predicate-0.3.7）、
                            PinStrength の**規則の版**（`PinStrength::RULE_VERSION`、pin-strength-0.1.0。tier2 の package 版
                            ではない——package を上げても規則が変わらなければ古い proof が「再導出不可」にならないように、round 2）。
                            検証者は三つが手元と一致するときだけ再導出する
grade_overall               6 等級
grade_software, grade_container, grade_environment, grade_inputs, grade_workflow, grade_runtime
stages_total, stages_with_environment, stages_with_own_environment
scripts_total, scripts_with_checksum
                            `script[]` の項目数と、そのうち checksum が結合した数。束の bytes から再導出できるので署名の内側に置く
                            （round 6: §4 が「記録に残す」と書いていたのに記録の欄にも counts にも無く、約束だけが浮いていた）
software_total, software_immutable, software_versioned, software_ranged, software_floating, software_local_path, software_absent
containers_total, containers_immutable, containers_versioned, containers_ranged, containers_floating, containers_local_path, containers_absent
inputs_total, inputs_with_checksum, inputs_internal
outputs_total, outputs_with_checksum, outputs_digest
                            outputs_digest は規則 `gc-outputs-rows-0.1`: checksum を持つ出力ごとに [name, algorithm, hex] の行
                            （name は文字列化、nil は ""）を作り、行を並べ替えて `JSON.generate` した bytes の sha256。
                            出力の**名前**も束縛される。値ではなく列の digest。checksum は書かれたまま。1 本も無ければ null
params_count, params_total
workflow_repository_sha256, workflow_commit  — repository は URL の sha256（私設 repo の名前を台帳に出さない。ただし束を持たない
                            者でも候補の URL を当てて sha256 を突き合わせることはできる——隠すのは名前であって存在ではない）。
                            commit は SCM extension の scm_commit そのまま（hash か名前）。無ければ null。tag らしさの推測
                            `workflow_ref` は署名の外（§5）
platform_cpu_architecture, platform_os_name, platform_os_release
                            v0.1.12（§6.1）。束の GenomicsChain 拡張の `platform` が名乗る値。書き出し器の自己申告で、無ければ null
zk_receipts                 v0.1.12（§6.1）。束の拡張の `zk_receipts[]` から導出した列。項目ごとに {receipt_sha256, image_id,
                            zkvm_name, zkvm_version, stage, journal_convention}。stage、receipt_sha256 の順に並べる。無ければ []
```

**null になりうる欄（5 つ）:** `producer_name` / `producer_version`（束が名乗らない。nf-prov）、`outputs_digest`（checksum つきの出力が
0 本）、`workflow_commit` と `workflow_repository_sha256`（SCM extension が無い——`gc_prov_write` が shell / R / Python の計算から
書く束は SCM を持たない。round 3: 必須のままだと §4.1 の最初の非 Nextflow producer が anchor に届かない）。schema は五つを
`["string","null"]` にし、null は「無い」の意味で署名に入る（v0.1.12 で `platform_*` の 3 つが加わり 8 つ。§6.1。v0.1.14 で `gpus_total`・`gpu_models`・`gpu_vendors_probed`・`machine_source`・`resources_sources` の 5 つが加わり 13。§6.2）。それ以外の署名欄は必須。**署名される欄の集合は `record_version` で
固定する**: 検証者は manifest の `record_version` の集合で `params` を組み立て、知らない `record_version` は版違いの見出しへ（§8）。
v0.1.8 で `scripts_total` / `scripts_with_checksum` を署名欄に足したので、**`record_version` は 0.2 に上げる**（round 7、opus5:
欄の集合を変えながら 0.1 のままなら、不変条件が自分の文面で破れている）。0.1 の proof はまだ存在しない——U3 が未着手なので、
この改版で失効するものは無い。以後、署名欄の増減は必ず `record_version` を上げる。

**server が決める欄（署名の外）:** `trust_tier = 'self_reported'`（提出者＝顧客自身の申告。Tier-2 と同じ語）、`toolchain`
（anchor の Ruby と platform。Tier-2 では digest subject の中にあったので署名できたが、束は grader の interpreter を持たないので
署名しない——round 1）、`seed`
（`{recorded, detection: heuristic}`。名前の推測なので署名の外——round 2）、`not_checked`（builder が固定した列 6 項目:
`locator_reachability`, `bundle_truthfulness`, `bundle_schema_conformance`, `checksum_values_as_written`,
`reference_genome_identification`, `seed_identification`。v0.1.12 で 3 項目を足して 9 項目——§6.1。schema は enum で固定し、client が送ってきた値は捨てる）、
`admission_rule` と `zk_verification`（v0.1.12、§6.1）。
同一性は「束の bytes ＋ 名前つきの手順の版」から導出される——束だけからではない。
**記録に入れないもの:** 束の本文、入力・出力の locator の列、パラメータの値、repository の URL。すべて digest で束縛し、顧客の手元に残す。
Synoptis の evidence 上限は 64 KB（`Config.max_evidence_size`）だが、記録は同一性と数だけ（試算 2.3 KB: §6 の欄を fixture の値で組み、
署名つき operator を含めて canonical JSON にした大きさ。U3 で実測に置き換える）なので余裕がある。

**束を残さない（不変条件、round 1 で明文化）:** anchor は束を 1 回の導出の間だけ memory に持ち、disk にも log にも書かない。
HTTP の access log は request body を記録しない設定にし、例外の trace は `params` を伏せる。**アダプタと述語が投げる例外の
message に束の値を入れない**（round 3: `FormatError` が JSON parser の断片や `spec_version` の値を写していた。message は欄の名前・
数・位置だけ。顧客側の `gc_prov_check` は顧客の machine で動くので詳しく出してよい）。束には絶対 path と全 param の値が
入る（§10-11 ii）ので、これが「束は顧客の手元に残る」という約束の実体。

**述語の返り値も束の内容である**（round 8、opus5）。`Predicate.grade` が返す `items[]` には `name`・`locator`・`reason`
（`version "…" names no release` のように**版の文字列をそのまま含む**）が入る。anchor 側はこの返り値を **log にも応答にも出さない**
——記録に載せてよいのは §6 が列挙する署名欄と数だけであり、`items[]` は顧客側の `gc_prov_check` が読むためのものである。
ここまで書いておかないと、`gc_prov_submit` の中の `logger.debug(result)` 一行で不変条件が破れ、しかも review する人が
根拠にできる規則が無い。U3 の test に「述語の返り値が anchor の log に現れない」1 本を含める。

**束の入口の上限（Gate A、round 1）:** 束は raw bytes で 2 MB まで、JSON の深さは 32 まで、`restricted_subset!`（NaN・U+2028 等の
拒否）を通す。Tier-2 の `dos_gate!`（64 KB）は束には**当てない**——nf-core/demo の束は `JSON.generate` で 57.6 KB（実測）、補完後は
試算 63.8 KB（round 1 の persona の計算。file は未作成）で、rnaseq 級は入口で弾かれてしまう。深さは `Manifest::DoSGate.compute_depth`
（public）を prov 側から呼んで見る——core には足さない（round 2）。**配備条件:** anchor の HTTP 層（puma / rack）の request body
上限が 2 MB 未満だと Gate A に届く前に落ちる。上限を 2 MB 以上に設定し、超過は Gate A の拒否と同じ文言で返す。

**proof の寿命（round 1、経路は round 2）:** Synoptis の既定 TTL は 86400 秒（24 時間）。engine の `create_attestation` は `ttl:` を
受け取れる（`ttl || @default_ttl`）が、core の `SynoptisAttestor#issue` はその引数を持たず、`SubmitCore.store_proof!` も渡さない
——TTL の経路は core の 2 か所を通す必要がある（§7 の (3)(4)）。prov の verdict_spec は `proof_ttl = 3153600000`（100 年。
KairosChain の `external_commitment_created` の記録に前例）を持ち、`store_proof!` が `spec.proof_ttl` を attestor に渡す。
Tier-1/2/3 の spec は `proof_ttl` を持たないので nil が渡り、engine の既定（24 時間）のまま——既存の挙動は変えない。
検証者は `expired` を「TTL を過ぎた」という鮮度の印として印刷し、「記録が無効」とは書かない。expired 以外の `valid: false` の
扱いは §8 の表。

**claim 文字列:** `prov:<predicate_version>:<grade_overall>:<stages_with_own_environment>/<stages_total>:<bundle_digest>:<submission_key>`
例: `prov:prov-predicate-0.3.7:absent:0/8:9bd92601…:<key>`。台帳を眺める人が、どの規則の版で出た等級か、段の何割が**自分の**環境を
宣言しているかを claim だけで読めるように（round 1: 1 段だけ固定した束が `immutable:30` と見えないため。round 2: workflow 全体の
1 本が `8/8` と見えないため）。述語の出力の `coverage` がこの `own/total`。Tier-2 の `tier2:<lock_state>:<proposed_demotions>:...`
と同じ発想。

**submission_key** は SubmitCore が `{digest_subject_hash, signed_identity, operator_pubkey}` から作る（既存）。同じ束を同じ鍵で再提出すると
既存 proof の回復になる（既存の recovery branch）。別の鍵で同じ束を出せば別の proof になる — これは仕様。誰が固定したかは鍵で決まる。
**回復は手順の版が同じときだけ**起きる: adapter / predicate / pin_strength のどれかが上がっていれば `signed_identity` が変わり
submission_key も変わるので、同じ束・同じ鍵でも新しい proof になる。これも仕様——古い版の等級は古い proof に残る。

**idempotency_key（round 3、round 4 で直した）:** prov では `sha256(submission_key)`。submission_key は署名される同一性の全体（三つの手順の版を含む）を
束ねているので、同一性が変わる再提出は必ず別の key になる。round 3 の `predicate_version` だけを足す形は、adapter か pin_strength だけが
上がって等級が変わらない再提出で衝突した（round 4、opus5 と codex）。

**submit 側の版のずれ（round 2）:** anchor の手順の版が顧客の `gc_prov_check` より新しい（または古い）と、顧客が署名した
`signed_params` の三つの版と anchor の再導出が一致せず IdentityMismatch になる。`gc_prov_submit` はこの拒否に anchor 側の三つの版を
添えて返し（`versions: {adapter, predicate, pin_strength}`）、`dry_run` でも同じ三つを返す。顧客は package を合わせてから出し直す。
版のずれに語彙が無いと、顧客には「一致しない」としか見えない。

**schema:** `genomicschain_prov/schemas/prov_attestation.schema.json`（置き場所は §7）。`record_type: prov_attestation`、
`record_version: 0.3`（§6。v0.1.8 で署名欄が増えたため 0.1 から 0.2 に、v0.1.12 で `platform_*` と `zk_receipts` が増えたため 0.3 に上げた。
どちらの時点でも proof はまだ存在しない）、`mcp_tool_name: gc_prov_submit`、`additionalProperties: false`。title は「pin strength」で、「再構築十分性」とは
書かない（等級は locator が第三者に何を許すかであって、再構築できることではない）。`not_checked` は必須で、builder が固定した
9 項目の列（上と §6.1）を enum で持つ。

### 6.1 v0.1.12 の追加 — 発行の関門（v0.1.13 で撤回）、CPU と OS、ZK 証明の検証（2026-10-11/12、operator 決定）

**なぜ。** ruling `ruling_service_plan_two_stage_drive_vk_20261011` の D9（ZK 証明を 11/15 から任意で添付できる）と D13（Tier 2.5 は
自己申告の構成的な記録のまま、immutable の要件と CPU・OS を足す）、および L2 `ruling_tier25_gate_and_zk_verify_20261012` の
G1（immutable は発行の関門）と G2（anchor が 11/15 から ZK 証明の中身を確かめる）。凍結後の個別改訂で、review の巡ではない。

```
                              今（v0.1.11）                     v0.1.12
発行するか                    どの等級でも発行                  grade_overall = immutable のときだけ（未満は拒否）
                                                                → v0.1.13 で撤回、どの等級でも発行に戻す（下の (1)）
CPU と OS                     欄が無い                          束の拡張 platform → 署名欄 3 つ（無ければ null）
ZK 証明                       欄が無い                          束の拡張 zk_receipts[] → 署名欄 zk_receipts。
                                                                証明の bytes は提出に添えて送り、anchor が検証してから記録
record_version                0.2                               0.3
not_checked                   6 項目                            9 項目
```

**(1) 発行の規則（v0.1.13 で G1 を撤回）。** anchor は**どの等級でも記録を発行する**。等級は述語が出したとおりに署名欄
`grade_overall` と分類ごとの `grade_*` に載り、その等級で何をしてよいかは記録を読む側——Tier 3 の route B、第三者——が決める。
記録には server が決める欄 `admission_rule: "prov-admission-0.2"` を置く（意味: 等級は計算したとおりに載せ、宣言されたすべての
ZK 証明が検証と照合を通った）。`dry_run` と `gc_prov_check` は、発行されるかどうかと、記録が載せる等級を出す。

*v0.1.12 の関門と撤回の理由。* v0.1.12 は `grade_overall` が `immutable` でない束を拒否していた（`GradeBelowRequirement`、
`admission_rule: "prov-admission-0.1"`）。operator は 2026-10-12 にこれを撤回した——「attestation はゆるく、署名された内容で
第三者が判断する」。G1 を採ったときの論拠は「関門は後からゆるめても、関門の下で出た記録はすべて immutable なので矛盾しない」で、
撤回はちょうどこの向きのゆるめにあたる。しかも撤回の時点で本番の記録は一つも無い（関門の下の記録は使い捨ての local anchor の
ものだけ）。検証器は `prov-admission-0.1` の記録を 0.1 の意味で読み続ける（`Identity::ADMISSION_RULES`）。撤回の記録は L2
`ruling_tier25_gate_withdrawn_20261012`。

**Tier 3 の route B（D11）**は、関門が無くなったので、記録の署名された等級を Tier 3 の側で読んで線を引く。線は D11 の元の形に戻す
（operator 決定 2026-10-12）: 「Tier 2.5 の記録があり、`grade_overall` ≥ `versioned`、`grade_inputs` = `immutable`、
`outputs_with_checksum` ≥ 1」。入力が指紋で固定されていなければ同じデータで走らせたかを確かめられず、道具は版番号があれば導入できる、
という 10/11 の理由がそのまま当てはまる（v0.1.12 が `immutable` に上げたのは関門の副作用だった）。Tier 3 が 2.5 の記録を読む実装は
この設計の外。

**(2) CPU と OS（D13）。** 束の `genomicschain_extension.platform = {cpu_architecture, os_name, os_release}`。書き出し器が
自己申告で書く（v0.1 のほかの値と同じく anchor は確かめない → `not_checked: platform_as_written`）。値は Ruby の `Etc.uname` の
`machine` / `sysname` / `release` で、**`nodename`（host 名）は書かない**。`gc_prov_write --plan` は既定で書き（plan が `platform` を
書いていればそちらを使う。別の machine で走った計算を記述するため。`--no-platform` で書かない）、補完器 `--from-nextflow-run` は
**既定で書かない**——補完器を走らせる machine が task の走った machine とは限らない（cluster・cloud の実行）ので、
`--platform-of-this-machine` を明示したときだけ書く。値を作らない原則（§4.1）の適用。拡張 block が複数あって `platform` が食い違えば
どちらも記録しない（producer と同じ規則、§4）。文字列でない値は「無い」（§5 の境界規則）。署名欄 `platform_*` は null 可。関門には
入れない（等級に関係しない）。

**(3) ZK 証明（D9、G2）。** 束の側の宣言、送り方、anchor の検証、記録に載るもの、の順に書く。

*束の宣言。* `genomicschain_extension.zk_receipts[]`、項目ごとに:

| 欄 | 意味 |
|---|---|
| `sha256` | 証明 file（RISC Zero の `Receipt` を bincode で直列化した bytes）の SHA-256、64 hex |
| `image_id` | guest program の image ID、64 hex（32 bytes を little-endian の u32 8 個として並べた hex——RISC Zero の慣習） |
| `zkvm` | `{name, version}`。v0.1 が受けるのは `risc0-zkvm` だけ |
| `step_number` | 証明が覆う段。束の `pipeline_steps[].step_number` を名指す（記録には位置 `stage` として載る、§5） |
| `journal` | journal の形の名前。v0.1 は `gc-zk-journal-0.1` だけ: risc0 serde の `([u8; 32], Vec<u8>)` = (段の入力 file の SHA-256, 段の出力 bytes) |
| `input_uri`, `output_uri` | journal が束縛する段の入力と出力の locator。その段の `input_list` / `output_list` にあり、拡張の `checksums[]` に SHA-256 があること |

宣言の読み取りはアダプタが行う（束から決定的に導ける部分）。宣言が壊れている——欄が欠ける、hex でない、段が無い、locator が
その段の list に無い、locator に SHA-256 が無い、同じ `sha256` が二度宣言される——なら、anchor は提出を拒否する
（`ZkDeclarationInvalid`。理由は欄の名前と位置だけ）。境界規則（§5）はここにも当てる: `zk_receipts` が配列でなければ `FormatError`、
object でない要素は空の項目として残り、宣言の欠陥として拒否される。拡張 block が複数あれば `zk_receipts[]` は連結する（`checksums[]` と同じ）。
上限は 1 束あたり 4 本、1 本あたり 512 KiB（succinct receipt は計算の大きさに依らず約 224 KB——実測 223,746 bytes、KairosChain_2026
`log/zk_demo_sizefactor_20260929/03_proofs`）。

*送り方。* 証明の bytes は束の外にある（束は証明の指紋しか持たない）。client は提出の引数 `zk_receipt_bytes`（`{receipt_sha256 → base64}`）に
添える。署名はしない——署名される同一性は束から導いた `zk_receipts` で、bytes はその `sha256` に一致しなければならない。宣言された
すべての証明に bytes が要り、宣言されていない bytes が来たら拒否する（束縛されない材料を受け取らない）。**bytes は 1 回の検証の間だけ
memory に持ち、disk にも log にも書かない**（束と同じ不変条件、§6）。外部 process には stdin で渡し、一時 file を作らない。

*anchor の検証。* 証明 1 本ごとに、版を固定した Rust の小さな検証 program `gc_zk_verify`（§7）を呼ぶ。入力は bytes（stdin）と image ID、
出力は JSON 1 行: 証明が image ID に対して検証できたか（`Receipt::verify`）、journal が `gc-zk-journal-0.1` として読めたか、読めたなら
journal の入力 digest と、出力 bytes の SHA-256。anchor は次の 4 つがすべて成り立つときだけ記録に進む——どれか一つでも欠ければ
`ZkReceiptRejected`（理由の符号だけ。journal の値は返さない）:

```
① bytes の sha256 = 宣言の sha256
② Receipt::verify(image_id) が通る（RISC Zero の検証。0.012 秒程度——同上の実測）
③ journal の入力 digest = 束が input_uri に記録した SHA-256
④ sha256(journal の出力 bytes) = 束が output_uri に記録した SHA-256
```

③④ が「この証明はこの束のこの段の計算のものだ」という結び付けで、これが無いと ② は「どこかの計算が正しかった」としか言わない。
検証 program が無い・時間切れ（30 秒）・異常終了は `ZkVerifierUnavailable` で、拒否として返す（証明を確かめずに記録することはしない。
証明の無い束は検証 program なしで通る）。

*記録に載るもの。* 署名欄 `zk_receipts`（上の表から、指紋・image ID・zkVM の名前と版・段の位置・journal の形の名前だけ）と、
server が決める欄 `zk_verification = {verifier, risc0_zkvm, journal_convention, receipts_verified}`（証明が 0 本なら null）。
**証明の bytes、journal の値、入力・出力の locator と digest は載せない**（記録は同一性と数だけ、2026-09-20 の決定）。

*言葉。* 検証道具の出力と `not_checked` の説明に、次の 2 文をそのまま置く（記憶 `warranty-scope`、2026-10-12 operator 指示）:

> (a) ZK 証明が示すのは、指定した段の計算が、記録された入力から正しく行われたことだけです。対象は指定した段だけで、記録された入力が
> 生データそのものであることは示しません。
> (b) GenomicsChain が保証するのは自らの手順と記録だけです。Tier 3 の記録は、その日に宣言どおりの結果に至ったという日付つきの
> 観察であり、将来の再現の約束ではありません。

**(4) not_checked に足す 3 項目。** `platform_as_written`（CPU と OS は書き出し器の申告のまま）、`zk_guest_program_semantics`
（image ID は program を名指すが、その program が何を計算するかは確かめていない）、`zk_inputs_are_raw_data`（(a) の後半）。
9 項目は record_version 0.3 で固定し、証明の有無に依らず常に全部を載せる。

**(5) 拡張の schema。** `genomicschain_core/schemas/bco_extension_genomicschain_v0_1.json` を U3 で作り、`producer`・`checksums[]`・
`platform`・`zk_receipts[]` を定める。URL（§10-1）はまだ公開していないので、v0_1 のまま欄を足してよい。**公開は売る前、operator の
判断**（外向きの行為）。

**(6) 版。** アダプタは `platform` と `zk_receipts` を読むので 0.4.0 に上げる（`adapter_version` は署名欄なので、古い版で読んだ等級と
区別される）。述語は変えない（等級の規則は動かない）。record_version は 0.3。

### 6.2 v0.1.14 の追加 — 計算資源（2026-10-14 起草、10-16 査読 2 回、10-17 凍結・実装、operator 決定）

凍結した草案 `docs/design/prov_v0_1_14_resources_draft.md`（sha256 fe85d0a9…）の §6.2 を写した。〔査読 r1〕などの印は草案のまま
残す。写した後に変えたのは (4) の表の plan の行だけで、その理由は下の「実装で決めたこと」の 2 項目めにある。

**なぜ。** Tier 3 が焼き直す機械を選ぶには、各段がどれだけの資源を要したかが要る。nf-core の失敗の多くは、段が要求した量を機械が
満たせないことで起きる。機械学習では GPU のベンダーと型番が、走るかどうかを決める。

```
                              今（v0.1.13）            v0.1.14
束の拡張                      platform, zk_receipts    ＋ resources（machine と steps[]）
等級                          7 つ（全体 + 6 分類）    7 つは同じ規則のまま ＋ grade_resources（別の規則 gc-resources-0.1）
全体の等級 grade_overall      最弱の 4 分類            変えない（資源は入れない、案イ）
署名欄                        record_version 0.3       ＋ 9 欄、record_version 0.4〔査読 r1: 6 → 9〕
not_checked                   9 項目                   10 項目（＋ resources_as_written）
アダプタ / 述語の版           bco-0.4.0 / 0.3.7        変えない
```

#### (1) 束に書くもの — `genomicschain_extension.resources`

| 部分 | 中身 |
|---|---|
| `machine` | `cpu_model`、`logical_cores`、`memory_total_bytes`、`disk_free_bytes`（作業 dir のある disk、書き出した時点）、`gpu_probe`（探した道具ごとの名前・版・結果）、`gpus[]`（`vendor`、`model`、`memory_bytes`、`driver_version`、`runtime` = `{name, version}` 例 CUDA・ROCm） |
| `steps[]` | `step_number` で段を名指す。`requested` = `{cpus, memory_bytes, time_seconds, disk_bytes, accelerators}`、`observed` = `{peak_memory_bytes, realtime_seconds, cpu_percent, read_bytes, write_bytes, cpu_model}`。どの欄も任意 |

不変条件:

- **探して無かったことと、探していないことを分ける。** `gpus` を `[]` と書くのは、`gpu_probe` に名前のある道具が少なくとも一つ
  正常に走り、何も報告しなかったときだけ。道具が一つも無ければ（`nvidia-smi`・`rocm-smi` が無い Linux など）`gpus` は書かず、
  note に残す。〔反証 2026-10-16〕この不変条件は §5 にある句の適用ではなく、この改訂で足す規則である（§5 の近い規則は「分類が空なら
  absent」）。帰結: 探査の道具が無い CPU だけの Linux 機では `gpus` が書かれず、`full` に届かない。`--plan` で書く束なら plan に `gpus: []` を
  書けば届く（plan が書いた値は `source: plan`）。〔凍結 10-17〕補完器 `--from-nextflow-run` とは併用できない（`gc_prov_write.rb` 90 行で
  二つは排他）ので、r3 の「plan に書けば届く」は補完器の束には当たらない。
- **`machine` は書き出し器が探った機械であって、task が使えた環境とは限らない**〔凍結 10-17、名前を正す〕。macOS の Docker Desktop で
  走らせた task は Linux の仮想機械の中で走り、host の GPU を使えない。`--gpus` を付けずに走らせた container も同じ。記録の
  `gpu_models` は「その機械に GPU があった」であって「task が GPU を使えた」ではない。
- **値を作らない**（§4.1）。集められなかった欄は書かない。trace に列の無い値は無い。
- **機械や人を特定する値は書かない。** host 名、利用者名、機器の serial・UUID、MAC、PCI の bus id。trace の `hostname` 列は読まない。
- **機械の欄は、その機械で走った計算にだけ書く。** 補完器 `--from-nextflow-run` は `machine` を既定で書かない（cluster・cloud では
  補完器の機械と task の機械が違う。platform と同じ理由）。`--machine-of-this-machine` を明示したときだけ書く。段ごとの値は trace が
  task ごとに持つので、この問題が無く、既定で読む。
- 拡張 block が複数あって `machine` が食い違えば、どちらも読まない。`steps[]` は段ごとに、食い違う欄だけ読まない（platform・
  producer と同じ規則）。
- 自己申告である。anchor は確かめない（`not_checked` に `resources_as_written`）。

#### (2) 等級 — `grade_resources`（規則 `gc-resources-0.1`。全体の等級には入れない）

段の判定を先に決める。**要求あり** = その段に `requested.cpus` と `requested.memory_bytes` の両方がある。**観測あり** = その段に
`observed.peak_memory_bytes` と `observed.realtime_seconds` の両方がある。**機械が揃う** = `cpu_model`・`logical_cores`・
`memory_total_bytes` があり、GPU を探した結果（`gpus`、空でもよい）がある。

```
absent   resources が無い、または読める値が一つも無い
partial  何かある（機械の欄の一部、または一部の段の値）が、steps に届かない
steps    全段が「要求あり」か「観測あり」のどちらかを満たす（段ごとにどちらでもよい）
full     全段が要求ありと観測ありの両方を満たし、かつ機械が揃う
```

- **一つの extension block の中で情報が増えて等級が下がることは無い**（operator の「あれば点数が高くなる」）。各段は下の段の条件を
  含む。〔査読 r1〕ただし block が二つあって `machine` が食い違えば、その欄は読まない（(1) の規則）ので、block を足すと下がりうる。
- **段が一つも無い束は、多くて `partial`**〔査読 r1〕。「全段が満たす」は段が 0 個だと何も調べずに成り立ってしまう。述語が段の無い束の
  環境を `absent` にするのと同じ向き。`steps[]` の `step_number` がどの段も名指さなければ、その項目は読まない。
- **一つの段に値が複数来たとき**（Snakemake の benchmark は job ごとに file を書く、retry や scatter）〔査読 r1〕: 要求は最大、観測の
  `peak_memory_bytes`・`realtime_seconds`・`cpu_percent` は最大、`read_bytes`・`write_bytes` は合計。機械の選び方に効くのは一つの job
  の最大だから。
- 全段の条件は**全段**で満たす（最弱の段が決める、§5 と同じ）。1 段だけ値があっても `partial`。
- 決定的である。同じ束から同じ等級が出る。数でない値・負の値は「無い」とする。〔反証 2026-10-16〕§5 の境界規則は文字列の欄の規則
  （「文字列か数値でなければ『無い』」）で、数の値の規則は §5 に無い。これはこの改訂で足す規則である。

例（r0 との比較）:

| 束 | r0 の等級 | r1 の等級 |
|---|---|---|
| nf-core を既定の設定で走らせ、補完器で埋めた（trace は既定の 14 列、機械は書かない） | absent | steps（全段に観測あり） |
| 同じ run で `trace.fields` に既定の 14 列と `cpus,memory` を並べた〔反証: `trace.fields` は列の一覧を置き換える。`cpus,memory` だけを書くと `peak_rss`・`realtime` が消える〕 | absent（機械が無いので先へ進めない） | steps（全段に両方あるが、機械が無い） |
| 上の行の設定で手元の機械で走らせ、`--machine-of-this-machine` も付けた | observed | full（GPU の探査の道具が一つでも走った場合）〔凍結 10-17: r3 の「無ければ plan に書けば」は CLI に無い道なので消した〕 |
| `--plan` で書いた束（機械は自動、段の値は無し） | machine | partial |

**`grade_overall` には入れない（案イ）。** 資源の欄は「locator が第三者に何を許すか」（§5 の等級の意味）ではなく、「走らせるのに要る
条件」である。最弱の 4 分類に入れると、資源の欄が無い束はすべて全体 `absent` に落ちる。全体 `immutable` の束 X は、資源が無くても
全体 `immutable` のまま、`grade_resources` が `absent` と並ぶ。

#### (3) 記録に載るもの（record_version 0.4）

0.3 の署名欄はそのまま全部残し、次の 9 欄を足す（〔査読 r1〕r2 の 6 欄に、値の出どころを示す 3 欄を足した）:

| 欄 | 中身 | null の意味 |
|---|---|---|
| `resources_rule_version` | `gc-resources-0.1` | — |
| `grade_resources` | absent / partial / steps / full | — |
| `stages_with_requested_resources` | 要求ありの段の数（分母は既存の `stages_total`） | — |
| `stages_with_observed_resources` | 観測ありの段の数（同上） | — |
| `gpus_total` | GPU の枚数 | 探していない |
| `gpu_models` | `[{vendor, model, count}]`、vendor・model の順に並べる。anchor の導出で絞る〔査読 r1〕: 16 項目まで、文字列は 128 文字まで・使える文字は英数字・空白・`._-()+/` だけ、UUID の形や 12 桁以上の 16 進の連なりを含む文字列は落とす（機器の serial を記録に出さない。書き出し器の規則を anchor でも守る）。`count` は 1〜64 の整数 | 探していない（`[]` は探して無かった） |
| `gpu_vendors_probed` | 正常に走った探査が対象とするベンダーの集合（`nvidia`・`amd`・`intel`・`apple`）を並べたもの〔査読 r1〕。`nvidia-smi` は nvidia、`rocm-smi` は amd、macOS の `system_profiler` は apple・intel・amd を覆う。Linux には Intel の探査が無い（§10）〔反証 r2〕。`rocm-smi` だけが走った NVIDIA 機の `[]` を、読み手が「AMD を探して無かった」と読めるように | 探していない |
| `machine_source` | `probe`（書き出し器が機械を探った）か `plan`（顧客が書いた）〔査読 r1〕。plan に書いた値で `full` に届いたことを記録の上で見せる | 機械の欄が無い |
| `resources_sources` | 段の値の `source` の集合（`nextflow_trace`・`snakemake_benchmark`・`gnu_time`・`bsd_time`・`gc_resources_input`・`plan`）を並べたもの〔査読 r1〕 | 段の値が無い |

`gpus_total` は、`count` が正しく読めた項目の `count` の合計。`gpu_models` は文字列の絞り込みを通った項目だけを並べるので、合計との
差が「型番を伏せたか、16 項目を超えて並べなかった GPU の枚数」になる〔査読 r1: 二つの関係が書かれていなかった。反証 r2: 16 項目の上限の分も差に入る〕。macOS の `system_profiler` は内蔵の GPU も返す。
Apple や Intel の内蔵 GPU も GPU として数える（機械学習の道具が使うことがある）。〔実装 10-17、名前を正す〕束の `gpus[]` は GPU 1 枚に
つき 1 項目で、項目の `count` は読まない。`gpus_total` は束の `gpus[]` の項目の数（項目がすべてオブジェクトのときに限って読む）。
`gpu_models` の `count` は、絞り込みを通った項目を (vendor, model) で束ねた数で、その合計と `gpus_total` の差が伏せた枚数になる
〔実装の査読 r2: r1 の後に足した文が、`gpus_total` を `gpu_models` の合計と書いていた〕。

型番以外の値（CPU の型番、メモリ量、段ごとの値）は記録に載せない。束にある（§6 の「記録は同一性と数だけ」）。GPU のベンダーと型番は
platform（§6.1 (2)）と同じく、記録だけで Tier 3 が機械を振り分けられるように載せる（operator 決定）。`not_checked` は 10 項目に
なり、record_version 0.4 で固定する。

#### (4) 取り込み口 — どのパイプライン道具でも、資源の情報を出せれば登録する

**operator の方針（2026-10-14、r2）:** 「全部が全部 nf-core を使うわけではないので、その他のパイプラインツール、例えば snakemake とか、
独自パイプラインなどを使った場合にもし、リソース情報を出力できれば登録する、という方向性で良い」。記憶 `service-2-5-decisions` の
「束を出す側は差し替え可能（Nextflow に縛らない）」と同じ線。

形は一つ、取り込み口は道具ごと。等級は束の `resources` の共通の形だけから出すので、どの道具から来た値かで等級は変わらない。

```
Nextflow の trace ──────────┐
Snakemake の benchmark ─────┤
GNU time の出力 ────────────┼──▶ 取り込み口（道具ごと） ──▶ resources（共通の形） ──▶ gc-resources-0.1 ──▶ grade_resources
資源の汎用 file（JSON） ────┤
plan に顧客が書いた値 ──────┘
```

| 取り込み口 | 要求（requested） | 観測（observed） | 段との結び方 |
|---|---|---|---|
| Nextflow の trace（`--from-nextflow-run`） | `cpus memory time disk accelerator`（`accelerator` は要求した GPU の数。2026-01 の Nextflow から `accelerator`・`accelerator_type` 列がある〔反証 r2〕。既定の 14 列には無い。`trace.fields` は列の一覧を置き換えるので、既定の 14 列と足す列を並べて書く〔反証 2026-10-16〕） | `peak_rss realtime %cpu read_bytes write_bytes cpu_model` | task の hash（container の列と同じ、`nextflow_run.rb` の `trace_image`） |
| Snakemake の benchmark file（rule に `benchmark:` を書いたもの） | 8.11 以降の `--benchmark-extended` で `threads`・`resources` | `s`（実時間）・`max_rss`・`io_in`・`io_out`（Snakemake の `benchmark.py` はどれも 1024×1024 で割る、つまり MiB。文書は io を bytes と書く〔反証 2026-10-16〕）・`cpu_time` | plan の段に benchmark file の path を書く。rule と段の対応は顧客が決める |
| GNU time の `-v`（最大メモリは kbytes）と、macOS の BSD time の `-l`（最大メモリは bytes）〔反証 2026-10-16: macOS の `/usr/bin/time` は GNU ではない。形式も単位も違うので読み手は二つ〕 | — | 最大メモリ・実時間・CPU 時間 | 同上 |
| 資源の汎用 file `gc-resources-input-0.1`（JSON） | 欄はすべて任意 | 同左 | 段の `step_number` を直接書く。独自パイプラインはこれを出せば足りる |
| plan に書いた値 | 顧客が書いたまま | —〔実装 10-17、operator: plan は要求値だけ。観測値を書いた plan は断る〕 | plan の段そのもの |

規則:

- **値の出どころを束に書く。** 段の値ごとに `source`（`nextflow_trace`、`snakemake_benchmark`、`gnu_time`、`bsd_time`、`gc_resources_input`、
  `plan`。(3) の `resources_sources` と同じ 6 つ〔反証 r2〕）。記録には載せない（束にある）。
- **知らない列や欄は読まない。** Snakemake の extended 形式は `params` と `wildcards`（試料名が入りうる）も書くが、取り込み口は
  資源の列だけを読み、ほかは束に写さない。
- **単位を外して数にする。** 人の読む形（`11.2 MB`、`663ms`）なら丸めがあったことを note に残す。Nextflow には `trace.raw = true`
  を手順書で勧める。Snakemake の文書は `max_rss` を megabytes とも MiB とも書き、io を bytes と書くが、code（`benchmark.py`）はどれも MiB で書く。
  file を書いた Snakemake の版の code に従い、実装で実物の file を見て確かめ、note に残す。
- **書き出し器は段を走らせないので、観測値を作らない。** 観測値はどれも、道具が実際に測って書いた file からだけ来る。測る道具が無い
  独自パイプラインには、段を時間とメモリの測定で包む別の道具（仮称 `gc_prov_measure`）を後で用意し、汎用 file を書かせる（§10）。
- `--plan` で書く束は、plan に `machine` が無ければ書き出す機械を探って書く（別の機械で走った計算を記述するなら plan に書く。
  `--no-machine` で書かない。platform と同じ）。
- GPU の探索: Linux は `nvidia-smi --query-gpu=…` と `rocm-smi`、macOS は `system_profiler SPDisplaysDataType -json`。どの道具を
  試し、どれが走ったかを `gpu_probe` に書く。

#### (5) 版

| 何 | 今 | v0.1.14 |
|---|---|---|
| アダプタ `prov-adapter-bco` | 0.4.0 | **0.4.0 のまま**（アダプタは拡張の知らない key を読まない。`resources` は別の読み手が読む） |
| 述語 `prov-predicate` | 0.3.7 | **0.3.7 のまま**（7 つの等級の規則は動かない） |
| 資源の規則 | — | `gc-resources-0.1`（新規、署名欄） |
| 書き出し器 | 0.2.0 | 0.3.0 |
| record_version | 0.3 | 0.4 |
| admission_rule | prov-admission-0.2 | 変えない |
| 拡張の schema（core） | `resources` 無し | `resources` を足す（schema は最上位で知らない key を拒まないので、古い束も通る） |
| package | prov 0.3.0、core 0.6.0 | prov 0.4.0、core 0.6.1 |
| 検証器の再導出の条件 | 三つの版で全か無か（`Prov::VERSION_FIELDS`、`verdict_spec/prov.rb` 57 行、`Verifier#rederive`、`verifier.rb` 221 行） | **二つに分ける**〔査読 r1〕: 7 つの等級と数は今の三つの版で再導出する。資源の 9 欄は `resources_rule_version` とアダプタの版が手元と同じときだけ再導出し、違えば資源の欄だけ「版違い」の見出しへ。r2 の「四つの版で全か無か」では、資源の規則を一度上げただけで 0.4 の記録すべての 7 つの等級が再導出されなくなり、別の規則にした理由が消える |
| 0.3 に固定された code〔査読 r1: r2 の表に無かった。このままだと最初の提出が schema 違反になる〕 | `prov_attestation.schema.json`（`record_version` の enum が `["0.3"]`、`not_checked` が 9 項目ちょうど、最上位の `additionalProperties: false`）、`Identity::RECORD_VERSION`（`identity.rb` 38 行）、`SIGNED_FIELDS`（'0.3' だけ）、`Identity.params_from_manifest`（182–185 行。版ごとの欄の集合 `SIGNED_FIELDS` は 64–65 行〔反証 r2〕）、`Identity.derive`、`NOT_CHECKED`（79 行）、`Verifier::NOT_CHECKED_TEXT`（`verifier.rb` 31–41 行）、`Prov.versions` と `ProcedureVersionMismatch` の文面（`verdict_spec/prov.rb` 75–78、140–146 行）、`gc_prov_submit.rb` 119–124 行 | どれも版ごとに持つ。schema は `record_version` で分け（0.3 の記録が今のまま通ること）、0.4 は 9 欄と `not_checked` 10 項目。`NOT_CHECKED_TEXT` に `resources_as_written` の文。`Prov.versions` と拒否の文面に `resources_rule_version` を足す。prov の `depends_on` を core `>= 0.6.1` に |

#### (6) 既存の記録・自己検査・ZK の実演との関係

**この改訂は、既にある等級・記録・証明の意味を一つも変えない。** そうなるように (5) の版を選んだ。

| 既にあるもの | 影響 | 根拠 |
|---|---|---|
| 0.3 の記録（第 2 回の自己検査 E-25 の V0・V6） | 意味は変わらない。新しい検証器でも、アダプタ・述語・pin の版が一致するので等級を再導出して「一致」と言える | 検証器は版が一致するときだけ再導出する（§8）。r0 のように述語を上げると、新しい検証器では「版違い」の見出しになっていた |
| 同じ束を 0.4 で記録し直した場合 | 7 つの等級と数は同じ。違うのは足した 9 欄、`record_version`、`not_checked`、`submission_key` と claim の末尾 | 0.4 の記録は別の記録として発行される。0.3 の記録は残る |
| ZK 証明（Supplementary S1 の実測、anchor の `gc_zk_verify`） | 無し | journal の形 `gc-zk-journal-0.1`、検証の 4 条件、署名欄 `zk_receipts` を変えない |
| Tier 3 の route B の線 | 無し | 線は `grade_overall`・`grade_inputs`・`outputs_with_checksum` だけを読む |

実装の受け入れ条件（非退行の test）: (i) 既存の test 束すべてで 7 つの等級と数が 0.3.0 と同じ、(ii) 変更の前に prov 0.3.0 で 0.3 の記録を
一つ作って fixture として保存し、新しい検証器で「一致」と読む〔反証 2026-10-16: 今の test は記録をその場で作るので、0.3 の fixture は
まだ無い〕、(iii) 資源の欄を足しても `grade_overall` が動かない、(iv) 段の無い束は多くて `partial`、(v) 資源の規則の版だけが違う 0.4 の
fixture で、7 つの等級と数は「一致」、資源の欄は「版違い」、(vi) 機器の serial に見える文字列を `model` に入れた束で、記録の
`gpu_models` から落ちる〔(iv)〜(vi) は査読 r1〕。加えて、手元にだけある第 2 回の V0・V6 の束で (i) を一度
確かめ、`selfapp/round2/expected.json` の E-25 の等級と同じであることを記録する（自己検査のやり直しではなく、確認の 1 行）。

#### (7) Tier 3 との関係

route B の線（§6.1 (1)）は変えない。Tier 3 は束の資源の欄を、焼き直す機械の選択と実行前の費用の見積もり（`gc_tier3_estimate` の
`n_cores`・`ram_gb`）に使う。Tier 3 の `jobspec_digest` は資源を含まない（Tier 3 の code の事実: `JobSpec#digest` は subject_ref・env・data・pipeline だけを覆う、
`genomicschain_tier3/lib/genomicschain_tier3/execution/backend.rb` 103 行。〔反証 2026-10-16〕r2 は §6.1 を根拠に挙げたが、§6.1 は
jobspec_digest に触れていない）ので、資源の欄は Tier 3 の同一性にも
入らない。機械学習で同じ GPU でも結果が揺れること（非決定性）は資源の欄の外にあり、Tier 3 の比較の許容誤差の問題である。

#### 実装で決めたこと（2026-10-17。prov 0.4.0、core 0.6.1、書き出し器 0.3.0）

凍結後の実装の待ち行列（L2 `handoff_tier25_v0114_v0115_implementation_20261017`）のうち、operator に尋ねた 3 件と、規則の空白を
埋めた細部。どれも消す・直す・名前を正す方向で、新しい署名欄も新しい CLI の口も足していない。

| 何 | 決めたこと | 根拠 |
|---|---|---|
| D5 GPU の型番の絞り込み | ベンダーは nvidia・amd・intel・apple の 4 つだけ。型番は、次のどれかを文字列のどこかに含めば落とす（区切りの文字は問わない）: 12 桁以上の 16 進の連なり（UUID もこれに含まれる）、8 桁以上の数字、IPv4（`.`・`-`・`_` 区切り）、MAC（`-`・`_`・空白区切りと、点で 3 つに区切る形）、host 名（点が二つ、または点の後に英字の名前）、`/` で始まる文字列、英字と数字が 3 つ以上ずつ混ざった 8 文字以上の語（serial の形）。落ちた GPU も `gpus_total` には数える。ベンダーは前後の空白を除いて小文字にしてから四つと比べ、型番は前後の空白を除いて記録する。同じ型番が 64 枚を超える組は `gpu_models` に載せない。path は文字列の先頭だけを見る（operator の言い方のとおり）。残る危険（operator が受け入れた、実装の査読 r2 で足した 3 つを含む）: 点の無い host 名、短い service tag、文字列の途中の path、4 文字ずつ横棒で区切った serial、横棒で区切った 3 組の MAC は型番と見分けられず通る。AMD の角括弧つきの名前は伏せる | operator 2026-10-17「ベンダー限定＋形で落とす」「path と長い数字だけ足す」「伏せたままにする」。凍結時の規則では「SN-Z9Y8X7W6V5U4」「gpu17.cluster.uzh.ch」「10.0.0.17」が、実装の査読 r1 では「NVIDIA (node3.local)」が記録に出た |
| plan の観測値 | plan に書けるのは要求値だけ。`resources.observed` を書いた plan は理由を添えて断る | operator 2026-10-17。(4) の規則「観測値はどれも、道具が実際に測って書いた file からだけ来る」と表の plan の行が食い違っていたので、規則の側に合わせた |
| D4 の三つの追加 | どれも足さない（署名欄 `stages_requesting_accelerators`、補完器の `--machine PATH` は待ち行列に残す）。macOS で container を使った段があるときに `gpus` と `gpu_probe` を書かない修正だけを入れた | operator 2026-10-17「何も足さない」。macOS の修正は (1) の凍結時の文「task が GPU を使えたとは限らない」の帰結で、書く量を減らす向き |
| `gpus[]` の数え方 | 束の `gpus[]` は GPU 1 枚につき 1 項目。anchor は (vendor, model) で束ねて `count` を出す。plan の `count` は書き出し器が項目に展開する | 待ち行列。(1) の表に `count` が無かった |
| `source` の無い machine | `plan` として読む。`probe` は強い主張なので、書かれていなければ名乗らせない | 規則の空白 |
| 機械の探査 | 命令は固定の引数で、命令の process が 10 秒で終わらなければ打ち切る（結果は `timeout`。命令が残した子 process が出力を握り続ける場合と、SIGKILL で終わらない場合は待ち続ける）。探査が報告した GPU を一つでも読めなければ、その探査は `failed` とし、その探査の GPU は書かない（読み損じを「探して無かった」と署名しない）。`gpus` は答えた探査があれば書き、Linux で rocm-smi だけが失敗すれば NVIDIA の GPU だけが載る（`gpu_vendors_probed` も nvidia だけ）。`gpus` はオブジェクトだけからなるときに読み、`gpu_vendors_probed` は `gpus` を読んだときだけ出す。macOS の規則: plan では、道具・runtime の `image` か OCI の image 参照の `uri` があれば GPU の行を書かない（Singularity の `.sif` や `https://` の image は見分けない）。Nextflow の補完では、macOS なら常に書かない（nf-prov の束は task が container で走っても container を名乗らないので、work/ が消えた後には見分けられない。operator 2026-10-17）。探査の出力が読めない形（rocm-smi の最上位がオブジェクトでない、`card…` の項目がオブジェクトでない、system_profiler の一覧が無いか一覧でない、型番が空）は `failed`。rocm-smi は `Card Series` を `Card Model`（PCI の番号）より先に採る。SIGKILL で終わらない process（固まった driver）は待ち続けることを、operator は残る危険として受け入れた（`--no-machine` で避けられる） | operator 2026-10-17「足す」（打ち切り）。実装の査読 r1 |
| 段の項目の読み方 | 知らない `source` の項目、束のどの段も名指さない `step_number` の項目は読まない（note に残す）。段の `cpu_model` は job で一つに揃うときだけ読み、それだけでは書かれた値に数えない（等級を上げも下げもしない）。数は値で比べる（2^53 未満の整数値の Float は等しい Integer として比べるので 4 と 4.0 は同じ。合計した値も同じ。2^53 以上の Float は Float のまま比べる）。`resources_sources` には、値が残った出どころだけを並べる（同じ block の中では、最大を採る欄はその最大を出した出どころ、同点ならその両方、合計の欄は足したすべて） | 「知らない欄は読まない」(4) と同じ向き。実装の査読 r1 で、CPU 名の食い違いが同じ block の中で等級を下げていた |
| Nextflow の `-resume` | `pipeline_info/execution_trace*.txt` をすべて名前の順に読み、task の hash ごと・欄ごとに後のファイルの値を採る。後のファイルの空欄（`-`）は前の値を消さない。読んだファイル名を note に残す。trace の短い hash と段の結び付きは、一つの trace ファイルの中と束の段の間で 1 対 1 のときだけ読む（同じ短い hash を持つものが二つあれば、どちらも読まない）。別の trace ファイルの同じ短い hash は同じ task とみなすので、以前の起動の別の task と偶然一致すれば値が混ざりうる | 待ち行列。実装の査読 r1 |
| 0.3 の client | anchor が 0.4.0 に上がった後、0.3 の署名欄で提出した client は `ProcedureVersionMismatch` で断られ、anchor の版（`resources_rule` を含む）が返る。記録は増えない。逆向き（0.4 の client と 0.3.0 の anchor）は版違いではなく `IdentityMismatch` になるので、anchor を先に上げる | 待ち行列「Policy for 0.3 clients」。実装の査読 r1 |
| 記録の schema | 0.3 の `prov_attestation.schema.json` は変えず、0.4 を別ファイル `prov_attestation_v0_4.schema.json` にした。`resources_rule_version` は `gc-resources-N.M` の形を許す | 0.3 の記録が今のまま通ることを、ファイルが変わっていないことで示せる |

受け入れの確認（2026-10-17）: (i) nf-core の fixture、0.3 の fixture、自己検査の V0・V6 の 4 束で、0.3 の署名欄 51 個が変更の前後で
一致。(ii) 変更前の prov 0.3.0 で作った記録（`genomicschain_prov/test/fixtures/record_v0_3/`、作った版は `made_with.json`）を新しい検証器が
「一致」と読む。(iii)〜(vi) は test（`resources_test.rb`、`prov_verify_test.rb`）。E-25 の確認の 1 行: V0・V6 とも、E-25 の manifest の
欄のうち束から出る 21 欄が一致、claim の形も一致（自己検査のやり直しではない）。

## 7. 道具と置き場所

| tool / script | 置き場所 | 動く場所 | 網 | 何をするか |
|---|---|---|---|---|
| `gc_prov_write` | `genomicschain_prov/bin/`（同じ理由で `tools/` には置かない。実装時に gem の `Skillset#load!` を読んで確認済——`Dir[tools/*.rb].sort.each { require }` が `anchor_profile` に関係なく走る。v0.1.11 で §9 の `tools/` 表記を訂正）。logic は `lib/genomicschain_prov/writer.rb`（純粋な組み立て）・`writer/environment.rb`（機械を触る側）・`writer/nextflow_run.rb`（補完器）に分け、Tier-3 executor は CLI を経ずに lib を呼ぶ | 顧客の workstation（off-anchor） | 使わない | `--plan` で段の一覧から BCO を書き、`--from-nextflow-run` で nf-prov の束を補完する（§4.1、§13.4-1）。集められなかったものは値を作らず note にして stderr へ。`--run-version-commands` は既定 off——plan は data file であり、その中の `version_command` は command line なので、他人の plan を読むだけで shell が走らない |
| `gc_prov_check` | `genomicschain_prov/bin/`（`tools/` には置かない: `Skillset#load!` が `tools/*.rb` をどの node でも eager に require するので、CLI の option parse が anchor の起動時に走る——round 3） | 顧客の workstation（off-anchor） | 使わない | 束を読み、digest・等級・数・`signed_params` を出す。`--json` で機械可読 |
| `gc_submit_client.rb --tier prov` | `scripts/`（既存に 1 tier 足す） | 顧客の workstation | anchor へ HTTPS | `signed_params` に署名して `gc_prov_submit` を呼ぶ。`--dry-run` / `--print-only` は既存のまま |
| `gc_prov_submit` | `genomicschain_prov/tools/`（prov の `skillset.json` の `anchor_profile_tool_classes`。core の登録を汎用化して読む） | anchor のみ | — | Tier-2 submit と同じ骨。ただし束の gate は §6 の Gate A。`dry_run` で `signed_params` を返す |
| `gc_prov_proof` | `genomicschain_prov/lib/genomicschain_prov/place_extension.rb`——MCP tool ではなく **Meeting Place の公開 route**。prov の `skillset.json` の `place_extensions[]` に `{class, require, public_routes: ["/place/web/prov/"]}` を書き、Hestia の `PlaceRouter#register_extension(public_routes:)` が `/place/web/prov/proof/<proof_id>` を **認証なし・GET/HEAD のみ・公開 rate limiter つき**で Bearer の前に dispatch する（round 3 で実物を読んだ: MCP の `tools/call` は body を読む前に Bearer を検査し、anchor では service_grant の AccessGate も重ねてかかるので、tool として登録しても 1 本だけ認証の外には出せない） | anchor のみ（Meeting Place が動いている node） | — | `proof_id` → registry の envelope。**返すのは次の欄だけ**: `proof_id, version, attester_id, subject_ref, claim, evidence`（canonical JSON の文字列 `{manifest, manifest_body_sha256}` そのまま）`, merkle_root, timestamp, ttl, submitter_pubkey, signature` に、`evidence` を parse した `manifest` と registry の `revoked` を足す。`actor_user_id`（Bearer の `--user` 名）・`actor_role`・`metadata` は**返さない**（署名の外の欄で、検証に要らず、顧客の token 名を漏らす——round 3、3 席）。`manifest.record_type` が `prov_attestation` でなければ not found と同じ返事（registry は全 tier で 1 本の `proofs.jsonl`。Tier-2 の manifest は repo の URL を hash せずに持つ——round 3、codex と verifier）。既存の `attestation_verify` は `valid / errors / content_hash / checked_at / proof_id` を返すだけで evidence を返さず、`attestation_list` は要約だけなので、第三者は manifest を読めない（round 2 の P0）。この route が §8 の第一段の材料。**extension の契約**（Hestia `PlaceRouter` が要求する、round 4）: `initialize(router)`、`public_call(env) → Rack の三つ組か nil`、`call(env, peer_id:) → nil`、`public_route_prefixes → ['/place/web/prov']`（`skillset.json` の `public_routes` は記録、class 側の列挙が `meeting_place_start` 経由の再登録でも効く）。見つからない・prov でない → HTTP 404 に JSON `{"error":"not_found"}`（extension 自身が組む。`public_call` が nil を返すと router の既定 404 は text/html）。rate limit は Hestia の公開 limiter: **30 requests/分 / client IP**、skillset catalog と共有 |
| `gc_prov_verify` | `genomicschain_prov/bin/`（同上） | 検証者（GenomicsChain または第三者） | anchor の `gc_prov_proof` route を GET | 束 + proof_id → envelope を取る → digest・等級を再計算 → manifest と照合 → 提出者の署名（と、鍵があれば anchor の署名）を**手元で**検証 → 「確かめたこと／確かめていないこと」（§8） |
| `gc_zk_verify`（v0.1.12） | `genomicschain_prov/zk_verifier/`（Rust の crate。`Cargo.toml` と `Cargo.lock` を repo に置き、`risc0-zkvm` を 3.0.6 に固定。記憶 `skillsets-ruby-first` の「他言語は避けられないときだけ、lock で固定」の適用——RISC Zero の検証は Rust にしか無い）。Ruby 側の呼び口は `lib/genomicschain_prov/zk_verifier.rb`（実行 file の場所は環境変数 `GC_ZK_VERIFY_BIN`、無ければ crate の `target/release/gc_zk_verify`） | anchor（必須、証明つきの提出を受けるなら）、顧客と検証者（任意） | 使わない | 証明の bytes を stdin、image ID を引数で受け、§6.1 ③④ の材料を JSON 1 行で返す。証明を作る機能（prover）は持たない |

**package の依存:**

```
genomicschain_prov  ──requires──▶  genomicschain_core（SubmitCore, Manifest）
                    ──requires──▶  genomicschain_tier2（PinStrength と、その版）  ← v0.1 はこれで行く。
                                                                              PinStrength を core へ移すのは候補、v0.1 では動かさない
```

core → prov の向きの依存は作らない（round 1: `Skillset#load!` は `tools/*.rb` を anchor_profile に関係なく eager に require するので、
core に prov を require する file を置くと、prov の無い node——team workstation の core + tier1——で core ごと落ちる）。
`verdict_spec/prov.rb`・`prov_submit.rb`・`gc_prov_submit`・`place_extension.rb`（`gc_prov_proof`）・schema は **genomicschain_prov に置く**。core に入れる変更は
4 か所（round 2 で実物を読んで数え直した。深さ gate は core に足さない——`DoSGate.compute_depth` が public なので prov 側で呼ぶ）:
(1) `AnchorProfileRegistration.install!` が差し替える `KairosMcp::Skillset#tool_class_names` が `name == 'genomicschain_core'` のときだけ
`anchor_profile_tool_classes` を読んでいるのを、どの skillset の `skillset.json` でも読むようにする（prov の `gc_prov_submit` を anchor だけに出す。`gc_prov_proof` はここに入らない——round 3 で MCP tool を Bearer から外せないと分かり、Meeting Place の公開 route に移した。v0.1.3 の名残の記述、round 6 で削除）、
(2) `SubmitCore.build_response` の `idempotency_key`: manifest の `record_type` が `prov_attestation` なら `submission_key` だけを材料にする（Tier-1/2/3 の manifest にも `submission_key` はあるので、有無ではなく record_type で分ける——round 5 の falsifier）。それ以外は既存の fallback
（`jobspec_digest || report_content_hash || adjudication_digest` と `result_hash || headline.static_readiness || codescan_evidence_digest` と pubkey）のまま
（Tier-1/2/3 は変えない。今のままだと prov は鍵だけの定数になる。§6 の idempotency_key）、(3) `SynoptisAttestor#issue(subject_ref:, claim:, evidence:, actor_role:)` に `ttl: nil` を足して
engine の `create_attestation(ttl:)` へ渡す、(4) `SubmitCore.store_proof!` が `spec.respond_to?(:proof_ttl) ? spec.proof_ttl : nil` を
attestor に渡す。(3)(4) は nil なら engine の既定に落ちるので Tier-1/2/3 の proof は変わらない。core の版は 0.5.0 → 0.6.0、
**同じ commit で prov の `depends_on` を `genomicschain_core >= 0.6.0` に上げる**（round 3: 0.5.0 の core の横に prov を入れると
`gc_prov_submit` は登録されず、手で登録しても TTL が渡らず 24 時間の proof が黙って出る）。`gc_prov_submit` は引き続き
`anchor_profile_tool_classes` の MCP tool（Bearer 有り。提出は認証の内側）。

配備の表（`genomicschain_core/plugin/SKILL.md` の表の anchor の行を直し、顧客 workstation と検証者の 2 行を足す）:

| Node | Packages | anchor_profile | 使う tool |
|---|---|---|---|
| anchor | core + tier1 + tier2 + tier3 + **prov**、＋ `gc_zk_verify` の実行 file（v0.1.12。anchor の Docker image に Rust の build 段を足して作る。HTTP の request body 上限は束 2 MB ＋ 証明 4 本の base64 で **5 MB 以上**——§6 の Gate A の配備条件を置き換える） | true | `gc_prov_submit` |
| 顧客 workstation | core + tier2 + **prov**（ZK 証明を自分で確かめたいときだけ `gc_zk_verify`） | false | `gc_prov_check`, client |
| 検証者 | core + tier2 + **prov**。core の depends_on が synoptis を、synoptis の depends_on が mmp を**要求する**（自動では入らない。install + enable の順は mmp → synoptis → core → tier2 → prov）。anchor の署名検証は `Synoptis::Verifier` と `MMP::Crypto`、提出者の署名検証は `ed25519` gem（`gem install ed25519`、README） | false | `gc_prov_verify` |

**顧客の鍵と Bearer:** 既存のとおり、顧客が `--keygen` で ed25519 鍵を作り、GenomicsChain が `gc_issue_bound_token.rb` で
その pubkey に束縛した Bearer を発行する（発行後に anchor の再起動が要る — 既知の運用制約）。
署名鍵は顧客の手元にだけある。GenomicsChain は失効も回転もできない。これが「鍵の所有」の堀の実体。

## 8. 検証者が言えること・言えないこと（`gc_prov_verify` の出力の形）

原則（round 2）: **検証者は、自分が手元に持つ bytes から自分で計算したことだけを「確かめた」と印刷する。** anchor の返事を
写すときは「anchor が言っている」と書く。第一段の材料は `gc_prov_proof` route が返す envelope（§7 の欄: `evidence` から取り出した
manifest・attester_id・timestamp・ttl・anchor の署名・submitter_pubkey・revoked）。

**二つの署名（round 3）。** 提出者の署名は ed25519、`Manifest.canonical_json({mcp_tool_name, params, nonce, chain_tip_hash})` の
bytes に対して、base64url。`params` は manifest の `record_version` が定める署名欄の集合（§6）から組み立てる。anchor の署名は
**RSA-2048 / SHA-256（PKCS#1 v1.5）、Base64、公開鍵は PEM**（MMP の `Crypto`。ed25519 ではない）で、bytes は Synoptis の
`ProofEnvelope#canonical_json`（proof_id・version・attester_id・subject_ref・claim・evidence・merkle_root・timestamp・ttl・
submitter_pubkey の順。`sort_keys: true` を渡しているが json gem はこの option を持たず（2.7 系・2.9.1・2.13.2・2.18.0 で実測）、どの版でも挿入順）。検証者は
route の JSON を `ProofEnvelope.from_h` で envelope に戻し（`manifest`・`revoked` の余分な欄は無視される）、verifier node の
`Synoptis::Verifier#verify(envelope, public_key:)` に PEM を渡す——bytes は verifier node の json gem が `canonical_json` で作り直す。`attestation_verify` は evidence を返さず、`public_key` を渡さない呼び出しは
署名つき envelope に対して常に `valid: false`（`no_public_key_for_verification`）を返すので、v0.1 の検証者は `attestation_verify` を
**使わない**。

```
確かめたこと（束と envelope から、この tool 自身が）
  - 束の digest = manifest の bundle_digest（manifest の bundle_digest_canonicalization が名指す規則で取り直す。file の sha256 ではない。
    規則の名前を知らなければ照合しない——下の表）
  - envelope.subject_ref = "prov:sha256:" + その digest、envelope.claim = §6 の形で組み直した文字列（anchor が署名した層が
    evidence の中身と一致すること。attestation_list が印刷するのは claim なので、台帳を読む人が引用するのはこちら）
  - evidence.manifest_body_sha256 = sha256(canonical_json(manifest))、envelope.submitter_pubkey = manifest.operator.pubkey、
    manifest.submission_key = `Manifest.canonical_json({digest_subject_hash: bundle_digest, signed_identity: record_version の署名欄の Hash,
    operator_pubkey: manifest.operator.pubkey})` の sha256（= claim の末尾）
  - 等級 = manifest の grade_overall と各分類、数（adapter_version / predicate_version / pin_strength_version の三つが
    手元の版と一致するときだけ再導出する。outputs_digest は outputs_digest_rule が手元と一致するときだけ）
  - 提出者の署名（manifest.operator の ed25519 署名。--submitter-pubkey で渡された鍵で検証。渡されなければ
    manifest 内の pubkey で検証し「manifest 内の鍵と自己整合」と書く——それは提出者の同一性の証明ではない）
  - 段 N 本のうち自分で環境を宣言した k、software M 本のうち immutable a / versioned b / ...、入力 K 本のうち checksum つき k'
  - （v0.1.12）CPU と OS: 束が名乗る値 = manifest の platform_*（束から読み直した照合であって、申告が正しいかではない）
  - （v0.1.12）ZK 証明: --zk-receipt で証明 file を渡され、手元に gc_zk_verify があるときだけ、§6.1 の ①〜④ を自分で行い
    「確かめたこと」に置く。無いときは下の「anchor が言っていること」へ
版が違うとき（見出しを別にする）
  - 「adapter / predicate / pin_strength の版が手元（x, y, z）と proof（x', y', z'）で違うので等級は再導出していない」
    ——不一致とは書かない。manifest の record_version を知らないときも同じ見出し（署名欄の集合が分からないので提出者の署名も、
    claim の末尾と submission_key も組み直さない）。digest の照合は正準化規則の名前に、署名の検証は record_version に依る——手順の版には依らない
anchor が言っていること（この tool は確かめていない）
  - 時刻 T に目撃した（attester_id、timestamp、anchor の署名）。--anchor-pubkey が渡されたときだけ、署名と、署名の中にある
    timestamp・ttl・subject_ref・claim・evidence を「確かめたこと」に移す。鍵が無い間は「anchor-reported」
  - chain_tip_hash: 顧客が署名した時点で見た proofs 台帳の末尾記録の hash（core の TipSource。block ではない）。受理時に
    anchor が鮮度（≤ 100 件か ≤ 6 時間）を確かめたという anchor の言い分で、この tool は検証しない
  - proof の鮮度（timestamp と ttl を印刷し、expired は「TTL を過ぎた」と書く。「記録が無効」とは書かない）
  - 失効（revoked）——**鍵があっても anchor-reported のまま**。revoked は registry の別 file から足した欄で、署名の外にある。
    書き換えても envelope の署名は通るので、「確かめた」には移せない（round 3、codex）
  - （v0.1.12、v0.1.13 で改訂）発行の規則: admission_rule の名前と、その名前の意味（`prov-admission-0.2` は「どの等級でも
    発行し、証明はすべて検証と照合を通った」、`prov-admission-0.1` は「grade_overall が immutable のときだけ発行した」）。
    知らない名前は「この検証器の知らない規則」と書く
  - （v0.1.12）ZK 証明を N 本、検証 program V（risc0-zkvm の版）で確かめ、束の入出力と照合した（zk_verification）——自分で確かめなかった証明について
確かめていないこと（manifest の not_checked をそのまま写す）
  - locator の先が今も取得できるか
  - 束が実行を正しく写しているか（producer と補完器の出力を信じている）
  - 束が規格の schema に適合しているか／束に書かれた checksum が正しいか（書かれたまま数えている）
  - 参照ゲノムが何だったか、乱数シードが何だったか（名前の推測は記録に無い）
  - 出力が正しいか、再構築して同じ出力が出るか  ← (iii) の仕事
  - （v0.1.12）CPU と OS の申告が正しいか、ZK の guest program が何を計算するか、記録された入力が生データそのものか
出力の末尾には §6.1 の (a)(b) の 2 文をそのまま置く
```

**`gc_prov_proof` が返せないとき、何を印刷するか（round 2 の P0: expired 以外の `valid: false` に描き方が無かった）。**
Synoptis の engine と Verifier の語彙をそのまま使い、検証者が自分で計算できることはそれでも計算する:

| anchor の返事 | 検証者が印刷すること | 束の照合 |
|---|---|---|
| `revoked: true` | 「anchor はこの proof を取り消したと言っている」＋通常どおり照合（取り消しは anchor の判断で、束の同一性は変わらない。route は envelope を返す） | する |
| envelope あり、`ttl` を過ぎている | 「鮮度: TTL を過ぎた（timestamp, ttl）」 | する |
| envelope の anchor 署名が `--anchor-pubkey` で検証できない（Verifier の `invalid_signature` / `missing_signature` 相当） | 「anchor の署名が渡された鍵で検証できない——proof は anchor のものではないか、鍵が違うか、直列化が違う（Ruby 以外の実装。json gem の版差は実測では出ていない）」 | する（提出者の署名は別に検証する） |
| `identity_outside_signature`（envelope version 1.0.0 に submitter_pubkey がある） | 「envelope の submitter_pubkey は署名の外にある——無視し、manifest.operator.pubkey を使う」＋ anchor の署名は 1.0.0 の欄集合で検証した結果（valid / invalid）をそのまま印刷 | **する**（evidence はどの version でも署名の中。round 3: 計算できることは計算する） |
| `missing_attester_id` / `missing_subject_ref` / `missing_claim` | 「envelope の必須欄が無い——anchor の記録として不完全」 | **する**（manifest は evidence の中に残っている） |
| evidence が parse できない／manifest が prov の形でない／`bundle_digest_canonicalization` か `outputs_digest_rule` の名前を知らない／envelope の version を知らない | 「この proof は prov の記録として読めない（理由）。束の digest だけ印刷する」 | 束の digest は計算する（照合先が無い） |
| HTTP 404（proof_id を知らない、または prov の記録でない） | 「anchor はこの proof_id を prov の記録として知らない」 | できない |
| HTTP 429 / 405 / 500、または届かない（網が無い、anchor が止まっている） | 「anchor の読み口が拒んだ（status）／届かない——proof_id と束の digest だけを印刷する。429 なら後で再試行」 | 束の digest は計算する（照合先が無い） |

言葉づかいは記憶 `warranty-scope` の規則に従う: 「固定した」「観測した」と書き、「保証」は記録と手順にだけ、「再現できる」は書かない。

**前提の穴（この設計の外だが、`gc_prov_verify` が第三者に効くために要る）:** anchor の公開鍵が配られていないので、
第三者は proof の anchor 署名を自分で検証できない（記憶 `warranty-scope` の GxP 前 2 件の ①）。v0.1 の `gc_prov_verify` は
鍵が無ければ「anchor-reported」と書き、公開鍵の配布は別件として起票する（§10-3）。提出者の公開鍵も同じ: 顧客が検証者に
束と一緒に渡すか、`--submitter-pubkey` で別経路から渡す。manifest 内の鍵は自己申告。

## 9. 実装の順番（完了できる単位、Principle 1）

| 単位 | 中身 | 完了の印 |
|---|---|---|
| U0 | nf-core の test profile（例 `nf-core/rnaseq -profile test`）を nf-prov つきで 1 本走らせ、`bco.json` と `ro-crate-metadata.json` を fixture として `genomicschain_prov/test/fixtures/` に置く | 2 ファイルがある。各欄がどこまで埋まっているかを 1 表にして L2 に記録 |
| U1 | BCO アダプタ `adapters/bco.rb` → `NormalizedProvenance` | `adapter_bco_test.rb`: fixture から 7 種類が取れる。空欄は nil |
| U1b | 汎用の最小書き出し器 `bin/gc_prov_write.rb`（§4.1。v0.1.11 で `tools/` から訂正——§7 の規則どおり、`Skillset#load!` は `tools/*.rb` をどの node でも eager に require する）: 段の一覧を受け取り、版・digest・checksum・パラメータ・seed・実行系の版を集めて BCO を書く。Tier-3 executor から呼べる形（logic は `lib/genomicschain_prov/writer*`、CLI は bin） | **済（2026-09-21）**。`prov_write_test.rb` 26 本: 2 段の shell 計算（デモの 223, 553, 2 → 388、test の中で実際に走らせる）から BCO が出て、U1 のアダプタで読め、全部集めると `immutable`。checksum を省くと **`local_path`**（v0.1.11 で訂正——workflow は予告どおり `floating` に落ちるが、入力の相対 path は §5 で floating より下の `local_path` なので、最弱である全体はそこで止まる。§4.1 の「floating 止まり」＝ floating を超えられない、は正しい）。checksum が上げていた 4 分類（workflow・runtime・environment・inputs）がすべて落ちることを 1 本で押さえる |
| U2 | 述語 `predicate.rb`（PinStrength を呼ぶ） | `predicate_test.rb`: 手書きの小さな正規化来歴 6 つで 6 等級が出る。fixture の等級が固定される（数値を test に書く） |
| U3 | `genomicschain_prov` に `verdict_spec/prov.rb`、`prov_submit.rb`、`schemas/prov_attestation.schema.json`、`tools/gc_prov_submit.rb`、`lib/genomicschain_prov/place_extension.rb`（`gc_prov_proof` route）。core の 4 か所（§7）と prov の core pin | `prov_submit_test.rb`: `tier2_submit_test.rb` の 14 本のうち prov に対応のある 11 本を写して通す（digest 不一致・identity 不一致・trust_tier 持込・重複回復。toolchain_ruby・tier1 content hash・applied stage の 3 本は prov に無い）。ただし DoS gate の 1 本は「2 MB 超を弾く／64 KB 超の束を通す」に書き換え、dry_run の 1 本（Tier-2 には無い）、TTL が 100 年で Tier-2 の proof は 24 時間のままの 1 本、`idempotency_key` が束ごとに違う 1 本、版ずれの拒否が三つの版を返す 1 本、`gc_prov_proof` route が prov の envelope を §7 の欄だけで返し、未知の id と Tier-2 の id に 404 を返し、`actor_user_id` を含まない 1 本、**Authorization header 無しで route が答え、同じ条件で prov の `tools/call` は拒まれる** 1 本（§0 の約束の test、round 4。unit test ではなく U4 と同じ使い捨て local anchor で回す——route と `/mcp` の順序は `HttpServer` にある、round 5）、SCM 無しの束が null の repo hash で記録される 1 本、script の checksum で workflow が immutable になる 1 本を足す。**v0.1.12 で足す（§6.1）**: immutable 未満の束が拒否され記録が増えない 1 本（拒否の応答に `items[]` の値が無い。**v0.1.13 で置き換え**: immutable 未満の束が記録され、等級 `local_path` と `prov-admission-0.2` を載せ、記録に束の値が無い 1 本。値が漏れないことの拒否側の確認は、署名した等級が束と食い違う提出の拒否で行う）、`platform` の無い束が null 3 つで、有る束が値つきで記録される 1 本、証明の無い束が `zk_receipts: []`・`zk_verification: null` で記録される 1 本（任意は本当に任意）、本物の証明（KairosChain_2026 の size-factor デモの succinct receipt を fixture に写す）が ①〜④ を通って記録され、bytes が registry にも log にも現れない 1 本、①〜④ のそれぞれを一つずつ壊して拒否される 4 本、宣言された証明の bytes が欠ける／宣言に無い bytes が来る 1 本、検証 program が無いと証明つきの束だけが拒否される 1 本、拡張の schema file が `platform` と `zk_receipts[]` を定める 1 本。`gc_zk_verify` 自体は crate の test（本物の receipt が通り、1 byte 変えると落ちる） |
| U4 | `gc_prov_check` と client の `--tier prov` | `submit_client_test.rb` に prov の 1 本。使い捨て local anchor で dry_run → 実提出 → 回復まで（09-09 の Tier-2 と同じ手順）。v0.1.12: 関門に届かない束で `gc_prov_check` が「発行されない、届かない分類はこれ」と出す（v0.1.13 で「発行される、記録が載せる等級はこれ」に置き換え）、証明つきの束で client が `zk_receipt_bytes` を添えて送り記録される、を local anchor で 1 本ずつ |
| U5 | `gc_prov_verify` | fixture + local anchor の proof で「確かめたこと／いないこと」が出る。改竄した束で不一致が出る。§8 の表の 8 行と版違いの見出しが 1 本ずつ。`--submitter-pubkey` 無しで「自己整合」の文言、`--anchor-pubkey` 有りで anchor の行が「確かめたこと」へ移る。v0.1.12: `--zk-receipt` 有りで証明の行が「確かめたこと」へ移り、無しで「anchor が言っていること」に残る。出力の末尾に §6.1 (a)(b) の 2 文 |
| U6 | WRROC アダプタ（v0.2） | 同じ fixture の `ro-crate-metadata.json` から U1 と同じ 7 種類 |
| U7 | 第二の機関目撃者（v0.2）— proof_id と時刻に別鍵で countersign する protocol | 設計から |

U0〜U5 が v0.1。U0 を先にするのは、アダプタの欄名を実物で決めるため（§4 の未確認）。

## 10. 決めていないこと・検証が要ること

1. ~~nf-prov の `bco.json` が `sha1_checksum` と SCM extension を埋めるか（U0 で見る）~~ **U0 で判明（2026-09-20、§13）**: SCM は埋める（remote 起動時）、checksum は入力にも出力にも無い、ツールの版と container は欄ごと無い。顧客側の補完手順は `gc_prov_write --from-nextflow-run`。**決定（09-20、unknowns pass）**: 補完で足す sha256・producer を載せる GenomicsChain の `extension_domain` の schema URL は `https://genomicschain.ch/schemas/bco_extension_genomicschain_v0_1.json`。schema file は v0.1 の実装と同時に repo（`genomicschain_core/schemas/`）に作り、公開は anchor の公開鍵と同じ時期（売る前）
2. `subject_ref` を `prov:sha256:<digest>` にするか、顧客が付ける run 名を許すか。v0.1 は前者（claim に顧客の文字列を入れない）
3. anchor 公開鍵の配布方法（§8 の穴）。この設計の外だが、(2.5) を第三者に売る前に閉じる
4. 第二の目撃者の protocol（U7）
5. PinStrength を core へ移すか（prov が tier2 に依存する形を続けるか）
6. 価格（事業側。stage 3 の実測後）
7. 有料化の時期は事業側の判断（09-20 確定）。この設計の実装はその前に進める
8. ~~container を使わない実行の扱い~~ **決定（2026-09-20）: 環境 = container と software の強い方**（§5 に反映）。U2 で顕在化した
   問題: 「分類が空なら `absent`」の規則をそのまま 5 分類に当てると、container 無しの実行——SUSHI/ezRun、R script、conda だけの
   環境——が全体 `absent` 止まりになる。環境を作り直す経路は二つあり一方で足りるので、最弱の規則は必須の環にだけ当てる。
   両経路の等級は記録に残るので、「container は :latest だが package は hash 固定」も読める
9. **runtime の上限**（同上）: 「版あり → versioned」なので、runtime に checksum か digest が無い限り全体は `versioned` を超えない。
   アダプタは runtime の `locator` と `checksum` を読むようにしてあり、補完器が Nextflow の framework jar の sha256 か実行 image の
   digest を書けば immutable に届く。**決定（09-20、unknowns pass）: 書く。** 補完器は実際に動いた Nextflow の framework jar の sha256 を runtime の
   checksum に入れる。jar の置き場は導入法で違う: launcher 導入なら `~/.nextflow/framework/<版>/`、conda 導入なら
   `<env>/share/nextflow/dist/<版>/nextflow-<版>-one.jar`（U0 の machine はこちら）。補完器は `NXF_HOME` と
   `nextflow` 実行ファイルの場所から探し、見つからなければ checksum を nil のまま残す（versioned 止まり）
10. **補完の真偽**（09-20、unknowns pass で決定）: 補完器が顧客の machine で書く値（ツールの版・image の digest・file の checksum）は
    anchor では確かめない。v0.1 の判は顧客の自己申告（`trust_tier = self_reported`）で、記録の `not_checked` に `bundle_truthfulness`
    を残す。補完の再導出は v0.2 の検証者の判（`prov_verified`、§12）の仕事
11. **宣言した未決（Open Unknowns、09-20 の unknowns pass）**: (i) ~~内部入力の規則は Nextflow の慣習に依っている~~ round 1 で解消:
    規則は「同じ束の中で出力（その locator か filename）として現れる locator」だけを内部とし、path の慣習には依らない（§13.4-3）。(ii) 束には絶対 path と全
    param の値が入る。記録には入らないが、検証者に束を渡すかどうかは顧客の判断で、v0.1 は伏字の仕組みを持たない。(iii) 補完した
    束は補完器を再実行しても同じ bytes にならない（`object_id`・時刻）。v0.1 は要求しない——digest はこの file を指す
12. **正準化の規則**（round 1）: v0.1 は `kairos-sorted-json-0.1`（§2）を記録に名前で載せる。RFC 8785（JCS）への移行は v0.2 の候補
    ——この記録型には古い署名が無いので移れる
13. **等級の網羅は数で見せる**（round 1、round 2 で数え方を直した）: claim に載るのは自分で環境を宣言した段の数 `own/N`。workflow 全体に
    1 本だけ宣言した tool は代替として全段を覆う（等級は上がる）が、claim は `0/N` と読める。その申告の真偽は `bundle_truthfulness` の外。
    v0.2 の検証者の判が `.command.run` と突き合わせる。補完器は段ごとの `prerequisite[]` **だけ**を書く（§13.4-1）ので、補完した束では
    段の網羅がそのまま数に出る
14. **anchor の読み口の認証** — **決定（2026-09-21、operator）: (A) `gc_prov_proof` だけ Bearer 無し・読み取り専用で開く。**
    proof_id を知る者は誰でも envelope を読める。読めるのは §7 の欄と、その manifest に書かれた §6 の欄（束の本文・locator・param 値・
    repo の URL は無い。`workflow_commit` は名前のこともある。`toolchain` は manifest の中——anchor の署名の内側——なので外せない。ただし**提出者の署名欄ではない**: §6 の
    `SIGNED_IDENTITY_FIELDS` には入らない（束の bytes から再導出できないため）。二つの「署名」を混同しないこと、round 6）。§0 の「第三者が後で確かめられる」の実体はここにある——鍵の発行を挟むと「GenomicsChain が
    許した者だけが確かめられる」に変わるので、それは採らない。既存の `attestation_verify` / `attestation_list` は Bearer 有りのまま
    （prov の検証者は使わない）。退けた案: (B) 第三者にも pubkey 束縛の Bearer を発行する（`gc_issue_bound_token.rb`。誰が読んだかは
    残るが、監査人ごとに鍵の手続きと anchor の再起動が要る）、(C) 公開鍵の配布（§10-3）まで Bearer 有りのまま。
    **仕組み（round 3 で実物を読んで決めた）**: MCP の `tools/call` は request ごとに body を読む前に Bearer を検査し（tool 名で
    分岐できない）、anchor では service_grant の AccessGate が `pubkey_hash` の無い呼び出しを重ねて拒むので、MCP tool を 1 本だけ
    認証の外に出す口は無い。v0.1.3 で候補に挙げた transport の allowlist と Synoptis の `public_read.rb` は、前者は存在せず、
    後者は anchoring Log の entry を digest で引く口で proof_id では引けない。**実在するのは Meeting Place の place extension の
    `public_routes`**（Hestia `PlaceRouter`: `/place/web/` 配下の prefix を認証なし・GET/HEAD のみ・公開 rate limiter つきで Bearer の前に
    dispatch する。skillset_exchange が同じ口で catalog を公開している）。`gc_prov_proof` はこれで `/place/web/prov/proof/<proof_id>`
    に出す（§7）。前提: anchor で Meeting Place が動いていること（meeting.genomicschain.io では動いている）。
    **読める欄**は §7 の列挙どおりで、それ以外は返さない。proof_id は `ProofEnvelope` が作る `SecureRandom.uuid`（UUID v4、122 bit）なので
    束の digest からも submission_key からも導けない——proof_id を知る者だけが読める。§12 の「同じ subject_ref の列」を引く口
    （v0.2）は digest を索引にするので、公開にするかは v0.2 で別に決める
15. **継承の代替は経路ごとか、段ごとか** — **決定（2026-09-21、operator）: 現状維持、§5 に逆転を明記するだけ。** 論点: いまは「段が一部でも自分で宣言すると、
    その段は workflow 全体の宣言を両経路とも使わない」（§5）。実測: workflow 全体に digest 固定の image、段 3 だけ版なしの awk を
    正直に足すと段 3 が immutable → floating に落ちる。代案は経路ごとの代替（container は container を、package は package を
    継承）——この逆転は消えるが、round 2 で固定した「段の `:latest` image と workflow 全体の checksum つき package → floating」が
    immutable に戻る。補完器は段ごとにだけ書くのでどちらでも補完した束は変わらない。退けた理由: 正直な `:latest` の申告が workflow
    全体の checksum で覆われる方が、段ごとの申告が下がることより隠す向きに倒れる

**v0.1.14 で足した未決（§6.2、2026-10-14 の草案のまま）。**

- `full` は共有 cluster の run では届きにくい（機械が一つに決まらない）。段ごとの `cpu_model` で機械の条件を代えるかは、実際の束を
  見てから決める。
- Nextflow の trace の `accelerator`・`accelerator_type` 列は要求した GPU の数と種類で、走った機械の GPU の型番ではない〔反証 r2: r2 は
  「GPU の列を持たない」と書いたが、2026-01 の Nextflow から列がある〕。cluster で GPU を使った段の機械の型番は、顧客が plan で書くしかない。
  Linux の Intel の GPU を探る道具を足すか。
- 測る道具の無い独自パイプライン向けに、段を時間とメモリの測定で包む道具（仮称 `gc_prov_measure`）を作るか。作るなら書き出し器
  とは別の道具にし、汎用 file `gc-resources-input-0.1` を書かせる。
- Snakemake の benchmark は `benchmark:` を書いた rule だけを測る。全段に書いていない束は `partial` に留まる。手順書で全 rule への
  `benchmark:` を勧めるか。
- 取り込み口を足す順番。実物の束が来た道具から足す（selective survival）。最初は Nextflow と汎用 file、次に Snakemake。
- 手順書に書く、値が取れる条件〔査読 r1〕: Nextflow の `peak_rss` は task の container に `ps`（procps）が要り、macOS で直接走らせると
  `-` になる。slim な image には `/usr/bin/time` が無いことが多く、bash の `time` には `-v` が無い。古い GNU time（1.7）は最大メモリを
  約 4 倍に出すと二つの査読が述べた（未確認。出力に版が出ないので、版を確かめる手順を書く）。Snakemake の benchmark は job ごとの
  file で、段との対応は (2) の集め方に従う。

## 11. デモ → 設計の対応表

| デモ（`demo.html`） | 設計 |
|---|---|
| 束の JSON（コミットつき） | BCO / WRROC。コミットは使わない（束は checksum を持つ。伏せたい値は束に入れない、が実運用の形） |
| 環境の固定を 4 つから選ぶ | §5 の述語が束から自動で出す。選ばない |
| 正準 JSON → SHA-256 | `Manifest.canonical_json_sha256`（規則は §2） |
| 顧客の鍵で署名 → 台帳 | client + `gc_prov_submit` → Synoptis proof |
| 第二の目撃者ボタン | U7（v0.2） |
| 検証者の「分かること／分からないこと」 | `gc_prov_verify` の出力（§8） |
| 再構築して実行 | (iii)。この設計の外 |

## 12. 判の積み重ね — 誰が、何を言えるか（v0.2 候補、2026-09-20 追記）

利用者の指摘（09-20）: §8 の「台帳が言うこと／言わないこと」は**顧客の判 1 枚**の話である。検証した人、再計算した人、
規制検査者がそれぞれ自分の鍵で判を押すと、言えることが一段ずつ増える。各段の主張は、その人が実際にやったことの範囲を出ない。
主語は全部同じ束の digest なので、台帳の上では「同じ指紋を指す判の列」になる。

| 判 | claim 種別 | 署名する鍵 | 言えるようになること | まだ言えないこと | 置き場所 |
|---|---|---|---|---|---|
| 顧客の判 | `prov` | 顧客 | この束が時刻 T にこの digest だった。等級 N。鍵 X が固定した（§6） | 一致・再構築・適合・正しさ | v0.1 |
| 検証した人の判 | `prov_verified` | 検証者（GenomicsChain か、顧客が指名した第三者） | 束から digest を取り直したら台帳と一致した。段の数・ツール・版・等級を読んだ。locator の到達性を検査したなら、その結果（日付つき） | 再構築・適合・正しさ | v0.2。`gc_prov_verify` の出力（§8）をそのまま proof にする |
| 再計算した人の判 | `prov_reproduced` | 再計算者（(iii)、別会社） | **観測**: 日付・条件（実行系の版、許容 ε、回数）・記録だけから作り直せたか（不足 n 件）・出力が一致したか。不一致も失敗もそのまま記録（記憶 `warranty-scope`） | 適合・正しさ | (iii) 側。形は Tier-3 の二軸判定と同じ |
| 規制検査者の判 | `prov_reg_check` | 検査者（監査人・notified body・当局の検査官） | 規則の名前・版・要件・検査した範囲・日付と、満たす／満たさない。**検査者の名前で** | 正しさ | GenomicsChain は書式と検証を提供し、運ぶだけ。自分では「適合」を書かない |
| 誰の判でも | — | — | — | 結果が科学的に正しい | — |

設計上の含意（v0.2 で決めること）:

- **proof を「同じ subject_ref の列」として引ける**必要がある。いまの `ProofLookup` は submission_key で 1 本を引く。subject_ref（束の digest）で列を返す読み口を足す。`gc_prov_verify` はこの列を読んで §8 の出力を組む。
- **claim 種別ごとに verdict_spec を分ける**（Tier-1/2/3 と同じ形）。各 spec の「言えること」を schema の `claims` と `not_checked` に機械可読で書く。
- **鍵**: 検証者・再計算者・検査者にも、それぞれ pubkey に束縛した Bearer を発行する（既存の `gc_issue_bound_token.rb`）。誰の判かは proof の `submitter_pubkey`。anchor の `attester_id` は全 proof に共通で、目撃者の役。
- **規則の版**: `prov_reg_check` は規則の識別子と版を持つ。`genomicschain_regwatch` の watchlist id と baseline digest をそのまま使えば、変更追跡が「この判が依拠した条文が動いた」と署名つきで言える。ここが並行製品との接点。
- **未決**: (iii) の判を同じ anchor に載せるか（別会社の proof を GenomicsChain が目撃する形になる）。検査者が自分の鍵を anchor に登録する手順。判の取り消し（既存の revoke）が「列」の中で何を意味するか。

**判の種別の入場規則（09-20 追記）:** 台帳に載せる判は「第三者が同じ手順で導き直せる主張」に限る。
指紋・等級・照合結果・条件つきの再実行の観測・規則の版と範囲つきの点検は導き直せる。「結果が科学的に正しい」は
導き直す手順がないので載せない（peer review 的な判は作らない）。判そのものへの異議（著者が同じ論文と同じ規則で
再検査を求める）は導き直せるので範囲の内側。外部の review の表明は、将来必要なら DOI つきの参照として同じ指紋に
結びつけるだけにし、GenomicsChain は作らない。

原理デモ v2 の場面 7・9・10・11 がこの節に対応する。

## 13. U0 の実測 — nf-prov の束は何を書き、何を書かないか（2026-09-20 追記）

U0（§9）を回した。nf-core/demo 1.2.0（commit `555d145b9e701c012f53996a2f17efb2daff5fe7`）を nf-prov 1.7.0・Nextflow 26.04.6・Docker で 1 本、
8 工程すべて完走（failed 0）。束 2 本は `genomicschain_prov/test/fixtures/nfcore_demo_1_2_0/` に verbatim で置いた（由来は同 dir の README）。
記録は GenomicsChain L2 `u0_nfprov_bundle_fields_20260920`。走らせる前に nf-prov の source（`renderers/BcoRenderer.groovy`、
`renderers/WrrocRenderer.groovy`）を読み、実物が source どおりであることを欄ごとに確かめた。

### 13.1 欄の埋まり方（§4 の 7 条件）

| 条件 | BCO（nf-prov 1.7.0） | WRROC（同） |
|---|---|---|
| 入力データ | 8 本、URI のみ。`sha1_checksum` 0/8（https 5、`work/tmp/` 相対 2、outdir 内の `file://` 1） | `File` 10 本、`sha256` 0/10 |
| コード | SCM extension に repo・commit・path（remote 起動のとき） | `codeRepository`、`version` = commit |
| ライブラリ・ツール | **Nextflow の 1 行だけ**。工程のツールは無い | `SoftwareApplication` 8 本、**版は 0/8** |
| container | **欄が無い** | `ContainerImage` 0 本。`CreateAction` 25 本に container の欄なし |
| 参照ゲノム | demo には無い（`parametric_domain` に iGenomes の既定値が 300 本以上並ぶだけ） | 同左 |
| パラメータ | 376 本。値あり 367、文字列 `"null"` 9（未設定を nf-prov が文字列化したもの）。大半が既定値 | `PropertyValue` 23 本（null は落とす） |
| 乱数シード | 無し | 無し |
| 実行環境の版 | Nextflow 26.04.6 | `runtimePlatform` "Nextflow 26.04.6" |

このほか: `object_id` は render ごとの乱数 UUID なので、同じ実行でも render し直せば別の束になる。`created`・`modified` は
workflow の開始時刻（render 時刻ではない）。
`etag` は nf-prov 独自の非正準 hash。WRROC の `conformsTo` は `wfrun/{process,workflow,provenance}/0.1`——規格の最新 0.6 ではない。

### 13.2 §5 の述語をそのまま当てると

| 分類 | 等級 | 理由 |
|---|---|---|
| workflow | immutable | scm_commit 40 hex |
| runtime | versioned | Nextflow 26.04.6 |
| software | **absent** | Nextflow 以外のツールが 0 本 |
| container | **absent** | 欄が無い |
| environment | **absent** | 8 段とも環境の宣言なし（`stages_with_own_environment` 0/8、代替もなし。claim は `0/8`） |
| inputs | local_path | 8 本すべて外部（束の中に、この run が作ったという出力の証拠が無い）。https 5 本は floating、`work/tmp/` 2 本と outdir 内の 1 本は local_path。補完器が hash を足せば immutable |
| **全体** | **absent** | environment（= 段の最弱 = absent）・inputs・workflow・runtime の 4 つの最弱 |

つまり既定の producer の束は、そのままでは `absent` になる（実測は 1 本。renderer の source がツール・container・checksum を
書かないので、nf-prov 1.7.0 の BCO ならどの run でも同じ）。正直だが、見出しとしては役に立たない。
§4.1 の旧文「container digest・checksum が出れば immutable」は nf-prov 単体では起きない。

### 13.3 足りない情報は同じ実行 dir にある

| 足りないもの | 在処 | 取れる等級 |
|---|---|---|
| ツールの版 | `results/pipeline_info/*_software_mqc_versions.yml`（cowpy 1.1.5、fastqc 0.12.1、seqtk 1.4-r122、nf-core/demo v1.2.0-g555d145、Nextflow 26.04.6） | versioned |
| container の名前 | `work/<hash>/.command.run` の `docker run` 行（4 種、すべて tag つき。例 `quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0`）。module の `container` directive は 4 本中 3 本が同じ文字列で、seqtk だけ registry 無し（`biocontainers/seqtk:…`。`quay.io/` は config の `registry` が補う）——実際に動いた名前は `.command.run` で取る | versioned |
| container の digest | `docker images --digests`（4 image すべて sha256 あり。例 fastqc `sha256:e194048d…`） | immutable |
| file の checksum | 実 file を hash する（staging された remote 入力、`work/`、`results/`） | immutable |

trace の既定 14 列に container 列は無い（`trace.fields` で足せる）。WRROC が crate dir に落とす解決済み `nextflow.config`（40 KB）には
`registry = 'quay.io'` しか無く、container directive は module 側にある。

### 13.4 設計への帰結（提案。operator が受け入れれば v0.1 の一部）

1. **`gc_prov_write` は nf-prov 束の補完器も兼ねる。** `gc_prov_write --from-nextflow-run <launch_dir>` が `bco.json`・`*_versions.yml`・
   各工程の `.command.run`（か container 列つき trace）・`docker image inspect`・file の hash を読み、補完した BCO を書く:
   各段の `prerequisite[]` にその段のツール {name, version, uri: `image@sha256:…`}——**段ごとにだけ**書き、workflow 全体の
   `software_prerequisites[]` には写さない（round 2: 写すと代替の経路が全段を覆い、段ごとの網羅が数に出なくなる。
   `software_prerequisites[]` は nf-prov が書いた runtime の 1 行のまま）、runtime（Nextflow）の framework jar の sha256（§10-9）と
   各ツールの file hash、そして **workflow の script 本体の sha256**（round 4: SCM の無い束はこれ無しに floating を超えられない）は
   GenomicsChain の `extension_domain` の `checksums[]` に **その項目の uri を鍵にして**書く（アダプタは
   入力・出力と同じ結合で tool・runtime・script の checksum を読む——round 3: それまで書く場所はあっても読む欄が無かった）、io の各項目に
   `sha1_checksum`（規格の欄は SHA-1）、同じ file の sha256 は同じ `checksums[]` に。
   等級は集めた分だけ上がる（tag のみ → versioned、digest と checksum → immutable）。述語は最弱のままで、何も隠さない。
   補完器が段の `input_list` / `output_list` に task の入出力の uri を書けば、§13.4-3 の順序規則で run の中間 file が内部入力として
   数から外れる。
2. **WRROC アダプタ（v0.2）は profile 0.1 と 0.6 の両方を受ける。**
3. **内部入力の規則（round 1 で改訂、round 2 で順序を入れた）**: 入力が内部（`inputs_internal`、`inputs_total` から外す）になるのは、
   **その束の中で、この run がそれを読む前に作ったと示されているとき**だけ——locator（`uri` のみ。`filename` は producer の
   見出しであって場所ではなく、round 2 で label の一致が入力を消せることが示された）が、ある段の `output_list` に、それを
   `input_list` に持つどの段よりも**前の位置**で現れること。`io_domain.output_subdomain`（公開出力）には段が無いので順序の証拠に
   ならない。次の二つは外部のまま等級に入る: どの段も `input_list` に持たない入力（束はそれがいつ読まれたかを示さない）、
   同じ段が読んで書く上書き（読んだ bytes は run が書く前からあった。codex と skeptic が指摘）。work dir や outdir の path prefix は
   使わない——prefix は producer が選ぶ値で、`outdir=/data` とすれば弱い入力が等級から消える（round 1 で 3 席が指摘、実際に
   再現された）。nf-prov の workflow 入力は元々「task が作らなかった入力」なので、その束ではこの規則は何も内部にせず、
   run が作った一時 file は書かれたとおり checksum 無しの local path として数える（補完器が hash を足せば immutable）。
   規則の向きは一貫して「内部と示す証拠が無ければ外部（＝等級に入る）」——producer が弱い入力を隠す側に倒れない。
4. **パラメータ**: `params_total` は `parametric_domain` の長さ（ここでは 376）。既定値で膨らむが「存在の有無のみ」の方針は変えない。
   `seed_recorded` は名前に seed を含み**値を持つ** param の有無（値が `"null"` なら false）。
5. `object_id` の乱数と時刻は設計に影響しない。digest はこの file を指す。同じ file の再提出は同じ proof の回復、render し直した file は
   別の proof——それで正しい。
6. `extension_domain` の `extension_schema` URL は **決定（09-20）**: `https://genomicschain.ch/schemas/bco_extension_genomicschain_v0_1.json`
   （§10-1。schema file は repo に、公開は売る前）。

### 13.5 顧客の手順への影響

Nextflow の顧客は run のあとに 1 手順増える: `gc_prov_write --from-nextflow-run` → `gc_prov_check` → client。
これは「補完しなければ等級 absent」と正直に見せた上での選択肢であって、補完を強制はしない。上流（nf-prov）に
container・ツールの版・checksum を BCO に書く提案を出す道もある。出せば補完器の仕事は減るが、受理と配布は先方の時間で決まる。

## 14. 改訂履歴

### 凍結の記（2026-09-21、operator 決定）

設計 review は round 8 で終了し、設計は **v0.1.10 で凍結**する。round 9 は回さない。

**理由。** operator の指摘: 「adapter は設計よりも実装の問題ではないか。だとするなら設計レビューは終わりにしよう。
設計なのに test が走っていること自体がおかしい」。これは正しく、数字が裏づけている。

| | 設計 | code | test |
|---|---|---|---|
| round 4 適用時 | 657 行 | 758 行 | 862 行 |
| round 8 適用時 | 759 行 | 1,029 行 | 1,259 行 |
| **4 巡の増分** | **+102 行（13%）** | **+271 行（36%）** | **+397 行（51%）** |

各巡の artifact で code は **付録（advisory only — findings against these never block; they go to the queue）** として
渡していた。席はその規則を守っており、round 8 の codex は 3 件中 2 件に「Advisory under the appendix rule」と明記して
返している。規則を破ったのは orchestrator 側で、付録への指摘を blocking として扱い毎巡 code を書き直していた。

**それでも設計だった分**（+102 行）は残る: §5 の等級規則（読めない項目を最弱として数える、scheme 無しの digest は
registry の形のときだけ image、checksum の経路には locator が要る、読めない項目は container と package の両経路を弱める）、
§4 の SCM と拡張 block の規則、§6 の `record_version` 0.2 と「述語の返り値を anchor が log にも応答にも出さない」不変条件。
これらは署名される等級と記録の契約を決めるので設計の中身である。付録の規則を守っていれば、同じ内容はもっと少ない巡で
出ていた——**設計の主張として述べられた指摘だけを blocking にすればよかった**。

**残る懸案の行き先。** 以下は設計の欠陥ではなく実装の課題として queue に置く。review の巡では追わない。

- `software_of` の重複除去が読めない項目を二つ潰す（`software_total` が 1 つ少なく数える。等級は動かない）
- `counts` が `np.workflow['scripts_total'].to_i` を読む（WRROC アダプタ U6 が欄を書かなければ黙って 0 を署名する）
- `stages_with_own_environment` が空の宣言で N/N まで水増しできる（等級は動かない）
- 拒否語の語全体一致が道具名と衝突する（`head (GNU coreutils) 8.32` が floating、`8.32` が versioned。§5 に宣言済みの緩み）
- 一成分の digest（`ubuntu@sha256:…`）と `OCI_TAGGED` に registry 検査が無いこと（いずれも §5 に宣言済みの緩み）
- §8 が `nonce` と `chain_tip_hash` の在処を書いていない（実装時に確定する）

**設計を改訂する条件。** 実装が突き当たった事実があるときだけ、個別に改訂する。「review の巡を回す」形には戻さない。



| 版 | 日付 | 何が変わったか |
|---|---|---|
| v0.1.14 | 2026-10-14 | **凍結後、四つ目の個別改訂。** operator の決定（計算資源の記録、案イ、GPU の型番を記録に）。束の拡張 `resources`（`machine` と段ごとの `steps[]`。取り込み口は道具ごと——Nextflow の trace、Snakemake の benchmark、GNU time、汎用 file、plan——で、等級は共通の形だけから出す）、新しい規則 `gc-resources-0.1` による `grade_resources`（absent < partial < steps < full、全段の最弱、段の無い束は多くて partial、`grade_overall` には入れない）、署名欄 9 つ（値の出どころ 3 欄を含む。GPU の型番は anchor の導出で絞る）、`not_checked` 10 項目、`record_version` 0.4。アダプタ 0.4.0 と述語 0.3.7 は変えない（7 つの等級の規則は動かず、0.3 の記録は新しい検証器でも再導出される）。検証器の再導出は、7 つの等級と資源の欄を分けて版を見る。route B の線は変えない |（2026-10-17 実装: prov 0.4.0、core 0.6.1、書き出し器 0.3.0。operator の決定 3 件——D5 はベンダー限定＋形で落とす、plan は要求値だけ、D4 は何も足さない——と規則の空白を埋めた細部は §6.2 の「実装で決めたこと」）|
| v0.1.13 | 2026-10-12 | **凍結後、三つ目の個別改訂。** operator の決定 2 件（L2 `ruling_tier25_gate_withdrawn_20261012`）。(1) v0.1.12 の G1（immutable を発行の関門にする）を撤回: anchor はどの等級でも記録を発行し、等級を計算したとおりに載せる。`admission_rule` は `prov-admission-0.2`。`GradeBelowRequirement` を削り、schema の `grade_overall` を 6 段階に戻し、`admission_rule` は 0.1 と 0.2 の両方を許す（0.1 の記録が使い捨ての local anchor に残っているため）。検証器は記録の `admission_rule` をその名前の意味で読む。(2) Tier 3 の route B は Tier 3 の側で署名された等級を読み、D11 の元の線（`grade_overall` ≥ versioned、inputs = immutable、`outputs_with_checksum` ≥ 1）に戻す。§6.1 (1)、§8、§9 の U3・U4 の行を直した。code: prov 0.3.0（記録の欄の意味が変わり、0.2.0 の検証器は新しい記録を誤って説明するため minor を上げた）、test は prov 6 本・core・tier1/2/3・regwatch すべて緑。G2（ZK 証明の検証）は変えない |
| v0.1.12 | 2026-10-12 | **凍結後、二つ目の個別改訂。** review の巡ではなく operator の決定 3 件（ruling `ruling_service_plan_two_stage_drive_vk_20261011` の D9・D13、L2 `ruling_tier25_gate_and_zk_verify_20261012` の G1・G2）。新しい §6.1 に集め、§6・§7・§8・§9 は該当行だけ直した。(1) immutable は発行の関門: `grade_overall` が immutable 未満の束は拒否し記録しない、server が決める欄 `admission_rule`、Tier 3 の route B もこれに合わせる。(2) CPU と OS: 束の拡張 `platform` を書き出し器が自己申告で書き（host 名は書かない、補完器は明示したときだけ）、署名欄 `platform_*` 3 つ（null 可）。(3) ZK 証明: 束の拡張 `zk_receipts[]` で宣言し、bytes は提出に添え、anchor が版固定の Rust program `gc_zk_verify`（risc0-zkvm 3.0.6）で検証し、journal の入出力 digest を束の段の入出力と照合してから記録する。記録には同一性だけ（指紋・image ID・zkVM の名前と版・段・journal の形）と server の欄 `zk_verification`。bytes と journal の値は載せない。operator は当初の選択肢文が「v0.2 に回す」と書いていた (B) を選び、追加の質問で「11/15 から」と答えた。(4) not_checked 9 項目、record_version 0.3、アダプタ 0.4.0、拡張の schema file を U3 で作る（公開は operator の判断）。(5) HTTP の body 上限 5 MB 以上。根拠の実測: succinct receipt 223,746 bytes、検証 0.012 秒、journal = (入力 file の SHA-256, 出力 bytes)（KairosChain_2026 `log/zk_demo_sizefactor_20260929/03_proofs`、`00_prereg/instances.csv` で input_sha256 = registered_commitment_sha256） |
| v0.1.11 | 2026-09-21 | **凍結後、最初の個別改訂。** review の巡ではなく、U1b の実装が突き当たった事実 2 件（凍結の記の「設計を改訂する条件」）。(1) §9 の U1b が `tools/gc_prov_write.rb` と書いていたが、§7 は round 3 に「CLI は `tools/` に置かない——`Skillset#load!` が `tools/*.rb` をどの node でも eager に require する」と決めている。gem の `skillset.rb` を読んで再確認したうえで §9 を `bin/` に訂正し、§7 の表に `gc_prov_write` の行を足した（v0.1 の §9 は round 3 より前に書かれた行が残っていた）。(2) §9 の完了の印「checksum を省くと等級が floating」を実測 `local_path` に訂正。workflow は予告どおり `floating` に落ちるが、plan が入力を相対 path で名指すため入力は §5 で floating より下の `local_path` になり、最弱である全体はそこで止まる。§4.1 の「floating 止まり」は正しい（floating を超えられない、の意）。意図——「等級は集めた分だけ上がる」——は test が 4 分類すべての落下で押さえている。U1b の実装そのもの: writer 0.1.0、`prov_write_test.rb` 26 本、prov 全体で 103 本 / 644 assertions 緑 |
| v0.1 | 2026-09-20 | 起草。§0–§12 |
| v0.1.1 | 2026-09-20 | U0 の実測（§13）、unknowns pass（§10-1/9/10/11） |
| v0.1.2 | 2026-09-20 | review round 1（REVISE）の 5 件: §5 段ごとの環境と版の形、§13.4-3 出力の証拠による内部入力、§6 記録の契約、§6/§8 proof の寿命と検証者の言い方、§7 配置 |
| v0.1.10 | 2026-09-21 | review round 8（4 席中 3 席回答——opus4.6 が再び 600 秒 timeout——全員 REVISE）の (b)。round 8 は「境界の第三形が保つか」を問うために回した round で、**保っていない 5 点**が出た: §5 欄の有無を Ruby の真偽でなく key で見る（JSON の `false` が素通りし `"script": false` が文字列 `"false"` として `scripts_total: 1` を署名していた。opus5・codex）、§5 文字列の欄に object が来たら「無い」扱い（`to_s` が Ruby の描画を署名される同一性に入れ、`Hash#inspect` の書式が 3.4 で変わったため同じ束が interpreter で違う等級になった。opus5）、§5 段の `input_list`/`output_list` と拡張の `checksums[]` も境界の対象へ（object で書かれると要素が落ち、**弱い入力が等級から消えた**。codex が再現、opus5・cursor も指摘）、§4 `sha256` は欄の有無で見る（`null` や空文字なら pin が残り `"?"` なら外れていた。codex）、§5 `scm_extension` が object でなければ空にせず**取り除く**（空にすると rank 0 の宣言として正しい commit hash を押しのけた——**round 7 の境界規則が自分で作った欠陥**。cursor）。§6 に「述語の返り値も束の内容であり anchor は log にも応答にも出さない」を明記（opus5）。(c) の整理: §4 の struct 一覧・§5/§6 の版表記・`readable` の註・SCM 食い違いの比較対象・`outputs_with_checksum` の数え方・未使用定数 `RANGE_ONLY_WORD` の削除。code: adapter 0.3.7 / predicate 0.3.7、test 77 本 / 493 assertions 緑（新規 6 本は修正前の tree で落ちることを別 checkout で確認） |
| v0.1.9 | 2026-09-21 | review round 7（4 席全員回答、全員 REVISE。4 席が揃ったのは round 4 以来）の (b): 正規化を**束が入る境界の一箇所**に移動（round 5 は経路ごと、round 6 は列挙した 5 配列に当て、どちらも当て忘れを残した——`parametric_domain[]`、SCM の block、runtime の走査。以後は `load` 直後を通った束に非 object 要素が無い）、§5 `script[]` の裸の文字列は実物の nf-prov 1.7.0 が書く読める申告なので例外と明記（v0.1.8 の文が実装と食い違っており、**文の側が誤り**だった。3 席が指摘）、規格が配列と定める欄が object なら `FormatError`、§5 checksum の経路には locator が要る（道具・runtime を入力に揃え、`inputs_with_checksum` も locator のある項目だけ数える）、§5/§10-8 読めない項目は container と package の両経路を弱める（正直な `docker://b:latest` を読めない要素に差し替えると段が上がっていた）、§4 同強の SCM 宣言が食い違えば記録しない、§4 読めない digest も食い違い扱い・ただし pin しないのは拡張の SHA-256 であって項目自身の `sha1_checksum` ではない、§5 拒否語と道具名の衝突（`head (GNU coreutils) 8.32`）を下振れを選ぶ緩みとして明記、§6 `record_version` を 0.2 に。code: adapter 0.3.6 / predicate 0.3.6、test 72 本 / 472 assertions 緑（新規 6 本は修正前の tree で落ちることを別 checkout で確認。既存 1 本は道具立てに locator を足して更新——新しい規則が触れる形だったため、test の趣旨は継承の可否で等級ではない） |
| v0.1.8 | 2026-09-21 | review round 6（4 席中 3 席回答——opus4.6 は 600 秒で timeout——全員 REVISE、指摘は高度に一致）の (b): §4/§5 **object でない配列要素**も落とさず `absent` として数える（`input_subdomain` / `output_subdomain` / `prerequisite` / `software_prerequisites` / `script[]` の全部。round 5 の修正は読めない object だけを保持しており、裸の文字列や `null` は依然落ちていた）、§5 「何も名指さない」の判定を checksum と版の枝より前へ（取得先の無い digest が immutable を買っていた）、§5/§4 container の経路も参照全体が image digest のときだけ immutable（`docker://tool:latest#@sha256:…` が再現）、§5 `.x` は候補を採る前に全候補を走査（`1.x 1.0` と `1.0 1.x` が分かれた）、§4 `genomicschain_extension` は全 block を統合し同一 locator の digest 食い違いは pin 無し、§6 `scripts_total / scripts_with_checksum` を署名される欄に、§5 tag の形に registry 検査を掛けていない理由を明記（v0.1.7 の記述は実装と食い違っていた）、§7 core 変更 (1) から `gc_prov_proof` を削除（v0.1.3 の名残）、§6/§10-14 `toolchain` の二つの「署名」を書き分け、§6 の版の例を 0.3.5 に。反証 1 件: 入力の URL 判定が tier2 の規則を使い `file://` が floating に上がるという指摘は再現せず（`local_path` のまま、§13.2 の実測どおり）。code: adapter 0.3.5 / predicate 0.3.5、test 67 本 / 446 assertions 緑（新規 9 本は修正前の tree で落ちることを別 checkout で確認） |
| v0.1.7 | 2026-09-21 | review round 5 の subprocess 席（4 席中 opus5 の 1 席のみ回答。worker が SIGTERM で落ち、opus4.6 は中断、codex は空、cursor は認証切れ——L2 `review_r5_…`）の (b) 5 件: §4/§5 読めない項目を落とさず `absent` として数える（`inputs_total`・`outputs_total` は署名される分母、段の `prerequisite[]` は継承させない）、§4/§5 scheme 無しの digest つき名前は registry の形のときだけ image（`tools/awk@sha256:…` は path）、§4 SCM extension が複数なら最弱、runtime の重複削減は predicate の `runtime_grade` 自身を呼ぶ（adapter の写しを廃し `defined?` 分岐を削除）、`input_grade` の `empty locator` 分岐が生きる。code: adapter 0.3.4 / predicate 0.3.4、test 58 本 / 417 assertions 緑（新規 7 本は修正前の code で落ちることを別 checkout で確認） |
| v0.1.6 | 2026-09-21 | review round 5 の persona 3 席の (b) 3 件（script[] は全項目、v/V 始まりの拒否、印はどの語でも）と (c) の文言（§8 json の実測、submission_key の組成、§9 U3 の test 環境、OCI_TAGGED の先頭文字）。subprocess 4 席の結果は L2 `review_r5_…` に。code: adapter 0.3.3 / predicate 0.3.3 |
| v0.1.5 | 2026-09-21 | falsifier（79 件中 4 件を反駁、修正済）を含む。review round 4（REVISE、5 席全員回答）の H1–H4: H1 code（範囲の印だけの語と候補内の印で ranged、拒否語は数字始まりの候補だけ・前後に数字可、Unicode 空白、末尾の `,`、runtime の同名項目は最弱、image 参照の形を adapter でも固定、checksum は hex のみ、FormatError の cause を捨てる）、H2 §6/§7（idempotency_key = sha256(submission_key)）、H3 §4/§5/§13.4-1 + code（script の checksum で workflow が immutable）、H4 §7（extension の契約・404・rate limit 30/分・ed25519 gem・install 順）、§8（from_h、json < 2.10、429 の行、5 行目の印刷、版違いの見出しに claim と submission_key）、§9（no-Bearer の test、U5 の行数）、§10-14（読める欄の言い方、proof_id の出所）。code: adapter 0.3.2 / predicate 0.3.2、test 52 本 |
| v0.1.4 | 2026-09-21 | falsifier（169 件中 6 件を反駁、修正済）と operator の決定 §10-15 を含む。review round 3（REVISE）の 5 件: G1 §5/§4（版の規則: 拒否は語全体、候補は数字を含む語を左から、DOI は locator 全体、runtime の digest は OCI 参照だけ、段の一部宣言の逆転を明記、object でない段は拒否）、G2 §6（null 5 欄、正準化規則と outputs 規則を署名、record_version が署名欄を固定、idempotency に predicate_version、prov の core pin）、G3 §7/§10-14（`gc_prov_proof` は place extension の公開 route、返す欄の列挙、record_type の絞り、proof_id は UUID v4）、G4 §8（二つの署名の算法と bytes、確かめること 4 行追加、revoked は常に anchor-reported、5〜6 行目は照合する、prov でない記録の行、chain_tip_hash は台帳末尾の hash）、G5 §6/§13.4-1（誤り文に束の値を入れない、拡張 checksum を tool と runtime に結合、重複除去の鍵に checksum）。§10-15 を operator の決定待ちで追加。code: adapter 0.3.1 / predicate 0.3.1 |
| v0.1.3 | 2026-09-21 | falsifier（128 件中 5 件を反駁、修正済）と operator の決定 §10-14 (A) を含む。review round 2（REVISE）の 5 件: F1 §5/§13.4-1（段 = 位置、重複除去に段、継承は代替のみ、段ゼロは absent、版の規則を言葉で、locator は immutable にならない、claim は own/total）、F2 §13.4-3（uri のみ、前の段が作ったものだけ内部、上書きは外部）、F3 §6/§7（core 4 か所と TTL の経路、`pin_strength_version` = 規則の版、`outputs_digest` の規則名、seed を署名の外へ、null になりうる欄、版ずれの語彙、回復は同版のみ）、F4 §7/§8（`gc_prov_proof`、手元での署名検証、誤り符号の表、版違いの見出し、読み口の認証 §10-14）、F5 言い回し（§2 正準化の限界、§4 checksum の出所と accessor、§6 repo hash の推測余地、§8 chain_tip_hash は順序、Gate A と HTTP の上限）。code: adapter 0.3.0 / predicate 0.3.0 / tier2 0.4.1 |
