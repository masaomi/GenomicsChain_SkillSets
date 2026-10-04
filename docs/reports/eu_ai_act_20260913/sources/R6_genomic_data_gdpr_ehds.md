# R6 — ゲノムデータ特有の論点：GDPR・EHDS と AI Act の重なり

**資料種別**: source dossier（一次資料の逐語引用集。人向けの読み物ではない）
**調査日**: 2026-09-13
**対象**: ヒトゲノムデータを扱い、解析パイプラインを走らせ、工程の一部で LLM を使う研究向けプラットフォーム
**記載規約**: 各事実に (a) 条番号または文書名 / (b) 出典 URL / (c) 英語原文引用 / (d) 出典種別 `[条文]` `[公式ガイダンス]` `[二次解説]` `[学術]` を付す。未確認は「確認できず」と明記する。出典が割れる場合は両論を残し「食い違い」と標識する。

---

## 0. この調査で判明した、前提を覆す事実

書き手が最初に知るべきことを先に置く。以下の三点は、2026年9月時点の法状況が 2024〜2025 年の解説と食い違う箇所である。

| # | 通説・依頼時の前提 | 2026-09-13 時点の実際 | 根拠 |
|---|---|---|---|
| 1 | AI Act の偏り検知例外は **Article 10(5)** にある | **Article 10(5) は削除された。**内容は新設 **Article 4a** に移り、対象が high-risk 以外にも拡大した | Regulation (EU) 2026/1744（§3） |
| 2 | AI Act Art. 2(7) は「Art. 10(5) と Art. 59 を除き GDPR に影響しない」 | 同じ改正で **「Articles 4a and 59」に書き換えられた** | Regulation (EU) 2026/1744（§4） |
| 3 | EHDS の二次利用にゲノムが入るかは要確認 | **明示的に入っている。**Art. 51(1)(f) `human genetic, epigenomic and genomic data`。ただし**この号の適用開始は 2031-03-26** と他号より遅い | Regulation (EU) 2025/327（§5） |
| 4 | スイスの十分性認定は **2024年に更新された** | **更新も差し替えもされていない。**2000年の **Decision 2000/518/EC** が現在も唯一の法的文書。2024-01-15 に出たのは**報告書**（COM(2024) 7 final）であって新決定ではない。依頼書が挙げた「2024/2683」という文書は**存在しない** | §7.1 |
| 5 | ドイツは **GenDG** で Art. 9(4) を行使した | 臨床・保険・雇用では正しいが、**研究には適用されない**（GenDG § 2(2) Nr. 1 が明文で除外）。ドイツの監督機関 DSK 自身が「研究用遺伝データには一般則しかない」と認めている | §1.7 |

加えて、**Digital Omnibus は二本に割れている**点に注意。AI 側（AI Act 改正）は成立済み。GDPR 側（個人データの定義変更、Art. 9 の新例外、科学研究の定義など）は **2026-09-13 時点で提案のまま、未成立**。したがって GDPR の条文は現行どおり読む。

---

## 1. 遺伝データの位置づけ — GDPR

### 1.1 定義 — Art. 4(13)

- **(a)** Regulation (EU) 2016/679, Article 4(13)
- **(b)** https://gdpr-info.eu/art-4-gdpr/ ／ 一次: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32016R0679
- **(d)** `[条文]`
- **(c)**

> "'genetic data' means personal data relating to the inherited or acquired genetic characteristics of a natural person which give unique information about the physiology or the health of that natural person and which result, in particular, from an analysis of a biological sample from the natural person in question;"

日本語の趣旨: 遺伝データとは、自然人の遺伝的特徴（先天・後天を問わない）に関する個人データであって、その人の生理または健康について固有の情報を与えるものをいい、とりわけ当該本人の生体試料の分析から得られるものをいう。

**Recital 34** が範囲を補足する（染色体・DNA・RNA の分析、または同等の情報を与える他の分析）。

### 1.2 識別要因としての「遺伝的同一性」— Art. 4(1)

ここが全ての起点になる。個人データの定義そのものに「遺伝的」が識別要因として書き込まれている。

- **(a)** GDPR Article 4(1)
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32016R0679
- **(d)** `[条文]`
- **(c)**

> "'personal data' means any information relating to an identified or identifiable natural person ('data subject'); an identifiable natural person is one who can be identified, directly or indirectly, in particular by reference to an identifier such as a name, an identification number, location data, an online identifier or to one or more factors specific to the physical, physiological, **genetic**, mental, economic, cultural or social identity of that natural person;"

日本語の趣旨: 識別可能な自然人とは、直接または間接に識別されうる者をいい、とりわけ氏名・識別番号・位置データ・オンライン識別子、または当該自然人の身体的・生理的・**遺伝的**・精神的・経済的・文化的・社会的同一性に特有な一つ以上の要因を参照して識別されうる者をいう。

→ 氏名を除去しても、遺伝的同一性に特有な要因が残れば個人データでありうる。§2 の匿名化論の法的土台はここにある。

### 1.3 原則禁止 — Art. 9(1)

- **(a)** GDPR Article 9(1)
- **(b)** https://gdpr-info.eu/art-9-gdpr/
- **(d)** `[条文]`
- **(c)**

> "Processing of personal data revealing racial or ethnic origin, political opinions, religious or philosophical beliefs, or trade union membership, and the processing of **genetic data**, biometric data for the purpose of uniquely identifying a natural person, data concerning health or data concerning a natural person's sex life or sexual orientation shall be prohibited."

日本語の趣旨: 人種・民族的出自、政治的意見、宗教・哲学的信条、労働組合加入を明らかにする個人データの取扱い、ならびに**遺伝データ**、自然人の一意識別を目的とする生体データ、健康に関するデータ、性生活・性的指向に関するデータの取扱いは、禁止する。

**構造上の要点**（実務で最も間違えられる点）: Art. 9(1) は原則禁止であり、Art. 9(2) がこれを解除する。**Art. 6 の適法根拠だけでは足りない。**Art. 6 の根拠と Art. 9(2) の解除事由の**両方**が累積的に必要である。制裁は Art. 83(5) の上位区分（2000万ユーロまたは全世界年間売上高の 4%、いずれか高い方）。

### 1.4 解除事由 — Art. 9(2)(a) 明示的同意

- **(a)** GDPR Article 9(2)(a)
- **(b)** https://gdpr-info.eu/art-9-gdpr/
- **(d)** `[条文]`
- **(c)**

> "the data subject has given explicit consent to the processing of those personal data for one or more specified purposes, except where Union or Member State law provide that the prohibition referred to in paragraph 1 may not be lifted by the data subject"

日本語の趣旨: データ主体が、一つ以上の特定された目的のために当該個人データの取扱いに明示的同意を与えた場合。ただし、第1項の禁止をデータ主体が解除できない旨を EU 法または加盟国法が定める場合を除く。

→ 末尾の但書が重要。**加盟国法が「同意では解除できない」と定めることを許している。**§1.6 の国内上乗せと接続する。

### 1.5 解除事由 — Art. 9(2)(j) 科学研究、および Art. 89(1) の保護措置

- **(a)** GDPR Article 9(2)(j)
- **(b)** https://gdpr-info.eu/art-9-gdpr/
- **(d)** `[条文]`
- **(c)**

> "processing is necessary for archiving purposes in the public interest, scientific or historical research purposes or statistical purposes in accordance with Article 89(1) based on Union or Member State law which shall be proportionate to the aim pursued, respect the essence of the right to data protection and provide for suitable and specific measures to safeguard the fundamental rights and the interests of the data subject."

日本語の趣旨: 公共の利益における記録保存の目的、科学的・歴史的研究の目的または統計の目的のために、Art. 89(1) に従って取扱いが必要である場合。ただし EU 法または加盟国法に基づくものであり、追求する目的に比例し、データ保護の権利の本質を尊重し、データ主体の基本的権利と利益を保護する適切かつ特別の措置を定めるものでなければならない。

**注意**: (j) は**それ自体では使えない。**「EU 法または加盟国法に基づく」ことが条件なので、国内法の受け皿が要る。国によって使えたり使えなかったりするのはこのためである。

- **(a)** GDPR Article 89(1)
- **(b)** https://gdpr-text.com/read/article-89/ ／ EDPB 委託研究 https://www.edpb.europa.eu/system/files/2022-01/legalstudy_on_the_appropriate_safeguards_89.1.pdf
- **(d)** `[条文]`
- **(c)** 冒頭文（逐語、完全に取得できたもの）

> "Processing for archiving purposes in the public interest, scientific or historical research purposes or statistical purposes, shall be subject to appropriate safeguards, in accordance with this Regulation, for the rights and freedoms of the data subject."

続く部分（複数の再録サイトで一致、ただし一次 PDF からの完全逐語は未取得 → **一部確認できず**）:

> "Those safeguards shall ensure that technical and organisational measures are in place in particular in order to ensure respect for the principle of data minimisation."

→ その後、措置には仮名化が含まれうること、識別を許さない形で目的を達成できるならその方法によらねばならないことが続く。**趣旨は「識別不要なら識別するな」**であり、§2 と §6 の双方に効く。

- **(a)** GDPR Article 89(2)
- **(b)** https://gdpr-info.eu/art-89-gdpr/
- **(d)** `[条文]`
- **(c)**

> "Where personal data are processed for scientific or historical research purposes or statistical purposes, Union or Member State law may provide for derogations from the rights referred to in Articles 15, 16, 18 and 21 subject to the conditions and safeguards referred to in paragraph 1 of this Article in so far as such rights are likely to render impossible or seriously impair the achievement of the specific purposes, and such derogations are necessary for the fulfilment of those purposes."

日本語の趣旨: 科学的・歴史的研究または統計の目的で個人データが取扱われる場合、EU 法または加盟国法は、Art. 15（アクセス）・16（訂正）・18（制限）・21（異議）の権利からの逸脱を定めうる。ただし第1項の条件と保護措置に服し、それらの権利が特定目的の達成を不可能にするか著しく損なう恐れがある限度において、かつその逸脱が目的達成に必要な場合に限る。

→ **逸脱もまた国内法次第。**GDPR が直接与える免除ではない。

### 1.6 Art. 9(4) — 加盟国がさらに条件を課せる（国内法が割れる理由）

- **(a)** GDPR Article 9(4)
- **(b)** https://gdpr-info.eu/art-9-gdpr/
- **(d)** `[条文]`
- **(c)**

> "Member States may maintain or introduce further conditions, including limitations, with regard to the processing of genetic data, biometric data or data concerning health."

日本語の趣旨: 加盟国は、遺伝データ、生体データまたは健康に関するデータの取扱いについて、制限を含むさらなる条件を維持し、または導入することができる。

**一方通行の歯止め**: 加盟国は**締める方向にしか動けない。**新しい適法根拠を加えることも、特別カテゴリの保護水準を下げることもできない（`[二次解説]` 複数で一致。一次条文には明文なし、Art. 9 の構造とリサイタルからの解釈）。

**帰結**: EU 域内でも遺伝データの規律は統一されていない。**「GDPR を満たした」は「その国の法を満たした」を意味しない。**具体的な国別の上乗せ例は §7.3 に置く。

> **EHDS による部分的な閉鎖に注意** — EHDS Recital (52) は、二次利用の文脈に限り Art. 9(4) の上乗せ余地を原則として閉じる。§5.6 参照。

### 1.7 加盟国の上乗せ — 具体例

「どの国が Art. 9(4) を実際に使ったか」を、**条文が 9条4項を名指ししているか**で整理する。ここを曖昧にした解説が多い。

```
9条4項を条文で名指ししているか？
  ├─ ITALY   ★★★ Codice privacy 2-septies 条が「In attuazione di ... art. 9, par. 4」と明記
  ├─ FRANCE  ★★★ Loi 78-17 art. 8-I-2°-c が「en application du 4 de l'article 9」と明記
  ├─ SPAIN   ★★  明記なし。追加規定第17 ＋ Ley 14/2007 が実質的に上乗せ
  ├─ FINLAND ★★  552/2019 が許可制・安全環境・匿名結果を上乗せ
  └─ GERMANY ✗   連邦法に 9条4項を名指しした条文なし
                 BDSG §22 は 9条2項の実装。GenDG は研究を明示的に適用除外
```

#### イタリア — 最も明快な 9条4項の実装（推奨して引く例）

- **(a)** D.Lgs. 30 giugno 2003, n. 196（D.Lgs. 101/2018 改正後）**Art. 2-septies** "Misure di garanzia per il trattamento dei dati genetici, biometrici e relativi alla salute"
- **(b)** https://www.brocardi.it/codice-della-privacy/parte-i/titolo-i/capo-ii/art2septies.html （⚠️ 公式統合版 Normattiva は未取得。再録サイトで確認）
- **(d)** `[条文]`
- **(c)** 第1項（逐語）

> "**In attuazione di quanto previsto dall'articolo 9, paragrafo 4, del regolamento**, i dati genetici, biometrici e relativi alla salute, possono essere oggetto di trattamento in presenza di una delle condizioni di cui al paragrafo 2 del medesimo articolo ed **in conformità alle misure di garanzia disposte dal Garante**"

英訳: "In implementation of Article 9(4) of the Regulation, genetic, biometric and health-related data may be processed where one of the conditions in Article 9(2) is present and **in conformity with the safeguard measures laid down by the Garante**."

**第6項 — 遺伝データだけに適用される特則（逐語）**

> "**Limitatamente ai dati genetici**, le misure di garanzia possono individuare, in caso di particolare ed elevato livello di rischio, **il consenso come ulteriore misura di protezione** dei diritti dell'interessato, **a norma dell'articolo 9, paragrafo 4, del regolamento**"

英訳: "**Limited to genetic data**, the safeguard measures may identify, in the case of a particular and high level of risk, **consent as an additional measure of protection** of the data subject's rights, **pursuant to Article 9(4) of the Regulation**."

→ **「遺伝データに限って同意を追加の保護措置として課しうる」**という、Art. 9(4) の教科書的な行使例。

第8項（逐語）: "I dati personali di cui al comma 1 **non possono essere diffusi**."（公表・拡散の禁止）

**実際に適用されている措置**

- **(a)** Garante, **Provvedimento n. 146 del 5 giugno 2019**, GU Serie Generale n. 176 del 29 luglio 2019, doc. web **9124510**
- **(b)** https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/9124510
- **(d)** `[公式ガイダンス]`
- 旧 Autorizzazione generale n. 8/2016（遺伝データ）は**更新のうえ維持**された。逐語: "4. Prescrizioni relative al trattamento **dei dati genetici (aut. gen. n. 8/2016)**;"
- §4.2 lett. e（逐語）: "i dati genetici e i campioni biologici […] **sono trattati con tecniche di cifratura o di pseudonimizzazione** […] le predette tecniche devono consentire, altresì, **il trattamento disgiunto dei dati genetici e sanitari dagli altri dati personali che permettono di identificare direttamente le persone interessate**."

日本語の趣旨: 名簿・登録簿・DB に含まれる遺伝データと生体試料は**暗号化または仮名化技術**で処理し、アクセス権者にとっても一時的に判読不能とすること。当該技術は、**遺伝・健康データを直接識別可能な他の個人データから分離して処理**できるものでなければならない。

**2025年の改正** — Garante, Provvedimento n. 66 del 13 febbraio 2025, GU n. 55 del 7 marzo 2025, doc. web **10112364**（https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/10112364 `[公式ガイダンス]`）: 遺伝データ研究の二次利用について、**Garante への事前協議義務を撤廃**し、Codice 110条1項後段に従わせる形に改めた。

⚠️ **2-septies 条にもとづく遺伝データ専用の misure di garanzia は 2026-09-13 時点で未採択。**2019年措置が恒久的な経過措置として機能している。2-septies 条2項の「少なくとも2年ごと」義務は 2018年の導入以来一度も履行されていない。

#### フランス — 9条4項を名指しした唯一の国レベル委任

- **(a)** Loi n° 78-17 du 6 janvier 1978, **article 8, I, 2°, c)**（Ordonnance n° 2018-1125 による番号振り直し後）
- **(b)** https://www.cnil.fr/fr/loi-78-17-du-6-janvier-1978-modifiee （⚠️ legifrance.gouv.fr は Cloudflare により自動取得不可。CNIL の法令再録で確認）
- **(d)** `[条文]`
- **(c)**

> "c) […] elle établit et publie des **règlements types** […] et de régir les traitements de données biométriques, **génétiques** et de santé. A ce titre […] elle peut prescrire des mesures, notamment techniques et organisationnelles, supplémentaires pour le traitement des données biométriques, **génétiques** et de santé **en application du 4 de l'article 9 du règlement (UE) 2016/679 du 27 avril 2016**"

→ ⚠️ **ただし遺伝データ向けの règlement type は未制定。**CNIL の公式一覧（https://www.cnil.fr/fr/reglements-type）に掲載されているのは職場の生体認証に関する1件のみ。**フランスの 9条4項委任は生体データについてのみ行使され、遺伝データについては未行使。**遺伝データの追加条件は議会制定法が担っている。

**データ保護法内の遺伝データ専用条項 — Loi 78-17 article 75（逐語・全文）** `[条文]`
（https://www.legifrance.gouv.fr/codes/article_lc/LEGIARTI000043896110）

> "Dans le cas où la recherche nécessite l'**examen des caractéristiques génétiques**, le **consentement éclairé et exprès** des personnes concernées doit être obtenu préalablement à la mise en œuvre du traitement de données. Le présent article n'est pas applicable aux recherches réalisées en application de l'article **L. 1130-5** du code de la santé publique."

英訳: "Where the research requires an **examination of genetic characteristics**, the **informed and express consent** of the persons concerned must be obtained prior to the implementation of the data processing."

**民法・公衆衛生法典・刑法による三重の上乗せ**

| 法令・条 | 逐語（抜粋） | 内容 | 種別 |
|---|---|---|---|
| Code civil **art. 16-10 I** | "**L'examen des caractéristiques génétiques constitutionnelles d'une personne ne peut être entrepris qu'à des fins médicales ou de recherche scientifique. Il est subordonné au consentement exprès de la personne, recueilli par écrit préalablement**" | 目的を医療・科学研究に限定。書面の明示的同意 | `[条文]` |
| Code civil **art. 16-10 IV** | "**Tout démarchage à caractère publicitaire portant sur l'examen des caractéristiques génétiques constitutionnelles d'une personne est interdit.**" | 勧誘広告の禁止 | `[条文]` |
| CSP **L. 1131-3** | "sont **seuls habilités** […] les **praticiens agréés** à cet effet par l'**Agence de la biomédecine** […] Les personnes qui procèdent à des examens […] **à des fins de recherche scientifique sont agréées**" | **研究目的の実施者にも生物医学庁の認証が必要** | `[条文]` |
| CSP **L. 1131-2-1** | "ne peuvent être pratiqués que dans des **laboratoires de biologie médicale autorisés** […] et **accrédités**" | 医療目的の検査は認可＋認定検査室のみ | `[条文]` |
| CSP **L. 1130-5 I** | "peut être réalisé à partir d'éléments du corps […] prélevés à d'autres fins **lorsque cette personne […] n'a pas exprimé son opposition**" | 二次利用研究はオプトアウトで可 | `[条文]` |
| Code pénal **226-25 I** | "Le fait de procéder à l'examen des caractéristiques génétiques d'une personne **à des fins autres que médicales, de recherche scientifique ou de lutte contre le dopage** est puni d'un an d'emprisonnement et de 15 000 euros d'amende." | 刑事罰 | `[条文]` |
| Code pénal **226-28-1** | "Le fait, pour une personne, **de solliciter l'examen de ses caractéristiques génétiques** ou de celles d'un tiers […] **en dehors des conditions prévues par la loi** est puni de **3 750 € d'amende**." | **消費者本人が海外 DTC に依頼する行為自体**を処罰 | `[条文]` |

→ **DTC 遺伝子検査の実質禁止は、民法 16-10 I ＋ IV ＋刑法 226-25 I・226-28-1 の組み合わせで成立している。**単独の「DTC 禁止条文」は存在しない。

> **【食い違い】HDS 認証は遺伝データに適用されるか。** 「France requires HDS certification as an Article 9(4) overlay」と説明する二次資料がある一方、ANS の参照基準 v2.0 §3.1.2 は適用範囲を **GDPR 4条15号（健康データ）**と定義し、**4条13号（遺伝データ）に言及していない**（https://esante.gouv.fr/sites/default/files/media_entity/documents/referentiel_certification_hds---fr--v2.pdf `[公式ガイダンス]`）。CSP L. 1111-8 I も取得文脈を "prévention, diagnostic, soins ou suivi social et médico-social" に限定。**「遺伝データだから HDS が要る」を支える条文は見つからなかった。**遺伝データが HDS 対象になるのは、それが臨床文脈で取得された健康データである限りにおいてである。

#### ドイツ — 依頼書の想定に重要な訂正

**BDSG § 22 は 9条4項ではなく 9条2項の実装である。**

- **(a)** Bundesdatenschutzgesetz **§ 22**
- **(b)** 独 https://www.gesetze-im-internet.de/bdsg_2018/__22.html ／ **公式英訳** https://www.gesetze-im-internet.de/englisch_bdsg/englisch_bdsg.html
- **(d)** `[条文]`（独英とも公式）
- § 22(1) は冒頭で "**Abweichend von Artikel 9 Absatz 1** der Verordnung (EU) 2016/679"（By derogation from Article 9(1)）と述べており、**9条2項の開放条項の実装**である。かつ**遺伝データを個別に扱う条文ではない**（9条1項の全カテゴリに一律適用）。
- § 22(2) 公式英訳（逐語・抜粋）:

> "(2) In the cases of subsection 1, **appropriate and specific measures shall be taken to safeguard the interests of the data subject.** […] these measures may include in particular the following: […] **6. the pseudonymization of personal data; 7. the encryption of personal data;** […] **10. specific rules of procedure to ensure compliance with this Act and with Regulation (EU) 2016/679 in the event of transfer or processing for other purposes.**"

**Gendiagnostikgesetz (GenDG) — 日付は依頼書のとおり正しい**

- **(a)** Gendiagnostikgesetz、**Ausfertigungsdatum 31.07.2009**、**BGBl. I S. 2529, 3672**、最終改正 Artikel 15 Absatz 4 des Gesetzes vom 4. Mai 2021 (BGBl. I S. 882)、**施行 2010-02-01**
- **(b)** https://www.gesetze-im-internet.de/gendg/
- **(d)** `[条文]`（⚠️ **公式英訳は存在しない。**以下は筆者訳）

**★最重要 — GenDG は研究に適用されない（§ 2 Abs. 2 Nr. 1、逐語）**

> "(2) **Dieses Gesetz gilt nicht** für genetische Untersuchungen und Analysen und den Umgang mit genetischen Proben und Daten **1. zu Forschungszwecken,** […]"

英訳: "(2) **This Act does not apply** to genetic examinations and analyses and to the handling of genetic samples and data **1. for research purposes** […]"

**ドイツの監督機関自身が「研究分野では 9条4項は未行使」と認めている**

- **(a)** DSK, **107. Konferenz, Beschluss vom 15. Mai 2024**「Positionspapier – Anforderungen an die Sekundärnutzung von genetischen Daten zu Forschungszwecken」
- **(b)** https://www.lda.brandenburg.de/lda/de/datenschutz/institutionen-und-dokumente/entschliessungen/107-dsk-sekundaernutzung-von-genetischen-daten-zu-forschungszwecken/
- **(d)** `[公式ガイダンス]`
- **(c)**

> "**Das Gendiagnostikgesetz gilt aber ausdrücklich nicht für die Verarbeitung von Daten zu Forschungszwecken (§ 2 Absatz 2 Nr. 1 GenDG). Für die Verarbeitung genetischer Daten zu Forschungszwecken gelten bislang deshalb lediglich die allgemeinen Regelungen für die Forschung mit besonderen Kategorien personenbezogener Daten.**"

> "Die DSK ist […] der Auffassung, dass für die Sekundärnutzung genetischer Daten zu Forschungszwecken eine **differenzierte und rechtsklare gesetzliche Regelung geschaffen werden muss** […] **Artikel 9 Absatz 4 DS-GVO** wie auch voraussichtlich die EHDS-Verordnung **sehen ausdrücklich eine entsprechende Öffnungsklausel für zusätzliche Bedingungen, einschließlich Beschränkungen, zur Verarbeitung genetischer Daten vor.**"

英訳: "**However, the Genetic Diagnosis Act expressly does not apply to the processing of data for research purposes (§ 2(2) no. 1 GenDG). For the processing of genetic data for research purposes, therefore, only the general rules on research with special categories of personal data have applied to date.** […] a **differentiated and legally clear statutory rule must be created** […]"

> **＝「ドイツは GenDG で 9条4項を使った」という説明は、臨床・保険・雇用の場面では正しく、研究の場面では誤り。**研究用遺伝データは、連邦法に遺伝特化ルールがなく、BDSG § 27 ＋ 州法（Berlin LKG § 25、Baden-Württemberg LKHG § 48、Bayern BayUniKlinG Art. 16 等）の寄せ集めで規律されている。**州をまたぐ研究連携では法的根拠が分裂する。**

参考 — BDSG § 27(1) 公式英訳（逐語・抜粋）`[条文]`: "**By derogation from Article 9(1)** […] processing […] shall be permitted **also without consent** for scientific or historical research purposes […] if […] the interests of the controller in processing **substantially outweigh** those of the data subject"

（GenDG の主要制限は臨床・保険・雇用に及ぶ。§ 7 実施主体の限定、§ 8(1) 明示的書面同意、§ 9 事前説明・熟慮期間・**知らないでいる権利**、§ 11 結果は本人のみ、§ 12(1) **10年保存 → 期限到来で即時廃棄**、§ 13(1) 検体の厳格な目的拘束、§ 18(1) 保険での要求禁止（生命保険で給付30万€超／年金3万€超は例外）、§ 19 雇用での要求禁止。罰則 § 25 1年以下の自由刑（有償・利得目的なら2年以下）、§ 26 5万€以下の過料。）

#### スペイン

- **(a)** Ley Orgánica 3/2018, de 5 de diciembre, **Disposición adicional decimoséptima**「Tratamientos de datos de salud」
- **(b)** https://www.boe.es/buscar/act.php?id=BOE-A-2018-16673 （BOE 公式統合版、ブロック #da-17）
- **(d)** `[条文]`
- **(c)** 第2項 c)（再利用の中核条項、逐語）

> "c) **Se considerará lícita y compatible la reutilización de datos personales con fines de investigación en materia de salud y biomédica cuando, habiéndose obtenido el consentimiento para una finalidad concreta, se utilicen los datos para finalidades o áreas de investigación relacionadas con el área en la que se integrase científicamente el estudio inicial.** […] **se requerirá informe previo favorable del comité de ética de la investigación.**"

第2項 d)（仮名化の中核条項、逐語・抜粋）:

> "d) […] **1.º Una separación técnica y funcional entre el equipo investigador y quienes realicen la seudonimización y conserven la información que posibilite la reidentificación.** 2.º Que los datos seudonimizados únicamente sean accesibles al equipo de investigación cuando: i) Exista un compromiso expreso de confidencialidad y de no realizar ninguna actividad de reidentificación […]"

英訳: "**1º A technical and functional separation between the research team and those who carry out the pseudonymisation and hold the information enabling re-identification.**"

→ **§2.7 の EDPB Guidelines 1/2026 para 168 が挙げる「federated storage with access through secure processing environments」と同じ設計思想が、スペインでは既に法律になっている。**

- **(a)** **Ley 14/2007, de 3 de julio, de Investigación biomédica**, TÍTULO V（44–71条）
- **(b)** https://www.boe.es/buscar/act.php?id=BOE-A-2007-12945
- **(d)** `[条文]`

| 条 | 逐語（抜粋） | 内容 |
|---|---|---|
| **45 c)** | "**Los datos genéticos de carácter personal no podrán ser utilizados con fines comerciales.**" | 個人遺伝データの**商業利用の全面禁止** |
| **45 e)** | "los datos obtenidos de los análisis genéticos **no podrán ser tratados ni cedidos con fines distintos a los previstos en esta Ley**" | 本法の目的外の処理・移転の禁止 |
| **48(1)** | "**Será preciso el consentimiento expreso y específico por escrito para la realización de un análisis genético.**" | 明示的・特定的・書面の同意 |
| **50(2)** | "**Los datos genéticos de carácter personal sólo podrán ser utilizados con fines epidemiológicos, de salud pública, de investigación o de docencia cuando el sujeto interesado haya prestado expresamente su consentimiento, o cuando dichos datos hayan sido previamente anonimizados.**" | **研究利用は明示的同意か匿名化のいずれか** |
| **51(1)** | "quedará sujeto al **deber de secreto de forma permanente**" | **恒久的な**守秘義務 |
| **52(1)** | "**se conservarán durante un período mínimo de cinco años**" | **最低5年の保存義務**（上乗せ） |
| **58(2)** | "**El consentimiento del sujeto fuente será siempre necesario cuando se pretendan utilizar con fines de investigación biomédica muestras biológicas que hayan sido obtenidas con una finalidad distinta, se proceda o no a su anonimización.**" | 他目的で採取された試料の研究利用には、**匿名化の有無にかかわらず**同意が必要 |

> **58(2) は §2 の議論に直接効く。**スペインでは「匿名化したから同意不要」が**条文で否定されている。**

⚠️ **訂正**: LOPDGDD 9条1項（同意だけでは解除できないカテゴリの列挙）に**遺伝データ・生体データ・健康データは含まれていない**。スペインの 9条4項行使は LOPDGDD 9条ではなく、追加規定第17 ＋ Ley 14/2007 にある。

#### フィンランド — EHDS の先行例

- **(a)** **Laki sosiaali- ja terveystietojen toissijaisesta käytöstä 552/2019**（Act on the Secondary Use of Health and Social Data）、**施行 2019-05-01**
- **(b)** https://www.finlex.fi/fi/lainsaadanto/ajantasainen/2019/552 ／ Findata https://findata.fi/en/services-and-instructions/legislation/
- **(d)** `[公式ガイダンス]`（⚠️ **Finlex の公式英訳は存在しない**。条文本体は Finlex が JavaScript 配信のため未取得。以下は Findata の公式説明による）
- **(c)**

> "The Secondary Use Act […] regulates how health and social data may be used outside their original purpose, for example in scientific research, statistics, and planning and reporting duty of an authority."

> "The Secondary Use Act is based on an **opt-out model**, meaning that data may be used for secondary purposes defined in law without notifying each individual separately. However, individuals have the right to prohibit the use of their data for secondary purposes under the […] GDPR."

| 上乗せ要件 | 状態 | 逐語 |
|---|---|---|
| Findata の許可 | ✅（2026年5月以降は一部が分散） | 下記 |
| 安全な処理環境 Kapseli® | ✅ | "Kapseli is a secure processing environment for the processing of data on individuals provided by Findata."（https://findata.fi/en/kapseli/、更新 2026-08-21） |
| 搬出できるのは**匿名**結果のみ | ✅ | "Under the Secondary Use Act, **results produced from disclosed data must be anonymous (Section 52)**. If a study requires exporting results that cannot be anonymised, this must be taken into account already at the planning stage."（https://findata.fi/en/services-and-instructions/producing-anonymous-results/、更新 2026-07-28） |

> **EHDS Art. 73 の secure processing environment と Art. 61(4) の「結果は匿名データのみ」は、フィンランドが 2019年に国内法で先行実装していたものと構造が一致する。**

**2026年の変化** — Laki … muuttamisesta, **1159/2025**（政府提案 HE 87/2025、https://www.finlex.fi/fi/lainsaadanto/saadoskokoelma/2025/1159 `[条文]`）:
- 臨床試験関係の改正は **2026-01-01**、その他は **2026-05-01** 施行
- **分散許可モデル**の導入 — 複数管理者のデータを含む許可を Findata 経由でも個別管理者からでも申請可能に
- **新設 51c 条** — データ許可にもとづく資料を**安全な外国の処理環境へ提供**できる。条件は、リスクが軽微であること、**フィンランドの研究組織が参加していること**、データ保護・安全性の水準が十分であること
- **2026-06-01** から匿名統計表に関する請求は THL へ移管。**個人レベル資料の許可申請は引き続き Findata**

→ **Findata は 2026年9月現在も稼働中**（正式名 Sosiaali- ja terveysalan tietolupaviranomainen）。廃止・統合ではなく権限の一部分散。

**批判的データ** `[学術]`（https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11443657/）: 2021年の2件の調査で、回答医師430名のうち **79% が許可手続は以前より複雑**と回答、55% がプロジェクト遅延、64% がコスト増。2020〜2023年にフィンランドの大学病院で承認されたデータ許可は**年あたり中央値 5.5% 減少**。

#### 【重要】EHDS が 9条4項の将来を変える

2029年3月26日（Chapter IV 適用開始）以降、加盟国は**遺伝・ゲノム・オミクス・バイオバンクデータについてのみ** 9条4項型の上乗せを継続できる（EHDS Art. 51(4)、Recital (52)。§5.6 参照）。

逆に言えば、**遺伝データ以外の一般的な健康データへの上乗せ**（スペインの再利用・仮名化要件、フィンランドの Findata 許可・Kapseli 要件、イタリア110条の倫理委員会要件）は、**EHDS 二次利用の射程内では維持できなくなる可能性がある。**

一方、**イタリア 2-septies 条6項の「遺伝データに限り同意を追加の保護措置として課しうる」という部分は、Art. 51(4) の例外に正面から収まる。**ゲノムを扱う限り、国別の上乗せは 2029年以降も残る。

---

## 2. 匿名化と偽名化 — 「匿名データしか扱わない」は抗弁になるか

### 2.0 結論を先に

規制当局の立場は**二層**になっている。単純な「ゲノムは本質的に識別可能だから絶対に匿名化できない」でも「単なる文脈次第」でもない。

```
┌─ 一般法の標準 ──────────────────────────────────┐
│ 匿名性は相対的・文脈依存                          │
│   GDPR Recital 26 →  Breyer C-582/14 (2016)       │
│                  →  EDPS v SRB C-413/23 P (2025)  │
│                  →  EDPB Guidelines 02/2026       │
└──────────────────┬───────────────────────────────┘
                   │ この標準をゲノムに当てはめると
                   ▼
┌─ 遺伝データへの当てはめ（当局の見解はほぼ一致）──┐
│ 「既定で個人データ。匿名たりうるのは例外的状況のみ」│
│   EDPB 2021 健康研究 Q&A Q18                      │
│   EDPB Guidelines 1/2026 §8.4 para 165            │
│   ドイツ DSK 2024（最も強い表現）                  │
│   ⇄ 英国 ICO はより許容的【食い違い】              │
└───────────────────────────────────────────────────┘
```

**「WGS（全ゲノム配列）は絶対に匿名化できない」と明文で断言した規制当局文書は、一つも見つからなかった。**最も強いドイツ DSK ですら "in der Regel"（原則として）と二度留保している。裏づけられる命題は次のとおり。

> **既定では個人データとして扱え。匿名性を主張するなら立証責任は主張者にあり、その立証は極めて重く、かつ継続的である。**

### 2.1 法の標準 — Recital 26

- **(a)** GDPR Recital 26
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32016R0679
- **(d)** `[条文]`
- **(c)** 逐語（全文）

> "The principles of data protection should apply to any information concerning an identified or identifiable natural person. Personal data which have undergone pseudonymisation, which could be attributed to a natural person by the use of additional information should be considered to be information on an identifiable natural person. To determine whether a natural person is identifiable, account should be taken of all the means reasonably likely to be used, such as singling out, either by the controller or by another person to identify the natural person directly or indirectly. To ascertain whether means are reasonably likely to be used to identify the natural person, account should be taken of all objective factors, such as the costs of and the amount of time required for identification, taking into consideration the available technology at the time of the processing and technological developments. The principles of data protection should therefore not apply to anonymous information, namely information which does not relate to an identified or identifiable natural person or to personal data rendered anonymous in such a manner that the data subject is not or no longer identifiable. This Regulation does not therefore concern the processing of such anonymous information, including for statistical or research purposes."

日本語の趣旨（要点のみ）: 仮名化された個人データは、追加情報を用いれば個人に帰属しうるものであり、識別可能な自然人に関する情報とみなされるべきである。識別可能性の判断にあたっては、管理者または**他の者**が用いる可能性が合理的にある全ての手段（単独抽出 singling out を含む）を考慮すべきである。その判断には費用・所要時間・処理時点で利用可能な技術および技術の進展といった客観的要素を考慮すべきである。

→ **「他の者」と「技術の進展」の二語が、ゲノムにおける匿名性主張を難しくしている。**

### 2.2 仮名化の定義 — Art. 4(5)

- **(a)** GDPR Article 4(5)
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32016R0679
- **(d)** `[条文]`
- **(c)**

> "'pseudonymisation' means the processing of personal data in such a manner that the personal data can no longer be attributed to a specific data subject without the use of additional information, provided that such additional information is kept separately and is subject to technical and organisational measures to ensure that the personal data are not attributed to an identified or identifiable natural person;"

**仮名化データは個人データである。**匿名化とは別物であり、GDPR の適用を外さない。

### 2.3 CJEU — Breyer, C-582/14（2016-10-19）

- **(a)** Judgment of 19 October 2016, *Patrick Breyer v Bundesrepublik Deutschland*, C-582/14, ECLI:EU:C:2016:779, paras 41, 43, 46
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX:62014CJ0582
- **(d)** `[条文]`（判例＝一次資料）
- **(c)**

> **41** "The use by the EU legislature of the word 'indirectly' suggests that, in order to treat information as personal data, it is not necessary that that information alone allows the data subject to be identified."

> **43** "In so far as that recital refers to the means likely reasonably to be used by both the controller and by 'any other person', its wording suggests that, for information to be treated as 'personal data' […] it is not required that all the information enabling the identification of the data subject must be in the hands of one person."

> **46** "[…] that would not be the case if the identification of the data subject was prohibited by law or practically impossible on account of the fact that it requires a disproportionate effort in terms of time, cost and man-power, so that the risk of identification appears in reality to be insignificant."

**ゲノムへの含意**: para 43 が決定的である。再識別に必要な参照データを**自分が持っていなくても**、誰かが合理的に持ちうるなら個人データになる。para 46 の「識別のリスクが現実には無視できる程度に見える」水準をゲノムで満たせるか、が争点の核心となる。

### 2.4 CJEU — EDPS v SRB, C-413/23 P（2025-09-04）**判決済み**

- **(a)** Judgment of 4 September 2025, *EDPS v SRB*, C-413/23 P, ECLI:EU:C:2025:645, paras 73, 75, 77, 80
- **(b)** 判決 https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX:62023CJ0413 ／ プレスリリース CP No 107/25 https://curia.europa.eu/site/upload/docs/application/pdf/2025-09/cp250107en.pdf
- **(d)** `[条文]`
- **(c)**

> **73** "[…] the concept of 'pseudonymisation' presupposes the existence of information enabling the data subject to be identified. The very existence of such information precludes data that have undergone pseudonymisation from being regarded, in all cases, as anonymous data […]"

> **77** "[…] that presupposes, first, that Deloitte is not in a position to lift those measures during any processing of the comments which is carried out under its control. Second, those measures must in fact be such as to prevent Deloitte from attributing those comments to the data subject including by recourse to other means of identification such as cross-checking with other factors, in such a way that, for the company, the person concerned is not or is no longer identifiable."

> **80** "[…] those clarifications relating to the assessment of whether or not the data subject is identifiable would be deprived of any practical effect if pseudonymised data were to be regarded as constituting, in all cases and for every person, personal data […]"

**判決の帰結**: 一般裁判所の判決を破棄・差戻し。仮名化データは「すべての場合・すべての者にとって」個人データとは限らない（相対的アプローチの確認）。ただし情報提供義務の文脈では、識別可能性は**収集時点・管理者の視点**で判断する。

⚠️ **射程の限定**: 本件は GDPR ではなく **Regulation (EU) 2018/1725**（EU 機関向け）の解釈である。条文構造がほぼ同一のため GDPR にも援用されるが、厳密には直接の GDPR 判例ではない。

### 2.5 Article 29 WP Opinion 05/2014（WP216）— 遺伝データの作例

- **(a)** Article 29 Data Protection Working Party, **Opinion 05/2014 on Anonymisation Techniques**, ref. 0829/14/EN, **WP216**, adopted **10 April 2014**. 遺伝データの EXAMPLE は §2.2.2, p.10
- **(b)** https://ec.europa.eu/justice/article-29/documentation/opinion-recommendation/files/2014/wp216_en.pdf
- **(d)** `[公式ガイダンス]`
- **(c)** EXAMPLE ボックス全文

> "Genetic data profiles are an example of personal data that can be at risk of identification if the sole technique used is the removal of the identity of the donor due to the unique nature of certain profiles. It has already been shown in the literature that the combination of publically available genetic resources (e.g. genealogy registers, obituary, results of search engine queries) and the metadata about DNA donors (time of donation, age, place of residence) can reveal the identity of certain individuals even if that DNA was donated 'anonymously'."

技術付属書 脚注 27（逐語）:

> "Genetic data are an especially significant example of sensitive data that can be at risk of re-identification if the sole mechanism to 'anonymize' them is the removal of donors' identities."

**WP216 の三基準**（後続文書がすべて引き継ぐ骨格）:

> "(i) is it still possible to single out an individual, (ii) is it still possible to link records relating to an individual, and (iii) can information be inferred concerning an individual?"

一般的立場（§2.2.2 結語）:

> "An effective anonymisation solution prevents all parties from singling out an individual in a dataset, from linking two records within a dataset (or between two separate datasets) and from inferring any information in such dataset. Generally speaking, therefore, removing directly identifying elements in itself is not enough to ensure that identification of the data subject is no longer possible."

### 2.6 【最重要】EDPB 健康研究 Q&A 第18問（2021-02-02）

**ゲノムの匿名化可能性を正面から問われた唯一の当局回答。**

- **(a)** EDPB, *Document on response to the request from the European Commission for clarifications on the consistent application of the GDPR, focusing on health research*, **adopted 2 February 2021**, §6, **Q18, paras 50–51**（および para 47）
- **(b)** https://www.edpb.europa.eu/sites/default/files/files/file1/edpb_replyec_questionnaireresearch_final.pdf
- **(d)** `[公式ガイダンス]`
- **(c)** 逐語（問と答の全文）

> **Q18.** "To what extent, if at all, can genetic data be considered anonymised where the controller carries out reasonable efforts and uses technically available means in order to prevent re-identification of the individuals?"

> **50.** "The EDPB points out that **the possibility to anonymise genetic data remains an unresolved issue**. As yet, it remains open to be demonstrated whether any combination of technical and organisational means can be effectively employed to remove genetic information from the material scope of the GDPR."

> **51.** "However, in the interests of protecting the rights and freedoms of individual data subjects, **it is strongly advised that such genetic data is treated as personal data** and that the processing thereof is conducted with the implementation of appropriate technical and organisational measures to ensure compliance with the Regulation."

para 47（匿名性の**継続的**立証責任）:

> "It should be taken into account that anonymisation of personal data can be difficult to achieve (and upheld) due also to ongoing advancements in available technological means, and progress made in the field of re-identification. […] Those parties which consider that they are using anonymous information in research should be in a position to satisfy themselves – and when questioned also the competent SA - **on an ongoing basis** that this continues to be the case, and that they have not inadvertently become data controllers of personal data […]"

日本語の趣旨: 遺伝データを匿名化できるかは**未解決の問題**である。技術的・組織的手段のいかなる組合せによって遺伝情報を GDPR の適用範囲から外せるかは、**いまだ示されていない**。データ主体の権利保護の観点から、遺伝データは個人データとして取扱うことを**強く推奨する**。

### 2.7 EDPB Guidelines 1/2026 §8.4（2026-04-15、意見募集版）

**現時点で最も新しい、遺伝データ名指しの当局見解。**

- **(a)** EDPB **Guidelines 1/2026 on processing of personal data for scientific research purposes**, version for public consultation, **adopted 15 April 2026**, §8.4, **para 165**（および 157, 167, 168）
- **(b)** https://www.edpb.europa.eu/system/files/2026-05/edpb_guidelines_202601_scientificresearch_en.pdf
- **(d)** `[公式ガイダンス]`（**意見募集版。最終版の採択は確認できず**）
- **(c)**

> **165.** "Genetic data is personal data retrieved from analysis of biological samples of human origin that is related to the inherited or acquired genetic characteristics of an individual, such as a complete genome sequence or certain genetic markers that are unique to an individual. **Genetic data profiles are considered to be personal data by default and can only be considered anonymous in exceptional circumstances, following a thorough analysis that takes the specific genetic configuration, and how common it is in the population, into account.**"

（脚注 243 は WP216 p.10 ＝ §2.5 の EXAMPLE を典拠としている）

> **157.** "Where the scientific research purposes cannot be fulfilled using anonymised data […] **or where anonymisation is not achievable**, the personal data should instead be pseudonymised."

> **167.** "Particular caution must be exercised in any research project where genetic or biometric data are processed. This is due to the specific nature and risks with such processing operations, not only for data subjects that participate in scientific research, **but also other data subjects who are related to the research participant.** […] The fact that genetic data cannot be changed by data subjects, but remains with them for the rest of their lives and beyond increases the risks."

> **168.** "Appropriate safeguards that may be particularly important when processing genetic or biometric data include, but are not limited to, **pseudonymisation, ethical approval, particularly restrictive purpose limitations, federated storage with access through secure processing environments, as well as rigid and role-based access controls.**"

日本語の趣旨（para 165）: 遺伝データプロファイルは**既定で個人データとみなされ**、匿名とみなしうるのは、**特定の遺伝的構成とそれが集団内でどれだけ一般的かを考慮した徹底的な分析**を経た**例外的状況**においてのみである。

**注目**: この文言は「決して匿名化できない」とは言っていない。**極めて狭い扉は開いている。**ただし扉を通るには集団頻度に基づく分析の提示が要る。

**para 168 は設計要求として読める** — 仮名化・倫理承認・厳格な目的限定・秘匿計算環境経由のアクセスを伴う分散保管・役割ベースのアクセス制御。EHDS の secure processing environment（§5.4）と同じ設計思想である。

### 2.8 EDPB Guidelines 02/2026 on Anonymisation（2026-07-07、意見募集中）

WP216 の後継。**遺伝データ専用の記述はない**が、プラットフォームの抗弁に直接効く条項がある。

- **(a)** EDPB **Guidelines 02/2026 on Anonymisation**, Version 1.0, **adopted 07 July 2026**（意見募集は 2026-10-30 まで）, paras 21, 22, 24, 38, 40, 82
- **(b)** https://www.edpb.europa.eu/system/files/2026-07/edpb_guidelines_202602_anonymisation_v1_en_0.pdf ／ 発表 https://www.edpb.europa.eu/news/edpb-sheds-light-on-anonymisation-and-web-scraping-for-generative-ai-and-adopts-final-version_en
- **(d)** `[公式ガイダンス]`（**意見募集版。未確定**）
- **(c)**

Executive summary:

> "Under the GDPR, data is anonymous if it does not relate to an identified or identifiable natural person. Whether this is the case may vary from one entity to another. Consequently, anonymity should be assessed from each relevant entity's perspective […] The framework itself presents three criteria which can be used to test if data is anonymous: **No Record Isolation, No Linkage and No Inference.** […] **Generally speaking, (re-) identification is more likely to be successful against record-level data with high dimensionality and high resolution**, but other factors are also important."

→ 「高次元・高解像度のレコード単位データ」は **WGS の定義そのもの**である。ゲノムを名指ししていないが、ゲノムに最も当てはまる記述になっている。

> **21.** "[…] if (a) it is reasonably likely that an entity can transfer the data to a third party, and (b) it cannot be ruled out that this receiving entity has the means to identify the individual through means reasonably likely to be used, the data should be considered personal for both that transfer and for any subsequent processing of the data by that recipient. Further, **this transfer means that the transferred information would also indirectly become personal for the transferring entity**, even if that entity would not otherwise have means reasonably likely to be used to identify the individuals in question."

**解析サービス提供者に直撃する条項。**解析結果を第三者（依頼元研究者）に渡す時点で、受領者が再識別手段を持たないと**断定できない**なら、渡す側にとっても個人データになる。

> **22.** "[…] for information to be anonymous, the likelihood of the individual being successfully distinguished from others within the given context does not need to be zero; instead, that likelihood should be **insignificant in reality**."

> **38.** "The principles of data protection apply whenever personal data is processed, which includes processing operations carried out to obtain anonymous information. This means, amongst other things, that **anonymisation must have a legal basis under Article 6 GDPR, and that one of the exemptions under Article 9(2) GDPR should apply** if the dataset contains special category personal data."

**匿名化それ自体が処理行為である。**「匿名データしか扱わない」と言っても、匿名化するまでの工程は GDPR 下にあり、遺伝データなら Art. 9(2) の解除事由が要る。

> **40.** "[…] controllers **should not use descriptions like 'anonymous', 'de-identified' or 'de-personalised' if individuals are actually still identifiable.**"

> **82.** "This would, in particular, be the case for AI models or synthetic data. Specific inferences can be made by querying (or, in the case of AI models, **prompting**) the given data with additional information to elicit new information about a particular individual. Where such an inference is also meaningful, this would be a violation of the No Inference criterion."

⚠️ **遺伝データの扱いの欠落**: 本ガイドライン全文で "genetic" のヒットは属性列挙（para 24）1箇所のみ、"genome"・"DNA" は 0 件。**ゲノム固有の当局見解は依然として §2.6・§2.7 に依存する。**

### 2.9 AEPD–EDPS「匿名化に関する10の誤解」

- **(a)** AEPD–EDPS, *10 Misunderstandings Related to Anonymisation*（2021-04-27）
- **(b)** https://www.edps.europa.eu/system/files/2021-04/21-04-27_aepd-edps_anonymisation_en_5.pdf
- **(d)** `[公式ガイダンス]`
- **(c)**

> "**MISUNDERSTANDING 3.** 'Anonymisation of data is always possible' — Fact: It is not always possible to lower the re-identification risk below a previously defined threshold whilst retaining a useful dataset for a specific processing."

> "**MISUNDERSTANDING 4.** 'Anonymisation is forever' — Fact: There is a risk that some anonymisation processes could be reverted in the future. Circumstances might change over time and new technical developments and the availability of additional information might compromise previous anonymisation processes."

> "**MISUNDERSTANDING 6.** […] Except for specific cases where data is highly generalised […] **the re-identification risk is never zero.**"

⚠️ 本文書も遺伝データを名指ししていない。

### 2.10 各国 DPA — 当局間で最も温度差が大きい箇所

#### ドイツ DSK（最も制限的）

- **(a)** Konferenz der unabhängigen Datenschutzaufsichtsbehörden des Bundes und der Länder, **Beschluss vom 15. Mai 2024 — Positionspapier: Anforderungen an die Sekundärnutzung von genetischen Daten zu Forschungszwecken**, §I
- **(b)** https://www.datenschutzkonferenz-online.de/media/dskb/2024-05-15_DSK-Beschluss_Genetische-Daten.pdf
- **(d)** `[公式ガイダンス]`
- **(c)** 逐語（ドイツ語原文）

> "In diesem Zusammenhang muss zudem berücksichtigt werden, dass **eine wirksame Anonymisierung genetischer Daten in der Regel daran scheitert, dass – etwa über einen Abgleich mit anderen genetischen Daten der betroffenen Person – eine Identifizierung möglich ist. Der Personenbezug lässt sich daher aus genetischen Daten in der Regel nicht entfernen. Genetische Daten sind deshalb schon aufgrund ihres potentiellen Informationsgehalts regelmäßig als personenbezogene Daten zu behandeln.**"

日本語の趣旨: 遺伝データの実効的な匿名化は、本人の他の遺伝データとの照合などによって識別が可能であるため、**通常は失敗する**。したがって遺伝データから個人との結びつきを取り除くことは通常できない。遺伝データは、その潜在的な情報内容だけを理由としても、**常に個人データとして扱われるべき**である。

→ 当局のなかで最も断定的。**それでも "in der Regel"（原則として）という留保が二度置かれている。**絶対的不可能性の主張ではない。

#### 英国 ICO（最も許容的）

- **(a)** ICO, *What is special category data?* — "What is genetic data?"（UK GDPR guidance）
- **(b)** https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/
- **(d)** `[公式ガイダンス]`（**UK は EU 離脱後。EU 法の解釈ではない**）
- **(c)**

> "So, in practice, **genetic analysis which includes enough genetic markers to be unique to an individual is personal data and special category genetic data, even if you have removed other names or identifiers.** And any genetic test results which are linked to a specific biological sample are usually personal data […]"

> "**However, there are cases where genetic information is not identifiable personal data. For example, where you have anonymised or aggregated partial genetic sequences or genetic test results (eg for statistical or research purposes), and they can no longer be linked back to a specific genetic identity, sample or profile; a patient record; or to any other identifier.**"

> "A genetic sample itself is not personal data until you analyse it to produce some data."

> **【食い違い】** ICO は「部分配列・集計結果の匿名化は匿名たりうる」と**明示的に認める**。DSK は「通常は匿名化に失敗する」。EDPB は「未解決／既定で個人データ、例外的状況のみ」。**ICO が最も許容的、DSK が最も制限的。**UK は EU 離脱後の独自路線である点に注意。EU 向けの主張に ICO を援用するのは危うい。

#### フランス CNIL

CNIL 独自の遺伝データ匿名化に関する公式見解は **確認できず**。CNIL は WP216 のフランス語版をホストしており（https://www.cnil.fr/sites/default/files/atoms/files/wp216_fr.pdf）、§2.5 の立場を引き継いでいると読めるが、独立した見解文書は見つからなかった。

### 2.11 EDPB–EDPS Joint Opinion 03/2022（EHDS）— 混合データセット

- **(a)** EDPB-EDPS **Joint Opinion 03/2022** on the Proposal for a Regulation on the European Health Data Space, adopted **12 July 2022**, para 41
- **(b)** https://www.edps.europa.eu/system/files/2022-07/22-07-12_edpb_edps_joint-opinion_europeanhealthdataspace_en_.pdf
- **(d)** `[公式ガイダンス]`
- **(c)**

> **41.** "[…] **the distinction between categories of personal and non-personal data is difficult to apply in practice.** Indeed, from a combination of non-personal data it is possible to infer or generate personal data […] **especially when non-personal data are the result of the anonymisation of personal data and even more in the context of processing of health data.** […] the EDPB and the EDPS […] recommend to make more explicit that **in case of mixed datasets (whereby personal and non-personal data are 'inextricably linked') the protections of the GDPR and the Proposal concerning personal electronic health data shall be applicable.**"

### 2.12 規制当局が依拠する再識別文献

当局文書が**実際に引用した**ものと、分野の定番を区別して記す。

| # | 文献 | DOI / URL | 当局による参照 | 種別 |
|---|---|---|---|---|
| 1 | Bohannon J. "Genealogy Databases Enable Naming of Anonymous DNA Donors." *Science* **339**(6117), 18 Jan 2013, p.262 | https://doi.org/10.1126/science.339.6117.262 | **WP216 脚注 8・27 が明示的に引用**（当局が実際に依拠した唯一の文献） | `[学術]` |
| 2 | Gymrek M, McGuire AL, Golan D, Halperin E, Erlich Y. "Identifying personal genomes by surname inference." *Science* **339**(6117):321–324, 18 Jan 2013 | doi:10.1126/science.1229566 / PMID 23329047 | 上記 Bohannon の News 記事の対象論文 ＝ WP216 が実質的に指す研究 | `[学術]` |
| 3 | Homer N, et al. "Resolving individuals contributing trace amounts of DNA to highly complex mixtures using high-density SNP genotyping microarrays." *PLoS Genetics* **4**(8):e1000167, 29 Aug 2008 | doi:10.1371/journal.pgen.1000167 / PMID 18769715 | NIH が dbGaP の集計統計を unrestricted → controlled access に移した直接の契機 | `[学術]` |
| 4 | Erlich Y, Narayanan A. "Routes for breaching and protecting genetic privacy." *Nature Reviews Genetics* **15**(6):409–421, Jun 2014 | doi:10.1038/nrg3723 / PMID 24805122（正誤表 doi:10.1038/nrg3777） | 分野の総説 | `[学術]` |
| 5 | Rocher L, Hendrickx JM, de Montjoye Y-A. "Estimating the success of re-identifications in incomplete datasets using generative models." *Nature Communications* **10**:3069, 23 Jul 2019 | doi:10.1038/s41467-019-10933-3 / PMID 31337762 | **AEPD–EDPS「10の誤解」脚注 8 が引用** | `[学術]` |
| 6 | Lippert C, et al. (Venter JC) "Identification of individuals by trait prediction using whole-genome sequencing data." *PNAS* **114**(38):10166–10171, 19 Sep 2017 | doi:10.1073/pnas.1711125114 / PMID 28874526 | **⚠️ 論争あり** — Erlich の反論プレプリント "Major flaws in…" (bioRxiv doi:10.1101/185330) が手法の有効性を否定。**引用するなら反論の存在を併記すること** | `[学術]` |

逐語（当局が引いた含意部分）:

> Homer et al. 2008: "These findings also suggest that **composite statistics across cohorts, such as allele frequency or genotype counts, do not mask identity within genome-wide association studies.**"

> Gymrek et al. 2013: "[…] we report that **surnames can be recovered from personal genomes by profiling short tandem repeats on the Y chromosome (Y-STRs) and querying recreational genetic genealogy databases.** […] **A key feature of this technique is that it entirely relies on free, publicly accessible Internet resources.**"

### 2.13 「匿名データしか扱わない」は抗弁になるか — 積み上げ

| # | 段 | 根拠 |
|---|---|---|
| 1 | EDPB は遺伝データの匿名化可能性を「**未解決**」「可能であることは**まだ示されていない**」とし、個人データとして扱うことを strongly advised としている | §2.6 |
| 2 | 最新ガイドラインは遺伝データプロファイルを「**既定で個人データ**、匿名たりうるのは集団頻度を踏まえた徹底的分析後の**例外的状況**のみ」とする | §2.7 |
| 3 | 第三者に渡す可能性があり、受領者に識別手段がないと**断定できない**なら、**渡す側にとっても**個人データになる | §2.8 para 21 |
| 4 | **匿名化それ自体が処理行為**であり、Art. 6 の根拠と Art. 9(2) の解除事由が要る。「匿名しか扱わない」は入口の処理を説明しない | §2.8 para 38 |
| 5 | 匿名性は**継続的に**立証し続けられる必要がある（技術の進展により覆りうる） | §2.6 para 47 / §2.9 誤解4 |

**扉が開いている狭い条件**（各当局が残した例外）:
- ICO: 部分配列・集計結果を匿名化・集約し、遺伝的同一性・検体・患者記録・その他の識別子に**もはや遡れない**場合（§2.10）
- EDPB: 特定の遺伝的構成と**集団内頻度**を踏まえた徹底的分析を経た**例外的状況**（§2.7）
- GA4GH（専門団体 `[二次解説]`、2018-10-10、Mark Phillips, https://www.ga4gh.org/news_item/can-genomic-data-be-anonymised/ ）: 腫瘍固有変異のような例を挙げつつ "researchers should never assume that genomic data are anonymous"

⚠️ **正直な不確実性**: 「WGS は絶対に匿名化できない」と明文で断言した規制当局文書は**一つも見つかっていない**。したがって「規制上、ゲノムは本質的に識別可能で決して匿名化できない」という命題は、**当局の文言としては裏づけられない**。裏づけられるのは §2.0 に置いた命題である。

---

## 3. AI Act の特別カテゴリ例外 — 【重要】Art. 10(5) は削除され Art. 4a になった

### 3.1 何が起きたか

```
2024-08-01  AI Act (Reg. (EU) 2024/1689) 発効
              └ Article 10(5)：high-risk の provider のみ、偏り検知のため
                特別カテゴリを例外的に処理できる。条件 (a)–(f) の6つ
                  ▲ Recital 70 が「Art. 9(2)(g) GDPR の実質的公益」と位置づけ

2025-11-19  委員会が Digital Omnibus 提案（COM(2025) 837）を公表
              └ 二本に分岐

2026-06-16  議会可決 ─┐
2026-06-29  理事会採択 ┤ AI 側
2026-07-08  署名       │
2026-07-24  官報掲載   │  Regulation (EU) 2026/1744
2026-07-27  発効 ──────┘  （Digital Omnibus on AI）
              ├ Article 10(5) を【削除】
              ├ 新 Article 4a を【新設】＝ 中身はほぼ同じ、条件 (a)–(f) 維持
              ├ 対象を high-risk 以外の provider / deployer にも拡大（新 4a(2)）
              └ Article 2(7) の参照を「Art. 10(5)」→「Articles 4a」に差替え

2026-09-13  GDPR 側（個人データ定義、Art.9 新例外、科学研究の定義）は
            【提案のまま・未成立】。GDPR は現行どおり読む
```

### 3.2 改正規則の同定

- **(a)** Regulation (EU) 2026/1744 of the European Parliament and of the Council of **8 July 2026** amending Regulations (EU) 2024/1689, (EU) 2018/1139 and (EU) 2023/1230 as regards the simplification of the implementation of harmonised rules on artificial intelligence (**Digital Omnibus on AI**)
- **(b)** https://eur-lex.europa.eu/eli/reg/2026/1744/oj/eng ／ 官報 HTML https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202601744
- **(d)** `[条文]`
- 官報掲載 **2026-07-24**、発効 **2026-07-27**（掲載の3日後。AI Act の 2026-08-02 期限に間に合わせる緊急扱い）
- 手続: 議会の立場 2026-06-16、理事会決定 2026-06-29。ファイル参照 PE/30/2026/REV/1

### 3.3 旧 Article 10(5)（削除済み。歴史的参照としてのみ）

- **(a)** Regulation (EU) 2024/1689, Article 10(5) — **Regulation (EU) 2026/1744 により削除**
- **(b)** https://artificialintelligenceact.eu/article/10/ （改正前後を併記）／ https://www.euaiact.com/article/10 （"Point deleted by Regulation (EU) 2026/1744" と注記）
- **(d)** `[条文]`
- **(c)** 柱書

> "To the extent that it is strictly necessary for the purpose of ensuring bias detection and correction in relation to the high-risk AI systems in accordance with paragraph (2), points (f) and (g) of this Article, the providers of such systems may exceptionally process special categories of personal data, subject to appropriate safeguards for the fundamental rights and freedoms of natural persons."

### 3.4 【現行】Article 4a — 逐語

- **(a)** Regulation (EU) 2024/1689, **Article 4a**（Regulation (EU) 2026/1744 により新設）
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202601744 ／ 統合表示 https://www.euaiact.com/article/4a
- **(d)** `[条文]`

**第1項 柱書（逐語）**

> "To the extent strictly necessary to ensure bias detection and correction in relation to high-risk AI systems in accordance with Article 10(2), points (f) and (g), of this Regulation, providers of such systems may exceptionally process special categories of personal data, subject to appropriate safeguards for the fundamental rights and freedoms of natural persons."

日本語の趣旨: Art. 10(2)(f)(g) に従った high-risk AI システムの偏りの検知と是正を確保するために**厳格に必要な限度において**、当該システムの提供者は、自然人の基本的権利と自由に対する適切な保護措置を条件として、特別カテゴリの個人データを**例外的に**取扱うことができる。

**条件 (a)–(f)（逐語）** — 依頼書は「五つの条件」とあったが、**実際は六つ**である。GDPR・EUDPR・法執行指令の規定に**加えて**、以下の**すべて**を満たす必要がある（累積要件）。

> **(a)** "the bias detection and correction cannot be effectively fulfilled by processing other data, including synthetic or anonymised data"

> **(b)** "the special categories of personal data are subject to technical limitations on the re-use of personal data, and state-of-the-art security and privacy-preserving measures"

> **(c)** "the special categories of personal data are subject to measures to ensure that the personal data processed are secured and protected, subject to suitable safeguards, including strict controls and documentation"

> **(d)** "the special categories of personal data are not transmitted, transferred or otherwise accessed by other parties"

> **(e)** "the special categories of personal data are deleted once the bias has been corrected or the personal data has reached the end of its retention period, whichever comes first"

> **(f)** "the records of processing activities pursuant to Regulations (EU) 2016/679 and (EU) 2018/1725 and Directive (EU) 2016/680 include the reasons why the processing of special categories of personal data was strictly necessary to detect and correct biases, and why that objective could not be achieved by processing other data"

日本語の趣旨:
| 号 | 中身 |
|---|---|
| (a) | 合成データや匿名データを含む**他のデータでは実効的に達成できない**こと（匿名化・合成データの優先） |
| (b) | 再利用に対する技術的制限と、最新水準の安全性・プライバシー保護措置（仮名化を含む）に服すること |
| (c) | 厳格なアクセス制御と文書化を含む、保護と安全確保の措置に服すること |
| (d) | **他の当事者に送信・移転されず、アクセスもされない**こと |
| (e) | 偏りが是正された時点、または保存期間の終了時点のいずれか早い方で**削除**されること |
| (f) | 処理活動の記録に、なぜ厳格に必要だったか、なぜ他のデータでは達成できなかったかの**理由を記載**すること |

**第2項（逐語、全文）** — Digital Omnibus による拡大部分

> "Providers and deployers of other AI systems and models and deployers of high-risk AI systems may exceptionally process special categories of personal data to the extent that: (a) such processing is strictly necessary to ensure bias detection and correction in view of possible biases that are likely to affect the health and safety of persons, have a negative impact on fundamental rights or lead to discrimination prohibited pursuant to Union law, especially where data outputs influence inputs for future operations; and (b) all of the conditions and safeguards set out in paragraph 1 are applied. **This paragraph does not create any obligation to conduct such bias detection and correction.**"

日本語の趣旨: **その他の AI システム・モデルの提供者および導入者**、ならびに high-risk AI システムの**導入者**もまた、(a) 人の健康と安全に影響し、基本的権利に悪影響を与え、または EU 法上禁止される差別をもたらす恐れのある偏りの検知・是正のために厳格に必要であり、とりわけ出力が将来の動作の入力に影響する場合であって、(b) 第1項のすべての条件と保護措置が適用される限度において、特別カテゴリの個人データを例外的に取扱うことができる。**本項は偏りの検知・是正を行う義務を創設するものではない。**

### 3.5 改正の趣旨 — Regulation (EU) 2026/1744 Recital 9

- **(a)** Regulation (EU) 2026/1744, Recital 9
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202601744
- **(d)** `[条文]`
- **(c)** 冒頭（逐語で取得できた範囲）

> "Bias detection and correction constitute a substantial public interest because they protect natural persons from the adverse effects of bi[as]…"

⚠️ **全文は未取得（確認できず）**。取得できた要旨: 旧 Art. 10(5) は high-risk のみを対象としていたが、偏りは導入者の行為からも、high-risk でないシステムからも生じうるため、新 Art. 4a によって提供者・導入者の双方に拡大する。**"substantial public interest"（実質的公益）の位置づけは維持されている**（§3.6 の Art. 9(2)(g) GDPR との接続が改正後も生きる根拠）。

### 3.6 【核心】これは GDPR の置き換えではない — Recital 70

- **(a)** Regulation (EU) 2024/1689, **Recital 70**（Digital Omnibus による改正は**確認されず**）
- **(b)** https://artificialintelligenceact.eu/recital/70/
- **(d)** `[条文]`
- **(c)** 逐語（全文）

> "In order to protect the right of others from the discrimination that might result from the bias in AI systems, the providers should, exceptionally, to the extent that it is strictly necessary for the purpose of ensuring bias detection and correction in relation to the high-risk AI systems, subject to appropriate safeguards for the fundamental rights and freedoms of natural persons and following the application of all applicable conditions laid down under this Regulation **in addition to** the conditions laid down in Regulations (EU) 2016/679 and (EU) 2018/1725 and Directive (EU) 2016/680, be able to process also special categories of personal data **as a matter of substantial public interest within the meaning of Article 9(2), point (g) of Regulation (EU) 2016/679** and Article 10(2), point (g) of Regulation (EU) 2018/1725."

日本語の趣旨: AI システムの偏りから生じうる差別から他者の権利を保護するため、提供者は、high-risk AI システムの偏りの検知・是正を確保するために厳格に必要な限度で、基本的権利と自由への適切な保護措置を条件とし、本規則の全条件を GDPR 等の条件に**加えて**適用したうえで、**GDPR 第9条2項(g)にいう実質的公益の問題として**、特別カテゴリの個人データを取扱うことができるべきである。

### 3.7 法的根拠をめぐる論争 — **未決**

**AI Act の偏り検知例外は、それ自体で GDPR Art. 9 の禁止を解除するのか。**

| 読み方 | 主張 | 帰結 |
|---|---|---|
| **自立的例外説** | AI Act が Art. 9 の禁止から明示的に免除を与えている | AI Act の条件を満たせば処理してよい |
| **従属的逸脱説**（より慎重・優勢） | AI Act は独立した GDPR 上の適法根拠を作らない。Recital 70 が示すとおり **Art. 9(2)(g)（実質的公益）を作動させる**依存的逸脱である | Art. 9(2)(g) の要件（EU 法または加盟国法に基づくこと、必要かつ比例的であること、適切な保護措置）を**別途**満たす必要がある |

- **(a)** European Parliamentary Research Service, *Algorithmic discrimination under the AI Act and the GDPR*（2025）
- **(b)** https://www.europarl.europa.eu/RegData/etudes/ATAG/2025/769509/EPRS_ATA(2025)769509_EN.pdf
- **(d)** `[公式ガイダンス]`（議会調査局。立法機関の付属機関だが拘束力はない）
- 内容: AI Act の特別カテゴリ処理条項の解釈について**共有された不確実性が続いている**こと、GDPR の制限が制約的に働きうることを指摘。

- **(a)** Engelfriet A., *Permitted by Design? Article 10(5) AIA, Sensitive Data, and the Legal Illusion of Bias Correction*（SSRN）
- **(b)** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5332461
- **(d)** `[学術]`

- **(a)** *Using sensitive data to de-bias AI systems: Article 10(5) of the EU AI act*, Computer Law & Security Review
- **(b)** https://www.sciencedirect.com/science/article/pii/S026736492500010X
- **(d)** `[学術]`

⚠️ **リサイタルは法的拘束力を持たない。**Recital 70 が Art. 9(2)(g) を指していることは解釈の手がかりであって、自動的な適法根拠の付与ではない。**この論点は未決のまま記録する。**

### 3.8 ゲノムプラットフォームにとっての実務的含意

- 条件 (a) が「合成・匿名データを優先せよ」と定める。ゲノムでは §2 のとおり匿名化が困難なので、**(a) は満たしやすい一方、その理由づけ自体が「匿名化できない」という自認になる**。
- 条件 (d)「他の当事者に送信・移転されず、アクセスもされない」は、**解析サービスとして第三者に結果を返す形態と正面から衝突しうる**。偏り検知のために処理した特別カテゴリデータは、外に出せない。
- 第2項の拡大により、**high-risk に該当しない場合でも**この経路は使える。ただし条件はすべて同じ。
- **義務ではない**（第2項末文）。偏り検知のために遺伝データを集めよ、という要求ではない。

---

## 4. AI Act と GDPR の関係 — 並行適用

### 4.1 条文 — Article 2(7)（改正後）

- **(a)** Regulation (EU) 2024/1689, **Article 2(7)**（Regulation (EU) 2026/1744 により改正）
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202601744
- **(d)** `[条文]`
- **(c)** 改正後（逐語）

> "Union law on the protection of personal data, privacy and the confidentiality of communications applies to personal data processed in connection with the rights and obligations laid down in this Regulation. **Without prejudice to Articles 4a and 59 of this Regulation, this Regulation shall not affect Regulation (EU) 2016/679 or (EU) 2018/1725, or Directive 2002/58/EC or (EU) 2016/680.**"

改正前（2024年原文、逐語）:

> "Union law on the protection of personal data, privacy and the confidentiality of communications applies to personal data processed in connection with the rights and obligations laid down in this Regulation. This Regulation shall not affect Regulation (EU) 2016/679 or (EU) 2018/1725, or Directive 2002/58/EC or (EU) 2016/680, **without prejudice to Article 10(5) and Article 59 of this Regulation.**"

日本語の趣旨: 個人データ保護・プライバシー・通信の秘密に関する EU 法は、本規則が定める権利義務に関連して取扱われる個人データに適用される。本規則の Art. 4a および Art. 59 を妨げることなく、本規則は GDPR、EUDPR、ePrivacy 指令、法執行指令に**影響を及ぼさない**。

> **【食い違い・解決済み】** artificialintelligenceact.eu の改正前後の表示では、改正の向きが逆に読める記述があった。しかし**新設された Art. 4a を旧条文が参照できるはずがない**という論理、および官報（Regulation (EU) 2026/1744）の改正条項本文から、上記の向き（旧「Article 10(5)」→ 新「Articles 4a」）が正しい。官報が優先する。

### 4.2 日本語での意味

**二つの規則は並行して適用される。片方を守っても、もう片方を守ったことにはならない。**

```
    ゲノム解析プラットフォームの一つの処理行為
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
   ┌─────────┐            ┌──────────┐
   │  GDPR   │            │  AI Act  │
   ├─────────┤            ├──────────┤
   │Art.6 根拠│            │リスク分類 │
   │ ＋      │            │ ＋       │
   │Art.9(2) │            │該当義務   │
   │ 解除事由 │            │(provider/ │
   │ ＋      │            │ deployer) │
   │Art.89   │            │          │
   │ 保護措置 │            │          │
   └─────────┘            └──────────┘
        │                       │
        └───────────┬───────────┘
                    ▼
        両方を独立に満たす必要がある
        （AI Act 適合宣言は GDPR 適合の証明にならない）
```

要点:
- AI Act は GDPR に**影響を及ぼさない**（without prejudice）。したがって AI Act の条件を満たしても、GDPR の Art. 6 根拠と Art. 9(2) 解除事由は**別途**必要である。
- **例外は二箇所だけ** — Art. 4a（偏り検知）と Art. 59（規制サンドボックスにおける目的外利用）。この二つに限り、AI Act が GDPR の規律に切り込む。
- 逆向きも成り立つ。GDPR を完全に守っていても、AI Act の分類・文書化・適合性評価の義務は消えない。

### 4.3 EDPB Opinion 28/2024 — AI モデル自体が個人データを含みうるか

**依頼書の理解（「モデルは自動的に匿名ではない、個別評価が必要」）は正確である。**

- **(a)** EDPB **Opinion 28/2024** on certain data protection aspects related to the processing of personal data in the context of AI models
- **(b)** 文書ページ https://www.edpb.europa.eu/our-work-tools/our-documents/opinion-board-art-64/opinion-282024-certain-data-protection-aspects_en ／ PDF https://www.edpb.europa.eu/system/files/documents/2024-12/edpb_opinion_202428_ai-models_en.pdf
- **(d)** `[公式ガイダンス]`
- 法的根拠: GDPR **Art. 64(2)**。要請者: **アイルランド監督機関（Data Protection Commission）**、2024年9月4日付。分量 35 ページ、para 1–136。署名 Chair, Anu Talus。
- **【食い違い】採択日**: PDF 表紙は "Adopted on 17 December 2024"、EDPB サイトのメタデータと報道発表は **18 December 2024**。EDPB による説明は**確認できず**。引用時は「2024年12月採択（文書表紙は17日、サイトは18日）」と書くのが安全。

**問われた4問（para 4、逐語）**

> **Question 1:** "Is the final AI Model, which has been trained using personal data, in all cases, considered not to meet the definition of personal data (as set out in Article 4(1) GDPR)?"

> **Question 2:** "Where a data controller is relying on legitimate interests as a legal basis for personal data processing to create, update and/or develop an AI Model, how should that controller demonstrate the appropriateness of legitimate interests as a legal basis […]"

> **Question 4:** "If an AI Model has been found to have been created, updated or developed using unlawfully processed personal data, what is the impact of this, if any, on the lawfulness of the continued or subsequent processing or operation of the AI model […]"

**設計上そもそも匿名でありえないモデル（para 29、逐語）**

> "However, some AI models are specifically designed to provide personal data regarding individuals whose personal data were used to train the model, or in some way to make such data available. In these cases, such AI models will inherently (and typically necessarily) include information relating to an identified or identifiable natural person, and so will involve the processing of personal data. **Therefore, these types of AI models cannot be considered anonymous.**"

**パラメータへの「吸収」（para 31、逐語）**

> "[…] even when an AI model has not been intentionally designed to produce information relating to an identified or identifiable natural person from the training data, **information from the training dataset, including personal data, may still remain 'absorbed' in the parameters of the model, namely represented through mathematical objects.** They may differ from the original training data points, but may still retain the original information of those data, which may ultimately be extractable or otherwise obtained, directly or indirectly, from the model. Whenever information relating to identified or identifiable individuals whose personal data was used to train the model may be obtained from an AI model with means reasonably likely to be used, **it may be concluded that such a model is not anonymous.**"

**【核心の結論】（para 34、逐語）**

> "Based on the above considerations, the EDPB considers that **AI models trained on personal data cannot, in all cases, be considered anonymous. Instead, the determination of whether an AI model is anonymous should be assessed, based on specific criteria, on a case-by-case basis.**"

日本語の趣旨: 個人データで学習された AI モデルは、**すべての場合において匿名とみなすことはできない**。モデルが匿名であるかの判断は、特定の基準に基づき、**個別に**評価されるべきである。

**監督機関が最低限確認すべき2点（para 38、逐語）**

> "[…] for a SA to agree with the controller that a given AI model may be considered anonymous, it should check at least whether it has received sufficient evidence that, with reasonable means: **(i) personal data, related to the training data, cannot be extracted out of the model; and (ii) any output produced when querying the model does not relate to the data subjects whose personal data was used to train the model.**"

**二つの「無視できる程度」要件（para 43、逐語）**

> "[…] for an AI model to be considered anonymous, using reasonable means, both **(i) the likelihood of direct (including probabilistic) extraction of personal data regarding individuals whose personal data were used to train the model; as well as (ii) the likelihood of obtaining, intentionally or not, such personal data from queries, should be insignificant for any data subject.** By default, SAs should consider that AI models are likely to require a thorough evaluation of the likelihood of identification […]"

（脚注 37 で *Breyer* C-582/14 para 46 と *OC v European Commission* C-479/22 P para 51 を引用 ← §2.3 と直結）

**説明責任違反の認定（para 57、逐語）**

> "if a SA is not able to confirm, after assessing the claim of anonymity, including in light of the documentation, that effective measures were taken to anonymise the AI model, **the SA would be in a position to consider that the controller has failed to meet its accountability obligations under Article 5(2) GDPR.**"

**攻撃耐性テストの例示（para 55、逐語）**

> "this could include, among others, structured testing against: (i) attribute and membership inference; (ii) exfiltration; (iii) regurgitation of training data; (iv) model inversion; or (v) reconstruction attacks."

### 4.4 Opinion 28/2024 — 正当な利益の三段階テスト

土台は **Guidelines 1/2024 on Article 6(1)(f) GDPR, v1.0, adopted 8 October 2024**（para 59、脚注 50–53）。

**三つの累積要件（para 66、逐語）**

> "[…] SAs should verify that controllers have carefully assessed and documented whether the three following cumulative conditions are met: **(i) the pursuit of a legitimate interest by the controller or by a third party; (ii) the processing is necessary to pursue the legitimate interest; and (iii) the legitimate interest is not overridden by the interests or fundamental rights and freedoms of the data subjects.**"

**第1段（para 68、逐語）**

> "an interest may be regarded as legitimate if the following three cumulative criteria are met: a. The interest is lawful; b. The interest is clearly and precisely articulated; and c. The interest is real and present, not speculative."

**第2段 — 必要性（para 72–73、逐語）**

> **72.** "The assessment of necessity therefore entails two elements: (i) whether the processing activity will allow the pursuit of the purpose; and (ii) whether there is no less intrusive way of pursuing this purpose."

> **73.** "**If the pursuit of the purpose is also possible through an AI model that does not entail processing of personal data, then processing personal data should be considered as not necessary.** This is particularly relevant for the development of AI models."

→ **ゲノム基盤に最も効く一文。**個人データを含まない形で目的を達成できるなら、個人データの処理は「必要」ではない。

**緩和措置の位置づけ（Executive Summary、逐語）**

> "**Mitigating measures should not be confused with the measures that the controller is legally required to adopt anyway to ensure compliance with the GDPR.**"

**異議権（para 65、逐語）**: "the right to object under Article 21 GDPR applies and should be ensured"

⚠️ **ただし注意** — 遺伝データは特別カテゴリなので、**正当な利益（Art. 6(1)(f)）だけでは足りない。**Art. 9(2) の解除事由が別途必要である（§1.3）。Opinion 28/2024 の正当な利益論は Art. 6 の層の話であり、Art. 9 の層を解決しない。

### 4.5 Opinion 28/2024 — 違法な学習データの帰結（3シナリオ）

**是正措置の射程（para 114、逐語）**

> "These may include, for instance, issuing a fine, imposing a temporary limitation on the processing, erasing part of the dataset that was processed unlawfully or, where this is not possible, depending on the facts at hand, having regard to the proportionality of the measure, **ordering the erasure of the whole dataset used to develop the AI model and/or the AI model itself.**"

| シナリオ | 状況 | 結論 |
|---|---|---|
| **1**（para 119–123） | 個人データがモデルに残存し、**同一管理者**が後続処理 | 個別判断。"**the unlawfulness of the processing in the development phase may impact the lawfulness of the subsequent processing**"（para 123） |
| **2**（para 124–132） | 個人データが残存し、**別の管理者**が展開 | 導入者にデューデリジェンス義務。データの出所と、GDPR 違反の産物でないかを評価したかを監督機関が考慮（para 129） |
| **3**（para 133–135） | 展開前にモデルを匿名化 | GDPR 不適用となりうる。ただし下記 |

**シナリオ2 の AI Act 接点（para 131、逐語）** — 最重要

> "The EDPB notes that the AI Act requires providers of high-risk AI systems to draw up an EU declaration of conformity, and that such declaration contains a statement that the relevant AI system complies with EU data protection laws. The EDPB notes that **such a self-declaration may not constitute a conclusive finding of compliance under the GDPR.** It may nonetheless be taken into account by the SAs when investigating a specific AI model."

→ **§4.2 の並行適用を具体化した一文。**AI Act の適合宣言は GDPR 適合の決定的証明にならない。

**シナリオ3（para 134、逐語）** — 「匿名だから GDPR 外」への直接の回答

> "If it can be demonstrated that the subsequent operation of the AI model does not entail the processing of personal data, the EDPB considers that the GDPR would not apply. […] However, **the EDPB emphasises that a mere assertion of anonymity of the model is not enough to exempt it from the application of the GDPR**, and notes that SAs should assess it taking into account, on a case-by-case basis, the considerations provided by the EDPB to address Question 1 of the Request."

### 4.6 AI Act × GDPR 統合ガイドライン — **未公表**

EDPB と欧州委員会が共同ガイドラインを準備中であることは公式に確認できるが、**2026-09-13 時点で未公表**。

- **(a)** EDPB-EDPS **Joint Opinion 1/2026** on the Proposal for a Regulation as regards the simplification of the implementation of harmonised rules on artificial intelligence (Digital Omnibus on AI), **para 4**。採択 **【食い違い】** PDF 表紙 "20 January 2026" / EDPB 文書ページ 21 January 2026
- **(b)** https://www.edpb.europa.eu/documents/legislative-opinion/edpb-edps-joint-opinion-12026-on-the-proposal-for-a-regulation-as_en ／ PDF https://www.edpb.europa.eu/system/files/2026-04/edpb_edps_jointopinion_202601_proposal_ai-omnibus_en.pdf
- **(d)** `[公式ガイダンス]`
- **(c)**

> **4.** "[…] the EDPB and the EDPS recall that **the EDPB and the European Commission are working on joint guidelines on the interplay between the GDPR and the AI Act to be issued later this year.** This echoes the commitments of the EDPB in its Helsinki Statement […]"

- **(a)** EDPB **Work Programme 2026-2027**, adopted 11 February 2026
- **(b)** https://www.edpb.europa.eu/system/files/documents/2026-02/edpb_work-programme_2026-2027_en.pdf
- **(d)** `[公式ガイダンス]`
- 収載項目: 柱2 `Joint guidelines on the interplay between the AI Act and the GDPR`／柱1 `Guidelines on anonymisation`, `Guidelines on pseudonymisation*`／柱4 `Guidelines on generative AI – data scraping`

**関連する既存文書**
| 文書 | 日付 | URL |
|---|---|---|
| EDPB **Statement 3/2024** on data protection authorities' role in the AI Act framework | 2024-07-16 | https://www.edpb.europa.eu/system/files/documents/2024-07/edpb_statement_202403_dpasroleaiact_en.pdf |
| EDPB-EDPS **Joint Opinion 5/2021** on the AI Act proposal | 2021-06-18 | https://www.edpb.europa.eu/system/files/documents/2021-06/edpb-edps_joint_opinion_ai_regulation_en.pdf （**本文未取得・逐語引用なし**） |
| EDPB **Guidelines 03/2026** on web scraping in the context of generative AI | 2026-07-07（意見募集中） | https://www.edpb.europa.eu/system/files/2026-07/edpb_guidelines_2020603_webscraping_v1_en_0.pdf |

⚠️ 「EDPB Statement 3/2025 on AI Act–GDPR interplay」は**存在を確認できず**。2025年の Statement で確認できたのは 1/2025（Age Assurance, 2025-02-11）、2/2025（PNR Directive, 2025-03-13）、4/2025（Data Act model contractual terms, 2025-07-08）、および番号なしの Helsinki Statement（2025-07-02）。

### 4.7 EDPB-EDPS Joint Opinion 2/2026 — GDPR 側改正への反対

- **(a)** EDPB-EDPS **Joint Opinion 2/2026** on the Proposal for a Regulation as regards the simplification of the digital legislative framework (Digital Omnibus), **adopted 10 February 2026**, paras 16, 17, 19
- **(b)** https://www.edpb.europa.eu/system/files/2026-02/edpb_edps_jointopinion_202602_digitalomnibus_en.pdf
- **(d)** `[公式ガイダンス]`
- **(c)** 個人データの定義の狭隘化への反対（para 16–17、逐語）

> **16.** "[…] the proposed changes do not accurately reflect and clearly go beyond the CJEU jurisprudence. This is the case, in particular, of the last sentence of the proposed new text which specifies that 'such information does not become personal for that entity merely because a potential subsequent recipient has means reasonably likely to be used to identify the natural person to whom the information relates'. In the EDPS v SRB judgment, the CJEU confirmed its previous jurisprudence, by recalling that **otherwise impersonal data may become personal in nature when they are put at the disposal of a recipient (any recipient) with means reasonably likely to be used to identify a data subject. The CJEU confirmed that, in such cases, those data are personal data both for the recipient and, indirectly, for the entity making the data available to the latter.**"

> **17.** "[…] the proposed changes would result in **significantly narrowing the concept of personal data**, thereby adversely affecting the fundamental right to data protection. Moreover, the proposed change may induce controllers to seek loopholes in the data protection regime […]"

→ **§2.8 para 21 と同じ命題を CJEU 判例として述べたもの。**データを渡す時点で、渡す側にとっても個人データになる。ゲノム解析サービスの構造に直接効く。

> **19.** "[…] the EDPB is preparing updated guidance on pseudonymisation following a public consultation and developing a new set of guidelines on anonymisation, which will take into account, among others, the EDPS v SRB judgment."

**Digital Omnibus の GDPR 側で提案されている内容（未成立）**: Art. 4 の個人データ定義の改正、新 Art. 9(2)(k)（AI の開発・運用における特別カテゴリの**付随的・残余的**処理の例外）、新 Art. 9(5)、新 Art. 41a（仮名化データが個人データでなくなる基準を委員会が実施行為で定める）、新 Art. 88c（機械学習モデルの開発・運用における正当な利益）、科学研究の定義。

Art. 9(2)(k) の射程について（para 48、逐語）:

> **48.** "[…] where the processing of special categories of personal data **is necessary** for the purposes of the processing in the context of the 'development and operation' of AI systems or models, **the derogation will not apply** and data controllers will need to rely on another derogation under Article 9(2) GDPR, if applicable."

→ 仮に成立しても、**ゲノムを意図的に処理する場合は使えない。**この例外は「避けようとしたのに混入した」場合のためのものである。

---

## 5. European Health Data Space (EHDS)

### 5.1 規則の同定

- **(a)** **Regulation (EU) 2025/327** of the European Parliament and of the Council of **11 February 2025** on the European Health Data Space and amending Directive 2011/24/EU and Regulation (EU) 2024/2847 (Text with EEA relevance)
- **(b)** 官報本文 https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202500327 ／ 書誌 https://eur-lex.europa.eu/legal-content/EN/ALL/?uri=CELEX:32025R0327 ／ ELI http://data.europa.eu/eli/reg/2025/327/oj
- **(d)** `[条文]`

| 項目 | 値 |
|---|---|
| CELEX | 32025R0327 |
| 立法手続 | 2022/0140/COD、PE/76/2024/REV/1 |
| 官報 | OJ L, 2025/327, **5.3.2025** |
| 署名（採択） | **2025-02-11**（Strasbourg。R. METSOLA / A. SZŁAPKA） |
| 議会の立場 | 2024-04-24 |
| 理事会決定 | 2025-01-21 |
| 発効 | **2025-03-25**（EUR-Lex メタデータ）— **食い違いあり、下記** |
| 現況 | In force、失効日なし |

Art. 105 第1段（逐語）:

> "This Regulation shall enter into force on the twentieth day following that of its publication in the Official Journal of the European Union."

> **【食い違い①：発効日】** 欧州委員会の公式ページは **26 March 2025** と記載（`[公式ガイダンス]` https://health.ec.europa.eu/ehealth-digital-health-and-care/european-health-data-space-regulation-ehds_en 逐語: "It enters into force on 26 March 2025"）。一方、EUR-Lex メタデータは **25/03/2025**、条文の計算（掲載 3月5日の翌日起算で20日目）も 25 March を支持。Arnold & Porter も 25 March 説（`[二次解説]`）。**両方が EU 公式である。**資料に書くなら「2025年3月25日（EUR-Lex）。ただし委員会ページは3月26日と記載」と併記すること。

### 5.2 構造

```
Regulation (EU) 2025/327 — EHDS
├─ Chapter II  一次利用（本人・医療者のアクセス）
├─ Chapter III EHR システムと wellness アプリ（製品規制）
├─ Chapter IV  【二次利用】← 研究者に関係するのはここ
│   ├─ Art 50  義務を負う health data holder の範囲（個人研究者は免除）
│   ├─ Art 51  提供対象データの最小区分 ← (f) に遺伝・ゲノム
│   ├─ Art 53  許される目的 ／ Art 54 禁止される利用
│   ├─ Art 55  health data access body（HDAB）の指定
│   ├─ Art 60  保有者の提供義務（3か月期限）／ Art 64 制裁金
│   ├─ Art 67  申請 → Art 68 data permit（許可証）
│   ├─ Art 71  本人の opt-out
│   ├─ Art 73  secure processing environment
│   └─ Art 75  HealthData@EU（越境基盤）／75(5) 第三国
├─ Chapter V   Art 88–91 第三国への移転・第三国からの申請
└─ Art 105     Entry into force and application（段階適用）
```

> **【食い違い②：章番号】** 二次解説の一部が「secondary use は Chapter III」と書くが、**採択本文では Chapter IV が "SECONDARY USE"、Chapter III は "EHR SYSTEMS AND WELLNESS APPLICATIONS"**。官報の章見出しで直接確認済み。**Chapter IV が正。**

### 5.3 【最重要】二次利用の対象区分 — Article 51（逐語）

- **(a)** Regulation (EU) 2025/327, **Article 51** "Minimum categories of electronic health data for secondary use"
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202500327
- **(d)** `[条文]`
- **(c)**

> "**1.** Health data holders shall make the following categories of electronic health data available for secondary use in accordance with this Chapter:
> (a) electronic health data from EHRs;
> (b) data on factors impacting on health, including socioeconomic, environmental and behavioural determinants of health;
> (c) aggregated data on healthcare needs, resources allocated to healthcare, the provision of and access to healthcare, healthcare expenditure and financing;
> (d) data on pathogens that impact human health;
> (e) healthcare-related administrative data, including on dispensations, reimbursement claims and reimbursements;
> **(f) human genetic, epigenomic and genomic data;**
> (g) other human molecular data such as proteomic, transcriptomic, metabolomic, lipidomic and other omic data;
> (h) personal electronic health data automatically generated through medical devices;
> (i) data from wellness applications;
> (j) data on professional status, and on the specialisation and institution of health professionals involved in the treatment of a natural person;
> (k) data from population-based health data registries such as public health registries;
> (l) data from medical registries and mortality registries;
> (m) data from clinical trials, clinical studies, clinical investigations and performance studies subject to Regulation (EU) No 536/2014, Regulation (EU) 2024/1938 […], Regulation (EU) 2017/745 and Regulation (EU) 2017/746;
> (n) other health data from medical devices;
> (o) data from registries for medicinal products and medical devices;
> (p) data from research cohorts, questionnaires and surveys related to health, after the first publication of the related results;
> (q) health data from biobanks and associated databases.
>
> **2.** Member States may provide in their national law that additional categories of electronic health data are to be made available for secondary use pursuant to this Regulation.
>
> **3.** Member States may establish rules for the processing and use of electronic health data containing improvements related to the processing of those data, such as correction, annotation or enrichment, based on a data permit pursuant to Article 68.
>
> **4.** Member States may introduce stricter measures and additional safeguards at national level aimed at safeguarding the sensitivity and value of the data that fall under paragraph 1, points (f), (g), (i) and (q). Member States shall notify the Commission of those measures and safeguards and, without delay, of any subsequent amendment affecting them."

### **依頼書の最重要質問への回答**

> **ゲノムデータは EHDS の二次利用の対象として明示的に列挙されている。**
> 条番号 **Article 51**、号 **第1項 (f)**、文言 **"human genetic, epigenomic and genomic data"**。
> バイオバンク由来データは別に (q)、その他のオミクスは (g) に置かれている。

**Recital (56)**（逐語、抜粋）も裏づける:

> "The categories of electronic health data that can be processed for secondary use should be broad and flexible enough to accommodate the evolving needs of health data users […] They can also include relevant data from the health system, for example electronic health records, claims data, dispensation data, data from disease registries or **genomic data** […]"

> **【食い違い⑤：草案の条番号】** 「草案では Article 33 だった」という前提は **確認できず**。COM(2022) 197 の原提案本文を照合していない。**採択本文が Article 51 であることは確認済み。**なお EDPB-EDPS Joint Opinion 03/2022 は提案の Art. 33(1)(f) に言及しており、条番号が 33 → 51 に移動した可能性は高いが、一次確認は取れていない。

### 5.4 段階適用 — Article 105（逐語）

- **(a)** Regulation (EU) 2025/327, **Article 105** "Entry into force and application"
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202500327
- **(d)** `[条文]`
- **(c)** 抜粋（ゲノムに関係する段を太字にした）

> "This Regulation shall apply from **26 March 2027**.
>
> However, Articles 3 to 15, Article 23(2) to (6), Articles 25, 26, 27, 47, 48 and 49 shall apply as follows:
> (a) from **26 March 2029** to priority categories of personal electronic health data referred to in Article 14(1), points (a), (b) and (c) […];
> (b) from **26 March 2031** to priority categories […] referred to in Article 14(1), points (d), (e) and (f) […];
> […]
>
> **Chapter IV shall apply from 26 March 2029. However, Article 55(6), Article 70, Article 73(5), Article 75(1) and (12), Article 77(4) and Article 78(6) shall apply from 26 March 2027; Article 51(1), points (b), (f), (g), (m) and (p), shall apply from 26 March 2031; and Article 75(5) shall apply from 26 March 2035.**"

**Article 14(1) の優先区分（逐語）** — 上の (a)/(b) 群を読むために必要:

> "(a) patient summaries; (b) electronic prescriptions; (c) electronic dispensations; (d) medical imaging studies and related imaging reports; (e) medical test results, including laboratory and other diagnostic results and related reports; and (f) discharge reports."

**日付の整理**

| 日付 | 何が始まるか |
|---|---|
| 2025-03-25 | 発効。義務はまだ発生しない |
| **2027-03-26** | 規則の一般適用日。Chapter II 本体、Chapter V（第三国関係の Art. 88・90・91 を含む）。Chapter IV のうち Art. 55(6)（HDAB の委員会への通知期限）、70、73(5)、75(1)・(12)、77(4)、78(6) が前倒し適用 |
| **2029-03-26** | **Chapter IV（二次利用）が適用開始。**一次利用の第1群（患者サマリ・処方・調剤）も |
| **2031-03-26** | **Art. 51(1) の (b)(f)(g)(m)(p) が適用開始 — すなわち遺伝・ゲノム (f)、他のオミクス (g)、臨床試験 (m)、研究コホート (p)、健康の決定要因 (b)。**一次利用の第2群（画像・検査結果・退院報告）も |
| **2035-03-26** | Art. 75(5) — 第三国・国際機関が HealthData@EU の authorised participant になれる規定 |

> **ゲノム固有の要点**: 二次利用の枠組みは 2029 年に始まるが、**ゲノムはその2年後の 2031 年まで対象にならない。**

> **【食い違い③】** Arnold & Porter `[二次解説]` は適用日を "March 25, 2027 / 2029 / 2031" と書くが、条文はすべて **26 March**。1日ずれている。条文が正。
> **【食い違い④】** 一部二次解説が Art. 75(5) を "enters into force on 26 March 2035" と書くが、条文は "shall **apply** from 26 March 2035"。規則全体の発効は 2025 年であり、2035 年は適用開始。発効と適用は別概念。

### 5.5 health data access body（HDAB）

**設置根拠 — Article 55(1)（逐語）** `[条文]`

> "Member States shall designate one or more health data access bodies responsible for carrying out the tasks and obligations set out in Articles 57, 58 and 59. Member States may either establish one or more new public sector bodies or rely on existing public sector bodies or on internal services of public sector bodies that fulfil the conditions set out in this Article. […] Where a Member State designates several health data access bodies, it shall designate one health data access body to act as coordinator […]"

**何をするか — Article 57(1)(a)(b)（逐語）**

> "Health data access bodies shall carry out the following tasks: (a) deciding on health data access applications pursuant to Article 67 of this Regulation, **authorising and issuing data permits** pursuant to Article 68 […] including with regard to: (i) providing access to electronic health data to health data users pursuant to a data permit **in a secure processing environment** in accordance with Article 73; (ii) monitoring and supervising compliance […]; (iii) requesting electronic health data referred to in Article 51 from relevant health data holders […]; (b) processing electronic health data referred to in Article 51 such as by receiving, combining, preparing and compiling such data when requested from health data holders and **the pseudonymisation or anonymisation of those data**;"

**研究者は誰に申請するか — HDAB であって保有者ではない**

Article 67(1)（逐語）:
> "A natural or legal person may submit a health data access application for the purposes referred to in Article 53(1) to a health data access body."

Article 68(7)（逐語）— 保有者にデータを求めるのは HDAB:
> "Following the issuance of the data permit, the health data access body shall immediately request the electronic health data from the health data holder. The health data access body shall make available the electronic health data to the health data user within two months of receiving them from the health data holders […]"

**data permit の定義 — Article 2(2)(v)（逐語）**
> "'data permit' means an administrative decision issued to a health data user by a health data access body to process certain electronic health data specified in the data permit for specific secondary use purposes, based on conditions laid down in Chapter IV of this Regulation;"

**期限と有効期間**
- Art. 68(4): "the health data access body shall issue or refuse a data permit **within three months** of receiving a complete health data access application."
- Art. 68(12): "A data permit shall be issued for the duration necessary to fulfil the requested purposes and that duration **shall not exceed 10 years.** That duration may be extended once, for a period which does not exceed 10 years […]"

**アクセスは必ず秘匿計算環境経由 — Article 73(1)（逐語、抜粋）**
> "Health data access bodies shall provide access to electronic health data pursuant to a data permit **only through a secure processing environment** which is subject to technical and organisational measures and security and interoperability requirements."

**許される目的のうち研究が該当する号 — Article 53(1)(e)（逐語）**
> "(e) scientific research related to health or care sectors that contributes to public health or health technology assessments, or ensures high levels of quality and safety of healthcare, of medicinal products or of medical devices, with the aim of benefiting end-users, such as patients, health professionals and health administrators, including: (i) development and innovation activities for products or services; **(ii) training, testing and evaluation of algorithms, including in medical devices, in vitro diagnostic medical devices, AI systems and digital health applications;**"

→ **(ii) が AI Act との接続点。**EHDS は AI システムの学習・試験・評価を二次利用の適法な目的として明示的に認めている。

**禁止される利用 — Article 54（逐語、抜粋）**
> "(a) taking decisions detrimental to a natural person or a group of natural persons based on their electronic health data […] (b) taking decisions in relation to a natural person or a group of natural persons in relation to job offers, offering less favourable terms in the provision of goods or services, including exclusion of such persons or groups from the benefit of an insurance or credit contract […] (c) carrying out advertising or marketing activities; […] (e) carrying out activities in conflict with ethical provisions laid down in national law."

**結果公表義務 — Article 61(4)（逐語、抜粋）** — 見落とされやすい研究者側の義務
> "Health data users shall make public the results or output of secondary use, including information relevant for the provision of healthcare, **within 18 months of the completion of the processing** of the electronic health data in the secure processing environment […] **The results or output of secondary use shall contain only anonymous data.** […] they shall acknowledge the sources of the electronic health data and the fact that the electronic health data have been obtained in the framework of the EHDS."

### 5.6 遺伝データ固有の制限と opt-out

遺伝データの扱いは**四層**に分かれる。

| 層 | 根拠 | 中身 |
|---|---|---|
| ① 適用の後ろ倒し | Art. 105 第5段 | Art. 51(1)(f)(g) は 2029 ではなく **2031-03-26 から** |
| ② 加盟国の上乗せ | Art. 51(4) | (f)(g)(i)(q) に限り、より厳しい国内措置を導入できる |
| ③ 本人の opt-out | Art. 71 | 理由不要・いつでも・撤回可能 |
| ④ 初回登録の規律は各国に残る | Recital (11) | 遺伝データの登録を本人同意にかからしめる国内法は影響を受けない |

**Art. 9(4) GDPR との関係 — Recital (52)（逐語、抜粋）** `[条文]`

> "Consequently, Member States should **no longer be able to maintain or introduce under Article 9(4) of Regulation (EU) 2016/679 further conditions**, including limitations and specific provisions requesting the consent of natural persons, with regard to the processing for secondary use of personal electronic health data under this Regulation, **with the exception of** the introduction of stricter measures and additional safeguards at national level aimed at safeguarding the sensitivity and value of certain data as laid down in this Regulation."

→ **EHDS の二次利用の文脈では、§1.6 の Art. 9(4) 上乗せ余地は原則として閉じられる。**残るのは Art. 51(4) の (f)(g)(i)(q) に限った上乗せのみ。**ゲノムはその例外に含まれる。**

Recital (52) はさらに、EHDS 自体が適法根拠を与えると述べる（逐語、抜粋）:

> "Accordingly, this Regulation provides for a legal basis for the secondary use of personal electronic health data, including the safeguards required under Article 9(2), points (g) to (j), of Regulation (EU) 2016/679 to allow the processing of special categories of data […]"

**Recital (11)（逐語）**

> "This Regulation does not affect Member States' competences concerning the initial registration of personal electronic health data, such as **making the registration of genetic data subject to the natural person's consent** or other safeguards."

**Article 71 — opt-out（逐語、主要項）**

> "**1.** Natural persons shall have the right to opt out at any time, and without providing any reason, from the processing of personal electronic health data relating to them for secondary use under this Regulation. The exercise of that right shall be reversible.
>
> **2.** Member States shall provide for an accessible and easily understandable opt-out mechanism […]
>
> **3.** Once natural persons have exercised the right to opt out, and where personal electronic health data relating to them can be identified in a dataset, personal electronic health data relating to those natural persons shall not be made available or otherwise processed pursuant to data permits issued under Article 68 or health data requests under Article 69 approved **after** the natural person has exercised the right to opt out. […] shall not affect the processing […] pursuant to data permits or health data requests that were issued or approved **before** the natural persons exercised their right to opt out.
>
> **4.** By way of exception […] a Member State may provide in its national law for a mechanism to make data for which a right to opt out has been exercised available, provided that all the following conditions are fulfilled: (a) the health data access application […] is submitted by a public sector body or a Union institution […] with a mandate to carry out tasks in the area of public health […] and the processing of those data is necessary for any of the following purposes: (i) the purposes referred to in Article 53(1), points (a), (b) and (c); (ii) **scientific research for important reasons of public interest**; (b) those data cannot be obtained by alternative means in a timely and effective manner under equivalent conditions; (c) the health data applicant has provided the justification […]"

**注意**: **遺伝データだけを対象にした専用の opt-out 条文は存在しない。**Art. 71 は全ての個人健康データに横断的にかかる。ただし一次利用側の Recital (18) は遺伝データを名指しして加盟国が特別の保護措置を置けると述べる（逐語、抜粋）: "Those rules and specific safeguards could also relate to specific categories of personal electronic health data, for example genetic data."

**匿名化後でも「highly sensitive」になりうる — Article 88(1)（逐語）** — §2 と直結する重要条項

> "Non-personal electronic health data made available by health data access bodies to a health data user in a third country […] and based on a natural person's electronic health data falling within one of the categories referred to in Article 51 of this Regulation, **shall be deemed highly sensitive** within the meaning of Article 5(13) of Regulation (EU) 2022/868 **where the transfer of such non-personal electronic data to third countries presents a risk of re-identification through means going beyond those reasonably likely to be used**, in particular in view of the limited number of natural persons to whom those data relate, the fact that they are geographically scattered or the technological developments expected in the near future."

Recital (92)（逐語、抜粋）が根拠を述べる:

> "Such residual risk is present in relation to rare diseases, that is to say a life-threatening or chronically debilitating condition affecting not more than 5 in 10 000 persons in the Union […] for instance in cases of data included in electronic health records, disease registries, biobanks and person-generated data, where the range of identification characteristics is broader […]"

→ **希少疾患のゲノムデータは、非個人データに転化した後でも第三国移転で規制対象になりうる。**

### 5.7 越境研究は容易になるのか、義務が増えるのか — **両方**

**容易になる側（研究者にとって）**

| 仕組み | 条文 | 逐語 |
|---|---|---|
| 単一窓口 | Art. 67(3) | "the health data applicant shall submit **a single health data access application** through the health data access body of the Member State where the main establishment of the health data applicant is located […] The health data access application shall be **automatically forwarded** to the relevant authorised participants in HealthData@EU and to the health data access bodies of the Member States where the health data holders […] are established." |
| 越境基盤 | Art. 75(7) | "The Member States and the Commission shall set up **HealthData@EU** to support and facilitate the cross-border access to electronic health data for secondary use, connecting the national contact points for secondary use and authorised participants […]" |
| 多国データの共用解析環境 | Art. 75(9) | "Where requested by two or more national contact points for secondary use, the Commission **may provide a secure processing environment** which is compliant with the requirements of Article 73 for data from more than one Member State." |
| 研究インフラの参加 | Art. 75(4) | "Health-related research infrastructures or similar infrastructures whose functioning is based on Union law […] **may become authorised participants in HealthData@EU** and connect to it." |
| GDPR 上の根拠の提供 | Recital (52) | §5.6 参照 |
| 個人研究者は保有者義務を免除 | Art. 50(1) | "The following categories of health data holders shall be **exempt** from the obligations on health data holders laid down in this Chapter: (a) **natural persons, including individual researchers**; (b) legal persons that qualify as microenterprises […]" （ただし Art. 50(2) により加盟国は国内法でこの免除を外せる） |

**義務が増える側（保有者・利用者にとって）**

| 義務 | 条文 | 逐語 |
|---|---|---|
| 提供義務と3か月期限 | Art. 60(1)(2) | "Health data holders shall make relevant electronic health data referred to in Article 51 available upon request to the health data access body […] within a reasonable time and **no later than three months** from the receipt of the request […] In justified cases, the health data access body may extend that period by a maximum of three months." |
| データセット記述の年次更新 | Art. 60(3) | "The health data holder shall, **at a minimum on an annual basis**, check that its dataset description in the national dataset catalogue is accurate and up to date." |
| 制裁金 | Art. 64(4) | "infringements of the duties of the health data holder or health data user pursuant to Article 60 and Article 61(1), (5) and (6) shall be subject to administrative fines of **a maximum of EUR 10 000 000 or, in the case of an undertaking, of a maximum of 2 % of its total worldwide annual turnover** in the preceding financial year, whichever is higher." （Art. 64(5) は上位類型について 2000万ユーロ／4% を定める） |
| 手数料 | Art. 62(1)(2) | "Health data access bodies […] **may charge fees** for making electronic health data available for secondary use. The fees shall be in proportion to the cost […] Member States may establish reduced fees for certain types of health data users located in the Union, such as public sector bodies […] university researchers or microenterprises." |

**"health data holder" の定義に研究機関が含まれる — Art. 2(2)(t)（逐語、冒頭）**

> "'health data holder' means any natural or legal person, public authority, agency or other body in the healthcare or the care sectors […] as well as any natural or legal person developing products or services intended for the health, healthcare or care sectors, developing or manufacturing wellness applications, **performing research in relation to the healthcare or care sectors** […] that has either: (i) the right or obligation […] to process personal electronic health data for the provision of healthcare or care or for the purposes of public health, reimbursement, **research**, innovation, policymaking […]"

→ **大学・研究機関・解析プラットフォームは health data holder になりうる。**その場合、Art. 60 の提供義務と Art. 64 の制裁金の対象になる。

### 5.8 スイスは EHDS の外にある

EHDS は EU 規則であり、スイスは EU にも EEA にも加盟していないため直接適用されない。ただし**条文には第三国からのアクセス経路が二本ある。**

```
スイスの研究者が EHDS データに二次利用でアクセスする経路
│
├─ 経路1：スイスが HealthData@EU の authorised participant になる
│    根拠 Art. 91(1)(a) + Art. 75(5)、委員会の implementing act が必要
│    → Art. 105 により 2035-03-26 以降でなければ不可能
│
└─ 経路2：相互主義（reciprocity）
     根拠 Art. 91(1)(b) + Art. 91(2)
     スイスが EU の申請者に「EHDS より厳しくない条件」で自国データを
     開放していると委員会が implementing act で認定すること
     → 条文上は 2027-03-26 から利用可能。ただし認定の時期は未定
```

**Article 91（逐語、第1項・第2項）** `[条文]`

> "**1.** Without prejudice to Articles 67, 68 and 69, health data access applications and health data requests submitted by a health data applicant established in a third country shall be considered eligible by health data access bodies and the Union health data access service if the third country concerned: (a) is an authorised participant on the basis of having a national contact point for secondary use covered by an implementing act referred to in Article 75(5); or **(b) allows Union health data applicants access to electronic health data in that third country under conditions that are not more restrictive than those provided for in this Regulation**, and therefore such access is covered by an implementing act referred to in paragraph 2 of this Article.
>
> **2.** By means of implementing acts, the Commission may determine that a third country meets the requirement set out in paragraph 1, point (b) […] The Commission shall make the list of implementing acts adopted pursuant to this paragraph publicly available."

**Article 75(5)（逐語、抜粋）**

> "Third countries or international organisations may become authorised participants in HealthData@EU where they comply with the rules of this Chapter and provide access to health data users located in the Union, on equivalent terms and conditions, to the electronic health data available to their health data access bodies, subject to compliance with Chapter V of Regulation (EU) 2016/679."

**Recital (94)（逐語）** — 相互主義の趣旨

> "Access to electronic health data for health data users established in third countries or for international organisations should take place **only on the basis of the reciprocity principle.** Making electronic health data available to a third country should be allowed to take place only where the Commission has established, by means of an implementing act, that the third country concerned allows access to electronic health data originating from that third country by Union entities **under the same conditions and with the same safeguards** as would be the case if they were accessing electronic health data within the Union. […]"

**個人データの移転は GDPR 第5章のまま — Article 90（逐語）**

> "Transfer of personal electronic health data to a third country or an international organisation shall be granted **in accordance with Chapter V of Regulation (EU) 2016/679.** Member States may maintain or introduce further conditions on international access to, and transfer of, personal electronic health data, including limitations, in accordance with Article 9(4) of Regulation (EU) 2016/679 […]"

**TEHDAS2 ガイドライン（共同行動の成果物）**

- **(a)** *Guideline for Health Data Access Bodies on international and third country access and transfer of electronic health data*, TEHDAS2 – Second Joint Action Towards the European Health Data Space, **27 April 2026**, 成果物番号 M4.3、43ページ
- **(b)** https://tehdas.eu/wp-content/uploads/2026/05/draft-guideline-for-health-data-access-bodies-on-international-and-third-country-access-and-transfer-of-electronic-health-data.pdf
- **(d)** `[公式ガイダンス]`（⚠️ **厳密には EU 共同行動の成果物であり、委員会自身の解釈ではない。**免責に "Views and opinions expressed are however those of the author(s) only and do not necessarily reflect those of the European Union or HaDEA." とある）
- **(c)**

> "Recognition of authorised third countries under Article 75(5) will only be possible as of 2035. In the initial years of the EHDS, **third-country access will therefore rely on the reciprocity-based mechanism under Article 91(1)(b). There is not yet any precise timeline available for the adoption of implementing acts on reciprocity under Article 91(1)(b).**"

> "Accordingly, both the conditions of access by data users and the safeguards for data users should be equivalent (i.e. 'not more restrictive than those provided for in this Regulation'), **but not necessarily identical** to those in the EU to meet the reciprocity requirement of Article 91(1)(b)."

> "[…] recognition under Article 91(2) or designation as an authorised participant under Article 75(5) applies **at the country level, not to individual organisations.**"

> "Absence of structured reciprocity frameworks. Respondents emphasised that, at present […] **there is no established EU-wide framework governing reciprocity with third countries for health data access.**"

**ERIC / EDIC 経由の抜け道（逐語）** — スイス機関にとって実務上最も重要かもしれない一節

> "ERICs and EDICs are entities established under EU law, even if they may include third-country members. As such, they should **not** be treated as international organisations under Article 75(5). For ERICs and EDICs, the relevant legal basis is **Article 75(4)**, which applies to entities established under EU law. […] Consequently: Article 75(4), rather than Article 75(5), would govern their potential participation to Healthdata@EU and **the applicable date of application would be 2029**, in line with Article 75(4)."

→ スイスの機関が ERIC / EDIC の構成機関として関わる場合、**2035 年ではなく 2029 年の枠組みが関係しうる。**ただし同ガイドラインは、第三国構成員を含む場合の特権免除など複雑な法的問題が残り本ガイドラインでは解決できない、とも述べている。

**EEA 関連性**: 規則名称末尾の "(Text with EEA relevance)" と EUR-Lex メタデータで確認済み。**EEA 協定への編入（EEA Joint Committee Decision）の有無は確認できず**（EFTA サイトが取得できなかった）。なお EEA に編入されてもスイスには及ばない（スイスは EEA 非加盟）。

---

## 6. 研究目的の例外の限界 — 解析サービスは「科学研究」か

**依頼の指示どおり、ここでは結論を出さない。条文が何を言い、誰が何を言い、どこが未決かを記録する。**

### 6.1 AI Act Article 2(6)（逐語）

- **(a)** Regulation (EU) 2024/1689, **Article 2(6)**（Digital Omnibus による改正は**確認されず**＝現行のまま）
- **(b)** https://artificialintelligenceact.eu/article/2/
- **(d)** `[条文]`
- **(c)**

> "This Regulation does not apply to AI systems or AI models, including their output, **specifically developed and put into service for the sole purpose of scientific research and development.**"

日本語の趣旨: 本規則は、**科学的な研究および開発のみを目的として特別に開発され、かつ提供開始（put into service）された** AI システムまたは AI モデル（その出力を含む）には適用されない。

### 6.2 【核心の文言上の論点】"put into service" であって "placed on the market" ではない

AI Act は二つを別概念として定義している。Art. 2(6) は**前者しか挙げていない。**

- **(a)** Regulation (EU) 2024/1689, **Article 3(9)(10)(11)**
- **(b)** https://artificialintelligenceact.eu/article/3/
- **(d)** `[条文]`
- **(c)**

> **(9) 'placing on the market'** means "the first making available of an AI system or a general-purpose AI model on the Union market"

> **(10) 'making available on the market'** means "the supply of an AI system or a general-purpose AI model for distribution or use on the Union market **in the course of a commercial activity, whether in return for payment or free of charge**"

> **(11) 'putting into service'** means "the supply of an AI system for first use **directly to the deployer or for own use** in the Union for its intended purpose"

**(3) 'provider'** の定義も関係する:

> "a natural or legal person […] that develops an AI system or a general-purpose AI model or that has an AI system or a general-purpose AI model developed and **places it on the market or puts the AI system into service under its own name or trademark, whether for payment or free of charge**"

**この定義群から読める構図**

```
   自分の研究室の中だけで使う解析 AI
        └→ "putting into service ... for own use"
        └→ 目的が科学研究のみなら Art. 2(6) に乗りうる

   他の研究者に解析サービスとして提供する
        └→ "supply ... for distribution or use on the Union market
             in the course of a commercial activity"（無償でも該当しうる）
        └→ "making available on the market" → "placing on the market"
        └→ Art. 2(6) は "placed on the market" を挙げていない
        └→ 【ここが未決】
```

**無償でも「commercial activity」でありうる点に注意。**Art. 3(10) は "whether in return for payment or free of charge" と明記している。学術機関が無償で提供しても、それだけで市場提供性が否定されるわけではない。

### 6.3 Recital 25（逐語、全文）

- **(a)** Regulation (EU) 2024/1689, **Recital 25**
- **(b)** https://artificialintelligenceact.eu/recital/25/ ／ 委員会 AI Act Service Desk https://ai-act-service-desk.ec.europa.eu/en/ai-act/recital-25
- **(d)** `[条文]`
- **(c)**

> "This Regulation should support innovation, should respect freedom of science, and should not undermine research and development activity. It is therefore necessary to exclude from its scope AI systems and models specifically developed and put into service for the sole purpose of scientific research and development. Moreover, it is necessary to ensure that this Regulation does not otherwise affect scientific research and development activity on AI systems or models prior to being placed on the market or put into service. As regards product-oriented research, testing and development activity regarding AI systems or models, the provisions of this Regulation should also not apply prior to those systems and models being put into service or placed on the market. **That exclusion is without prejudice to the obligation to comply with this Regulation where an AI system falling into the scope of this Regulation is placed on the market or put into service as a result of such research and development activity** and to the application of provisions on AI regulatory sandboxes and testing in real world conditions. Furthermore, without prejudice to the exclusion of AI systems specifically developed and put into service for the sole purpose of scientific research and development, **any other AI system that may be used for the conduct of any research and development activity should remain subject to the provisions of this Regulation.** In any event, any research and development activity should be carried out in accordance with recognised ethical and professional standards for scientific research and should be conducted in accordance with applicable Union law."

**Recital 25 が例外を三方向から絞っている**

| # | 絞り | 該当文言 |
|---|---|---|
| 1 | 研究に**使われる**だけの AI は対象外 | "any other AI system that may be used for the conduct of any research and development activity should remain subject to the provisions of this Regulation" |
| 2 | 研究の**結果として**市場に出せば義務が復活 | "where an AI system […] is placed on the market or put into service as a result of such research and development activity" |
| 3 | 倫理・職業基準の遵守は残る | "in accordance with recognised ethical and professional standards for scientific research" |

### 6.4 AI Act Article 2(8) — 上市前の研究開発

- **(a)** Regulation (EU) 2024/1689, **Article 2(8)**
- **(b)** https://artificialintelligenceact.eu/article/2/
- **(d)** `[条文]`
- **(c)**

> "This Regulation does not apply to any research, testing or development activity regarding AI systems or AI models **prior to their being placed on the market or put into service.** Such activities shall be conducted in accordance with applicable Union law. **Testing in real world conditions shall not be covered by that exclusion.**"

→ 2(8) は「まだ出していない段階」の免除であり、**科学研究に限定されていない。**2(6) との関係が学説上の論点になっている（§6.5）。

### 6.5 学術的評価 — Finck (2025)

- **(a)** Michèle Finck, "In Search of the Lost Research Exemption: Reflections on the AI Act," *GRUR International*, **Vol. 74, Issue 10, October 2025, pp. 903–904**
- **(b)** https://doi.org/10.1093/grurint/ikaf100 ／ https://academic.oup.com/grurint/article/74/10/903/8238058
- **(d)** `[学術]`
- 論旨:
  - Art. 2(6) は "developed and **put into service (but not placed on the market!)**" を対象とする、と明示的に指摘している。
  - "The scope of this provision mainly hinges on the interpretation of **'the sole purpose of scientific research.'**"
  - 研究者は成果の最終的な用途を着手時点で予見できないことが多く、基礎研究は「純粋に科学的な領域を超えた応用を必ず見出す」ため Art. 2(6) の外に落ちうる、という緊張を指摘。
  - Art. 2(6) と 2(8) の関係について**二つの読みが競合**する — 2(8) が一般的な研究免除を与えるので 2(6) は冗長である、という読みと、両者の相違は意図的な分離である、という読み。
  - ⚠️ **第三者への提供が例外を失わせるかについて、本論文は明示的に論じていない。**"sole purpose" の文言が商業的頒布を失格させることを示唆する、という水準にとどまる。

**その他の学術的指摘**

- **(a)** *Challenges in applying the EU AI act research exemptions to contemporary AI research*, npj Digital Medicine
- **(b)** https://www.nature.com/articles/s41746-025-02263-0
- **(d)** `[学術]`
- 論旨: これらの免除は、研究と商業活動の境界、実験室内の開発と実世界試験の境界という、**現代の AI 研究の実態を十分に捉えていない区別**に依拠している。

### 6.6 GDPR 側の「科学研究」— こちらも境界が動いている

GDPR には「科学研究」の定義がない。Digital Omnibus（**未成立**）が定義を入れようとしており、その審査過程で EDPB / EDPS が境界について発言している。**この発言は、AI Act の解釈にも参照されうる。**

- **(a)** EDPB-EDPS **Joint Opinion 2/2026**, **§4.1 Definition, paras 26, 29**
- **(b)** https://www.edpb.europa.eu/system/files/2026-02/edpb_edps_jointopinion_202602_digitalomnibus_en.pdf
- **(d)** `[公式ガイダンス]`
- **(c)**

提案されている GDPR 上の定義（para 26 が引用する文言、逐語）:

> "scientific research '(...) shall contribute to existing scientific knowledge or apply existing knowledge in novel ways, be carried out with the aim of contributing to the growth of society's general knowledge and wellbeing and adhere to ethical standards in the relevant research area'."

EDPB / EDPS の勧告（para 29(ii)、逐語） — **境界論として最も重要な一節**

> "moving the phrases 'any research which can also support innovation, such as technological development and demonstration' and '[t]his does not exclude that the research may also aim to further a commercial interest' from the definition into the relevant Recital […] The EDPB and the EDPS note that these phrases provide extra context and guidance for the definition of scientific research but do not, as such, constitute criteria for an activity to qualify as scientific research. For example, **product research and development may support innovation, but does not necessarily constitute scientific research.**"

para 29(i)（逐語）— 科学研究に求めるべき要素

> "moving from Recital 28 to the enacting terms that scientific research should: 1. be conducted following a **methodological and systematic approach** of the relevant scientific research field. In addition, it should be added that scientific research should be conducted in an **autonomous and independent manner**; 2. lead to **verifiable and transparent results.** It is recommended to explain in the recitals that transparency may, among other things, involve making research results publicly available."

日本語の趣旨: 製品の研究開発はイノベーションを支えうるが、**必ずしも科学研究にあたるわけではない**。科学研究には、当該分野の方法論に沿った体系的な取り組み、自律的・独立した実施、検証可能で透明な結果が求められるべきである。

→ **「商業的利益を伴ってもよい」と「商業的な製品開発は科学研究ではない」は両立する、というのが監督機関の立場。**分かれ目は資金源ではなく、**方法論・独立性・結果の検証可能性**に置かれている。

### 6.7 【未決】解析サービス提供は Art. 2(6) に乗るか

**依頼の指示に従い、ここでは判断しない。**判断材料を並べる。

| 免除に**不利**な材料 | 出典 |
|---|---|
| Art. 2(6) は "put into service" のみを挙げ、"placed on the market" を挙げていない | §6.2、Finck (2025) が明示的に指摘 |
| "making available on the market" は**無償でも**成立しうる | Art. 3(10) |
| Recital 25 は「研究の結果として上市すれば義務が復活する」と明記 | §6.3 |
| Recital 25 は「研究活動に**使われる**だけの AI は規則に服したまま」と明記 | §6.3 |
| "sole purpose"（唯一の目的）は多目的利用を排除する、という読みが通説 | §6.5、複数の `[二次解説]` |
| 監督機関は「製品の研究開発は必ずしも科学研究ではない」とする | §6.6 |

| 免除に**有利**な材料 | 出典 |
|---|---|
| Art. 2(6) は "scientific research **and development**" と書いており、開発も含む | 条文 |
| Recital 25 は "should respect freedom of science" と、広い趣旨を掲げる | §6.3 |
| GDPR 側の提案定義は「研究が商業的利益を追求することを排除しない」と明記（ただし未成立、かつ EDPB はリサイタルへの移動を勧告） | §6.6 |
| 利用者が研究者に限られ、利用目的が研究に限定され、独立した方法論に沿っている場合、監督機関が挙げる要素を満たしうる | §6.6 |

**未決である理由の核心**

1. **公式ガイダンスが存在しない。**委員会の AI Act Service Desk はリサイタルを再掲するのみ。Art. 2(6) の適用範囲についての解釈指針は**確認できず**。
2. **"sole purpose" の意味が条文上定義されていない。**AI Act は "scientific research" も "development" も定義していない。
3. **GDPR の「科学研究」概念を借りるべきかが争われている。**借りるべきとする説（定義を置かなかったのは GDPR との整合を含意する）と、借りるべきでないとする説（GDPR 型のリサイタルを意図的に置かなかった、Art. 2(8) の別免除が科学研究に限定されていない）が対立する。§6.5 参照。
4. **AI Act × GDPR 統合ガイドラインが未公表。**§4.6。

**記録すべき暫定的な読み**（判断ではなく、材料の重みづけ）: 文言上は、**第三者に提供する時点で "placing on the market" 側に寄る**という読みのほうが支持材料が多い。ただしこれを確定させる公式ガイダンスも判例も**存在しない**。

**なお** — Art. 2(6) に乗ったとしても、**GDPR は独立に適用され続ける**（§4.2）。AI Act の免除は GDPR の免除ではない。ゲノムデータの Art. 9(1) 禁止と Art. 9(2) 解除事由の必要性は、AI Act の適用の有無と無関係に残る。

---

## 7. 国際移転 — EU からスイスへ

> **【訂正】依頼書の前提に誤りが二つある。**
> ① **スイスの十分性認定は 2024年に更新も差し替えもされていない。**現在も **2000年の Decision 2000/518/EC そのもの**が効力を有する唯一の法的文書である。
> ② **「Commission implementing decision Switzerland adequacy 2024/2683」という文書は存在しない（確認できず）。**EUR-Lex・委員会の adequacy ページ・FDPIC のいずれにも該当なし。2024年1月15日に採択されたのは **11件の決定を「維持する」という報告書**（COM(2024) 7 final）であって、新しい決定の束ではない。近い番号の 2023/2683 は使い捨てプラスチックボトルの再生プラ含有率に関する規則で無関係。

### 7.1 スイスの十分性認定 — 2026年9月時点で有効

```
Directive 95/46/EC 25条6項
  └─ Decision 2000/518/EC（2000-07-26）★現在も唯一の法的根拠
        ├─ 2016-12-16  Implementing Decision (EU) 2016/2295 で改正（Art. 3a 継続監視を追加）
        ├─ 2018-05-25  GDPR 適用開始 → Art. 45(9) により存続
        ├─ 2023-09-01  スイス改正 FADP 施行（＝継続の実質的根拠）
        ├─ 2024-01-15  COM(2024) 7 final：11件すべて「継続して adequate」と結論
        │                 ※ 新決定は採択していない。報告書のみ
        ├─ 2024-12-05  EDPB が委員会に書簡（方法論の透明性を要求。異議ではない）
        └─ 2026-09-13  EUR-Lex 表示「In force」。廃止・停止・係争なし
```

#### 原決定の同定

- **(a)** Commission Decision **2000/518/EC** of **26 July 2000** pursuant to Directive 95/46/EC on the adequate protection of personal data provided in Switzerland（notified under document number **C(2000) 2304**）、OJ **L 215, 25.8.2000, p. 1**
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32000D0518 ／ 統合版 https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:02000D0518-20161217 ／ 法的状態 https://eur-lex.europa.eu/eli/dec/2000/518/oj
- **(d)** `[条文]`

→ 依頼書の番号・日付は**正しい**。改正法令は COMMISSION IMPLEMENTING DECISION (EU) **2016/2295** of **16 December 2016**、OJ L 344, 17.12.2016, p. 83。

EUR-Lex の法的状態表示（逐語）:

> "In force: This act has been changed. Current consolidated version: 17/12/2016"

Date of end of validity・Repealed by の欄は**空**。

#### operative article — 逐語（依頼の4点目）

- **(a)** Decision 2000/518/EC, **Article 1**（統合版 02000D0518-20161217）
- **(d)** `[条文]`
- **(c)**

> "For the purposes of Article 25(2) of Directive 95/46/EC, for all the activities falling within the scope of that Directive, **Switzerland is considered as providing an adequate level of protection for personal data transferred from the Community.**"

日本語の趣旨: 指令 95/46/EC 第25条2項の適用上、同指令の適用範囲に属する**すべての活動**について、スイスは共同体から移転される個人データについて**十分な保護水準を提供している**とみなされる。

> **遺伝データも含まれる。**"for **all the activities** falling within the scope of that Directive" と書かれており、**特別カテゴリ（遺伝データ・健康データ）を除外する文言は決定のどこにもない。**

**Article 3a（2016/2295 で追加された継続監視条項、逐語・抜粋）**

> "1. **The Commission shall, on an ongoing basis, monitor developments in the Swiss legal order that could affect the functioning of this Decision, including developments concerning access to personal data by public authorities** […]
> 4. **Where evidence shows that an adequate level of protection is no longer ensured** […] the Commission shall inform the competent Swiss authority and, if necessary, propose draft measures […] **with a view to repealing or suspending this Decision or limiting its scope.**"

#### 2024年1月15日に実際に起きたこと

- **(a)** **COM(2024) 7 final**, *Report from the Commission to the European Parliament and the Council on the first review of the functioning of the adequacy decisions adopted pursuant to Article 25(6) of Directive 95/46/EC*, Brussels, **15 January 2024**。付属文書 **SWD(2024) 3 final**。理事会文書番号 5454/24
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:52024DC0007
- **(d)** `[公式ガイダンス]`
- **(c)** 対象11か国・地域（逐語）

> "Andorra, Argentina, Canada (for commercial operators), Faroe Islands, Guernsey, Isle of Man, Israel, Jersey, New Zealand, **Switzerland**, and Uruguay. As a result, data transfers from the EU to these countries or territories can take place without additional requirements."

総括結論（逐語）:

> "Based on these findings, the Commission concludes that **each of the eleven countries and territories continues to ensure an adequate level of protection for personal data transferred from the European Union within the meaning of the GDPR, as interpreted by the Court of Justice.**"

スイスの節（§4.10、逐語・全文）— **遺伝データに直接効く評価**:

> "The Commission welcomes the developments in the Swiss legal framework since the adoption of the adequacy decision […] **In particular, the modernised Federal Act on Data Protection that has further increased the convergence with the EU's data protection framework, notably with respect to the protections for sensitive data and the rules on international data transfers. Switzerland also strengthened its international commitments in the field of data protection by ratifying Convention 108+ in September 2023.** […] the Commission concludes that **Switzerland continues to provide an adequate level of protection for personal data transferred from the EU.**"

→ **「sensitive data の保護強化」が名指しで評価されている。**スイス改正 FADP は遺伝データを sensitive personal data に明示的に追加しており（下記）、ゲノムデータの移転にとって直接の意味を持つ。

#### スイス改正データ保護法（revFADP）

- **(a)** Federal Act on Data Protection (FADP), **SR 235.1**, of **25 September 2020**、**施行 2023年9月1日**、Article 5(c)
- **(b)** https://www.fedlex.admin.ch/eli/cc/2022/491/en
- **(d)** `[条文]`
- **(c)**

> "c. **sensitive personal data** means: […] 2. data relating to health, the private sphere or affiliation to a race or ethnicity, **3. genetic data**, 4. biometric data that uniquely identifies a natural person […]"

→ **スイス法でも遺伝データは sensitive personal data である。**施行日 2023-09-01 は依頼書の記述どおりで**正しい**。

#### FDPIC の説明

- **(a)** FDPIC（スイス連邦データ保護情報委員）"Adequacy" ページ
- **(b)** https://www.edoeb.admin.ch/en/adequacy
- **(d)** `[公式ガイダンス]`
- **(c)**

> "The EU deemed Switzerland to provide an adequate level of data protection in a decision issued in 2000. This adequacy decision was based on the old Directive 95/46/EC […] This has been replaced by the GDPR. **The EU is currently examining the level of data protection in Switzerland on the basis of the GDPR. In the meantime, the previous adequacy decision continues to apply.** In its report of 15 January 2024, the EU determined that Switzerland has an adequate level of data protection based on the GDPR as well."

→ **スイス当局自身が「GDPR ベースの新決定はまだ審査中で、旧決定が適用され続けている」と述べている。**この状態が続く限り、GDPR 45条3項の新決定に伴う条項（4年ごとの定期審査の組み込み等）はスイスには直接適用されない。

#### 定期審査義務 — 条文構造を区別すること（依頼の5点目）

二段に分かれる。混同しやすい。

| 層 | 根拠 | 内容 |
|---|---|---|
| ① **新しい GDPR 決定にかかる義務** | GDPR Art. 45(3) | "**The implementing act shall provide for a mechanism for a periodic review, at least every four years**" — 実施法令が審査の仕組みを盛り込むものとする、という書き方。**2000/518/EC にはこの条項がない**（同決定 Art. 4 は「通知から3年後に1回」という 2000年当時の一回限りの評価条項） |
| ② **旧11件について委員会が自らに課すもの** | GDPR Art. 97 | COM(2024) 7 final 逐語: "**Article 97 of the GDPR requires the Commission to periodically review these decisions, every four years**, in order to determine whether the countries and territories that received an adequacy finding continue to provide an adequate level of protection" |

旧決定の存続根拠 — **GDPR Article 45(9)**（逐語）`[条文]`:

> "Decisions adopted by the Commission on the basis of Article 25(6) of Directive 95/46/EC **shall remain in force until amended, replaced or repealed** by a Commission Decision adopted in accordance with paragraph 3 or 5 of this Article."

**実務上の見通し**: 第1回審査が 2024年1月15日。「4年ごと」を素直に当てはめれば**次回は 2028年前半**。ただしこれは決定本体の条項ではなく報告書中の委員会の言明なので、前倒しも遅延もありうる（第1回は Schrems II を理由に大幅に遅れた）。

#### 2024年以降の動き — 停止・撤回・係争なし

- **(a)** EDPB Letter to the European Commission on its review of its eleven adequacy decisions adopted under Directive 95/46/EC、**2024年12月5日**（Anu Talus → Michael McGrath）
- **(b)** https://www.edpb.europa.eu/system/files/2024-12/edpb_letter_20241205_european-commission-review-of-11-existing-adequacy-decisions_en.pdf
- **(d)** `[公式ガイダンス]`
- 内容: **方法論の透明性向上の要請**であって、スイスの十分性に対する異議ではない。

**2025年・2026年を通じて、スイスの十分性認定に対する停止・撤回・司法上の挑戦は確認されなかった**（EUR-Lex の法的状態、委員会 adequacy ページ、FDPIC ページ、CJEU 係属事件を検索）。

> **【食い違い・軽微】** 上記 EDPB 書簡の日付を「12月6日」とする二次解説があるが、EDPB のファイル名と本文は **20241205** ＝ 12月5日。12月6日は公表日。

### 7.2 十分性の効果 — SCC は不要

**回答: EU からスイスへの移転に、SCC その他 Art. 46 の適切な保護措置は不要である。**

- **(a)** GDPR **Article 45(1)**
- **(b)** https://gdpr-info.eu/art-45-gdpr/
- **(d)** `[条文]`
- **(c)**

> "**A transfer of personal data to a third country or an international organisation may take place where the Commission has decided that the third country** […] **ensures an adequate level of protection. Such a transfer shall not require any specific authorisation.**"

対比 — **Article 46(1)**（逐語）:

> "**In the absence of a decision pursuant to Article 45(3)**, a controller or processor may transfer personal data to a third country or an international organisation only if the controller or processor has provided appropriate safeguards […]"

> **ただし十分性が免除するのは「移転手段の要件」だけである。**GDPR 9条（特別カテゴリの処理根拠）、6条（適法性）、5条（原則）、35条（DPIA）は EU 側の管理者に引き続きかかる。**移転先がスイスであっても、そもそも遺伝データを処理してよいかは §1.3–§1.5 の問題として別に立つ。**

### 7.3 逆向き — スイスから外へ出す場合（別問題）

判断主体は **FDPIC ではなく連邦参事会（Federal Council）**である。旧 DSG 下では FDPIC が参考リストを維持していたが、改正 FADP で拘束力あるリストとして連邦参事会の権限に移った。

- **(a)** FADP, **SR 235.1**, **Article 16(1)**
- **(b)** https://www.fedlex.admin.ch/eli/cc/2022/491/en
- **(d)** `[条文]`
- **(c)**

> "Art. 16 Principles. 1 Personal data may be disclosed abroad if **the Federal Council has decided that the legislation of the State concerned or the international body guarantees an adequate level of protection.**"

- **(a)** Ordinance on Data Protection (DPO), **SR 235.11**, of 31 August 2022（Status as of 15 September 2024）、**Annex 1**（Art. 8 para. 1）
- **(b)** https://www.fedlex.admin.ch/eli/cc/2022/568/en#annex_1
- **(d)** `[条文]`
- **(c)** 表題と該当部分（逐語・抜粋）

> "**States, territories, specified sectors in a State and international bodies that guarantee an adequate level of data protection**
> 1 Germany* 2 Andorra*** 3 Argentina*** 4 Austria* 5 Belgium* […] 22 Island* […] 27 Liechtenstein* […] 32 Norway* […] 39 United Kingdom** […] 44 United States***"
> 脚注: "* The assessment of the adequacy of data protection includes the disclosure of personal data in accordance with Directive (EU) 2016/680."

**回答（依頼の確認点）**: EU 加盟国は**国ごとに個別に列挙**されており（「EU」という束ではない）、EEA の Iceland（"Island" と表記）・Liechtenstein・Norway も入っている。したがって **CH → EU 方向も追加の移転手段は不要。双方向で自由に流れる。**

改正履歴（逐語）: "Amended by No I of the O of 14 Aug. 2024, in force since 15 Sep. 2024 (AS 2024 435)"

### 7.4 米国クラウドへの onward transfer

| # | 事実 | 出典 | 種別 |
|---|---|---|---|
| 1 | **Schrems II**: CJEU judgment of **16 July 2020**, Case **C-311/18**。Privacy Shield（Decision 2016/1250）無効。SCC は有効を維持 | — | `[二次解説]` |
| 2 | **現行の EU-US 枠組**: Commission Implementing Decision **(EU) 2023/1795** of **10 July 2023**（notified C(2023) 4745）、OJ **L 231/118, 20.9.2023** | https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32023D1795 | `[条文]` |
| 3 | **Latombe 第一審**: General Court, Case **T-553/23**, judgment **3 September 2025**, ECLI:**EU:T:2025:831**（第10拡大部）。**請求棄却 ＝ DPF 有効** | https://curia.europa.eu/site/upload/docs/application/pdf/2025-09/cp250106en.pdf | `[公式ガイダンス]` |
| 4 | **上訴係属中**: **C-703/25 P**、上訴提起 **2025-10-31**、上訴理由は OJ に **2025-12-22** 公表。**2026年9月時点で判決・AG 意見なし** | https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=OJ:C_202506610 | `[条文]`（OJ 公示） |
| 5 | **DPF は 2026年9月現在も in force。**停止・撤回なし | 委員会 adequacy ページ | `[公式ガイダンス]` |
| 6 | **新しい圧力（2026年）**: 米最高裁 **Trump v. Slaughter**, No. **25-332**, decided **29 June 2026**（6-3）。Humphrey's Executor を破棄し、FTC 委員の for-cause 解任保護を違憲とした | https://supreme.justia.com/cases/federal/us/609/25-332/ | `[二次解説]` |
| 7 | **PCLOB の定足数喪失**（2025-01-27、5名中3名解任）が第1回定期審査（COM(2024) 451 final, 2024-10-09）で懸念として指摘済み | https://commission.europa.eu/document/download/25695177-8073-4ce3-bf81-eb816dc6b468_en | `[公式ガイダンス]` |
| 8 | **第2回定期審査は未実施。**decision の recital 211 により次回は3年後＝2027年頃の予定 | — | `[二次解説]` |

**Decision (EU) 2023/1795 Article 1（逐語）** `[条文]`:

> "For the purpose of Article 45 of Regulation (EU) 2016/679, **the United States ensures an adequate level of protection for personal data transferred from the Union to organisations in the United States that are included in the 'Data Privacy Framework List'**, maintained and made publicly available by the U.S. Department of Commerce, in accordance with Section I.3 of Annex I."

→ **十分性は「DPF List に掲載された組織への移転」に限られる。**クラウド事業者が DPF 認証を保持しているかを個別に確認する必要がある。

**EDPB 書簡 2026年7月31日（逐語）**

- **(a)** EDPB Letter, Anu Talus (Chair) → Commissioner Michael McGrath, Brussels, **31 July 2026**, Subject: "US Supreme Court judgment Trump v. Slaughter"
- **(b)** https://www.edpb.europa.eu/system/files/2026-08/edpb_letter_20260731_us_supremecourt_judgment_trump_v_slaughter_en.pdf
- **(d)** `[公式ガイダンス]`
- **(c)**

> "The EDPB wishes to highlight that **the existence and effective functioning of one or more independent supervisory authorities in the third country** […] **is one of the key elements to be taken into account when assessing the adequacy of the level of protection in a third country according to Article 45(2)(b)** of Regulation (EU) 2016/679."

> "Given the potential consequences that the US Supreme Court's judgment may have in the EEA […] **the EDPB asks the European Commission to closely assess whether this development affects the functioning of Commission Implementing Decision EU 2023/1795** and would welcome relevant actions […]"

> **【食い違い】** 二次解説の一部がこの書簡を「委員会に adequacy decision の reconsider を求めた」と要約するが、**原文は "closely assess whether this development affects the functioning"** であり、再考の要求ではない。**原文を採ること。**

**Swiss-US Data Privacy Framework — 存在し、有効**

- **(a)** スイス連邦参事会決定 **2024年8月14日**、**施行 2024年9月15日**
- **(b)** https://www.admin.ch/en/nsb?id=102054
- **(d)** `[公式ガイダンス]`
- **(c)**

> "The certification for US companies and a new US data protection review court in particular will allow personal data to be transferred from Switzerland to certified companies in the USA without any additional guarantees."

DPO Annex 1, No. 44（逐語）`[条文]`:

> "44 United States*** **For personal data processed by organisations certified under the Principles of the Swiss-US Privacy Framework, an adequate level of protection is deemed to be guaranteed** based on the safeguards provided by **Executive Order 14086 of 7 October 2022**, the Rule on the United States Attorney General's Data Protection Review Court of 7 October 2022 and Intelligence Community Directive 126 […] and the **Designation of Switzerland on 7 June 2024** as a country covered by the two-layer redress mechanism, including access to the Data Protection Review Court."

> **【食い違い】日付の混同に注意。**DPF Principles の effective date は 2023年7月17日だが、**スイスからのデータを受領できるようになったのは 2024年9月15日**（スイス側の承認の発効日）。一部の二次解説が「2023年9月15日」と書くのは誤り。この間の1年強、スイスからの移転に DPF は使えなかった。

### 7.5 EHDS 側の移転規律

- **(a)** Regulation (EU) 2025/327, **Article 90**
- **(b)** https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202500327
- **(d)** `[条文]`
- **(c)**

> "Transfer of personal electronic health data to a third country or an international organisation shall be granted **in accordance with Chapter V of Regulation (EU) 2016/679.** Member States may maintain or introduce further conditions on international access to, and transfer of, personal electronic health data, including limitations, **in accordance with Article 9(4) of Regulation (EU) 2016/679**, in addition to the requirements laid down in Article 24(3) and Article 75(5) of this Regulation and in Chapter V of Regulation (EU) 2016/679."

→ **EHDS は独自の移転規律を作らず、GDPR 第5章に送り返している。**かつ、移転については Art. 9(4) の国内上乗せ余地が**明文で維持されている**（§5.6 の二次利用における Art. 9(4) の原則閉鎖とは別扱い）。

- **(a)** Regulation (EU) 2025/327, **Article 88(1)** — 全文は §5.6
- **(d)** `[条文]`
- 内容: **非個人データ（匿名化済み）であっても、Art. 51 の区分に由来し、第三国移転で「合理的に用いられる手段を超える」再識別リスクがあるなら "highly sensitive" とみなされる。**ゲノムはこの条項の主たる想定対象である（Recital (92) が希少疾患・バイオバンクを名指し）。

### 7.6 スイス経路の整理

```
EU の管理者 ──── 遺伝データ ────▶ スイスの解析プラットフォーム
     │                                    │
     │  ① 移転手段: 十分性認定で足りる     │  ④ さらに US クラウドへ？
     │     （SCC 不要。§7.2）              │     DPF List 掲載組織なら
     │                                    │     十分性で足りる（§7.4）
     │  ② ただし処理根拠は別問題            │     ただし上訴 C-703/25 P 係属中
     │     Art. 9(2) 解除事由が必要（§1）   │
     │                                    │
     │  ③ EHDS 経由のデータなら
     │     Art. 90 → GDPR 第5章
     │     ＋ Art. 88(1) の highly sensitive 判定
     │     ＋ 第三国アクセスは 2035年 or 相互主義（§5.8）
```

**要点**: 移転手段の層（十分性）は現状クリアだが、**処理根拠の層（Art. 9(2)）と EHDS 固有の層（Art. 88(1)・第三国経路）は別に立つ。**十分性認定があることは「遺伝データを自由に扱ってよい」ことを意味しない。

---

## 8. 依頼書の前提と実際の対応表

書き手が原稿で前提を書き換える必要がある箇所の一覧。

| 依頼書の記述 | 実際 | 本資料の該当節 |
|---|---|---|
| 「AI Act Article 10(5) を逐語引用し、**五つ**の条件を列挙せよ」 | Art. 10(5) は **2026-07-27 に削除済み**。内容は **Art. 4a** に移り、条件は **六つ**（a–f）。対象は high-risk 以外にも拡大 | §3 |
| 「Art. 2(7) は Art. 10(5) と Art. 59 を除き GDPR に影響しない」 | 改正後は「**Articles 4a and 59**」 | §4.1 |
| 「EHDS Regulation (EU) 2025/327」 | 正しい。11 February 2025 採択、OJ 2025-03-05 | §5.1 |
| 「ゲノムデータは二次利用の対象区分に明示されているか」 | **明示されている。Art. 51(1)(f)。**ただし適用は 2031-03-26 から | §5.3, §5.4 |
| 「EDPB Guidelines 01/2025 on pseudonymisation」 | 存在するが **意見募集版のみ。最終版の採択は確認できず** | §9 |
| 「Recital 70 if relevant」 | 関連する。**Art. 9(2)(g) GDPR の実質的公益**という位置づけを与えており、改正後も生きている | §3.6 |
| 「Switzerland adequacy decision 2026 renewed を確認せよ」 | **更新されていない。**2000/518/EC が現役（2016/2295 で改正済み）。ただし**2026年9月時点で有効であることは確認できた** | §7.1 |
| 「Commission implementing decision Switzerland adequacy 2024/2683」 | **存在しない。**該当文書なし | §7.1、確認できなかったこと #1 |
| 「revFADP は 2023年9月1日施行」 | **正しい。**かつ改正 FADP は遺伝データを sensitive personal data に明示的に含める（Art. 5(c)(3)） | §7.1 |
| 「Art. 9(4) の例を2〜3件」 | **5件を確認。**条文が 9条4項を名指しするのはイタリアとフランスのみ。ドイツは名指しなし（上記 #5） | §1.7 |
| 「EDPB Opinion 28/2024 はモデルが個人データを含みうると述べているか」 | **述べている。**para 34「**cannot, in all cases, be considered anonymous**」。依頼書の理解は正確 | §4.3 |

---

## 9. 未成立だが追跡すべきもの（Digital Omnibus の GDPR 側）

**2026-09-13 時点で提案のまま。GDPR は現行どおり読む。**成立すれば §1・§2 の前提が動く。

- COM(2025) 837、2025-11-19 公表。ファイル参照 **2025/0360(COD)**
- AI 側は分離・先行して成立（Regulation (EU) 2026/1744）。**GDPR / ePrivacy / NIS2 / Data Act 側は交渉中**
- 主な提案内容: Art. 4 の個人データ定義の改正（*EDPS v SRB* の相対的アプローチの条文化）、新 **Art. 9(2)(k)**（AI の開発・運用における特別カテゴリの付随的・残余的処理）、新 Art. 9(5)、新 **Art. 41a**（仮名化データが個人データでなくなる基準を委員会の実施行為で定める）、新 **Art. 88c**（機械学習モデルの開発・運用における正当な利益）、「科学研究」の定義
- EDPB / EDPS は個人データ定義の狭隘化に**反対**（§4.7）
- ⚠️ 成立時期・最終内容ともに**確認できず**

**関連ガイダンスの現況**

| 文書 | 状態（2026-09-13） |
|---|---|
| EDPB **Guidelines 01/2025 on Pseudonymisation**（PDF 表紙 "Adopted on 16 January 2025"） | 意見募集版のみ（募集は 2025-03-14 に終了）。**最終版の採択は確認できず** |
| EDPB **Guidelines 1/2026 on scientific research**（adopted 15 April 2026） | 意見募集版。**最終版は確認できず**。【食い違い】一部二次解説は採択日を16日、募集期限を6月26日とする（PDF 表紙は15日） |
| EDPB **Guidelines 02/2026 on Anonymisation**（adopted 07 July 2026） | 意見募集中（**2026-10-30 まで**）。未確定 |
| EDPB **Guidelines 03/2026 on web scraping in generative AI**（adopted 07 July 2026） | 意見募集中（2026-10-30 まで） |
| EDPB × 委員会 **AI Act–GDPR 統合ガイドライン** | **未公表。**Joint Opinion 1/2026 が「2026年内に発出」と予告 |

---

## 確認できなかったこと

本資料で一次確認が取れなかった事項を、すべてここに集める。**原稿でこれらに触れる場合は、追加照合を行うか、不確実として明示すること。**

### §7（国際移転）

1. **「Commission implementing decision Switzerland adequacy 2024/2683」** — **存在しない（確認できず）。**EUR-Lex、委員会 adequacy ページ、FDPIC のいずれにも該当なし。**依頼書の前提が誤り。**スイスの決定は差し替えられていない（§7.1）。
2. **EU-US DPF の第2回定期審査** — **未実施。**decision の recital 211 により次回は 2027年頃の予定だが、`[二次解説]` レベル。
3. **上訴 C-703/25 P（Latombe）の判決時期** — **確認できず。**2026年9月時点で判決・AG 意見なし。
4. **Trump v. Slaughter 判決が DPF の十分性に与える影響についての委員会の判断** — **確認できず。**EDPB が 2026-07-31 に照会した段階（§7.4）。

### §1（GDPR 国内上乗せ）

5. **イタリア: 2-septies 条にもとづく遺伝データ専用 misure di garanzia** — **未採択。**garanteprivacy.it のトピック検索全件、2023〜2026年の provvedimenti、行政透明性ポータル、公開意見募集を確認。2019年措置が現役。
6. **イタリア: Normattiva の公式統合条文** — **未取得。**brocardi.it / studiolegalestefanelli.it の再録で確認。**公式版での再確認を推奨。**
7. **イタリア: Codice privacy 110-bis 条の2017年原始条文**（遺伝データを再利用対象から明示的に除外していたとされる "ad esclusione di quelli genetici" の文言） — **確認できず。**`[二次解説]` にとどまる。
8. **フランス: legifrance.gouv.fr の直接取得** — **Cloudflare により一律 HTTP 403。**CNIL の法令再録（頁日付 2024-11-15）と codes.droit.org の PDF を使用。**Loi 78-17 の条文は 2024年11月以降の改正を反映していない可能性がある**（ただし art. 75 は Legifrance 現行版 ID と文言一致を別途確認済み）。
9. **フランス: ANS の HDS 参照基準 v2.1 のスケジュール** — esante.gouv.fr の告知ページが HTTP 404。**一次確認できず。**現行 v2.0 の PDF 自体は取得・検証済み。
10. **ドイツ: GenDG の公式英訳** — **存在しない**（gesetze-im-internet.de の翻訳一覧を確認。遺伝関連で掲載されているのは GenDV のみ）。本資料の GenDG 英訳は筆者訳。
11. **ドイツ: Berlin LKG § 25 等の州法の一次確認** — gesetze.berlin.de が JavaScript 必須の SPA で静的取得不可。再録サイト経由のため実質 `[二次解説]`。
12. **ドイツ: GenDG § 2(2) Nr. 1 の「zu Forschungszwecken（研究目的）」の語義** — **未確定。**Bundestag 調査局 WD 9 - 3000 - 098/19 が逐語で "Nicht abschließend geklärt ist bislang die Frage, was unter dem Begriff „zu Forschungszwecken" […] zu verstehen ist." と述べている（https://www.bundestag.de/resource/blob/706276/5996ae006ab738e4d22e0071f8efdaa8/WD-9-098-19-pdf.pdf `[公式ガイダンス]`）。**§6 の AI Act 側の「科学研究」境界問題と同型の未決である。**
13. **スペイン: Ley 14/2007 の 2022-09-06 以降の改正** — BOE 統合版に "Última actualización publicada el 06/09/2022"。**以後の改正なしと推定**するが、断定的確認ではない。
14. **フィンランド: 552/2019 の条文本体** — **未取得。**Finlex が JavaScript で本文配信、WebFetch・curl・開放データ API の3経路すべて失敗。**Finlex 公式英訳は存在しない**（`/fi/lainsaadanto/saadoskaannokset/2019/eng/552` は HTTP 404）。STM が英訳 PDF を公開するがスキャン画像・2019年版で 2025年改正未反映。施行日 2019-05-01 は `[二次解説]` レベル。52条の「匿名結果のみ」は Findata の公式説明による引用であり、**条文の逐語ではない**。
15. **フィンランド: バイオバンク法 688/2012 の置き換え** — **成立していない。**2018年・2020-21年の2度の全面改正草案はいずれも成立せず、2022年の部分改正（671/2023）のみ。事業 STM111:00/2024 が 2027-01-01 / 2028-01-01 施行を予定するが、**政府提案の国会提出の事実は確認できず。**
16. **GDPR Article 89(1) の第2文以降の完全逐語** — 複数の再録サイトで一致する文言（"Those safeguards shall ensure that technical and organisational measures are in place in particular in order to ensure respect for the principle of data minimisation."）は得たが、仮名化・識別不能化に関する後続部分の一次 PDF からの完全逐語は**未取得**。
17. 「加盟国は新しい適法根拠を加えられず、保護水準を下げられない」という Art. 9(4) の一方通行性 — `[二次解説]` 複数で一致するが、**一次条文に明文はない**。解釈である。

### §2（匿名化）

18. **EDPS TechDispatch のゲノム専用号** — **確認できず**。TechDispatch には Neurodata (#1/2024)、Federated Learning (#1/2025) 等があるが、ゲノム／遺伝データ専用号は見つからず。EDPS の索引ページが HTTP 202 を返したため、**網羅的な否定ではない**。
19. **EDPS 単独のゲノムデータ識別可能性に関する Opinion / Paper** — **確認できず**。2020年の Preliminary Opinion on data protection and scientific research の PDF は HTTP 403 で取得不可。
20. **CNIL の遺伝データ匿名化に関する独立した公式見解** — **確認できず**。
21. **ドイツ DSK が EDPB Guidelines 1/2026 を受けて立場を再検討している件** — `[二次解説]`（LDA Brandenburg）のみ。**DSK 自身の公式声明は確認できず**。
22. **EDPB-EDPS Joint Opinion 03/2022（EHDS）における遺伝・ゲノムデータへの言及の全容** — EDPS サイトの PDF が HTTP 403 で取得できず、para 41（混合データセット、§2.11）のみ別経路で取得。**提案 Art. 33(1)(f) に関する具体的な勧告の有無・内容は確認できず**。なお同 Opinion がよく知られた除外勧告は wellness アプリに関するものであって、遺伝データではない。

### §3–§4（AI Act）

23. **Regulation (EU) 2026/1744 Recital 9 の全文** — 冒頭の一文のみ逐語取得。**残りは確認できず**（要旨のみ）。
24. **AI Act Recital 70 が Digital Omnibus により改正されたか** — artificialintelligenceact.eu は改正の表示なしと報告。**改正がないことの積極的確認は取れていない**。
25. **EDPB Opinion 28/2024 の採択日が 17日か 18日か** — PDF 表紙とサイトが**食い違い**、EDPB による説明は**確認できず**。
26. **EDPB-EDPS Joint Opinion 1/2026 の採択日が 20日か 21日か** — 同様の**食い違い**。
27. **EDPB Statement 3/2025** — 番号自体の存在と題名が**確認できず**。AI Act–GDPR interplay を扱う Statement は 2024年の 3/2024 のみ。EDPB の statements 一覧ページが 404 を返したため、**網羅的な否定ではない**。
28. **EDPB-EDPS Joint Opinion 5/2021（AI Act 提案）の本文** — 未取得。**逐語引用なし**。題名・日付・URL のみ確認。
29. **AI Act × GDPR 統合ガイドライン** — **未公表**（2026-09-13 時点）。EDPB のニュースフィードで実質的な全体会合ニュースは 2026-07-30 が最後。

### §5（EHDS）

30. **COM(2022) 197 原提案における Art. 51 の対応条番号**（「Article 33 だった」か） — **確認できず**。原提案本文を照合していない。
31. **EEA 協定への EHDS 編入状況**（EEA Joint Committee Decision の有無・番号・日付） — **確認できず**。EFTA の EEA-Lex ページが Cloudflare により取得不可。検索結果の要約は「under scrutiny（未編入）」だが**一次確認なし。断定して書かないこと**。
32. **Art. 91(2) の相互主義 implementing act が、いずれかの第三国について既に採択されたか** — **確認できず**。TEHDAS2 は 2026年4月時点で「時期の見通しがない」と述べている。
33. **欧州委員会の EHDS FAQ 文書の逐語内容** — 存在は言及されているが本文未取得。
34. **EHDS 発効日の 25日／26日の食い違いについての EU 側の説明** — **確認できず**。EUR-Lex と委員会ページの双方が EU 公式のまま矛盾している。

### §6（研究免除）

35. **AI Act Art. 2(6) の適用範囲に関する委員会・AI Office の公式解釈指針** — **確認できず**。AI Act Service Desk はリサイタルの再掲のみ。
36. **解析サービス提供が "placing on the market" にあたるかを判断した判例・行政先例** — **確認できず**。
37. **Finck (2025) が第三者提供と例外喪失の関係を論じているか** — **論じていないことを確認**（"sole purpose" の文言からの示唆にとどまる）。

### 方法論上の注記

38. ⚠️ **自己検証の性質について** — 本資料の逐語引用の抽出と、その正確性の点検は、抽出を行ったのと同じ文脈が行っている。**独立した検証ではない。**公表物で使う前に、記載した URL から原文を直接確認すること。とくに §3.4（Article 4a）と §5.3（Article 51）は結論を左右する条文であり、官報の原文にあたること。
39. 本資料では、法律事務所ブログ・IAPP 等の `[二次解説]` を**事実記述には用いていない**。例外は、明示的に `[二次解説]` と標識した箇所（Arnold & Porter の日付、GA4GH のブリーフ、Art. 9(4) 一方通行性の解釈、DSK 再検討の情報）のみである。
