# 草案 r3 — Tier 2.5 設計 v0.1.15: 環境の置き場所から今も取れるかの観察（2026-10-16）

**凍結（2026-10-17、operator）。** 設計の査読は第 2 回で終えた（2 回とも P0 は 0、修正で生じた新しい P0 も 0。第 2 回の重い指摘は実装の分類と、
第 3 回の改訂で足した仕組みの中に集まった）。凍結の時点では、消す・直す・名前を正すだけを入れ、〔凍結 10-17〕と印を付けた。残りの
指摘は実装の待ち行列（L2 `handoff_tier25_v0114_v0115_implementation_20261017`）にあり、実装の査読で code に対して確かめる。

**状態:** 草案 r3。実装はまだ。operator の承認後に `prov_anchoring_design_v0_1.md` の新しい §6.3、§7 の行（(7) の道具と登録）、§8 の
段落（(6) の検証者の表示）、§10 の数行、§14 の 1 行として取り込む。査読の前の 2 回目の反証で直した箇所に〔反証 r2〕と印を付けた。凍結後の個別改訂であり、設計 review の巡ではない（v0.1.11〜14 と同じ扱い）。実装は v0.1.14 の後、
commit の前に複数 LLM の査読。

**版の順（operator 決定、2026-10-16）:** v0.1.14 = 計算資源、**v0.1.15 = この改訂**、v0.1.16 = ZK の秘密を守る設計。Tier 3 段階 0
（別の草案）は v0.1.14・v0.1.15 の査読が収まった後に、単独で直して査読する（operator 決定「案A」、2026-10-16）。

**改訂の経緯:**

| 版 | 変更 |
|---|---|
| r0 | 顧客の手元の道具が点検する形 |
| r1 | anchor の側を先に作る（operator 決定）。r0 の誤り「anchor が点検するには置き場所の一覧を受け取る必要がある」を直した——anchor は `gc_prov_submit` で束を 1 回の導出の間だけ memory に受け取っている |
| r2 | 査読の前の反証で 8 点を直した（再提出と回復、結果の段の名前、conda の問い合わせ先、Docker Hub の回数制限、proof_id を記録に出さない、裏づけの札、読み口と検証器、core の版） |
| r3 | 複数 LLM の査読 第 1 回（L2 `mlr_r1_tier25_v0114_v0115_t3s0_20261016`。意見を返した 5 席——MCP の集計に入った 4 席と、走り直した Fable 5.1——がすべて REVISE、P0 なし）を受けて三つの組を直した。**FG1 外向きの問い合わせの守り**（(5) を一つの関門に書き直し、git を子 process で呼ばない、問い合わせは署名の確認の後だけ、予算と上限）、**FG2 数え方と言葉**（数える単位を二つ、結果の段に `access_denied` と `not_attempted`、答えた相手の種類、表示の規則、顧客への項目ごとの結果）、**FG3 記録の土台**（寿命、claim、idempotency、core の版の表、札の語彙をこの改訂に移す）。直した箇所に〔査読 r1〕と印を付けた |

**operator の言葉（2026-10-16、原文）:**
「できれば、Tier2.5にはTier3の再現計算のための計算環境構築のメタデータのattestationとチェックも担わせたいのですが、それも可能ですか？」
「A -> Bの計算環境を再構築できる、というメタデータがあるかどうか、zk proofとは別にチェックすることは可能だと思いますか？
この情報があるとTier3の実行可能性（再現できるかどうかは別として）が高まると思うのです。」
「はいその方向で設計に足して下さい。」
「v0.1.15でTier2.5の取得可能かどうかの修正、v0.1.16でzkの秘密を守る設計、にしましょう。」「anchorを先に作るでいきましょう。」

## 人向けの要約

```
製薬会社の計算 A → B の、環境を組み直す材料について
  ① 書いてあるか、どれだけ固いか      今の Tier 2.5 の等級（§5）。変えない
  ② 書いてある場所から、今も取れるか  ← v0.1.15。anchor が問い合わせ、日付つきの観察として別の記録に残す
  ③ 実際に組み立てられるか            Tier 3 との境界。この改訂の外（§10）

Tier 2.5 の記録（変えない）  ◀── 重ねる ──  到達の観察の記録 prov_reachability（新規）
                                             例: container の置き場所 8 種類のうち
                                                 6 種類 = 相手が同じ指紋で存在すると答えた（うち公開の registry 6）
                                                 1 種類 = 存在するとだけ答えた（tag で名指し）
                                                 1 種類 = 匿名では読めないと答えた
                                             どれがどれかは記録に載せない（提出した顧客にだけ、その応答で返す）
```

- 例: 束に `star@sha256:…` と書いてあれば等級は immutable。しかし registry（container image の置き場）から消されていれば、
  Tier 3 は取ってこられない。②はこれを、GenomicsChain の位置から、その日に見る。
- anchor は中身を取り寄せない。「存在する」「同じ指紋で答えた」は置き場所の側の答えであって、anchor が中身を確かめたのではない。
  答えた相手が顧客自身の server でありうることも、記録は隠さない（(4) の相手の種類）。
- 等級には混ぜない。等級は「同じ束からは、いつ計算しても同じ答え」で、届くかどうかは日によって変わる。

---

## §6.3 v0.1.15 の追加 — 環境の置き場所から今も取れるかの観察

### (1) なぜ等級にも prov の記録にも入れず、別の記録にするか

| 判断 | 理由 |
|---|---|
| 等級に入れない | §5 の規則は決定的（同じ束から同じ等級）。届くかどうかは時刻・registry の方針で変わる。混ぜると §8 の検証者の再導出が「不一致」を出しうる |
| prov の記録に入れない | prov の記録は一時点の言明で、同じ束・同じ鍵の再提出は既存の proof の回復になる（§6 の submission_key）。観察は何度も見直すもので、回復の仕組みと合わない。入れれば record_version も上がり、v0.1.14 の 0.4、v0.1.16 の ZK と版を取り合う |
| 別の記録として重ねる | prov の記録・アダプタ・述語・資源の規則・ZK の検証はどれも変わらない |

### (2) 範囲と数える単位

対象は `NormalizedProvenance` の環境の置き場所: `containers`、`software`（containers 以外。アダプタでは containers は software の一部なので、
この分類の項目の数は `software_total − containers_total`〔反証 r2〕）、`workflow` の repository と commit、`runtime`。
**入力（データ）は対象外**（§10）。

**数える単位を二つ持つ〔査読 r1〕。** nf-core の束では段が task なので、container の項目は段ごとに並ぶ。査読者の見積もりでは、10 試料の
rnaseq で数百〜数千項目が 50 前後の image を指す（未計測〔反証 r2〕）。そこで:

- **問い合わせは、置き場所の文字列が同じものを一度だけ**行う（`distinct`）。
- 記録には分類ごとに **項目の数**（`items`、prov の記録の `containers_total` などと同じ数え方）と **異なる置き場所の数**（`distinct`）の
  両方を載せ、結果の段ごとの数は `distinct` で数える。項目の結果は、その置き場所の結果をそのまま受け継ぐ。
- 問い合わせる順は決定的にする: 分類の順（containers → software → workflow_repository → workflow_commit → runtime）、分類の中は
  置き場所の文字列の辞書順。

### (3) 提出の流れ

```
顧客                                                anchor（SubmitCore の順に）
gc_submit_client --tier prov-reach
  束（verbatim）と提出ごとの nonce に署名し、
  prov の proof_id は署名の外の引数で送る ────────▶ gc_prov_reach（SubmitCore の順〔反証 r2: r3 の初稿の図は順が違った〕）
                                                       ① 入口: 束の digest・Gate A（2 MB、深さ 32）・アダプタによる導出（置き場所を
                                                          取り出す。ネットワークにも台帳にも触れない。prov の今の型と同じ）・署名された
                                                          同一性と束の一致
                                                       ② Bearer の照合
                                                       ③ 回復の確認（同じ署名の再送はここで既存の記録が返る）
                                                       ④ 署名の確認
                                                       ⑤ server が決める欄: prov の記録を proof_id で引き、bundle_digest と
                                                          prov_proof_ref の一致を確かめ、問い合わせる（(5) の関門と予算の内側で）
                                                       ⑥ 記録を発行する。束と置き場所は捨てる
  ◀── proof_id、数、項目ごとの結果（応答だけ） ────
```

**問い合わせは署名の確認の後だけ〔査読 r1〕。** 今の SubmitCore は、入口の検査（`apply_gates!`）→ Bearer の照合 → 回復の確認 → 署名の確認
（`verify_admission!`）→ server が決める欄（`server_set_fields`）→ 記録、の順に進む（`submit_core.rb` の `submit`）。⑤ は
`server_set_fields` の中で行い、`apply_gates!` では行わない（prov は ZK の検証を `apply_gates!` で行っているが、その型を真似ない）。
台帳を引くのも ⑤ で行う（署名を確かめる前の呼び出しに、proof_id があるかどうかを答えない）。したがって、署名の無い呼び出し、Bearer の
違う呼び出し、同じ署名の再送は、外へ一つも問い合わせず、prov の記録を proof_id で引かない。〔凍結 10-17〕回復の確認は submission_key で
既存の記録を探す台帳の照合で、署名を確かめる前に行われる（今の core の動き）。r3 の「台帳も引かない」は誤り。**dry_run は問い合わせない**: 分類ごとの `items` と `distinct`
と、名前を引かずに決められる拒否の数（scheme、userinfo、port、IP の直書き、扱わない種類）だけを返す。名前を引く判定（(5) の関門の
3・4）は dry_run では行わない〔反証 r2: r3 の初稿は「(5) で拒まれる数」を返すと書き、名前を引かずには決められなかった〕。

拒否するのは形の誤りだけ: prov の記録が台帳に無い、`bundle_digest` が一致しない、`prov_proof_ref` が一致しない、署名が通らない、束が
入口の上限を超える、(5) の予算を超えた提出。**数の中身では拒否しない**（v0.1.13 の「どの等級でも発行する」と同じ考え方）。

**再提出は新しい観察にする。** client が提出ごとに作る 32 bytes の乱数を、署名される同一性の欄 `observation_nonce` に入れる。core の
SubmitCore は `submission_key`（digest の主語・署名される同一性・公開鍵）で既存の proof を探して回復を返すので（`submit_core.rb` 50–62 行）、
nonce が同一性に入っていれば別の key になる。claim と idempotency key は (7)。

**顧客への項目ごとの結果〔査読 r1〕。** 数だけでは、顧客は「どれが取れなかったか」が分からず、Tier 3 の準備に使えない。そこで応答にだけ、
束の中の位置（分類と、その分類での項目の番号）ごとの結果の段を返す。置き場所の文字列は返さない（顧客は束を持っているので位置で足りる）。
この項目ごとの結果は記録にも log にも書かない。返す相手は署名を確かめた提出者だけなので、提出者が既に持っている束の情報より多くを
渡すことはない。

### (4) 結果の段と、答えた相手の種類

**結果の段（異なる置き場所ごと）〔査読 r1 で 7 段に〕:**

```
digest_match    置き場所が中身の指紋で名指され、相手が同じ指紋で存在を答えた。相手の答えであり、anchor は中身を取り寄せていない
exists          存在の答えが返ったが、名指しが中身の指紋ではない（tag、版の名前、git の ref の名前）
access_denied   相手は答えたが、匿名では読めないと言った（401・403）。私設のものも、存在しないものもここに入る
                （Docker Hub は存在しない repository にも匿名には 401 を返す）。「消えた」とも「ある」とも読まない
not_found       存在しないと答えが返った（404、版が無い）
error           答えが得られなかった（時間切れ、429、TLS の失敗、相手の一時的な失敗）。「消えた」とは読まない
not_attempted   anchor 自身の予算や遮断で問い合わせなかった（(5) の上限、同じ host の連続失敗で止めた）。相手の状態について何も言わない
not_checkable   点検の方法が無い、または (5) の関門で拒んだ（local_path、absent、扱わない scheme、置き場所が無い、userinfo つき、
                443 以外の port、名前が引けない、公開でない宛先）
```

〔査読 r1〕「関門で拒んだ」と「名前が引けない」を同じ `not_checkable` にまとめるのは、二つを分けると、anchor の内側の DNS でどの名前が
引けるかを外から探れてしまうため。顧客には (3) の項目ごとの結果で同じ `not_checkable` が返る。

| 置き場所の種類 | 問い合わせ（中身は取り寄せない） | 最良の結果 |
|---|---|---|
| OCI image、digest で名指し（`…@sha256:…`） | registry の manifest に HEAD（`/v2/<name>/manifests/<digest>`、Accept に OCI と Docker の manifest と index の型）。401 の `WWW-Authenticate: Bearer realm=…` には匿名の token を一度だけ取りに行く（realm の URL も (5) の関門を通す）。応答の `Docker-Content-Digest` が名指しの digest と同じ | digest_match |
| OCI image、tag で名指し | 同じ HEAD を tag で | exists |
| git の repository | **子 process を使わない**〔査読 r1〕。smart HTTP の ref の広告（`GET <repo>/info/refs?service=git-upload-pack`）を、(5) の関門を通した同じ接続で、8 MB まで流しながら読む。
超えたら `not_attempted`（anchor の上限）〔反証 r2: 広告は `refs/pull/*` を含み、nf-core/modules で 660,232 bytes、bioconda-recipes で
4,677,728 bytes。1 MB では足りない〕 | exists |
| git の commit（hash） | 上の ref の広告に、その hash を先端に持つ ref があれば digest_match。無ければ not_checkable（先端でない commit は、object を取り寄せないと確かめられない）〔査読 r1: r2 は ls-remote で digest_match を出すと書いたが、ls-remote は ref の名前で照合し、先端しか見えない〕 | digest_match か not_checkable |
| git の commit（hash でない名前） | ref の広告にその名前があれば exists | exists |
| conda の package | **完全な指定だけ**〔査読 r1〕: `channel::name==version`（`==`）で、channel が明示され `defaults` でなく、version に `*`・範囲・比較の印が無いもの。〔反証 r2〕`=` 一つは conda では前方一致（`=1.17` は `1.17.*`）なので not_checkable。`==` でも build は固定されないので結果は exists まで。版ごとの API `https://api.anaconda.org/release/<channel>/<name>/<version>`（200 か 404）。channel・name・version は `[A-Za-z0-9._+-]` だけ（path を組み立てるので）。それ以外は not_checkable。今の書き出し器は conda の置き場所を書かない（Nextflow の補完器は image を道具の uri に書く）ので、当面は数が 0 になりうる | exists |
| https の URL（道具の配布物など） | HEAD（拒まれたら Range 0-0 の GET を送り、header を受け取ったら本文を読まずに接続を閉じる） | exists |
| local_path、absent、未対応の scheme、置き場所の無い項目 | 問い合わせない | not_checkable |

**答えた相手の種類〔査読 r1〕。** 置き場所は顧客が書くので、顧客が自分の registry を指し、どんな digest にも「ある」と答えさせることが
できる。記録だけを読む第三者には、それが公開の registry の答えか顧客の server の答えかが見えない。そこで `digest_match` と `exists` を、
答えた host の種類で分けて数える:

- `public_registry` — 規則 `gc-reachability-0.1` に固定した一覧の host: `registry-1.docker.io`（`docker.io`）、`quay.io`、`ghcr.io`、
  `public.ecr.aws`、`mcr.microsoft.com`、`registry.gitlab.com`、`community.wave.seqera.io`、`github.com`、`gitlab.com`、`bitbucket.org`、
  `codeberg.org`、`api.anaconda.org`。〔反証 r2〕`community.wave.seqera.io` を足した——repository の nf-core の fixture は image 4 つのうち 2 つが
  ここにある。
  一覧を変えるときは規則の版を上げる。
- `other_host` — それ以外（私設の registry、顧客の server、大学の server）。

一覧は operator が見直せる既定であって、品質の判定ではない（`other_host` は「悪い」ではなく「答えた相手の素性を記録が言えない」）。

### (5) anchor を守る関門と予算（anchor が顧客の書いた宛先に問い合わせるため）〔査読 r1 で書き直し〕

**一つの関門 `gate(url)` を、置き場所、`WWW-Authenticate` の realm の URL、すべての redirect 先に、同じように通す。**

```
gate(url):
  1. scheme は https だけ。userinfo（user:pass@）があれば拒む。port は 443 だけ
  2. host が anchor 自身の名前・自身の公開 IP なら拒む
  3. 名前を引き、A と AAAA の答えをすべて取る。一つでも下の 4 に落ちれば拒む
  4. 埋め込まれた IPv4 を取り出してから判定する（IPv4-mapped ::ffff:0:0/96、IPv4-compatible、NAT64 64:ff9b::/96——IANA は
     Globally Reachable を True とする——、6to4 2002::/16——同じく N/A）。Teredo 2001::/32（N/A）と 64:ff9b:1::/48（False、埋め込みの
     位置が決まらない）は取り出さずに拒む〔反証 r2〕。IANA の IPv4・IPv6 Special-Purpose Address Registry で Globally Reachable が
     True でない範囲と、multicast の範囲（multicast の registry にある）はすべて拒む（例: 0.0.0.0/8、10/8、100.64/10、127/8、
     169.254/16、172.16/12、192.0.0/24、192.0.2/24、192.168/16、198.18/15、198.51.100/24、203.0.113/24、224/4（multicast）、240/4、
     ::/128、::1、100::/64、2001:2::/48、2001:db8::/32、3fff::/20、5f00::/16、fc00::/7、fe80::/10、ff00::/8（multicast））。
     一覧は実装の時点で IANA の CSV から作り、その日付を規則の版と一緒に残す。
     言語の便利な判定（Ruby の `IPAddr#private?` など）に頼らない——0.0.0.0、100.64/10、NAT64 を通してしまう（査読 r1 で Ruby 3.4.10 にて確認）
  5. 確かめた IP に接続を固定し、TLS は SNI に元の host 名を送り、証明書をその host 名で検証する（VERIFY_PEER）。検証を切らない
  6. proxy を使わない（環境変数の proxy も読まない。proxy が名前を引くと固定が無効になる。Ruby の Net::HTTP は既定で環境変数の
     `http_proxy` を読むので、proxy の引数を明示して無効にする〔反証 r2〕）
```

redirect は 3 回まで、毎回 `gate` を通す。realm の URL も `gate` を通し、redirect と同じ回数と時間の予算に数える。

**時間と大きさ:**

- 1 問い合わせは**壁時計で 10 秒**（接続・TLS・header まで含めた期限。読み取りごとの待ち時間ではない）。1 観察の合計は 60 秒。
- header は 64 KiB まで。JSON（token、conda の API）は 1 MB まで、git の ref の広告は 8 MB まで、**伸長した後の bytes で数える**
  （`Accept-Encoding: identity` を送り、圧縮で返ってきても伸長しながら数える）。JSON の超過は error、広告の超過は `not_attempted`。
- HEAD で足りないときの Range GET は、header を受け取ったら本文を読まずに閉じる（Range を無視して全体を返す server がある）。

**予算（共有の IP と worker を守る）:**

- 1 観察で問い合わせる異なる置き場所は 200 まで。超えた分は `not_attempted`。
- 同じ host への問い合わせは 1 観察で、`public_registry` の host なら 100 まで、それ以外の host なら 20 まで、同時に 2 本まで
  〔反証 r2: nf-core の image は quay.io などに集まるので、一律 20 では大半が `not_attempted` になる〕。同じ host で時間切れか 5xx が 3 回続いたら、その host の残りは
  `not_attempted`（遮断）。
- anchor 全体で同時に進む観察は 2 つまで。同じ鍵からは同時に 1 つ、1 日に 24 観察まで。超えた提出は拒む（形の誤りと同じ扱い。
  記録は作らない）。

**漏らさない:**

- 置き場所の文字列・解決した IP・応答を disk にも log にも書かない。結果の cache は持たない。
- 問い合わせの層の境界で例外をすべて受け止め、決まった符号（`timeout`、`tls`、`dns`、`refused`、`http_<code>`、`too_large`）だけを
  持つ型の例外に置き換える。ライブラリの message（host 名や URL を含む）は捨てる。子 process は使わない（argv や stderr に置き場所が
  出ない）。
- **配備条件:** anchor の名前解決は query log を残さない resolver を使う。cloud の flow log や SNI を記録する egress の proxy を置くなら、
  置き場所の host 名がそこに残ることを受け入れたと §10 に書く。

問い合わせそのものは、宛先の持ち主に「GenomicsChain の IP からこの置き場所が引かれた」ことを知らせる。これは避けられない。

### (6) 記録 — `prov_reachability`（record_version 0.1）

**顧客が署名する欄（署名される同一性）:**

```
subject_ref               "prov-reach:<bundle_digest>"
prov_proof_ref            sha256(prov の記録の proof_id)
bundle_digest             点検した束（anchor が計算し直す）
reachability_rule         gc-reachability-0.1（(4) の結果の段と host の一覧、(5) の関門と予算を含む）
scope                     "environment"
observation_nonce         提出ごとの 32 bytes の乱数（hex）
```

prov の記録の proof_id そのものは署名の外の引数で渡し、記録には載せない〔査読 r1: r2 の (3) は「proof_id に署名する」と書き、(6) と
食い違っていた〕。base の §10-14 で proof_id は prov の記録を読む鍵なので、観察の記録を読める者に渡さない。両方の proof_id を持つ
検証者は、`prov_proof_ref` で二つの記録のつながりを確かめられる。

**anchor が決める欄（anchor の proof の署名で守られる）:**

```
observer                  "anchor"（顧客側の観察は (9) で "customer"）
observed_at               anchor が問い合わせを終えた時刻（UTC）
checker                   {gc_prov_reach の版, アダプタの版}
same_signer               prov の記録と同じ鍵か
counts                    分類（containers, software, workflow_repository, workflow_commit, runtime）ごとに
                          items: 項目の数
                          distinct: 異なる置き場所の数、と結果の段ごとの数
                            {digest_match: {public_registry, other_host}, exists: {public_registry, other_host},
                             access_denied, not_found, error, not_attempted, not_checkable}
backing                   gc-backing-0.1 の札（下）: counts は anchor_observed、prov の記録との照合は procedure_checked
not_checked               5 項目（下）
```

**札の語彙 `gc-backing-0.1` はこの改訂で定める**〔査読 r1: r2 では未承認の Tier 3 段階 0 の草案にだけ定義があった〕。base 設計の §6.3 に
置き、Tier 3 段階 0 はここを引く。core に定数として置く（二つの package が使うため）。

| 札 | 意味 |
|---|---|
| `procedure_checked` | GenomicsChain の手順が、記録や提出された材料から導き直した |
| `anchor_observed` | GenomicsChain の anchor が自分の位置から観察した。導き直せない、日付つきの観察 |
| `customer_signed` | 宣言した鍵で署名された申告が存在する（誰が言ったか） |
| `customer_stated` | 申告の中身（何を言ったか） |
| `not_checked` | 誰も確かめていない |
| `platform_audit_log`・`hardware_attested` | 予約（Tier 3 の段階 1・2） |

**`not_checked`（record_version 0.1 で固定）:** `reachability_from_other_networks`（anchor の位置から見た結果）、`content_not_fetched`
（中身は取り寄せていない。digest_match も相手の答え）、`answerer_independence`（`other_host` の答えは、束を書いた本人の server のもの
でありうる）〔査読 r1〕、`buildability`（組み立ててはいない、③）、`future_reachability`（将来も取れることは言わない）。

**記録に載せないもの:** 置き場所の文字列、解決した digest や IP、応答、host 名、prov の記録の proof_id、項目ごとの結果。prov の記録の
`not_checked: locator_reachability` はそのまま残す（prov の記録自身は点検していない）。

**検証者の表示〔査読 r1〕:** 分類をまたいだ合計や、`digest_match` と `exists` を足した数は**出さない**。結果の段ごとに一行ずつ、段の意味を
添えて出す。`observer`、`same_signer`、`observed_at` と観察からの日数を必ず出す。次の文を置く:
> この観察は、GenomicsChain の anchor が、記録の日時に、自分のネットワークの位置から問い合わせた結果です。中身を取り寄せては
> おらず、「同じ指紋で存在する」も置き場所の側の答えです。公開の registry 以外の答えは、束を書いた本人の server のものでありえます。
> 組み立てられることも、将来も取れることも示しません。

### (7) 記録の土台 — 寿命、claim、idempotency、読み口〔査読 r1〕

| 何 | 決め | 理由 |
|---|---|---|
| 寿命 | `proof_ttl` = 3,153,600,000 秒（100 年、prov と同じ） | 指定しないと Synoptis の既定 86,400 秒で、観察は翌日に `expired` と読まれる（記憶 `synoptis-proof-ttl-hazard`）。観察の新しさは `observed_at` で読み、寿命では読まない |
| claim | `prov-reach:<reachability_rule>:<bundle_digest>:<submission_key>` | Synoptis は (attester, subject_ref, claim) が同じ proof を二度作らず、core は既存の proof_id を返す。数が同じ二つの観察が一つにまとめられないよう、提出ごとに変わる submission_key で終える。〔凍結 10-17〕r3 の「`existing` が返ったら失敗として扱う」は消した——spec の hook は store の状態を受け取らず（`submit_core.rb` 92–109 行）、claim が提出ごとに変わるので、この型では `existing` に届かない |
| idempotency key | `sha256(submission_key)` | core の分岐（`submit_core.rb` 240 行、今は `prov_attestation` だけ）を、**新しい型を列挙する一覧**にする（初めは `prov_attestation` と `prov_reachability`）。既定の枝（Tier 1〜4）は一文字も変えない |
| 読み口 | 公開の読み口（`place_extension.rb` 73 行、今は `prov_attestation` だけ）と `Verifier#unreadable_reason` に `prov_reachability` を足す | |
| 登録 | `genomicschain_prov/skillset.json` の `anchor_profile_tool_classes` に `gc_prov_reach`、client の `scripts/gc_submit_client.rb` に `--tier prov-reach` | 今の client は tier1・tier2・prov だけを知る |
| prov_proof_ref | core の小さな関数一つ（`sha256(proof_id)`）。Tier 3 段階 0 も同じ関数を使う | 同じ prov の記録を二つの草案が別の形で指さないように |

### (8) Tier 3 との関係

- route B の線（§6.1 (1)）は変えない。v0.1.15 では観察を Tier 3 の関門にしない。
- `gc_tier3_estimate` は観察の `proof_id` を渡されたら、観察の日付、`not_found`・`access_denied`・`error`・`not_attempted` の数を
  見積もりの横に出す。GenomicsChain の側で走らせる Tier 3 では、`access_denied` の置き場所は取れない。

### (9) 後で足すもの — 顧客側の観察（`observer: "customer"`）

顧客の手元の道具（仮称 `gc_prov_reach_local`、網なしの `gc_prov_check` とは別）が同じ表で問い合わせ、数を署名して出す。札は
`customer_stated`。顧客の認証でだけ届く私設の registry と、Tier 3 段階 0 のために要る。記録の形は (6) と同じ。この改訂では作らない。

### (10) 既にあるものとの関係

| 既にあるもの | 影響 | 根拠 |
|---|---|---|
| prov の記録（0.3、v0.1.14 の 0.4） | 無し | 別の記録として重ねる |
| アダプタ・述語・資源の規則・ZK の検証・`gc_prov_check` | 無し | 読むだけ、または触れない |
| core の SubmitCore | **変える**: idempotency key の分岐を新しい型の一覧に、札の語彙と `prov_proof_ref` の関数を足す | (7) |
| 公開の読み口・検証器・client | **変える** | (7) |
| 第 2 回の自己検査・ZK の実演・論文 | やり直し不要 | 論文の Tier 2.5 の記述は `8091516` に固定され、この観察を述べていない |

**受け入れの test:**

- (i) prov と core の既存の test がすべて緑。(ii) prov の記録の schema に差分が無い。
- (iii) `gate` の test はネットワークに出ない（HTTP・DNS を差し替える）。次の宛先がすべて拒まれる: `0.0.0.0`、`127.0.0.1`、
  `100.100.100.200`、`169.254.169.254`、`[::ffff:169.254.169.254]`、`[64:ff9b::a9fe:a9fe]`、`[2002:a9fe:a9fe::]`、`[::1]`、`[fd00::1]`、
  `10.0.0.1`、`198.18.0.1`、anchor 自身の名前、`https://user:pw@host/`、`https://host:6379/`。A は公開・AAAA は私設、の名前も拒まれる。
  realm の URL と redirect 先に私設の宛先を返す registry の差し替えで、二度目の問い合わせが起きない。
- (iv) 7 つの結果の段と、host の種類、予算（200、host ごと public_registry 100・それ以外 20〔凍結 10-17〕、遮断、同時実行）がすべて出る。
- (v) 署名の無い呼び出し・Bearer の違う呼び出し・dry_run・同じ署名の再送で、外への問い合わせが 0 回。
- (vi) 束・置き場所・prov の proof_id・ライブラリの例外の message（host 名を含む差し替え）が log に現れない。
- (vii) 同じ束・同じ鍵の 2 回の提出が 2 つの記録になり、counts が同じでも別の proof_id になる。
- (viii) **idempotency key の非退行**: core を変える**前に**、Tier 1・2・3・4 と prov の記録について、新しい提出と回復の両方の道で
  idempotency key を fixture に取っておき、変えた後も同じであることを確かめる（今の test で値を固定しているのは prov だけ。Tier 2 は
  「違う」ことしか確かめていない〔反証 r2〕）。
- (ix) 24 時間を過ぎた観察の記録が `expired` と読まれない。

### (11) 版 — core の版の表（三つの草案で共有する）〔査読 r1〕

| core の版 | 中身 | どの改訂が運ぶか |
|---|---|---|
| 0.6.1 | 束の拡張の schema に `resources` | v0.1.14 |
| 0.6.2 | idempotency key の分岐を新しい型の一覧に（`prov_reachability`）、札の語彙 `gc-backing-0.1` の定数、`prov_proof_ref` の関数 | v0.1.15 |
| 0.6.3 | 一覧に Tier 3 段階 0 の型を足す（宣言・番号札・申告） | Tier 3 段階 0 |

順番が入れ替わったときは、先に出す改訂が共有の変更を運び、表を書き直す。prov の package は v0.1.14 で 0.4.0、v0.1.15 で 0.5.0。
新しい規則 `gc-reachability-0.1`、新しい記録 `prov_reachability` 0.1、道具 `gc_prov_reach` と client の `--tier prov-reach`。

### (12) 実装の順番（完了できる単位）

1. R0 — idempotency key の fixture を取る（(10) の (viii)、core を変える前に）。
2. R1 — `gate`、結果の段、予算、例外の符号化（ネットワークに出ない。差し替えた HTTP・DNS で test）。
3. R2 — 問い合わせ: OCI と git の ref の広告から（Tier 3 の実行に直接効く）。次に https、conda。
4. R3 — core 0.6.2、記録の schema、verdict spec、`gc_prov_reach`、client、使い捨ての手元 anchor で端から端まで。
5. R4 — 公開の読み口、`gc_prov_verify` の表示、`gc_tier3_estimate` の表示。

## §10 に足す（決めていないこと）

- 観察を Tier 3 の関門にするか、するなら線をどこに引くか（日付の新しさ、`not_found` と `access_denied` の数）。
- 先端でない git の commit を確かめるか（smart HTTP の fetch で `want <commit>` を送り、packfile の前で止める。未検証）。GitHub の API を
  使うなら匿名の上限は IP ごとに 1 時間 60 回で、anchor では全顧客が共有する。token を anchor に持たせるかは operator の判断。
- quay.io・ghcr.io での振る舞いは 2 回目の反証で一部確かめた〔反証 r2〕: 存在しない repository に quay.io は token があっても 401、
  ghcr.io は 403、どちらも存在する image の HEAD は `Docker-Content-Digest` を返す。index と manifest の型の Accept は未確認。
- HPC で多い Singularity / Apptainer の image〔査読 r1、反証 r2 で直した〕: 補完器は `docker run` / `podman run` の行から image を読み
  （`nextflow_run.rb` 109 行）、無ければ trace の `container` 列に戻る（`image_by_step` 346–361 行 → `trace_image` 372–378 行）。既定の
  trace には `container` 列が無いので、手順書で `trace.fields` に `container` を加えるよう勧める。Singularity の container の文字列が
  `docker://…` でなく file の path なら、置き場所は local_path になる。
- `public_registry` の一覧の見直し。
- 入力（データ）の置き場所を対象にするか。
- ③ 実際に組み立てられるか。Tier 3 段階 0 の準備との境界。
- 顧客側の観察 (9) を作る時期。
- 本番の anchor で Synoptis の `attestation_list`（subject_ref で絞れる）が顧客の Bearer から呼べるかを確かめる。呼べるなら、
  `bundle_digest` を知る者が prov の記録を引けることになる（v0.1.15 が新しく作る問題ではないが、観察の記録も `bundle_digest` を載せる）。
- 配備条件（(5) の resolver の query log、flow log、egress の SNI）の受け入れ。
- 参照ゲノムの特定と乱数の種（prov の `not_checked` の残り）は、この改訂の外。

## §14 改訂履歴に足す 1 行（草案）

| v0.1.15 | 2026-10-16 | **凍結後、五つ目の個別改訂。** operator の決定（Tier 3 の実行可能性のため、環境の置き場所から今も取れるかを ZK とは別に点検する。anchor の側を先に作る。版の順は v0.1.14 資源 → v0.1.15 この改訂 → v0.1.16 ZK の秘密）。新しい §6.3。anchor 側の道具 `gc_prov_reach`（束を verbatim で受け、memory でだけ持ち、署名の確認の後に、環境の置き場所——containers・software・git の repository と commit・runtime——に中身を取り寄せずに問い合わせる。git は子 process を使わず smart HTTP の ref の広告で）、異なる置き場所を一度だけ問い合わせ、項目と異なる置き場所の二つの単位で数える。結果 7 段（digest_match / exists / access_denied / not_found / error / not_attempted / not_checkable）、答えた host の種類（public_registry / other_host）。一つの関門 `gate`（https・443 だけ、userinfo を拒む、すべての A/AAAA を IANA の特別用途の範囲で判定、埋め込みの IPv4 を取り出す、IP を固定し SNI と証明書の検証を保つ、proxy なし。置き場所・realm・redirect に同じく通す）、壁時計の期限と伸長後の大きさの上限、host ごと・鍵ごと・全体の予算、例外の符号化、子 process なし。新しい記録 `prov_reachability` 0.1（prov の記録の上に重ね、分類ごとの数と日時だけ。prov の proof_id は SHA-256 だけ。数の中身では拒否しない。署名される nonce で再提出を新しい観察にする。claim は submission_key で終える。寿命 100 年）、規則 `gc-reachability-0.1`、`not_checked` 5 項目、札の語彙 `gc-backing-0.1` をここで定める。core 0.6.2（idempotency key を新しい型の一覧で、札の定数、prov_proof_ref の関数）、公開の読み口と検証器と client に新しい型を足す。prov の記録・アダプタ・述語・資源の規則・ZK の検証・route B の線は変えない。顧客側の観察（`observer: customer`）は同じ形で後から |
