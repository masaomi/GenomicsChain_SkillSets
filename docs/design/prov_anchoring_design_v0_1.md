# (2.5) 来歴の固定（provenance anchoring）— 設計 v0.1

**日付:** 2026-09-20
**著者:** masaomi（起草は Claude Fable 5.1、このセッション）
**状態:** 草案 v0.1.8（2026-09-21: round 6（3 席回答、全員 REVISE）の (b) を反映——「読めない項目を落とさない」を **object でない要素**まで広げ、項目を読むすべての場所に一つの規則として当てる。checksum と版の枝より「何も名指さない」の判定を前に置く。container の経路も digest の形で固定。`.x` は全候補を走査。拡張 block は全部を統合。`scripts_total / scripts_with_checksum` を記録の欄に。code は adapter 0.3.5 / predicate 0.3.5、test 67 本緑。v0.1.7: round 5 の subprocess 席で唯一返答した opus5 の (b) 5 件を反映——読めない項目を落とさず absent として数える、scheme 無しの digest は registry の形のときだけ image、SCM extension の複数は最弱、runtime の重複削減は predicate の規則そのもの。code は adapter 0.3.4 / predicate 0.3.4、test 58 本緑。v0.1.6: round 5 の persona 3 席の (b) を反映——script[] は全項目の checksum で pin、v/V 始まりの候補も拒否語を見る、範囲の印はどの語にあっても ranged、§8 json の言い方と submission_key の組成。code は adapter 0.3.3 / predicate 0.3.3、test 53 本緑。round 5 の記録は L2 `review_r5_prov_anchoring_v0_1_5_20260921`。v0.1.5: round 4（REVISE、5 席全員回答）の残り H1–H4 を反映——H1 code（範囲の印の語、拒否語の位置、runtime の重複、image 参照の形、checksum の形、例外の cause）、H2 §6/§7 idempotency は submission_key から、H3 script の checksum で workflow が immutable に届く、H4 §7/§8/§9/§10-14 の文言。round 4 の記録は L2 `review_r4_prov_anchoring_v0_1_4_20260921`。v0.1.4: round 3（REVISE）の (a)/(b) を 5 件 G1–G5 に束ねて反映——G1 §5 版の規則・DOI・runtime、G2 §6 null 欄と正準化規則の署名、G3 §7/§10-14 読み口を place route に、G4 §8 検証者の言えること、G5 §6/§13.4-1 誤り文と拡張 checksum の結合。round 3 の記録は L2 `review_r3_prov_anchoring_v0_1_3_20260921`。v0.1.3 まで: round 2 の (a)/(b) を 5 件の直しに束ねて反映——F1 §5/§13.4-1 帳簿の直し（段の同一性・重複除去・継承の数え方・版の規則・locator の上限）、F2 §13.4-3 内部入力の順序規則、F3 §6/§7 記録と core の変更 4 件、F4 §7/§8 検証者の読み口と誤り符号、F5 言い回し。code は adapter 0.3.0 / predicate 0.3.0 / tier2 0.4.1 で反映済、test 41 本緑。round 1 の記録は L2 `review_r1_prov_anchoring_v0_1_1_20260920`、round 2 は `review_r2_prov_anchoring_v0_1_2_20260920`。改訂履歴は §14）
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
束が一つの file について二つのことを言っているとき、どちらが勝つかを配列の順が決めてはならない。

### 4.1 束を出す側（producer）は差し替え可能にする — Nextflow に縛らない（09-20 追記）

利用者の指摘: nf-prov を唯一の入口にすると「全部の計算を Nextflow で書く」という第三者依存が生じる。
アダプタが読むのは **形式（BCO / WRROC）**であって nf-prov ではないので、束を出す側は複数持てる。

| producer | 対象 | 自動度 | 到達できる固定度 | 状態 |
|---|---|---|---|---|
| Nextflow + nf-prov（既定） | Nextflow で回す pipeline | 全自動（config に 1 block。fixture の `prov.config` は 13 行） | **そのままでは `absent`**（U0 実測 §13: container もツールの版も checksum も束に無い）。`gc_prov_write --from-nextflow-run` で補うと、tag だけなら versioned、digest と checksum まで取れば immutable | v0.1。U0 済（2026-09-20、fixture あり） |
| `gc_prov_write`（汎用の最小書き出し器。§13 以降は nf-prov 束の補完器も兼ねる） | shell・R・Python・SUSHI/ezRun など、実行系を問わない。Nextflow の実行 dir を渡せば nf-prov の束を補う | 半自動: 段の一覧（コマンド）を顧客が書き、ツールの版・container digest・入出力の checksum・パラメータ・seed・実行系の版は script が集める | 記録した分だけ。checksum を取れば immutable、取らなければ floating 止まり — 等級がそのまま見せる | **v0.1 に入れる**。Tier-3 の実行系（local / thoa）が自分の実行を束にするのにも使う |
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
  :workflow,        # {'name','version','repository','commit','ref_kind','path','script'}
  :runtime,         # {'engine','version','locator','checksum'} か nil
  :software,        # [{'name','version','locator','checksum','stage'}] runtime を除く全ツール
  :containers,      # [{'ref','name','stage'}] software のうち locator が OCI image 参照のもの
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

**版の規則（言葉で。predicate 0.3.3 の `version_grade`）。** BCO の `version` は自由文なので、空白で語に切って次の順で読む。
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

  **この規則は「項目を読むすべての場所」に一つの形で適用する**（round 6、3 席が独立に同じ場所を挙げた）。v0.1.7 は読めない
  **object** だけを保持しており、**そもそも object でない要素**（裸の文字列、`null`）は依然として捨てていた。対象は
  `input_subdomain[]`、`output_subdomain[]`、`prerequisite[]`、`software_prerequisites[]`、`script[]` の全部。object でない要素は
  空の項目として保持し、最弱（`absent`）として数える。裸の文字列を locator として読むことはしない——規格の項目は object であり、
  推測すれば producer の文字列が経路を選ぶことになる。`script[]` も同じで、読めない要素を先に落としてから「全項目に checksum が
  あるか」を判定すると、判定対象の配列自体が縮む（uri を書かなければ `immutable`、正直に書けば `floating` だった）。
- **checksum も版も、何を digest したかを名指していなければ等級を上げない。** 「何も名指さない項目は absent」の判定は、checksum の枝と
  版の枝より**前**に置く（round 6）。取得先の無い digest は第三者に何も許さず、等級が測っているのはまさにそれである。同様に、
  name も uri も無く version だけがある項目は、道具を名指していないので `versioned` ではなく `absent`。
- **container の経路も digest の形で固定する。** tier2 の `PinStrength.container` は digest の**部分文字列**を pin と読む——repo の
  設定値を読む道具としては正しいが、署名される等級には使えない。`docker://tool:latest#@sha256:<64 桁>` が immutable に届いていた
  （round 6、codex が再現）。runtime と同じく、参照**全体**が image の digest 参照のときだけ immutable とし、digest らしい末尾を
  持つだけの参照は floating で打ち止める。
- **`.x` のような全体印は、どの候補にあっても全体に効く。** 候補を左から見て最初に release の形に合ったものを採ると、`1.x 1.0` は
  ranged、`1.0 1.x` は versioned になっていた（round 6、codex が再現）。同じ申告の並べ替えで等級が変わるので、`.x` は候補を採る前に
  全候補を走査する。範囲の印（`< > ! *`）が既にそうなっているのと同じ扱い。
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
                            等級を出した手順の版: アダプタ（prov-adapter-bco-0.3.5）、述語（prov-predicate-0.3.5）、
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
```

**null になりうる欄（5 つ）:** `producer_name` / `producer_version`（束が名乗らない。nf-prov）、`outputs_digest`（checksum つきの出力が
0 本）、`workflow_commit` と `workflow_repository_sha256`（SCM extension が無い——`gc_prov_write` が shell / R / Python の計算から
書く束は SCM を持たない。round 3: 必須のままだと §4.1 の最初の非 Nextflow producer が anchor に届かない）。schema は五つを
`["string","null"]` にし、null は「無い」の意味で署名に入る。それ以外の署名欄は必須。**署名される欄の集合は `record_version` で
固定する**: 検証者は manifest の `record_version` の集合で `params` を組み立て、知らない `record_version` は版違いの見出しへ（§8）。

**server が決める欄（署名の外）:** `trust_tier = 'self_reported'`（提出者＝顧客自身の申告。Tier-2 と同じ語）、`toolchain`
（anchor の Ruby と platform。Tier-2 では digest subject の中にあったので署名できたが、束は grader の interpreter を持たないので
署名しない——round 1）、`seed`
（`{recorded, detection: heuristic}`。名前の推測なので署名の外——round 2）、`not_checked`（builder が固定した列 6 項目:
`locator_reachability`, `bundle_truthfulness`, `bundle_schema_conformance`, `checksum_values_as_written`,
`reference_genome_identification`, `seed_identification`。schema は enum で固定し、client が送ってきた値は捨てる）。
同一性は「束の bytes ＋ 名前つきの手順の版」から導出される——束だけからではない。
**記録に入れないもの:** 束の本文、入力・出力の locator の列、パラメータの値、repository の URL。すべて digest で束縛し、顧客の手元に残す。
Synoptis の evidence 上限は 64 KB（`Config.max_evidence_size`）だが、記録は同一性と数だけ（試算 2.3 KB: §6 の欄を fixture の値で組み、
署名つき operator を含めて canonical JSON にした大きさ。U3 で実測に置き換える）なので余裕がある。

**束を残さない（不変条件、round 1 で明文化）:** anchor は束を 1 回の導出の間だけ memory に持ち、disk にも log にも書かない。
HTTP の access log は request body を記録しない設定にし、例外の trace は `params` を伏せる。**アダプタと述語が投げる例外の
message に束の値を入れない**（round 3: `FormatError` が JSON parser の断片や `spec_version` の値を写していた。message は欄の名前・
数・位置だけ。顧客側の `gc_prov_check` は顧客の machine で動くので詳しく出してよい）。束には絶対 path と全 param の値が
入る（§10-11 ii）ので、これが「束は顧客の手元に残る」という約束の実体。

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
例: `prov:prov-predicate-0.3.5:absent:0/8:9bd92601…:<key>`。台帳を眺める人が、どの規則の版で出た等級か、段の何割が**自分の**環境を
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
`record_version: 0.1`、`mcp_tool_name: gc_prov_submit`、`additionalProperties: false`。title は「pin strength」で、「再構築十分性」とは
書かない（等級は locator が第三者に何を許すかであって、再構築できることではない）。`not_checked` は必須で、builder が固定した
6 項目の列（上）を enum で持つ。

## 7. 道具と置き場所

| tool / script | 置き場所 | 動く場所 | 網 | 何をするか |
|---|---|---|---|---|
| `gc_prov_check` | `genomicschain_prov/bin/`（`tools/` には置かない: `Skillset#load!` が `tools/*.rb` をどの node でも eager に require するので、CLI の option parse が anchor の起動時に走る——round 3） | 顧客の workstation（off-anchor） | 使わない | 束を読み、digest・等級・数・`signed_params` を出す。`--json` で機械可読 |
| `gc_submit_client.rb --tier prov` | `scripts/`（既存に 1 tier 足す） | 顧客の workstation | anchor へ HTTPS | `signed_params` に署名して `gc_prov_submit` を呼ぶ。`--dry-run` / `--print-only` は既存のまま |
| `gc_prov_submit` | `genomicschain_prov/tools/`（prov の `skillset.json` の `anchor_profile_tool_classes`。core の登録を汎用化して読む） | anchor のみ | — | Tier-2 submit と同じ骨。ただし束の gate は §6 の Gate A。`dry_run` で `signed_params` を返す |
| `gc_prov_proof` | `genomicschain_prov/lib/genomicschain_prov/place_extension.rb`——MCP tool ではなく **Meeting Place の公開 route**。prov の `skillset.json` の `place_extensions[]` に `{class, require, public_routes: ["/place/web/prov/"]}` を書き、Hestia の `PlaceRouter#register_extension(public_routes:)` が `/place/web/prov/proof/<proof_id>` を **認証なし・GET/HEAD のみ・公開 rate limiter つき**で Bearer の前に dispatch する（round 3 で実物を読んだ: MCP の `tools/call` は body を読む前に Bearer を検査し、anchor では service_grant の AccessGate も重ねてかかるので、tool として登録しても 1 本だけ認証の外には出せない） | anchor のみ（Meeting Place が動いている node） | — | `proof_id` → registry の envelope。**返すのは次の欄だけ**: `proof_id, version, attester_id, subject_ref, claim, evidence`（canonical JSON の文字列 `{manifest, manifest_body_sha256}` そのまま）`, merkle_root, timestamp, ttl, submitter_pubkey, signature` に、`evidence` を parse した `manifest` と registry の `revoked` を足す。`actor_user_id`（Bearer の `--user` 名）・`actor_role`・`metadata` は**返さない**（署名の外の欄で、検証に要らず、顧客の token 名を漏らす——round 3、3 席）。`manifest.record_type` が `prov_attestation` でなければ not found と同じ返事（registry は全 tier で 1 本の `proofs.jsonl`。Tier-2 の manifest は repo の URL を hash せずに持つ——round 3、codex と verifier）。既存の `attestation_verify` は `valid / errors / content_hash / checked_at / proof_id` を返すだけで evidence を返さず、`attestation_list` は要約だけなので、第三者は manifest を読めない（round 2 の P0）。この route が §8 の第一段の材料。**extension の契約**（Hestia `PlaceRouter` が要求する、round 4）: `initialize(router)`、`public_call(env) → Rack の三つ組か nil`、`call(env, peer_id:) → nil`、`public_route_prefixes → ['/place/web/prov']`（`skillset.json` の `public_routes` は記録、class 側の列挙が `meeting_place_start` 経由の再登録でも効く）。見つからない・prov でない → HTTP 404 に JSON `{"error":"not_found"}`（extension 自身が組む。`public_call` が nil を返すと router の既定 404 は text/html）。rate limit は Hestia の公開 limiter: **30 requests/分 / client IP**、skillset catalog と共有 |
| `gc_prov_verify` | `genomicschain_prov/bin/`（同上） | 検証者（GenomicsChain または第三者） | anchor の `gc_prov_proof` route を GET | 束 + proof_id → envelope を取る → digest・等級を再計算 → manifest と照合 → 提出者の署名（と、鍵があれば anchor の署名）を**手元で**検証 → 「確かめたこと／確かめていないこと」（§8） |

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
| anchor | core + tier1 + tier2 + tier3 + **prov** | true | `gc_prov_submit` |
| 顧客 workstation | core + tier2 + **prov** | false | `gc_prov_check`, client |
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
確かめていないこと（manifest の not_checked をそのまま写す）
  - locator の先が今も取得できるか
  - 束が実行を正しく写しているか（producer と補完器の出力を信じている）
  - 束が規格の schema に適合しているか／束に書かれた checksum が正しいか（書かれたまま数えている）
  - 参照ゲノムが何だったか、乱数シードが何だったか（名前の推測は記録に無い）
  - 出力が正しいか、再構築して同じ出力が出るか  ← (iii) の仕事
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
| U1b | 汎用の最小書き出し器 `tools/gc_prov_write.rb`（§4.1）: 段の一覧を受け取り、版・digest・checksum・パラメータ・seed・実行系の版を集めて BCO を書く。Tier-3 executor から呼べる形 | `prov_write_test.rb`: 2 段の shell 計算（デモの 223, 553, 2）から BCO が出て、U1 のアダプタで読める。checksum を省くと等級が floating になる |
| U2 | 述語 `predicate.rb`（PinStrength を呼ぶ） | `predicate_test.rb`: 手書きの小さな正規化来歴 6 つで 6 等級が出る。fixture の等級が固定される（数値を test に書く） |
| U3 | `genomicschain_prov` に `verdict_spec/prov.rb`、`prov_submit.rb`、`schemas/prov_attestation.schema.json`、`tools/gc_prov_submit.rb`、`lib/genomicschain_prov/place_extension.rb`（`gc_prov_proof` route）。core の 4 か所（§7）と prov の core pin | `prov_submit_test.rb`: `tier2_submit_test.rb` の 14 本のうち prov に対応のある 11 本を写して通す（digest 不一致・identity 不一致・trust_tier 持込・重複回復。toolchain_ruby・tier1 content hash・applied stage の 3 本は prov に無い）。ただし DoS gate の 1 本は「2 MB 超を弾く／64 KB 超の束を通す」に書き換え、dry_run の 1 本（Tier-2 には無い）、TTL が 100 年で Tier-2 の proof は 24 時間のままの 1 本、`idempotency_key` が束ごとに違う 1 本、版ずれの拒否が三つの版を返す 1 本、`gc_prov_proof` route が prov の envelope を §7 の欄だけで返し、未知の id と Tier-2 の id に 404 を返し、`actor_user_id` を含まない 1 本、**Authorization header 無しで route が答え、同じ条件で prov の `tools/call` は拒まれる** 1 本（§0 の約束の test、round 4。unit test ではなく U4 と同じ使い捨て local anchor で回す——route と `/mcp` の順序は `HttpServer` にある、round 5）、SCM 無しの束が null の repo hash で記録される 1 本、script の checksum で workflow が immutable になる 1 本を足す |
| U4 | `gc_prov_check` と client の `--tier prov` | `submit_client_test.rb` に prov の 1 本。使い捨て local anchor で dry_run → 実提出 → 回復まで（09-09 の Tier-2 と同じ手順） |
| U5 | `gc_prov_verify` | fixture + local anchor の proof で「確かめたこと／いないこと」が出る。改竄した束で不一致が出る。§8 の表の 8 行と版違いの見出しが 1 本ずつ。`--submitter-pubkey` 無しで「自己整合」の文言、`--anchor-pubkey` 有りで anchor の行が「確かめたこと」へ移る |
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

| 版 | 日付 | 何が変わったか |
|---|---|---|
| v0.1 | 2026-09-20 | 起草。§0–§12 |
| v0.1.1 | 2026-09-20 | U0 の実測（§13）、unknowns pass（§10-1/9/10/11） |
| v0.1.2 | 2026-09-20 | review round 1（REVISE）の 5 件: §5 段ごとの環境と版の形、§13.4-3 出力の証拠による内部入力、§6 記録の契約、§6/§8 proof の寿命と検証者の言い方、§7 配置 |
| v0.1.8 | 2026-09-21 | review round 6（4 席中 3 席回答——opus4.6 は 600 秒で timeout——全員 REVISE、指摘は高度に一致）の (b): §4/§5 **object でない配列要素**も落とさず `absent` として数える（`input_subdomain` / `output_subdomain` / `prerequisite` / `software_prerequisites` / `script[]` の全部。round 5 の修正は読めない object だけを保持しており、裸の文字列や `null` は依然落ちていた）、§5 「何も名指さない」の判定を checksum と版の枝より前へ（取得先の無い digest が immutable を買っていた）、§5/§4 container の経路も参照全体が image digest のときだけ immutable（`docker://tool:latest#@sha256:…` が再現）、§5 `.x` は候補を採る前に全候補を走査（`1.x 1.0` と `1.0 1.x` が分かれた）、§4 `genomicschain_extension` は全 block を統合し同一 locator の digest 食い違いは pin 無し、§6 `scripts_total / scripts_with_checksum` を署名される欄に、§5 tag の形に registry 検査を掛けていない理由を明記（v0.1.7 の記述は実装と食い違っていた）、§7 core 変更 (1) から `gc_prov_proof` を削除（v0.1.3 の名残）、§6/§10-14 `toolchain` の二つの「署名」を書き分け、§6 の版の例を 0.3.5 に。反証 1 件: 入力の URL 判定が tier2 の規則を使い `file://` が floating に上がるという指摘は再現せず（`local_path` のまま、§13.2 の実測どおり）。code: adapter 0.3.5 / predicate 0.3.5、test 67 本 / 446 assertions 緑（新規 9 本は修正前の tree で落ちることを別 checkout で確認） |
| v0.1.7 | 2026-09-21 | review round 5 の subprocess 席（4 席中 opus5 の 1 席のみ回答。worker が SIGTERM で落ち、opus4.6 は中断、codex は空、cursor は認証切れ——L2 `review_r5_…`）の (b) 5 件: §4/§5 読めない項目を落とさず `absent` として数える（`inputs_total`・`outputs_total` は署名される分母、段の `prerequisite[]` は継承させない）、§4/§5 scheme 無しの digest つき名前は registry の形のときだけ image（`tools/awk@sha256:…` は path）、§4 SCM extension が複数なら最弱、runtime の重複削減は predicate の `runtime_grade` 自身を呼ぶ（adapter の写しを廃し `defined?` 分岐を削除）、`input_grade` の `empty locator` 分岐が生きる。code: adapter 0.3.4 / predicate 0.3.4、test 58 本 / 417 assertions 緑（新規 7 本は修正前の code で落ちることを別 checkout で確認） |
| v0.1.6 | 2026-09-21 | review round 5 の persona 3 席の (b) 3 件（script[] は全項目、v/V 始まりの拒否、印はどの語でも）と (c) の文言（§8 json の実測、submission_key の組成、§9 U3 の test 環境、OCI_TAGGED の先頭文字）。subprocess 4 席の結果は L2 `review_r5_…` に。code: adapter 0.3.3 / predicate 0.3.3 |
| v0.1.5 | 2026-09-21 | falsifier（79 件中 4 件を反駁、修正済）を含む。review round 4（REVISE、5 席全員回答）の H1–H4: H1 code（範囲の印だけの語と候補内の印で ranged、拒否語は数字始まりの候補だけ・前後に数字可、Unicode 空白、末尾の `,`、runtime の同名項目は最弱、image 参照の形を adapter でも固定、checksum は hex のみ、FormatError の cause を捨てる）、H2 §6/§7（idempotency_key = sha256(submission_key)）、H3 §4/§5/§13.4-1 + code（script の checksum で workflow が immutable）、H4 §7（extension の契約・404・rate limit 30/分・ed25519 gem・install 順）、§8（from_h、json < 2.10、429 の行、5 行目の印刷、版違いの見出しに claim と submission_key）、§9（no-Bearer の test、U5 の行数）、§10-14（読める欄の言い方、proof_id の出所）。code: adapter 0.3.2 / predicate 0.3.2、test 52 本 |
| v0.1.4 | 2026-09-21 | falsifier（169 件中 6 件を反駁、修正済）と operator の決定 §10-15 を含む。review round 3（REVISE）の 5 件: G1 §5/§4（版の規則: 拒否は語全体、候補は数字を含む語を左から、DOI は locator 全体、runtime の digest は OCI 参照だけ、段の一部宣言の逆転を明記、object でない段は拒否）、G2 §6（null 5 欄、正準化規則と outputs 規則を署名、record_version が署名欄を固定、idempotency に predicate_version、prov の core pin）、G3 §7/§10-14（`gc_prov_proof` は place extension の公開 route、返す欄の列挙、record_type の絞り、proof_id は UUID v4）、G4 §8（二つの署名の算法と bytes、確かめること 4 行追加、revoked は常に anchor-reported、5〜6 行目は照合する、prov でない記録の行、chain_tip_hash は台帳末尾の hash）、G5 §6/§13.4-1（誤り文に束の値を入れない、拡張 checksum を tool と runtime に結合、重複除去の鍵に checksum）。§10-15 を operator の決定待ちで追加。code: adapter 0.3.1 / predicate 0.3.1 |
| v0.1.3 | 2026-09-21 | falsifier（128 件中 5 件を反駁、修正済）と operator の決定 §10-14 (A) を含む。review round 2（REVISE）の 5 件: F1 §5/§13.4-1（段 = 位置、重複除去に段、継承は代替のみ、段ゼロは absent、版の規則を言葉で、locator は immutable にならない、claim は own/total）、F2 §13.4-3（uri のみ、前の段が作ったものだけ内部、上書きは外部）、F3 §6/§7（core 4 か所と TTL の経路、`pin_strength_version` = 規則の版、`outputs_digest` の規則名、seed を署名の外へ、null になりうる欄、版ずれの語彙、回復は同版のみ）、F4 §7/§8（`gc_prov_proof`、手元での署名検証、誤り符号の表、版違いの見出し、読み口の認証 §10-14）、F5 言い回し（§2 正準化の限界、§4 checksum の出所と accessor、§6 repo hash の推測余地、§8 chain_tip_hash は順序、Gate A と HTTP の上限）。code: adapter 0.3.0 / predicate 0.3.0 / tier2 0.4.1 |
