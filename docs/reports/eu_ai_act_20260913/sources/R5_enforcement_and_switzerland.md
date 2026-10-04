# R5 — 執行・罰則・域外適用、およびスイスに拠点を置く側の立場

調査日: 2026-09-13
出典種別タグ: `[条文]` = 法令本文 / `[公式]` = EU・スイス連邦・欧州評議会の公式発表 / `[二次解説]` = 法律事務所・研究機関・報道

---

## 0. 前提 — 2026 年 7 月の改正法（これを踏まえないと条文番号が古くなる）

**AI Act 本体**
- Regulation (EU) 2024/1689 of 13 June 2024 (Artificial Intelligence Act)
- URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
- `[条文]`

**改正法（Digital Omnibus on AI）— 実在を EUR-Lex 本文で確認済み**
- Regulation (EU) 2026/1744 of 8 July 2026, OJ L, 2026/1744, 24.7.2026
- 正式題名（原文）: "amending Regulations (EU) 2024/1689, (EU) 2018/1139 and (EU) 2023/1230 as regards the simplification of the implementation of harmonised rules on artificial intelligence (Digital Omnibus on AI)"
- URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202601744
- 発効: Article 4「This Regulation shall enter into force on the third day following that of its publication」→ 官報掲載 24.7.2026 の 3 日後 = **2026-07-27**（改正法自身が他条で "from 27 July 2026" と明記しており裏が取れる）
- `[条文]`

この改正法が本項目に関係する範囲（Article 1 の改正項目 1〜43 を全件確認した結果）:

| 本 dossier の対象条文 | 2026/1744 による改正 |
|---|---|
| Art 2(1)(a)(b)(c) 域外適用 | **改正なし**（改正されたのは 2(2)、2(7)、および新設 2(13) のみ） |
| Art 2(6) 科学研究の適用除外 | **改正なし** |
| Art 22 高リスク・第三国提供者の代理人 | **改正なし** |
| Art 54 GPAI・第三国提供者の代理人 | **改正なし** |
| Art 99 罰則 | 改正あり — 99(1) 差替、99(4) に (da) 追加、**99(6a) を新設** |
| Art 101 GPAI 提供者への制裁金 | **改正なし** |
| Art 70 国内当局の指定 | 70(8) のみ差替（SMC への助言に関する文言追加） |
| Art 88 GPAI 執行 | **改正なし** |
| Art 75 市場監視 | 大幅改正 — AI Office の排他的所管が拡大、Art 75a 新設 |
| Art 113 適用開始日 | 改正あり — 高リスク規定の適用開始が後ろ倒し |

**適用開始日（Art 113、2026/1744 改正後）** `[条文]`
- 2025-02-02: Chapter I・II（ただし Art 5(1) 第一副段落 (ba)(bb) と Art 5(1a)(1b) は 2026-12-02 から）
- 2025-08-02: Chapter III Section 4、Chapter V（GPAI）、Chapter VII、Chapter XII、Art 78（Art 101 を除く）
- 2026-08-02: 原則の適用開始日（Art 113 第 2 段落「It shall apply from 2 August 2026.」は改正されていない）
- **2027-12-02**: Annex III 高リスク（Art 6(2)）
- **2028-08-02**: Annex I 高リスク（Art 6(1)）
- 2026-07-27: Articles 102〜110

原文（改正後 Art 113 第 3 段落 (c)）:
> "Chapter III, Sections 1, 2, and 3, with the exception of Article 6(5), shall apply from: (i) 2 December 2027 as regards AI systems classified as high-risk pursuant to Article 6(2) and Annex III; and (ii) 2 August 2028 as regards AI systems classified as high-risk pursuant to Article 6(1) and Annex I;"

日本語: 高リスク AI の実体要件の適用開始が、Annex III 系は 2027 年 12 月 2 日、Annex I 系は 2028 年 8 月 2 日に後ろ倒しされた。**禁止行為（Art 5）と透明性義務（Art 50）と GPAI 義務は後ろ倒しされていない。**

---

## 1. 域外適用 — Article 2(1)

### 1.1 条文（原文・逐語）

出典: Regulation (EU) 2024/1689, Article 2(1)
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
`[条文]`

> "1. This Regulation applies to:
> (a) providers placing on the market or putting into service AI systems or placing on the market general-purpose AI models in the Union, irrespective of whether those providers are established or located within the Union or in a third country;
> (b) deployers of AI systems that have their place of establishment or are located within the Union;
> (c) providers and deployers of AI systems that have their place of establishment or are located in a third country, where the output produced by the AI system is used in the Union;
> (d) importers and distributors of AI systems;
> (e) product manufacturers placing on the market or putting into service an AI system together with their product and under their own name or trademark;
> (f) authorised representatives of providers, which are not established in the Union;
> (g) affected persons that are located in the Union."

日本語訳（要旨）:
- (a) EU 域内で AI システムを上市・供用する提供者、または EU 域内で GPAI モデルを上市する提供者。**提供者が EU 域内にいるか第三国にいるかを問わない。**
- (b) EU 域内に設立地を持つ、または所在する利用者（deployer）。
- (c) **第三国に設立地を持つ、または所在する提供者および利用者であって、当該 AI システムが生み出した出力が EU 域内で使用されるもの。**
- (f) EU 域内に設立されていない提供者の授権代理人。
- (g) EU 域内に所在する影響を受ける者。

**食い違い（テキスト差異）**: 二次解説サイト artificialintelligenceact.eu の Art 2(1)(a) は "providers placing on the market or putting into service AI systems **or general-purpose AI models** in the Union" と表記しており、官報正文の "or **placing on the market** general-purpose AI models in the Union" と語順・語句が異なる。官報（EUR-Lex）が正文。
- 二次出典 URL: https://artificialintelligenceact.eu/article/2/ `[二次解説]`

### 1.2 (c) の趣旨を説明する Recital 22（逐語）

出典: Regulation (EU) 2024/1689, Recital 22
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
`[条文]`

> "In light of their digital nature, certain AI systems should fall within the scope of this Regulation even when they are not placed on the market, put into service, or used in the Union. This is the case, for example, where an operator established in the Union contracts certain services to an operator established in a third country in relation to an activity to be performed by an AI system that would qualify as high-risk. In those circumstances, the AI system used in a third country by the operator could process data lawfully collected in and transferred from the Union, and provide to the contracting operator in the Union the output of that AI system resulting from that processing, without that AI system being placed on the market, put into service or used in the Union. To prevent the circumvention of this Regulation and to ensure an effective protection of natural persons located in the Union, this Regulation should also apply to providers and deployers of AI systems that are established in a third country, to the extent the output produced by those systems is intended to be used in the Union."

日本語: デジタルという性質に照らすと、EU 域内で上市・供用・使用されていない AI システムであっても本規則の適用範囲に入るべき場合がある。たとえば EU 域内に設立された事業者が、高リスクに該当する活動を第三国の事業者に外注する場合である。このとき第三国の AI システムは、EU で適法に収集され EU から移転されたデータを処理し、その出力を EU 域内の発注者に返しうる。この間、当該 AI システムは EU 域内で上市も供用も使用もされていない。**本規則の潜脱を防ぎ、EU 域内に所在する自然人を実効的に保護するため**、第三国に設立された提供者・利用者にも、その出力が EU 域内で使用されることが**意図されている**限りにおいて、本規則が適用されるべきである。

### 1.3 ここが不確かな点 — 「used」と「intended to be used」の乖離

**食い違い（条文 vs 前文、いずれも AI Act 正文内部）**:

| 箇所 | 原文 | 意味 |
|---|---|---|
| Art 2(1)(c)（法的拘束力あり） | "where the output produced by the AI system **is used** in the Union" | 出力が EU で**実際に使われている**こと |
| Recital 22（解釈指針、拘束力なし） | "to the extent the output produced by those systems **is intended to be used** in the Union" | 出力が EU で使われることが**意図されている**こと |

この差は条文の起草過程で残ったものであり、AI Act 本文はどちらの読み方を採るかを明示していない。前文は条文の解釈指針にすぎず、条文の文言を上書きできない（EU 法の一般原則）。したがって:

- 文言どおり読めば、提供者の意図とは無関係に、**EU 域内の誰かが出力を実際に使った時点で** (c) の要件は満たされうる。
- 一方 Recital 22 の趣旨（潜脱防止）を重く読めば、EU 向けに出力を提供する構成が対象であって、提供者がまったく予期しない EU からの偶発的アクセスまでは射程外だ、という解釈も成り立つ。

**「EU の研究者がサービスを使えばそれだけで発動するか」への回答**: 条文の文言に照らすかぎり、**発動しうる**。ただし (c) が発動しても、それは AI Act の適用範囲に入るというだけであって、直ちに具体的義務が生じるわけではない。生じる義務は、そのシステムが (i) 禁止行為（Art 5）に当たるか、(ii) 高リスクに当たるか、(iii) Art 50 の透明性義務の対象か、(iv) GPAI モデルか、によって決まる。この 4 つのいずれにも当たらないシステムには、Art 2(1)(c) が発動しても実体的義務はほぼ生じない。**「適用範囲に入る」と「義務を負う」は別の問題**である点が、二次解説でしばしば混同されている。

**確認できず**: Art 2(1)(c) の「used」の解釈について、欧州委員会のガイドラインや CJEU 判例で決着がついた形跡は、2026-09-13 時点で見つけられなかった。Art 96 に基づくガイドラインのうち Art 2(1)(c) を正面から扱ったものの存在を確認できなかった。

### 1.4 科学研究の適用除外（チューリヒの読み手に直接効く）

出典: Regulation (EU) 2024/1689, Article 2(6), (8), (10) — いずれも 2026/1744 による改正なし
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
`[条文]`

> "6. This Regulation does not apply to AI systems or AI models, including their output, specifically developed and put into service for the sole purpose of scientific research and development."

日本語: 本規則は、**科学的な研究開発のみを目的として**特別に開発され供用された AI システム・AI モデル（その出力を含む）には適用されない。

> "8. This Regulation does not apply to any research, testing or development activity regarding AI systems or AI models prior to their being placed on the market or put into service. Such activities shall be conducted in accordance with applicable Union law. Testing in real world conditions shall not be covered by that exclusion."

日本語: 上市・供用の前段階における AI システム・AI モデルの研究・試験・開発活動には本規則は適用されない。ただし**実世界条件での試験（testing in real world conditions）はこの除外に含まれない**。

> "12. This Regulation does not apply to AI systems released under free and open-source licences, unless they are placed on the market or put into service as high-risk AI systems or as an AI system that falls under Article 5 or 50."

日本語: 自由・オープンソースライセンスで公開された AI システムには適用されない。ただし高リスクとして、または Art 5・Art 50 に該当するものとして上市・供用される場合を除く。

**注意点（不確かさ）**: Art 2(6) の "sole purpose"（唯一の目的）は狭い。研究目的で作ったものを外部の研究者にサービスとして提供し始めた時点で、"sole purpose of scientific research and development" を維持していると言えるかは条文からは判断できない。「研究用だから対象外」と即断できる条文ではない。**確認できず**: この境界について委員会ガイドラインは確認できなかった。

---

## 2. 第三国の提供者の代理人 — Article 22 / Article 54

### 2.1 高リスク AI システム — Article 22

出典: Regulation (EU) 2024/1689, Article 22（2026/1744 による改正なし）
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
`[条文]`

見出し: "Authorised representatives of providers of high-risk AI systems"

> "1. Prior to making their high-risk AI systems available on the Union market, providers established in third countries shall, by written mandate, appoint an authorised representative which is established in the Union."

日本語: **第三国に設立された提供者は、高リスク AI システムを EU 市場で利用可能にする前に、書面による委任により、EU 域内に設立された授権代理人を選任しなければならない。**

> "3. The authorised representative shall perform the tasks specified in the mandate received from the provider. It shall provide a copy of the mandate to the market surveillance authorities upon request, in one of the official languages of the institutions of the Union, as indicated by the competent authority. For the purposes of this Regulation, the mandate shall empower the authorised representative to carry out the following tasks:
> (a) verify that the EU declaration of conformity referred to in Article 47 and the technical documentation referred to in Article 11 have been drawn up and that an appropriate conformity assessment procedure has been carried out by the provider;
> (b) keep at the disposal of the competent authorities and national authorities or bodies referred to in Article 74(10), for a period of 10 years after the high-risk AI system has been placed on the market or put into service, the contact details of the provider that appointed the authorised representative, a copy of the EU declaration of conformity referred to in Article 47, the technical documentation and, if applicable, the certificate issued by the notified body;
> (c) provide a competent authority, upon a reasoned request, with all the information and documentation, including that referred to in point (b) of this subparagraph, necessary to demonstrate the conformity of a high-risk AI system with the requirements set out in Section 2, including access to the logs, as referred to in Article 12(1), automatically generated by the high-risk AI system, to the extent such logs are under the control of the provider;
> (d) cooperate with competent authorities, upon a reasoned request, in any action the latter take in relation to the high-risk AI system, in particular to reduce and mitigate the risks posed by the high-risk AI system;
> (e) where applicable, comply with the registration obligations referred to in Article 49(1), or, if the registration is carried out by the provider itself, ensure that the information referred to in point 3 of Section A of Annex VIII is correct."

代理人の任務（日本語）: (a) EU 適合宣言と技術文書が作成され、適切な適合性評価手続が提供者により実施されたことの確認。(b) 上市・供用から **10 年間**、提供者の連絡先・EU 適合宣言の写し・技術文書・（該当すれば）通知機関の証明書を当局の利用に供すること。(c) 理由を付した請求に応じ、適合性を示すのに必要な情報・文書一切（提供者の管理下にあるログへのアクセスを含む）を所管当局に提供すること。(d) 理由を付した請求に応じ、当局の措置に協力すること。(e) 該当する場合、Art 49(1) の登録義務を履行すること。

> "The mandate shall empower the authorised representative to be addressed, in addition to or instead of the provider, by the competent authorities, on all issues related to ensuring compliance with this Regulation."

日本語: 委任は、本規則の遵守確保に関するすべての事項について、当局が提供者に加えてまたは提供者に代えて代理人に連絡できる権限を与えるものでなければならない。

> "4. The authorised representative shall terminate the mandate if it considers or has reason to consider the provider to be acting contrary to its obligations pursuant to this Regulation. In such a case, it shall immediately inform the relevant market surveillance authority, as well as, where applicable, the relevant notified body, about the termination of the mandate and the reasons therefor."

日本語: 代理人は、提供者が本規則上の義務に反していると判断するか、そう判断する理由があるときは、**委任を終了させなければならない**。その場合、直ちに市場監視当局（該当すれば通知機関も）に終了とその理由を通知する。

**発動条件の確認**: Art 22 は「高リスク AI システム」を「EU 市場で利用可能にする前」に発動する。**高リスクでないシステムには Art 22 の代理人選任義務はない。** また Art 2(1)(c) だけで（EU 市場に出していないのに）Art 22 が発動するかは条文上明確でない。Art 22(1) の文言は "making their high-risk AI systems available on the Union market" であり、Art 2(1)(c) の「出力が EU で使われる」構成を直接には捉えていない。**確認できず**: この点を明示した公式解釈は見つけられなかった。

### 2.2 GPAI モデル — Article 54

出典: Regulation (EU) 2024/1689, Article 54（2026/1744 による改正なし）
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
`[条文]`

> "1. Prior to placing a general-purpose AI model on the Union market, providers established in third countries shall, by written mandate, appoint an authorised representative which is established in the Union."

日本語: 第三国に設立された提供者は、GPAI モデルを EU 市場に上市する前に、書面委任により EU 域内に設立された授権代理人を選任しなければならない。

代理人の任務（Art 54(3)）: (a) Annex XI の技術文書が作成され、Art 53 および該当すれば Art 55 の義務が履行されていることの確認、(b) 上市後 **10 年間** Annex XI 技術文書の写しと提供者の連絡先を AI Office および国内所管当局の利用に供すること、(c) 理由を付した請求に応じ AI Office に情報・文書を提供すること、(d) AI Office および所管当局に協力すること。委任先は AI Office に対して提出する（Art 22 が市場監視当局に提出するのと異なる）。

**重要な免除 — Art 54(6)**:
> "6. The obligation set out in this Article shall not apply to providers of general-purpose AI models that are released under a free and open-source licence that allows for the access, usage, modification, and distribution of the model, and whose parameters, including the weights, the information on the model architecture, and the information on model usage, are made publicly available, unless the general-purpose AI models present systemic risks."

日本語: アクセス・使用・改変・頒布を許す自由/オープンソースライセンスで公開され、かつ重みを含むパラメータ・モデル構造の情報・モデル利用の情報が公開されている GPAI モデルの提供者には、本条の義務は適用されない。ただし当該 GPAI モデルが**システミックリスク**を有する場合を除く。

---

## 3. 罰則 — Article 99 / Article 101 / Article 100

出典: Regulation (EU) 2024/1689, Article 99（Regulation (EU) 2026/1744 Art 1(38) により一部改正）
URL（原典）: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
URL（改正法）: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202601744
`[条文]`

### 3.1 制裁金の段階表

| 条 | 対象となる違反 | 絶対額 | 全世界売上高比 | どちらを採るか |
|---|---|---|---|---|
| Art 99(3) | Art 5 の禁止行為（prohibited practices）の不遵守 | 3,500 万ユーロ | 前会計年度の全世界年間総売上高の **7%** | **高い方**（whichever is higher） |
| Art 99(4) | 事業者・通知機関に関するその他の義務の不遵守（Art 5 を除く）— Art 16 提供者義務、Art 22 代理人義務、Art 23 輸入者、Art 24 頒布者、**Art 25(2)(4)**、Art 26 利用者義務、Art 31/33(1)(3)(4)/34 通知機関、**Art 50 透明性義務** | 1,500 万ユーロ | **3%** | **高い方** |
| Art 99(5) | 通知機関または国内所管当局への、不正確・不完全・誤解を招く情報の提供 | 750 万ユーロ | **1%** | **高い方** |
| Art 99(6) | **SME（新興企業を含む）**: 上記 (3)(4)(5) すべてについて | ← 同額 | ← 同率 | **低い方**（whichever is lower） |
| Art 99(6a)（2026 新設） | **SMC（small mid-cap enterprise）**: (4) と (5) のみ | ← 同額 | ← 同率 | **低い方** |
| Art 101(1) | GPAI モデル提供者に対し**欧州委員会**が科す制裁金 | 1,500 万ユーロ | **3%** | **高い方** |
| Art 100(2) | EU の機関・組織による Art 5 禁止行為 | 150 万ユーロ | — | — |
| Art 100(3) | EU の機関・組織によるその他の違反 | 75 万ユーロ | — | — |

### 3.2 逐語引用

**Art 99(3)** `[条文]`
> "3. Non-compliance with the prohibition of the AI practices referred to in Article 5 shall be subject to administrative fines of up to EUR 35 000 000 or, if the offender is an undertaking, up to 7 % of its total worldwide annual turnover for the preceding financial year, whichever is higher."

日本語: Art 5 に定める AI 実務の禁止に対する不遵守は、3,500 万ユーロ以下の、または違反者が事業体である場合は前会計年度の全世界年間総売上高の 7% 以下の行政制裁金の対象となる。**いずれか高い方。**

**Art 99(4)**（改正後。2026/1744 Art 1(38)(b) が (da) を挿入） `[条文]`
> "4. Non-compliance with any of the following provisions related to operators or notified bodies, other than those laid down in Articles 5, shall be subject to administrative fines of up to EUR 15 000 000 or, if the offender is an undertaking, up to 3 % of its total worldwide annual turnover for the preceding financial year, whichever is higher:
> (a) obligations of providers pursuant to Article 16;
> (b) obligations of authorised representatives pursuant to Article 22;
> (c) obligations of importers pursuant to Article 23;
> (d) obligations of distributors pursuant to Article 24;
> (da) obligations of providers and operators pursuant to Article 25(2) and (4);
> (e) obligations of deployers pursuant to Article 26;
> (f) requirements and obligations of notified bodies pursuant to Article 31, Article 33(1), (3) and (4) or Article 34;
> (g) transparency obligations for providers and deployers pursuant to Article 50."

（注: 冒頭の "other than those laid down in Articles 5" は官報正文どおり。"Articles" は正文の誤記と思われるが原文ママ。(da) は Regulation (EU) 2026/1744 による挿入。）

日本語: Art 5 に定めるものを除く、事業者または通知機関に関する以下のいずれかの規定の不遵守は、1,500 万ユーロ以下、または事業体の場合は前会計年度の全世界年間総売上高の 3% 以下の行政制裁金の対象となる。いずれか高い方。(a) Art 16 の提供者義務、(b) Art 22 の授権代理人義務、(c) Art 23 の輸入者義務、(d) Art 24 の頒布者義務、(da) Art 25(2)(4) の提供者・事業者義務、(e) Art 26 の利用者義務、(f) Art 31・33(1)(3)(4)・34 の通知機関の要件と義務、(g) Art 50 の提供者・利用者の透明性義務。

**Art 99(5)** `[条文]`
> "5. The supply of incorrect, incomplete or misleading information to notified bodies or national competent authorities in reply to a request shall be subject to administrative fines of up to EUR 7 500 000 or, if the offender is an undertaking, up to 1 % of its total worldwide annual turnover for the preceding financial year, whichever is higher."

日本語: 請求に応じて通知機関または国内所管当局に不正確・不完全・誤解を招く情報を提供したことは、750 万ユーロ以下、または事業体の場合は前会計年度の全世界年間総売上高の 1% 以下の行政制裁金の対象となる。いずれか高い方。

**Art 99(6) — SME / 新興企業の特則（逐語）** `[条文]`
> "6. In the case of SMEs, including start-ups, each fine referred to in this Article shall be up to the percentages or amount referred to in paragraphs 3, 4 and 5, whichever thereof is lower."

日本語: **SME（新興企業を含む）の場合、本条に定める各制裁金は、第 3 項・第 4 項・第 5 項に定める割合または金額のうち、いずれか低い方を上限とする。**

→ つまり SME にとっては、売上高が小さいほど「%」側が小さくなるので、実際上は「%」側が上限になる。全世界年間総売上高が 500 万ユーロの SME が Art 5 違反をした場合、上限は 7% = 35 万ユーロであって 3,500 万ユーロではない。

**Art 99(6a) — SMC の特則（2026/1744 により新設、逐語）** `[条文]`
> "6a. In the case of SMCs, each fine referred to in paragraphs 4 and 5 shall be up to the percentages or amount referred therein, whichever is lower."

日本語: SMC の場合、**第 4 項および第 5 項**に定める各制裁金は、そこに定める割合または金額のうちいずれか低い方を上限とする。

**重要な非対称**: Art 99(6)（SME）は **(3)(4)(5) すべて**を対象とするのに対し、Art 99(6a)（SMC）は **(4) と (5) のみ**で、**(3) の禁止行為は対象外**。したがって SMC が Art 5 の禁止行為を行った場合、「高い方」の原則に戻り、3,500 万ユーロが上限となりうる。

**SME / SMC の定義**（2026/1744 が Art 3 に新設）`[条文]`
> "(14a) 'micro, small and medium-sized enterprise' or 'SME' means a micro, small or medium-sized enterprise as defined in Article 2 of the Annex to Recommendation 2003/361/EC;
> (14b) 'small mid-cap enterprise' or 'SMC' means a small mid-cap enterprise as defined in point (2) of the Annex to Recommendation (EU) 2025/1099;"

日本語: SME は勧告 2003/361/EC 附属書 Art 2 の定義による（従業員 250 人未満かつ売上高 5,000 万ユーロ以下または総資産 4,300 万ユーロ以下、が同勧告の基準）。SMC は勧告 (EU) 2025/1099 附属書第 2 点の定義による。

**Art 99(1)（2026/1744 により差替）** `[条文]`
> "1. In accordance with the terms and conditions laid down in this Regulation, Member States shall lay down the rules on penalties and other enforcement measures, which may also include administrative fines, warnings and non-monetary measures, applicable to any infringement of this Regulation by operators, and shall take all measures necessary to ensure that they are properly and effectively implemented, thereby taking into account the guidelines issued by the Commission pursuant to Article 96. The penalties provided for shall be effective, proportionate and dissuasive. The Member States shall take into account the interests of SMEs, including start-ups, and SMCs, and their economic viability when imposing penalties."

日本語: 制裁の具体的規則は**加盟国が定める**。制裁は実効的・比例的・抑止的でなければならない。加盟国は制裁を科す際、SME（新興企業を含む）および SMC の利益とその経済的存続可能性を考慮しなければならない。

### 3.3 Art 99(7) — 制裁金額を決めるときに当局が考慮する要素（逐語）

`[条文]`
> "7. When deciding whether to impose an administrative fine and when deciding on the amount of the administrative fine in each individual case, all relevant circumstances of the specific situation shall be taken into account and, as appropriate, regard shall be given to the following:
> (a) the nature, gravity and duration of the infringement and of its consequences, taking into account the purpose of the AI system, as well as, where appropriate, the number of affected persons and the level of damage suffered by them;
> (b) whether administrative fines have already been applied by other market surveillance authorities to the same operator for the same infringement;
> (c) whether administrative fines have already been applied by other authorities to the same operator for infringements of other Union or national law, when such infringements result from the same activity or omission constituting a relevant infringement of this Regulation;
> (d) the size, the annual turnover and market share of the operator committing the infringement;
> (e) any other aggravating or mitigating factor applicable to the circumstances of the case, such as financial benefits gained, or losses avoided, directly or indirectly, from the infringement;
> (f) the degree of cooperation with the national competent authorities, in order to remedy the infringement and mitigate the possible adverse effects of the infringement;
> (g) the degree of responsibility of the operator taking into account the technical and organisational measures implemented by it;
> (h) the manner in which the infringement became known to the national competent authorities, in particular whether, and if so to what extent, the operator notified the infringement;
> (i) the intentional or negligent character of the infringement;
> (j) any action taken by the operator to mitigate the harm suffered by the affected persons."

日本語（要素の一覧）: (a) 違反の性質・重大性・期間とその結果（AI システムの目的、影響を受けた者の数、被害の程度を考慮）、(b) 同一の違反につき他の市場監視当局が既に制裁金を科しているか、(c) 同一の作為・不作為につき他の EU 法・国内法違反で既に制裁金を科されているか、(d) 違反事業者の規模・年間売上高・市場シェア、(e) 違反から直接・間接に得た利益や回避した損失などの加重・軽減要素、(f) 違反の是正と悪影響の緩和に向けた国内所管当局への協力の程度、(g) 実施した技術的・組織的措置を考慮した事業者の責任の程度、(h) 違反が当局に知られた経緯（特に事業者自身が通報したか、どの程度通報したか）、(i) 違反が故意か過失か、(j) 影響を受けた者の被害を緩和するために事業者が採った措置。

**その他の Art 99 の規定** `[条文]`
- 99(2): 加盟国は適用開始日までに制裁規則を委員会に通知する。
- 99(8): 各加盟国は、自国に設立された公的機関・団体に行政制裁金をどこまで科せるかを定める。
- 99(9): 加盟国の法制次第で、制裁金は国内の管轄裁判所が科す形でもよい。
- 99(10): 本条の権限行使は、実効的な司法救済とデュープロセスを含む適切な手続的保障に服する。
- 99(11): 加盟国は毎年、科した行政制裁金と関連訴訟を委員会に報告する。

### 3.4 Article 101 — GPAI モデル提供者への制裁金（逐語）

出典: Regulation (EU) 2024/1689, Article 101（2026/1744 による改正なし）
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
`[条文]`

> "1. The Commission may impose on providers of general-purpose AI models fines not exceeding 3 % of their annual total worldwide turnover in the preceding financial year or EUR 15 000 000, whichever is higher., when the Commission finds that the provider intentionally or negligently:
> (a) infringed the relevant provisions of this Regulation;
> (b) failed to comply with a request for a document or for information pursuant to Article 91, or supplied incorrect, incomplete or misleading information;
> (c) failed to comply with a measure requested under Article 93;
> (d) failed to make available to the Commission access to the general-purpose AI model or general-purpose AI model with systemic risk with a view to conducting an evaluation pursuant to Article 92."

（注: "whichever is higher., when" の句読点は官報正文どおり。原文ママ。）

日本語: **欧州委員会**は、GPAI モデルの提供者に対し、前会計年度の全世界年間総売上高の 3% または 1,500 万ユーロを超えない制裁金を科すことができる（**いずれか高い方**）。委員会が、提供者が故意または過失により次のいずれかを行ったと認定した場合である。(a) 本規則の関連規定への違反、(b) Art 91 に基づく文書・情報の請求への不遵守、または不正確・不完全・誤解を招く情報の提供、(c) Art 93 に基づき要求された措置への不遵守、(d) Art 92 に基づく評価を行うための GPAI モデル（システミックリスクのある GPAI モデルを含む）へのアクセスを委員会に提供しなかったこと。

> "In fixing the amount of the fine or periodic penalty payment, regard shall be had to the nature, gravity and duration of the infringement, taking due account of the principles of proportionality and appropriateness. The Commission shall also into account commitments made in accordance with Article 93(3) or made in relevant codes of practice in accordance with Article 56."

（"shall also into account" は正文どおり。原文ママ。）

日本語: 制裁金または履行強制金の額を定めるにあたっては、比例性と適切性の原則に十分配慮しつつ、違反の性質・重大性・期間を考慮する。委員会は、Art 93(3) に基づく約束および Art 56 に基づく実務規範における約束も考慮する。

その他の項（日本語要旨）:
- 101(2): 決定の前に、委員会は暫定的認定を提供者に伝達し、意見を述べる機会を与えなければならない。
- 101(3): "Fines imposed in accordance with this Article shall be effective, proportionate and dissuasive."
- 101(4): 科した制裁金の情報は、適切に Board に伝達される。
- 101(5): "The Court of Justice of the European Union shall have unlimited jurisdiction to review decisions of the Commission fixing a fine under this Article. It may cancel, reduce or increase the fine imposed."（EU 司法裁判所は制裁金決定について**無制限管轄権**を有し、取消・減額・**増額**ができる。）
- 101(6): 手続の詳細と手続的保障は実施法令で定める。

**適用開始**: Art 113 第 3 段落 (b) により、Chapter XII は 2025-08-02 から適用されるが「with the exception of Article 101」。Art 101 は原則の適用開始日である **2026-08-02** から適用される。

---

## 4. 誰が執行するのか

### 4.1 国内所管当局・市場監視当局 — Article 70

出典: Regulation (EU) 2024/1689, Article 70（70(8) のみ 2026/1744 で改正）
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
`[条文]`

> "1. Each Member State shall establish or designate as national competent authorities at least one notifying authority and at least one market surveillance authority for the purposes of this Regulation. Those national competent authorities shall exercise their powers independently, impartially and without bias..."

日本語: 各加盟国は、本規則の目的のため、**少なくとも 1 の通知当局（notifying authority）と少なくとも 1 の市場監視当局（market surveillance authority）**を国内所管当局として設置または指定しなければならない。これらの当局は独立・公平・偏りなく権限を行使する。

**期限（逐語）**:
> "2. Member States shall communicate to the Commission the identity of the notifying authorities and the market surveillance authorities and the tasks of those authorities, as well as any subsequent changes thereto. Member States shall make publicly available information on how competent authorities and single points of contact can be contacted, through electronic communication means **by 2 August 2025**. Member States shall designate a market surveillance authority to act as the single point of contact for this Regulation, and shall notify the Commission of the identity of the single point of contact. The Commission shall make a list of the single points of contact publicly available."

日本語: 加盟国は通知当局・市場監視当局の身元とその任務を委員会に通知する。加盟国は**2025 年 8 月 2 日までに**、所管当局と単一窓口（single point of contact）への連絡方法を電子的手段で公開しなければならない。加盟国は本規則の単一窓口として機能する市場監視当局を指定し、その身元を委員会に通知する。

> "6. By 2 August 2025, and once every two years thereafter, Member States shall report to the Commission on the status of the financial and human resources of the national competent authorities, with an assessment of their adequacy."

**Art 70(9)**: EU の機関・組織については、**欧州データ保護監察官（EDPS）**が監督の所管当局となる。

### 4.2 加盟国は実際に指定したか — 大幅に未達

**食い違い（数字が出典によって異なる）**:

| 出典 | 時点 | 数字 |
|---|---|---|
| 欧州議会研究局 (EPRS) "Enforcement of the AI Act" | 2026-03-18 公開、2026 年 3 月時点 | 27 加盟国中 **8 か国**のみが単一窓口を指定済み |
| 二次解説（aiacto.eu、Digital Omnibus 議会審議で言及された数字と説明） | 2026 | 27 か国中 **8 か国** |
| 二次解説（axis-intelligence.com） | 2026-06-17 時点 | **9 か国**が市場監視当局と通知当局の両方を指定済み、12 か国が部分的、6 か国が未指定 |
| Future of Life Institute トラッカー（二次解説経由） | 更新時点不明 | 9 か国が両方指定済み、12 か国が立法提案・公表が係属中 |

- EPRS URL: https://epthinktank.eu/2026/03/18/enforcement-of-the-ai-act/ `[二次解説（欧州議会研究局）]`
  - 逐語（要点）: "has the sole authority to enforce the AI Act provisions on GPAI models"（AI Office について）
- 二次解説 URL: https://www.aiacto.eu/en/blog/ai-act-member-states-national-authorities-2026 `[二次解説]`
- トラッカー URL: https://artificialintelligenceact.eu/national-implementation-plans/ `[二次解説]`

**個別例（ドイツ）** `[二次解説]`
- URL: https://euronews.com/next/2025/08/06/german-government-urged-to-start-proper-supervision-of-ai
- ドイツは 2025 年 8 月 2 日の期限までに市場監視当局を欧州委員会に通知しなかった。ハンブルクのデータ保護監察官 Thomas Fuchs は連邦政府に迅速な指定を求め、企業と行政機関に「拘束力のある連絡先」が欠けていると警告した。

**確認できず**: 2026-09-13 時点の正確な指定済み加盟国数を、欧州委員会の公式一覧（Art 70(2) が委員会に公開を義務づけている single points of contact のリスト）で直接確認することはできなかった。上記はすべて 2026 年 3〜6 月時点の数字である。

**評価**: 加盟国側の遅延は企業側の義務を免除しない。ただし実務上、執行の実効性は当局の整備状況に依存する。

### 4.3 AI Office と European AI Board — Article 64〜68

出典: Regulation (EU) 2024/1689, Articles 64〜68
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202401689
`[条文]`

**Art 64 — AI Office**
> "1. The Commission shall develop Union expertise and capabilities in the field of AI through the AI Office.
> 2. Member States shall facilitate the tasks entrusted to the AI Office, as reflected in this Regulation."

2026/1744 により Art 64 に新設された第 3 項:
> "3. Without prejudice to the budgetary procedure, the AI Office shall be allocated adequate resources to effectively perform its duties and exercise its powers in relation to the enforcement of this Regulation."

日本語: AI Office は**欧州委員会の内部組織**であり、独立機関ではない。2026 年改正で「執行のための十分な資源を配分する」旨が追加された。

**Art 65 — European Artificial Intelligence Board（Board）**
> "1. A European Artificial Intelligence Board (the 'Board') is hereby established.
> 2. The Board shall be composed of one representative per Member State. The European Data Protection Supervisor shall participate as observer. The AI Office shall also attend the Board's meetings, without taking part in the votes."

日本語: Board は**加盟国 1 名ずつの代表**で構成される。EDPS はオブザーバー参加。AI Office も出席するが投票には参加しない。任期 3 年、1 回更新可（Art 65(3)）。Art 65(6) により市場監視当局と通知当局の 2 つの常設サブグループを設置する。

**Art 66 — Board の任務**
> "The Board shall advise and assist the Commission and the Member States in order to facilitate the consistent and effective application of this Regulation."

日本語: Board は**助言・支援機関**であって、制裁を科す権限は持たない。

**Art 67 — advisory forum（諮問フォーラム）、Art 68 — scientific panel of independent experts（独立専門家科学パネル）**: いずれも技術的専門知識を提供する補助機関。

### 4.4 GPAI 義務の執行 — Article 88

出典: Regulation (EU) 2024/1689, Article 88（2026/1744 による改正なし）
`[条文]`

> "1. The Commission shall have exclusive powers to supervise and enforce Chapter V, taking into account the procedural guarantees under Article 94. The Commission shall entrust the implementation of these tasks to the AI Office, without prejudice to the powers of organisation of the Commission and the division of competences between Member States and the Union based on the Treaties.
> 2. Without prejudice to Article 75(3), market surveillance authorities may request the Commission to exercise the powers laid down in this Section, where that is necessary and proportionate to assist with the fulfilment of their tasks under this Regulation."

日本語: **欧州委員会が Chapter V（GPAI モデル）の監督・執行の排他的権限を持つ**。委員会はこの任務の実施を **AI Office** に委ねる。市場監視当局は、必要かつ比例的な場合、本節の権限行使を委員会に要請できる。

### 4.5 2026 年改正による執行構造の変更 — AI Office の所管拡大（Art 75、Art 75a 新設）

出典: Regulation (EU) 2026/1744, Article 1(31)(32)
URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202601744
`[条文]`

改正後の Art 75(1)（逐語）:
> "1. The AI Office shall be exclusively competent for the supervision and enforcement of the obligations under this Regulation in relation to the following AI systems:
> (a) AI systems based on general-purpose AI models where the model and the system are developed by the same provider, or by providers forming part of the same undertaking as that provider, with the exception of: (i) AI systems related to products covered by the Union harmonisation legislation listed in Annex I; (ii) AI systems referred to in point 2 of Annex III; (iii) AI systems provided by law enforcement authorities, border management authorities and financial institutions, insofar as those AI systems fall under Article 74(6); and (iv) AI systems referred to in point 8 of Annex III as regards the administration of justice;
> (b) AI systems that constitute or that are integrated into a very large online platform or very large online search engine designated in accordance with Regulation (EU) 2022/2065.
> The exclusive competence referred to in the first subparagraph shall apply to the providers of those systems. It shall apply to the deployers of those systems only when they are also the provider or form part of the same undertaking as the provider."

日本語: AI Office は、(a) **同一の提供者（または同一企業グループの提供者）が GPAI モデルとその上の AI システムの両方を開発した場合の当該 AI システム**（4 つの例外あり）、および (b) DSA（Regulation (EU) 2022/2065）で指定された超大規模オンラインプラットフォーム／検索エンジンを構成するか、それに統合された AI システム、について**排他的な監督・執行権限**を持つ。この排他的権限は当該システムの**提供者**に及ぶ。**利用者（deployer）**には、その利用者が同時に提供者であるか提供者と同一企業に属する場合にのみ及ぶ。

新設 Art 75a（逐語、冒頭）:
> "1. When exercising its tasks of supervision and enforcement laid down in Article 75(1) of this Regulation, the AI Office shall have all the powers of a market surveillance authority provided for in this Section and in Article 14(4) and Article 16(3) of Regulation (EU) 2019/1020. The AI Office shall be authorised to fully reclaim from the relevant operator the totality of the costs of its supervision and enforcement activities with respect to instances of non-compliance, including costs for human and technical resources..."

日本語: AI Office は Art 75(1) の任務を行使するとき、本節および市場監視規則 (EU) 2019/1020 Art 14(4)・16(3) に定める市場監視当局の**すべての権限**を持つ。不遵守事案については、人的・技術的資源のコストを含む監督・執行活動の費用全額を、当該事業者から回収する権限を与えられる。

改正後 Art 75(2a): 市場監視当局は、Art 75(1) の AI システムの提供者・利用者が違反したと疑う十分な理由があるとき、Art 70(2) の単一窓口を通じて AI Office に評価を要請できる。AI Office は**遅くとも要請受領から 4 か月以内に**、権限行使の意向またはその理由を単一窓口に通知しなければならない。

**評価**: 2026 年改正は、執行の重心を加盟国当局から欧州委員会（AI Office）へ一定程度移した。加盟国の指定遅延（§4.2）への構造的対応と読める。

### 4.6 2026 年 9 月時点で実際の執行措置はあったか

**欧州委員会公式ページ**
- "The enforcement framework of the AI Act", Shaping Europe's digital future
- URL: https://digital-strategy.ec.europa.eu/en/policies/enforcement-ai-act
- ページ最終更新: **2026-08-24**
- 逐語: "The enforcement of the AI Act is shared between the European Commission's AI Office, the European Data Protection Supervisor, and national competent authorities designated by the Member States."
- `[公式]`
- **このページには、実際に行われた執行措置・調査・制裁金の記載は一切ない。** 権限と枠組みのみを記述している。

**EPRS（欧州議会研究局）2026-03-18**
- URL: https://epthinktank.eu/2026/03/18/enforcement-of-the-ai-act/
- `[二次解説（欧州議会研究局）]`
- 実際に採られた執行措置への言及なし。

**食い違い（二次情報。いずれも裏付けなし）**:

| 主張 | 出典 | 評価 |
|---|---|---|
| 2026-08-02 の期限から数日内に、欧州委員会が計 **4,700 万ユーロ**の執行措置 3 件を確認。最大は汎欧州の HR テック企業への **1,800 万ユーロ** | https://www.aipolicydesk.com/blog/eu-ai-act-first-fines-47-million-hiring-emotion-recognition-2026 `[二次解説]` | 商業ブログ。公式裏付けなし |
| **2026 年 3 月**に EU AI Office が計 **8,500 万ユーロ**（4,500 万 + 2,800 万 + 1,200 万）の制裁金 | https://informedclearly.com/en/ai/52202/eu-ai-act-first-fines-enforcement-2026 `[二次解説]` | 商業ブログ。公式裏付けなし。上記と日付・総額・内訳のすべてが矛盾 |
| 2026 年初頭に欧州委員会が禁止行為に関する最初の正式調査を開始 | 同上系統 `[二次解説]` | 公式裏付けなし |

**結論**: **2026-09-13 時点で、AI Act に基づく執行措置・制裁金が実際に科されたことを、公式出典で確認できなかった。** 上記の二次情報は相互に矛盾しており、いずれも商業ブログである。欧州委員会の公式執行ページ（2026-08-24 更新）にも記載がない。「執行実績はまだない」と断定はできないが、「公式に確認できる執行実績はない」とは言える。

**構造的な注意点**: Art 99 の制裁金を科すのは**加盟国の市場監視当局**であり、欧州委員会ではない（例外は Art 101 の GPAI と Art 100 の EU 機関）。加盟国当局の処分は必ずしも欧州委員会のページには載らない。したがって「委員会ページに記載がない」ことは「加盟国レベルで何も起きていない」ことを意味しない。Art 99(11) により加盟国は毎年委員会に報告するが、その報告の公開は確認できず。

---

## 5. スイスの立場（重点）

### 5.1 スイスは AI Act に直接は拘束されない

**事実関係**:
- スイスは EU 加盟国ではなく、EEA（欧州経済領域）にも加盟していない。1992 年 12 月 6 日の国民投票で EEA 加盟が否決された。
- AI Act は "Text with EEA relevance"（EEA 関連性のあるテキスト）と付記されているが、スイスは EEA の当事国ではないため、この付記によってスイスに適用されることはない。
- AI Act は EU・スイス二国間協定（Bilaterals）の附属書に取り込まれていない。**確認できず**: 2026-09-13 時点で AI Act を EU・スイス間協定に取り込む交渉が行われている形跡は確認できなかった。

**したがって、スイスに拠点を置く側に AI Act が及ぶ経路は 2 つに限られる**:

1. **Art 2(1) の域外適用（法的経路）** — 特に (c)。詳細は §1。
   - (a) 経路: EU 域内で AI システムを「上市（placing on the market）」または「供用（putting into service）」した場合。EU の研究者に向けてサービスを提供する行為がこれに当たるかは、そのサービスが「AI システムの供給」なのか「AI を用いた役務の提供」なのかによる。Art 3(9) は "placing on the market" を "the first making available of an AI system ... on the Union market" と定義しており、**システムそのものを供給する**ことを指す。SaaS 型でシステム自体は提供者の手元にある構成は (a) ではなく (c) の射程に入りやすい。
   - (c) 経路: **EU 域内の研究者が解析結果（出力）を EU 域内で使う限り、文言上は該当しうる。**

2. **契約による経路（事実上の経路）** — EU の顧客・共同研究先が、自らの AI Act 上の義務（特に Art 26 の利用者義務）を果たすために、スイス側の提供者に契約で AI Act 準拠を要求する。これは法の域外適用ではなく、供給網を通じた事実上の波及である。法的には AI Act 違反ではなく契約違反の問題になる。

### 5.2 連邦参事会の 2025 年 2 月 12 日決定

**公式出典 1 — 連邦参事会プレスリリース**
- タイトル: "KI-Regulierung: Bundesrat will Konvention des Europarats ratifizieren"
- 日付: 2025-02-12（ベルン）
- URL: https://www.admin.ch/de/nsb?id=104110
- `[公式]`
- 逐語（冒頭）:
  > "Die Schweiz soll die Konvention des Europarats zu Künstlicher Intelligenz (KI) ratifizieren und die dafür notwendigen Anpassungen im Schweizer Recht vornehmen. Zudem sind die Aktivitäten zur Regulierung von KI in einzelnen Bereichen wie zum Beispiel dem Gesundheitswesen oder dem Verkehr weiterzuführen."

  日本語: スイスは欧州評議会の人工知能（KI）に関する条約を批准し、そのために必要なスイス法の適応を行うべきである。加えて、医療や交通といった個別分野における KI 規制の活動を継続すべきである。

- **注記**: このページの本文全体はこのネットワークからは取得できなかった（admin.ch が curl / WebFetch をブロック）。上記はリード文のみ。Eckwerte（骨子）の箇条書きは下記の連邦司法局ページと二次解説から補った。

**公式出典 2 — 連邦司法局（BJ）のプロジェクトページ（本文取得済み、最も信頼できる公式記述）**
- タイトル: "Künstliche Intelligenz"
- 公開日表示: "Veröffentlicht am 12. Februar 2025"
- URL: https://www.bj.admin.ch/de/kuenstliche-intelligenz
- `[公式]`
- 逐語（核心部分）:
  > "Auf der Grundlage der Auslegeordnung hat der Bundesrat am 12. Februar 2025 dem EJPD den Auftrag erteilt, bis Ende 2026 eine Vernehmlassungsvorlage für neue Regeln für die Nutzung von KI zu erarbeiten. Das Gesetzesprojekt soll namentlich die Bereiche Transparenz, Datenschutz, Nichtdiskriminierung und Aufsicht umfassen. Das Eidgenössische Departement für Umwelt, Verkehr, Energie und Kommunikation (UVEK) wird seinerseits ebenfalls bis Ende 2026 weitere nicht-gesetzgeberische Massnahmen vorschlagen. Mit den vorgeschlagenen Entwicklungen wird die Schweiz die KI-Konvention des Europarats ratifizieren können."

  日本語: 現状整理（Auslegeordnung）に基づき、連邦参事会は 2025 年 2 月 12 日、**連邦司法警察省（EJPD）に対し、2026 年末までに AI 利用の新規則に関する意見聴取草案（Vernehmlassungsvorlage）を作成するよう委託した**。この立法計画は、とりわけ**透明性・データ保護・非差別・監督**の各分野を対象とする。環境・運輸・エネルギー・通信省（UVEK）も同じく 2026 年末までに、立法によらないその他の措置を提案する。提案されている諸展開により、スイスは欧州評議会の KI 条約を批准できるようになる。

- 逐語（現状把握の前提）:
  > "In der Schweiz gibt es aktuell keine spezifische Gesetzgebung zur KI."

  日本語: **スイスには現在、KI に関する固有の法律は存在しない。**

**規制アプローチの骨子（Eckwerte）** `[二次解説]`（admin.ch 本文を取得できなかったため二次出典）
- 出典: https://law.ch/lawnews/2025/02/ki-regulierung-bundesrat-will-konvention-des-europarats-ratifizieren/ 、https://hub.hslu.ch/management-and-law/2025/02/13/ki-regulierung-schweiz-positioniert-sich-oder-doch-nicht/
- (1) 欧州評議会 KI 条約をスイス法に取り込む。同条約の適用対象は**第一義的に国家主体**である。
- (2) 法改正が必要な場合は**可能なかぎり分野別（sektorbezogen）**とする。一般的・分野横断的な規制は、データ保護のような**基本権に関わる中心的領域に限定**する。
- (3) 立法以外に、自己申告協定や業界解決策といった**法的拘束力のない措置**も策定する。
- 目的: スイスのイノベーション拠点としての強化、経済的自由を含む基本権保護の維持、国民の KI への信頼の強化。

**要するに**: スイスは EU AI Act を「そのまま（tel quel）」取り込まない方針を採り、欧州評議会条約の批准 + 分野別対応という道を選んだ。

### 5.3 2025 年 2 月以降に何が起きたか（2026-09-13 時点の状況）

**確認できた事実（公式）**:

| 日付 | 事項 | 出典 |
|---|---|---|
| 2025-02-12 | 連邦参事会決定。EJPD に 2026 年末までの意見聴取草案作成を委託 | https://www.bj.admin.ch/de/kuenstliche-intelligenz `[公式]` |
| 2025-03-26 | 連邦参事会プレスリリース「Schweiz unterzeichnet Europaratskonvention zu KI」。逐語: "Bundesrat Albert Rösti wird am 27. März 2025 in Strassburg die Konvention des Europarats über Künstliche Intelligenz (KI) und Menschenrechte, Demokratie und Rechtstaatlichkeit im Namen der Schweiz unterzeichnen." | https://www.admin.ch/de/nsb?id=104646 `[公式]` |
| **2025-03-27** | **スイスが CETS 225 に署名**（ストラスブール、Rösti 連邦参事）。署名であって批准ではない | 同上 `[公式]` + `[二次解説]` |
| 2025-10-27 | 連邦司法局が参加型作業会議を開催。約 60 名の利害関係者代表が参加。結果は総括報告にまとめられた | https://www.bj.admin.ch/de/kuenstliche-intelligenz `[公式]` |
| 2025-12-17 | 文書「Begleitgruppe『Regulierung von künstlicher Intelligenz』」（PDF、117.82 kB）公開。意見聴取草案作成のための専門家伴走グループ | 同上 `[公式]` |

**BJ ページの「Was ist bisher geschehen?」欄には、2025-12-17 より後の項目は記載されていない**（2026-09-13 時点で確認）。

**現状（2026-09-13）**:
- **意見聴取（Vernehmlassung）は開始されていない。** 期限は 2026 年末であり、まだ 3 か月半残っている。
- アクションプラン「Digitale Schweiz」上、欧州評議会条約の実施のための予備草案（Vorentwurf）は **2026 年 12 月**に予定されている。
  - URL: https://digital.swiss/de/aktionsplan/massnahme/vorlage-zur-umsetzung-des-rahmenubereinkommens-des-europarats-uber-kunstliche-intelligenz-und-menschenrechte,-demokratie-und-rechtsstaatlichkeit `[公式]`
- 意見聴取草案の後にも、意見聴取手続そのもの、連邦参事会によるメッセージ採択、両院での審議、（任意的レファレンダムの対象となるため）レファレンダム期間、が続く。**スイスに AI 固有法が施行されるのは早くても 2028〜2029 年以降**と見るのが自然だが、これは推測であり公式の予定表ではない。
- 二次情報（規制トラッカー）の記述: 「2026 年 9 月 8 日時点で、2026 年末期限の意見聴取草案はまだ開始されていない」
  - URL: https://regulatorik.ai/en/framework/coe-ai `[二次解説]`

**確認できず**: 2026 年に入ってからの連邦参事会の追加決定、進捗報告、期限変更の有無は、公式出典では確認できなかった。BJ ページの更新が 2025-12-17 で止まっているため、2026 年前半〜中盤の動きが不明である。

### 5.4 欧州評議会 AI 枠組条約（CETS 225）

**条約の基本情報**
- 正式名称: Council of Europe Framework Convention on Artificial Intelligence and Human Rights, Democracy and the Rule of Law
- 条約番号: **CETS No. 225**
- 閣僚委員会による採択: 2024-05-17
- 署名開放: **2024-09-05**（リトアニア・ヴィリニュス、欧州評議会法務大臣会議）
- 位置づけ: **AI に関する初の法的拘束力を持つ国際条約**
- `[公式]` / `[二次解説]`
- 注: coe.int および rm.coe.int は、この調査を行ったネットワークからは Cloudflare により完全にブロックされていた（HTTP 403）。条約本文と署名・批准一覧を一次出典で直接確認することができなかった。

**EU 側の手続（EUR-Lex で確認済み）** `[条文]` / `[公式]`
- Council Decision (EU) 2022/2349 of 21 November 2022: 交渉開始の授権
- **Council Decision (EU) 2024/2218 of 28 August 2024**（署名の授権）
  - URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202402218
  - 題名（逐語）: "on the signing, on behalf of the European Union, of the Council of Europe Framework Convention on Artificial Intelligence and Human Rights, Democracy and the Rule of Law"
  - `[条文]`
- EU は 2024-09-05 に署名
- COM(2025) 265 final: 締結（conclusion）に関する理事会決定案。URL: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:52025PC0265 `[公式]`
- 欧州議会の同意: **2026-03-11**（勧告 A10-0007/2026、IMCO・LIBE 両委員会。採決 455 対 101） `[二次解説]`
- **EU による批准書寄託: 2026-05-15**（欧州評議会閣僚委員会第 135 会期、キシナウ） `[二次解説]`

**発効要件（Art 30）**
- 二次出典による記述（複数の出典で一致、逐語は英語二次出典より）:
  > "The treaty enters into force on the first day of the month following the expiration of a period of three months after the date on which five signatories, including at least three Council of Europe member states, have ratified it."

  日本語: 本条約は、**5 の署名国（うち少なくとも 3 は欧州評議会加盟国）が批准した日から 3 か月の期間が満了した後の、翌月の初日に発効する。**
- Art 30(4): 発効後に同意を表明した当事国については、寄託から 3 か月後の翌月初日に効力が生じる。
- `[二次解説]` — **条約本文（Art 30）の逐語引用を一次出典で確認できなかった。**上記の文言は複数の二次出典に共通する表現であり、実質的には信頼できるが、原文の完全一致は保証しない。

**発効しているか — 食い違い**

| 立場 | 主張 | 出典 | 評価 |
|---|---|---|---|
| **発効していない** | 2026-09-07 時点で、寄託された同意表明は **EU の 1 件のみ**（2026-05-15、宣言付き）。21 の国・機関が署名しているが、署名は批准ではない。したがって**当事国（Parties）はゼロ** | https://regulatorik.ai/en/framework/coe-ai `[二次解説]` | 後述の eucrim 記事と整合する |
| **発効していない** | 2025-09-30 時点で「Over the past year, the Convention was signed by 16 countries (among them 5 non-CoE member states) and the European Union」。批准については一切報告せず、「In order to enter into force, the Convention must be ratified by 5 states, including at least 3 CoE member states」と発効要件のみを記載 | https://eucrim.eu/news/anniversary-of-coes-ai-convention/ （2025-09-30）`[二次解説（Max Planck 系の学術系媒体）]` | **批准ゼロを 2025 年 9 月末時点で示唆** |
| **発効している** | 英国・フランス・ノルウェーらの批准により **2025-11-01 に発効**した | https://srjconsultingservices.com/ai-governance/coe-framework-convention/ 等 `[二次解説]` | 裏付けなし |

**この食い違いに対する本 dossier の判断**:
2025-11-01 に発効するには、Art 30 の 3 か月ルールにより **2025-07-31 までに 5 件目の批准が寄託されている**必要がある。しかし eucrim（2025-09-30）はその 2 か月後の時点で批准件数をまったく報告せず、発効要件のみを将来形で記述している。また英国の批准を確認しようとした検索では、英国政府関係の記述は一貫して批准を**将来の事象**として扱っており（"Once the treaty is ratified and brought into effect in the UK..."、"as the convention is ratified"）、批准書寄託の事実は確認できなかった。
→ **「2025-11-01 発効」説を支える証拠は見つからなかった。2026-09-13 時点で CETS 225 は未発効である可能性が高い。** ただし**確認できず**: 欧州評議会条約局の公式署名・批准一覧（CETS 225）に、このネットワークからアクセスできなかったため、断定はできない。この点は書き手が別経路で必ず確認すべき項目である。

**AI Act との違い（構造的な差異）**

| | EU AI Act (Reg. 2024/1689) | CETS 225 |
|---|---|---|
| 拘束する相手 | **事業者**（提供者・利用者・輸入者・頒布者等）に直接 | **国家**（締約国）。締約国が国内法で実施する義務を負う |
| 法形式 | EU 規則。加盟国で直接適用可能 | 枠組条約。締約国に立法・行政措置を義務づける |
| 私人への効果 | 直接適用。企業が制裁金の名宛人になる | **企業に直接の義務を課さない**。国内実施法を通じてのみ企業に及ぶ |
| 制裁 | Art 99 / Art 101 の行政制裁金（最大 7% / 3,500 万ユーロ） | **制裁規定なし**。遵守は報告・監視メカニズムによる |
| 民間部門 | 全面適用 | 締約国は民間部門への適用方法を選択できる（条約は柔軟性を認める） |
| スイスへの効果 | 直接には適用されない（Art 2(1) 経由のみ） | 批准すればスイスを国際法上拘束する。ただし企業への効果は国内実施法次第 |

**スイスにとっての含意**: スイスが CETS 225 を批准しても、それ自体がチューリヒの研究者に直接の義務を課すわけではない。義務は 2026 年末の意見聴取草案を起点とする**国内実施法**が成立して初めて生じる。連邦参事会の方針（§5.2）によれば、その実施法は主として**国家主体**を対象とし、民間への一般的・分野横断的規制は基本権に関わる中心領域（データ保護など）に限定される。

### 5.5 スイスのデータ保護法（revDSG / nDSG）は何を追加するか

**法令**
- Bundesgesetz über den Datenschutz (Datenschutzgesetz, DSG) vom 25. September 2020
- SR 235.1、**2023 年 9 月 1 日施行**（全面改正版。revDSG / nDSG と通称）
- URL（全文 HTML）: https://www.fedlex.admin.ch/filestore/fedlex.data.admin.ch/eli/cc/2022/491/20230901/de/html/fedlex-data-admin-ch-eli-cc-2022-491-20230901-de-html.html
- ELI: https://www.fedlex.admin.ch/eli/cc/2022/491/de
- `[条文]`

**AI に関係する主要規定**

**Art 3 — 場所的適用範囲（逐語）**
> "Art. 3 Räumlicher Geltungsbereich
> 1 Dieses Gesetz gilt für Sachverhalte, die sich in der Schweiz auswirken, auch wenn sie im Ausland veranlasst werden."

日本語: 本法は、**スイス国内に効果を及ぼす事象に適用される。当該事象が国外で引き起こされた場合であっても同様である。**
→ AI Act Art 2(1)(c) と対称的な「効果主義」。スイス法もまた域外適用の構造を持つ。

**Art 21 — 自動化された個別決定に際しての情報提供義務（逐語）**
> "Art. 21 Informationspflicht bei einer automatisierten Einzelentscheidung
> 1 Der Verantwortliche informiert die betroffene Person über eine Entscheidung, die ausschliesslich auf einer automatisierten Bearbeitung beruht und die für sie mit einer Rechtsfolge verbunden ist oder sie erheblich beeinträchtigt (automatisierte Einzelentscheidung).
> 2 Er gibt der betroffenen Person auf Antrag die Möglichkeit, ihren Standpunkt darzulegen. Die betroffene Person kann verlangen, dass die automatisierte Einzelentscheidung von einer natürlichen Person überprüft wird.
> 3 Die Absätze 1 und 2 gelten nicht, wenn:
> a. die automatisierte Einzelentscheidung in unmittelbarem Zusammenhang mit dem Abschluss oder der Abwicklung eines Vertrags zwischen dem Verantwortlichen und der betroffenen Person steht und ihrem Begehren stattgegeben wird; oder
> b. die betroffene Person ausdrücklich eingewilligt hat, dass die Entscheidung automatisiert erfolgt."

日本語: 管理者は、**もっぱら自動化された処理に基づき**、かつ当該個人に法的効果をもたらすか重大な影響を与える決定（自動化された個別決定）について、当該個人に**情報を提供する**。申請があれば当該個人に見解を述べる機会を与える。当該個人は、**自然人による再審査**を要求できる。例外は、(a) 当該決定が管理者と当該個人の間の契約の締結・履行と直接関連し、かつその者の要求が容認された場合、(b) 当該個人が自動決定に明示的に同意した場合。

**Art 22 — データ保護影響評価（DSFA）**: 処理が個人の人格または基本権に高いリスクをもたらしうる場合、管理者は事前に影響評価を作成しなければならない。

**AI Act との比較 — revDSG が追加するもの**
- revDSG は **AI 固有の法ではない**。AI Act のようなリスク階層、適合性評価、CE マーキング、技術文書、通知機関の仕組みは一切存在しない。
- 追加されるのは、**個人データを処理する AI についてのデータ保護法上の規律**のみ: 透明性（Art 19 以下の情報提供義務）、自動化個別決定の告知と人による再審査（Art 21）、高リスク処理の影響評価（Art 22）、国外移転の規律（十分性認定または標準契約条項等）。
- ゲノムデータは revDSG Art 5(c) の「besonders schützenswerte Personendaten（特に保護に値する個人データ）」に**遺伝データ（genetische Daten）**および生体データとして含まれる。したがって処理には追加の要件（明示的同意等）がかかる。**確認できず**: Art 5(c) の逐語引用は本調査では取得していない（取得したのは Art 3、21、22 のみ）。書き手は必要なら fedlex で確認のこと。
- 罰則構造が根本的に異なる: revDSG の制裁は**刑事罰**であり、Art 60 以下で**責任ある自然人**に対し最高 **25 万スイスフラン**の過料（Busse）。AI Act のような企業に対する行政制裁金（売上高比）ではない。

**結論**: revDSG は AI Act の代替にならない。両者は重なるが、規律の対象・手法・制裁が異なる。EU の研究者を相手にするチューリヒのサービスは、GDPR（EU の被験者データを扱う場合）と revDSG（スイスで効果が生じる場合）の**両方**を同時に考える必要があり、そこに AI Act Art 2(1)(c) が重なりうる。

---

## 6. 他の法令との重なり（一覧）

| 法令 | 正式名称・番号 | 状態（2026-09-13） | AI Act との関係 | 出典 | 種別 |
|---|---|---|---|---|---|
| **GDPR** | Regulation (EU) 2016/679（一般データ保護規則） | 2018-05-25 から適用中 | AI Act Art 2(7)（2026/1744 で改正）: "Union law on the protection of personal data, privacy and the confidentiality of communications applies to personal data processed in connection with the rights and obligations laid down in this Regulation. Without prejudice to Articles 4a and 59 of this Regulation, this Regulation shall not affect Regulation (EU) 2016/679..." → **AI Act は GDPR に影響しない。両者は並行して適用される。**ただし新設 Art 4a により、バイアス検出・是正のための特別カテゴリデータ処理に限り、条件付きで例外が設けられた | https://eur-lex.europa.eu/eli/reg/2016/679/oj | `[条文]` |
| **AI 責任指令（AILD）** | Proposal COM(2022) 496 — Directive on adapting non-contractual civil liability rules to artificial intelligence | **撤回済み。** 2025-02-11 採択の 2025 年委員会作業計画で撤回予定が示され（理由: "No foreseeable agreement - the Commission will assess whether another proposal should be tabled or another type of approach should be chosen"）、**2025-10-06 に官報で撤回通知が公示**（委員会第 2533 回会合 2025-07-16 の決定に基づく） | 撤回により、AI に起因する損害の民事責任は各加盟国の国内法に委ねられ、加盟国間で結論が分かれる余地が残った | https://www.twobirds.com/en/insights/2025/proposed-eu-ai-liability-rules-withdrawn 、https://iapp.org/news/a/european-commission-withdraws-ai-liability-directive-from-consideration | `[二次解説]` |
| **改正製造物責任指令（PLD）** | Directive (EU) 2024/2853 of 23 October 2023 on liability for defective products and repealing Council Directive 85/374/EEC、OJ L, 2024/2853, 18.11.2024 | 加盟国の国内法化期限 **2026-12-09**。逐語: "by 9 December 2026. They shall immediately inform the Commission thereof." | **ソフトウェアが明示的に「製品」に含まれた。** Art 4(1) 逐語: "'product' means all movables, even if integrated into, or inter-connected with, another movable or an immovable; it includes electricity, digital manufacturing files, raw materials **and software**". また Art 4(4): "'component' means any item, whether tangible or intangible, raw material or related service, that is integrated into, or inter-connected with, a product." → AI システムは無過失責任の対象となりうる。AILD 撤回後、**AI 被害の民事責任の主要経路はこの改正 PLD である** | https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202402853 | `[条文]` |
| **データ法（Data Act）** | Regulation (EU) 2023/2854 of 13 December 2023 on harmonised rules on fair access to and use of data、OJ L, 2023/2854, 22.12.2023 | **2025-09-12 から適用中**（逐語: "It shall apply from 12 September 2025."）。Art 3(1) の義務は 2026-09-12 より後に上市される接続製品に適用 | 接続製品・関連サービスが生成するデータへのアクセス権、クラウド切替（Chapter VI）、公的機関のデータ要求（Chapter V）を規律。AI の**学習データの入手経路**と、プラットフォーム間の移行可能性に影響する | https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32023R2854 | `[条文]` |
| **欧州健康データスペース（EHDS）** | Regulation (EU) 2025/327 establishing a European Health Data Space | 2025-03-05 官報公示、**2025-03-26 発効**。原則の適用開始は **2027-03-26**。**二次利用（Chapter III）は 2029-03-26 から**。医用画像・検査結果・退院サマリー等の一部カテゴリは 2031-03-26 から | ゲノム・健康データの**二次利用**（研究・政策立案・規制判断）の枠組みを定める。**ゲノミクス基盤にとっては AI Act より射程が近い可能性がある。**健康データ利用者は健康データアクセス機関に申請し、匿名化・仮名化された形でデータを得る | https://eur-lex.europa.eu/eli/reg/2025/327/oj （**注**: 本調査では EUR-Lex で直接検証しておらず、日付は二次解説による。書き手は要確認） | `[二次解説]` |

---

## 7. チューリヒの読み手にとっての要点（条文に紐づけた整理）

1. **AI Act はスイスに直接適用されない。** スイスは EU でも EEA でもなく、AI Act は二国間協定に取り込まれていない。
2. **しかし Art 2(1)(c) が届きうる。** 「第三国に所在する提供者・利用者であって、当該 AI システムが生み出した出力が EU 域内で使用されるもの」。EU の研究者がチューリヒのサービスを使い、その解析結果を EU 域内で使えば、文言上この要件は満たされうる。Recital 22 は "intended to be used"（使用されることが意図されている）と書いており条文と乖離があるが、**拘束力があるのは条文（"is used"）の方**である。
3. **適用範囲に入ることと、義務を負うことは別。** Art 2(1)(c) が発動しても、そのシステムが禁止行為（Art 5）・高リスク（Annex I/III）・Art 50 の透明性義務対象・GPAI モデル、のいずれにも当たらなければ、実体的義務はほぼ生じない。
4. **科学研究の適用除外（Art 2(6)）は狭い。** "sole purpose of scientific research and development"（唯一の目的が科学的研究開発）。第三者にサービスとして提供し始めた時点でこの除外を維持できるかは条文から判断できない。
5. **代理人選任義務（Art 22）は高リスクの場合のみ。** GPAI モデルの提供者なら Art 54。いずれも高リスク/GPAI でなければ発動しない。
6. **SME 特則は有利に働く。** Art 99(6) により、SME（新興企業を含む）には「低い方」の上限が適用される。売上高が小さければ実際上は「%」側が上限になる。大学発の小規模プラットフォームは通常 SME に該当する（勧告 2003/361/EC の基準）。
7. **高リスク規定の適用は 2027-12-02 / 2028-08-02 に後ろ倒しされた**（Regulation (EU) 2026/1744）。ただし禁止行為・透明性義務・GPAI 義務は後ろ倒しされていない。Art 50 の透明性義務は **2026-08-02 から既に執行可能**である。
8. **公式に確認できる執行実績はまだない**（2026-09-13 時点）。加盟国の当局指定自体が大幅に遅れている（2026 年 3 月時点で 27 か国中 8 か国）。
9. **スイス国内法はまだ存在しない。** 意見聴取草案は 2026 年末が期限で、まだ開始されていない。当面、スイス側の法的な足場は revDSG（+ GDPR、EU の被験者データを扱う場合）である。
10. **現実的には、法よりも契約が先に効く。** EU の共同研究先・顧客が自らの Art 26（利用者義務）を満たすために契約で準拠を求めてくる経路の方が、当局の執行より早く到来する可能性が高い。

---

## 8. 確認できなかったこと

1. **欧州評議会条約局の CETS 225 公式署名・批准一覧。** coe.int および rm.coe.int はこの調査を行ったネットワークから Cloudflare により完全にブロックされていた（HTTP 403、curl・WebFetch とも）。したがって以下が一次出典で確認できていない:
   - CETS 225 が発効しているかどうか（二次出典が真っ向から対立している。§5.4 の判断は状況証拠に基づく推論であり、確定ではない）
   - 署名国の正確な数（二次出典は 16／21／37 と食い違う。母数の取り方が違う可能性がある）
   - 批准（同意表明）を寄託した国・機関の正確な一覧と件数
   - **条約 Art 30 の逐語原文**（発効規定の文言は二次出典に共通する表現から再構成しており、原文との完全一致は保証しない）
   - スイスの CETS 225 上のステータス（署名は 2025-03-27 で確認できたが、条約局台帳上の記載内容は未確認）
   → **書き手は必ず https://www.coe.int/en/web/conventions/full-list?module=signatures-by-treaty&treatynum=225 を別経路で確認すること。**

2. **admin.ch のプレスリリース本文。** https://www.admin.ch/de/nsb?id=104110（2025-02-12）および id=104646（2025-03-26）は、curl では Akamai に、WebFetch では部分取得のみで、本文全体を取得できなかった。Eckwerte（規制アプローチの骨子 3 点）は二次解説から補っている。逐語引用として使うなら要再取得。

3. **2026 年に入ってからのスイスの動き。** 連邦司法局のプロジェクトページ（bj.admin.ch/de/kuenstliche-intelligenz）の「Was ist bisher geschehen?」欄は 2025-12-17 で止まっている。2026 年前半〜中盤に連邦参事会の追加決定・進捗報告・期限変更があったかどうかは確認できなかった。

4. **AI Act に基づく実際の執行措置。** 欧州委員会の公式執行ページ（2026-08-24 更新）にも、EPRS の 2026-03-18 の分析にも、実際に採られた執行措置・調査・制裁金の記載がない。一方、複数の商業ブログが 2026 年 3 月あるいは 2026 年 8 月に多額の制裁金が科されたと主張しているが、日付・総額・内訳のすべてが相互に矛盾し、公式裏付けもない。**「執行実績がない」と断定はできず、「公式に確認できる執行実績はない」としか言えない。** なお Art 99 の制裁金を科すのは加盟国当局であり、その処分は欧州委員会のページには載らない構造である点に注意。

5. **2026-09-13 時点の加盟国当局指定状況の正確な数字。** 確認できたのは 2026-03（EPRS、8/27）と 2026-06-17（二次解説、9/27 が両当局とも指定済み）。欧州委員会が Art 70(2) に基づき公開すべき single points of contact の一覧そのものは確認できなかった。

6. **Art 2(1)(c) の "used" の解釈に関する公式ガイダンス。** 欧州委員会の Art 96 ガイドラインのうち、Art 2(1)(c) の域外適用の発動条件を正面から扱ったものの存在を確認できなかった。CJEU 判例も確認できなかった。この論点は現時点で未決着である。

7. **Art 22 と Art 2(1)(c) の関係。** Art 22(1) は「高リスク AI システムを EU 市場で利用可能にする前に」代理人を選任せよと定めるが、Art 2(1)(c) の「出力だけが EU で使われる」構成でも Art 22 が発動するのかは条文上明確でなく、公式解釈も見つけられなかった。

8. **revDSG Art 5(c) の逐語**（遺伝データが「特に保護に値する個人データ」に含まれることの条文上の根拠）。本調査では revDSG の Art 3、21、22 のみ取得した。

9. **EHDS Regulation (EU) 2025/327 の日付の一次検証。** 発効日・適用開始日・二次利用章の適用開始日は二次解説にのみ依拠しており、EUR-Lex で直接確認していない。

10. **AI Liability Directive 撤回の官報通知そのもの。** 撤回の事実と 2025-10-06 という日付は複数の法律事務所・IAPP の記述で一致しているが、官報の撤回通知（OJ C シリーズ）を直接確認していない。

11. **Regulation (EU) 2026/1744 の前文（Recitals）の精査。** 本文（Article 1 の改正項目 1〜43）は全件確認したが、前文 47 項のうち内容を読んだのは (1)〜(5) と (47) のみである。改正の趣旨に関する記述で見落としがある可能性がある。
