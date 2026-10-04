# R3 — 誰が何の義務を負うのか（役割の定義と義務の中身）

作成日: 2026-09-13 / 調査担当: R3 research seat
用途: 一次資料集。人向けの読み物ではなく、後段の書き手が引用するための検証済み事実の集積。

---

## 0. 前提 — 2026 年に条文が変わっている（この章を読まずに先へ進まないこと）

EU AI Act（Regulation (EU) 2024/1689）は **2026 年 7 月に初めて改正された**。
本ドシエの条文引用は、特記しない限り **改正後（consolidated 版 27.07.2026）** の текст に基づく。

| 項目 | 内容 | 出典 |
|---|---|---|
| 改正法 | Regulation (EU) 2026/1744 of 8 July 2026, "Digital Omnibus on AI" | [条文] EUR-Lex CELEX:32026R1744 |
| OJ 掲載 | `OJ L, 2026/1744, 24.7.2026` | [条文] EUR-Lex 書誌 CELEX:32026R1744 |
| 発効 | 2026-07-27（Date of effect: 27/07/2026; Entry into force） | [条文] 同上 |
| 現行 consolidated 版 | `02024R1689 — EN — 27.07.2026 — 001.001` | [条文] EUR-Lex CELEX:02024R1689-20260727 |

出典 URL:
- 原典（2024 OJ）: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689 [条文]
- 改正法: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32026R1744 [条文]
- 現行 consolidated: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:02024R1689-20260727 [条文]

consolidated 版の冒頭に置かれた注記（EUR-Lex の定型文）:
> "This text is meant purely as a documentation tool and has no legal effect."
> （この文書は資料としてのものであり、法的効力を持たない。正本は OJ 掲載版。）

### 本ドシエの主題に対する 2026 年改正の影響（一覧）

| 条 | 改正の有無 | 何が変わったか |
|---|---|---|
| Art. 3 定義（provider / deployer / importer / distributor / AR / placing / putting / making available） | **変更なし** | 2024 年の文言がそのまま現行 |
| Art. 4 AI リテラシー | **全文差し替え** | "ensure a sufficient level" → "take measures to support the development"。努力義務化 |
| **Art. 4a（新設）** | **新設** | 旧 Art. 10(5) がここへ移動し、対象が拡大 |
| Art. 9 / 12 / 13 / 14 / 15 | 変更なし | — |
| Art. 10 | 改正 | 1 項・6 項差し替え、**5 項は削除**（→ Art. 4a へ） |
| Art. 11(1) 第2段 | 改正 | 簡易様式の対象に SMC（small mid-cap）追加 |
| Art. 16 / 18 / 19 / 20 / 21 / 22 | 変更なし | — |
| Art. 17 | 2 項のみ改正 | 比例原則に SME/SMC を明記 |
| Art. 25 | 2 項・4 項第1段 改正 | 初期 provider の協力義務が (a)(b)(c) に具体化。4 項に "AI model" 追加 |
| Art. 26 | 変更なし | — |
| Art. 27 | 4 項・5 項改正 | DPIA との相互参照を明示的に許容 |
| Art. 43 | 3 項のみ改正 | Annex I 関連。**1 項・2 項（Annex III の振り分け）は変更なし** |
| Art. 47 / 48 / 49 / 71 | 変更なし | — |
| Art. 50 | 7 項のみ改正 | Commission の implementing act 権限の整理。1〜6 項は変更なし |
| Art. 113 適用日 | 改正 | 高リスク（Ch. III §1–3）の適用が **2027-12-02 / 2028-08-02** へ延期 |
| Annex VIII | 改正 | Section B の points 7, 9 削除（Art. 49(2) 登録の簡素化） |

---

## 1. 役割の定義 — Article 3

すべて [条文] / 出典: consolidated 版 Article 3（原典 Article 3 と同一文言。2026 年改正で変更されていない）
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:02024R1689-20260727

### 1.1 provider と deployer の違い — 本ドシエで最も重要な一点

この Regulation の義務配分は、ほぼすべてこの一本の線で決まる。線の引き方は「作ったかどうか」ではなく、
**自分の名前・商標で市場に出したか（provider）／他人のものを自分の権限の下で使っているか（deployer）** である。

```
                    その AI システムを EU 市場に
                    「自分の名前 or 商標」で出したか？
                              |
              ┌───────── YES ─────────┐          └── NO ──┐
              |                                            |
         ★ PROVIDER                              自分の権限の下で使っているか？
   （Art. 8–22 のほぼ全部を負う）                          |
   ・要求事項適合（Art. 8–15）                    ┌── YES ──┴── NO ──┐
   ・品質管理体制（Art. 17）                      |                    |
   ・技術文書 10 年保管（Art. 18）            ★ DEPLOYER      　 供給網上の中継役
   ・ログ保管（Art. 19）                    （Art. 26、条件付き    ・EU 内で第三国製品を
   ・適合性評価（Art. 43）                    で Art. 27 FRIA）      市場に出す → IMPORTER
   ・CE マーキング（Art. 48）                                       ・それ以外の流通
   ・EU DB 登録（Art. 49）                    ※個人の非職業的利用      → DISTRIBUTOR
   ・第三国なら AR 選任（Art. 22）               は deployer でない
```

**(3) provider** [条文]
> "'provider' means a natural or legal person, public authority, agency or other body that develops an AI system or a general-purpose AI model or that has an AI system or a general-purpose AI model developed and places it on the market or puts the AI system into service under its own name or trademark, whether for payment or free of charge;"

日本語の要点: AI システムまたは汎用 AI モデルを自分で開発した者、あるいは開発させた者であって、それを **自分の名前または商標で** 市場に出す、あるいはサービス提供を開始する者。**有償か無償かを問わない**（無料公開でも provider になる）。

**(4) deployer** [条文]
> "'deployer' means a natural or legal person, public authority, agency or other body using an AI system under its authority except where the AI system is used in the course of a personal non-professional activity;"

日本語の要点: AI システムを **自分の権限の下で使っている** 者。個人が職業と無関係に使う場合は除かれる。したがって研究室・病院・企業が他社の AI を業務で使えば deployer である。

**(5) authorised representative（域内代理人）** [条文]
> "'authorised representative' means a natural or legal person located or established in the Union who has received and accepted a written mandate from a provider of an AI system or a general-purpose AI model to, respectively, perform and carry out on its behalf the obligations and procedures established by this Regulation;"

日本語の要点: EU 域内にいて、provider から **書面による委任** を受け、それを承諾した者。provider に代わって本規則上の義務と手続を実行する。

**(6) importer** [条文]
> "'importer' means a natural or legal person located or established in the Union that places on the market an AI system that bears the name or trademark of a natural or legal person established in a third country;"

日本語の要点: EU 域内にいて、**第三国の者の名前・商標が付いた** AI システムを EU 市場に出す者。

**(7) distributor** [条文]
> "'distributor' means a natural or legal person in the supply chain, other than the provider or the importer, that makes an AI system available on the Union market;"

日本語の要点: 供給網の中で、provider でも importer でもなく、AI システムを EU 市場で入手可能にする者。

参考 **(8) operator**（上記の総称）[条文]
> "'operator' means a provider, product manufacturer, deployer, authorised representative, importer or distributor;"

### 1.2 市場投入に関する三つの動詞

**(9) placing on the market（上市）** [条文]
> "'placing on the market' means the first making available of an AI system or a general-purpose AI model on the Union market;"

日本語の要点: EU 市場で **初めて** 入手可能にすること。一回きりの事象。

**(10) making available on the market（市場での提供）** [条文]
> "'making available on the market' means the supply of an AI system or a general-purpose AI model for distribution or use on the Union market in the course of a commercial activity, whether in return for payment or free of charge;"

日本語の要点: **商業活動の過程で** 流通または利用のために供給すること。有償・無償を問わない。「商業活動の過程で」が条件なので、純粋に非商業な配布はここに入らない。

**(11) putting into service（サービス提供開始）** [条文]
> "'putting into service' means the supply of an AI system for first use directly to the deployer or for own use in the Union for its intended purpose;"

日本語の要点: deployer に直接、初回利用のために供給すること。**あるいは EU 域内で自分自身が使うために** 意図した目的で供給すること。つまり **外部に一切売らず社内で自作 AI を使い始めるだけでも "putting into service" に当たり、その組織は provider になりうる**。これは見落とされやすい。

### 1.3 関連する二つの定義（Art. 25 の理解に必須）

**(12) intended purpose（意図された目的）** [条文]
> "'intended purpose' means the use for which an AI system is intended by the provider, including the specific context and conditions of use, as specified in the information supplied by the provider in the instructions for use, promotional or sales materials and statements, as well as in the technical documentation;"

日本語の要点: provider が意図した用途。使用説明書・販促資料・技術文書に書かれた内容で決まる。**provider が文書に何を書いたかが、法的な「用途」を決める**。

**(23) substantial modification（重大な改変）** [条文]
> "'substantial modification' means a change to an AI system after its placing on the market or putting into service which is not foreseen or planned in the initial conformity assessment carried out by the provider and as a result of which the compliance of the AI system with the requirements set out in Chapter III, Section 2 is affected or results in a modification to the intended purpose for which the AI system has been assessed;"

日本語の要点: 上市後の変更のうち、**当初の適合性評価で予見・計画されていなかった** もので、かつ Chapter III Section 2（Art. 8–15）への適合に影響するか、評価済みの意図された目的を変えるもの。

---

## 2. Article 25 — 役割が移る場面（サービス構築者にとっての要）

[条文] 出典: consolidated Article 25。**1 項は 2026 年改正で変更されていない**。2 項と 4 項第1段が差し替えられた。

### 2.1 第 1 項 — provider になってしまう三つの場合（原文のまま）

> "1. Any distributor, importer, deployer or other third-party shall be considered to be a provider of a high-risk AI system for the purposes of this Regulation and shall be subject to the obligations of the provider under Article 16, in any of the following circumstances:
>
> (a) they put their name or trademark on a high-risk AI system already placed on the market or put into service, without prejudice to contractual arrangements stipulating that the obligations are otherwise allocated;
>
> (b) they make a substantial modification to a high-risk AI system that has already been placed on the market or has already been put into service in such a way that it remains a high-risk AI system pursuant to Article 6;
>
> (c) they modify the intended purpose of an AI system, including a general-purpose AI system, which has not been classified as high-risk and has already been placed on the market or put into service in such a way that the AI system concerned becomes a high-risk AI system in accordance with Article 6."

日本語の要点:
- **柱書**: distributor・importer・deployer・**その他の第三者**（"other third-party"）は、以下のいずれかに当たれば高リスク AI システムの provider **とみなされ**、Article 16 の provider 義務を全部負う。「その他の第三者」が入っているため、供給網上の位置に関係なく誰でも当たりうる。
- **(a) 名前・商標を載せた場合**: 既に市場に出ている高リスク AI システムに自分の名前や商標を付けた。契約で義務を別配分していても、それとは無関係に（"without prejudice to"）この規定は働く。**契約で逃げられない**。
- **(b) 重大な改変をした場合**: 既に市場に出ている高リスク AI システムに substantial modification（定義は Art. 3(23)、上記 1.3）を加え、それでもなお高リスクのままである場合。
- **(c) 用途を変えて高リスク化させた場合**: 高リスクに分類されていなかった AI システム（**汎用 AI システムを含む**）の intended purpose を変更し、その結果 Article 6 の下で高リスクになった場合。

**(c) が他人のモデルの上にサービスを作る者にとって決定的である。** 汎用モデルそれ自体は高リスクでなくても、それを Annex III の用途（例: 雇用、教育、必須サービスへのアクセス、医療の一部）に向けた製品として組み上げた時点で、組み上げた側が provider になる。

### 2.2 第 2 項 — 元の provider はどうなるか（2026 年改正後の現行文）

> "2. Where the circumstances referred to in paragraph 1 occur, the provider that initially placed the AI system on the market or put it into service shall no longer be considered to be a provider of that specific AI system for the purposes of this Regulation.
>
> That initial provider shall closely cooperate with new providers and shall make available the necessary information and provide the reasonably expected technical access and other assistance that are required for the fulfilment of the obligations set out in this Regulation, in particular with regard to compliance with the conformity assessment of high-risk AI systems.
>
> In particular, the obligation laid down in the second subparagraph shall include, where relevant for the purposes specified therein, the following:
> (a) making available of technical documentation sufficient to assess compliance with the requirements laid down in Article 16;
> (b) informing the new providers about known limitations and failure modes; and
> (c) providing the new providers with targeted technical access, including for testing and validation.
>
> This paragraph shall not apply in cases where the initial provider has clearly specified that its AI system is not to be changed into a high-risk AI system and therefore does not fall under the obligation to cooperate with the new providers and hand over the documentation."

日本語の要点: 1 項の事情が生じると、**元の provider はその特定のシステムについて provider でなくなる**。ただし新しい provider に密接に協力し、必要情報・合理的に期待される技術アクセス・その他の支援を提供しなければならない。2026 年改正はこの協力義務の中身を (a)(b)(c) に具体化した — 技術文書の提供、**既知の限界と故障モードの通知**、テストと検証のための的を絞った技術アクセス。
**最後の一文が実務上の抜け道である**: 元の provider が「自社の AI システムは高リスクに変えられてはならない」と明確に指定していた場合、この協力義務（文書引き渡し義務を含む）は生じない。多くのモデル提供者が利用規約でこれを書く動機がある。

### 2.3 第 3 項 — 製品メーカーが provider とみなされる場合（変更なし）

> "3. In the case of high-risk AI systems that are safety components of products covered by the Union harmonisation legislation listed in Section A of Annex I, the product manufacturer shall be considered to be the provider of the high-risk AI system, and shall be subject to the obligations under Article 16 under either of the following circumstances:
> (a) the high-risk AI system is placed on the market together with the product under the name or trademark of the product manufacturer;
> (b) the high-risk AI system is put into service under the name or trademark of the product manufacturer after the product has been placed on the market."

### 2.4 第 4 項 — 第三者供給者との書面契約（2026 年改正後の現行文）

> "4. The provider of a high-risk AI system and the third party that supplies an AI system, AI model, tools, services, components, or processes that are used or integrated in a high-risk AI system shall, by written agreement, specify the necessary information, capabilities, technical access and other assistance based on the generally acknowledged state of the art, in order to enable the provider of the high-risk AI system to fully comply with the obligations set out in this Regulation. This paragraph shall not apply to third parties making accessible to the public tools, services, processes, or components, other than general-purpose AI models, under a free and open-source licence."

日本語の要点: 高リスク AI システムの provider と、そこに組み込まれる部品・道具・サービス・プロセス（2026 年改正で **"AI model" が明示的に追加された**）を供給する第三者は、**書面による合意** で必要な情報・能力・技術アクセス・支援を定めなければならない。
免除: フリー／オープンソースライセンスで公開されている道具・サービス・プロセス・部品には適用されない。ただし **汎用 AI モデル（general-purpose AI models）はこの免除から除外されている** — OSS の汎用モデルであっても、この書面契約義務の免除は受けられない。

第 5 項（変更なし）: 2 項と 3 項は知的財産権・営業秘密の保護を妨げない。

---

## 3. 高リスク AI への要求 — Chapter III Section 2（Art. 8–15）

すべて [条文]。出典: consolidated Article 8–15。
**適用日に注意**: Chapter III Section 2 は 2026 年改正により、Annex III 系は **2027-12-02**、Annex I 系は **2028-08-02** からの適用（本ドシエ §9）。

### Art. 8 — 要求事項の遵守（総則）
日本語一行: 高リスク AI システムは、意図された目的と **一般に認められた技術水準** を考慮して、本節の要求事項を満たさなければならない。
原文の要となる一句:
> "taking into account their intended purpose as well as the generally acknowledged state of the art on AI and AI-related technologies"

### Art. 9 — リスク管理体制（risk management system）
日本語一行: システムの **全ライフサイクルを通じて継続的・反復的に** 回るリスク管理の仕組みを、確立し・実施し・文書化し・維持しなければならない。
原文の要となる一句:
> "a continuous iterative process planned and run throughout the entire lifecycle of a high-risk AI system, requiring regular systematic review and updating"

構成される 4 段階（Art. 9(2), 原文）:
> "(a) the identification and analysis of the known and the reasonably foreseeable risks ...; (b) the estimation and evaluation of the risks that may emerge when the high-risk AI system is used in accordance with its intended purpose, and under conditions of reasonably foreseeable misuse; (c) the evaluation of other risks possibly arising, based on the analysis of data gathered from the post-market monitoring system referred to in Article 72; (d) the adoption of appropriate and targeted risk management measures designed to address the risks identified pursuant to point (a)."

付随して押さえる点:
- 残留リスクは「許容可能」と判断される水準まで下げること（9(5)）: "the relevant residual risk associated with each hazard, as well as the overall residual risk of the high-risk AI systems is judged to be acceptable"
- 試験は上市前に必ず行い、**事前に定めた指標と確率的閾値** に照らして行うこと（9(8)）: "Testing shall be carried out against prior defined metrics and probabilistic thresholds that are appropriate to the intended purpose"
- **18 歳未満の者への悪影響** を検討すること（9(9)）: "whether in view of its intended purpose the high-risk AI system is likely to have an adverse impact on persons under the age of 18 and, as appropriate, other vulnerable groups"

### Art. 10 — データとデータガバナンス

**重要: 2026 年改正で 10(5) は削除され、Art. 4a に移された。** 依頼で指定された「10(5) とその 5 条件」は、現行法では **Article 4a(1) の (a)–(f)** として存在する。以下、現行文で示す。

**10(1)（2026 年改正後の現行文）** [条文]
> "1. High-risk AI systems which make use of techniques involving the training of AI models with data shall be developed on the basis of training, validation and testing data sets that meet the quality criteria referred to in paragraphs 2, 3 and 4 of this Article and in Article 4a(1) whenever such data sets are used."

（参考・旧文言: "... that meet the quality criteria referred to in paragraphs 2 to 5 whenever such data sets are used."）

**10(2)（変更なし、原文のまま）** [条文]
> "2. Training, validation and testing data sets shall be subject to data governance and management practices appropriate for the intended purpose of the high-risk AI system. Those practices shall concern in particular:
> (a) the relevant design choices;
> (b) data collection processes and the origin of data, and in the case of personal data, the original purpose of the data collection;
> (c) relevant data-preparation processing operations, such as annotation, labelling, cleaning, updating, enrichment and aggregation;
> (d) the formulation of assumptions, in particular with respect to the information that the data are supposed to measure and represent;
> (e) an assessment of the availability, quantity and suitability of the data sets that are needed;
> (f) examination in view of possible biases that are likely to affect the health and safety of persons, have a negative impact on fundamental rights or lead to discrimination prohibited under Union law, especially where data outputs influence inputs for future operations;
> (g) appropriate measures to detect, prevent and mitigate possible biases identified according to point (f);
> (h) the identification of relevant data gaps or shortcomings that prevent compliance with this Regulation, and how those gaps and shortcomings can be addressed."

日本語の要点: 訓練・検証・試験の各データセットは、意図された目的に見合ったデータガバナンス実務の対象となる。**(b) 出所と当初の収集目的**、**(f) バイアスの検査**、**(g) 検出されたバイアスへの対処措置**、**(h) データの欠落の特定** が中核。

**10(3)（変更なし、原文のまま）** [条文]
> "3. Training, validation and testing data sets shall be relevant, sufficiently representative, and to the best extent possible, free of errors and complete in view of the intended purpose. They shall have the appropriate statistical properties, including, where applicable, as regards the persons or groups of persons in relation to whom the high-risk AI system is intended to be used. Those characteristics of the data sets may be met at the level of individual data sets or at the level of a combination thereof."

日本語の要点: 関連性があり、十分に代表性があり、**可能な限り** 誤りがなく完全であること。"to the best extent possible" が付いているのは 3 項のうち「誤りがなく完全」の部分だけで、「関連性」「十分な代表性」にはこの限定語が掛かっていない。統計的性質は、個々のデータセット単位でも、複数を合わせた単位でも満たしてよい。

**10(4)（変更なし）**
> "4. Data sets shall take into account, to the extent required by the intended purpose, the characteristics or elements that are particular to the specific geographical, contextual, behavioural or functional setting within which the high-risk AI system is intended to be used."

**10(5) — 削除済み。** consolidated 版では該当箇所が `▼M1 —————` と表示される（EUR-Lex の削除記号）。[条文]

**10(6)（2026 年改正後の現行文）**
> "6. For the development of high-risk AI systems not using techniques involving the training of AI models, paragraphs 2, 3 and 4 of this Article and Article 4a(1) shall apply only to the testing data sets."

### Art. 4a（新設）— バイアス検出・是正のための特別カテゴリー個人データ処理

[条文] 出典: consolidated Article 4a（Regulation (EU) 2026/1744 Article 1, point (6) により新設）
旧 Art. 10(5) の後継。**Chapter I に置かれたことに注意** — 高リスクの章ではない。

**4a(1) — 高リスク AI の provider について（旧 10(5) に相当。5 条件 → 6 条件として現行化）**
> "1. To the extent strictly necessary to ensure bias detection and correction in relation to high-risk AI systems in accordance with Article 10(2), points (f) and (g), of this Regulation, providers of such systems may exceptionally process special categories of personal data, subject to appropriate safeguards for the fundamental rights and freedoms of natural persons. In addition to the provisions set out in Regulations (EU) 2016/679 and (EU) 2018/1725 and Directive (EU) 2016/680, as applicable, all the following conditions shall be met in order for such processing to occur:
> (a) the bias detection and correction cannot be effectively fulfilled by processing other data, including synthetic or anonymised data;
> (b) the special categories of personal data are subject to technical limitations on the re-use of personal data, and state-of-the-art security and privacy-preserving measures, including pseudonymisation;
> (c) the special categories of personal data are subject to measures to ensure that the personal data processed are secured and protected, subject to suitable safeguards, including strict controls and documentation of the access, to avoid misuse and to ensure that only authorised persons have access to those personal data with appropriate confidentiality obligations;
> (d) the special categories of personal data are not transmitted, transferred or otherwise accessed by other parties;
> (e) the special categories of personal data are deleted once the bias has been corrected or the personal data has reached the end of its retention period, whichever comes first; and
> (f) the records of processing activities pursuant to Regulations (EU) 2016/679 and (EU) 2018/1725 and Directive (EU) 2016/680 include the reasons why the processing of special categories of personal data was strictly necessary to detect and correct biases, and why that objective could not be achieved by processing other data."

日本語の要点（条件の読み下し）:
条件の柱は「**厳に必要な範囲で（strictly necessary）**、Art. 10(2)(f)(g) のバイアス検出・是正のためだけに、**例外的に**」である。GDPR（Regulation (EU) 2016/679）等の規定に **加えて**、下記すべてを満たす必要がある。
- (a) 他のデータ — 合成データや匿名化データを含む — では実効的に達成できないこと。
- (b) 再利用に技術的制限が掛かっており、仮名化を含む最新技術の安全・プライバシー保護措置が施されていること。
- (c) アクセスの厳格な管理と記録を含む保護措置が施され、守秘義務を負う許可された者のみがアクセスできること。
- (d) 他の当事者に送信・移転・アクセスされないこと。
- (e) バイアスが是正された時点、または保存期間の満了時点の **いずれか早い方** で削除されること。
- (f) GDPR 等の処理活動記録に、なぜこの処理が厳に必要だったか、なぜ他のデータでは目的を達成できなかったかの理由が記載されること。

**注（旧 10(5) との差分）**: 旧条文は 5 条件 (a)–(e) + 記録要件 (f) の構成で、現行 4a(1) と実質同一である。依頼文の「五つの条件」は旧 (a)–(e) を指すと解される。文言上の小差: 旧 (b) "re-use of the personal data" → 現行 "re-use of personal data"、旧 "must be met" → 現行 "shall be met"、現行は "as applicable" を追加。

**4a(2) — 新設された拡張部分（旧 10(5) には存在しなかった）**
> "2. Providers and deployers of other AI systems and models and deployers of high-risk AI systems may exceptionally process special categories of personal data to the extent that:
> (a) such processing is strictly necessary to ensure bias detection and correction in view of possible biases that are likely to affect the health and safety of persons, have a negative impact on fundamental rights or lead to discrimination prohibited pursuant to Union law, especially where data outputs influence inputs for future operations; and
> (b) all of the conditions and safeguards set out in paragraph 1 are applied.
>
> This paragraph does not create any obligation to conduct such bias detection and correction."

日本語の要点: **高リスク以外の AI システム・モデルの provider と deployer、および高リスク AI システムの deployer** にも、同じ条件下で特別カテゴリー個人データの例外的処理の道が開かれた。ただし最後の一文が明示するとおり、**これはバイアス検出・是正を行う義務を課すものではない** — 許可であって義務ではない。

### Art. 11 + Annex IV — 技術文書
日本語一行: 上市前に技術文書を作成し、**最新の状態に保つ**。中身は最低限 Annex IV の項目を含む。
原文の要となる一句（11(1) 第1段、変更なし）:
> "The technical documentation of a high-risk AI system shall be drawn up before that system is placed on the market or put into service and shall be kept up-to date."

11(1) 第2段（2026 年改正後の現行文）— 簡易様式の対象:
> "SMEs, including start-ups, and SMCs, may provide the elements of the technical documentation specified in Annex IV in a simplified manner."
（改正前は "SMEs, including start-ups, may ..." で、SMC = small mid-cap enterprise は含まれていなかった。SMC の定義は新 Art. 3(14b)、Recommendation (EU) 2025/1099 の Annex point (2) を参照。）

**Annex IV の見出し（原文）**:
> "The technical documentation referred to in Article 11(1) shall contain at least the following information, as applicable to the relevant AI system:"

Annex IV point 1「システムの一般的記述」に含まれるもの（原文抜粋）:
> "(a) its intended purpose, the name of the provider and the version of the system reflecting its relation to previous versions; ... (d) the description of all the forms in which the AI system is placed on the market or put into service, such as software packages embedded into hardware, downloads, or APIs; ... (g) a basic description of the user-interface provided to the deployer;"

Annex IV point 2「要素と開発プロセスの詳細な記述」に含まれるもの（原文抜粋、(a)(b)(c)）:
> "(a) the methods and steps performed for the development of the AI system, including, where relevant, recourse to pre-trained systems or tools provided by third parties and how those were used, integrated or modified by the provider;"
> "(b) the design specifications of the system, namely the general logic of the AI system and of the algorithms; the key design choices including the rationale and assumptions made, ... what the system is designed to optimise for, and the relevance of the different parameters; the description of the expected output and output quality of the system; the decisions about any possible trade-off made regarding the technical solutions adopted to comply with the requirements set out in Chapter III, Section 2;"
> "(c) the description of the system architecture explaining how software components build on or feed into each other and integrate into the overall processing; the computational resources used to develop, train, test and validate the AI system;"

**Annex IV 2(a) は他人のモデルの上に作る者にとって重要**: "recourse to pre-trained systems or tools provided by third parties and how those were used, integrated or modified by the provider" — 事前学習済みモデルを使ったこと、それをどう使い・統合し・改変したかを技術文書に書く義務がある。
Annex IV の全項目（point 1〜9）の完全な列挙は本ドシエでは省略。必要なら consolidated 版 ANNEX IV を直接参照のこと。

### Art. 12 — 記録保持 / 自動ログ

**何が記録できなければならないか（12(1)(2)、変更なし、原文）**:
> "1. High-risk AI systems shall technically allow for the automatic recording of events (logs) over the lifetime of the system.
> 2. In order to ensure a level of traceability of the functioning of a high-risk AI system that is appropriate to the intended purpose of the system, logging capabilities shall enable the recording of events relevant for:
> (a) identifying situations that may result in the high-risk AI system presenting a risk within the meaning of Article 79(1) or in a substantial modification;
> (b) facilitating the post-market monitoring referred to in Article 72; and
> (c) monitoring the operation of high-risk AI systems referred to in Article 26(5)."

日本語の要点: **ログ機能を備えること自体が製品要求事項**。何を記録するかは (a) リスク発生や重大な改変につながりうる状況の特定、(b) 上市後モニタリングの支援、(c) deployer によるシステム運用の監視、の三つに resolve する。

**Annex III 点 1(a)（遠隔生体識別システム）についての最低限（12(3)、原文）**:
> "3. For high-risk AI systems referred to in point 1 (a), of Annex III, the logging capabilities shall provide, at a minimum:
> (a) recording of the period of each use of the system (start date and time and end date and time of each use);
> (b) the reference database against which input data has been checked by the system;
> (c) the input data for which the search has led to a match;
> (d) the identification of the natural persons involved in the verification of the results, as referred to in Article 14(5)."

**Art. 19 — ログの保管期間（最低 6 か月）** [条文]（変更なし）
> "1. Providers of high-risk AI systems shall keep the logs referred to in Article 12(1), automatically generated by their high-risk AI systems, to the extent such logs are under their control. Without prejudice to applicable Union or national law, the logs shall be kept for a period appropriate to the intended purpose of the high-risk AI system, of at least six months, unless provided otherwise in the applicable Union or national law, in particular in Union law on the protection of personal data."

日本語の要点: **自分の管理下にある限りで（"to the extent such logs are under their control"）** 保管する。期間は意図された目的に見合った期間で、**最低 6 か月**。ただし他の EU 法・国内法、特に個人データ保護法が別段の定めをする場合はそちらが優先する。
**deployer 側にも同じ 6 か月義務がある**（Art. 26(6)、下記 §6.1）。provider と deployer の双方に掛かる点に注意。

### Art. 13 — 透明性と deployer への情報提供

日本語一行: deployer が出力を **解釈でき、適切に使える** ように設計・開発し、使用説明書を添えること。

原文の要となる一句（13(1)）:
> "High-risk AI systems shall be designed and developed in such a way as to ensure that their operation is sufficiently transparent to enable deployers to interpret a system's output and use it appropriately."

使用説明書の性質（13(2)）:
> "High-risk AI systems shall be accompanied by instructions for use in an appropriate digital format or otherwise that include concise, complete, correct and clear information that is relevant, accessible and comprehensible to deployers."

**使用説明書に最低限含めるもの（13(3)、原文全文）**:
> "(a) the identity and the contact details of the provider and, where applicable, of its authorised representative;
> (b) the characteristics, capabilities and limitations of performance of the high-risk AI system, including:
> (i) its intended purpose;
> (ii) the level of accuracy, including its metrics, robustness and cybersecurity referred to in Article 15 against which the high-risk AI system has been tested and validated and which can be expected, and any known and foreseeable circumstances that may have an impact on that expected level of accuracy, robustness and cybersecurity;
> (iii) any known or foreseeable circumstance, related to the use of the high-risk AI system in accordance with its intended purpose or under conditions of reasonably foreseeable misuse, which may lead to risks to the health and safety or fundamental rights referred to in Article 9(2);
> (iv) where applicable, the technical capabilities and characteristics of the high-risk AI system to provide information that is relevant to explain its output;
> (v) when appropriate, its performance regarding specific persons or groups of persons on which the system is intended to be used;
> (vi) when appropriate, specifications for the input data, or any other relevant information in terms of the training, validation and testing data sets used, taking into account the intended purpose of the high-risk AI system;
> (vii) where applicable, information to enable deployers to interpret the output of the high-risk AI system and use it appropriately;
> (c) the changes to the high-risk AI system and its performance which have been pre-determined by the provider at the moment of the initial conformity assessment, if any;
> (d) the human oversight measures referred to in Article 14, including the technical measures put in place to facilitate the interpretation of the outputs of the high-risk AI systems by the deployers;
> (e) the computational and hardware resources needed, the expected lifetime of the high-risk AI system and any necessary maintenance and care measures, including their frequency, to ensure the proper functioning of that AI system, including as regards software updates;
> (f) where relevant, a description of the mechanisms included within the high-risk AI system that allows deployers to properly collect, store and interpret the logs in accordance with Article 12."

日本語の要点（構造）: (a) 誰が作ったか → (b) 何ができて何ができないか（性能・精度指標・既知の限界・入力データ仕様・出力の解釈方法）→ (c) 当初評価時に織り込み済みの変更 → (d) 人間による監督の方法 → (e) 必要な計算資源・想定寿命・保守 → (f) ログの取り扱い方。

### Art. 14 — 人間による監督（human oversight）

日本語一行: **使用中の期間を通じて自然人が実効的に監督できる** よう、人間‑機械インターフェースを含めて設計・開発すること。

原文の要となる一句（14(1)）:
> "High-risk AI systems shall be designed and developed in such a way, including with appropriate human-machine interface tools, that they can be effectively overseen by natural persons during the period in which they are in use."

監督措置の置き場所（14(3)）— provider が組み込むか、deployer が実施できる形で provider が特定するか、またはその両方:
> "(a) measures identified and built, when technically feasible, into the high-risk AI system by the provider before it is placed on the market or put into service;
> (b) measures identified by the provider before placing the high-risk AI system on the market or putting it into service and that are appropriate to be implemented by the deployer."

**監督者ができなければならないこと（14(4)、原文）**:
> "(a) to properly understand the relevant capacities and limitations of the high-risk AI system and be able to duly monitor its operation, including in view of detecting and addressing anomalies, dysfunctions and unexpected performance;
> (b) to remain aware of the possible tendency of automatically relying or over-relying on the output produced by a high-risk AI system (automation bias), in particular for high-risk AI systems used to provide information or recommendations for decisions to be taken by natural persons;
> (c) to correctly interpret the high-risk AI system's output, taking into account, for example, the interpretation tools and methods available;
> (d) to decide, in any particular situation, not to use the high-risk AI system or to otherwise disregard, override or reverse the output of the high-risk AI system;
> (e) to intervene in the operation of the high-risk AI system or interrupt the system through a 'stop' button or a similar procedure that allows the system to come to a halt in a safe state."

日本語の要点: (b) の **automation bias（自動化バイアス — 出力に自動的に頼りすぎる傾向）** が条文に明記されている点、(d) の「使わない／無視する／覆す」権限、(e) の **停止ボタンによる安全な状態での停止** が中核。

14(5)（Annex III 点 1(a) 系の追加要求、原文）:
> "no action or decision is taken by the deployer on the basis of the identification resulting from the system unless that identification has been separately verified and confirmed by at least two natural persons with the necessary competence, training and authority."
日本語: **二人以上の自然人による別個の検証・確認** がない限り、識別結果に基づく行為・決定をしてはならない（いわゆる four-eyes 原則）。法執行・移民・国境管理・庇護の目的で、EU 法または国内法がこの要求を不均衡と判断する場合は適用されない。

### Art. 15 — 精度、頑健性、サイバーセキュリティ

日本語一行: **ライフサイクル全体を通じて一貫して** 適切な水準の精度・頑健性・サイバーセキュリティを達成すること。

原文の要となる一句（15(1)）:
> "High-risk AI systems shall be designed and developed in such a way that they achieve an appropriate level of accuracy, robustness, and cybersecurity, and that they perform consistently in those respects throughout their lifecycle."

精度指標の開示（15(3)）:
> "The levels of accuracy and the relevant accuracy metrics of high-risk AI systems shall be declared in the accompanying instructions of use."

フィードバックループ（15(4) 第3段）:
> "High-risk AI systems that continue to learn after being placed on the market or put into service shall be developed in such a way as to eliminate or reduce as far as possible the risk of possibly biased outputs influencing input for future operations (feedback loops), and as to ensure that any such feedback loops are duly addressed with appropriate mitigation measures."

**AI 固有の攻撃類型（15(5) 第3段、原文）** — 条文が攻撃の種類を名指ししている珍しい箇所:
> "The technical solutions to address AI specific vulnerabilities shall include, where appropriate, measures to prevent, detect, respond to, resolve and control for attacks trying to manipulate the training data set (data poisoning), or pre-trained components used in training (model poisoning), inputs designed to cause the AI model to make a mistake (adversarial examples or model evasion), confidentiality attacks or model flaws."

日本語: 訓練データの汚染（data poisoning）、事前学習済み部品の汚染（model poisoning）、誤りを誘発する入力（adversarial examples / model evasion）、機密性への攻撃、モデルの欠陥。

**2026 年改正による補足（新 Art. 42(3)）** [条文]:
> "Where high-risk AI systems fall within the scope of Regulation (EU) 2024/2847 and the conditions laid down in Article 12(1) of that Regulation are fulfilled, such systems shall be deemed to comply with the cybersecurity requirements set out in Article 15 of this Regulation."
日本語: Cyber Resilience Act（Regulation (EU) 2024/2847）の要件を満たす場合、Art. 15 のサイバーセキュリティ要求を満たしたとみなされる（適合推定）。

---

## 4. 提供者（provider）の義務 — Art. 16–22

### Art. 16 — provider 義務の一覧（変更なし、原文全文）
[条文]
> "Providers of high-risk AI systems shall:
> (a) ensure that their high-risk AI systems are compliant with the requirements set out in Section 2;
> (b) indicate on the high-risk AI system or, where that is not possible, on its packaging or its accompanying documentation, as applicable, their name, registered trade name or registered trade mark, the address at which they can be contacted;
> (c) have a quality management system in place which complies with Article 17;
> (d) keep the documentation referred to in Article 18;
> (e) when under their control, keep the logs automatically generated by their high-risk AI systems as referred to in Article 19;
> (f) ensure that the high-risk AI system undergoes the relevant conformity assessment procedure as referred to in Article 43, prior to its being placed on the market or put into service;
> (g) draw up an EU declaration of conformity in accordance with Article 47;
> (h) affix the CE marking to the high-risk AI system or, where that is not possible, on its packaging or its accompanying documentation, to indicate conformity with this Regulation, in accordance with Article 48;
> (i) comply with the registration obligations referred to in Article 49(1);
> (j) take the necessary corrective actions and provide information as required in Article 20;
> (k) upon a reasoned request of a national competent authority, demonstrate the conformity of the high-risk AI system with the requirements set out in Section 2;
> (l) ensure that the high-risk AI system complies with accessibility requirements in accordance with Directives (EU) 2016/2102 and (EU) 2019/882."

日本語の要点: これが Art. 25(1) で「provider とみなされた者」がそっくり負う一覧である。12 項目。

### Art. 17 — 品質管理体制（quality management system）
日本語一行: **書かれた方針・手続・指示** の形で体系的・秩序立てて文書化された品質管理体制を置くこと。

原文の要となる一句（17(1)）:
> "That system shall be documented in a systematic and orderly manner in the form of written policies, procedures and instructions, and shall include at least the following aspects:"

最低限含めるべき 13 項目 (a)–(m) のうち、押さえるべきもの（原文）:
> "(a) a strategy for regulatory compliance, including compliance with conformity assessment procedures and procedures for the management of modifications to the high-risk AI system;"
> "(f) systems and procedures for data management, including data acquisition, data collection, data analysis, data labelling, data storage, data filtration, data mining, data aggregation, data retention and any other operation regarding the data that is performed before and for the purpose of the placing on the market or the putting into service of high-risk AI systems;"
> "(g) the risk management system referred to in Article 9;"
> "(h) the setting-up, implementation and maintenance of a post-market monitoring system, in accordance with Article 72;"
> "(i) procedures related to the reporting of a serious incident in accordance with Article 73;"
> "(m) an accountability framework setting out the responsibilities of the management and other staff with regard to all the aspects listed in this paragraph."

17(2)（2026 年改正後の現行文）:
> "2. The implementation of the aspects referred to in paragraph 1 shall be proportionate to the size of the provider's organisation, in particular, if the provider is an SME, including a start-up, or an SMC. Providers shall, in any event, respect the degree of rigour and the level of protection required to ensure the compliance of their high-risk AI systems with this Regulation."
日本語: 実装は組織規模に比例してよい（改正で SME・SMC が明記された）。ただし **厳格さと保護の水準そのものは下げてはならない**。

### Art. 18 — 文書の 10 年保管（変更なし）
[条文]
> "1. The provider shall, for a period ending 10 years after the high-risk AI system has been placed on the market or put into service, keep at the disposal of the national competent authorities:
> (a) the technical documentation referred to in Article 11;
> (b) the documentation concerning the quality management system referred to in Article 17;
> (c) the documentation concerning the changes approved by notified bodies, where applicable;
> (d) the decisions and other documents issued by the notified bodies, where applicable;
> (e) the EU declaration of conformity referred to in Article 47."

日本語の要点: 上市／サービス提供開始から **10 年間**、国内所轄当局がいつでも利用できる状態で保管する。破産・廃業の場合の取り扱いは各加盟国が定める（18(2)）。

### Art. 19 — 自動生成ログ（本ドシエ §3 の Art. 12 の項に既出。最低 6 か月）

### Art. 20 — 是正措置と情報提供義務（変更なし）
[条文]
> "1. Providers of high-risk AI systems which consider or have reason to consider that a high-risk AI system that they have placed on the market or put into service is not in conformity with this Regulation shall immediately take the necessary corrective actions to bring that system into conformity, to withdraw it, to disable it, or to recall it, as appropriate. They shall inform the distributors of the high-risk AI system concerned and, where applicable, the deployers, the authorised representative and importers accordingly."

日本語の要点: 不適合と **考える、または考えるに足る理由がある** 段階で、直ちに是正・撤回・無効化・回収のいずれか適切な措置を取る。distributor に通知し、該当すれば deployer・域内代理人・importer にも通知する。
20(2): Art. 79(1) の意味でのリスクを認識したら、直ちに原因を調査し（該当すれば報告した deployer と協働して）、市場監視当局と証明書を発行した notified body に通知する。

### Art. 21 — 所轄当局との協力（変更なし）
[条文]
> "1. Providers of high-risk AI systems shall, upon a reasoned request by a competent authority, provide that authority all the information and documentation necessary to demonstrate the conformity of the high-risk AI system with the requirements set out in Section 2, in a language which can be easily understood by the authority in one of the official languages of the institutions of the Union as indicated by the Member State concerned."
> "2. Upon a reasoned request by a competent authority, providers shall also give the requesting competent authority, as applicable, access to the automatically generated logs of the high-risk AI system referred to in Article 12(1), to the extent such logs are under their control."

日本語の要点: **理由を付した要求** があれば、適合性を示す情報・文書を提出する。言語は当該加盟国が指定する EU 公用語のうち当局が容易に理解できるもの。自動生成ログへのアクセスも同様。得られた情報は Art. 78 の守秘義務に服する（21(3)）。

### Art. 22 — 第三国 provider の域内代理人（変更なし、原文全文）

**これは EU 域外の provider すべてに掛かる。** [条文]

> "1. Prior to making their high-risk AI systems available on the Union market, providers established in third countries shall, by written mandate, appoint an authorised representative which is established in the Union.
>
> 2. The provider shall enable its authorised representative to perform the tasks specified in the mandate received from the provider.
>
> 3. The authorised representative shall perform the tasks specified in the mandate received from the provider. It shall provide a copy of the mandate to the market surveillance authorities upon request, in one of the official languages of the institutions of the Union, as indicated by the competent authority. For the purposes of this Regulation, the mandate shall empower the authorised representative to carry out the following tasks:
> (a) verify that the EU declaration of conformity referred to in Article 47 and the technical documentation referred to in Article 11 have been drawn up and that an appropriate conformity assessment procedure has been carried out by the provider;
> (b) keep at the disposal of the competent authorities and national authorities or bodies referred to in Article 74(10), for a period of 10 years after the high-risk AI system has been placed on the market or put into service, the contact details of the provider that appointed the authorised representative, a copy of the EU declaration of conformity referred to in Article 47, the technical documentation and, if applicable, the certificate issued by the notified body;
> (c) provide a competent authority, upon a reasoned request, with all the information and documentation, including that referred to in point (b) of this subparagraph, necessary to demonstrate the conformity of a high-risk AI system with the requirements set out in Section 2, including access to the logs, as referred to in Article 12(1), automatically generated by the high-risk AI system, to the extent such logs are under the control of the provider;
> (d) cooperate with competent authorities, upon a reasoned request, in any action the latter take in relation to the high-risk AI system, in particular to reduce and mitigate the risks posed by the high-risk AI system;
> (e) where applicable, comply with the registration obligations referred to in Article 49(1), or, if the registration is carried out by the provider itself, ensure that the information referred to in point 3 of Section A of Annex VIII is correct.
>
> The mandate shall empower the authorised representative to be addressed, in addition to or instead of the provider, by the competent authorities, on all issues related to ensuring compliance with this Regulation.
>
> 4. The authorised representative shall terminate the mandate if it considers or has reason to consider the provider to be acting contrary to its obligations pursuant to this Regulation. In such a case, it shall immediately inform the relevant market surveillance authority, as well as, where applicable, the relevant notified body, about the termination of the mandate and the reasons therefor."

日本語の要点（スイス・日本など EU 域外の事業者にとって）:
- **EU 市場で高リスク AI システムを入手可能にする前に**、書面による委任で EU 域内に設立された域内代理人を選任しなければならない。事後ではなく事前。
- 代理人の職務: 適合宣言と技術文書の存在確認、**10 年間の文書保管**、当局への情報提供（ログへのアクセスを含む）、当局への協力、EU データベース登録。
- 当局は provider に加えて、あるいは provider の代わりに、代理人に対して直接連絡できる。
- **代理人には離脱義務がある**: provider が義務に反していると考える、または考えるに足る理由があるとき、代理人は委任を終了 **しなければならない**（"shall terminate"）。そして直ちに市場監視当局に理由とともに通知する。単なる私的な契約関係ではない。

（注: 汎用 AI モデルの第三国 provider については別途 Art. 54 が域内代理人を定める。本ドシエの範囲外。）

---

## 5. 適合性評価と登録 — Art. 43, 47, 48, 49, 71

### 5.1 結論から — Annex III の高リスクは第三者評価が必要か？

**必要ない。Annex III の points 2〜8 は、notified body（第三者認証機関）が関与しない内部管理（Annex VI）による自己評価が原則である。** 第三者評価が関わりうるのは Annex III **point 1（生体認証）** だけで、それも条件付きである。

```
高リスク AI システムの適合性評価ルート（Art. 43）
│
├─ Annex III point 1（生体認証系）  ── Art. 43(1)
│    ├─ 整合規格 / 共通仕様を適用した  → 提供者が選択できる:
│    │                                    (a) Annex VI 内部管理（第三者なし）
│    │                                    (b) Annex VII 第三者（notified body）
│    └─ 整合規格がない／適用していない／
│       一部しか適用していない／制限付き公表  → Annex VII（第三者）が必須
│
├─ Annex III points 2〜8              ── Art. 43(2)
│    └─ Annex VI 内部管理のみ。「notified body の関与を予定しない」と条文が明記 ★
│
└─ Annex I Section A（製品組み込み型）── Art. 43(3)（2026 年改正で差し替え）
     └─ 当該分野別法令の手続に従う（AI であることを理由に第三者評価が
        自動的に必要になるわけではない、と改正で明記された）
```

**Art. 43(1)（変更なし、原文）** [条文]
> "1. For high-risk AI systems listed in point 1 of Annex III, where, in demonstrating the compliance of a high-risk AI system with the requirements set out in Section 2, the provider has applied harmonised standards referred to in Article 40, or, where applicable, common specifications referred to in Article 41, the provider shall opt for one of the following conformity assessment procedures based on:
> (a) the internal control referred to in Annex VI; or
> (b) the assessment of the quality management system and the assessment of the technical documentation, with the involvement of a notified body, referred to in Annex VII."

同 43(1) 第2段（Annex VII が必須になる場合）:
> "In demonstrating the compliance of a high-risk AI system with the requirements set out in Section 2, the provider shall follow the conformity assessment procedure set out in Annex VII where:
> (a) harmonised standards referred to in Article 40 do not exist, and common specifications referred to in Article 41 are not available;
> (b) the provider has not applied, or has applied only part of, the harmonised standard;
> (c) the common specifications referred to in point (a) exist, but the provider has not applied them;
> (d) one or more of the harmonised standards referred to in point (a) has been published with a restriction, and only on the part of the standard that was restricted."

**Art. 43(2)（変更なし、原文）— これが「ほとんどの Annex III は自己評価」の根拠** [条文]
> "2. For high-risk AI systems referred to in points 2 to 8 of Annex III, providers shall follow the conformity assessment procedure based on internal control as referred to in Annex VI, **which does not provide for the involvement of a notified body**."
（強調は本ドシエによる。原文に強調記号はない。）

日本語: Annex III の点 2 から 8 までの高リスク AI システムについては、provider は Annex VI の内部管理に基づく適合性評価手続に従う。**この手続は notified body の関与を予定していない。**

**Art. 43(4)（変更なし）— 重大な改変があれば再評価**
> "4. High-risk AI systems that have already been subject to a conformity assessment procedure shall undergo a new conformity assessment procedure in the event of a substantial modification, regardless of whether the modified system is intended to be further distributed or continues to be used by the current deployer."
日本語: **さらに流通させるかどうか、現在の deployer が使い続けるだけかどうかを問わず**、重大な改変があれば新たな適合性評価を受けなければならない。社内利用でも逃れられない。
同項第2段: 当初の適合性評価の時点で provider が事前に決めておき Annex IV point 2(f) の技術文書に記載した変更は、substantial modification に当たらない（継続学習するシステムのための逃げ道）。

**Art. 43(6)（変更なし）— 将来の格上げ余地**: Commission は委任行為により、Annex III の点 2〜8 を Annex VII 手続（またはその一部）の対象に変更する権限を持つ。つまり **現在の「自己評価が原則」は恒久的な保証ではない**。

**Art. 43(3)（2026 年改正後の現行文、Annex I 系）** [条文] — 改正で追加された明確化:
> "The classification of a product as a high-risk AI system in accordance with Article 6(1) does not affect the choice of the conformity assessment procedure provided to the manufacturers of products covered by Union harmonisation legislation listed in Section A of Annex I, including, where applicable, an option to rely on harmonised standards. The manufacturers of such products are not required to choose a conformity assessment procedure involving third-party conformity assessment only because the product includes a high-risk AI system as a safety component, if this is not required by the Union harmonisation legislation listed in Section A of Annex I."
日本語: 製品に高リスク AI が安全部品として含まれるというだけの理由で、第三者適合性評価を選ばなければならなくなるわけではない。
同項には移行期限も入った: Annex I Section A 系の notified body は **2028-01-28 まで** に本規則に基づく指定を申請しなければならない。

### 5.2 Art. 47 — EU 適合宣言（EU declaration of conformity）（変更なし）
[条文]
> "1. The provider shall draw up a written machine readable, physical or electronically signed EU declaration of conformity for each high-risk AI system, and keep it at the disposal of the national competent authorities for 10 years after the high-risk AI system has been placed on the market or put into service."
> "4. By drawing up the EU declaration of conformity, the provider shall assume responsibility for compliance with the requirements set out in Section 2. The provider shall keep the EU declaration of conformity up-to-date as appropriate."

日本語の要点: システム **一つごとに** 作成する。**機械可読** な書面で、物理的または電子的に署名する。10 年間保管。内容は Annex V に定められ、上市先加盟国の当局が容易に理解できる言語に翻訳する（47(2)）。**適合宣言を作成することにより、provider は Section 2 の要求事項への適合について責任を引き受ける**（47(4)）。

### 5.3 Art. 48 — CE マーキング（変更なし）
[条文]
> "2. For high-risk AI systems provided digitally, a digital CE marking shall be used, only if it can easily be accessed via the interface from which that system is accessed or via an easily accessible machine-readable code or other electronic means."
> "3. The CE marking shall be affixed visibly, legibly and indelibly for high-risk AI systems. Where that is not possible or not warranted on account of the nature of the high-risk AI system, it shall be affixed to the packaging or to the accompanying documentation, as appropriate."
> "4. Where applicable, the CE marking shall be followed by the identification number of the notified body responsible for the conformity assessment procedures set out in Article 43."

日本語の要点: デジタル提供の場合は **デジタル CE マーキング**。アクセス元のインターフェースから容易にアクセスできるか、容易にアクセスできる機械可読コード等で提供できる場合に限る。notified body が関与した場合はその識別番号を続けて付す — 逆に言えば **Annex VI 自己評価の場合、CE マークに番号は付かない**。一般原則は Regulation (EC) No 765/2008 Art. 30 に従う（48(1)）。

### 5.4 Art. 49 — EU データベースへの登録（変更なし）
[条文]
> "1. Before placing on the market or putting into service a high-risk AI system listed in Annex III, with the exception of high-risk AI systems referred to in point 2 of Annex III, the provider or, where applicable, the authorised representative shall register themselves and their system in the EU database referred to in Article 71."
> "2. Before placing on the market or putting into service an AI system for which the provider has concluded that it is not high-risk according to Article 6(3), that provider or, where applicable, the authorised representative shall register themselves and that system in the EU database referred to in Article 71."
> "3. Before putting into service or using a high-risk AI system listed in Annex III, with the exception of high-risk AI systems listed in point 2 of Annex III, deployers that are public authorities, Union institutions, bodies, offices or agencies or persons acting on their behalf shall register themselves, select the system and register its use in the EU database referred to in Article 71."
> "5. High-risk AI systems referred to in point 2 of Annex III shall be registered at national level."

日本語の要点:
- **provider は上市前に自分自身とシステムを EU データベースに登録する**（49(1)）。Annex III の点 2（重要インフラ）は例外で、国レベルの登録（49(5)）。
- **49(2) が見落とされやすい**: Art. 6(3) を使って「これは高リスクではない」と自ら結論づけた場合でも、**その結論を出したこと自体を EU データベースに登録しなければならない**。高リスクでないと判断すれば登録が不要になる、ということではない。
- **公的機関である deployer には登録義務がある**（49(3)）。民間の deployer にはない。
- 法執行・移民・庇護・国境管理の分野（Annex III points 1, 6, 7）については、データベースの **非公開の安全な区画** に、限定された情報のみを登録する（49(4)）。

2026 年改正の影響: Art. 49 本文は変更なし。ただし **Annex VIII Section B の points 7 と 9 が削除** され、Art. 49(2) の登録内容が簡素化された [条文 Regulation (EU) 2026/1744 Art. 1 point (41)]。

### 5.5 Art. 71 — EU データベース（変更なし）
[条文]
> "2. The data listed in Sections A and B of Annex VIII shall be entered into the EU database by the provider or, where applicable, by the authorised representative."
> "3. The data listed in Section C of Annex VIII shall be entered into the EU database by the deployer who is, or who acts on behalf of, a public authority, agency or body, in accordance with Article 49(3) and (4)."
> "4. With the exception of the section referred to in Article 49(4) and Article 60(4), point (c), the information contained in the EU database registered in accordance with Article 49 shall be accessible and publicly available in a user-friendly manner. The information should be easily navigable and machine-readable."
> "6. The Commission shall be the controller of the EU database."

日本語の要点: データベースは Commission が加盟国と協力して構築・維持し、**Commission が管理者（controller）** となる。Art. 49(4) の非公開区画と実環境試験（Art. 60(4)(c)）の情報を除き、**登録情報は一般に公開され、機械可読でなければならない**。

---

## 6. 利用者側（deployer）の義務 — Art. 26, 27

### 6.1 Art. 26 — deployer の義務（2026 年改正なし、原文）

[条文] 出典: consolidated Article 26。

**26(1) 使用説明書に従う**
> "1. Deployers of high-risk AI systems shall take appropriate technical and organisational measures to ensure they use such systems in accordance with the instructions for use accompanying the systems, pursuant to paragraphs 3 and 6."

**26(2) 人間による監督者の指名**
> "2. Deployers shall assign human oversight to natural persons who have the necessary competence, training and authority, as well as the necessary support."
日本語: **必要な能力・訓練・権限、そして必要な支援を備えた** 自然人に人間による監督を割り当てる。名前だけの監督者では足りない。

**26(4) 入力データ**
> "4. Without prejudice to paragraphs 1 and 2, to the extent the deployer exercises control over the input data, that deployer shall ensure that input data is relevant and sufficiently representative in view of the intended purpose of the high-risk AI system."
日本語: **入力データを管理している限りにおいて**、入力データが意図された目的に照らして関連性があり十分に代表的であることを確保する。

**26(5) 監視と通報**
> "5. Deployers shall monitor the operation of the high-risk AI system on the basis of the instructions for use and, where relevant, inform providers in accordance with Article 72. Where deployers have reason to consider that the use of the high-risk AI system in accordance with the instructions may result in that AI system presenting a risk within the meaning of Article 79(1), they shall, without undue delay, inform the provider or distributor and the relevant market surveillance authority, and shall suspend the use of that system. Where deployers have identified a serious incident, they shall also immediately inform first the provider, and then the importer or distributor and the relevant market surveillance authorities of that incident."
日本語: リスクがあると考えるに足る理由があれば、遅滞なく provider または distributor と市場監視当局に通知し、**利用を停止する**。重大なインシデントを発見した場合は、まず provider に、次に importer / distributor と市場監視当局に直ちに通知する。provider に連絡が取れない場合は Art. 73 を準用する。

**26(6) ログの 6 か月保管（provider と同じ期間が deployer にも掛かる）**
> "6. Deployers of high-risk AI systems shall keep the logs automatically generated by that high-risk AI system to the extent such logs are under their control, for a period appropriate to the intended purpose of the high-risk AI system, of at least six months, unless provided otherwise in applicable Union or national law, in particular in Union law on the protection of personal data."

**26(7) 職場での利用 — 労働者への事前通知**
> "7. Before putting into service or using a high-risk AI system at the workplace, deployers who are employers shall inform workers' representatives and the affected workers that they will be subject to the use of the high-risk AI system."
日本語: 職場で高リスク AI を使い始める前に、**使用者である deployer は労働者代表と影響を受ける労働者に通知しなければならない**。

**26(8) 公的機関 deployer の登録義務**
> "8. Deployers of high-risk AI systems that are public authorities, or Union institutions, bodies, offices or agencies shall comply with the registration obligations referred to in Article 49. When such deployers find that the high-risk AI system that they envisage using has not been registered in the EU database referred to in Article 71, they shall not use that system and shall inform the provider or the distributor."
日本語: **登録されていない高リスク AI システムを使ってはならない** — 公的機関 deployer には、使う前に EU データベースを確認する実質的な義務がある。

**26(9) DPIA との接続**
> "9. Where applicable, deployers of high-risk AI systems shall use the information provided under Article 13 of this Regulation to comply with their obligation to carry out a data protection impact assessment under Article 35 of Regulation (EU) 2016/679 or Article 27 of Directive (EU) 2016/680."
日本語: Art. 13 の使用説明書の情報を、GDPR Art. 35 の DPIA（データ保護影響評価）の実施に使う。

**26(11) 影響を受ける自然人への通知**
> "11. Without prejudice to Article 50 of this Regulation, deployers of high-risk AI systems referred to in Annex III that make decisions or assist in making decisions related to natural persons shall inform the natural persons that they are subject to the use of the high-risk AI system."
日本語: **自然人に関する決定を行う、または決定を補助する** Annex III 系の高リスク AI を使う deployer は、その自然人に対して、自分が高リスク AI の利用対象になっていることを通知しなければならない。

**26(12) 当局への協力**
> "12. Deployers shall cooperate with the relevant competent authorities in any action those authorities take in relation to the high-risk AI system in order to implement this Regulation."

（26(10) は事後遠隔生体識別の法執行利用に関する詳細規定。本ドシエの範囲外だが、司法当局等の事前許可、48 時間以内の事後許可、年次報告義務などを定める。）

### 6.2 Art. 27 — 基本権影響評価（FRIA）— 誰が実施義務を負うか

**27(1) 第1文（2026 年改正なし、原文のまま）** [条文]
> "1. Prior to deploying a high-risk AI system referred to in Article 6(2), with the exception of high-risk AI systems intended to be used in the area listed in point 2 of Annex III, deployers that are bodies governed by public law, or are private entities providing public services, and deployers of high-risk AI systems referred to in points 5 (b) and (c) of Annex III, shall perform an assessment of the impact on fundamental rights that the use of such system may produce."

**誰が FRIA を実施しなければならないか（条文の構造を分解）**:

| 対象 | 条文の語 | 日本語 |
|---|---|---|
| ① 公法上の団体である deployer | "deployers that are bodies governed by public law" | 公法に基づき設立された機関（公的機関） |
| ② 公共サービスを提供する民間主体である deployer | "or are private entities providing public services" | 公共サービスを提供する民間事業者 |
| ③ Annex III 点 5(b)(c) の高リスク AI の deployer | "and deployers of high-risk AI systems referred to in points 5 (b) and (c) of Annex III" | ①②に該当しなくても、この用途なら義務あり |

対象システムの範囲: **Article 6(2) の高リスク AI システム（＝ Annex III 系）** に限られる。**Annex III 点 2 に挙げられた領域で使われることを意図したシステムは除外される。**
つまり、Annex I 系（製品組み込み型）の高リスク AI には FRIA 義務はない。また、①②③のいずれにも当たらない純民間の deployer には FRIA 義務はない。

**評価に含めるべき 6 項目（27(1) (a)–(f)、原文）**:
> "(a) a description of the deployer's processes in which the high-risk AI system will be used in line with its intended purpose;
> (b) a description of the period of time within which, and the frequency with which, each high-risk AI system is intended to be used;
> (c) the categories of natural persons and groups likely to be affected by its use in the specific context;
> (d) the specific risks of harm likely to have an impact on the categories of natural persons or groups of persons identified pursuant to point (c) of this paragraph, taking into account the information given by the provider pursuant to Article 13;
> (e) a description of the implementation of human oversight measures, according to the instructions for use;
> (f) the measures to be taken in the case of the materialisation of those risks, including the arrangements for internal governance and complaint mechanisms."

**27(2)（変更なし）— 初回利用が起点**
> "2. The obligation laid down in paragraph 1 applies to the first use of the high-risk AI system. The deployer may, in similar cases, rely on previously conducted fundamental rights impact assessments or existing impact assessments carried out by provider."
日本語: 義務は **初回利用** に掛かる。類似の事案では過去の FRIA や provider が実施した既存の影響評価に依拠してよい。1 項の要素が変わった、または最新でなくなったと考える場合は更新する。

**27(3)（変更なし）— 市場監視当局への通知**
> "3. Once the assessment referred to in paragraph 1 of this Article has been performed, the deployer shall notify the market surveillance authority of its results, submitting the filled-out template referred to in paragraph 5 of this Article as part of the notification."
日本語: **実施したら結果を市場監視当局に通知する**。AI Office が用意する記入済みテンプレートを添えて提出する。FRIA は社内文書として置いておけばよいものではない。

**27(4)（2026 年改正後の現行文）— DPIA との関係が改善された**
> "4. If any of the obligations laid down in this Article is already met through the data protection impact assessment conducted pursuant to Article 35 of Regulation (EU) 2016/679 or Article 27 of Directive (EU) 2016/680, the deployer may, when conducting the fundamental rights impact assessment referred to in paragraph 1 of this Article, include cross-references to the relevant sections of that data protection impact assessment or include relevant parts thereof in the fundamental rights impact assessment."
（改正前の文言: "... the fundamental rights impact assessment referred to in paragraph 1 of this Article shall complement that data protection impact assessment." — 「補完する」から「相互参照または一部組み込みができる」へ変わり、重複作業が明示的に減らされた。）

**27(5)（2026 年改正後の現行文）**: AI Office が質問票テンプレート（自動化ツールを含む）を作成する。このテンプレートは、該当する場合に DPIA の関連部分への相互参照や取り込みを可能にするものでなければならない。

---

## 7. Article 50 — 透明性の義務（高リスクでなくても掛かる）

[条文] 出典: consolidated Article 50。**1〜6 項は 2026 年改正で変更されていない**（7 項のみ改正）。
Chapter IV の表題そのものが "TRANSPARENCY OBLIGATIONS FOR PROVIDERS AND DEPLOYERS OF CERTAIN AI SYSTEMS" であり、高リスク分類とは独立に掛かる。

### 四つの義務 — 誰に掛かるか

| 項 | 義務 | 掛かる相手 |
|---|---|---|
| 50(1) | AI と対話していることを人に知らせる | **provider**（設計・開発義務） |
| 50(2) | 合成コンテンツを機械可読形式で標識する | **provider** |
| 50(3) | 感情認識・生体分類の運用を対象者に知らせる | **deployer** |
| 50(4) | ディープフェイクの開示／公益事項に関する AI 生成テキストの開示 | **deployer** |

つまり **前二つは provider の義務、後二つは deployer の義務** である。

### 50(1) — AI との対話であることの告知（provider）
> "1. Providers shall ensure that AI systems intended to interact directly with natural persons are designed and developed in such a way that the natural persons concerned are informed that they are interacting with an AI system, unless this is obvious from the point of view of a natural person who is reasonably well-informed, observant and circumspect, taking into account the circumstances and the context of use. This obligation shall not apply to AI systems authorised by law to detect, prevent, investigate or prosecute criminal offences, subject to appropriate safeguards for the rights and freedoms of third parties, unless those systems are available for the public to report a criminal offence."

日本語の要点: 自然人と **直接対話することを意図した** AI システムについて、対話相手が AI であることを知らされるように設計・開発する。
**免除 1**: 「合理的に十分な知識があり、注意深く、慎重な自然人」の視点から見て、状況と利用の文脈に照らして **明らか** な場合は不要。
**免除 2**: 犯罪の検知・予防・捜査・訴追のために法により許可された AI システム（第三者の権利・自由に対する適切な保護措置が前提）。ただし **一般市民が犯罪を通報するために利用できるシステムにはこの免除は及ばない**。

### 50(2) — 合成コンテンツの機械可読な標識（provider）
> "2. Providers of AI systems, including general-purpose AI systems, generating synthetic audio, image, video or text content, shall ensure that the outputs of the AI system are marked in a machine-readable format and detectable as artificially generated or manipulated. Providers shall ensure their technical solutions are effective, interoperable, robust and reliable as far as this is technically feasible, taking into account the specificities and limitations of various types of content, the costs of implementation and the generally acknowledged state of the art, as may be reflected in relevant technical standards. This obligation shall not apply to the extent the AI systems perform an assistive function for standard editing or do not substantially alter the input data provided by the deployer or the semantics thereof, or where authorised by law to detect, prevent, investigate or prosecute criminal offences."

日本語の要点: **汎用 AI システムを含む**、合成の音声・画像・動画・テキストを生成する AI システムの provider は、出力が **機械可読形式で標識され、人工的に生成・操作されたものとして検出可能** であることを確保する。技術的解決策は、技術的に可能な範囲で、実効的・相互運用可能・頑健・信頼できるものでなければならない。
**免除**: ①標準的な編集の補助機能を果たすにとどまる場合、②deployer が提供した入力データまたはその意味内容を実質的に変更しない場合、③犯罪の検知・予防・捜査・訴追のために法により許可される場合。

**移行措置（2026 年改正で新設された Art. 111(4)）** [条文]:
> "4. Providers of AI systems, including general-purpose AI systems, generating synthetic audio, image, video or text content, that have been placed on the market before 2 August 2026 shall take the necessary steps in order to comply with Article 50(2) by 2 December 2026."
日本語: **2026-08-02 より前に市場に出ていた既存システム** については、50(2) への適合期限は **2026-12-02** まで猶予される。

### 50(3) — 感情認識・生体分類の告知（deployer）
> "3. Deployers of an emotion recognition system or a biometric categorisation system shall inform the natural persons exposed thereto of the operation of the system, and shall process the personal data in accordance with Regulations (EU) 2016/679 and (EU) 2018/1725 and Directive (EU) 2016/680, as applicable. This obligation shall not apply to AI systems used for biometric categorisation and emotion recognition, which are permitted by law to detect, prevent or investigate criminal offences, subject to appropriate safeguards for the rights and freedoms of third parties, and in accordance with Union law."

日本語の要点: 感情認識システムまたは生体分類システムの **deployer** は、それにさらされる自然人にシステムの運用を知らせ、かつ GDPR 等に従って個人データを処理する。
**免除**: 犯罪の検知・予防・捜査のために法により許容される生体分類・感情認識（第三者の権利・自由の保護措置が前提、EU 法に従う）。

### 50(4) — ディープフェイクと公益事項に関する AI 生成テキスト（deployer）

**第1段（ディープフェイク）**
> "4. Deployers of an AI system that generates or manipulates image, audio or video content constituting a deep fake, shall disclose that the content has been artificially generated or manipulated. This obligation shall not apply where the use is authorised by law to detect, prevent, investigate or prosecute criminal offence. Where the content forms part of an evidently artistic, creative, satirical, fictional or analogous work or programme, the transparency obligations set out in this paragraph are limited to disclosure of the existence of such generated or manipulated content in an appropriate manner that does not hamper the display or enjoyment of the work."

日本語の要点: ディープフェイクを構成する画像・音声・動画を生成・操作する AI システムの **deployer** は、そのコンテンツが人工的に生成・操作されたものであることを開示する。
**免除 1**: 犯罪の検知・予防・捜査・訴追のために法により許可された利用。
**軽減（免除ではない）**: **明らかに芸術的・創作的・風刺的・虚構的またはこれに類する** 作品・番組の一部を成す場合、義務は「そのような生成・操作コンテンツが存在することを、作品の表示や鑑賞を妨げない適切な方法で開示する」ことに限定される。開示自体は残る。

**第2段（公益事項に関する AI 生成テキスト）**
> "Deployers of an AI system that generates or manipulates text which is published with the purpose of informing the public on matters of public interest shall disclose that the text has been artificially generated or manipulated. This obligation shall not apply where the use is authorised by law to detect, prevent, investigate or prosecute criminal offences or where the AI-generated content has undergone a process of human review or editorial control and where a natural or legal person holds editorial responsibility for the publication of the content."

日本語の要点: **公益事項について公衆に情報を提供する目的で公表される** テキストを生成・操作する AI システムの deployer は、そのテキストが人工的に生成・操作されたものであることを開示する。
**免除 1**: 犯罪の検知・予防・捜査・訴追のための法により許可された利用。
**免除 2（実務上大きい）**: AI 生成コンテンツが **人間によるレビューまたは編集上の統制** の過程を経ており、かつ **自然人または法人がその公表について編集責任を負っている** 場合。報道機関が編集責任を負って公表する場合は、この免除に当たりうる。

### 50(5)(6) — 提供の仕方と他の義務との関係
> "5. The information referred to in paragraphs 1 to 4 shall be provided to the natural persons concerned in a clear and distinguishable manner at the latest at the time of the first interaction or exposure. The information shall conform to the applicable accessibility requirements."
> "6. Paragraphs 1 to 4 shall not affect the requirements and obligations set out in Chapter III, and shall be without prejudice to other transparency obligations laid down in Union or national law for deployers of AI systems."

日本語の要点: 情報は **明確で識別可能な方法** で、遅くとも **最初の対話または曝露の時点** までに提供する。アクセシビリティ要件に適合させる。Chapter III（高リスク規制）の要求は Art. 50 とは別に掛かり続ける — **重畳的に適用される**。

### 50(7)（2026 年改正後の現行文）— 行動規範
> "7. The Commission shall encourage and facilitate the drawing up of codes of practice at Union level to facilitate the effective implementation of the obligations regarding the detection, marking and labelling of artificially generated or manipulated content. The Commission, taking utmost account of the opinion of the Board, shall assess whether adherence to those codes of practice is adequate to ensure compliance with the obligations laid down in paragraphs 2 and 4 of this Article, in accordance with the procedure laid down in Article 56(6). If it deems the code of practice to be inadequate, the Commission may adopt an implementing act specifying common rules for the implementation of those obligations in accordance with the examination procedure laid down in Article 98(2)."
（改正前は "The AI Office shall encourage ..." で、行動規範の承認に implementing act を要した。改正後は Commission が「遵守が適切か」を評価する形に変わった。）

### Art. 50 についての公式ガイダンス

| 項目 | 内容 | 種別・出典 |
|---|---|---|
| Guidelines on transparency obligations for providers and deployers of certain AI systems | Commission が公表。ページの "Last update" は 2026-08-06 | [公式ガイダンス] https://digital-strategy.ec.europa.eu/en/policies/guidelines-transparency-ai-generated-content |
| Code of Practice on Transparency of AI-generated Content | Art. 50(2) の標識と 50(4) の表示を対象とする自主的行動規範。Commission と AI Board が「適切（adequate）」と確認したと報じられている | [公式ガイダンス／二次解説] 同上 + 下記二次解説 |
| Art. 50 の適用開始 | 2026-08-02（Commission ページの記載: "Article 50 of the AI Act applies from 2 August 2026."） | [公式ガイダンス] 同上 |

Commission ページが provider / deployer の役割分担について述べている内容（要旨）:
- provider: "Design AI systems in a way that ensures individuals are explicitly informed whenever they interact with an AI system directly" / "Add machine-readable marks to enable the detection of AI-generated or manipulated content"
- deployer: 感情認識・生体分類のツール、ディープフェイク、および人間のレビューや編集統制を経ていない公益事項に関するテキスト公表について、対象者に知らせる

二次解説（日付の裏取りに使えるが一次資料ではない）:
- Faegre Drinker, "EU AI Act — Commission Confirms Transparency Code of Practice as Adequate and Publishes Final Version of Its Guidelines on Transparency Obligations" (2026-07) — https://www.faegredrinker.com/en/insights/publications/2026/7/eu-ai-act-commission-confirms-transparency-code-of-practice-as-adequate-and-publishes-final-version-of-its-guidelines-on-transparency-obligations [二次解説]
- artificialintelligenceact.eu, "The EU AI Act's Transparency Rules: A Practical Guide to Article 50" — https://artificialintelligenceact.eu/transparency-rules-article-50/ [二次解説]

**食い違い**: 最終版ガイドラインの公表日について、二次解説は 2026-07-20 とするが、Commission のページ上で確認できたのは "Last update" の 2026-08-06 のみで、正式な採択日はページに記載されていない。どちらが採択日かは確定できず。

---

## 8. AI リテラシー — Article 4

### 8.1 現行文（2026 年改正後）

[条文] 出典: consolidated Article 4（Regulation (EU) 2026/1744 Art. 1 point (5) により全文差し替え）

> "**Article 4 — AI literacy**
>
> 1. Providers and deployers of AI systems shall take measures to support the development of AI literacy of their staff and other persons dealing with the operation and use of AI systems on their behalf, taking into account their technical knowledge, experience, education and training and the context the AI systems are to be used in, and considering the persons or groups of persons on whom the AI systems are to be used. This obligation does not require providers or deployers to guarantee any specific level of AI literacy of any individual.
>
> 2. The Commission and the Member States shall support and facilitate the efforts of providers and deployers of AI systems, in particular SMEs, in fulfilling their obligation under paragraph 1 of this Article. For that purpose, the Commission shall publish practical examples of how to comply with that obligation on the single information platform referred to in Article 62(3), point (b).
>
> 3. The Board shall adopt recommendations, taking into account European competence frameworks, to support the Commission and Member States in the promotion of AI literacy required under paragraph 1, including by setting out common objectives."

### 8.2 改正前の文言（比較用）

[条文] 出典: 原典 OJ L, 2024/1689 Article 4
> "Providers and deployers of AI systems shall take measures to ensure, to their best extent, a sufficient level of AI literacy of their staff and other persons dealing with the operation and use of AI systems on their behalf, taking into account their technical knowledge, experience, education and training and the context the AI systems are to be used in, and considering the persons or groups of persons on whom the AI systems are to be used."

**差分**: "take measures to **ensure, to their best extent, a sufficient level of** AI literacy" → "take measures to **support the development of** AI literacy"。さらに新しい最終文で「特定個人が特定水準の AI リテラシーを持つことを保証する義務はない」と明記された。**結果債務から努力債務へ** の移行である。

### 8.3 誰に、いつから掛かるか

| 項目 | 内容 | 出典 |
|---|---|---|
| 対象 | **providers AND deployers** の双方。条文の第一語が "Providers and deployers of AI systems" | [条文] Art. 4(1) |
| リスク階層との関係 | **無関係**。高リスクかどうかを問わず、AI システムの provider / deployer すべてに掛かる。Art. 4 は Chapter I（General provisions）に置かれており、Chapter III（高リスク）ではない | [条文] 条文の配置 |
| 適用開始 | **2025-02-02**。Art. 113 第3段(a): "Chapters I and II shall apply from 2 February 2025" — Art. 4 は Chapter I に属する | [条文] Art. 113 |
| 2026 年改正による適用日の変更 | **なし**。Art. 113(a) の改正は Art. 5(1)(ba)(bb) と 5(1a)(1b) の例外を追加しただけで、Chapter I の 2025-02-02 適用は維持された | [条文] Art. 113(a) 現行文 |

**食い違い（要注意）**: 二次解説の一つは「national supervision starting 3 August 2026」と述べているが、これに対応する条文上の根拠は Art. 113 の文面からは直接には確認できなかった（Art. 113(b) が Chapter VII 等を 2025-08-02 から、また Art. 99 の罰則規定に関する加盟国の整備義務は Art. 99(1) 参照）。**「監督・執行の開始日」については条文からの確認ができず。** 適用開始日（2025-02-02）と執行体制の整備日は別の論点である。

---

## 9. 適用日 — Article 113（2026 年改正後の現行文）

[条文] 出典: consolidated Article 113

> "This Regulation shall enter into force on the twentieth day following that of its publication in the Official Journal of the European Union.
> It shall apply from 2 August 2026.
> However:
> (a) Chapters I and II shall apply from 2 February 2025, with the exception of Article 5(1), first subparagraph, points (ba) and (bb), and Article 5(1a) and (1b) which shall apply from 2 December 2026;
> (b) Chapter III Section 4, Chapter V, Chapter VII and Chapter XII and Article 78 shall apply from 2 August 2025, with the exception of Article 101;
> (c) Chapter III, Sections 1, 2, and 3, with the exception of Article 6(5), shall apply from:
> (i) 2 December 2027 as regards AI systems classified as high-risk pursuant to Article 6(2) and Annex III; and
> (ii) 2 August 2028 as regards AI systems classified as high-risk pursuant to Article 6(1) and Annex I;
> (d) Articles 102 to 110 shall apply from 27 July 2026."

### 本ドシエの各条がいつから掛かるか

| 条 | 属する章・節 | 適用開始日 | 根拠 |
|---|---|---|---|
| Art. 3 定義 | Chapter I | 2025-02-02 | 113(a) |
| **Art. 4 AI リテラシー** | Chapter I | **2025-02-02** | 113(a) |
| **Art. 4a バイアス検出のための特別カテゴリー処理** | Chapter I（新設） | Chapter I は 2025-02-02 適用中。4a は改正法発効（2026-07-27）以降に存在 → **2026-07-27 から**（本ドシエの読み。公式確認は取れず） | 113(a) + Reg. 2026/1744 発効日 |
| **Art. 8–15（高リスク要求事項）** | Chapter III **Section 2** | **Annex III 系: 2027-12-02 / Annex I 系: 2028-08-02** | 113(c) |
| **Art. 16–27（provider / deployer 義務、Art. 25 の役割移転を含む）** | Chapter III **Section 3** | **Annex III 系: 2027-12-02 / Annex I 系: 2028-08-02** | 113(c) |
| Art. 28–39（notified body 制度） | Chapter III Section 4 | 2025-08-02 | 113(b) |
| Art. 40–49（規格・適合性評価・登録） | Chapter III **Section 5** | **113(c) に Section 5 は含まれていない → 一般規則の 2026-08-02** | 113 第2段 |
| **Art. 50 透明性** | Chapter IV | **2026-08-02**（既存システムの 50(2) のみ 2026-12-02 まで猶予） | 113 第2段 + Art. 111(4) |
| Art. 71 EU データベース | Chapter VIII | 2026-08-02 | 113 第2段 |

**重要な構造上の注意**: Art. 43（適合性評価）と Art. 49（登録）が属する Chapter III **Section 5** は 113(c) の延期対象に含まれておらず、条文の文面上は 2026-08-02 から適用される。一方で「適合性評価を受けよ」という **義務** は Art. 16(f) にあり、Art. 16 は Section 3 に属するため 2027-12-02 まで延期されている。**したがって実務上、Annex III 系の適合性評価・CE マーキング・登録の義務は 2027-12-02 まで発生しないと読めるが、この読み方を明示した公式ガイダンスは確認できていない。**

### 既存システムの扱い（Art. 111(2)、2026 年改正後）
[条文]
> "2. Without prejudice to the application of Article 5 as referred to in Article 113, third paragraph, point (a), this Regulation shall apply to operators of high-risk AI systems, other than the systems referred to in paragraph 1 of this Article, that have been placed on the market or put into service before the date of application of Chapter III referred to in Article 113, only if, as from that date, those systems are subject to significant changes in their designs. In any case, the providers and deployers of high-risk AI systems intended to be used by public authorities shall take the necessary steps to comply with the requirements and obligations laid down in this Regulation by 2 August 2030."

日本語の要点: Chapter III の適用日より前に市場に出ていた高リスク AI システムについては、**その日以降に設計に重大な変更（"significant changes in their designs"）が加えられた場合に限り** 本規則が適用される。ただし **公的機関による利用を意図した高リスク AI システム** の provider と deployer は、いかなる場合も **2030-08-02 まで** に適合させなければならない。
（注: ここでの語は "significant changes in their designs" であり、Art. 3(23) の "substantial modification" とは異なる語である。両者の関係を説明した公式ガイダンスは確認できず。）

---

## 10. 実務上の要点（後段の書き手向けの整理。条文の引用ではなく本ドシエの読み）

1. **サービス構築者が provider になる一文**: 他人の AI システム／汎用 AI システムの **intended purpose を変更して Annex III の高リスク用途に当てはめた瞬間**、あるいは既存の高リスクシステムに **自分の名前・商標を付けた** か **substantial modification を加えた** 瞬間に、その者は Art. 25(1) により provider とみなされ、Art. 16 の 12 項目をそっくり負う。契約で義務を別配分していても (a) には効かない。

2. **「社内利用だから市場に出していない」は逃げ道にならない**: Art. 3(11) の putting into service は "for own use in the Union for its intended purpose" を含む。Art. 43(4) も「現在の deployer が使い続けるだけか」を問わず再評価を要求する。

3. **EU 域外の事業者は Art. 22 が入口**: 高リスク AI を EU 市場で入手可能にする **前に** 域内代理人を書面委任で選任する。代理人には離脱義務があるため、名義貸しでは機能しない。

4. **Annex III 高リスクの適合性評価は原則として自己評価**: Art. 43(2) が明文で "which does not provide for the involvement of a notified body" と書いている。第三者認証が要るのは Annex III point 1（生体認証）で整合規格を適用しない場合など、限定的。ただし Art. 43(6) により Commission が将来これを変更できる。

5. **高リスクでなくても Art. 4（リテラシー）と Art. 50（透明性）は掛かる**。前者は 2025-02-02 から、後者は 2026-08-02 から。**この二つが、高リスクに当たらない大多数の事業者にとって現に発生している義務である。**

6. **高リスク規制の本体は 2027-12-02（Annex III）／2028-08-02（Annex I）まで延期された** が、延期されたのは義務の適用であって、設計時点で織り込むべき要求事項が消えたわけではない。Art. 111(2) により、延期期日前に市場に出しておけば「設計の重大な変更」があるまで規制の外に置かれるという構造がある。

---

## 確認できなかったこと

1. **Art. 4a の適用開始日の公式確認**。Art. 4a は Chapter I に新設されたため、Chapter I の適用日（2025-02-02）と改正法の発効日（2026-07-27）のどちらを起点とするかは条文の文面からは明示されていない。本ドシエでは「改正法発効日から存在するので 2026-07-27 から」と読んだが、**これは本ドシエの推論であり、公式ガイダンスによる裏付けはない**。

2. **旧 Art. 10(5) から新 Art. 4a への移行に関する経過措置の有無**。Regulation (EU) 2026/1744 に該当する経過規定は見つけられなかったが、全文を網羅的に精査したわけではない。

3. **Art. 4（AI リテラシー）の監督・執行がいつから始まるか**。二次解説は「2026-08-03 から national supervision」とするが、これを直接支える条文は特定できなかった。**食い違いとして記録する** — 適用日（2025-02-02、Art. 113(a) で確認済み）と執行開始日は別問題である。

4. **Art. 50 ガイドライン最終版の正式採択日**。Commission ページには "Last update 6 August 2026" とあるのみで、採択日の記載は見つからなかった。二次解説は 2026-07-20 とする。**食い違いとして記録する。**

5. **Code of Practice on Transparency of AI-generated Content の最終版本文と、Commission による adequacy 判断の正式文書**。二次解説（Faegre Drinker）が「adequate と確認された」と報じているが、Commission 側の一次文書（決定・公表日・本文 URL）は確認できず。

6. **高リスク分類に関する Commission ガイドライン（Art. 6(5) 要求）が最終版になっているか**。2026-05-19 に draft が公表されたことは確認できた（https://digital-strategy.ec.europa.eu/en/library/draft-commission-guidelines-classification-high-risk-ai-systems）が、2026-09-13 時点で最終版が採択されたかは確認できず。なお Art. 113(c) は Art. 6(5) を延期の対象から除外している。

7. **Annex IV の全 9 項目の逐語**。point 1 と point 2 の (a)(b)(c) のみ引用した。残りは consolidated 版の ANNEX IV を直接参照のこと。

8. **Annex VI（内部管理手続）と Annex VII（notified body 関与手続）の本文**。本ドシエでは Art. 43 の振り分けのみを扱い、各手続の中身は取得していない。

9. **Annex III の各 point（1〜8）の具体的な用途一覧**。本ドシエは Art. 43 と Art. 27 が point 番号で振り分けを行うことのみを記録した。用途一覧そのものは R1／R2 の担当範囲と想定される。

10. **罰則（Art. 99）の金額と、2026 年改正による変更の有無**。Art. 99 が改正されたことは改正法の一覧から確認できたが、中身は取得していない。本ドシエの範囲外と判断した。

11. **Art. 26(10)（事後遠隔生体識別の法執行利用）の詳細**。条文は取得済みだが、本ドシエでは範囲外として要旨のみ記載した。

---

## 出典一覧

| # | 出典 | URL | 種別 |
|---|---|---|---|
| S1 | Regulation (EU) 2024/1689 原典（OJ L, 2024/1689, 12.7.2024） | https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689 | [条文] |
| S2 | Regulation (EU) 2024/1689 現行 consolidated 版（02024R1689 — EN — 27.07.2026 — 001.001） | https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:02024R1689-20260727 | [条文] |
| S3 | Regulation (EU) 2026/1744 of 8 July 2026（Digital Omnibus on AI、OJ L, 2026/1744, 24.7.2026、発効 2026-07-27） | https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32026R1744 | [条文] |
| S4 | EUR-Lex 書誌情報（2024/1689） | https://eur-lex.europa.eu/legal-content/EN/ALL/?uri=CELEX:32024R1689 | [条文] |
| S5 | EUR-Lex 書誌情報（2026/1744） | https://eur-lex.europa.eu/legal-content/EN/ALL/?uri=CELEX:32026R1744 | [条文] |
| S6 | Commission — Guidelines on transparency obligations（Art. 50） | https://digital-strategy.ec.europa.eu/en/policies/guidelines-transparency-ai-generated-content | [公式ガイダンス] |
| S7 | Commission — Draft guidelines on the classification of high-risk AI systems（2026-05-19 draft） | https://digital-strategy.ec.europa.eu/en/library/draft-commission-guidelines-classification-high-risk-ai-systems | [公式ガイダンス] |
| S8 | Commission — Guidelines for providers and deployers of AI high-risk systems | https://digital-strategy.ec.europa.eu/en/policies/guidelines-ai-high-risk-systems | [公式ガイダンス] |
| S9 | AI Act Service Desk（Commission 運営） | https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-6 | [公式ガイダンス] |
| S10 | artificialintelligenceact.eu — Article 3 / 25 / 50 解説 | https://artificialintelligenceact.eu/article/3/ ほか | [二次解説] |
| S11 | Faegre Drinker — Transparency Code of Practice adequacy 報道 | https://www.faegredrinker.com/en/insights/publications/2026/7/eu-ai-act-commission-confirms-transparency-code-of-practice-as-adequate-and-publishes-final-version-of-its-guidelines-on-transparency-obligations | [二次解説] |
| S12 | Gibson Dunn — EU AI Act Omnibus Agreement | https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/ | [二次解説] |
| S13 | lawandtechnology.eu — Digital Omnibus rewrites Article 4 | https://lawandtechnology.eu/en/ai-literacy-digital-omnibus-article-4-ai-act/ | [二次解説] |

**本ドシエの条文引用はすべて S2（consolidated 27.07.2026）または S3（改正法）から取得した。S1 は改正前文言の比較のためにのみ使用した。S10〜S13 の二次解説は日付・経緯の裏取りにのみ使用し、条文の文言そのものは一次資料から直接取得している。**
