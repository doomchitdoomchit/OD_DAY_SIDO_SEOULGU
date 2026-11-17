WITH daily_district AS (
  SELECT 
    delivery_date, 
    receiver_sigungu_nm, 
    is_weekend, 
    SUM(total_vol) AS daily_vol
  FROM `vw_base_parcel_data` 
  GROUP BY 1, 2, 3
),
district_stats AS (
  SELECT
    receiver_sigungu_nm,
    AVG(daily_vol) AS daily_avg_vol,
    STDDEV(daily_vol) AS stddev_daily_vol,
    MAX(daily_vol) AS max_daily_vol,
    ROUND(SAFE_DIVIDE(STDDEV(daily_vol), AVG(daily_vol)), 4) AS cv_index,
    ROUND(SAFE_DIVIDE(MAX(daily_vol), AVG(daily_vol)), 4) AS par_index,
    AVG(CASE WHEN is_weekend = 'Weekday' THEN daily_vol END) AS weekday_avg_vol,
    AVG(CASE WHEN is_weekend = 'Weekend' THEN daily_vol END) AS weekend_avg_vol,
    ROUND(SAFE_DIVIDE(AVG(CASE WHEN is_weekend = 'Weekend' THEN daily_vol END), AVG(CASE WHEN is_weekend = 'Weekday' THEN daily_vol END)), 4) AS weekend_weekday_ratio
  FROM daily_district 
  GROUP BY 1
),
od_stats AS (
  SELECT
    od_route_name,
    receiver_sigungu_nm,
    SUM(total_vol) AS route_vol,
    ROUND(SAFE_DIVIDE(SUM(total_vol), SUM(SUM(total_vol)) OVER ()) * 100, 4) AS od_share_pct
  FROM `vw_base_parcel_data` 
  GROUP BY 1, 2
)
SELECT
  o.od_route_name,
  o.receiver_sigungu_nm,
  o.route_vol,               -- [추가] 노선 총 물동량
  s.daily_avg_vol,
  s.stddev_daily_vol,
  s.max_daily_vol,           -- [추가] 자치구 최고 피크일 물동량
  s.cv_index,                -- 변동계수 (CV)
  s.par_index,               -- 첨두율 (PAR)
  s.weekday_avg_vol,
  s.weekend_avg_vol,
  s.weekend_weekday_ratio,   -- [추가] 주말/평일 물동량 비율
  o.od_share_pct,            -- 노선 점유율 (%)
  ROUND(s.par_index * o.od_share_pct, 4) AS peak_risk_index, -- 피크 위험 지수
  -- [추가] Looker Studio 드롭다운 전용 피크 위험 등급 (Tier)
  CASE 
    WHEN ROUND(s.par_index * o.od_share_pct, 4) >= 1.5 THEN '🔴 고위험 (Peak Risk >= 1.5)'
    WHEN ROUND(s.par_index * o.od_share_pct, 4) >= 1.0 THEN '🟡 주의 (1.0 <= Peak Risk < 1.5)'
    ELSE '🟢 안전 (Peak Risk < 1.0)'
  END AS peak_risk_tier
FROM od_stats o
JOIN district_stats s ON o.receiver_sigungu_nm = s.receiver_sigungu_nm