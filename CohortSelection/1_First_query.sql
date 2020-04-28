  -- this query performs the first step of the cohor selection and selects
  -- patinets older than 15 and excluded patients admitted to CSRU or TSICU
  -- further it extracts the basic patients` infomation
WITH
  myCohort AS (
  SELECT
    --- pateint information
    pat.GENDER,
    pat.DOD,
    CASE
      WHEN pat.dod <= DATETIME_ADD(adm.ADMITTIME, INTERVAL 30 day) AND pat.dod IS NOT NULL THEN 1
    ELSE
    0
  END
    AS mortality30
    --- admission infomation
    ,
    ie.subject_id,
    ie.hadm_id,
    adm.admittime,
    adm.DISCHTIME,
    adm.ADMISSION_LOCATION,
    adm.ADMISSION_TYPE,
    adm.INSURANCE,
    adm.Ethnicity,
    CASE
      WHEN adm.ethnicity IN ( 'WHITE' -- 40996
      , 'WHITE - RUSSIAN' --    164
      , 'WHITE - OTHER EUROPEAN' --     81
      , 'WHITE - BRAZILIAN' --     59
      , 'WHITE - EASTERN EUROPEAN' --     25
      ) THEN 'white'
      WHEN adm.ethnicity IN ( 'BLACK/AFRICAN AMERICAN' --   5440
      ,
      'BLACK/CAPE VERDEAN' --    200
      ,
      'BLACK/HAITIAN' --    101
      ,
      'BLACK/AFRICAN' --     44
      ,
      'CARIBBEAN ISLAND' --      9
      ) THEN 'black'
      WHEN adm.ethnicity IN ( 'HISPANIC OR LATINO' --   1696
      , 'HISPANIC/LATINO - PUERTO RICAN' --    232
      , 'HISPANIC/LATINO - DOMINICAN' --     78
      , 'HISPANIC/LATINO - GUATEMALAN' --     40
      , 'HISPANIC/LATINO - CUBAN' --     24
      , 'HISPANIC/LATINO - SALVADORAN' --     19
      , 'HISPANIC/LATINO - CENTRAL AMERICAN (OTHER)' --     13
      , 'HISPANIC/LATINO - MEXICAN' --     13
      , 'HISPANIC/LATINO - COLOMBIAN' --      9
      , 'HISPANIC/LATINO - HONDURAN' --      4
      ) THEN 'hispanic'
      WHEN adm.ethnicity IN ( 'ASIAN' --   1509
      ,
      'ASIAN - CHINESE' --    277
      ,
      'ASIAN - ASIAN INDIAN' --     85
      ,
      'ASIAN - VIETNAMESE' --     53
      ,
      'ASIAN - FILIPINO' --     25
      ,
      'ASIAN - CAMBODIAN' --     17
      ,
      'ASIAN - OTHER' --     17
      ,
      'ASIAN - KOREAN' --     13
      ,
      'ASIAN - JAPANESE' --      7
      ,
      'ASIAN - THAI' --      4
      ) THEN 'asian'
      WHEN adm.ethnicity IN ( 'AMERICAN INDIAN/ALASKA NATIVE' --     51
      , 'AMERICAN INDIAN/ALASKA NATIVE FEDERALLY RECOGNIZED TRIBE' --      3
      ) THEN 'native'
      WHEN adm.ethnicity IN ( 'UNKNOWN/NOT SPECIFIED' --   4523
      ,
      'UNABLE TO OBTAIN' --    814
      ,
      'PATIENT DECLINED TO ANSWER' --    559
      ) THEN 'unknown'
    ELSE
    'other'
  END
    AS ethnicity_grouped,
    DATETIME_DIFF(adm.admittime,
      pat.dob,
      Year) AS AGE_ADMISSION,
    ROUND(DATETIME_DIFF(adm.DISCHTIME,
        adm.ADMITTIME,
        Day), 2) AS LOS_HOSP,
    DENSE_RANK() OVER (PARTITION BY adm.subject_id ORDER BY adm.admittime) AS hospstay_seq,
    CASE
      WHEN DENSE_RANK() OVER (PARTITION BY adm.subject_id ORDER BY adm.admittime) = 1 THEN TRUE
    ELSE
    FALSE
  END
    AS first_hosp_stay
    --- icu information
    ,
    ie.ICUSTAY_ID,
    ie.INTIME,
    ie.LOS AS LOS_ICU,
    ie.OUTTIME,
    ie.FIRST_CAREUNIT,
    CASE
      WHEN DENSE_RANK() OVER (PARTITION BY ie.hadm_id ORDER BY ie.intime) = 1 THEN TRUE
    ELSE
    FALSE
  END
    AS first_icu_stay
  FROM
    `physionet-data.mimiciii_clinical.icustays` ie
  INNER JOIN
    `physionet-data.mimiciii_clinical.admissions` adm
  ON
    ie.hadm_id = adm.hadm_id
    AND ie.SUBJECT_ID = adm.SUBJECT_ID
  INNER JOIN
    `physionet-data.mimiciii_clinical.patients` pat
  ON
    ie.subject_id = pat.subject_id
  ORDER BY
    ie.subject_id,
    adm.admittime,
    ie.intime )
  #select count(distinct(subject_id)) from myCohort as c where c.AGE_ADMISSION>=16
  #2.-> exclude patinets from CSRU and TSICU and age above 16 and penumonia as main diagnosis
  # additionally filter so that we extract the ICU and Hospital id for theri very first admission
  ,
  step2 AS (
    #count(distinct(mc.SUBJECT_ID))
  SELECT
    co.SUBJECT_ID,
    co.HADM_ID,
    co.ADMITTIME,
    co.DISCHTIME,
    co.ICUSTAY_ID,
    co.INTIME,
    co.OUTTIME,
    co.LOS_ICU,
    LOS_HOSP,
    co.AGE_ADMISSION,
    GENDER,
    ethnicity_grouped AS Ethnicity,
    co.INSURANCE,
    ADMISSION_LOCATION,
    DOD,
    FIRST_CAREUNIT,
    mortality30,
    DENSE_RANK() OVER (PARTITION BY co.subject_id ORDER BY co.admittime) AS hospstay_seq,
    CASE
      WHEN DENSE_RANK() OVER (PARTITION BY co.hadm_id ORDER BY co.intime) = 1 THEN TRUE
    ELSE
    FALSE
  END
    AS first_icu_stay
  FROM
    myCohort AS co
  INNER JOIN
    `physionet-data.mimiciii_clinical.diagnoses_icd` AS dia
  ON
    co.HADM_ID = dia.HADM_ID
    AND co.SUBJECT_ID = dia.SUBJECT_ID
  INNER JOIN
    `physionet-data.mimiciii_clinical.d_icd_diagnoses` AS d_dia
  ON
    d_dia.ICD9_CODE = dia.ICD9_CODE
    AND dia.ICD9_CODE IN ('480',
      '481',
      '482',
      '483',
      '484',
      '485',
      '486',
      '487')
    AND dia.SEQ_NUM = 1
  WHERE
    co.AGE_ADMISSION >=16
    AND co.FIRST_CAREUNIT != 'CSRU'
    AND co.FIRST_CAREUNIT != 'TSICU' )
SELECT
  *
FROM
  step2 AS co
WHERE
  co.hospstay_seq = 1
  AND co.first_icu_stay = TRUE