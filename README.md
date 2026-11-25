# 📦 서울시 자치구별 일일 택배 물동량 데이터 파이프라인 &  대시 보드 & Direct Multi-Step 수요예측


> 본 프로젝트는 **Polars, BigQuery, LightGBM, SHAP**을 기반으로 서울시 25개 자치구의 일일 택배 물동량을 **7일 예측 시점(t+1 ~ t+7)** 기준으로 정밀 예측하고, 전체 데이터 파이프라인과 분석 결과를 한눈에 탐색할 수 있는 **Looker Studio 대시보드**까지 연동한 **시계열 수요예측 파이프라인**입니다.

> [Looker Studio 대시보드(Data Studio)](https://datastudio.google.com/s/oHk2lopv0sI)  
<sub> *※ 서울시 자치구별 수송 현황, YoY/MoM 트렌드, 자치구 특화(LQ) 지표 및 피크 위험 매트릭스를 대시보드에서 직접 탐색하실 수 있습니다.* </sub>
---

## 📌 1. Executive Summary

본 프로젝트는 대용량 물류 데이터를 효율적으로 가공하고, 시계열 데이터의 특수성(주간 요일성, 공휴일 쏠림, 자치구별 상권 차이)을 반영하여 **최대 정확도 94.6% (t+2 WAPE 5.38%)**의 수요예측 파이프라인을 구현한 결과물입니다. 또한 서울시 25개 자치구의 5개년 물동량 통계 검정(4-Step Sequential Test & Two-Way ANOVA) 통하여 물류 자원 최적 배치의 정량적 근거를 도출했습니다.

### 🎯 핵심 성과
* **예측 오차율 극적 단축**: 초기 단일 모델 베이스라인(WAPE ~16%, MAPE ~65%) 대비 **Direct Multi-Step 분리 모델과 Target 기준 요일 정밀 시차 설계**를 적용하여 **WAPE 5.38% (t+2 기준)** 달성 및 전 구간(t+1 ~ t+7) **6.6% 이내 오차 평탄화**.
* **대시보드 조인 병목 해소**: Looker Studio 자기결합(Self-Join) 시 발생하는 날짜 매칭 오류 및 렌더링 지연을 **BigQuery `LAG()` 윈도우 함수 및 CTE 기반 Single View** 설계로 처리 성능 **90% 이상 개선**.
* **통계 검정 및 A/B 테스트 체계 구축**: 25개 자치구 병목 요일(Group A vs Group B) 4단계 통계 검정(Levene, Welch's t, Mann-Whitney U, Cohen's d) 기반 A/B 테스트와 Two-Way ANOVA
* **안정적 오차 통제**: `np.log1p` 타깃 변환 및 자치구 물동량 스케일 가중치(`sample_weight`)를 결합하여 소형 자치구의 MAPE 폭증 현상을 **16% ~ 18%대로 완전 안착**.

### 🛠️ Tech Stack
* **Languages & Libraries**: Python 3.12, Polars, LightGBM, SHAP, NumPy, Pandas, Scipy, Statsmodels, Scikit-Learn
* **Data Engineering & Storage**: Apache Parquet, Google BigQuery (Standard SQL)
* **Visualization & Analytics**: Looker Studio, Matplotlib, Seaborn
* **Domain Focus**: A/B Testing, Causal Inference & Hypothesis Testing, Time-Series Forecasting, Feature Engineering

---

## 🏗️ 2. System Architecture

전체 파이프라인은 데이터 수집 및 압축 저장부터 DW 조립, 대시보드 제공, ML 예측 및 모델 해석까지 4단계로 유기적으로 연결되어 있습니다.

| 단계 | 파이프라인 모듈 | 주요 역할 및 핵심 기술 |
| :--- | :--- | :--- |
| **Stage 1** | **Data Ingestion & Storage** | Raw CSV (45,000+ rows) 수집 후 Polars 기반 Columnar Format(Parquet)으로 변환하여 단일 스레드에서 멀티스레드 병렬 처리로 전환 및 데이터 압축 |
| **Stage 2** | **Data Warehouse Layer** | Google BigQuery 단일 DW 구축 및 CTE 등 각 보드별 분석 뷰(View) 설계 (YoY, MoM, LQ, Peak Risk/PAR 등) |
| **Stage 3** | **BI & Operations** | Looker Studio 대시보드 연동 (수송 개요, 자치구 LQ 특화 분석, 계절성 및 피크 위험 매트릭스 제공) |
| **Stage 4** | **Statistical Testing & A/B Testing** | 서울 25개 자치구 4단계 통계 검정, Two-Way ANOVA 등 A/B 테스트 파이프라인 구축 |
| **Stage 5** | **ML & Model Interpretability** | Direct Multi-Step (t+1 ~ t+7) 7개 독립 LightGBM 회귀 학습, 백테스팅 및 SHAP TreeExplainer 모델 해석 |

---

## 🛠️ 3. Data Engineering & SQL Modeling

### 1. Polars 기반 Parquet Columnar 저장소 변환
대용량 시계열 전처리의 I/O 오버헤드를 줄이고 메모리 효율을 극대화하기 위해 **Polars LazyFrame** 파이프라인을 채택했습니다. 
* **용량 최적화**: 기존 CSV 형식 대비 파일 용량을 **60MB에서 9MB로 대폭 감축 (약 85% 용량 절감)**.
* **병렬 처리**: 단일 스레드 중심 처리 방식에서 멀티스레드 병렬 처리 엔진으로 전환하여 CPU 연산 효율 및 데이터 전처리 파이프라인 속도를 크게 개선했습니다.

### 2. BigQuery 윈도우 함수 기반 분석 뷰(View) 구축
Looker Studio 데이터 블렌딩(Self-Join) 시 발생하는 특정 날짜 누락 및 대시보드 렌더링 병목 현상을 방지하기 위해 BigQuery 내에서 CTE와 윈도우 함수(`LAG()`)를 활용한 보드별 분석 전용 View(YoY, MoM, LQ, Peak Risk/PAR 등)를 구축했습니다.  
*(※ 상세 SQL 쿼리 코드는 `/sql` 디렉토리 참조)*

---

## 🔬 4. Statistical Testing & A/B Testing
> 📖 **[상세 통계 검정표 & A/B 테스트 명세서 보기 (docs/01_ab-testing-stat.md)](docs/01-ab-testing-stat.md)**

### 1. 서울 25개 자치구 병목 요일 4단계 통계 검정 (4-Step Sequential Test)
* **검정 목적**: 도착지 자치구(`RECEIVER_SIGUNGU_NM`) 단위로 **Group A(주말·공휴일 직후 2영업일: 월·화)**와 **Group B(평시: 수·목·금)** 간의 물동량 및 변동성 차이를 정량 입증.
* **4단계 순차 검정 체계**:
  1. **Levene's Test (분산 동질성)**: 비정규 분포에 강건한 검정 기법으로 두 그룹 간 이분산성 입증 ($p < 0.05$).
  2. **Welch's t-test (평균 차이)**: 이분산성을 반영하여 Group A가 Group B 대비 평균 29.7% ~ 45.2% 물동량이 급증함을 입증 ($p < 0.001$).
  3. **Mann-Whitney U Test (비모수 검정)**: 이상치 영향을 배제하고 중앙값 위치 이동 재확인 ($p < 0.001, r \ge 0.70$).
  4. **Cohen's d (효과 크기)**: 대용량 표본의 $p$-value 착시를 넘어서는 강력한 실질적 효과 크기($d = 1.37 \sim 1.53$) 산출.

### 2. 시기별(2019 / 2020-2022 / 2023) 이원 분산분석 (Two-Way ANOVA)
* **검정 목적**: 팬데믹 전(2019), 팬데믹기(2020~2022), 엔데믹기(2023)에 따른 요일별 물동량 구조 변화 검정.
* **ANOVA 결과**: 시기($Period$)와 요일 그룹($Group$) 간의 **교차 효과($Period \times Group, F = 3.65, p = 0.026$)가 통계적으로 유의미**함을 증명.
* **운영 인사이트**: 팬데믹기 월·화 쏠림 비율(45.9% ~ 46.8%) 대비 엔데믹 이후 평탄화(42.0% ~ 43.7%) 현상을 규명하여 현장 인력 및 배차 재배치의 정량적 근거 제시.

---

## 🤖 5. ML Pipeline & Feature Engineering
> 📖 **[상세 Multi-Step LightGBM 수요예측 모델링(docs/02-lgbm-forecasting-model.md)](docs/02-lgbm-forecasting-model.md)**


### 💡 5대 핵심 피처 엔지니어링 전략

| 전략 번호 | 피처 이름 | 설명 및 설계 의도 |
| :--- | :--- | :--- |
| **Strategy 1** | **Direct Multi-step (t+1 ~ t+7)** | 7일 뒤 예측을 위해 하나의 모델로 재귀(Recursive)하지 않고, t+1부터 t+7까지 7개 전용 LightGBM 모델을 분리하여 초단기 시차 유효성을 극대화 |
| **Strategy 2** | **Target 기준 요일 정밀 시차 (`same_dow_lag_1~4`)** | Target 날짜($D = t + step$) 관점에서 정확히 지난주 동일 요일($D-7, D-14, D-21, D-28$)을 1:1 매칭하여 시차 요일 불일치(Lag Misalignment) 완벽 해결 |
| **Strategy 3** | **동적 카테고리 비중 (`rolling_food_ratio_7`)** | 자치구별 고정 비중(Static) 대신 최근 7일간의 이동 카테고리 비율을 계산하여 상권 변동성을 정밀하게 포착 (Feature Gain 0 문제 해소) |
| **Strategy 4** | **공휴일 사전 쏠림 & 이월 가중 스코어 (`impact_score`)** | 단순 이진 공휴일 변수 대신 `연휴 연속 일수 × D-1 쏠림` 스코어를 산출하여 명절/연휴 직전 및 직후 물동량 폭증을 모델링 |
| **Strategy 5** | **중기 모멘텀 & 상대 비율 (`mid_term_momentum`)** | `최근 3일 이동평균 ÷ 14일 이동평균` 및 `동일 요일 ÷ 4주 이동평균` 비율 피처를 추가하여 t+3~t+4 과도기 오차 방어 |

*(※ 상세 Python 모델링 소스코드는 `/notebook` 디렉토리 참조)*


### 📊 60일 Out-of-Time 백테스팅 오차 개선 비교 표

| Forecast Horizon | Initial Baseline WAPE | Initial Baseline MAPE | Intermediate Model WAPE | **Final Model WAPE** | **Final Model MAPE** | **전체 WAPE 개선 폭** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **t+1 (내일)** | ~16.00% | ~65.00% | 10.68% | **5.91%** | **16.37%** | **-10.09%p** |
| **t+2 (모레)** | ~16.00% | ~65.00% | 10.59% | **5.38% (최고)** | **16.05%** | **-10.62%p** |
| **t+3 (3일 뒤)** | ~16.00% | ~65.00% | 12.66% | **6.17%** | **17.41%** | **-9.83%p** |
| **t+4 (4일 뒤)** | ~16.00% | ~65.00% | 12.88% | **6.58%** | **17.53%** | **-9.42%p** |
| **t+5 (5일 뒤)** | ~16.00% | ~65.00% | 12.34% | **6.69%** | **17.93%** | **-9.31%p** |
| **t+6 (6일 뒤)** | ~16.00% | ~65.00% | 11.92% | **6.36%** | **17.72%** | **-9.72%p** |
| **t+7 (7일 뒤)** | ~16.00% | ~65.00% | 12.48% | **6.57%** | **18.09%** | **-9.43%p** |

---

## 💡 6. Troubleshooting & Lessons Learned

### Lesson 1: Lag Misalignment (시차 요일 불일치) 교정
* **문제**: 기존 `vol_lag_{step+7}` 피처는 t+3 예측 모델에 '오늘 기준 7일 전(지난주 월요일)' 수량을 주입하여 목요일 예측값과 요일이 어긋나는 현상 발생.
* **해결**: Target 날짜($D = t + step$) 관점에서 `shift(7)`을 수행하는 `same_dow_lag_1` 모듈을 도입하여 t+3~t+4 오차율을 **12.88%에서 6.17%로 단축**.

### Lesson 2: Static vs Dynamic Feature Transformation
* **문제**: 자치구별 고정 식품 비중(`food_ratio`)을 입력했을 때 자치구 범주형 변수에 흡수되어 Feature Gain이 0점으로 측정됨.
* **해결**: 최근 7일간의 이동 비율(`rolling_food_ratio_7`)로 동적 재설계하여 Gain 31,000의 핵심 피처로 부활시킴.

### Lesson 3: Looker Studio BigQuery Integration
* **문제**: 대시보드 상에서 YoY 비교 시 Self-Join 처리로 인해 특정 날짜 조인 실패 및 대시보드 렌더링 속도 저하 발생.
* **해결**: BigQuery 파이프라인 단에서 `LAG(month_vol, 12)` 윈도우 함수 및 CTE 기반 Single View를 생성하여 대시보드 조인 연산을 제거함.

---

## 📂 7. Directory Structure

```
.
├── data/
│   ├── DWC_KXLCLS_OD_DAY_SIDO_SEOULGU_201901.csv   	# 서울시에서 직접 받은 csv
│   └── seoulgu.parquet   				# csv 파일 parquet으로 전환
├── docs/
│   └── 01-ab-testing-stat.md
│   └── 02-lgbm-forecasting-model.md
├── sql/
│   └── vw_base_parcel_data.sql
│   └── vw_board1_monthly_growth.sql
│   └── vw_board2_district_lq.sql
│   └── vw_board3_seasonality.sql
│   └── vw_board4_peak_risk.sql
├── src/
│   ├── csv2parq.py          # 데이터 변환
├── notebooks/
│   └── 01_지역별_상품_물동량_통계_데이터_baseline.ipynb
│   └── 02_지역별_상품_물동량_통계_데이터_ADDlog_POSTHoli.ipynb
│   └── 03_지역별_상품_물동량_통계_데이터_ModelSplit_ADDFeatures.ipynb
│   └── 04_지역별_상품_물동량_통계_데이터_ADDtargetweek.ipynb
├── README.md
└── requirements.txt
```
