# R2 — 禁止行為と高リスク分類（医療・健康分野重点）source dossier

- 調査日: 2026-09-13
- 担当: R2 seat
- 出典種別タグ: `[条文]` = 官報・法文そのもの / `[公式ガイダンス]` = 欧州委員会・MDCG・AI Board の文書 / `[二次解説]` = 法律事務所等の解説

---

## 0. 前提 — 2026 年の改正を踏まえないと全部ずれる

AI Act (Regulation (EU) 2024/1689) は 2026 年に大幅に改正された。**2024 年版の条文だけを見ると、条番号も適用日も誤る。**

### 0.1 改正法令の同定 `[条文]`

- **Regulation (EU) 2026/1744** of the European Parliament and of the Council of **8 July 2026** amending Regulations (EU) 2024/1689, (EU) 2018/1139 and (EU) 2023/1230 as regards the simplification of the implementation of harmonised rules on artificial intelligence (**Digital Omnibus on AI**)
- 出典 URL: https://eur-lex.europa.eu/eli/reg/2026/1744/oj/eng
- 構成: Article 1 が AI Act を **43 点** 改正、Article 2 が 2018/1139（航空）、Article 3 が 2023/1230（機械）、Article 4 が発効規定。
- 発効日: EUR-Lex の consolidated 版の ELI が `https://eur-lex.europa.eu/eli/reg/2024/1689/2026-07-27` であることから、改正の効力発生日は **2026-07-27** `[条文]`。
- 官報掲載日を 2026-07-24 とする記述 `[二次解説]`（複数の法律事務所ブログ）。官報ヘッダからは直接確認していない。

### 0.2 適用日（改正後 Article 113 第 3 段）`[条文]`

改正後の Article 113 の文言（Regulation (EU) 2026/1744 Article 1 点(40) による置換）:

> ‘Chapters I and II shall apply from 2 February 2025, with the exception of Article 5(1), first subparagraph, points (ba) and (bb), and Article 5(1a) and (1b) which shall apply from **2 December 2026**;’

> ‘Chapter III, Sections 1, 2, and 3, with the exception of Article 6(5), shall apply from:
> (i) **2 December 2027** as regards AI systems classified as high-risk pursuant to Article 6(2) and Annex III; and
> (ii) **2 August 2028** as regards AI systems classified as high-risk pursuant to Article 6(1) and Annex I;’

> ‘Articles 102 to 110 shall apply from 27 July 2026.’

和訳の要点: 禁止行為のうち従来の (a)〜(h) は 2025-02-02 から既に適用されている。新設の (ba)(bb) だけが 2026-12-02 から。高リスクの義務（Chapter III 第 1〜3 節）は、Annex III 経路が **2027-12-02**、Annex I 経路が **2028-08-02** に後ろ倒しされた（改正前はそれぞれ 2026-08-02 / 2027-08-02）。**Article 6(5)（委員会ガイドライン作成義務）はこの延期の対象外**である点に注意。

延期理由の記述（改正法 recital）`[条文]`:

> "the delayed availability of standards, common specifications, and alternative guidance and the delayed establishment of national competent authorities lead to challenges that jeopardise the effective entry into application of those obligations"

和訳の要点: 規格・共通仕様・ガイダンスの整備と各国所管当局の設置が遅れ、当初の適用日を維持する正当性が失われた、という理由付け。

### 0.3 本 dossier が改正の影響を確認した範囲 `[条文]`

Regulation (EU) 2026/1744 の全文を grep して確認した結果:

| 対象 | 改正の有無 |
|---|---|
| Article 2(6)（科学研究の除外） | **改正なし**。consolidated 版でも文言同一 |
| Article 2(8)（市場投入前の研究・試験・開発） | **改正なし** |
| Article 2(2), 2(7) | 置換あり。2(13) を新設 |
| Article 5(1)(a)〜(h) | **改正なし**。(ba)(bb) と 5(1a)(1b) を新設 |
| Article 6(1), 6(2), 6(3), 6(4), 6(5) | **改正なし**。6(1a)(1b)(1c) を新設 |
| Article 49（登録義務） | **改正なし**（omnibus 本文に "Article 49" の改正指示なし） |
| **Annex III** | **改正なし**（omnibus に "Annex III is amended"（AI Act の Annex III について）の指示なし。consolidated 版の Annex III に改正マーカー ▼M1 が 0 件） |
| Annex I | 改正あり。§2.2 参照 |

---

## 1. Article 5 — 禁止される AI の実践

条文出典 URL: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32024R1689 （原典）／ https://eur-lex.europa.eu/eli/reg/2024/1689/2026-07-27 （consolidated）

柱書 `[条文]`: "1. The following AI practices shall be prohibited:"

### 1.1 全項目一覧（各 1 行 + 英語原文の核）

| 号 | 日本語の要旨 | 英語原文の核 |
|---|---|---|
| **(a)** | 意識下に働きかける技法、または意図的に操作的・欺瞞的な技法を用い、人の行動を実質的に歪めて重大な危害を生じさせる（またはそのおそれのある）AI システム | "deploys subliminal techniques beyond a person's consciousness or purposefully manipulative or deceptive techniques ... materially distorting the behaviour" |
| **(b)** | 年齢・障害・特定の社会的経済的状況に由来する脆弱性を悪用し、行動を実質的に歪めて重大な危害を生じさせる（またはそのおそれのある）AI システム | "exploits any of the vulnerabilities of a natural person or a specific group of persons due to their age, disability or a specific social or economic situation" |
| **(ba)** *(新設・2026-12-02 適用)* | 本人の自由な同意なく、識別可能な自然人の陰部や性的行為の写実的な画像・動画・音声等を生成・改変する AI システム | "generates or manipulates realistic images, videos, audio or similar material of an identifiable natural person's intimate parts ... without that person's freely-given, specific, informed, unambiguous and explicit consent" |
| **(bb)** *(新設・2026-12-02 適用)* | Directive 2011/93/EU にいう児童性的虐待素材を生成・改変する AI システム（国内法上の "without right" 抗弁がある場合を除く） | "generates or manipulates material or performance within the meaning of Article 2, points (c) and (e), of Directive 2011/93/EU, except where a 'without right' defence applies under national law" |
| **(c)** | 社会的行動や推測された人格特性に基づき一定期間にわたり自然人を評価・分類し、その社会的スコアが文脈外での、または均衡を欠く不利益取扱いにつながるもの（ソーシャルスコアリング） | "evaluation or classification of natural persons ... based on their social behaviour or known, inferred or predicted personal or personality characteristics, with the social score leading to ..." |
| **(d)** | もっぱらプロファイリングまたは人格特性の評価のみに基づいて、自然人の犯罪実行リスクを評価・予測するもの（予測的警察活動） | "making risk assessments of natural persons in order to assess or predict the risk of a natural person committing a criminal offence, based solely on the profiling of a natural person or on assessing their personality traits and characteristics" |
| **(e)** | インターネットや CCTV 映像から顔画像を無差別に収集して顔認識データベースを作成・拡張するもの | "create or expand facial recognition databases through the untargeted scraping of facial images from the internet or CCTV footage" |
| **(f)** | **職場および教育機関の領域**で自然人の感情を推論する AI システム。医療上または安全上の理由による場合を除く | "to infer emotions of a natural person in the areas of workplace and education institutions, except where the use of the AI system is intended to be put in place or into the market for medical or safety reasons" |
| **(g)** | **生体データに基づき個々の自然人を分類し、人種・政治的意見・労働組合員資格・宗教的哲学的信条・性生活・性的指向を推知・推論する**生体分類システム（§1.2 に逐語引用） | 下記 §1.2 |
| **(h)** | 法執行目的での公共空間における「リアルタイム」遠隔生体識別。(i) 誘拐・人身取引・性的搾取の被害者や行方不明者の捜索、(ii) 生命・身体への具体的・重大・切迫した脅威やテロ攻撃の防止、(iii) Annex II 掲記の一定の重罪の被疑者の所在特定、に厳格に必要な場合を除く | "the use of 'real-time' remote biometric identification systems in publicly accessible spaces for the purposes of law enforcement, unless and in so far as such use is strictly necessary for one of the following objectives" |

補足 `[条文]`:

- (h) 第 1 段の後に: "Point (h) of the first subparagraph is without prejudice to Article 9 of Regulation (EU) 2016/679 for the processing of biometric data for purposes other than law enforcement."
- Article 5(8): "This Article shall not affect the prohibitions that apply where an AI practice infringes other Union law."
- Article 5(1a)(1b)（新設）: (ba)(bb) についてのみ、provider 側は「当該生成・改変が intended purpose である場合」または「設計・訓練・アーキテクチャ・能力・利用者向け機能から、大幅な技術的改変を要さずに当該生成・改変が合理的に予見可能かつ再現可能であり、かつ十分な技術的安全措置を欠く場合」に限り禁止対象となる。deployer 側は当該目的で使用した場合に限る。

### 1.2 Article 5(1)(g) の逐語引用と、健康・遺伝データの扱い

**逐語引用（原文）** `[条文]`:

> (g) the placing on the market, the putting into service for this specific purpose, or the use of biometric categorisation systems that categorise individually natural persons based on their biometric data to deduce or infer their race, political opinions, trade union membership, religious or philosophical beliefs, sex life or sexual orientation; this prohibition does not cover any labelling or filtering of lawfully acquired biometric datasets, such as images, based on biometric data or categorizing of biometric data in the area of law enforcement;

日本語の意味: 生体データに基づいて個々の自然人を分類し、人種・政治的意見・労働組合員資格・宗教的または哲学的信条・性生活・性的指向を推知または推論する生体分類システムの市場投入・当該目的での使用開始・使用を禁止する。ただしこの禁止は、適法に取得された生体データセット（画像等）に対する生体データに基づくラベル付けやフィルタリング、および法執行分野における生体データの分類には及ばない。

**健康・遺伝データについての確認結果:**

1. **推論先の属性リストに「健康」も「遺伝」も入っていない** `[条文]`。列挙は race / political opinions / trade union membership / religious or philosophical beliefs / sex life / sexual orientation の 6 つのみ。GDPR Article 9(1) の特別カテゴリ（人種的民族的出自、政治的意見、宗教的哲学的信条、労働組合員資格、**遺伝データ、生体データ、健康データ**、性生活・性的指向）と比べると、**遺伝データと健康データが意図的に落ちている**。
2. 欧州委員会の禁止行為ガイドライン（全 135 ページ）を全文検索したところ、**"genetic" という語は 1 箇所も出現しない** `[公式ガイダンス]`。
3. ただし、ガイドラインは **DNA が生体分類の「入力側」になりうる**と明言している `[公式ガイダンス]`:

> (278) Biometric categorisation may rely on categories of physical characteristics (e.g., facial features and form, skin colour) based on which persons are assigned to specific categories. Some of these categories may be of a special 'sensitive' nature' or characteristics protected under Union non-discrimination law, such as race. However, **biometric categorisation may also be based on DNA** or on behavioural aspects, such as keystroke analysis or a person's gait.

日本語の意味: 生体分類は顔の特徴や肌の色といった身体的特徴のカテゴリに依拠しうる。そのカテゴリの一部は「センシティブ」な性質のもの、または EU 差別禁止法上保護される特性（人種等）でありうる。ただし生体分類は **DNA** に基づくこともあり、また打鍵解析や歩容といった行動的側面に基づくこともある。

4. AI Act の 'biometric data' 定義 `[条文]` Article 3(34):

> 'biometric data' means personal data resulting from specific technical processing relating to the physical, physiological or behavioural characteristics of a natural person, such as facial images or dactyloscopic data;

日本語の意味: 「生体データ」とは、自然人の身体的・生理的または行動的特徴に関する特定の技術的処理から得られる個人データをいい、顔画像や指紋データがその例である。

**注記（解釈上の論点、本 dossier は結論を出さない）**: GDPR Article 4(14) の定義が「当該自然人の一意の識別を可能にし、または確認する」ことを要件とするのに対し、**AI Act の定義にはこの一意識別要件がない**。そのため DNA 配列データが AI Act 上の 'biometric data' に当たる余地は条文上排除されておらず、ガイドライン (278) もそれを前提にしている。したがって「ゲノムデータから人種や性的指向を推論する機能」は、推論先が (g) の列挙に含まれる限り禁止対象になりうる。逆に「ゲノムデータから疾患リスク（＝健康属性）を推論する」ことは (g) の列挙外である。この論点を正面から論じた公式文書は見つけられなかった（§確認できなかったこと参照）。

### 1.3 Article 5(1)(f) 感情認識の「医療上・安全上の理由」例外

委員会ガイドライン §7.2.3 `[公式ガイダンス]`:

> (256) The prohibition in Article 5(1)(f) AI Act contains an explicit exception for emotion recognition systems used in the area of the workplace and education institutions for medical or safety reasons, such as systems for therapeutical use. In light of the AI Act's objective to ensure a high-level of fundamental rights protection, **this exception should be narrowly interpreted**.

> (257) In particular, **therapeutic uses should be understood to mean uses of CE-marked medical devices**. Moreover, this exception does not comprise the use of emotion recognition systems to detect general aspects of wellbeing. The general monitoring of stress levels at the workplace is not permitted under health or safety aspects. For example, an AI system intended to detect burnout or depression at the workplace or in education institutions would not be covered by the exception and would remain prohibited.

> (258) The notion of safety reasons within this exception should be understood to apply only in relation to the protection of life and health and not to protect other interests, for example property against theft or fraud.

日本語の意味: 職場・教育機関での感情認識の「医療上・安全上の理由」例外は**狭く解釈**される。治療目的とは **CE マーキングされた医療機器の使用**を意味する。一般的なウェルビーイング検知や職場のストレスレベルの一般的監視は例外に含まれない。バーンアウトや抑うつを職場・教育機関で検知する AI システムは例外に当たらず、禁止されたままである。安全上の理由は生命と健康の保護に限られ、盗難や詐欺からの財産保護には及ばない。

### 1.4 欧州委員会「禁止行為ガイドライン」 `[公式ガイダンス]`

- 正式名称: **Commission Guidelines on prohibited artificial intelligence practices established by Regulation (EU) 2024/1689 (AI Act)** — COMMUNICATION FROM THE COMMISSION
- **文書番号: C(2025) 5052 final、Brussels, 29.7.2025**（PDF ヘッダから直接確認）
- 公式ページ URL: https://digital-strategy.ec.europa.eu/en/library/guidelines-prohibited-ai-practices
- 英語版 PDF URL: https://ec.europa.eu/newsroom/dae/redirection/document/112367
- 別ホスト（AI Act Service Desk）: https://ai-act-service-desk.ec.europa.eu/sites/default/files/2025-08/guidelines_on_prohibited_artificial_intelligence_practices_established_by_regulation_eu_20241689_ai_act_english_ied3r5nwo50xggpcfmwckm3nuc_112367-1.PDF
- 分量: 本文 24 言語版あり。英語版 PDF のテキスト抽出で 6,361 行。

**【食い違い】公表日について。** 委員会ページおよび多数の二次解説は公表日を **2025 年 2 月 4 日** とする `[公式ガイダンス]`/`[二次解説]`。一方、PDF 本体のヘッダは **Brussels, 29.7.2025 / C(2025) 5052 final** である `[公式ガイダンス]`。整合的な説明としては「2025-02-04 に委員会がドラフト Communication の**内容を承認**して公表し（ページ上の表題も "Approval of the content of the draft Communication..."）、2025-07-29 に Communication として**正式採択**された」というもの `[二次解説]`。両方を記録する。どちらの日付を引くかで意味が変わるので、書き手は用途に応じて選ぶこと。

法的性質 `[公式ガイダンス]`: 法的拘束力はない。AI Act Article 96 に基づき発出。最終的な法解釈権限は CJEU にある。

---

## 2. Article 6 — 高リスク分類の仕組み

### 2.1 Article 6(1) — Annex I 経路（逐語引用）`[条文]`

> 1. Irrespective of whether an AI system is placed on the market or put into service independently of the products referred to in points (a) and (b), that AI system shall be considered to be high-risk where **both** of the following conditions are fulfilled:
> (a) the AI system is intended to be used as a safety component of a product, or the AI system is itself a product, covered by the Union harmonisation legislation listed in Annex I;
> (b) the product whose safety component pursuant to point (a) is the AI system, or the AI system itself as a product, is required to undergo a **third-party conformity assessment**, with a view to the placing on the market or the putting into service of that product pursuant to the Union harmonisation legislation listed in Annex I.

日本語の意味: (a)(b) の**両方**を満たすとき高リスクとなる。(a) Annex I 掲記の EU 整合化法令の対象となる製品の安全構成要素として使われることが意図されているか、AI システム自体がそうした製品であること。(b) その製品（または製品としての AI システム自体）が、当該法令に基づく市場投入・使用開始にあたり**第三者適合性評価**を受けることを要求されていること。なお、当該製品とは独立に市場投入されるかどうかは問わない。

### 2.2 Annex I のうち医療・健康に関係する法令 `[条文]`

**Section A（New Legislative Framework ベース）**（2026 年改正後の consolidated 版で確認）:

| 番号 | 法令 |
|---|---|
| 1. | **削除**（改正前は Directive 2006/42/EC 機械指令。Regulation (EU) 2026/1744 により削除され、Regulation (EU) 2023/1230 として Section B 第 21 号へ移動） |
| 2.〜10. | 玩具、レジャー用船舶、リフト、爆発性雰囲気用機器、無線機器、圧力機器、索道、個人用保護具、ガス機器 |
| **11.** | **Regulation (EU) 2017/745**（医療機器規則 = **MDR**） |
| **12.** | **Regulation (EU) 2017/746**（体外診断用医療機器規則 = **IVDR**） |

重要: 削除された第 1 号の分は**繰り上げられていない**。consolidated 版で MDR は依然 **point 11**、IVDR は **point 12** である（EUR-Lex consolidated で直接確認）。

Section B（その他）: 民間航空保安、二輪・三輪車、農林用車両、船舶用機器、鉄道相互運用性、自動車、一般安全、民間航空、および新第 21 号 = Regulation (EU) 2023/1230（機械規則）。**Section B に該当する場合、Article 2(2) により AI Act のうち Article 6(1)、Article 60a、Articles 102〜112 のみが適用される**（改正後の文言）`[条文]`。MDR/IVDR は Section A なので、この限定の対象外＝ Chapter III の要件がフルに乗る。

委員会ドラフトガイドラインの補足 `[公式ガイダンス]`:

> (24) The list of Union harmonisation legislation in Annex I AI Act is **exhaustive**. New products may be added or removed from that list, but only through amendments to the scope of the Union harmonisation legislation itself ... or by adding new Union harmonisation legislation to Annex I AI Act.

> (26) The classification of an AI system as high-risk under Article 6(1) AI Act is therefore dependent upon and operates in conjunction with existing Union harmonisation legislation. The AI Act, through its Article 6(1), **does not in itself extend the scope of Union harmonisation legislation** to new or additional products that are not already subject to that legislation.

日本語の意味: Annex I のリストは**限定列挙**である。Article 6(1) は既存の整合化法令と連動して働くだけで、それ自体が整合化法令の適用範囲を新たな製品に拡張することはない。

### 2.3 Article 6 新設パラグラフ（2026 年改正）`[条文]`

> ‘1a. For the purposes of this Regulation, including paragraph 1 of this Article, AI systems that are **solely used for non-safety related aspects of user assistance, performance optimisation, service efficiency, automation or convenience or quality control shall not qualify as safety components**.
> 1b. Notwithstanding paragraph 1a, AI systems **the failure or malfunctioning of which would endanger health and safety shall qualify as safety components**.
> 1c. A product that is required to undergo a third-party conformity assessment **solely due to risks other than risks to health and safety**, in particular risks relating to the distribution of radio spectrum or electromagnetic interference that do not affect health and safety, shall not be considered as fulfilling the condition in paragraph 1, point (b).’

日本語の意味: 1a — 利用者支援・性能最適化・サービス効率・自動化・利便性・品質管理といった安全に関係しない側面にのみ用いられる AI システムは「安全構成要素」に当たらない。1b — ただし、その故障や誤作動が健康と安全を危険にさらす AI システムは安全構成要素に当たる。1c — 健康・安全以外のリスク（電波の分配や電磁干渉など）のみを理由として第三者適合性評価が要求される製品は、6(1)(b) の条件を満たさない。

### 2.4 Article 6(2) — Annex III 経路 `[条文]`

> 2. In addition to the high-risk AI systems referred to in paragraph 1, AI systems referred to in Annex III shall be considered to be high-risk.

Annex III の 8 分野は §3 に全列挙。

### 2.5 Article 6(3) — フィルタ（逐語引用）`[条文]`

> 3. By derogation from paragraph 2, an AI system referred to in Annex III **shall not be considered to be high-risk where it does not pose a significant risk of harm to the health, safety or fundamental rights of natural persons, including by not materially influencing the outcome of decision making**.
>
> The first subparagraph shall apply where **any** of the following conditions is fulfilled:
> (a) the AI system is intended to perform a **narrow procedural task**;
> (b) the AI system is intended to **improve the result of a previously completed human activity**;
> (c) the AI system is intended to **detect decision-making patterns or deviations from prior decision-making patterns and is not meant to replace or influence the previously completed human assessment**, without proper human review; or
> (d) the AI system is intended to perform a **preparatory task** to an assessment relevant for the purposes of the use cases listed in Annex III.
>
> **Notwithstanding the first subparagraph, an AI system referred to in Annex III shall always be considered to be high-risk where the AI system performs profiling of natural persons.**

日本語の意味: 第 2 項の例外として、Annex III 掲記の AI システムであっても、自然人の健康・安全・基本的権利への重大な危害のリスクをもたらさない場合（意思決定の結果に実質的な影響を与えない場合を含む）は高リスクとみなされない。第 1 段は (a)〜(d) の**いずれか一つ**が満たされる場合に適用される。(a) 狭い手続的タスクの遂行、(b) 既に完了した人間の活動の結果を改善すること、(c) 意思決定パターンや過去の意思決定パターンからの逸脱を検知することを意図し、適切な人間によるレビューなしに既完了の人間の評価を置き換えたり影響したりすることを意図しないもの、(d) Annex III 掲記の用途に関連する評価への準備的タスクの遂行。**第 1 段にかかわらず、当該 AI システムが自然人のプロファイリングを行う場合は常に高リスクとみなされる。**

'profiling' の定義 `[条文]` Article 3(52): "'profiling' means profiling as defined in Article 4, point (4), of Regulation (EU) 2016/679;"（GDPR の定義を参照）

委員会ドラフトガイドラインの読み方 `[公式ガイダンス]`/`[二次解説]`: 4 条件は**累積ではなく選択的**（いずれか一つで足りる）。また、複数の AI コンポーネントが相互作用し、その結合出力が高リスク用途の判断に実質的な影響を与える場合、単一の AI システムとして扱われ、真に分離可能でない限り個々のコンポーネントが単独で 6(3) のフィルタに依拠することはできない。委員会はこれを agentic AI にも明示的に拡張している `[二次解説]`（DLA Piper / Jones Day 等の解説。ドラフト本文での該当箇所は未特定）。

### 2.6 Article 6(4) — 免除を主張する provider の登録義務 `[条文]`

> 4. A provider who considers that an AI system referred to in Annex III is not high-risk shall **document its assessment before that system is placed on the market or put into service**. Such provider shall be subject to the **registration obligation set out in Article 49(2)**. Upon request of national competent authorities, the provider shall provide the documentation of the assessment.

日本語の意味: Annex III 掲記の AI システムが高リスクでないと考える provider は、市場投入または使用開始の**前に**その評価を文書化しなければならない。当該 provider は Article 49(2) の登録義務を負う。所管当局の要求に応じて評価文書を提出しなければならない。

Article 49(2) の内容 `[条文]`:

> 2. Before placing on the market or putting into service an AI system for which the provider has concluded that it is not high-risk according to Article 6(3), that provider or, where applicable, the authorised representative shall register themselves and that system in the EU database referred to in Article 71.

日本語の意味: Article 6(3) により高リスクでないと結論した AI システムについて、provider（または該当する場合は域内代理人）は、市場投入・使用開始の前に、自らと当該システムを Article 71 の EU データベースに登録しなければならない。

つまり「高リスクではない」と主張する道は**無手続ではない**。事前の文書化と EU データベース登録がセットで要求される。

### 2.7 Article 6(5) — 委員会ガイドラインの義務と、実際に出たかどうか `[条文]`

> 5. The Commission shall, after consulting the European Artificial Intelligence Board (the 'Board'), and **no later than 2 February 2026**, provide guidelines specifying the practical implementation of this Article in line with Article 96 together with a comprehensive list of practical examples of use cases of AI systems that are high-risk and not high-risk.

**実際の状況（2026-09-13 時点）— 最終版は未採択、ドラフトのみ** `[公式ガイダンス]`:

| 事項 | 内容 |
|---|---|
| ドラフト公表日 | **2026 年 5 月 19 日**（法定期限 2026-02-02 を超過） |
| 形式 | 3 分冊の ANNEX to a COMMUNICATION FROM THE COMMISSION。文書ヘッダは "Brussels, XXX / […](2026) XXX draft" と**未確定のまま** |
| 表題 | "Draft Commission guidelines on the classification of high-risk AI systems under Article 6 of Regulation (EU) 2024/1689 (AI Act) **for stakeholder consultation**" |
| 分冊 1 | General principles — https://ec.europa.eu/newsroom/dae/redirection/document/128559 |
| 分冊 2 | Annex I of AI Act — https://ec.europa.eu/newsroom/dae/redirection/document/128560 |
| 分冊 3 | Annex III of AI Act — https://ec.europa.eu/newsroom/dae/redirection/document/128561 |
| 公式ページ | https://digital-strategy.ec.europa.eu/en/library/draft-commission-guidelines-classification-high-risk-ai-systems |
| ステータスページ | https://digital-strategy.ec.europa.eu/en/policies/guidelines-ai-high-risk-systems （最終更新 **2026-07-06**。"open until 23 July 2026" のコンサルテーションと "adoption by the Commission" が今後と記載） |

ドラフト本文の Disclaimer（逐語）`[公式ガイダンス]`:

> Disclaimer: These Guidelines are **still a draft document**. They provide clarifications for the classification of AI systems as high-risk pursuant to Article 6 AI Act and a list of practical examples to assist in such classification. The drafts are published for stakeholder feedback to provide input to the Commission **before it adopts a finalised version**.

**【食い違い】コンサルテーション締切**: 委員会公式ページの記述は **2026-07-23** `[公式ガイダンス]`。一方、複数の二次解説は **2026-06-23** とする `[二次解説]`（William Fry 等）。DLA Piper は 2026-07-23 とする `[二次解説]`。両方を記録する。

**結論: Article 6(5) が要求するガイドラインは、2026-09-13 時点で最終版が採択されていない。** 存在するのはドラフト（2026-05-19 公表）のみ。法定期限 2026-02-02 は徒過している。

---

## 3. Annex III の 8 分野 — 全列挙とゲノム解析プラットフォームの該当性

柱書 `[条文]`: "High-risk AI systems pursuant to Article 6(2) are the AI systems listed in any of the following areas:"

| # | 分野（原文見出し） | 小項目 | ゲノムデータ解析／研究プラットフォームの該当可能性 |
|---|---|---|---|
| **1** | **Biometrics**, in so far as their use is permitted under relevant Union or national law | (a) 遠隔生体識別（本人確認のみの biometric verification は除く）／(b) センシティブまたは保護される属性・特性に基づく**生体分類**（当該属性の推論に基づくもの）／(c) 感情認識 | **条件付きであり得る。** ゲノムデータが AI Act 上の 'biometric data'（Article 3(34)、一意識別要件なし）に当たると解される場合、(b) の「生体分類」に触れる余地がある。Annex III 1(b) は Article 5(1)(g) より広く「sensitive or protected attributes」一般を対象とし、健康属性を排除する文言がない。純粋な変異検出・アノテーションのみなら該当しない |
| **2** | **Critical infrastructure**: 重要デジタルインフラ、道路交通、水・ガス・熱・電力の供給の管理運用における安全構成要素 | （細分なし） | **該当しない。** 研究計算基盤は本号の「重要インフラ」ではない |
| **3** | **Education and vocational training** | (a) 入学・入所の判定や配属／(b) 学習成果の評価（学習過程の誘導に用いる場合を含む）／(c) 受けられる教育水準の評価／(d) 試験中の禁止行為の監視・検知 | **該当しない**（研究解析用途では）。ただし同一プラットフォームを大学が受講者評価に転用すれば (b) に触れる |
| **4** | **Employment, workers' management and access to self-employment** | (a) 採用・選考（求人広告のターゲティング、応募書類の分析・絞り込み、候補者評価）／(b) 労働関係の条件・昇進・終了の決定、個人の行動や特性に基づくタスク割当、業績・行動の監視評価 | **該当しない**（研究解析用途では）。研究者の貢献度を自動評価して処遇に結びつける機能を持たせれば (b) に触れる |
| **5** | **Access to and enjoyment of essential private services and essential public services and benefits** | §3.1 に逐語引用 | **原則として該当しない**が、(a)(c)(d) は要検討。§3.1 参照 |
| **6** | **Law enforcement**, in so far as permitted under relevant Union or national law | (a) 犯罪被害者化リスク評価／(b) ポリグラフ等／(c) 証拠の信頼性評価／(d) 再犯リスク評価・人格特性評価／(e) 犯罪の検知・捜査・訴追の過程でのプロファイリング | **該当しない。** ただし法医学ゲノミクス（forensic genomics）を法執行機関向けに提供する場合は別途検討が必要 |
| **7** | **Migration, asylum and border control management**, in so far as permitted under relevant Union or national law | (a) ポリグラフ等／(b) 入国者のリスク（**健康リスクを含む**）評価／(c) 庇護・査証・在留許可申請の審査支援／(d) 本人の検知・認識・識別（渡航文書の確認を除く） | **該当しない**（研究用途では）。(b) に "a health risk, posed by a natural person who intends to enter" とあり、入国者の健康リスク評価に使えば該当しうる |
| **8** | **Administration of justice and democratic processes** | (a) 司法機関による事実と法の調査解釈・法適用の支援（ADR を含む）／(b) 選挙・国民投票の結果や投票行動への影響 | **該当しない** |

### 3.1 Point 5 の逐語引用（医療との接点） `[条文]`

> **5. Access to and enjoyment of essential private services and essential public services and benefits:**
> (a) AI systems intended to be used **by public authorities or on behalf of public authorities** to evaluate the **eligibility of natural persons for essential public assistance benefits and services, including healthcare services**, as well as to grant, reduce, revoke, or reclaim such benefits and services;
> (b) AI systems intended to be used to evaluate the creditworthiness of natural persons or establish their credit score, with the exception of AI systems used for the purpose of detecting financial fraud;
> (c) AI systems intended to be used for **risk assessment and pricing in relation to natural persons in the case of life and health insurance**;
> (d) AI systems intended to evaluate and classify emergency calls by natural persons or to be used to dispatch, or to establish priority in the dispatching of, emergency first response services, including by police, firefighters and medical aid, as well as of **emergency healthcare patient triage systems**.

日本語の意味: (a) **公的機関によって、または公的機関のために**用いられ、**医療サービスを含む**基礎的公的扶助給付・サービスについて自然人の**受給資格**を評価し、またはそれらを付与・減額・取消・回収することを意図した AI システム。(b) 信用度評価・信用スコア（金融詐欺検知を除く）。(c) **生命保険および健康保険**における自然人のリスク評価と価格設定。(d) 緊急通報の評価分類、緊急初動サービス（警察・消防・救急を含む）の派遣または派遣優先順位の決定、および**救急医療のトリアージシステム**。

**重要な限定 — point 5(a) は「医療全般」ではない。** 対象は (i) **公的機関による／公的機関のための**使用であり、(ii) **給付・サービスの受給資格の評価または給付の付与・減額・取消・回収**である。診断支援や治療方針の提示そのものは point 5(a) には入らない（そちらは Annex I 経路＝ MDR/IVDR の問題になる）。

委員会ドラフトガイドラインの解説 `[公式ガイダンス]`:

> (283) For such an AI system to be classified as high-risk pursuant to point 5(a) of Annex III AI Act it must be intended to be used by or on behalf of public authorities: (i) to evaluate the eligibility of natural persons for essential public assistance benefits and services, including healthcare services; or (ii) to grant, reduce, revoke, or reclaim such benefits and services; or (iii) for both purposes.

> (288) Recital 58 AI Act clarifies that essential public assistance benefits and services are those benefits and services **for which natural persons apply, or which natural persons receive that are necessary for them to fully participate in society or to improve their standard of living**. ... These include: 1. **Healthcare services (such as long-term care services)**; 2. Social security benefits ...

日本語の意味: 基礎的公的扶助給付・サービスとは、自然人が申請し、または受給するもので、社会に十分に参加し、または生活水準を向上させるために必要なものをいう。これには医療サービス（長期介護サービス等）や社会保障給付が含まれる。

「on behalf of」について `[公式ガイダンス]`: 委員会は、委託を受けて公的活動を遂行する民間主体も捕捉されると読んでいる（外注による回避を塞ぐ趣旨）`[二次解説]`。

### 3.2 科学研究ツール・ラボデータ解析は Annex III に載っているか

**載っていない。** `[条文]`

Annex III の 8 分野の見出しは Biometrics / Critical infrastructure / Education and vocational training / Employment, workers' management and access to self-employment / Access to and enjoyment of essential private services and essential public services and benefits / Law enforcement / Migration, asylum and border control management / Administration of justice and democratic processes の 8 つのみであり、**「科学研究」「研究インフラ」「臨床検査」「ゲノミクス」「バイオインフォマティクス」「ラボ情報システム」に相当する分野見出しも小項目も存在しない**。consolidated 版（2026-07-27 時点）でも同じで、Regulation (EU) 2026/1744 は Annex III を改正していない。

したがって **Annex III 経路では、純粋な研究用ゲノム解析プラットフォームは高リスクにならない。** 高リスクになるとすれば経路は次の 2 つのいずれかである:

1. **Annex I 経路** — MDR/IVDR の医療機器・体外診断用医療機器に当たり、かつ notified body による第三者適合性評価が必要な場合（§4）。
2. **Annex III の個別小項目に機能が触れる場合** — 特に point 1(b)（生体分類）、point 5(a)（公的機関のための受給資格評価）、point 5(c)（生命・健康保険のリスク評価と価格設定）、point 5(d)（救急トリアージ）。プラットフォームが「解析基盤」を超えてこれらの判断に用いられる出力を出すかどうかで決まる。

なお Article 7 により、委員会は委任法令で Annex III に新たな用途を追加できるが、追加できるのは **既存の 8 分野の中**（"the AI systems are intended to be used in any of the areas listed in Annex III"）であり、新たな分野見出しの追加には Article 112 の手続を経た本則改正が必要 `[条文]`。

---

## 4. 医療機器との接続 — MDR/IVDR

### 4.1 決定的な公式文書: MDCG 2025-6 / AIB 2025-1 `[公式ガイダンス]`

- 正式名称: **FAQ on the Interplay between the Medical Devices Regulation (MDR) & In Vitro Diagnostic Medical Devices Regulation (IVDR) and the Artificial Intelligence Act (AIA)**
- 文書番号: **AIB 2025-1 / MDCG 2025-6**、2025 年 6 月（公表 2025-06-19）
- PDF URL: https://health.ec.europa.eu/document/download/b78a17d7-e3cd-4943-851d-e02a2f22bbb4_en?filename=mdcg_2025-6_en.pdf
- 告知ページ: https://health.ec.europa.eu/latest-updates/mdcg-2025-6-faq-interplay-between-medical-devices-regulation-vitro-diagnostic-medical-devices-2025-06-19_en
- 分量: 27 ページ、36 問。MDCG・New Technologies stakeholders group・EU AI Board の医療技術サブグループが共同作成 `[二次解説]`
- 略語: **MDAI** = medical device AI

### 4.2 高リスク判定の 2 条件（Q2 逐語引用）`[公式ガイダンス]`

> **2. Under what conditions is a MDAI considered a high-risk AI system within the meaning of the AIA?**
> A MDAI is considered a high-risk AI system under Article 6(1) AIA if it meets **both** of the following conditions:
> 1. the MDAI is a safety component, or the AI system is itself a medical device **and**
> 2. the MDAI is subject to a **third-party conformity assessment by a notified body** in accordance with the MDR/IVDR (See table 1 below).

日本語の意味: MDAI は、(1) 安全構成要素であるか AI システム自体が医療機器であること、**かつ** (2) MDR/IVDR に基づき notified body による第三者適合性評価の対象であること、の両方を満たすとき Article 6(1) の高リスク AI システムとなる。

### 4.3 Table 1 — クラス別対応表（逐語再現）`[公式ガイダンス]`

| Classification | Notified Body Involved? | AIA High-Risk (Art. 6(1)) conditions fulfilled? |
|---|---|---|
| MDR Class I (non-sterile, non-measuring, non-reusable surgical) | No | **No** |
| MDR Class I (sterile, measuring, reusable surgical) | Yes | Yes |
| MDR Class IIa, IIb, III | Yes | Yes |
| MDR Annex XVI | Yes | Yes |
| IVDR Class A (non-sterile) | No | **No** |
| IVDR Class A（滅菌） | Yes | Yes |
| IVDR Class B, C, D | Yes | Yes |
| **In-house device according to Art. 5(5) MDR/IVDR** | **No** | **No** |

原文キャプション: "Table 1: Non-exhaustive list of AIA Article 6(1) application to MDR/IVDR"（**非網羅的**であることに注意）

補足 Q4 `[公式ガイダンス]`:

> The classification of an AI system as a high-risk under Article 6(1) AIA does not imply that the medical device or in vitro diagnostic medical device falls in a higher risk class under the MDR and IVDR. ... It is rather **the classification of a medical device under the MDR/IVDR which determines whether the AI system qualifies as high-risk under Article 6(1) AIA**.
> The application of **Article 5 AIA, prohibited AI practices** and Article 50 AIA transparency obligations for providers and deployers of certain AI systems **does not depend on the MDR/IVDR classification**.

日本語の意味: 方向は一方通行である。MDR/IVDR 上の分類が AI Act 上の高リスク該当性を決めるのであって、その逆ではない。そして**禁止行為（Article 5）と透明性義務（Article 50）は MDR/IVDR の分類に依存せず適用される**。つまり医療機器に当たらなくても Article 5 からは逃れられない。

### 4.4 ソフトウェアが医療機器に当たるか — MDCG 2019-11 `[公式ガイダンス]`

- 文書名: **MDCG 2019-11 — Guidance on Qualification and Classification of Software in Regulation (EU) 2017/745 – MDR and Regulation (EU) 2017/746 – IVDR**
- **Revision 1 が 2025 年 6 月 17 日に公表** `[二次解説]`（Emergo by UL、BioSlice Blog 等が一致して報告）。Rev.1 の変更点として報告されているもの: 実質的変更はないが、**MDAI（medical device artificial intelligence）という語が初登場**、modular MDSW の概念の強化、Annex I (c.1) を European Health Data Space 規則との関係で更新、Annex IV に Class I の例を追加、「健康情報を処理するだけのソフトウェアは、それが直接に医療目的に資する場合にのみ MDR/IVDR の対象となる」旨の明確化。Rule 11 の構造と qualification のロジックは不変。
- MDCG 2025-6 による定義の引用 `[公式ガイダンス]`: "According to MDCG 2019-11, 'medical device software' (MDSW) refers to software intended, either alone or in combination, to fulfil a medical purpose as defined in **Article 2(1) MDR or Article 2(2) IVDR**."

**ゲノム解析ソフトが device かどうかの分岐点:**

IVDR Article 2(2) の定義（逐語）`[条文]`:

> 'in vitro diagnostic medical device' means any medical device which is a reagent, reagent product, calibrator, control material, kit, instrument, apparatus, piece of equipment, **software** or system, whether used alone or in combination, intended by the manufacturer to be used in vitro for the examination of specimens, including blood and tissue donations, derived from the human body, **solely or principally for the purpose of providing information on one or more of the following**:
> (a) concerning a physiological or pathological process or state;
> (b) concerning congenital physical or mental impairments;
> (c) concerning the predisposition to a medical condition or a disease;
> (d) to determine the safety and compatibility with potential recipients;
> (e) to predict treatment response or reactions;
> (f) to define or monitoring therapeutic measures.

日本語の意味: 「体外診断用医療機器」とは、試薬・試薬製品・較正物質・対照物質・キット・器具・装置・機器・**ソフトウェア**またはシステムであって、単独でまたは組み合わせて、人体由来の検体（血液・組織提供を含む）を体外で検査するために製造業者が意図し、**もっぱらまたは主として**次の情報を提供する目的のものをいう。(a) 生理的・病理的な過程または状態に関する情報、(b) 先天的な身体的・精神的機能障害に関する情報、**(c) 医学的状態または疾患への素因に関する情報**、(d) 潜在的受容者との安全性・適合性の判定、(e) 治療反応または反応の予測、(f) 治療措置の決定または監視。

**ゲノム解析にとっての要点**: (c) の「疾患への素因（predisposition）」と (e) の「治療反応の予測」は、多くのゲノム解析ソフトが提供する情報そのものである。したがって **intended purpose（製造業者が意図した目的）にこれらの主張を書いた瞬間に IVDR device になる**。逆に言えば、判定は技術ではなく **intended purpose の宣言**で決まる。AI Act Article 3(12) の 'intended purpose' 定義も同じ発想である `[条文]`: "the use for which an AI system is intended by the provider, including the specific context and conditions of use, as specified in the information supplied by the provider in the instructions for use, promotional or sales materials and statements, as well as in the technical documentation"（＝**使用説明書だけでなく、販促資料や技術文書上の記載も intended purpose を構成する**）。

### 4.5 「研究用のみ（research use only）」の除外 — IVDR Article 1(3)(a) `[条文]`

> 3. This Regulation does not apply to:
> (a) **products for general laboratory use or research-use only products**, unless such products, in view of their characteristics, are **specifically intended by their manufacturer to be used for in vitro diagnostic examination**;

日本語の意味: 本規則は、一般的な実験室用製品または研究用のみの製品には適用されない。ただし、その特性に照らして、製造業者が体外診断検査に用いることを特に意図している場合はこの限りでない。

つまり RUO は IVDR の**適用範囲そのものから外れる**。結果として notified body も関与せず、AI Act Article 6(1) の条件 (b) が満たされないため、**Annex I 経路では高リスクにならない**。ただし「研究用のみ」というラベルは、intended purpose の実質が診断であれば通用しない（"in view of their characteristics" と "specifically intended by their manufacturer" の両方を見る文言構造）。

### 4.6 院内製造（in-house）の例外 — IVDR Article 5(5) `[条文]`

> 5. With the exception of the relevant general safety and performance requirements set out in Annex I, the requirements of this Regulation shall not apply to devices manufactured and used only within **health institutions established in the Union**, provided that **all** of the following conditions are met:
> (a) **the devices are not transferred to another legal entity**;
> (b) manufacture and use of the devices occur under appropriate quality management systems;
> (c) the laboratory of the health institution is compliant with standard **EN ISO 15189** or where applicable national provisions, including national provisions regarding accreditation;
> (d) the health institution justifies in its documentation that the target patient group's specific needs cannot be met, or cannot be met at the appropriate level of performance by an **equivalent device available on the market**;
> (e) the health institution provides information upon request on the use of such devices to its competent authority ...;
> (f) the health institution draws up a declaration which it shall make publicly available, including: (i) 製造した health institution の名称と住所、(ii) 機器を特定するために必要な詳細、(iii) Annex I の一般安全性能要件を満たす旨の宣言（満たさない要件があればその情報と理由）;
> (g) class D 機器については、製造施設・製造工程・設計および性能データ（intended purpose を含む）を所管当局が Annex I 適合性を確認できる程度に詳細に記した文書を作成する。加盟国は class A, B, C にもこれを適用しうる;
> (h) 文書どおりに製造されることを確保するあらゆる必要な措置をとる; および
> (i) 臨床使用から得られた経験をレビューし、必要な是正措置をとる。
>
> ... **This paragraph shall not apply to devices that are manufactured on an industrial scale.**

'health institution' の定義 `[条文]` IVDR Article 2(29): "'health institution' means an organisation the primary purpose of which is the care or treatment of patients or the promotion of public health;"

**ゲノミクスプラットフォームにとっての決定的な条件は (a) と最終段である。**
- (a) 「他の法人に移転されないこと」 — 自院内での製造・使用に閉じている必要がある。**他の研究機関にサービスとして提供する形態はこの条件を満たさない。**
- 最終段「産業規模で製造される機器には適用しない」。

MDCG 2025-6 の帰結 `[公式ガイダンス]`: Table 1 のとおり in-house device は notified body の関与がなく、したがって **AI Act の高リスクにも当たらない**。ただし MDCG 2025-6 は、その場合でも AI Act のその他の義務（禁止行為を含む）は適用されると述べている `[二次解説]`（該当 Q 番号は未特定）。AIB と MDCG は in-house MDAI について追加のガイダンスを出す予定と報じられている `[二次解説]`。

### 4.7 臨床評価・性能試験と AI Act の関係（MDCG 2025-6 Q25）`[公式ガイダンス]`

> Where high-risk MDAI undergoes a clinical investigation or performance study, this constitutes **real-world testing** under the AIA. In such cases, paragraph 3 of Article 60(1) applies, which allows real-world testing of high-risk AI systems prior to their placing on the market or putting into service, provided that such testing is in accordance with applicable Union or national laws, including those under the MDR and IVDR.
> Although **the AIA does not apply to AI systems that are not yet placed on the market or put into service**, [脚注 80: Article 2(8) AIA] the AIA introduces a specific provision for Annex III high-risk AI systems ...

日本語の意味: 高リスク MDAI が MDR の臨床試験または IVDR の性能試験を受ける場合、それは AI Act 上の「実環境試験」に当たる。AI Act は市場投入・使用開始前の AI システムには適用されない（Article 2(8)）が、実環境試験には特則がある。

---

## 5. 研究目的の除外 — Article 2(6) と Article 2(8)

### 5.1 Article 2(6) 逐語引用 `[条文]`

> 6. This Regulation does not apply to AI systems or AI models, including their output, **specifically developed and put into service for the sole purpose of scientific research and development**.

日本語の意味: 本規則は、**もっぱら科学研究および開発の目的のために特に開発され、かつ使用開始された** AI システムまたは AI モデル（その出力を含む）には適用されない。

（2026 年改正後も文言は同一。consolidated 版で確認済み。）

### 5.2 Article 2(8) 逐語引用 `[条文]`

> 8. This Regulation does not apply to **any research, testing or development activity regarding AI systems or AI models prior to their being placed on the market or put into service**. Such activities shall be conducted in accordance with applicable Union law. **Testing in real world conditions shall not be covered by that exclusion.**

日本語の意味: 本規則は、AI システムまたは AI モデルが**市場投入または使用開始される前の**研究・試験・開発活動には適用されない。それらの活動は適用される EU 法に従って行われなければならない。**実環境での試験はこの除外の対象外である。**

### 5.3 2 つの除外の役割分担

| | Article 2(6) | Article 2(8) |
|---|---|---|
| 軸 | **目的**による除外 | **時点**による除外 |
| 対象 | もっぱら科学研究開発の目的で特に開発・使用開始された AI システム／モデル（出力を含む） | 市場投入・使用開始「前」のあらゆる研究・試験・開発活動 |
| 除外の切れ目 | 研究以外の目的が混入した時点 | 市場投入または使用開始の時点 |
| 明示された穴 | （条文上なし） | 実環境試験（testing in real world conditions） |

### 5.4 Recital 25 逐語引用 — Article 2(6) の射程を最も規定する文 `[条文]`

> This Regulation should support innovation, should respect freedom of science, and should not undermine research and development activity. It is therefore necessary to exclude from its scope AI systems and models specifically developed and put into service for the sole purpose of scientific research and development. Moreover, it is necessary to ensure that this Regulation does not otherwise affect scientific research and development activity on AI systems or models prior to being placed on the market or put into service. As regards product-oriented research, testing and development activity regarding AI systems or models, the provisions of this Regulation should also not apply prior to those systems and models being put into service or placed on the market. **That exclusion is without prejudice to the obligation to comply with this Regulation where an AI system falling into the scope of this Regulation is placed on the market or put into service as a result of such research and development activity** and to the application of provisions on AI regulatory sandboxes and testing in real world conditions. Furthermore, without prejudice to the exclusion of AI systems specifically developed and put into service for the sole purpose of scientific research and development, **any other AI system that may be used for the conduct of any research and development activity should remain subject to the provisions of this Regulation**. In any event, any research and development activity should be carried out in accordance with recognised ethical and professional standards for scientific research and should be conducted in accordance with applicable Union law.

日本語の意味（後半 2 文が核心）: (i) この除外は、そうした研究開発活動の**結果として** AI システムが市場投入または使用開始される場合に本規則を遵守する義務を妨げない。(ii) もっぱら科学研究開発の目的で特に開発・使用開始された AI システムの除外を妨げることなく、**研究開発活動の遂行に用いられうるその他の AI システムは、本規則の規定の対象であり続けるべきである**。

### 5.5 委員会ガイドラインの解説（禁止行為ガイドライン §2.5.3、para 30–33）`[公式ガイダンス]`

> (31) As clarified in recital 25 AI Act, the AI Act aims to support innovation and recognises the importance of scientific research in advancing AI technologies and contributing to scientific progress and innovation. Article 2(6) AI Act therefore provides an exclusion for 'AI systems or AI models, including their outputs, specifically developed and put into service for the sole purpose of scientific research and development'.
> For example, research into cognitive and behavioural responses to AI-driven subliminal or deceptive stimuli can provide valuable insights into human-AI interactions ... **Such research is permitted, since it is excluded from the scope of the AI Act, notwithstanding the prohibition in Article 5(1)(a) AI Act.**

> (32) The exclusion in Article 2(8) AI Act is, however, **without prejudice to the obligation to comply with the AI Act where an AI system is placed on the market or put into service as a result of such research and development activity**. Testing in real-world conditions within the meaning of the AI Act is also not covered by that exclusion.

> (33) In any event, any research and development activity (including when excluded from the scope of the AI Act) should be carried out in accordance with recognised ethical and professional standards for scientific research and should be conducted in accordance with applicable Union law (e.g., data protection law that remains applicable).

日本語の意味: (31) Article 2(6) の除外は**禁止行為にも及ぶ**（サブリミナル刺激への認知・行動反応の研究は Article 5(1)(a) の禁止にかかわらず許される、という例示）。(32) Article 2(8) の除外は、研究開発の結果として市場投入・使用開始された場合の遵守義務を妨げない。実環境試験も除外されない。(33) いずれにせよ、研究開発活動は認められた科学研究の倫理的・職業的基準に従い、適用される EU 法（データ保護法など。これは引き続き適用される）に従って行われなければならない。

**注記: Article 2(6) は AI Act の scope からの除外なので、禁止行為（Article 5）も高リスク規制（Chapter III）も、除外が効く限りまとめて外れる。** 委員会ガイドライン (31) がそれを明示している。これは重要で、「高リスク分類の前に Article 2(6) が来る」という順序になる。

### 5.6 「他の研究者にサービスとして提供する」場合は保護されるか

**条文上の手がかり（結論は出さず、材料のみ記録する）:**

1. Article 2(6) は "specifically developed **and put into service** for the sole purpose of scientific research and development" と書く。
2. 'putting into service' の定義 `[条文]` Article 3(11): "the supply of an AI system for **first use directly to the deployer** or for own use in the Union for its intended purpose"。→ **他の研究者に供給する行為は 'putting into service' に当たる。** したがって「使用開始したら除外が切れる」という読み方はできない。Article 2(6) はむしろ "put into service ... for the sole purpose of scientific research and development" を除外の**要件**として書いているので、使用開始それ自体は除外を壊さない。
3. しかし Recital 25 の最終段は "any other AI system that **may be used for the conduct of any research and development activity** should remain subject to the provisions of this Regulation" と書く。→ 「研究の遂行に使われうるツール」一般は規制対象であり続ける、という方向を示す。
4. したがって条文構造上の分岐は「**そのシステム自体が、もっぱら科学研究開発を目的として特に開発されたか**」にあり、「利用者が研究者かどうか」「無償かどうか」にはない。汎用的な解析基盤を研究者に提供する場合、(3) の文が効いて除外が否定される可能性がある。
5. 逆に、特定の研究プロジェクトのために特に開発され、その研究目的のみに供給されるシステムであれば、(1)(2) の要件を満たす余地がある。

**この論点を正面から扱った公式文書は見つけられなかった。** 委員会の禁止行為ガイドライン §2.5.3（para 30–33）は研究の「フェーズ」の話に終始し、「研究ツールを第三者に提供する場合」に触れていない。高リスク分類のドラフトガイドライン 3 分冊を全文検索しても、Article 2(6) への言及は Annex III 分冊に 1 箇所（選挙行動のモデリングを研究目的で行う学術機関の例について "it is likely that such AI system would be excluded under Article 2(6) AI Act"）があるのみで、提供形態の議論はない `[公式ガイダンス]`。

（参考・その 1 箇所の逐語）`[公式ガイダンス]`:

> - AI systems used by academic institutions for modelling electoral behaviour for research purposes. Such systems are not intended to influence the outcome of elections. In any event, it is likely that such AI system would be excluded under Article 2(6) AI Act.

---

## 6. 使用した一次資料の所在（再検証用）

| 資料 | URL | 取得方法 |
|---|---|---|
| AI Act 原典（OJ, CELEX 32024R1689） | https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32024R1689 | curl（User-Agent 要設定） |
| AI Act consolidated（2026-07-27 時点） | https://eur-lex.europa.eu/eli/reg/2024/1689/2026-07-27 | curl。CELEX 形式の URL は HTTP 202 で空応答になるため ELI 形式を使うこと |
| Regulation (EU) 2026/1744（Digital Omnibus on AI） | https://eur-lex.europa.eu/eli/reg/2026/1744/oj/eng | curl |
| IVDR 原典（CELEX 32017R0746） | https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32017R0746 | curl |
| 禁止行為ガイドライン C(2025) 5052 final | https://ec.europa.eu/newsroom/dae/redirection/document/112367 | curl + pdftotext |
| 高リスク分類ドラフトガイドライン（3 分冊） | 128559 / 128560 / 128561（§2.7 の表） | curl + pdftotext |
| MDCG 2025-6 / AIB 2025-1 | https://health.ec.europa.eu/document/download/b78a17d7-e3cd-4943-851d-e02a2f22bbb4_en?filename=mdcg_2025-6_en.pdf | curl + pdftotext |

注: EUR-Lex は連続アクセスで HTTP 202（空ボディ）を返すことがある。数秒〜十数秒空けて ELI 形式 URL で再試行すると 200 が返る。

---

## 確認できなかったこと

1. **Regulation (EU) 2026/1744 の官報掲載日。** 二次解説は 2026-07-24 とするが、OJ ヘッダから直接確認していない。発効日 2026-07-27 は consolidated 版の ELI（`.../2024/1689/2026-07-27`）から逆算した推定であり、改正法 Article 4 の文言そのものは読んでいない。検索語: "Regulation (EU) 2026/1744 digital omnibus AI Act amending 2024/1689 EUR-Lex"。

2. **Article 6(5) ガイドラインの最終版が 2026-07 以降に採択されたかどうか。** 委員会ステータスページの最終更新は 2026-07-06 で、その時点では未採択。2026-07-06 から本調査日 2026-09-13 までの間に採択された形跡は検索で見つからなかったが、**「採択されていない」ことを積極的に確認したわけではない**（ネガティブの証明はできていない）。検索語: "high-risk classification guidelines AI Act final adopted Commission September 2026 Article 6(5)"。書き手は digital-strategy.ec.europa.eu の当該ページと ai-act-service-desk.ec.europa.eu を直接再確認すること。

3. **高リスク分類ドラフトガイドラインのコンサルテーション締切**。委員会ページは 2026-07-23、一部の二次解説は 2026-06-23 とする（§2.7 の【食い違い】）。どちらが正しいか、または段階が 2 つあったのかを確定できなかった。

4. **ゲノム配列データが AI Act Article 3(34) の 'biometric data' に当たるか**を正面から述べた公式見解。委員会ガイドライン para 278 が「生体分類は DNA に基づくこともある」と述べているのが最も近い記述で、定義該当性そのものを論じた文書は見つからなかった。検索範囲: 禁止行為ガイドライン全文（"genetic" は 0 件）、高リスク分類ドラフト 3 分冊。

5. **Article 2(6) が「他の研究者にサービスとして提供されるシステム」を保護するか**（§5.6）。公式ガイダンスに該当する記述がない。条文・recital・定義からの材料のみ記録した。国内所管当局のガイダンスや CJEU の判断は探索していない。

6. **MDCG 2025-6 のうち、in-house MDAI について「AI Act のその他の義務は適用される」と述べている箇所の Q 番号。** 二次解説（NSF、Emergo by UL）が一致してそう報じているが、PDF 本文で該当 Q を特定できなかった。書き手が引用する場合は PDF を直接確認すること。

7. **委員会ドラフトガイドラインにおける modular / agentic AI と Article 6(3) フィルタの関係の逐語**。DLA Piper・Jones Day 等の二次解説が「分離可能でない限りコンポーネント単位でフィルタに依拠できない」と報じているが、ドラフト本文の該当パラグラフ番号を特定していない。

8. **MDCG 2019-11 Rev.1 の一次 PDF**。Rev.1 の存在と 2025-06-17 公表、および変更点の内容は複数の二次解説から取ったもので、health.ec.europa.eu 上の PDF 本体は取得していない。Rev.1 の変更点に関する記述はすべて `[二次解説]` 扱いとすること。

9. **Annex III point 1(b)（生体分類）についてのドラフトガイドラインの解説**。ゲノムデータとの関係を確認したかったが、Annex III 分冊の point 1 の記述を精読していない（point 5 と point 8 のみ確認）。

10. **MDR（Regulation (EU) 2017/745）Article 2(1) の医療機器定義および同 Article 5(5)**。IVDR 側は一次条文で確認したが、MDR 側は条文を直接取得していない。ゲノム解析は主に IVDR 側の問題になるため優先度を下げた。
