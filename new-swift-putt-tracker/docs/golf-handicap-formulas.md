# Golf Handicap Formulas (WHS)

## 1. Handicap Index

Your Handicap Index is the average of your best 8 Score Differentials from your most recent 20 rounds, rounded to one decimal, with a maximum of 54.0.

**Step 1: Score Differential for each round**

$$
\text{Score Differential} = \frac{113}{\text{Slope Rating}} \times (\text{Adjusted Gross Score} - \text{Course Rating} - \text{PCC})
$$

- **Adjusted Gross Score:** your gross score with each hole capped at net double bogey (par + 2 + any handicap strokes you receive on that hole).
- **PCC:** Playing Conditions Calculation, an adjustment of -1 to +3 for abnormal course or weather conditions. It is usually 0.

**Step 2: Average the best differentials**

With fewer than 20 scores, fewer differentials are used:

| Scores | Differentials used | Adjustment |
| --- | --- | --- |
| 3 | Lowest 1 | -2.0 |
| 4 | Lowest 1 | -1.0 |
| 5 | Lowest 1 | none |
| 6 | Average of lowest 2 | -1.0 |
| 7-8 | Average of lowest 2 | none |
| 9-11 | Average of lowest 3 | none |
| 12-14 | Average of lowest 4 | none |
| 15-16 | Average of lowest 5 | none |
| 17-18 | Average of lowest 6 | none |
| 19 | Average of lowest 7 | none |
| 20 | Average of lowest 8 | none |

The Index is also subject to a soft cap and a hard cap, which limit how fast it can rise above your lowest Index of the past 12 months.

## 2. Course Handicap

Course Handicap converts your Handicap Index to the tees you are playing, then rounds to the nearest whole number.

$$
\text{Course Handicap} = \text{Handicap Index} \times \frac{\text{Slope Rating}}{113} + (\text{Course Rating} - \text{Par})
$$

## 3. Playing Handicap

Playing Handicap is your Course Handicap multiplied by the handicap allowance for the format. Round once, at the end, to the nearest whole number.

$$
\text{Playing Handicap} = \text{Course Handicap} \times \text{Handicap Allowance}
$$

| Format | Allowance |
| --- | --- |
| Individual stroke play | 95% |
| Stableford | 95% |
| Individual match play | 100% |
| Four-ball stroke play | 85% |
| Four-ball better-ball match play | 90% |

Allowances can vary by country or competition, so check your local rules.

## Worked example

A round of 88 on tees with Course Rating 71.3, Slope 128, Par 72 and PCC 0 gives a Score Differential of 14.7. For a player with a Handicap Index of 14.2 on the same tees, the Course Handicap is 15.38 before rounding and the Playing Handicap in stroke play is 15.

| Step | Calculation | Result |
| --- | --- | --- |
| Score Differential | (113 / 128) x (88 - 71.3) = 0.8828 x 16.7 | 14.7 |
| Course Handicap | 14.2 x (128 / 113) + (71.3 - 72) | 15.38 unrounded |
| Playing Handicap (stroke play, 95%) | 15.38 x 0.95 = 14.61 | 15 |
