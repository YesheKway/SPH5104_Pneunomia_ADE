  -- extract CPAP from the "Oxygen Delivery Device" fields
WITH
  cpap AS (
  SELECT
    ie.icustay_id,
    MIN(DATETIME_SUB(charttime,
        INTERVAL 1 hour)) AS starttime,
    MAX(DATETIME_ADD(charttime,
        INTERVAL 4 hour)) AS endtime
    #, max(case when lower(ce.value) similar to '%(cpap mask|bipap mask)%' then 1 else 0 end) as cpap
    ,
    MAX(CASE
        WHEN LOWER(ce.value) LIKE '%cpap mask%' OR LOWER(ce.value) LIKE '%bipap mask%' THEN 1
      ELSE
      0
    END
      ) AS cpap
  FROM
    `physionet-data.mimiciii_clinical.icustays` ie
  INNER JOIN
    `physionet-data.mimiciii_clinical.chartevents` ce
  ON
    ie.icustay_id = ce.icustay_id
    AND ce.charttime BETWEEN ie.intime
    AND DATETIME_ADD(ie.intime,
      INTERVAL 1 day)
  WHERE
    itemid IN (
      -- TODO: when metavision data import fixed, check the values in 226732 match the value clause below
      467,
      469,
      226732 )
    #and lower(ce.value) similar to '%(cpap mask|bipap mask)%'
    AND LOWER(ce.value) LIKE '%cpap mask%'
    OR LOWER(ce.value) LIKE '%bipap mask)%'
    -- exclude rows marked as error
    AND ce.error != 1
  GROUP BY
    ie.icustay_id )
  -- extract a flag for surgical service
  -- this combined with "elective" from admissions table defines elective/non-elective surgery
  ,
  surgflag AS (
  SELECT
    adm.hadm_id,
    CASE
      WHEN LOWER(curr_service) LIKE '%surg%' THEN 1
    ELSE
    0
  END
    AS surgical,
    ROW_NUMBER() OVER (PARTITION BY adm.HADM_ID ORDER BY TRANSFERTIME ) AS serviceOrder
  FROM
    `physionet-data.mimiciii_clinical.admissions` adm
  LEFT JOIN
    `physionet-data.mimiciii_clinical.services` se
  ON
    adm.hadm_id = se.hadm_id )
  -- icd-9 diagnostic codes are our best source for comorbidity information
  -- unfortunately, they are technically a-causal
  -- however, this shouldn't matter too much for the SAPS II comorbidities
  ,
  comorb AS (
  SELECT
    hadm_id
    -- these are slightly different than elixhauser comorbidities, but based on them
    -- they include some non-comorbid ICD-9 codes (e.g. 20302, relapse of multiple myeloma)
    ,
    MAX(CASE
        WHEN icd9_code BETWEEN '042  ' AND '0449 ' THEN 1
    END
      ) AS AIDS /* HIV and AIDS */,
    MAX(CASE
        WHEN icd9_code BETWEEN '20000' AND '20238' THEN 1 -- lymphoma
        WHEN icd9_code BETWEEN '20240'
      AND '20248' THEN 1 -- leukemia
        WHEN icd9_code BETWEEN '20250' AND '20302' THEN 1 -- lymphoma
        WHEN icd9_code BETWEEN '20310'
      AND '20312' THEN 1 -- leukemia
        WHEN icd9_code BETWEEN '20302' AND '20382' THEN 1 -- lymphoma
        WHEN icd9_code BETWEEN '20400'
      AND '20522' THEN 1 -- chronic leukemia
        WHEN icd9_code BETWEEN '20580' AND '20702' THEN 1 -- other myeloid leukemia
        WHEN icd9_code BETWEEN '20720'
      AND '20892' THEN 1 -- other myeloid leukemia
        WHEN icd9_code = '2386 ' THEN 1 -- lymphoma
        WHEN icd9_code = '2733 ' THEN 1 -- lymphoma
    END
      ) AS HEM,
    MAX(CASE
        WHEN icd9_code BETWEEN '1960 ' AND '1991 ' THEN 1
        WHEN icd9_code BETWEEN '20970'
      AND '20975' THEN 1
        WHEN icd9_code = '20979' THEN 1
        WHEN icd9_code = '78951' THEN 1
    END
      ) AS METS /* Metastatic cancer */
  FROM (
    SELECT
      hadm_id,
      seq_num,
      CAST(icd9_code AS STRING) AS icd9_code
    FROM
      `physionet-data.mimiciii_clinical.diagnoses_icd` ) icd
  GROUP BY
    hadm_id ),
  pafi1 AS (
    -- join blood gas to ventilation durations to determine if patient was vent
    -- also join to cpap table for the same purpose
  SELECT
    bg.icustay_id,
    bg.charttime,
    PaO2FiO2,
    CASE
      WHEN vd.icustay_id IS NOT NULL THEN 1
    ELSE
    0
  END
    AS vent,
    CASE
      WHEN cp.icustay_id IS NOT NULL THEN 1
    ELSE
    0
  END
    AS cpap
  FROM
    `mimic-267216.Generals.bloodgasaterial_firstday` bg
  LEFT JOIN
    `mimic-267216.base_data.VentilationDuration` vd
  ON
    bg.icustay_id = vd.icustay_id
    AND bg.charttime >= vd.starttime
    AND bg.charttime <= vd.endtime
  LEFT JOIN
    cpap cp
  ON
    bg.icustay_id = cp.icustay_id
    AND bg.charttime >= cp.starttime
    AND bg.charttime <= cp.endtime ),
  pafi2 AS (
    -- get the minimum PaO2/FiO2 ratio *only for ventilated/cpap patients*
  SELECT
    icustay_id,
    MIN(PaO2FiO2) AS PaO2FiO2_vent_min
  FROM
    pafi1
  WHERE
    vent = 1
    OR cpap = 1
  GROUP BY
    icustay_id ),
  cohort AS (
  SELECT
    ie.subject_id,
    ie.hadm_id,
    ie.icustay_id,
    ie.intime,
    ie.outtime
    -- the casts ensure the result is numeric.. we could equally extract EPOCH from the interval
    -- however this code works in Oracle and Postgres
    ,
    ROUND( DATETIME_DIFF( ie.intime,
        pat.dob,
        YEAR), 2 ) AS age,
    vital.heartrate_max,
    vital.heartrate_min,
    vital.sysbp_max,
    vital.sysbp_min,
    vital.tempc_max,
    vital.tempc_min
    -- this value is non-null iff the patient is on vent/cpap
    ,
    pf.PaO2FiO2_vent_min,
    uo.urineoutput,
    labs.bun_min,
    labs.bun_max,
    labs.wbc_min,
    labs.wbc_max,
    labs.potassium_min,
    labs.potassium_max,
    labs.sodium_min,
    labs.sodium_max,
    labs.bicarbonate_min,
    labs.bicarbonate_max,
    labs.bilirubin_min,
    labs.bilirubin_max,
    gcs.mingcs,
    comorb.AIDS,
    comorb.HEM,
    comorb.METS,
    CASE
      WHEN adm.ADMISSION_TYPE = 'ELECTIVE' AND sf.surgical = 1 THEN 'ScheduledSurgical'
      WHEN adm.ADMISSION_TYPE != 'ELECTIVE'
    AND sf.surgical = 1 THEN 'UnscheduledSurgical'
    ELSE
    'Medical'
  END
    AS AdmissionType
  FROM
    `physionet-data.mimiciii_clinical.icustays` ie
  INNER JOIN
    `physionet-data.mimiciii_clinical.admissions` adm
  ON
    ie.hadm_id = adm.hadm_id
  INNER JOIN
    `physionet-data.mimiciii_clinical.patients` pat
  ON
    ie.subject_id = pat.subject_id
    -- join to above views
  LEFT JOIN
    pafi2 pf
  ON
    ie.icustay_id = pf.icustay_id
  LEFT JOIN
    surgflag sf
  ON
    adm.hadm_id = sf.hadm_id
    AND sf.serviceOrder = 1
  LEFT JOIN
    comorb
  ON
    ie.hadm_id = comorb.hadm_id
    -- join to custom tables to get more data....
  LEFT JOIN
    `mimic-267216.Generals.gcs_firstday` gcs
  ON
    ie.icustay_id = gcs.icustay_id
  LEFT JOIN
    `mimic-267216.base_data.First24h_Vitals` vital
  ON
    ie.icustay_id = vital.icustay_id
  LEFT JOIN
    `mimic-267216.Generals.urine_output_firstday` uo
  ON
    ie.icustay_id = uo.icustay_id
  LEFT JOIN
    `mimic-267216.base_data.First24h_LabResults` labs
  ON
    ie.icustay_id = labs.icustay_id ),
  scorecomp AS (
  SELECT
    cohort.*
    -- Below code calculates the component scores needed for SAPS
    ,
    CASE
      WHEN age IS NULL THEN NULL
      WHEN age < 40 THEN 0
      WHEN age < 60 THEN 7
      WHEN age < 70 THEN 12
      WHEN age < 75 THEN 15
      WHEN age < 80 THEN 16
      WHEN age >= 80 THEN 18
  END
    AS age_score,
    CASE
      WHEN heartrate_max IS NULL THEN NULL
      WHEN heartrate_min < 40 THEN 11
      WHEN heartrate_max >= 160 THEN 7
      WHEN heartrate_max >= 120 THEN 4
      WHEN heartrate_min < 70 THEN 2
      WHEN heartrate_max >= 70
    AND heartrate_max < 120
    AND heartrate_min >= 70
    AND heartrate_min < 120 THEN 0
  END
    AS hr_score,
    CASE
      WHEN sysbp_min IS NULL THEN NULL
      WHEN sysbp_min < 70 THEN 13
      WHEN sysbp_min < 100 THEN 5
      WHEN sysbp_max >= 200 THEN 2
      WHEN sysbp_max >= 100 AND sysbp_max < 200 AND sysbp_min >= 100 AND sysbp_min < 200 THEN 0
  END
    AS sysbp_score,
    CASE
      WHEN tempc_max IS NULL THEN NULL
      WHEN tempc_min < 39.0 THEN 0
      WHEN tempc_max >= 39.0 THEN 3
  END
    AS temp_score,
    CASE
      WHEN PaO2FiO2_vent_min IS NULL THEN NULL
      WHEN PaO2FiO2_vent_min < 100 THEN 11
      WHEN PaO2FiO2_vent_min < 200 THEN 9
      WHEN PaO2FiO2_vent_min >= 200 THEN 6
  END
    AS PaO2FiO2_score,
    CASE
      WHEN UrineOutput IS NULL THEN NULL
      WHEN UrineOutput < 500.0 THEN 11
      WHEN UrineOutput < 1000.0 THEN 4
      WHEN UrineOutput >= 1000.0 THEN 0
  END
    AS uo_score,
    CASE
      WHEN bun_max IS NULL THEN NULL
      WHEN bun_max < 28.0 THEN 0
      WHEN bun_max < 84.0 THEN 6
      WHEN bun_max >= 84.0 THEN 10
  END
    AS bun_score,
    CASE
      WHEN wbc_max IS NULL THEN NULL
      WHEN wbc_min < 1.0 THEN 12
      WHEN wbc_max >= 20.0 THEN 3
      WHEN wbc_max >= 1.0
    AND wbc_max < 20.0
    AND wbc_min >= 1.0
    AND wbc_min < 20.0 THEN 0
  END
    AS wbc_score,
    CASE
      WHEN potassium_max IS NULL THEN NULL
      WHEN potassium_min < 3.0 THEN 3
      WHEN potassium_max >= 5.0 THEN 3
      WHEN potassium_max >= 3.0
    AND potassium_max < 5.0
    AND potassium_min >= 3.0
    AND potassium_min < 5.0 THEN 0
  END
    AS potassium_score,
    CASE
      WHEN sodium_max IS NULL THEN NULL
      WHEN sodium_min < 125 THEN 5
      WHEN sodium_max >= 145 THEN 1
      WHEN sodium_max >= 125
    AND sodium_max < 145
    AND sodium_min >= 125
    AND sodium_min < 145 THEN 0
  END
    AS sodium_score,
    CASE
      WHEN bicarbonate_max IS NULL THEN NULL
      WHEN bicarbonate_min < 15.0 THEN 5
      WHEN bicarbonate_min < 20.0 THEN 3
      WHEN bicarbonate_max >= 20.0
    AND bicarbonate_min >= 20.0 THEN 0
  END
    AS bicarbonate_score,
    CASE
      WHEN bilirubin_max IS NULL THEN NULL
      WHEN bilirubin_max < 4.0 THEN 0
      WHEN bilirubin_max < 6.0 THEN 4
      WHEN bilirubin_max >= 6.0 THEN 9
  END
    AS bilirubin_score,
    CASE
      WHEN mingcs IS NULL THEN NULL
      WHEN mingcs < 3 THEN NULL -- erroneous value/on trach
      WHEN mingcs < 6 THEN 26
      WHEN mingcs < 9 THEN 13
      WHEN mingcs < 11 THEN 7
      WHEN mingcs < 14 THEN 5
      WHEN mingcs >= 14 AND mingcs <= 15 THEN 0
  END
    AS gcs_score,
    CASE
      WHEN AIDS = 1 THEN 17
      WHEN HEM = 1 THEN 10
      WHEN METS = 1 THEN 9
    ELSE
    0
  END
    AS comorbidity_score,
    CASE
      WHEN AdmissionType = 'ScheduledSurgical' THEN 0
      WHEN AdmissionType = 'Medical' THEN 6
      WHEN AdmissionType = 'UnscheduledSurgical' THEN 8
    ELSE
    NULL
  END
    AS admissiontype_score
  FROM
    cohort )
  -- Calculate SAPS II here so we can use it in the probability calculation below
  ,
  score AS (
  SELECT
    s.*
    -- coalesce statements impute normal score of zero if data element is missing
    ,
    coalesce(age_score,
      0) + coalesce(hr_score,
      0) + coalesce(sysbp_score,
      0) + coalesce(temp_score,
      0) + coalesce(PaO2FiO2_score,
      0) + coalesce(uo_score,
      0) + coalesce(bun_score,
      0) + coalesce(wbc_score,
      0) + coalesce(potassium_score,
      0) + coalesce(sodium_score,
      0) + coalesce(bicarbonate_score,
      0) + coalesce(bilirubin_score,
      0) + coalesce(gcs_score,
      0) + coalesce(comorbidity_score,
      0) + coalesce(admissiontype_score,
      0) AS SAPSII
  FROM
    scorecomp s )
SELECT
  ie.subject_id,
  ie.hadm_id,
  ie.icustay_id,
  SAPSII,
  1 / (1 + EXP(- (-7.7631 + 0.0737*(SAPSII) + 0.9971*(LN(SAPSII + 1))) )) AS SAPSII_PROB,
  age_score,
  hr_score,
  sysbp_score,
  temp_score,
  PaO2FiO2_score,
  uo_score,
  bun_score,
  wbc_score,
  potassium_score,
  sodium_score,
  bicarbonate_score,
  bilirubin_score,
  gcs_score,
  comorbidity_score,
  admissiontype_score
FROM
  `physionet-data.mimiciii_clinical.icustays` ie
LEFT JOIN
  score s
ON
  ie.icustay_id = s.icustay_id
ORDER BY
  ie.icustay_id;