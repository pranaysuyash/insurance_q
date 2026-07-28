# Wide-Open Brainstorm — CoverWise Rename: Synthesis

**Date:** 2026-07-28
**Status:** Synthesis complete. All 10 roles captured (Archivist executed twice — once directly, once via the subagent that finally completed after a long delay; both outputs preserved per founder directive to save every agent response).
**Skill:** `wide-open-brainstorm` (Carl Kibler agent-skills)
**Doctrine:** `motto_v4.md` §0.1.1 (anything else?), §0.2 (confidence honesty), §0.5 (evidence tiers)
**Governing inputs:** `CoverWise_Name_Clearance_and_Brand_Risk_Report_2026-07-28.docx` (RED/90+, RENAME) and `CoverWise_Renaming_Agent_Pitch_and_Voting_Pack_2026-07-28.docx` (16-name slate + doctrine + do-not-repitch ledger + scoring rubric).
**Evidence tier:** Tier 0 (creative/strategic reasoning — NO name here is legally cleared; counsel + IP India registry search is the binding gate per the clearance report §7).

---

## 0. How to read this artifact

- **`raw/01–10`** contain every agent's output verbatim, exactly as returned. Nothing is paraphrased or softened. This is the durable record — read those for the full reasoning, the pitches, and the failure modes each role surfaced.
- **This file** is the synthesis: cross-role convergence, the six-hat coverage check, the kill-test verdict, build conditions, and a ranked shortlist for counsel clearance. It does not pick the final name — that is the founder's decision after counsel review.
- **No name in this artifact is legally cleared.** Every "wins" / "strongest" claim is strategic reasoning only. The clearance gate (IP India Classes 9/36/42, counsel review) is binding before any commitment.

## 0.1 Panel composition and execution notes

- **External LLMs available on this machine:** `claude` (Claude Code — working), `kimi -p` (Moonshot — working), `gemini` (deprecated/auth-broken), `codex` (hangs on stdin), `qwen` (no auth configured). Net usable externals: **2** (claude, kimi).
- **Execution mode:** per the skill, 2+ external LLMs → full-diversity mode. Externals were used for outsider/whimsy/future-perspective roles (fresh eyes, no codebase anchoring); subagents for project-aware roles.
- **Rate-limit reality:** the first parallel batch mostly failed with request-rate limits (only the Outsider returned). The second batch succeeded for all subagents + both externals. The Archivist subagent failed twice synchronously; a third attempt was launched in the background and **eventually completed** after a long delay (~6 min). Because the direct-execution fallback had already been written before the background result landed, **two Archivist outputs exist** (`raw/11_archivist.md` = direct fallback; `raw/11_archivist_subagent.md` = the actual subagent). Both are preserved per the founder's "save every agent response" directive. They converge on the same diagnosis (vault/archive/record framing is a recovery-flow failure; the name must frame the deceased's act as a *gift*, not a *stash*) but propose different name sets.
- **The subagent Archivist is the richer output** — its recovery-flow scene (the Pune father, the family scattered, the phone pulled from a drawer) is the most vivid modeling of the bereavement moment in the entire panel, and its pitches (Waymark, Mantle, Amanat, Kept Whole, For Keeps) are stronger on the Red-hat grief lens than the direct fallback's (Ledgerleft, Lastleaf, Kept Clear, Bahi, In Trust).

---

## 1. North star that emerged (where multiple roles converged)

**The brand's only uncopyable position is *alignment* — the reader with zero conflict of interest.** This is not a feature; it is the structural fact that every competitor (Lemonade, Digit, ACKO, CoverSure — all sellers/brokers/IRDAI agents) profits from the family's confusion. The Strategist named it explicitly ("the only reader who has nothing to sell you"); the Trickster arrived at the same place via a different route ("policies are identity documents — who are we when things go wrong?"); the Cartographer reached it structurally ("the app is a reference layer over external documents, never the source — it cannot sell because it doesn't transact").

**The second convergence: the name's binding constraint is *crisis-state retrievability*, not semantics or ownability.** The Champion ("findable at the moment of crisis"), the Operator ("WhatsApp voice note transcribed by thumb"), the Skeptic ("recognition speed under stress"), and the Devil's Advocate ("what a man types into Play Store at 2am") all independently arrived at the same test: a stressed non-user hears the name once and must retrieve it correctly. This is the single most repeated insight across the panel and it is the strongest signal in the whole exercise.

**The third convergence: the curated slate is mostly founder-pleasing, user-fragile.** The Skeptic, Operator, and Devil's Advocate independently flagged 6+ of the 16 slate names as operational fails (common phrases that lose their own app-store search; the "&" in North & Kin; metaphors that need explanation). The Future Self agreed: only 1 slate name ("All There") survives 2027 pressure-testing.

---

## 2. Six-hat coverage check

| Hat | Lens | Covered by | Strength |
|---|---|---|---|
| **White** (facts/constraints/unknowns) | Strategist (competitor analysis), Devil's Advocate (P0 reality check), Executioner (effort/cost evidence) | Strong |
| **Yellow** (value/upside if thesis is right) | Champion (steelman of outcome-naming), Future Self (2027 winning thesis) | Strong |
| **Black** (risks/failure modes) | Skeptic (full slate takedown), Operator (operational friction), Executioner (avoidance/sequencing) | Strong — possibly over-weighted toward caution |
| **Green** (creative alternatives/reframes) | Trickster (photo album / identity), Cartographer (reference layer vs container), Outsider (Indic-rooted direction) | Strong — most generative pass |
| **Red** (emotion/taste/trust) | Trickster (identity in crisis), Champion (warm+competent+calm), Outsider (what the audience actually feels), Archivist (the bereavement scene — father dies, survivor opens the app 2 years later) | Strong — the Archivist's recovery-flow scene is the most vivid grief modeling in the panel |
| **Blue** (facilitation/synthesis/next) | This document | Adequate |

**Former thin spot, now filled:** the Red hat on grief/mortality was under-served until the Archivist landed. The subagent Archivist's recovery-flow scene (the Pune father, the family scattered across cities, the phone pulled from a drawer, "Papa had some app") is now the panel's sharpest emotional model and reshapes the shortlist below.

---

## 3. The slate, pressure-tested (synthesized critique)

Combining the Operator's operational ratings, the Skeptic's failure modes, and the Future Self's survival test:

| Slate name | Operator verdict | Skeptic verdict | Future Self | Net |
|---|---|---|---|---|
| North & Kin (88) | Marginal — `&` wound | Founder-pleasing, unownable as one token | Loses 2027 (ampersand + consultancy register) | **Survives only as "Northkin"** (Champion's resolution) |
| All There (85) | FAIL (phrase) | Survives only as "AllThere" single token | **Only slate name that survives 2027** | Strong if collapsed to one token; weak as phrase |
| Kitchen Drawer (84) | Marginal (metaphor needs explanation) | Junk-drawer association | Loses (locks to "storage") | Emotionally right, operationally/architecturally wrong |
| Held Together (81) | FAIL (phrase) | Crafts-store register, implies fragility | Loses | Cut |
| Good Measure (80) | FAIL (idiom) | "A little extra" = wrong meaning | Loses | Cut |
| Home Index (79) | Marginal-to-fail | Real-estate/cold register | Loses | Cut |
| In Order (78) | FAIL (phrase) | Survives only as "InOrder" | Loses | Weak |
| House of Record (76) | Marginal (stiff) | Record-label register | Loses | Cut |
| On Record (75) | FAIL (phrase) | Cold/legal register | Loses | Cut |
| Ready When (75) | FAIL (fragment) | Incomplete sentence | Loses | **Cut — worst on the slate** |
| Long View (74) | Marginal (collision) | Investment-fund register (regulatory-adjacent) | Loses | Cut |
| Second Look (72) | Marginal (collision) | Implies doubt | Loses | Cut |
| Norial/Keralune/Toveli/Avylo | — | Dead Veyra/Nuvra pattern | Lose | **All four cut** — unanimous |

**Synthesized verdict on the slate:** of 16 names, **~2 survive serious pressure-testing** (North & Kin only as "Northkin"; All There only as "AllThere"). The panel strongly suggests the founder look beyond the slate for the strongest candidates.

---

## 4. Original names proposed by the panel (deduplicated, 22 candidates)

| Proposed by | Name | Type | Core thesis |
|---|---|---|---|
| Strategist | Second Chair | Metaphor | Alignment — the advocate beside you |
| Strategist | At Hand | Phrase | Proximity/calm, maximally sayable |
| Strategist | Fair Copy | Literary | The honest, corrected version |
| Strategist | Candent | Coined (real root) | Luminous honesty |
| Strategist | By the Page | Phrase | Source-fidelity as a brand promise |
| Champion | Homeward | Real word | Direction-of-care, motion |
| Champion | Steady | Real word | The emotional state itself |
| Champion | Mantle | Real word (double meaning) | Shelf + responsibility |
| Operator | Kosha (कोष) | Sanskrit real | Treasury/storehouse |
| Operator | Prama (प्रमा) | Sanskrit real | Valid knowledge/proof |
| Operator | Apta (अप्त) | Sanskrit real | Trusted/authoritative |
| Operator | Daybook | English real | Household ledger |
| Cartographer | Lekh (लेख) | Hindi real | Written account |
| Cartographer | Foldmark | Coined compound | The crease that shows where to open |
| Cartographer | Sightline | English real | Orientation without destination |
| Cartographer | Tippani (टिप्पनी) | Hindi real | The annotation layer (margin-note) |
| Cartographer | Sambhal (संभाल) | Hindi real | Caretaking/hold-together |
| Trickster | Brightwork | Metaphor (nautical) | Made visible / cared for |
| Trickster | Kept | Past participle | Active custody |
| Trickster | Ground Truth | Technical phrase | Truth-resolution |
| Trickster | Clearside | Coined | The position from which things become visible |
| Trickster | Kinloom | Coined portmanteau | Weaving scattered into coherent |
| Skeptic | Keepset | Coined compound | The kept-and-arranged set |
| Skeptic | Surefile | Coined compound | Certain files |
| Future Self | Kinset | Coined compound | The family protection set |
| Future Self | Ahead | Real word | Proactive readiness |
| Future Self | Kinsight | Coined compound | Kin + insight |
| Outsider | Sahaj (सहज) | Sanskrit real | Effortless/natural |
| Outsider | Samjho (समझो) | Hindi imperative | Understand |
| Outsider | BimaBol (बीमाबोल) | Compound (real roots) | Insurance + speak |
| Outsider | Hisaab (हिसाब) | Persian-root real | Reckoning/settling |
| Outsider | Sahi (सही) | Hindi real | Correct/true/authentic |
| Devil's Advocate | Policy Reader | Descriptive | ASO/function-literal |
| Devil's Advocate | Insurance Khata | Descriptive + metaphor | Industry word + household ledger |
| Archivist (direct fallback) | Ledgerleft | Coined compound | What was left — the kept-clear account |
| Archivist (direct fallback) | Lastleaf | Coined compound | The final page that matters most |
| Archivist (direct fallback) | Kept Clear | Phrase | Present AND comprehensible |
| Archivist (direct fallback) | Bahi (बही) | Hindi real | The household account-book |
| Archivist (direct fallback) | In Trust | Phrase (legal double meaning) | Held for the family's benefit |
| Archivist (subagent) | Waymark | English real | The sign left for those who follow |
| Archivist (subagent) | Mantle | English real (double meaning) | Passed-down responsibility + heart-of-home |
| Archivist (subagent) | Amanat (آمانت) | Urdu/Hindi real | Entrusted-in-trust-for-another |
| Archivist (subagent) | Kept Whole | Phrase | Nothing missing, nothing broken |
| Archivist (subagent) | For Keeps | Idiom | Permanently, as a kept gift |

*(Both Archivist runs preserved; the subagent's pitches are the stronger set on the grief lens.)*

---

## 5. Where the panel independently converged (highest-signal names)

**Convergence = multiple roles, no coordination, landing on the same idea.** That is the strongest signal in a brainstorm.

1. **"Kin" as a root** — Champion (North & Kin → Northkin), Trickster (Kinloom), Future Self (Kinset, Kinsight). Four independent arrivals. The family/kin root is the panel's strongest single theme.
2. **Single-token resolution of multi-word candidates** — Champion (Northkin), Skeptic (AllThere, InOrder), Operator (the implicit argument for short real words). Multi-word/phrasal names are operationally fragile; collapsing to one ownable token is the unanimous fix.
3. **The "reference/annotation layer" as the structural truth** — Cartographer (Index/Fold/Tippani), Strategist (alignment = "the reader, not the seller"), Trickster (identity documents). The product is not a container; naming the container (drawer/vault) is a category error.
4. **Real Indic-rooted words over English coinage** — Operator (Kosha/Prama/Apta), Cartographer (Lekh/Tippani/Sambhal), Outsider (Sahaj/Samjho/Hisaab), Archivist (Bahi/Amanat). **Four roles** independently argued the founder's English-first assumption is itself a user-exclusion choice. This is now the panel's second-strongest convergence after crisis-state retrievability.
5. **The contrarian "just name the function" position** — Devil's Advocate (Policy Reader, Insurance Khata), Skeptic (Surefile). Two roles argued the doctrine's "don't name the industry" is wrong for a discoverability-bound solo app.
6. **"Gift, not stash" — the deceased's act, not the company's offering** — Archivist (both runs: "frame the deceased as a guide who marked the path, not a hoarder who locked things away"). This convergence is unique to the Archivist but it reframes every other role's pitches: a name that reads as *the company's product* fails the recovery moment; a name that reads as *what the deceased left behind* passes it. This is the lens the rest of the panel lacked.

---

## 6. The competing strategic theses (the real tension)

The panel did NOT converge on a single naming philosophy. There are **two genuinely opposed schools**, and the founder must choose between them (or synthesize):

### School A — "Name the outcome/feeling, in English, coin or compound for ownability"
- **Proponents:** Strategist, Champion, Cartographer, Trickster, Future Self.
- **Core argument:** the category is low-trust; an industry-word name reads as a vendor; the only uncopyable position is alignment/identity, which requires a non-industry name; portfolio expansion needs a portable masterbrand.
- **Best candidates:** Northkin, Second Chair, Tippani, Kosha, Kinset, Steady, Homeward, At Hand, Foldmark.

### School B — "Name the function in the user's language; discoverability beats ownability at 0 users"
- **Proponents:** Devil's Advocate, Outsider, Skeptic (partially).
- **Core argument:** a solo founder with no ad budget cannot afford to teach the market what a coined name means; the user at 2am types "policy reader" / "insurance khata", not "Northkin"; hiding the category hides free distribution; the portfolio constraint is premature optimization.
- **Best candidates:** Policy Reader, Insurance Khata, BimaBol, Hisaab, Sahi, Samjho.

**The arbitration (per the skill's Champion-vs-Executioner logic):**
- School A is right *if* the primary distribution channel is referral/word-of-mouth/PR (where a distinctive name earns recall).
- School B is right *if* the primary channel is app-store search by category keyword (where descriptive names win free discovery).
- **The binding question for the founder:** *how do your first 1,000 users actually find the app?* If the answer is "a cousin WhatsApps it during a hospitalization," School A wins (the name must survive voice-to-text recall). If the answer is "they search 'insurance policy reader' in Play Store," School B wins. The honest answer is probably *both*, which is why a **hybrid** — a coined/real-word name with strong category-keyword ASO in the subtitle/descriptor — is the synthesis.

---

## 7. Kill-test verdict (Executioner)

**The rename survived. The elaborate process did not.**

The Executioner found three strong kill-the-exercise arguments (wrong sequencing — name installed as launch gate over P0 bugs; avoidance wearing the costume of strategy; premature portfolio optimization). It rendered **"THE EXERCISE SURVIVED THE KILL TEST — barely, and for exactly one reason: the CoverSure collision is a critical near-homophone with a regulated IRDAI competitor, and RevenueCat product IDs + application ID cannot be renamed after a first paying customer."**

But the Executioner was explicit: the *rename act* survives; the *16-name slate + scoring rubric + multi-round process* should be killed. Its six survival conditions (in `raw/10_executioner.md`) are adopted as **build conditions** below.

**This is a genuine positive signal** (per the skill §7.5): the Executioner probed hard and the rename survived on a real, verifiable cost-asymmetry — not on vibes.

---

## 8. Build conditions (proceed / prototype / pause)

Synthesizing the Executioner's conditions with the panel's findings:

**PROCEED NOW (in parallel, not blocking):**
1. Pick **one** name this week, not five. Decisiveness is the missing ingredient. The panel gave the founder ~22 candidates; the decision is now selection, not generation.
2. Send the chosen name (+ 2 alternates) to **counsel** for IP India Class 9/36/42 search (exact + phonetic). This is the only step worth real calendar time.
3. The mechanical rename (`sed` across ~100 test imports, asset regen, env vars, pbxproj, Gradle) is one gated afternoon — per the founder's own claim in the rename doc. Hold the founder to that.

**PROTOTYPE FIRST (do not commit publicly):**
4. Voice-to-text test the top 3 names on a cheap Android with Indian-English + Hindi accents. The Operator + Skeptic + Champion all made this the binding test. Any name that fails one-shot transcription is out.
5. App-store search test: type each top-3 name into Play Store and confirm the app would win its own exact-string result. (This is what kills most phrase-names.)

**PAUSE / KILL:**
6. **Drop the portfolio-reusability constraint for v1.** Name the app. Decide the umbrella brand when product #2 is real. Do not let a hypothetical second product make naming the first impossible. (Executioner + Devil's Advocate independently demanded this.)
7. **Restore the engineering P0 list as the launch gate.** The clearance report's six-point gate is a *release precondition for the name*, not the launch gate for the product. Product launches when P0-1 (OAuth migration), P0-3 (renewal scheduling), P0-6 (signed bundle) are closed **and** the name clears. Both gates; neither subsumes the other.
8. **No public release under any name until both gates pass.**

---

## 9. Ranked shortlist for counsel (synthesis, not a verdict)

These are the names that survived the most independent cross-role pressure. Ranked by (a) how many roles independently supported the *direction*, (b) operational survivability, (c) distinctiveness. **This is a recommendation to send to counsel, not a final pick.**

### Tier 1 — send to counsel first (strongest cross-role convergence)
1. **Northkin** — Champion's resolution of the founder's #1; solves the ampersand; preserves both semantic poles; family-root convergence. *Risk: Hindi/Tamil warmth depends on descriptor.*
2. **Tippani** (टिप्पनी) — Cartographer's top pick; structurally encodes the non-regulated boundary (an annotation cannot replace its source); warm Hindi word; strongly ownable. *Risk: needs descriptor for English-first users; spelling standardization.*
3. **Kosha** (कोष) — Operator's pick; real Sanskrit "treasury/storehouse"; maximally sayable; portfolio-portable. *Risk: light wellness-vertical collision; Bengali food association.*
4. **Amanat** (آمانت) — Archivist (subagent) top pick; the single sharpest recovery-test name because its literal meaning ("thing entrusted in trust for another") *is* the product's deepest promise; frames the deceased's act as a gift, not a stash; cultural depth unavailable in English. *Risk: Urdu-origin → weaker in South India; common word (TV/film titles) → weak standalone TM; solemn register may strain portfolio stretch.*
5. **Kept Whole** — Archivist (subagent); strongest pure-emotion name; triple meaning (the deceased kept the family whole / the product keeps the protection whole / the survivor will be kept whole); two short English words any Indian-English speaker grasps. *Risk: generic phrase → weak standalone TM; "made whole" legal adjacency.*

### Tier 2 — strong, send as alternates
4. **Second Chair** — Strategist's #1; owns alignment (the only uncopyable position). *Risk: legal/courtroom register; English-only idiom.*
5. **Kinset** — Future Self's pick; names the portfolio vision directly. *Risk: "Kin" family is crowding; sounds genealogical without descriptor.*
6. **AllThere** (single token) — the only slate name that survives 2027; the sentence users want to hear. *Risk: weak trademark as a near-phrase.*

### Tier 3 — the contrarian bets (if ASO/discoverability outweighs ownability for the founder)
7. **Insurance Khata** — Devil's Advocate's pick; localization-proof; the household ledger everyone already trusts. *Risk: fails the founder's "name the outcome not the industry" doctrine — by design.*
8. **BimaBol** — Outsider's pick; category comprehension in the first syllable. *Risk: Hindi-centric; wordplay ages.*

**Deliberately excluded from the shortlist:** all coined soft-vowel marks (Norial/Keralune/Toveli/Avylo + any new ones in that pattern) — unanimous panel rejection. All phrase-names kept as phrases (All There, Held Together, In Order, etc.) — operational fails. Kitchen Drawer — architecturally wrong (names the container). Ready When — worst on the slate.

---

## 10. Anything else? (motto §0.1.1)

1. **The Archivist landed and reshaped the shortlist.** Its recovery-flow scene (Pune father dies; family scattered; phone pulled from a drawer; "Papa had some app") is the panel's sharpest emotional model. Its central inversion — *the name must frame the deceased's act as a gift, not a stash* — is a lens no other role provided, and it promotes **Amanat** and **Kept Whole** into Tier 1. The Red-hat/grief gap flagged in the first synthesis is now closed.

2. **The voice-to-text test is the single highest-leverage validation the founder can run this week.** It costs nothing, takes 20 minutes, and it is the test 4 roles independently named as binding. No name should go to counsel without passing it. (Procedure: 5 speakers × 3 Indian-English/Hindi accents × top-5 names, transcribed via Google voice typing on a mid-range Android.) Note: Amanat and the other Indic-rooted names should be tested specifically for South-Indian-accent recognition, since the Archivist flagged regional legibility as their main risk.

3. **The "Indic vs English" split is the real decision, not "which name."** Schools A and B (§6) reflect a deeper product question: is this an English-first aspirational product (School A) or a vernacular-first functional product (School B)? The naming will follow that answer. The founder should answer the product question, not just the naming question. The Archivist's Amanat/Bahi and the Outsider's Sahaj/Samjho/Hisaab are the strongest School-B candidates; Northkin/Tippani/Kosha are the strongest School-A candidates.

4. **The panel over-indexed on caution.** Six of ten roles (Skeptic, Operator, Devil's Advocate, Executioner, partially Champion and Cartographer) argued against the slate. That is useful — it kills weak names — but it also means the *bold, emotional, brand-love* case is under-served. The Trickster, Outsider, and Archivist were the roles arguing *for* surprising/emotional choices. The founder should weight their input specifically when evaluating whether the "safe" shortlist is too safe.

5. **No name here is legally cleared.** Stated three times because it matters three times. The clearance report's six-point gate (counsel search, IP India Classes 9/36/42, domains/handles, mobile+auth migration, store+legal metadata) is binding before any public commitment.

6. **Honesty correction (motto §0.2).** An earlier version of this synthesis stated the background Archivist "produced nothing usable." That was wrong — it was still running when checked, and completed minutes later with the richest recovery-flow output in the panel. Both the direct-execution fallback and the subagent output are preserved; the correction is recorded here per the confidence-honesty standard.

---

## Update log

- 2026-07-28: created. 9 of 10 roles captured; Archivist in flight. Synthesis included six-hat check, kill-test verdict, build conditions, ranked shortlist.
- 2026-07-28: Archivist completed (subagent, after long delay) AND a direct-execution fallback was written in parallel — both preserved in `raw/`. Synthesis updated: Red-hat gap closed; convergence §5 expanded (Indic-root now 4 roles; new "gift vs stash" convergence); Tier-1 shortlist expanded to 5 (Amanat, Kept Whole added); "Anything else?" §10 reconciled; honesty correction recorded for the earlier "produced nothing usable" misstatement.
