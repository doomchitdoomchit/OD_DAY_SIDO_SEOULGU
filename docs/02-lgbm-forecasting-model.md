# 🤖 Direct Multi-Step LightGBM 수요예측 모델 종합 정리

서울시 25개 자치구 일일 택배 물동량 데이터 기반 **Direct Multi-Step LightGBM 수요예측 모델 파이프라인**의 배경, 아키텍처 설계, 피처 엔지니어링, 성과 및 모델 해석 정리 문서입니다.

---

## 1. 🎯 배경 및 문제 의식 (Problem Definition)

* **기존 단일/재귀 모델(Recursive Forecasting)의 한계**: 
  하나의 모델로 7일 뒤까지 재귀적으로 예측할 경우($t+1 \rightarrow t+2 \rightarrow \dots \rightarrow t+7$), 이전 시점의 예측 오차가 다음 시점 예측의 입력으로 누적되어 $t+3$ 이후 예측 오차(WAPE)가 폭증하는 문제가 발생하였습니다.
* **시차 요일 불일치 (Lag Misalignment)**: 
  예측 대상 날짜($D = t + \text{step}$)의 요일 특성을 고려하지 않고 단순 과거 시차($t-7$)를 주입하면 Target 요일과 시차 요일이 어긋나는 현상이 관측되었습니다.
* **소형 자치구 오차 폭증 현상**: 
  중구, 도봉구 등 물동량이 적은 소형 자치구의 경우 절대 수량 차이로 인해 상대적 오차율(MAPE)이 60% 이상으로 폭증하는 문제가 존재하였습니다.

---

## 2. 🏗️ 핵심 모델 아키텍처 (Direct Multi-Step Structure)

* **7개 독립 레그레서 분리 학습**: 
  $t+1$부터 $t+7$까지 7개의 전용 LightGBM 모델을 각각 독립적으로 생성 및 학습시켜 재귀적 오차 누적을 근본적으로 차단하였습니다.
* **Horizon별 차등 하이퍼파라미터 튜닝**:
  * **초단기 ($t+1, t+2$)**: 복잡한 파동 포착을 위한 고용량 설정 (`n_estimators=1000`, `num_leaves=35`, `colsample_bytree=0.9`)
  * **중기 ($t+3, t+4$)**: 중간 수준 모델링 (`n_estimators=1000`, `num_leaves=25`, `reg_alpha=0.05`)
  * **중장기 ($t+5 \sim t+7$)**: 과적합 방지를 위한 강력한 규제 적용 (`n_estimators=1000`, `num_leaves=20`, `reg_alpha=0.1`, `reg_lambda=0.1`)

---

## 3. 💡 5대 핵심 피처 엔지니어링 전략 (Feature Engineering)

1. **Direct Multi-step (t+1 ~ t+7)**: 예측 Horizon별 모델 분리.
2. **Target 기준 요일 정밀 시차 (`same_dow_lag_1~4`)**: Target 날짜($D = t + \text{step}$) 관점에서 정확히 지난주 동일 요일($D-7, D-14, D-21, D-28$)을 1:1 매칭하여 시차 요일 불일치 교정.
3. **동적 카테고리 비중 (`rolling_food_ratio_7`)**: 자치구별 고정 비중(Static) 대신 최근 7일간의 이동 카테고리 비율을 산출하여 상권 변동성 반영 (Feature Gain 0 문제 해결).
4. **공휴일 사전 쏠림 & 이월 가중 스코어 (`impact_score`)**: $\text{연휴 연속 일수} \times \text{D-1 쏠림}$ 스코어를 설계하여 명절/연휴 직전 및 직후 물동량 폭증을 정밀 모델링.
5. **중기 모멘텀 & 상대 비율 (`mid_term_momentum`, `same_dow_to_m28_ratio`)**: $\text{최근 3일 이동평균} \div \text{14일 이동평균}$ 및 $\text{동일 요일} \div \text{4주 이동평균}$ 비율을 추가하여 과도기 오차 방어.
6. **타깃 변환 및 스케일 가중치**: `np.log1p` 타깃 스케일링과 자치구 물동량 스케일 비례 가중치(`sample_weight`)를 결합하여 소형 자치구의 MAPE를 **16% ~ 18%대로 완전 안착**.

---

## 4. 📊 백테스팅 최종 성과 (Backtesting Performance)

* **오차율 극적 단축**: 기존 단일 baseline 모델(WAPE 15.76%) 대비 **Direct Multi-Step 모델 적용 시 WAPE 5.38% (t+2 기준)** 달성.
* **전 구간 오차 평탄화**: $t+1 \sim t+7$ 예측 전 구간에서 오차율을 **6.6% 이내로 안정적으로 통제**.

| Forecast Horizon | Baseline WAPE | Final Model WAPE | Final Model MAPE | WAPE 개선 폭 |
| :--- | :--- | :--- | :--- | :--- |
| **t+1 (내일)** | 10.68% | **5.91%** | 16.37% | -4.77%p |
| **t+2 (모레)** | 10.59% | **5.38% (최고)** | 16.05% | -5.21%p |
| **t+3 (3일 뒤)** | 12.66% | **6.17%** | 17.41% | -6.49%p |
| **t+4 (4일 뒤)** | 12.88% | **6.58%** | 17.53% | -6.30%p |
| **t+5 (5일 뒤)** | 12.34% | **6.69%** | 17.93% | -5.65%p |
| **t+6 (6일 뒤)** | 11.92% | **6.36%** | 17.72% | -5.56%p |
| **t+7 (7일 뒤)** | 12.48% | **6.57%** | 18.09% | -5.91%p |

---

## 5. 🔍 모델 해석성 (SHAP & Feature Importance)

* **Top 5 Feature Importance (Gain)**:
  1. `dayofweek` (요일 - Gain ~543,000): 주간 반복 파동의 절대 기준
  2. `is_off_day` (휴무일 여부 - Gain ~298,000): 0건 배정 차단
  3. `same_dow_to_m28_ratio` (동일 요일 ÷ 28일 이동평균 - Gain ~97,117): 중장기 오차 방어
  4. `today_vol` (오늘 실적 - Gain ~92,000): 자치구 기본 수량 스케일 보정
  5. `rolling_food_ratio_7` (최근 7일 동적 식품 비중 - Gain ~31,000): 상권 변화 포착
* **SHAP TreeExplainer 인사이트**: `pre_holiday_impact_score`와 `same_dow_to_m28_ratio`의 상승이 SHAP Value를 양(+)의 방향으로 이동시켜 연휴 전 출하 쏠림이 물동량 폭증을 유발하는 메커니즘을 정량 입증.

### 💡 SHAP (TreeExplainer) 인사이트
* **방향성 검증**: `pre_holiday_impact_score` 및 `same_dow_to_m28_ratio`의 값이 증가할수록 SHAP Value가 양(+)의 방향으로 크게 이동하여, 연휴 직전 출하 쏠림 및 상승 추세가 물동량 폭증을 직관적으로 유발함을 증명했습니다.
