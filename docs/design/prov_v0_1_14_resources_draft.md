# 草案 r3 — Tier 2.5 設計 v0.1.14: 計算資源の欄（2026-10-14、r3 は 2026-10-16）

**r2（同日、operator の方針を受けて）:** (4) を Nextflow 専用の書き方から、道具ごとの取り込み口と共通の形に書き換えた
（Snakemake の benchmark、GNU time、汎用 file、plan）。等級の規則・記録・版は r1 のまま。

**凍結（2026-10-17、operator）。** 設計の査読は第 2 回で終えた（2 回とも P0 は 0、修正で生じた新しい P0 も 0。第 2 回の重い指摘は実装の分類と、
第 3 回の改訂で足した仕組みの中に集まった）。凍結の時点では、消す・直す・名前を正すだけを入れ、〔凍結 10-17〕と印を付けた。残りの
指摘は実装の待ち行列（L2 `handoff_tier25_v0114_v0115_implementation_20261017`）にあり、実装の査読で code に対して確かめる。

**状態:** 草案 r3（段の規則 r1 は operator が 2026-10-16 に確定）。r3 は複数 LLM の査読 第 1 回（2026-10-16、L2
`mlr_r1_tier25_v0114_v0115_t3s0_20261016`）を受けた直しで、直した箇所に〔査読 r1〕と印を付けた。r2 の後、査読の前の反証で直した箇所に〔反証 2026-10-16〕と印を付けた。operator の承認後に `prov_anchoring_design_v0_1.md` の新しい §6.2、§10 の数行、§14 の 1 行として取り込む。査読の前の 2 回目の反証で直した箇所に〔反証 r2〕と印を付けた。
凍結後の個別改訂であり、設計 review の巡ではない（v0.1.11〜13 と同じ扱い）。実装は承認の後、commit の前に複数 LLM の査読。

**r0（同日朝、KairosChain_2026 の session が書いた版）からの変更。**

| | r0 | r1 | 理由 |
|---|---|---|---|
| 等級の段 | absent < machine < requested < observed（上の段は下の段を前提） | absent < partial < steps < full（下の (2)） | nf-core の既定の trace には観測値があり要求値が無い。r0 では既定のまま補完した nf-core の束が `absent` になる |
| 等級を出す規則 | 述語（predicate）の版を上げる | 別の規則 `gc-resources-0.1` を置き、アダプタと述語の版は動かさない | 既存の 7 つの等級が「同じ手順で出た」ことを記録の上で示せる。0.3 の記録は新しい検証器でも再導出される（下の (6)） |
| GPU の記録 | 未決 | 署名欄 `gpu_models`（ベンダー・型番・枚数）と `gpus_total`。null = 探していない、`[]` = 探して無かった | operator 決定（2026-10-14、「1,3 はその方向で」） |
| 段ごとの CPU の型番 | なし | trace の `cpu_model` 列があれば段の観測値に書く | task ごとの値なので、補完器を走らせる機械との食い違いが起きない |

**operator の決定（2026-10-14、原文）:** 「再現には computer resource specs が大事です。nf-core の nextflow が失敗するのもこの
ハードウェアが計算（入力データ量に対して）規模に見合わない場合によくおきます。特に機械学習では（どのベンダーのどの）GPU が利用できるか
どうかが大きく関わります」「ただし、nextflow のように計算途中のリソース情報を出力できない場合もあるので、あれば点数が高くなる、ように
しておいて下さい」「案イで良いです」（＝全体の等級に入れない）。

---

## §6.2 v0.1.14 の追加 — 計算資源

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

### (1) 束に書くもの — `genomicschain_extension.resources`

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

### (2) 等級 — `grade_resources`（規則 `gc-resources-0.1`。全体の等級には入れない）

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

### (3) 記録に載るもの（record_version 0.4）

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
Apple や Intel の内蔵 GPU も GPU として数える（機械学習の道具が使うことがある）。

型番以外の値（CPU の型番、メモリ量、段ごとの値）は記録に載せない。束にある（§6 の「記録は同一性と数だけ」）。GPU のベンダーと型番は
platform（§6.1 (2)）と同じく、記録だけで Tier 3 が機械を振り分けられるように載せる（operator 決定）。`not_checked` は 10 項目に
なり、record_version 0.4 で固定する。

### (4) 取り込み口 — どのパイプライン道具でも、資源の情報を出せれば登録する

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
| plan に書いた値 | 顧客が書いたまま | 顧客が書いたまま | plan の段そのもの |

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

### (5) 版

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

### (6) 既存の記録・自己検査・ZK の実演との関係

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

### (7) Tier 3 との関係

route B の線（§6.1 (1)）は変えない。Tier 3 は束の資源の欄を、焼き直す機械の選択と実行前の費用の見積もり（`gc_tier3_estimate` の
`n_cores`・`ram_gb`）に使う。Tier 3 の `jobspec_digest` は資源を含まない（Tier 3 の code の事実: `JobSpec#digest` は subject_ref・env・data・pipeline だけを覆う、
`genomicschain_tier3/lib/genomicschain_tier3/execution/backend.rb` 103 行。〔反証 2026-10-16〕r2 は §6.1 を根拠に挙げたが、§6.1 は
jobspec_digest に触れていない）ので、資源の欄は Tier 3 の同一性にも
入らない。機械学習で同じ GPU でも結果が揺れること（非決定性）は資源の欄の外にあり、Tier 3 の比較の許容誤差の問題である。

---

## §10 に足す（決めていないこと）

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

## §14 改訂履歴に足す 1 行（草案）

| v0.1.14 | 2026-10-14 | **凍結後、四つ目の個別改訂。** operator の決定（計算資源の記録、案イ、GPU の型番を記録に）。束の拡張 `resources`（`machine` と段ごとの `steps[]`。取り込み口は道具ごと——Nextflow の trace、Snakemake の benchmark、GNU time、汎用 file、plan——で、等級は共通の形だけから出す）、新しい規則 `gc-resources-0.1` による `grade_resources`（absent < partial < steps < full、全段の最弱、段の無い束は多くて partial、`grade_overall` には入れない）、署名欄 9 つ（値の出どころ 3 欄を含む。GPU の型番は anchor の導出で絞る）、`not_checked` 10 項目、`record_version` 0.4。アダプタ 0.4.0 と述語 0.3.7 は変えない（7 つの等級の規則は動かず、0.3 の記録は新しい検証器でも再導出される）。検証器の再導出は、7 つの等級と資源の欄を分けて版を見る。route B の線は変えない |
