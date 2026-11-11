# Campus Food Insights — Findings Log

This file records verified facts from each phase of the analysis. Every number comes directly from the R scripts run on `data/dmaProjectdata.csv`.

---

## Questions (Phase 4)

### Q1. Why are high spenders (> Rs 2,000/month) much more satisfied than low or medium spenders?
- **Fact that led to it:** In EDA, Spend Band showed a statistically significant link with satisfaction (`p = 0.0123`): `52.4%` (`11/21`) of High spenders (`> Rs 2,000`) are satisfied versus `18.2%` (`4/22`) of Low spenders and `20.0%` (`9/45`) of Medium spenders.
- **Answer:** High spenders (`n = 21`) report fewer campus outlet meals per day (`0.71` vs `1.01` for `<= Rs 2,000`), slightly more outside orders (`1.10` vs `0.88` per week; `28.6%` heavy outside vs `16.4%`), higher Nescafé use (`57.1%` vs `38.8%`), and lower Yadav Canteen use (`19.0%` vs `32.8%`). However, none of those single outlet, factor, or improvement gaps is statistically significant on its own (`p = 0.220` to `1.000`), and High spenders still ask for Lower Prices (`52.4%`), Better Food Quality (`57.1%`), and Better Hygiene (`52.4%`) just as much as everyone else. In plain terms, students with a larger monthly budget appear more satisfied because they can supplement campus meals and pick freely rather than relying solely on budget campus options, though the survey does not record *which* specific items or off-campus meals they buy.

### Q2. What sets Nescafé users apart from non-users, and does using Nescafé explain their higher satisfaction?
- **Fact that led to it:** Nescafé users (`n = 38`) are more than twice as likely to be satisfied (`39.5%`, `15/38`) as non-users (`18.0%`, `9/50`), a statistically supported difference (`p = 0.0456`).
- **Answer:** Nescafé users pick more outlets overall (`2.58` vs `1.74` outlets on average), spend slightly more (`Rs 1,879` vs `Rs 1,658`, with `31.6%` vs `18.0%` in the High spend band), and—crucially—show higher satisfaction inside *every* spend tier (`30.0%` vs `8.3%` in Low spend, `25.0%` vs `17.2%` in Medium, and `66.7%` vs `33.3%` in High). Still, their decision factors and improvement wishes are nearly identical to non-users (`50.0%` want Better Hygiene, `50.0%` want Better Quality, and `50.0%` want Lower Prices; all `p >= 0.271`). Because the survey asked only for overall campus satisfaction and not outlet-by-outlet ratings, the data cannot prove that Nescafé directly caused higher satisfaction, though Nescafé users consistently rate campus food better across all budgets.

### Q3. Who skips breakfast most often, and how is skipping breakfast linked to outlet choices and meal habits?
- **Fact that led to it:** `70.5%` of respondents (`62/88`) skip breakfast most often, yet Yadav Canteen users appeared to skip breakfast less (`53.8%` vs `77.4%`, borderline `p = 0.0505`).
- **Answer:** Breakfast skipping is widespread across every year (`66.7%`–`80.0%`), gender (`68.8%`–`71.4%`), and diet (`66.7%`–`74.4%`), with no demographic difference (`p >= 0.75`). The clearest behavioral link is outlet choice: Yadav Canteen is used by only `22.6%` (`14/62`) of breakfast skippers versus `46.2%` (`12/26`) of non-skippers (`p = 0.0505`), while Night Canteen leans the opposite way (`29.0%` of breakfast skippers vs `11.5%` of non-skippers, `p = 0.138`, not statistically supported). Breakfast skippers are also twice as likely to report eating `0` campus outlet meals per day (`30.6%` vs `15.4%`). The survey does not measure wake-up times or class schedules, so it cannot verify *why* students skip breakfast.

### Q4. Do Vegetarian and Non-Vegetarian students rely on different food channels or ask for different improvements?
- **Fact that led to it:** In EDA, diet showed borderline differences in heavy outside ordering (`30.8%` Vegetarian vs `10.3%` Non-Veg, `p = 0.0652`), Hostel Mess use (`66.7%` vs `41.0%`, `p = 0.0750`), and Night Canteen use (`12.8%` vs `33.3%`, `p = 0.0982`).
- **Answer:** Vegetarians (`n = 39`) and Non-Vegetarians (`n = 39`) rely on noticeably different channels, though the outlet and delivery differences are borderline at this sample size (`p = 0.065`–`0.104`): Vegetarians use the Hostel Mess more (`66.7%` vs `41.0%`) and Night Canteen less (`12.8%` vs `33.3%`), and order outside `>= 2` times/week three times as often (`30.8%` vs `10.3%`). Importantly, Vegetarians demand **Lower Prices** significantly more often (`56.4%` vs `25.6%` for Non-Vegetarians and `44.4%` for Eggetarians, `p = 0.0206`). Overall satisfaction (`33.3%` Veg, `20.5%` Non-Veg, `33.3%` Eggetarian) does not differ reliably (`p = 0.430`), and Vegans (`n = 1`) have too few responses for any claim.

### Q5. Do dissatisfied students ask for different improvements than neutral or satisfied students, or are the complaints campus-wide?
- **Fact that led to it:** Only `27.3%` of students (`24/88`) are satisfied (`4–5`), while over half demand Better Hygiene (`52.3%`) and Better Food Quality (`50.0%`), and all 4 facility-rating columns were empty.
- **Answer:** Improvement demands are campus-wide rather than limited to dissatisfied students. Across Dissatisfied (`1–2`, `n = 22`), Neutral (`3`, `n = 42`), and Satisfied (`4–5`, `n = 24`) students, nearly identical shares want Better Hygiene/Cleanliness (`54.5%`, `52.4%`, `50.0%`; `p = 0.953`), Better Food Quality (`45.5%`, `50.0%`, `54.2%`; `p = 0.840`), and Lower Prices (`45.5%`, `38.1%`, `45.8%`; `p = 0.773`). Dissatisfied students ask slightly more for Larger Portions (`36.4%` vs `19.0%` Neutral and `20.8%` Satisfied), though this gap may be luck (`p = 0.280`). **What the data cannot answer:** which specific dining facility aspect (seating, staff friendliness, operating hours, or waste management) caused low scores, because all four rating columns were 100% blank.

---

## Cleaning Summary (Phase 1)

- **Raw dataset:** `88` responses and `20` columns collected via Google Forms (`10/11/2026 15:15:14` to `10/11/2026 15:53:33`, a ~38-minute window).
- **Duplicates:** `0` exact duplicate rows across all columns and `0` duplicate answer rows when excluding `Timestamp`.
- **Completely empty columns dropped (6 columns, 100% NA):**
  1. `Untitled Question`
  2. `How would you rate the following aspects of our campus dining facilities? [Infrastructure and Seating]`
  3. `How would you rate the following aspects of our campus dining facilities? [Staff Friendliness]`
  4. `How would you rate the following aspects of our campus dining facilities? [Operating Hours/Availability]`
  5. `How would you rate the following aspects of our campus dining facilities? [Waste Management/Cleanliness]`
  6. `How much do you value the inclusion of specific nutrition information (calories, macros) on campus menus?`
  - *Limitation:* Because all 4 facility-rating questions and the nutrition-information question are completely empty (0 of 88 answered), we cannot analyze ratings for infrastructure, staff friendliness, operating hours, cleanliness, or calorie/macro demand.
- **Text-to-number fixes (`4` distinct rows had messy typed entries; `0` NAs left after cleaning):**
  - `meals_per_day` (2 rows fixed): `"1-2 meals"` parsed to `1` (conservative lower bound via `readr::parse_number()`), and `"1 times"` parsed to `1`.
  - `spend` (2 rows fixed): `"Rs. 2,000/-"` parsed to `2000` (after stripping `"Rs."`) and `"around 1000"` parsed to `1000`.
  - `outside_orders` (2 rows fixed): `"twice a week"` converted to `2` and `"1 times"` parsed to `1`.
- **Helper columns created:**
  - `satisfied`: `1` if `satisfaction >= 4`, else `0`.
  - `skips_breakfast`: `1` if `skipped_meal == "Breakfast"`, else `0`.
  - `heavy_outside`: `1` if `outside_orders >= 2`, else `0`. *Cutoff justification:* `80.7%` of students (`71` of `88`) order outside `0` times (`28`, `31.8%`) or `1` time (`43`, `48.9%`) per week; ordering `2` or more times (`12` at `2` + `5` at `3` = `17` students, `19.3%`) marks the top fifth who rely heavily on outside delivery.
  - `spend_band`: ordered factor with 3 balanced bands — `Low (<= Rs 1,000)`, `Medium (Rs 1,001-2,000)`, and `High (> Rs 2,000)`.
- **Multi-select splitting:** Split `outlets` (9 unique options), `factors` (11 unique options), and `improvements` (11 unique options) into `31` binary `0/1` columns using `stringr::str_detect(..., fixed())`. Verified `0` mismatches between the dummy column sums and original selection counts across all `88` rows.
- **Rare categories flagged (< 8 students):** `Day Scholar` (`4`), `Vegan` (`1`), `Cash` (`2`), `Dinner` skipped (`1`), and `I rarely skip meals` (`5`). Per project rules, no group claims will be made for groups smaller than 8.
- **Saved clean dataset:** `outputs/clean.rds` and `outputs/clean.csv` (`88` rows, `49` columns).


---

## Overall facts (Phase 2)

1. **Sample bias toward 3rd-year male hostel students:** Out of `88` respondents, `75.0%` (`66`) are 3rd Year students (`13.6%` 1st Year, `11.4%` 2nd Year), `95.5%` (`84`) live in the Hostel, and `63.6%` (`56`) are Male (`36.4%` Female). Any findings mainly reflect hostel-dwelling 3rd-year students rather than the whole campus equally.
2. **Several groups have too few responses (< 8) for subgroup claims:** Day Scholars (`4`, `4.5%`), Vegans (`1`, `1.1%`), Cash payers (`2`, `2.3%`), students who skip Dinner (`1`, `1.1%`), and students who rarely skip meals (`5`, `5.7%`) each have fewer than 8 responses.
3. **Diet split is balanced between Vegetarian and Non-Vegetarian:** `44.3%` (`39`) are Vegetarian, `44.3%` (`39`) are Non-Vegetarian, `10.2%` (`9`) are Eggetarian, and `1.1%` (`1`) is Vegan (`too few responses`).
4. **Digital payments dominate campus purchases:** `97.7%` (`86` of `88`) primarily use UPI/QR Code, while only `2.3%` (`2`) use Cash.
5. **Monthly extra food spend averages Rs 1,753:** Excluding prepaid hostel mess fees, students spend an average of `Rs 1,753.41` per month (median `Rs 1,500`, range `Rs 500` to `Rs 4,000`). Half (`51.1%`, `45`) fall in the Medium band (`Rs 1,001-2,000`), `25.0%` (`22`) spend `<= Rs 1,000`, and `23.9%` (`21`) spend `> Rs 2,000`.
6. **Campus outlet meals average about 1 per day:** Students eat an average of `0.94` meals per day from campus food outlets (median `1`, range `0` to `3`). Notably, `23` students (`26.1%`) eat `0` outlet meals per day (likely relying on Hostel Mess).
7. **Most students order outside food at most once a week:** Outside ordering averages `0.93` times per week (median `1`, range `0` to `3`). `31.8%` (`28`) never order outside (`0`), `48.9%` (`43`) order `1` time, and `19.3%` (`17`) are heavy outside orderers (`2` or `3` times/week).
8. **Overall satisfaction is lukewarm (neutral on average):** Satisfaction averages `3.01` out of `5` (median `3`). Nearly half (`47.7%`, `42`) gave a neutral `3`, `25.0%` (`22`) are dissatisfied (`4` gave `1`, `18` gave `2`), and only `27.3%` (`24`) are satisfied (`21` gave `4`, `3` gave `5`).
9. **Breakfast is overwhelmingly the most skipped meal:** `70.5%` (`62` of `88`) skip Breakfast most often, far ahead of Lunch (`13.6%`, `12`) and Evening Snack (`9.1%`, `8`). Only `5.7%` (`5`) say they rarely skip meals and `1.1%` (`1`) skip Dinner.
10. **Hostel Mess, Nescafé, and Snacker lead outlet usage:** On average students pick `2.10` outlets. The top 5 are Hostel Mess (`52.3%`, `46`), Nescafé (`43.2%`, `38`), Snacker (`39.8%`, `35`), Yadav Canteen (`29.5%`, `26`), and Night Canteen (`23.9%`, `21`). Campus Café (`7`), Chai Vyanjan (`6`), Other Stalls (`5`), and Outside Delivery as a primary option (`1`) are much rarer.
11. **Five core factors drive outlet choice:** Students select an average of `2.92` factors. The top 5 all hover near ~50%: Food Quality (`54.5%`, `48`), Price/Affordability (`51.1%`, `45`), Portion Size (`48.9%`, `43`), Hygiene/Cleanliness (`47.7%`, `42`), and Taste (`44.3%`, `39`). Healthy/Nutritious Options (`10.2%`, `9`) and Location/Convenience (`9.1%`, `8`) trail far behind.
12. **Top wanted improvements mirror the dissatisfaction drivers:** Students pick an average of `2.47` improvements. Over half demand Better Hygiene/Cleanliness (`52.3%`, `46`) and Better Food Quality (`50.0%`, `44`), followed by Lower Prices (`42.0%`, `37`), Larger Portions (`23.9%`, `21`), and Better Taste (`22.7%`, `20`).


---

## EDA facts (Phase 3)

*(Note: All comparisons skip groups smaller than 8 students — specifically `Day Scholar` n=4, `Vegan` n=1, `Cash` n=2, and the 4 smallest outlets: `Campus Café` n=7, `Chai Vyanjan` n=6, `Other Campus Food Stalls/Carts` n=5, and `Outside Food Delivery` n=1.)*

### Statistically Supported Facts (Chi-square `p < 0.05`)
1. **High monthly spenders are much more satisfied (`p = 0.0123`, Pearson Chi-square = 8.79, df = 2):** Among students spending `> Rs 2,000/month` (`n = 21`), **`52.4%`** (`11/21`) are satisfied (rating 4 or 5), compared with only **`20.0%`** (`9/45`) in the Medium spend band (`Rs 1,001-2,000`) and **`18.2%`** (`4/22`) in the Low spend band (`<= Rs 1,000`). Students who spend more appear better able to buy satisfaction, while low and medium spenders are mostly dissatisfied or neutral.
2. **Nescafé users are more than twice as likely to be satisfied (`p = 0.0456`, Pearson Chi-square = 4.00, df = 1):** **`39.5%`** (`15/38`) of Nescafé users are satisfied, compared with only **`18.0%`** (`9/50`) of non-users (mean rating `3.13` vs `2.92`; mean spend `Rs 1,879` vs `Rs 1,658`).

### Noticeable Patterns Only (Not Confirmed at `p < 0.05` — May Be Luck)
3. **Yadav Canteen users appear to skip breakfast less often (borderline `p = 0.0505`, Chi-square = 3.82, df = 1):** `53.8%` (`14/26`) of Yadav Canteen users skip breakfast, compared with `77.4%` (`48/62`) of non-users. Yadav Canteen users also have lower average spend (`Rs 1,585` vs `Rs 1,824`, `p = 0.1377`).
4. **Vegetarian students appear to order outside heavily more often (`p = 0.0652`, simulated Chi-square; Vegan n=1 excluded):** `30.8%` (`12/39`) of Vegetarians order outside 2+ times/week, versus `10.3%` (`4/39`) of Non-Vegetarians and `11.1%` (`1/9`) of Eggetarians.
5. **Diet shows noticeable differences in Hostel Mess and Night Canteen usage (borderline):** Vegetarians report higher Hostel Mess use (`66.7%`, `26/39` vs `41.0%` Non-Veg and `44.4%` Eggetarian; `p = 0.0750`) and lower Night Canteen use (`12.8%`, `5/39` vs `33.3%` for both Non-Veg and Eggetarian; `p = 0.0982`).
6. **Night Canteen users show higher breakfast skipping (`85.7%`, `18/21` vs `65.7%`, `44/67` for non-users),** though this is not statistically supported (`p = 0.1382`, may be luck).
7. **2nd-year students show higher satisfaction (`50.0%`, `5/10`) than 1st-year (`33.3%`, `4/12`) and 3rd-year (`22.7%`, `15/66`),** but this is not statistically supported (`p = 0.1800`, may be luck with small 1st/2nd-year counts).

### No Real Difference / Weak Linear Correlations
8. **Gender shows virtually no difference across all metrics:** Male and Female students have nearly identical satisfaction (`26.8%` vs `28.1%`, `p = 1.000`), breakfast skipping (`71.4%` vs `68.8%`, `p = 0.9824`), heavy outside ordering (`19.6%` vs `18.8%`, `p = 1.000`), and monthly spend (`Rs 1,729` vs `Rs 1,797`, `p = 0.464`).
9. **Linear correlations among the 4 numeric columns are all very weak and non-significant (`|r| <= 0.132`, all `p >= 0.222`):**
   - `spend` vs `meals_per_day`: `r = -0.132` (`p = 0.222`)
   - `outside_orders` vs `satisfaction`: `r = 0.112` (`p = 0.299`)
   - `meals_per_day` vs `satisfaction`: `r = 0.108` (`p = 0.315`)
   - `spend` vs `satisfaction`: `r = 0.102` (`p = 0.342`) — *Note:* Even though straight-line correlation is weak (`r = 0.102`), Spend Band showed a real threshold jump above `Rs 2,000` (`p = 0.0123`).
   - `spend` vs `outside_orders`: `r = 0.071` (`p = 0.513`)
   - `meals_per_day` vs `outside_orders`: `r = -0.063` (`p = 0.558`)


---

## Mined patterns (Phase 5)

### 1. Association Rules (`arules / apriori`)
Tuned to `support >= 0.14` (at least `13` students per rule), `confidence >= 0.65`, and `lift > 1.15`, yielding **`23` non-redundant rules** across outlets, decision factors, wanted improvements, and behavior flags. Five key rules in plain words:

1. **`{Improve: Better Food Quality, Improve: Lower Prices} => {Outlet: Nescafé}`** (`count = 13`, `support = 0.148`, `confidence = 0.722`, `lift = 1.67`): Among students wanting both better quality and lower prices, `72.2%` regularly use Nescafé — `1.67` times higher than the overall Nescafé rate (`43.2%`). Even satisfied-leaning Nescafé users feel its items are pricey relative to quality.
2. **`{Improve: Better Taste} => {Factor: Hygiene/Cleanliness}`** (`count = 14`, `support = 0.159`, `confidence = 0.700`, `lift = 1.47`): `70.0%` of students asking for better taste also prioritize hygiene when choosing where to eat (`1.47x` the overall hygiene-factor rate). Taste complaints go hand-in-hand with cleanliness expectations.
3. **`{Improve: Better Taste} => {Outlet: Hostel Mess}`** (`count = 14`, `support = 0.159`, `confidence = 0.700`, `lift = 1.34`): `70.0%` of students demanding better taste are Hostel Mess users (`1.34x` baseline Hostel Mess rate of `52.3%`).
4. **`{Factor: Price/Affordability, Improve: Lower Prices} => {Outlet: Hostel Mess}`** (`count = 13`, `support = 0.148`, `confidence = 0.650`, `lift = 1.24`): Students who pick outlets by affordability and still want lower prices are concentrated among Hostel Mess users (`65.0%`), highlighting budget pressure around mess/extra food costs.
5. **`{Outlet: Night Canteen} => {Flag: Skips Breakfast}`** (`count = 18`, `support = 0.205`, `confidence = 0.857`, `lift = 1.22`): `85.7%` of Night Canteen users (`18/21`) skip breakfast most often — `1.22x` the campus average (`70.5%`). Late-night eating habits go together with missed morning meals.

*(Also notable: `{Factor: Hygiene/Cleanliness, Factor: Portion Size} => {Flag: Skips Breakfast}` has `88.2%` confidence, `lift = 1.25`, `count = 15`; and `{Flag: Satisfied (4-5)} => {Factor: Food Quality}` has `66.7%` confidence, `lift = 1.22`, `count = 16`.)*

### 2. Decision Tree (`rpart` predicting `satisfied = rating 4-5`)
- **Accuracy vs. Baseline:** Always guessing the majority class (`Not_Satisfied`, `64/88`) gives a **`72.7%` baseline**. With 10-fold cross-validation (`best_cp = 0.0625`, 2 splits), CV accuracy is **`73.9%`** (and in-sample accuracy is `79.5%`). So the tree improves slightly over guessing the majority class (`+1.2` percentage points out-of-sample), showing that satisfaction depends partly on spending and hygiene expectations, plus unmeasured factors like individual food experience.
- **Plain-language explanation (3–4 sentences):** First, the tree splits at monthly spend `< Rs 2,250`: among the `67` students spending `Rs 2,000` or less (`76%` of the sample), **`81%`** are not satisfied (`19%` satisfied). Among the `21` students spending `Rs 2,250` or more (`24%` of the sample), satisfaction splits on whether they list Hygiene/Cleanliness as a top priority. Those high spenders who prioritize Hygiene (`n = 9`) are still **`78%`** unsatisfied, while high spenders who do not flag Hygiene (`n = 12`) are **`75%`** satisfied. In short, spending above `Rs 2,000` helps satisfaction—unless the student cares strongly about hygiene.

### What These Mined Patterns Mean
- **For students:** Skipping breakfast is nearly universal (`70.5%`), especially among Night Canteen users (`85.7%`). Students relying on budgets `<= Rs 2,000` rarely feel satisfied (`19.4%`), and Vegetarians bear extra outside-delivery reliance (`30.8%` heavy outside) and price stress (`56.4%` want lower prices).
- **For administration:** Hygiene/Cleanliness (`52.3%` improvement demand, and the key decision-tree split holding back even high spenders) and Food Quality (`50.0%`) are systemic issues across all satisfaction tiers, not just complaints from a few unhappy students. Upgrading mess taste/quality, enforcing hygiene audits across campus outlets, and offering an affordable, quick morning breakfast option directly address the biggest gaps—and future surveys must capture the 4 facility-rating items properly.
- **For food vendors:** Nescafé enjoys higher overall user satisfaction (`39.5%`), yet its price-and-quality rule (`lift = 1.67`) shows students want better value-for-money combos. Hostel Mess vendors face clear taste and portion concerns (`Rule 5` and `Rule 6`), while Yadav Canteen's lower breakfast-skipping link (`53.8%` vs `77.4%`) shows a morning meal gap other vendors can tap into, and Vegetarians need more affordable campus options so they do not rely heavily on Swiggy/Zomato.
