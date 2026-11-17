WITH unpivoted AS (
  SELECT month, is_weekend, '가구/인테리어' AS category_nm, vol_furniture_interior AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '기타' AS category_nm, vol_etc AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '도서/음반' AS category_nm, vol_books_music AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '디지털/가전' AS category_nm, vol_digital_appliances AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '생활/건강' AS category_nm, vol_living_health AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '스포츠/레저' AS category_nm, vol_sports_leisure AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '식품' AS category_nm, vol_food AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '출산/육아' AS category_nm, vol_baby_kids AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '패션의류' AS category_nm, vol_fashion_clothing AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '패션잡화' AS category_nm, vol_fashion_acc AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT month, is_weekend, '화장품/미용' AS category_nm, vol_cosmetics_beauty AS cat_vol FROM `vw_base_parcel_data`
),
monthly_avg AS (
  SELECT month, category_nm, AVG(cat_vol) AS m_avg
  FROM unpivoted GROUP BY 1, 2
),
yearly_avg AS (
  SELECT category_nm, AVG(cat_vol) AS y_avg
  FROM unpivoted GROUP BY 1
)
SELECT
  u.month,
  CONCAT(CAST(u.month AS STRING), '월') AS month_str,
  u.is_weekend,
  u.category_nm,
  SUM(u.cat_vol) AS cat_total_vol,
  ROUND(SAFE_DIVIDE(m.m_avg, y.y_avg), 4) AS seasonal_index
FROM unpivoted u
JOIN monthly_avg m ON u.month = m.month AND u.category_nm = m.category_nm
JOIN yearly_avg y ON u.category_nm = y.category_nm
GROUP BY 1, 2, 3, 4, 6