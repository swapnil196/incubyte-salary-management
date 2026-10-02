# Salary Management — Requirements

**Author:** Swapnil Dongre · **Date:** 2 October 2026 · **Status:** Written before implementation

A web app that replaces ACME's salary spreadsheets and answers questions about how the company pays people.

> Rendered version: `docs/requirements.html`

---

## 1. Goal

ACME's HR team tracks pay for 10,000 employees across several countries in spreadsheets, which is slow
and easy to get wrong. Build web software that lets the HR Manager manage salary data and answer
questions about how the organisation pays people.

The user is the **HR Manager at ACME**, who is allowed to see every employee's pay.

Two outcomes define success:

- Salary data is accurate, stored in one place, and keeps its full history.
- The HR Manager can answer a question about pay across the company in under a minute, without opening Excel.

## 2. Scope and features

### A · Managing salary data

| Feature | Detail |
|---|---|
| Employee list | Search and filter by country, department, job level and status. Paginated on the server so 10,000 records stay fast. |
| Employee profile | Job and personal details, plus the complete salary history for that person. |
| Record a pay change | Enter a new salary with an effective date and a reason, such as promotion or annual review. The previous record is kept, never overwritten. |
| Pay bands | Expected minimum, midpoint and maximum salary for each job level in each country. |
| Multiple currencies | Salaries held in local currency, with the exchange rate stored on each record so company-wide totals are consistent and repeatable. |

### B · Answering questions about pay

| Feature | Detail |
|---|---|
| Dashboard | Total annual payroll cost, headcount, and median pay across the company in one currency. |
| Breakdowns | Median pay and the 25th to 75th percentile range, by country, department and job level. |
| Outliers | Who is paid below the minimum or above the maximum of their pay band. |
| Pay equity | Median pay by gender within the same job level and country, hidden for any group under 5 people so no individual's pay can be worked out. |
| CSV export | Download any filtered view for reports and board decks. |

### C · Data

| Feature | Detail |
|---|---|
| Seed script | Creates 10,000 employees with realistic salaries, currencies and change history, including deliberate outliers so the dashboard has something real to show. |

## 3. Deliberately left out

Each item below is a decision, not an oversight. The first row is the one to add before anyone uses this for real.

| Not building | Reasoning |
|---|---|
| **Login, user accounts and permissions** | The brief describes one trusted HR Manager. Auth is well understood and would use up build time without showing design judgment. **This is the first thing to add before real use.** |
| Running payroll: payslips, tax, deductions | A separate and heavily regulated system that differs per country. Managing salaries and paying salaries are two different products. |
| Bonuses, equity and benefits | Each comes with its own vesting and accrual rules. Base salary carries most of the analytical value, and the data model leaves room to add them later. |
| Approval workflow for pay changes | Needs the multiple users excluded above. Each change already records who made it and why, which is what a workflow would later build on. |
| Bulk CSV upload | The hard part is handling bad rows and conflicts, which is a lot of work for little insight. Export is included because HR genuinely needs it. |
| Live currency exchange rates | Reports would give a different answer each time they ran. Rates are stored in the database and saved onto each record instead. |
| Translating the interface | The HR Manager works in English. Currency and date formatting per country is still handled. |
| Hiring, performance reviews, leave | Outside the problem. The brief is about salary. |
