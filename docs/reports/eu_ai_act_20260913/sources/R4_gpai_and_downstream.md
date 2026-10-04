# R4 — 汎用 AI モデル（GPAI）の規律と、その上に作る側の立場

**調査日**: 2026-09-13
**調査範囲**: EU AI Act (Regulation (EU) 2024/1689) 第 V 章、および他社の大規模言語モデルを API 経由で呼んでサービスを作る小規模チームに何がかかるか。
**出典種別の記号**: `[条文]` = 法令本文 / `[公式ガイダンス]` = 欧州委員会・AI Office の公式文書 / `[二次解説]` = 法律事務所・解説サイト

> **この文書を使う人への注意（重要）**
> 依頼書では「3(68) = systemic risk」とされていたが、**これは誤り**である。Article 3(68) は
> `downstream provider` であり、`systemic risk` は **Article 3(65)** である。下の § 1 に
> 実際の番号どおりに記録した。

---

## 0. 要点先出し — 「API を呼ぶだけで GPAI provider になるか」

**ならない。** 欧州委員会のガイドライン第 57 項が、上流と下流の役割を明示的に分けている。

- (a) 出典: Commission Guidelines on the scope of the obligations for providers of general-purpose AI models, para (57)
- (b) URL: https://ai-act-service-desk.ec.europa.eu/sites/default/files/2025-07/guidelines_on_the_scope_of_the_obligations_for_generalpurpose_ai_models_established_by_regulation_1cx2atxgq79us4n3x8jfgyy1qlm_118340-3.pdf
- (c) 原文:
  > "when an upstream actor develops or has developed a general-purpose AI model and makes the model available for the first time to a downstream actor on the Union market, the model should be considered to have been placed on the market and the upstream actor to be the provider of the model. The upstream actor therefore has to comply with the obligations for providers of general-purpose AI models. **The downstream actor integrating the model into an AI system and placing the system on the Union market or putting it into service in the Union may be the provider of the system.** In this case the downstream actor has to comply with the applicable requirements and obligations for AI systems laid down in the AI Act."
- (d) 種別: `[公式ガイダンス]`

**日本語で**: 上流（Anthropic / OpenAI）がモデルを EU 市場に初めて出した時点で、上流が「モデルの
provider」になる。そのモデルを組み込んで AI システムを EU 市場に出す下流の事業者は、「**システムの**
provider」であって「**モデルの** provider」ではない。したがって第 V 章（Art. 53–55）の義務は下流には
かからない。下流にかかるのは AI *システム* 側の規律（該当すれば第 III 章の高リスク規律、および
Art. 50 の透明性義務）である。

さらに、API 経由でモデルを提供する行為そのものが「上流による placing on the market」として
列挙されている（ガイドライン第 53 項、下の § 5.4 に引用）。つまり API は**モデルを出す側の**
販売経路であって、呼ぶ側の製造行為ではない。

例外は一つだけ: **モデルを大幅に改変した場合**（§ 5.1 の 1/3 compute 基準）。

---

## 1. 定義 — Article 3

出典 URL（以下 § 1 共通）: https://artificialintelligenceact.eu/article/3/ 　種別: `[条文]`
（原典は https://eur-lex.europa.eu/eli/reg/2024/1689/oj/eng — EUR-Lex の全文 HTML は容量が大きく
自動取得で Article 3 まで到達できなかったため、条文ミラーから取得した。文言は同一。）

### Article 3(1) — `AI system`

> "a machine-based system that is designed to operate with varying levels of autonomy and that may exhibit adaptiveness after deployment, and that, for explicit or implicit objectives, infers, from the input it receives, how to generate outputs such as predictions, content, recommendations, or decisions that can influence physical or virtual environments"

**日本語**: 機械ベースのシステムで、さまざまな度合いの自律性をもって動くように設計され、配備後に
適応性を示すこともあり、明示または黙示の目的のために、受け取った入力から、物理的または仮想的な
環境に影響を与えうる予測・コンテンツ・推奨・決定といった出力をどう生成するかを推論するもの。

### Article 3(3) — `provider`

> "a natural or legal person, public authority, agency or other body that develops an AI system or a general-purpose AI model or that has an AI system or a general-purpose AI model developed and places it on the market or puts the AI system into service under its own name or trademark, whether for payment or free of charge"

**日本語**: AI システムまたは GPAI モデルを自ら開発する、あるいは開発させたうえで、自分の名称または
商標のもとに市場に出す（システムの場合は使用に供する）自然人・法人・公的機関等。有償無償を問わない。

**注**: provider は「システムの provider」と「モデルの provider」の両方を一つの定義でカバーしている。
どちらの provider なのかで、かかる義務がまったく違う。これが R4 の中心的な分岐点。

### Article 3(4) — `deployer`

> "a natural or legal person, public authority, agency or other body using an AI system under its authority except where the AI system is used in the course of a personal non-professional activity"

**日本語**: 自らの権限のもとで AI システムを使う者。ただし個人的・非職業的な利用は除く。

### Article 3(63) — `general-purpose AI model`

> "an AI model, including where such an AI model is trained with a large amount of data using self-supervision at scale, that displays significant generality and is capable of competently performing a wide range of distinct tasks regardless of the way the model is placed on the market and that can be integrated into a variety of downstream systems or applications, except AI models that are used for research, development or prototyping activities before they are placed on the market"

**日本語**: 大量のデータを大規模な自己教師あり学習で訓練したものを含む AI モデルであって、顕著な
汎用性を示し、市場への出し方を問わず幅広い別種のタスクを適切にこなす能力をもち、多様な下流の
システムやアプリケーションに組み込めるもの。市場に出す前の研究・開発・試作に使われるモデルは除く。

### Article 3(64) — `high-impact capabilities`

> "capabilities that match or exceed the capabilities recorded in the most advanced general-purpose AI models"

**日本語**: 最も先進的な GPAI モデルで記録された能力に匹敵するか、それを上回る能力。

### Article 3(65) — `systemic risk`　←依頼書で 3(68) とされていたもの

> "a risk that is specific to the high-impact capabilities of general-purpose AI models, having a significant impact on the Union market due to their reach, or due to actual or reasonably foreseeable negative effects on public health, safety, public security, fundamental rights, or the society as a whole, that can be propagated at scale across the value chain"

**日本語**: GPAI モデルの高影響能力に固有のリスクであって、その到達範囲ゆえに EU 市場に重大な影響を
与えるもの、または公衆衛生・安全・公共の安全・基本的権利・社会全体への現実のもしくは合理的に
予見可能な悪影響ゆえにそうであるもので、バリューチェーン全体に大規模に伝播しうるもの。

### Article 3(66) — `general-purpose AI system`

> "an AI system which is based on a general-purpose AI model and which has the capability to serve a variety of purposes, both for direct use as well as for integration in other AI systems"

**日本語**: GPAI モデルに基づく AI システムであって、直接利用と他の AI システムへの組み込みの
どちらにおいても、多様な目的に役立つ能力をもつもの。

### Article 3(67) — `floating-point operation`

> "any mathematical operation or assignment involving floating-point numbers, which are a subset of the real numbers typically represented on computers by an integer of fixed precision scaled by an integer exponent of a fixed base"

**日本語**: 浮動小数点数を含む任意の数学的演算または代入。浮動小数点数とは実数の部分集合で、
固定精度の整数に固定基数の整数指数を掛けた形で計算機上に表現されるのが通例。

### Article 3(68) — `downstream provider`　←**これが本題の語**

> "a provider of an AI system, including a general-purpose AI system, which integrates an AI model, regardless of whether the AI model is provided by themselves and vertically integrated or provided by another entity based on contractual relations"

**日本語**: AI モデルを組み込む AI システム（汎用 AI システムを含む）の provider。そのモデルを
自社で用意して垂直統合しているか、契約関係に基づいて他社から提供されているかを問わない。

**読み方の要点**: `downstream provider` は法文上「**AI システムの** provider」と定義されている。
「AI モデルの provider」ではない。この一語に、§ 0 の結論がすでに書き込まれている。API 経由で他社の
モデルを組み込んでサービスを出すチームは、典型的にこの `downstream provider` に当たる。

---

## 2. 第 V 章の義務 — Article 51–55

### 2.1 Article 51 — systemic risk をもつ GPAI モデルへの分類

- (a) Article 51
- (b) https://artificialintelligenceact.eu/article/51/
- (d) `[条文]`

**Art. 51(1)**: GPAI モデルは、(a) 適切な技術的手段・方法論（評価・ベンチマークを含む）で評価した
結果、高影響能力をもつ場合、または (b) 欧州委員会が職権もしくは科学パネルの適格警告に基づき
Annex XIII の基準に照らして同等の能力・影響をもつと決定した場合に、systemic risk をもつものとして
分類される。

**Art. 51(2) — 10^25 FLOP の推定規定**（原文引用）:

> "A general-purpose AI model shall be presumed to have high impact capabilities pursuant to paragraph 1, point (a), when the cumulative amount of computation used for its training measured in floating point operations is greater than 10^25."

**日本語**: GPAI モデルは、その訓練に使われた累積計算量が浮動小数点演算で測って 10^25 を超えるとき、
第 1 項 (a) にいう高影響能力をもつものと**推定される**。

> **注記の必要**: 上記の verbatim 文言は条文ミラー経由の取得であり、取得ツールが一部を要約した
> 応答も返した（「shall be presumed to have high impact capabilities」「greater than 10^25」の
> 断片は確実に確認できた）。文言全体を EUR-Lex 原典で一字一句照合することは今回できていない。
> **数値 10^25 FLOP と「推定（presumed）」という法的性質の二点は、複数出典で一致しており確実。**

**Art. 51(3) — 委員会による閾値改正権限**:

> "The Commission shall adopt delegated acts in accordance with Article 97 to amend the thresholds listed in paragraphs 1 and 2 of this Article, as well as to supplement benchmarks and indicators in light of evolving technological developments, such as algorithmic improvements or increased hardware efficiency, where necessary, for these thresholds to reflect the state of the art."

**日本語**: 委員会は、アルゴリズムの改良やハードウェア効率の向上といった技術発展を踏まえ、閾値が
最新技術水準を反映するよう必要なときは、Article 97 に従う委任法により本条第 1・2 項の閾値を改正し、
ベンチマーク・指標を補充する。→ **10^25 という数字は固定ではない。**

### 2.2 Article 53 — すべての GPAI モデル provider の義務

- (b) https://artificialintelligenceact.eu/article/53/
- (d) `[条文]`

**Art. 53(1)** の四つの義務:

| 号 | 義務 | 誰に向けて |
|---|---|---|
| (a) | モデルの技術文書を作成・最新化する。訓練・試験の過程と評価結果を含み、**最低でも Annex XI** の情報を含む | AI Office と各国当局に**請求があれば**提出 |
| (b) | 情報・文書を作成・最新化し、**利用可能にする**。最低でも **Annex XII** の要素を含む | **そのモデルを自社の AI システムに組み込もうとする AI システムの provider**（= 下流） |
| (c) | EU 著作権法を遵守する方針を策定する。Directive (EU) 2019/790 第 4 条 (3) の権利留保の特定と尊重を含む | — |
| (d) | 訓練に使ったコンテンツについて、**十分に詳細な要約を作成し公開する**。AI Office 提供のテンプレートに従う | 公衆 |

**Art. 53(1)(b) の原文（AI Office のガイドラインが引用した形）**:

> "draw up, keep up-to-date and make available information and documentation to providers of AI systems who intend to integrate the general-purpose AI model into their AI systems"

**日本語**: GPAI モデルを自社の AI システムに組み込もうとする AI システムの provider に対し、情報と
文書を作成・最新化し、利用可能にすること。

→ **これが下流にとって最も重要な条文**である。下流は義務を負う側ではなく、**上流から情報を受け取る
権利をもつ側**としてここに登場する。§ 6 参照。

**Art. 53(2) — オープンソース免除**（原文引用）:

> "The obligations set out in paragraph 1, points (a) and (b), shall not apply to providers of AI models that are released under a free and open-source licence that allows for the access, usage, modification, and distribution of the model, and whose parameters, including the weights, the information on the model architecture, and the information on model usage, are made publicly available. This exception shall not apply to general-purpose AI models with systemic risks."

**日本語**: 第 1 項 (a)(b) の義務は、モデルへのアクセス・利用・改変・頒布を認める自由かつ
オープンソースのライセンスで公開され、かつ重みを含むパラメータ、モデルアーキテクチャの情報、
モデルの利用に関する情報が公開されている AI モデルの provider には適用されない。この例外は
systemic risk をもつ GPAI モデルには適用されない。

**免除されない範囲（ここが要点）** — 委員会ガイドライン第 73 項が免除対象を列挙しており、
免除されるのは **53(1)(a)・53(1)(b)・Article 54** の三つ**だけ**である:

- (a) 出典: GPAI Guidelines para (73)
- (c) 原文: "For providers meeting the conditions referred to in Section 4.2, the following obligations do not apply, unless their model is a general-purpose AI model with systemic risk: o Article 53(1), point (a) … o Article 53(1), point (b) … o Article 54 AI Act, which concerns the obligation to appoint an authorised representative"
- (d) `[公式ガイダンス]`

したがって **免除されないもの**:

1. **Art. 53(1)(c) 著作権方針** — オープンソースでも必要。
2. **Art. 53(1)(d) 訓練コンテンツの公開要約** — オープンソースでも必要。
3. **systemic risk をもつモデルの場合は、そもそも免除が一切効かない**（Art. 53(2) 末文、Art. 54(6)、
   ガイドライン第 74 項）。
4. オープンソース免除には「**収益化していないこと（lack of monetisation）**」の条件もかかる
   （ガイドライン § 4.2.2）。単にライセンスが OSI 的であればよいという話ではない。

**Art. 53(4) — 行動規範と整合規格の位置づけ**（原文引用）:

> "Providers of general-purpose AI models may rely on codes of practice within the meaning of Article 56 to demonstrate compliance with the obligations set out in paragraph 1 of this Article, until a harmonised standard is published. Compliance with European harmonised standards grants providers the presumption of conformity to the extent that those standards cover those obligations. Providers of general-purpose AI models who do not adhere to an approved code of practice or do not comply with a European harmonised standard shall demonstrate alternative adequate means of compliance for assessment by the Commission."

**日本語**: GPAI モデルの provider は、整合規格が公表されるまでの間、Article 56 にいう行動規範に依拠して
第 1 項の義務の遵守を示すことができる。欧州整合規格への適合は、その規格が当該義務をカバーする限りに
おいて、**適合の推定**を provider に与える。承認された行動規範に従わず、欧州整合規格にも適合しない
provider は、委員会の評価に付すため、代替の適切な遵守手段を示さなければならない。

→ **法的に厳密な「presumption of conformity（適合の推定）」を生むのは整合規格のほうであり、
行動規範ではない。** 行動規範は「遵守を示すために依拠できる（may rely on）」手段にとどまる。
§ 3 で再論する。

### 2.3 Article 53(1)(d) の公開要約テンプレート

- (a) Article 53(1)(d) の実施文書
- (b) 発表: https://digital-strategy.ec.europa.eu/en/news/commission-presents-template-general-purpose-ai-model-providers-summarise-data-used-train-their
  文書: https://digital-strategy.ec.europa.eu/en/library/explanatory-notice-and-template-public-summary-training-content-general-purpose-ai-models
- (c) 正式名称: "Explanatory Notice and Template for the Public Summary of Training Content for general-purpose AI models"
- (d) `[公式ガイダンス]`

| 項目 | 内容 |
|---|---|
| **公表日** | **2025-07-24** |
| 構成 | 3 節（モデルの識別情報 → 訓練データの内容 → データ処理の法的側面） |
| 使用義務 | 任意ではなく**必須の様式**。オープンソースライセンスで公開するモデルの provider にも適用される |
| 適用開始 | 2025-08-02 以降に市場に出すモデル。それ以前のモデルは 2027-08-02 まで猶予 |
| 更新 | 稼働中のモデルは少なくとも 6 か月ごと、および重要な変更時の更新が推奨される |
| 欠落データ | 最善を尽くしても入手できない／取得が不相当な負担になる情報は、**欠落を明示して説明**しなければならない |
| 事前協議 | 430 を超える団体が参加した公開協議を経て策定 |

> **食い違いの可能性**: 上の表のうち「3 節構成」「6 か月ごとの更新推奨」「430 団体」は
> `[二次解説]`（Securiti、WilmerHale、Mayer Brown 等の集約）に由来する。公表日 2025-07-24 と
> 「必須様式である」点は Commission 発表ページで確認済み。テンプレート本文を一次資料として
> 逐条確認することは今回していない。

### 2.4 Article 54 — 第三国 provider の EU 域内代理人

- (b) https://artificialintelligenceact.eu/article/54/
- (d) `[条文]`

**Art. 54(1)**: EU 域外に設立された GPAI モデルの provider は、EU 市場にモデルを出す**前に**、
書面による委任により、EU 域内に設立された**authorised representative（公認代理人）**を任命しなければ
ならない。

**Art. 54(3)** — 代理人の職務:
- Annex XI の技術文書が作成され、Article 53 の義務が履行されていることを**検証する**
  > "verify that the technical documentation specified in Annex XI has been drawn up and all obligations referred to in Article 53 … have been fulfilled"
- 技術文書と provider の連絡先を、**モデルの市場投入後 10 年間**、AI Office と各国当局のために保管する
- 理由を付した請求に応じ、遵守を示す情報・文書を AI Office に提供する
- モデルに関して当局と協力する。モデルが下流のシステムに組み込まれている場合を含む

**Art. 54(6)** — オープンソース免除: 自由かつオープンソースライセンスで公開され、パラメータが
公開されているモデルには本条は適用されない。**ただし systemic risk をもつモデルは除く**。

**下流側への含意**: この義務は**上流のモデル provider にかかる**。Anthropic や OpenAI のような
第三国 provider が EU 域内代理人を立てているかどうかは、下流の調達側が確認すべき事項ではあるが、
下流自身の義務ではない。

### 2.5 Article 55 — systemic risk をもつモデルへの追加義務

- (b) https://artificialintelligenceact.eu/article/55/
- (d) `[条文]`

**Art. 55(1)** — Article 53・54 に**加えて**課される義務（原文引用）:

| 号 | 原文 | 日本語 |
|---|---|---|
| (a) | "perform model evaluation in accordance with standardised protocols and tools reflecting the state of the art, including conducting and documenting adversarial testing of the model" | 最新技術水準を反映した標準化された手順・ツールに従ってモデル評価を行う。**敵対的テスト（adversarial testing）**の実施と文書化を含む |
| (b) | "assess and mitigate possible systemic risks at Union level, including their sources, that may stem from the development, the placing on the market or a general-purpose AI model" | 開発・市場投入・利用から生じうる EU レベルの systemic risk を、その源泉を含めて評価し軽減する |
| (c) | "keep track of, document, and report, without undue delay, to the AI Office and, as appropriate, to national competent authorities, relevant information about serious incidents" | **重大インシデント**に関する情報を追跡・文書化し、不当な遅滞なく AI Office（適切な場合は各国当局）に**報告**する。是正措置も含む |
| (d) | "ensure an adequate level of cybersecurity protection for the general-purpose AI model with systemic risk and the physical infrastructure of the model" | モデルおよびその物理インフラについて、十分な水準の**サイバーセキュリティ**保護を確保する |

**Art. 55(2)**: 整合規格が公表されるまで、Article 56 の行動規範に依拠して遵守を示せる。整合規格への
適合は適合の推定を与える。承認された行動規範に従わない provider は、代替の適切な遵守手段を
委員会の評価に付して示さなければならない。

**Art. 55(3)**: 本条により得た情報・文書（営業秘密を含む）は Article 78 の守秘義務に従って扱う。

**下流側への含意**: Art. 55 は**モデル provider にしかかからない**。API を呼ぶ側が「敵対的テストを
実施し文書化する」義務を条文から負うことはない（契約上求められることはありうる）。ただし
§ 5.1 の 1/3 compute 基準を越えて systemic risk モデルを改変した場合は、**Art. 55 の全義務が下流に
移ってくる**（ガイドライン第 65 項第三ポツ、第 70 項以降）。

---

## 3. GPAI 行動規範（General-Purpose AI Code of Practice）

- (b) 公式: https://digital-strategy.ec.europa.eu/en/policies/contents-code-gpai
  本文: https://code-of-practice.ai/
- (d) `[公式ガイダンス]`

| 項目 | 内容 |
|---|---|
| **最終版の公表日** | **2025-07-10**（独立専門家から委員会が受領） |
| 策定過程 | AI Office が調整。約 1,000 の関係者が参加。草案は 2024-11、2024-12、2025-03 の 3 回 |
| 署名者リストの公開日 | **2025-08-01**（第 V 章適用開始の前日） |
| 法的性質 | **任意（voluntary）**。委員会と AI Board が「adequate な任意のツール」と確認した |

### 3.1 三つの章

| 章 | 対象条文 | 適用範囲 |
|---|---|---|
| 1. **Transparency（透明性）** | Art. 53(1)(a)(b)、Annex XI・XII | すべての GPAI モデル provider。Model Documentation Form を提供 |
| 2. **Copyright（著作権）** | Art. 53(1)(c) | すべての GPAI モデル provider |
| 3. **Safety and Security（安全とセキュリティ）** | Art. 55 | **systemic risk をもつモデルの provider のみ** |

コミットメントは合計 12 件（最初の 2 章に各 1 件、Safety and Security 章に 10 件）＋対応する measures。
`[二次解説]`

### 3.2 署名者

欧州委員会の公式ページに掲載されている署名者（21 社。同ページは 2026-07-31 に最終更新）:

> AI Studio Delta, Aleph Alpha, Almawave, Amazon, **Anthropic**, Black Forest Labs, Bria AI, Cohere,
> Domyn, Dweve, Fastweb, **Google**, IBM, LINAGORA, **Microsoft**, Mistral AI, Open Hippo, **OpenAI**,
> Pleias, ServiceNow, WRITER

- **xAI** — **Safety and Security 章のみ**に署名。透明性・著作権の義務は代替の適切な手段で示すことになる。
- **Meta** — **署名せず**。「法的不確実性」と規制の行き過ぎを理由に明示的に拒否した。主要 AI 開発者の
  中では唯一の拒否とされる。`[二次解説]`
- 中国拠点の企業も概ね署名していない。`[二次解説]`

> **食い違い**: 署名者数について、委員会ページからの取得では **21 社**（xAI を別記）、
> 別の追跡サイト（aiprovidertrust.com、2026-07-05 時点）では **23 件** が列挙されている。
> 委員会の同ページには「署名者は即座には反映されない場合がある（リストは継続更新）」との注記が
> あり、時点差で説明できる。**署名者リストは継続的に更新されるため、使用時点で公式ページを
> 再確認すること。**

### 3.3 法的地位 — 「適合の推定」ではない

ここは正確に区別する必要がある。

- **Art. 53(4) / 55(2)**: 「**presumption of conformity（適合の推定）**」を生むのは**欧州整合規格
  （harmonised standards）**への適合であって、行動規範ではない。行動規範については "may rely on
  codes of practice … to demonstrate compliance"（遵守を示すために依拠**できる**）という表現にとどまる。
- **Art. 56(6)**: AI Office と Board が adequate と評価した行動規範に従うことで、Art. 53(1) および
  55(1) の義務の遵守を示すことができる。

委員会ガイドライン第 94 項（原文引用）:

> "Providers of general-purpose AI models can demonstrate compliance with the obligations in Articles 53(1) and 55(1) AI Act by adhering to a code of practice that is assessed as adequate by the AI Office and the Board (Article 56(6) AI Act). Any opt-out from chapters of the code of practice results in losing the benefits of facilitating the demonstration of compliance in that respect. … For providers of general-purpose AI models that adhere to a code of practice that is assessed as adequate, the Commission will focus its enforcement activities on monitoring their adherence to the code of practice."

**日本語**: GPAI モデルの provider は、AI Office と Board が adequate と評価した行動規範に従うことで、
Art. 53(1) と 55(1) の義務の遵守を示すことができる（Art. 56(6)）。行動規範のいずれかの章から
opt-out すると、その範囲では遵守証明を容易にする利益を失う。adequate と評価された行動規範に従う
provider について、委員会は執行活動を**その行動規範への遵守の監視に集中させる**。

同第 95 項 — 署名しない場合:

> "Providers of general-purpose AI models that do not adhere to a code of practice that is assessed as adequate are expected to demonstrate how they comply with their obligations under Chapter V of the AI Act via other adequate means and will have to report the measures they have implemented to the AI Office. … They may also be subject to a larger number of requests for information and requests for access to conduct model evaluations throughout the entire model lifecycle"

**日本語**: 署名しない provider は、他の適切な手段で第 V 章の義務をどう守っているかを示すことが
期待され、実施した措置を AI Office に報告しなければならない。さらに、**より多くの情報提供請求や
モデル評価のためのアクセス請求を受けることがありうる**。

同第 96 項 — 制裁金への影響:

> "The Commission may take into account commitments implemented in line with a code of practice that is assessed as adequate as a mitigating factor when fixing the amount of fines, depending on the specific circumstances (Article 101(1) AI Act)."

**日本語**: 委員会は、adequate と評価された行動規範に沿って実施されたコミットメントを、制裁金の額を
決める際の**減軽要素**として考慮しうる。

### 3.4 2026 年の更新について

公式ページの最終更新は **2026-07-31** で、署名者リストが継続更新されている旨の注記がある。
行動規範の**本文**そのものが 2026 年に改訂されたという記述は、今回の調査では確認できなかった。
`[公式ガイダンス]`（更新日のみ）

---

## 4. いつから効くのか、執行はいつからか

### 4.1 時系列

```
2024-08-01  AI Act 発効（entry into force）
    │
2025-02-02  第 I・II 章（禁止行為など）適用開始        ← Art. 113(a)
    │
2025-07-10  GPAI Code of Practice 最終版 公表
2025-07-18  GPAI Guidelines 内容承認 C(2025) 5045 final
2025-07-24  訓練コンテンツ要約テンプレート 公表
2025-08-01  Code of Practice 署名者リスト公開
    │
2025-08-02  ★ 第 V 章（GPAI 義務 Art. 51-56）適用開始   ← Art. 113(b)
    │           ただし委員会に執行権限はまだない
    │           ↓ 1 年の「執行なしの適用」期間
2025-11-19  GPAI Guidelines 正式採択 C(2025) 7719 final
    │
2026-07-24  Digital Omnibus on AI が OJ に掲載 = Reg (EU) 2026/1744
2026-07-27  同 発効（高リスク規律の期日を後ろ倒し。GPAI は不変）
    │
2026-08-02  ★★ 委員会の GPAI 執行権限 発動（Art. 101 の制裁金を含む）
    │           Art. 50 透明性義務も適用開始
    │           【今日 2026-09-13 はこの後】
    │
2027-08-02  ★ 2025-08-02 より前に市場に出ていたモデルの遵守期限  ← Art. 111(3)
    │
2027-12-02  高リスク（Annex III）適用開始 ← Omnibus により 2026-08-02 から延期
2028-08-02  高リスク（Annex I 組込型）適用開始 ← Omnibus により延期
```

### 4.2 Article 113(b) — 第 V 章の適用開始

- (a) Article 113(b)
- (b) https://artificialintelligenceact.eu/article/113/
- (c) 原文: "Chapter III Section 4, Chapter V, Chapter VII and Chapter XII and Article 78 shall apply from 2 August 2025", with the exception of Article 101
- (d) `[条文]`

**日本語**: 第 III 章第 4 節、**第 V 章**、第 VII 章、第 XII 章および Article 78 は **2025 年 8 月 2 日**
から適用される。ただし **Article 101 は除く**。

**重要**: この「Article 101 を除く」が、執行が 1 年遅れる根拠である。Art. 101 は委員会が GPAI モデル
provider に制裁金を課す権限を定めた条文であり、それだけが本則の適用日（2026-08-02）に据え置かれた。

### 4.3 Article 111(3) — 既存モデルの経過措置

- (a) Article 111(3)
- (b) https://artificialintelligenceact.eu/article/111/
- (c) 原文: "Providers of general-purpose AI models that have been placed on the market before 2 August 2025 shall take the necessary steps in order to comply with the obligations laid down in this Regulation by 2 August 2027."
- (d) `[条文]`

**日本語**: **2025 年 8 月 2 日より前に**市場に出された GPAI モデルの provider は、本規則に定める義務を
遵守するために必要な措置を **2027 年 8 月 2 日までに**とらなければならない。

ガイドライン第 109 項が同条を引用したうえで「This covers such models throughout their entire
lifecycle」（当該モデルのライフサイクル全体をカバーする）と補足している。`[公式ガイダンス]`

**緩和**: ガイドライン第 111 項 —
> "providers of general-purpose AI models placed on the market before 2 August 2025 are not required to conduct retraining or unlearning of models, where it is not possible to do this for actions performed in the past, where some of the information about the training data is not available, or where its retrieval would cause the provider disproportionate burden. Such instances must be clearly disclosed and justified in the copyright policy and in the summary of the content used for training."

**日本語**: 2025-08-02 より前に市場に出たモデルの provider は、**再訓練やアンラーニングを行う義務を
負わない**。過去の行為についてそれが不可能な場合、訓練データの情報の一部が入手できない場合、
または取得が provider に不相当な負担を生じさせる場合。そうした事例は**著作権方針および訓練
コンテンツ要約の中で明確に開示し、正当化しなければならない**。

### 4.4 執行権限の発動 — 2026 年 8 月 2 日

**一次資料**: ガイドライン第 115 項（原文引用）:

> "the AI Act acknowledges that immediately after 2 August 2025, providers may not be able to fully implement certain measures laid down in a code of practice that is assessed as adequate or alternative adequate measures. **In the first year from 2 August 2025 onwards, the Commission cannot take any enforcement actions because its enforcement powers only enter into application on 2 August 2026.** This lack of enforcement does not put into question the applicability of the obligations laid down in Chapter V of the AI Act from 2 August 2025 onwards (Article 113, point (b), AI Act). … **From 2 August 2026 onwards, the Commission will enforce with fines compliance with all obligations by providers of general-purpose AI models who are not fully compliant on that date**, taking into account all relevant aspects mentioned in Article 101 AI Act."

**日本語**: 2025 年 8 月 2 日の直後には、provider が adequate と評価された行動規範や代替手段の一部を
完全には実施できない可能性があることを AI Act は認めている。**2025 年 8 月 2 日から 1 年間、委員会は
いかなる執行措置もとることができない。その執行権限は 2026 年 8 月 2 日にしか適用開始されないからで
ある。**執行がないことは、第 V 章の義務が 2025 年 8 月 2 日から適用されることを何ら左右しない。
… **2026 年 8 月 2 日以降、委員会は、その日に完全には遵守していない GPAI モデル provider に対し、
Article 101 に挙げられた全ての関連事情を考慮したうえで、制裁金をもって遵守を執行する。**

- (b) 出典 URL: 上記ガイドライン PDF, para (115)
- (d) `[公式ガイダンス]` — **これは一次のガイダンスによる確認であり、二次解説に依存していない**

**制裁金の上限（Article 101）**: GPAI モデル provider に対し、**前会計年度の全世界年間総売上高の 3%
または 1,500 万ユーロのいずれか高いほう**。故意または過失が要件。根拠は (i) 規則の関連規定違反、
(ii) Art. 91 の文書・情報提供請求への不遵守、(iii) Art. 93 により求められた措置への不遵守、
(iv) Art. 92 のモデル評価に必要なアクセスを与えないこと、の四つ。`[二次解説]`
（Art. 99 は加盟国が operator 等に課す行政制裁金の枠組みで、**名宛人も執行者も別**。Art. 99 は
2025-08-02 から適用済み。）

### 4.5 Digital Omnibus（2026）は GPAI を動かしたか → **動かしていない**

- (a) Regulation (EU) 2026/1744（2026 年 7 月 8 日付、Regulation (EU) 2024/1689 等を改正）
- (b) https://eur-lex.europa.eu/eli/reg/2026/1744/oj/eng
  ELI: http://data.europa.eu/eli/reg/2026/1744/oj
- (d) `[条文]`（本文は今回未照合）／ 内容の記述は `[二次解説]`

| 項目 | 内容 |
|---|---|
| OJ 掲載 | **2026-07-24**（OJ L, 2026/1744, 24.7.2026） |
| 発効 | **2026-07-27**（掲載の 3 日後。2026-08-02 の期限が迫っていたため緊急扱い） |
| 立法過程 | 委員会提案 2025-11-19 → 議会第一読 2026-03-26 → 政治合意 2026-05-07 → 議会承認 2026-06-16 → 理事会承認 2026-06-29 → 署名 2026-07-08 |
| **高リスクの延期** | Annex III（単独型）: 2026-08-02 → **2027-12-02**。Annex I（製品組込型）: → **2028-08-02** |
| **GPAI への影響** | **なし**。Art. 51–56 の義務は 2025-08-02 から有効のまま、変更されていない。Art. 111(3) の 2027-08-02 も変更なし。著作権方針と訓練コンテンツ公開要約もそのまま |
| Art. 5 / Art. 50 | 変更なし（Art. 50 透明性義務は 2026-08-02 から適用済み） |
| GPAI 周辺の間接的変更 | AI Office の監督範囲が拡大。従来は GPAI モデルと**同一 provider** が作ったシステムが対象だったが、**モデル provider と同一 undertaking 内で開発された GPAI ベースの全 AI システム**に広がった |
| 新設 | Art. 5 に CSAM・非同意の性的画像を生成する AI システムの禁止が追加。技術的保護措置の実装期限は 2026-12-02 |

> **重要な注意**: Article 113 の本文は Omnibus により**改正されている**。条文ミラーサイトが返す
> Art. 113 の記述には、改正後の 2027-12-02 / 2028-08-02 の日付が混入している場合がある。
> 原典の Art. 113(a)(b) は変更されておらず、**第 V 章の 2025-08-02 は動いていない**。
> 引用時は改正後の統合版（consolidated version）を確認すること。
>
> **Omnibus 本文の逐条確認は今回できていない**（上記 EUR-Lex URL は未取得）。日付と
> 規則番号は複数の `[二次解説]` が一致しており信頼度は高いが、一次照合はされていない。

---

## 5. ファインチューニングした側はどうなるか — **本題**

出典（§ 5 全体）:
- (a) Commission Guidelines on the scope of the obligations for providers of general-purpose AI models established by Regulation (EU) 2024/1689 (AI Act)
- (b) PDF: https://ai-act-service-desk.ec.europa.eu/sites/default/files/2025-07/guidelines_on_the_scope_of_the_obligations_for_generalpurpose_ai_models_established_by_regulation_1cx2atxgq79us4n3x8jfgyy1qlm_118340-3.pdf
  ランディングページ（24 言語）: https://digital-strategy.ec.europa.eu/en/library/guidelines-scope-obligations-providers-general-purpose-ai-models-under-ai-act
- (c) 文書番号: 内容承認 **C(2025) 5045 final**（Brussels, 18.7.2025）／正式採択 **C(2025) 7719 final**（2025-11-19）
- (d) `[公式ガイダンス]` — Article 96(1) に基づく**法的拘束力のない解釈文書**

> **ツール取得の不一致の記録**: ある二次情報は「Guidelines publication date: July 18, 2026」と
> 返したが、これは 2025 年の誤りである。PDF 表紙に "Brussels, 18.7.2025 C(2025) 5045 final" と
> 明記されている。**2025-07-18 が正しい。**

### 5.0 ガイドラインが答える四つの問い（第 8 項）

1. そのモデルは GPAI モデルか
2. その行為者は、それを市場に出す provider か
3. 自由なライセンスでの公開に対する例外の適用を受けるか
4. 委員会の執行、特に適用開始直後の期間に何を期待すべきか

### 5.1 いつ下流が「新しいモデルの provider」になるか — 1/3 compute 基準

**第 60 項** — 問題の所在:
> "According to recital 97 AI Act, '[general-purpose AI] models may be modified or fine-tuned into new models'. In particular, downstream actors (distinct from the original provider and not acting on its behalf) may modify a general-purpose AI model (with or without integrating it into an AI system). Nevertheless, the AI Act does not specify the conditions under which downstream modifiers should be considered the providers of the modified general-purpose AI models."

**日本語**: GPAI モデルは改変されたりファインチューニングされたりして新しいモデルになりうる
（前文 97）。とくに、元の provider と別で、その代理としても行動していない下流の行為者が、GPAI モデルを
改変することがある（AI システムに組み込むかどうかを問わない）。しかし AI Act は、**下流の改変者が
どういう条件で改変後モデルの provider とみなされるかを定めていない**。

脚注 11: 委員会は「fine-tuning」を「modifying」の一つの方法とみなす。
脚注 12（実務上きわめて重要）:
> "Whether it is the original provider or a downstream actor who modifies the general-purpose AI model must be assessed on a case-by-case basis. An important factor in this assessment may be who has the control over the model's weights, **for example, in case of fine-tuning via API**."

**日本語**: GPAI モデルを改変したのが元の provider なのか下流の行為者なのかは、個別に判断しなければ
ならない。その判断で重要な要素になりうるのは、**誰がモデルの重みを支配しているか**である。たとえば
**API 経由のファインチューニング**の場合。

→ **Bedrock 上のマネージド fine-tuning のように重みをプラットフォーム側が保持する形態では、
下流が「改変者」に当たらない可能性がある。** ただしケースバイケース。

**第 61 項** — すべての改変が provider 化を招くわけではない:
> "The Commission deems that it is not necessary for every modification of a general-purpose AI model to lead to the downstream modifier being considered the provider of the modified general-purpose AI model. This is in line with the Blue Guide which states that 'a product which has been subject to important changes or overhauls aiming to modify its original performance, purpose or type may be considered as a new product'."

**第 62 項** — 判断の基準:
> "Instead, the Commission considers a downstream modifier to become the provider of the modified general-purpose AI model **only if the modification leads to a significant change in the model's generality, capabilities, or systemic risk**."

**日本語**: 委員会は、下流の改変者が改変後 GPAI モデルの provider になるのは、**その改変がモデルの
汎用性・能力・systemic risk に重大な変化をもたらす場合に限る**と考える。

**第 63 項** — 定量的な指標基準（**1/3 compute 基準**）:
> "Based on the considerations above, an indicative criterion for when a downstream modifier is considered to be the provider of a general-purpose AI model is that **the training compute used for the modification is greater than a third of the training compute of the original model** (see paragraph 115 for how 'training compute' should be understood in these guidelines)."

**日本語**: 下流の改変者が GPAI モデルの provider とみなされるかどうかの**指標的基準（indicative
criterion）**は、**改変に使われた訓練計算量が、元のモデルの訓練計算量の 3 分の 1 を超えること**である。

**第 64 項** — 元モデルの計算量が分からない場合の代替閾値:
> "However, if the downstream modifier cannot be expected to know this value (for example because it has not been communicated by the provider of the original model) and cannot estimate it … then the threshold should be replaced as follows. If the original model is a general-purpose AI model with systemic risk, the threshold should be replaced with a third of the threshold for a model being presumed to have high-impact capabilities (i.e. currently 10^25 FLOP, see Article 51(2) AI Act). Otherwise, it should be replaced with a third of the threshold for a model being presumed to be a general-purpose AI model (i.e. currently 10^23 FLOP, see Section 2.1)."

**代替閾値の整理**:

| 元モデルの種類 | 閾値 | 数値 |
|---|---|---|
| 元モデルの訓練計算量を知っている／推定できる | 元モデルの訓練計算量の 1/3 超 | — |
| 知りえない。元モデルが **systemic risk あり** | 10^25 FLOP の 1/3 | 約 **3.3 × 10^24 FLOP** |
| 知りえない。元モデルが **systemic risk なし** | 10^23 FLOP の 1/3 | 約 **3.3 × 10^22 FLOP** |

**第 67 項** — 現時点での実効性:
> "While currently few modifications may meet the criterion set out in paragraph 60, the number of downstream modifiers that become providers of general-purpose AI models may increase over time as the compute used to modify models increases. **The criterion is thus primarily forward-looking**, and in line with the risk-based approach of the AI Act. Therefore, the Commission's approach may change in the future as technology and the market evolve."

**日本語**: 現時点でこの基準を満たす改変はほとんどないだろうが、改変に使われる計算量が増えるに
つれて、GPAI モデルの provider になる下流の改変者の数は時とともに増えうる。**この基準は主として
将来を見越したものである。**したがって委員会のアプローチは技術と市場の進展に応じて将来変わりうる。

> **食い違い（軽微）**: 第 67 項は "the criterion set out in paragraph 60" と参照しているが、
> 基準が実際に置かれているのは**第 63 項**である。ガイドライン本文の内部参照の誤りと思われる。
> 引用時は第 63 項を指すこと。

### 5.2 閾値を超えた場合、下流は何を負うか

**第 68 項** — 義務は「改変部分」に限定される:
> "According to recital 109 AI Act, 'in the case of a modification or fine-tuning of a model, the obligations for providers of general-purpose AI models should be limited to that modification or fine-tuning, for example by complementing the already existing technical documentation with information on the modifications, including new training data sources …'. That is, **the documentation required by Article 53(1), points (a) and (b), AI Act is limited to information on the modification, while the copyright policy required by Article 53(1), point (c), AI Act and the summary of the content used for training required by Article 53(1), point (d), AI Act are limited to the data used as part of the modification.**"

**日本語**: モデルの改変・ファインチューニングの場合、GPAI モデル provider の義務は**その改変
部分に限定される**。すなわち Art. 53(1)(a)(b) の文書化は改変に関する情報に限られ、Art. 53(1)(c) の
著作権方針と Art. 53(1)(d) の訓練コンテンツ要約は、**改変の一部として使われたデータに限られる**。

**第 69 項**: 「A downstream modifier who becomes the provider of a general-purpose AI model must
also comply with Article 54 AI Act.」→ **EU 域外の事業者なら、EU 域内代理人の任命が必要になる。**

**第 65 項第三ポツ／第 70 項以降** — systemic risk モデルを改変した場合:
> "In cases where the original model is a general-purpose AI model with systemic risk, the modified model can be expected to present significantly different systemic risk compared to the original model. In particular, the Commission deems that the original provider cannot reasonably foresee the change in systemic risk posed by such modifications in its systemic risk assessment and mitigation. This justifies the downstream modifier being subject to the obligations in Article 55 AI Act."

**日本語**: 元モデルが systemic risk をもつ GPAI モデルである場合、改変後モデルは元モデルと著しく
異なる systemic risk を呈すると予想される。とくに、元の provider は自らの systemic risk 評価・軽減の
中でそうした改変による systemic risk の変化を合理的に予見できないと委員会は考える。これが、
**下流の改変者が Art. 55 の義務に服することを正当化する**。

→ この場合、義務は**改変部分に限定されない**（委員会への通知を含む Art. 55 の全義務）。`[二次解説]`

### 5.3 API を呼ぶ／プロンプトを書く／RAG を組む — provider になるか

**結論: ならない。ただしガイドラインはこれを一文で否定してはいない。** 否定は二つの構造から導かれる。

**構造 1 — 第 57 項の役割分担**（§ 0 に全文引用済み）。上流がモデルの provider、下流はシステムの
provider。これが原則である。

**構造 2 — 第 62–63 項の閾値**。改変が「汎用性・能力・systemic risk の重大な変化」をもたらさなければ
provider にならない。プロンプト、system prompt、RAG、API 呼び出しは**モデルの重みを変えない**ため、
「training compute used for the modification」がゼロであり、1/3 基準を構造的に満たしえない。

> **注意して記録する**: **ガイドライン本文には "prompting"、"retrieval-augmented generation"、
> "RAG"、"system prompt" という語は一度も現れない。**（PDF 全文を grep で確認した。"prompts" は
> 音楽生成モデルの例（第 324 行付近）と "text prompts including lyrics" にのみ出現する。）
> 「プロンプトだけなら provider にならない」という命題は、**ガイドラインの明文ではなく、
> 第 57 項と第 63 項からの推論**である。
>
> 二次解説はこれを明言している。たとえば:
> > "Lighter interventions such as prompt engineering, few-shot learning, or narrow fine-tuning are generally not considered substantial, meaning the deployer is not treated as a GPAI provider."
> — `[二次解説]`（複数の法律事務所解説の集約）
>
> **RAG の扱いは食い違いがある**: ある集約は「fine-tuning, distillation, and Retrieval-Augmented
> Generation (RAG)」を分析の対象技術に含めるとし、別の記述は RAG を軽い介入の側に置く。
> **RAG はモデルの重みを変えないため 1/3 compute 基準では常にゼロ**であり、実務上は provider 化
> しないと読むのが自然だが、**ガイドラインの明文による裏づけはない**。

**API 経由の提供は「上流の placing on the market」である** — 第 53 項（原文引用）:
> "The following list of examples gives insights into when a general-purpose AI model should be considered to be placed on the market …:
> • a general-purpose AI model is made available for the first time on the Union market via a software library or package;
> • **a general-purpose AI model is made available for the first time on the Union market via an application programming interface (API);**
> • a general-purpose AI model is uploaded for the first time to a public catalogue, hub, or repository for direct download on the Union market;
> • a general-purpose AI model is made available for the first time on the Union market as a physical copy;
> • **a general-purpose AI model is made available for the first time on the Union market via a cloud computing service;**
> • a general-purpose AI model is made available for the first time on the Union market by being copied onto a customer's own infrastructure;
> • a general-purpose AI model is integrated into a chatbot made available for the first time on the Union market via a web interface;
> • a general-purpose AI model is integrated into a mobile application made available for the first time on the Union market via app stores;
> • **a general-purpose AI model is used for internal processes that are essential for providing a product or service to third parties or that affect the rights of natural persons in the Union.**"

**日本語**: API 経由での提供、クラウドコンピューティングサービス経由での提供は、いずれも
「GPAI モデルを市場に出す」行為の例として挙げられている。これは**モデルを供給する側の行為**である。

**第 49 項** — 前文 97 の引用:
> "Recital 97 AI Act further clarifies that '[g]eneral-purpose AI models may be placed on the market in various ways, **including through libraries, application programming interfaces (APIs)**, as direct download, or as physical copy.'"

**第 56 項** — 自社モデルを自社システムに組み込む場合（垂直統合）:
> "as specified in recital 97 AI Act, '[w]hen the provider of a general-purpose AI model integrates an own model into its own AI system that is made available on the market or put into service, that model should be considered to be placed on the market and, therefore, the obligations in this Regulation for models should continue to apply in addition to those for AI systems.'"

**日本語**: GPAI モデルの provider が**自社のモデル**を自社の AI システムに組み込んで市場に出す場合、
そのモデルは市場に出されたものとみなされ、モデルに対する義務がシステムに対する義務に**加えて**
適用され続ける。→ これは自社でモデルを作っている事業者の話であり、他社モデルを API で呼ぶ側には
当たらない。

**第 58–59 項** — EU 域外で受け取ったモデルを EU に持ち込む場合（**下流が例外的にモデルの provider に
なりうる唯一の非改変ケース**）:
> "(58) … when an upstream actor develops or has developed a general-purpose AI model and makes the model available for the first time to a downstream actor **outside the Union market**, and the downstream actor integrates the model into an AI system which it places on the Union market … the model should be considered to be placed on the Union market once the system into which it is integrated is placed on the Union market …
> (59) **The upstream actor should then be considered the provider of the model, unless the upstream actor has excluded, in a clear and unequivocal way, the distribution and use of the model on the Union market**, including its integration into AI systems that are intended to be placed on the Union market or put into service in the Union. If the upstream actor has done this, **the downstream actor that integrates the model into a system and places the system on the Union market … should be considered the provider of the model.**"

**日本語**: 上流が EU 域外で初めてモデルを下流に渡し、下流がそれをシステムに組み込んで EU 市場に
出す場合、そのシステムが EU 市場に出た時点でモデルも EU 市場に出たとみなされる。この場合、
原則として上流がモデルの provider だが、**上流が EU 市場での頒布・利用を明確かつ一義的に排除して
いた場合には、下流がモデルの provider とみなされる**。

→ **実務上の含意**: 利用規約やライセンスで「EU 市場での利用を明示的に排除している」上流モデルを
使ってはいけない。それを EU 市場向けのサービスに組み込むと、**下流がモデルの provider になり、
Art. 53 の全義務（技術文書、訓練データ要約、著作権方針）を背負う**ことになる。
これは 1/3 compute 基準とは**別ルート**の provider 化である。調達時に確認すべき点。

### 5.4 AI *システム* の provider として何を負うか — Art. 3(1) と Art. 3(63) の対比

条文上の区別を明示する:

| | **AI system**（Art. 3(1)） | **general-purpose AI model**（Art. 3(63)） |
|---|---|---|
| 原文の核 | "a machine-based system … that … **infers, from the input it receives, how to generate outputs** such as predictions, content, recommendations, or decisions that can influence physical or virtual environments" | "**an AI model** … that displays **significant generality** and is capable of competently performing a wide range of distinct tasks … and that **can be integrated into a variety of downstream systems or applications**" |
| 何を指すか | 入力から出力を生成する**システム**。モデルはその部品 | **モデルそのもの**。システムに組み込まれる対象 |
| 誰が provider か | それを自分の名前で市場に出す者（Art. 3(3)）。API を呼ぶチームは**ここ** | それを最初に EU 市場に出した者（通常は上流。Art. 3(3) + ガイドライン第 57 項） |
| かかる章 | 第 II 章（禁止）、第 III 章（高リスク、該当すれば）、Art. 50（透明性） | **第 V 章（Art. 51–56）** |

前文 97 は "AI models are typically integrated into and form part of AI systems" と述べ、モデルは
システムの構成要素であって、システムそのものではないことを確認している（ガイドライン第 55 項が引用）。

**AI システムの provider として実際にかかるもの**（該当する場合のみ）:

1. **Art. 5 — 禁止行為**。2025-02-02 から適用。無条件にかかる。
2. **Art. 6・Annex III — 高リスク該当性**。該当すれば第 III 章第 2 節の要件（リスク管理 Art. 9、
   データガバナンス Art. 10、Annex IV の技術文書等）。適用開始は Omnibus により **2027-12-02**
   （Annex III 単独型）。
   - 雇用・信用力の評価のように**自然人をスコアリングする**機能は、該当を検討する必要がある。`[二次解説]`
   - 一般的な B2B の要約機能などは Annex III のどの類型にも当たらない。`[二次解説]`
3. **Art. 50 — 透明性義務**。**2026-08-02 から適用済み**（今日の時点で発効している）。
   - 自然人が AI システムと直接やりとりしていることの開示。ただし
     "where that would be obvious to a reasonably well-informed person" の例外あり
   - 生成された合成の音声・画像・映像・テキストの**機械可読な形でのマーキング**
   - deepfake および公共の関心事に関する AI 生成テキストの開示。芸術・風刺・編集責任下の
     コンテンツには例外あり
   - `[二次解説]`（https://securityboulevard.com/2026/09/the-eu-ai-act-for-the-downstream-provider-what-you-owe-when-you-just-call-an-api/ 、2026-09-09）
4. **制裁金**: Art. 99(4) により 1,500 万ユーロまたは全世界売上高の 3% の高いほう。`[二次解説]`

---

## 6. 上流から下流へ渡される情報 — Annex XII

- (a) Annex XII（Article 53(1)(b) で参照される）
- (b) https://artificialintelligenceact.eu/annex/12/
- (d) `[条文]`

正式表題: *Transparency information referred to in Article 53(1), point (b) — technical documentation
for providers of general-purpose AI models to downstream providers that integrate the model into
their AI system.*

### 第 1 項 — モデルの一般的説明

> "A general description of the general-purpose AI model including:
> (a) the tasks that the model is intended to perform and the type and nature of AI systems into which it can be integrated;
> (b) the acceptable use policies applicable;
> (c) the date of release and methods of distribution;
> (d) how the model interacts, or can be used to interact, with hardware or software that is not part of the model itself, where applicable;
> (e) the versions of relevant software related to the use of the general-purpose AI model, where applicable;
> (f) the architecture and number of parameters;
> (g) the modality (e.g. text, image) and format of inputs and outputs;
> (h) the licence."

| 号 | 日本語 |
|---|---|
| (a) | モデルが行うことを意図されたタスク、および組み込みうる AI システムの種類と性質 |
| (b) | 適用される許容利用方針（acceptable use policies） |
| (c) | リリース日と頒布の方法 |
| (d) | モデル自身の一部でないハードウェア・ソフトウェアと、モデルがどう相互作用するか（該当する場合） |
| (e) | モデルの利用に関係するソフトウェアのバージョン（該当する場合） |
| (f) | アーキテクチャとパラメータ数 |
| (g) | 入出力のモダリティ（テキスト、画像など）と形式 |
| (h) | モデルのライセンス |

### 第 2 項 — モデルの要素と開発過程の説明

> "A description of the elements of the model and of the process for its development, including:
> (a) the technical means (e.g. instructions for use, infrastructure, tools) required for the general-purpose AI model to be integrated into AI systems;
> (b) the modality (e.g. text, image, etc.) and format of the inputs and outputs and their maximum size (e.g. context window length, etc.);
> (c) information on the data used for training, testing and validation, where applicable, including the type and provenance of data and curation methodologies."

| 号 | 日本語 |
|---|---|
| (a) | GPAI モデルを AI システムに組み込むために必要な技術的手段（利用説明書、インフラ、ツールなど） |
| (b) | 入出力のモダリティと形式、およびその**最大サイズ**（コンテキストウィンドウ長など） |
| (c) | 訓練・試験・検証に使われたデータに関する情報（該当する場合）。データの**種類と出所**、および**キュレーション方法論**を含む |

### 下流にとっての実務的な読み方

Annex XII は**下流が上流に要求できる情報のリスト**である。Art. 53(1)(b) は上流に「make available」
する義務を課している。したがって:

- Anthropic / OpenAI / AWS Bedrock といった供給元に対し、**Annex XII の各項目を明示して**
  ドキュメントを要求できる。
- その**要求と回答そのものが、下流が自らの注意義務を果たしたことを示す記録になる**。
  > "The request, and the response, are the artifact that shows you did your own diligence."
  — `[二次解説]`（Security Boulevard, 2026-09-09）
- ただし Annex XII は「情報を受け取る」だけの規定であり、下流に**何かを作成・公開する義務を
  直接課してはいない**。

### 参考 — Annex XI（下流には渡らない、当局向けの技術文書）

Art. 53(1)(a) の Annex XI は**AI Office と各国当局に請求に応じて出す**もので、下流への提供義務の
対象ではない。Annex XII より広く、以下を含む（`[条文]`, https://artificialintelligenceact.eu/annex/11/）:

- **第 1 節（全 provider）**: モデルの一般的説明（Annex XII 第 1 項と重複する項目）＋
  「design specifications of the model and training process, including training methodologies」、
  データの種類・出所・キュレーション方法、**訓練に使われた計算資源・訓練時間**、
  「known or estimated energy consumption of the model」（既知または推定のエネルギー消費量）
- **第 2 節（systemic risk モデルのみ、追加）**:
  1. "A detailed description of the evaluation strategies, including evaluation results"（評価戦略と評価結果の詳細）
  2. 該当する場合、"internal and/or external adversarial testing (e.g. red teaming), model adaptations, including alignment and fine-tuning" の措置の詳細
  3. 該当する場合、"detailed description of the system architecture explaining how software components build or feed into each other"

→ **Annex XI と Annex XII の差は意図的である。** 下流には統合に必要な範囲（XII）だけが渡り、
訓練計算量・エネルギー消費・評価結果といった機微な情報（XI）は当局止まりになる。

---

## 7. 小規模チーム向けの要約表

| 問い | 答え | 根拠 |
|---|---|---|
| API を呼ぶだけで GPAI モデルの provider になるか | **ならない** | Guidelines para (57)、Art. 3(68) |
| 自分は何の provider か | **AI システムの provider** = `downstream provider` | Art. 3(68)、Guidelines para (57) |
| system prompt / RAG で provider になるか | **ならない**（重みを変えず compute がゼロのため） | Guidelines para (62)(63) からの推論。明文なし |
| ファインチューニングで provider になるか | **元モデルの訓練計算量の 1/3 を超えたら**なる | Guidelines para (63) |
| 元モデルの計算量が分からないとき | systemic risk あり: 10^25÷3、なし: 10^23÷3 | Guidelines para (64) |
| 実際に超えることはあるか | 現時点ではほとんどない。基準は「forward-looking」 | Guidelines para (67) |
| API 経由の fine-tuning は | **誰が重みを支配しているか**で個別判断 | Guidelines 脚注 12 |
| 超えたら何を負うか | Art. 53(1)(a)(b) は改変部分の文書化、(c)(d) は改変に使ったデータの範囲。＋Art. 54 | Guidelines para (68)(69) |
| systemic risk モデルを超えて改変したら | Art. 55 の**全**義務。改変部分に限定されない | Guidelines para (65)(70) |
| 上流が EU 利用を明示排除しているモデルを使ったら | **下流がモデルの provider になる**（別ルートの危険） | Guidelines para (59) |
| 上流から何を取れるか | **Annex XII の全項目**。Art. 53(1)(b) が上流に提供義務を課す | Annex XII、Art. 53(1)(b) |
| 実際にかかる義務は | Art. 5（禁止）、該当すれば Art. 6/Annex III（高リスク、2027-12-02〜）、**Art. 50（透明性、2026-08-02 適用済み）** | Art. 113、Reg (EU) 2026/1744 |
| 今日（2026-09-13）時点の状況 | GPAI 義務は 2025-08-02 から適用済み、**執行も 2026-08-02 から開始済み**。高リスクだけが 2027-12-02 に延期 | Guidelines para (115)、Reg (EU) 2026/1744 |

---

## 出典一覧

### `[条文]`
- Regulation (EU) 2024/1689 (AI Act) — https://eur-lex.europa.eu/eli/reg/2024/1689/oj/eng
- Regulation (EU) 2026/1744 (Digital Omnibus on AI) — https://eur-lex.europa.eu/eli/reg/2026/1744/oj/eng （ELI: http://data.europa.eu/eli/reg/2026/1744/oj 、OJ L, 2026/1744, 24.7.2026）
- 条文ミラー（文言取得に使用）: Article 3 / 51 / 53 / 54 / 55 / 111 / 113、Annex XI / XII —
  https://artificialintelligenceact.eu/article/3/ ほか

### `[公式ガイダンス]`
- Commission Guidelines on the scope of the obligations for providers of general-purpose AI models
  established by Regulation (EU) 2024/1689 (AI Act) — C(2025) 5045 final (18.7.2025) / 正式採択
  C(2025) 7719 final (19.11.2025)
  PDF: https://ai-act-service-desk.ec.europa.eu/sites/default/files/2025-07/guidelines_on_the_scope_of_the_obligations_for_generalpurpose_ai_models_established_by_regulation_1cx2atxgq79us4n3x8jfgyy1qlm_118340-3.pdf
  ランディング: https://digital-strategy.ec.europa.eu/en/library/guidelines-scope-obligations-providers-general-purpose-ai-models-under-ai-act
- General-Purpose AI Code of Practice（2025-07-10） — https://digital-strategy.ec.europa.eu/en/policies/contents-code-gpai 、本文 https://code-of-practice.ai/
- Explanatory Notice and Template for the Public Summary of Training Content for general-purpose AI
  models（2025-07-24） — https://digital-strategy.ec.europa.eu/en/library/explanatory-notice-and-template-public-summary-training-content-general-purpose-ai-models
  発表: https://digital-strategy.ec.europa.eu/en/news/commission-presents-template-general-purpose-ai-model-providers-summarise-data-used-train-their
- FAQ: https://digital-strategy.ec.europa.eu/en/faqs/guidelines-obligations-general-purpose-ai-providers
- GPAI Q&A: https://digital-strategy.ec.europa.eu/en/faqs/general-purpose-ai-models-ai-act-questions-answers

### `[二次解説]`
- Security Boulevard, "The EU AI Act for the Downstream Provider: What You Owe When You Just Call an API"（2026-09-09） — https://securityboulevard.com/2026/09/the-eu-ai-act-for-the-downstream-provider-what-you-owe-when-you-just-call-an-api/
- Mayer Brown（2026-07） — https://www.mayerbrown.com/en/insights/publications/2026/07/eu-ai-act-news-digital-omnibus-on-ai-new-guidance-on-risk-classification-gpai-and-transparency-obligations
- Freshfields "EU AI Act unpacked #34: The final Digital Omnibus on AI" — https://www.freshfields.com/en/our-thinking/blogs/technology-quotient/eu-ai-act-unpacked-34-the-final-digital-omnibus-on-ai-key-amendments-to-the-a-102nber
- Gibson Dunn "EU AI Act Omnibus Agreement" — https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/
- Paul Weiss（Guidelines + Template） — https://www.paulweiss.com/insights/client-memos/eu-commission-publishes-guidelines-on-general-purpose-ai-obligations-as-well-as-training-data-disclosure-template-further-clarity-as-the-countdown-to-enforcement-begins
- WilmerHale（Guidelines / Template） — https://www.wilmerhale.com/en/insights/blogs/wilmerhale-privacy-and-cybersecurity-law/20250724-european-commission-issues-guidelines-for-providers-of-general-purpose-ai-models
- CMS "General-purpose AI models: Obligations and roles for Providers and downstream modifiers" — https://cms.law/en/swe/legal-updates/general-purpose-ai-models-obligations-and-roles-for-providers-and-downstream-modifiers-under-the-eu-ai-act
- Wikipedia "General-Purpose AI Code of Practice" — https://en.wikipedia.org/wiki/General-Purpose_AI_Code_of_Practice
- AI Provider Trust Registry（署名者追跡） — https://aiprovidertrust.com/questions/gpai-code-of-practice/
- artificialintelligenceact.eu "Overview of Guidelines for GPAI Models" — https://artificialintelligenceact.eu/gpai-guidelines-overview/
- lawandtechnology.eu（Reg 2026/1744 の OJ 掲載） — https://lawandtechnology.eu/en/digital-omnibus-on-ai-official-journal-regulation-2026-1744/

---

## 確認できなかったこと

1. **EUR-Lex 原典による Article 3 の逐語照合。** eur-lex.europa.eu の AI Act 全文 HTML は容量が
   大きく、自動取得ではプリアンブル（前文 67 付近）までしか到達できなかった。§ 1 の定義文言は
   条文ミラー（artificialintelligenceact.eu）から取得した。文言は正確と考えられるが、
   **一次原典での一字一句の照合はできていない**。同じ理由で Art. 51 / 53 / 54 / 55 / 111 / 113、
   Annex XI / XII も同ミラー経由である。

2. **Article 51(2) の完全な原文一文。** 「shall be presumed to have high impact capabilities」
   「greater than 10^25」「floating point operations」という要素は確認できたが、取得ツールが
   一部を要約形で返したため、条文一文をそのまま提示することは**厳密にはできていない**。
   数値 10^25 と「推定規定である」という性質は複数出典で一致しており確実。

3. **Article 51(1)(a)(b) および Annex XIII の逐語。** systemic risk 分類の第二経路（委員会の
   職権決定、Annex XIII の基準）は概略のみ確認。Annex XIII の項目は未取得。

4. **Article 56 の逐語。** 行動規範の法的位置づけは Art. 53(4)（逐語取得済み）と Art. 55(2)、
   およびガイドライン第 94 項（逐語取得済み）が引用する Art. 56(6) から再構成した。
   **Art. 56 本文そのものは取得していない。**

5. **Article 101 の逐語。** 制裁金の上限（3% / 1,500 万ユーロ）と四つの根拠は `[二次解説]` の
   複数一致による。**条文本文は未取得。**

6. **訓練コンテンツ要約テンプレート本文の逐条確認。** 公表日（2025-07-24）と「必須様式である」
   ことは公式発表で確認したが、テンプレート本体（3 節構成、6 か月ごとの更新推奨、欠落データの
   開示要件など）は `[二次解説]` 経由である。テンプレート PDF 自体は取得していない。

7. **Regulation (EU) 2026/1744 の本文。** EUR-Lex の該当 URL は特定したが、**本文は取得していない**。
   OJ 掲載日（2026-07-24）、発効日（2026-07-27）、高リスクの新期日（2027-12-02 / 2028-08-02）、
   「GPAI は変更なし」の三点は、複数の `[二次解説]`（Freshfields、Gibson Dunn、Hunton、Cooley、
   lawandtechnology.eu 等）が一致しているが、一次照合はされていない。
   **とくに「Art. 113(b) の 2025-08-02 が変更されていない」ことは、統合版条文で確認すべき。**

8. **prompting / RAG / system prompt についてのガイドライン明文。** **存在しない。**
   PDF 全文を検索した結果、これらの語は GPAI Guidelines 本文に現れない（"prompts" は音楽生成
   モデルの例にのみ出現）。§ 5.3 の結論は第 57 項と第 62–63 項からの**推論**であり、
   明文の根拠ではない。この点は報告書で明示すべき。

9. **RAG の位置づけについての食い違い。** ある `[二次解説]` の集約は RAG を「分析の対象技術」
   （fine-tuning、distillation と並べて）に含め、別の記述は「軽い介入」に分類する。
   1/3 compute 基準の下では RAG は常にゼロ compute であり provider 化しないと読むのが自然だが、
   **委員会の明示的な立場は確認できなかった**。

10. **Code of Practice の署名者数。** 委員会公式ページ経由で **21 社**（xAI を Safety and Security
    章のみとして別記）、第三者追跡サイトで **23 件**（2026-07-05 時点）。委員会ページに継続更新の
    注記があるため時点差と考えられるが、**2026-09-13 時点の確定した署名者数は確認できなかった**。
    Meta が署名していないこと、xAI が Safety and Security 章のみであることは一致している。

11. **Code of Practice 本文の 2026 年改訂の有無。** 公式ページの最終更新は 2026-07-31 だが、
    これが署名者リストの更新なのか本文の改訂なのかは**区別できなかった**。本文の版数・改訂履歴は
    確認していない。

12. **ガイドラインの 2026 年改訂の有無。** 第 116 項は委員会が必要に応じて見直すと述べている。
    2025-11-19 の正式採択（C(2025) 7719 final）以降に改訂があったかどうかは**確認できなかった**。
    ある取得結果が「Guidelines publication date: July 18, 2026」と返したが、これは 2025 年の
    誤りである（PDF 表紙に "Brussels, 18.7.2025" と明記）。2026 年版の存在を示す証拠は得られなかった。

13. **Art. 50（透明性義務）の逐語。** 2026-08-02 から適用されていることと概要は `[二次解説]` で
    確認したが、**条文本文は取得していない**。下流の AI システム provider にとって現時点で最も
    直接効いている条文であるため、別途の逐語確認が望ましい。

14. **ガイドライン第 67 項の内部参照の誤り。** 同項は "the criterion set out in paragraph 60" と
    書くが、基準が置かれているのは第 63 項である。これがガイドライン本文の誤植なのか、後続版で
    修正されたのかは**確認できなかった**。
