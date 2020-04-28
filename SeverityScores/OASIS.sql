WITH
  surgflag AS (
  SELECT
    ie.icustay_id,
    MAX(CASE
        WHEN LOWER(curr_service) LIKE '%surg%' THEN 1
        WHEN curr_service = 'ORTHO' THEN 1
      ELSE
      0
    END
      ) AS surgical
  FROM
    `physionet-data.mimiciii_clinical.icustays` ie
  LEFT JOIN
    `physionet-data.mimiciii_clinical.services` se
  ON
    ie.hadm_id = se.hadm_id
    AND se.transfertime < DATETIME_ADD(ie.intime,
      INTERVAL 1 day)
  GROUP BY
    ie.icustay_id ),
  cohort AS (
  SELECT
    ie.subject_id,
    ie.hadm_id,
    ie.icustay_id,
    ie.intime,
    ie.outtime,
    adm.deathtime,
    ROUND(DATETIME_DIFF(ie.INTIME,
        adm.ADMITTIME,
        Hour), 2) AS PreICULOS,
    DATETIME_DIFF(ie.INTIME,
      pat.DOB,
      Year) AS age
    #, cast(ie.intime as timestamp) - cast(adm.admittime as timestamp) as PreICULOS
    #, floor( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 ) as age
    ,
    gcs.mingcs,
    vital.heartrate_max,
    vital.heartrate_min,
    vital.meanbp_max,
    vital.meanbp_min,
    vital.resprate_max,
    vital.resprate_min,
    vital.tempc_max,
    vital.tempc_min,
    vent.vent AS mechvent,
    uo.urineoutput,
    CASE
      WHEN adm.ADMISSION_TYPE = 'ELECTIVE' AND sf.surgical = 1 THEN 1
      WHEN adm.ADMISSION_TYPE IS NULL
    OR sf.surgical IS NULL THEN NULL
    ELSE
    0
  END
    AS ElectiveSurgery
    -- age group
    ,
    CASE
      WHEN DATETIME_DIFF(ie.intime, pat.dob, Year) <= 1 THEN 'neonate'
      WHEN DATETIME_DIFF(ie.intime,
      pat.dob,
      Year) <= 15 THEN 'middle'
    #when ( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 ) <= 1 then 'neonate'
    #when ( ( cast(ie.intime as date) - cast(pat.dob as date) ) / 365.242 ) <= 15 then 'middle'
    ELSE
    'adult'
  END
    AS ICUSTAY_AGE_GROUP
    -- mortality flags
    ,
    CASE
      WHEN adm.deathtime BETWEEN ie.intime AND ie.outtime THEN 1
      WHEN adm.deathtime <= ie.intime -- sometimes there are typographical errors in the death date
    THEN 1
      WHEN adm.dischtime <= ie.outtime AND adm.discharge_location = 'DEAD/EXPIRED' THEN 1
    ELSE
    0
  END
    AS ICUSTAY_EXPIRE_FLAG,
    adm.hospital_expire_flag
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
  LEFT JOIN
    surgflag sf
  ON
    ie.icustay_id = sf.icustay_id
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
    `mimic-267216.base_data.Ventfirstday` vent
  ON
    ie.icustay_id = vent.icustay_id ),
  scorecomp AS (
  SELECT
    co.subject_id,
    co.hadm_id,
    co.icustay_id,
    co.ICUSTAY_AGE_GROUP,
    co.icustay_expire_flag,
    co.hospital_expire_flag
    -- Below code calculates the component scores needed for OASIS
    ,
    CASE
      WHEN preiculos IS NULL THEN NULL
      WHEN preiculos > 0
    AND preiculos < 0.17 THEN 5
      WHEN preiculos >= 0.17 AND preiculos < 4.95 THEN 3
      WHEN preiculos >= 4.95
    AND preiculos < 24.01 THEN 0
      WHEN preiculos >= 24.1 AND preiculos < 311.81 THEN 2
      WHEN preiculos > 311.80 THEN 1
    ELSE
    2
  END
    AS preiculos_score,
    CASE
      WHEN age IS NULL THEN NULL
      WHEN age < 24 THEN 0
      WHEN age <= 53 THEN 3
      WHEN age <= 77 THEN 6
      WHEN age <= 89 THEN 9
      WHEN age >= 90 THEN 7
    ELSE
    0
  END
    AS age_score,
    CASE
      WHEN mingcs IS NULL THEN NULL
      WHEN mingcs <= 7 THEN 10
      WHEN mingcs < 14 THEN 4
      WHEN mingcs = 14 THEN 3
    ELSE
    0
  END
    AS gcs_score,
    CASE
      WHEN heartrate_max IS NULL THEN NULL
      WHEN heartrate_max > 125 THEN 6
      WHEN heartrate_min < 33 THEN 4
      WHEN heartrate_max >= 107
    AND heartrate_max <= 125 THEN 3
      WHEN heartrate_max >= 89 AND heartrate_max <= 106 THEN 1
    ELSE
    0
  END
    AS heartrate_score,
    CASE
      WHEN meanbp_min IS NULL THEN NULL
      WHEN meanbp_min < 20.65 THEN 4
      WHEN meanbp_min < 51 THEN 3
      WHEN meanbp_max > 143.44 THEN 3
      WHEN meanbp_min >= 51 AND meanbp_min < 61.33 THEN 2
    ELSE
    0
  END
    AS meanbp_score,
    CASE
      WHEN resprate_min IS NULL THEN NULL
      WHEN resprate_min < 6 THEN 10
      WHEN resprate_max > 44 THEN 9
      WHEN resprate_max > 30 THEN 6
      WHEN resprate_max > 22 THEN 1
      WHEN resprate_min < 13 THEN 1
    ELSE
    0
  END
    AS resprate_score,
    CASE
      WHEN tempc_max IS NULL THEN NULL
      WHEN tempc_max > 39.88 THEN 6
      WHEN tempc_min >= 33.22 AND tempc_min <= 35.93 THEN 4
      WHEN tempc_max >= 33.22
    AND tempc_max <= 35.93 THEN 4
      WHEN tempc_min < 33.22 THEN 3
      WHEN tempc_min > 35.93
    AND tempc_min <= 36.39 THEN 2
      WHEN tempc_max >= 36.89 AND tempc_max <= 39.88 THEN 2
    ELSE
    0
  END
    AS temp_score,
    CASE
      WHEN UrineOutput IS NULL THEN NULL
      WHEN UrineOutput < 671.09 THEN 10
      WHEN UrineOutput > 6896.80 THEN 8
      WHEN UrineOutput >= 671.09
    AND UrineOutput <= 1426.99 THEN 5
      WHEN UrineOutput >= 1427.00 AND UrineOutput <= 2544.14 THEN 1
    ELSE
    0
  END
    AS UrineOutput_score,
    CASE
      WHEN mechvent IS NULL THEN NULL
      WHEN mechvent = 1 THEN 9
    ELSE
    0
  END
    AS mechvent_score,
    CASE
      WHEN ElectiveSurgery IS NULL THEN NULL
      WHEN ElectiveSurgery = 1 THEN 0
    ELSE
    6
  END
    AS electivesurgery_score
    -- The below code gives the component associated with each score
    -- This is not needed to calculate OASIS, but provided for user convenience.
    -- If both the min/max are in the normal range (score of 0), then the average value is stored.
    ,
    preiculos,
    age,
    mingcs AS gcs,
    CASE
      WHEN heartrate_max IS NULL THEN NULL
      WHEN heartrate_max > 125 THEN heartrate_max
      WHEN heartrate_min < 33 THEN heartrate_min
      WHEN heartrate_max >= 107
    AND heartrate_max <= 125 THEN heartrate_max
      WHEN heartrate_max >= 89 AND heartrate_max <= 106 THEN heartrate_max
    ELSE
    (heartrate_min+heartrate_max)/2
  END
    AS heartrate,
    CASE
      WHEN meanbp_min IS NULL THEN NULL
      WHEN meanbp_min < 20.65 THEN meanbp_min
      WHEN meanbp_min < 51 THEN meanbp_min
      WHEN meanbp_max > 143.44 THEN meanbp_max
      WHEN meanbp_min >= 51 AND meanbp_min < 61.33 THEN meanbp_min
    ELSE
    (meanbp_min+meanbp_max)/2
  END
    AS meanbp,
    CASE
      WHEN resprate_min IS NULL THEN NULL
      WHEN resprate_min < 6 THEN resprate_min
      WHEN resprate_max > 44 THEN resprate_max
      WHEN resprate_max > 30 THEN resprate_max
      WHEN resprate_max > 22 THEN resprate_max
      WHEN resprate_min < 13 THEN resprate_min
    ELSE
    (resprate_min+resprate_max)/2
  END
    AS resprate,
    CASE
      WHEN tempc_max IS NULL THEN NULL
      WHEN tempc_max > 39.88 THEN tempc_max
      WHEN tempc_min >= 33.22 AND tempc_min <= 35.93 THEN tempc_min
      WHEN tempc_max >= 33.22
    AND tempc_max <= 35.93 THEN tempc_max
      WHEN tempc_min < 33.22 THEN tempc_min
      WHEN tempc_min > 35.93
    AND tempc_min <= 36.39 THEN tempc_min
      WHEN tempc_max >= 36.89 AND tempc_max <= 39.88 THEN tempc_max
    ELSE
    (tempc_min+tempc_max)/2
  END
    AS temp,
    UrineOutput,
    mechvent,
    ElectiveSurgery
  FROM
    cohort co ),
  score AS (
  SELECT
    s.*,
    coalesce(age_score,
      0) + coalesce(preiculos_score,
      0) + coalesce(gcs_score,
      0) + coalesce(heartrate_score,
      0) + coalesce(meanbp_score,
      0) + coalesce(resprate_score,
      0) + coalesce(temp_score,
      0) + coalesce(urineoutput_score,
      0) + coalesce(mechvent_score,
      0) + coalesce(electivesurgery_score,
      0) AS OASIS
  FROM
    scorecomp s )
SELECT
  subject_id,
  hadm_id,
  icustay_id,
  ICUSTAY_AGE_GROUP,
  hospital_expire_flag,
  icustay_expire_flag,
  OASIS
  -- Calculate the probability of in-hospital mortality
  ,
  1 / (1 + EXP(- (-6.1746 + 0.1275*(OASIS) ))) AS OASIS_PROB,
  age,
  age_score,
  preiculos,
  preiculos_score,
  gcs,
  gcs_score,
  heartrate,
  heartrate_score,
  meanbp,
  meanbp_score,
  resprate,
  resprate_score,
  temp,
  temp_score,
  urineoutput,
  UrineOutput_score,
  mechvent,
  mechvent_score,
  electivesurgery,
  electivesurgery_score
FROM
  score
ORDER BY
  icustay_id;