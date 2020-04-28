  -- get all heights from chartevents
WITH
  chartevents_heights AS (
  SELECT
    co.ICUSTAY_ID,
    VALUENUM,
    VALUEUOM,
    c.CHARTTIME
  FROM
    `mimic-267216.CohorSelection_Pneumonia.6_StartedOnBroad` AS co
  LEFT JOIN
    `physionet-data.mimiciii_clinical.chartevents` AS c
  ON
    co.Subject_id = c.Subject_id
    AND co.HADM_ID = c.HADM_ID
    AND co.ICUSTAY_ID = c.ICUSTAY_ID
    AND c.ITEMID IN (226730,
      920,
      1394,
      4187,
      3486,
      3485,
      4188,
      3693)
  WHERE
    c.VALUENUM IS NOT NULL
    AND (c.ERROR IS NULL
      OR c.ERROR = 0) )
  -- get all weights from chartevents
  ,
  chartevents_weights AS (
  SELECT
    co.ICUSTAY_ID,
    VALUENUM,
    VALUEUOM,
    c.CHARTTIME
  FROM
    `mimic-267216.CohorSelection_Pneumonia.6_StartedOnBroad` AS co
  LEFT JOIN
    `physionet-data.mimiciii_clinical.chartevents` AS c
  ON
    co.Subject_id = c.Subject_id
    AND co.HADM_ID = c.HADM_ID
    AND co.ICUSTAY_ID = c.ICUSTAY_ID
    AND c.ITEMID IN (763,
      224639,
      762,
      226512 )
  WHERE
    c.VALUENUM IS NOT NULL
    AND (c.ERROR IS NULL
      OR c.ERROR = 0)
  GROUP BY
    co.ICUSTAY_ID,
    VALUENUM,
    VALUEUOM,
    c.CHARTTIME )
  -- get all weight and hight measuremnats from noteevents 
  ,
  echo_weight AS (
  SELECT
    ie.subject_id,
    weight,
    ec.chartdate
  FROM
    `mimic-267216.CohorSelection_Pneumonia.6_StartedOnBroad` ie
  INNER JOIN
    `physionet-data.mimiciii_derived.echodata_structured` ec
  ON
    ec.subject_id = ie.subject_id
  WHERE
    height IS NOT NULL ),
  echo_height AS (
  SELECT
    ie.subject_id,
    height,
    ec.chartdate
  FROM
    `mimic-267216.CohorSelection_Pneumonia.6_StartedOnBroad` ie
  INNER JOIN
    `physionet-data.mimiciii_derived.echodata_structured` ec
  ON
    ec.subject_id = ie.subject_id
  WHERE
    height IS NOT NULL
    AND height*2.54 > 100 )
SELECT
  *
FROM
  echo_height