import os
import glob

import pandas as pd

def build_parquet(input_pattern: str, output_path: str):
    # 1. 필요한 컬럼만 지정 및 데이터 타입 사전 정의 (메모리 절약 핵심)
    cat_cols = [
        '대분류_착지물동량 가구/인테리어', '대분류_착지물동량 기타', '대분류_착지물동량 도서/음반',
        '대분류_착지물동량 디지털/가전', '대분류_착지물동량 생활/건강', '대분류_착지물동량 스포츠/레저',
        '대분류_착지물동량 식품', '대분류_착지물동량 출산/육아', '대분류_착지물동량 패션의류',
        '대분류_착지물동량 패션잡화', '대분류_착지물동량 화장품/미용'
    ]
    
    dtype_dict = {
        '송하인_시명': 'category',
        '송하인_시코드': 'int16',
        '수하인_시명': 'category',
        '수하인_시코드': 'int16',
        '수하인_구명': 'category',
        '수하인_구코드': 'int32',
        **{col: 'int32' for col in cat_cols}
    }

    column_mapping = {
        '배송년월일': 'DELIVERY_YMD',
        '송하인_시명': 'SENDER_SIDO_NM',
        '송하인_시코드': 'SENDER_SIDO_CD',
        '수하인_시명': 'RECEIVER_SIDO_NM',
        '수하인_시코드': 'RECEIVER_SIDO_CD',
        '수하인_구명': 'RECEIVER_SIGUNGU_NM',
        '수하인_구코드': 'RECEIVER_SIGUNGU_CD',
        '대분류_착지물동량 가구/인테리어': 'CAT_VOL_FURNITURE_INTERIOR',
        '대분류_착지물동량 기타': 'CAT_VOL_ETC',
        '대분류_착지물동량 도서/음반': 'CAT_VOL_BOOKS_MUSIC',
        '대분류_착지물동량 디지털/가전': 'CAT_VOL_DIGITAL_APPLIANCES',
        '대분류_착지물동량 생활/건강': 'CAT_VOL_LIVING_HEALTH',
        '대분류_착지물동량 스포츠/레저': 'CAT_VOL_SPORTS_LEISURE',
        '대분류_착지물동량 식품': 'CAT_VOL_FOOD',
        '대분류_착지물동량 출산/육아': 'CAT_VOL_BABY_KIDS',
        '대분류_착지물동량 패션의류': 'CAT_VOL_FASHION_CLOTHING',
        '대분류_착지물동량 패션잡화': 'CAT_VOL_FASHION_ACC',
        '대분류_착지물동량 화장품/미용': 'CAT_VOL_COSMETICS_BEAUTY'
    }   


    # 2. 5년 치 분할 CSV 파일 순회 로드 (예: data/delivery_2021.csv ~ 2025.csv)
    file_list = sorted(glob.glob(input_pattern))
    df_list = []

    for file in file_list:
        temp_df = pd.read_csv(file, dtype=dtype_dict, encoding='cp949')
        # 날짜 타입 최적화 변환
        temp_df['배송년월일'] = pd.to_datetime(temp_df['배송년월일'].astype(str), format='%Y%m%d')
        df_list.append(temp_df)

    # 3. 병합 후 Category 타입 재정렬 (파일 간 카테고리 불일치 방지)
    full_df = pd.concat(df_list, ignore_index=True)
    for col in ['송하인_시명', '수하인_시명', '수하인_구명']:
        full_df[col] = full_df[col].astype('category')
    
    full_df = full_df.rename(columns=column_mapping)
    # 4. 고압축 Parquet 포맷으로 저장 (snappy 또는 zstd 압축 사용)
    full_df.to_parquet(output_path, engine='pyarrow', compression='zstd', index=False)
    print(f"변환 완료! 메모리 사용량: {full_df.memory_usage(deep=True).sum() / 1024**2:.2f} MB")

if __name__ == '__main__':
    data_pattern = 'data/DWC_KXLCLS_OD_DAY_SIDO_SEOULGU_*.csv'
    output_path = 'data/seoulgu.parquet'
    build_parquet(data_pattern, output_path)