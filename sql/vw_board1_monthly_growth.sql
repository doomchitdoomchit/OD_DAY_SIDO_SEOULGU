WITH monthly_summary AS (
  SELECT
    year,
    month,
    year_month_date,
    SUM(total_vol) AS monthly_vol
  FROM
    `vw_base_parcel_data`
  GROUP BY 1, 2, 3
)
SELECT
  year,
  month,
  year_month_date,
  monthly_vol,
  -- MoM (전월 대비 성장률 %)
  LAG(monthly_vol, 1) OVER (ORDER BY year_month_date) AS prev_month_vol,
  ROUND(SAFE_DIVIDE(monthly_vol - LAG(monthly_vol, 1) OVER (ORDER BY year_month_date), LAG(monthly_vol, 1) OVER (ORDER BY year_month_date)) * 100, 2) AS mom_growth_pct,
  -- YoY (전년 동월 대비 성장률 %)
  LAG(monthly_vol, 12) OVER (ORDER BY year_month_date) AS prev_year_month_vol,
  ROUND(SAFE_DIVIDE(monthly_vol - LAG(monthly_vol, 12) OVER (ORDER BY year_month_date), LAG(monthly_vol, 12) OVER (ORDER BY year_month_date)) * 100, 2) AS yoy_growth_pct
FROM
  monthly_summary
ORDER BY
  year_month_date