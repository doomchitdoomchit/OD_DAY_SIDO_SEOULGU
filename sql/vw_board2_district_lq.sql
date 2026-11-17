WITH unpivoted AS (
  SELECT receiver_sigungu_nm, '가구/인테리어' AS category_nm, vol_furniture_interior AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '기타' AS category_nm, vol_etc AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '도서/음반' AS category_nm, vol_books_music AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '디지털/가전' AS category_nm, vol_digital_appliances AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '생활/건강' AS category_nm, vol_living_health AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '스포츠/레저' AS category_nm, vol_sports_leisure AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '식품' AS category_nm, vol_food AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '출산/육아' AS category_nm, vol_baby_kids AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '패션의류' AS category_nm, vol_fashion_clothing AS cat_vol FROM `vw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '패션잡화' AS category_nm, vol_fashion_acc AS cat_vol FROM `vsw_base_parcel_data` UNION ALL
  SELECT receiver_sigungu_nm, '화장품/미용' AS category_nm, vol_cosmetics_beauty AS cat_vol FROM `vw_base_parcel_data`
),
district_cat AS (
  SELECT receiver_sigungu_nm, category_nm, SUM(cat_vol) AS district_cat_vol
  FROM unpivoted GROUP BY 1, 2
),
totals AS (
  SELECT receiver_sigungu_nm, SUM(district_cat_vol) AS district_total_vol, SUM(SUM(district_cat_vol)) OVER () AS overall_total_vol
  FROM district_cat GROUP BY 1
),
cat_totals AS (
  SELECT category_nm, SUM(district_cat_vol) AS overall_cat_vol
  FROM district_cat GROUP BY 1
)
SELECT
  d.receiver_sigungu_nm,
  d.category_nm,
  d.district_cat_vol,
  t.district_total_vol,
  c.overall_cat_vol,
  t.overall_total_vol,
  ROUND(SAFE_DIVIDE(SAFE_DIVIDE(d.district_cat_vol, t.district_total_vol), SAFE_DIVIDE(c.overall_cat_vol, t.overall_total_vol)), 4) AS lq_index
FROM district_cat d
JOIN totals t ON d.receiver_sigungu_nm = t.receiver_sigungu_nm
JOIN cat_totals c ON d.category_nm = c.category_nm