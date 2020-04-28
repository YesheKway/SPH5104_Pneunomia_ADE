WITH
  onlyBlood AS (
  SELECT
    abx.SUBJECT_ID,
    abx.HADM_ID,
    abx.ICUSTAY_ID,
    m.SPEC_TYPE_DESC,
    m.CHARTDATE
  FROM
    `mimic-267216.CohorSelection_Pneumonia.5_all_ABX` AS abx
  INNER JOIN
    `physionet-data.mimiciii_clinical.microbiologyevents` AS m
  ON
    abx.Subject_id = m.SUBJECT_ID
    AND abx.HADM_ID = m.HADM_ID
  WHERE
    m.SPEC_TYPE_DESC LIKE '%BLOOD%'
    AND m.SPEC_TYPE_DESC != 'FLUID RECEIVED IN BLOOD CULTURE BOTTLES' )
  #select count(distinct(SUBJECT_ID)) from onlyBlood
  ,
  seq_b AS (
  SELECT
    o.*,
    DENSE_RANK() OVER (PARTITION BY o.subject_id ORDER BY o.CHARTDATE) AS pres_seq
  FROM
    onlyBlood AS o ),
  firstDate AS (
  SELECT
    s.Subject_id,
    s.HADM_ID,
    s.ICUSTAY_ID,
    s.Chartdate
  FROM
    seq_b AS s
  WHERE
    s.pres_seq = 1
  GROUP BY
    Subject_id,
    HADM_ID,
    ICUSTAY_ID,
    Chartdate )
  #select count(distinct(SUBJECT_ID)) from firstDate
  ,
  allbroad AS (
  SELECT
    a.SUBJECT_ID,
    a.HADM_ID,
    a.ICUSTAY_ID,
    a.STARTDATE,
    a.AbxClass
  FROM
    `mimic-267216.CohorSelection_Pneumonia.5_all_ABX` AS a
  WHERE
    a.AbxClass = 'Broad'
  GROUP BY
    a.SUBJECT_ID,
    a.HADM_ID,
    a.ICUSTAY_ID,
    a.STARTDATE,
    a.AbxClass ),
  firstDataBroad AS (
  SELECT
    a.*,
    DENSE_RANK() OVER (PARTITION BY a.subject_id ORDER BY a.Startdate) AS pres_seq
  FROM
    allbroad AS a ),
  firstABXpre AS (
  SELECT
    a.SUBJECT_ID,
    a.HADM_ID,
    a.ICUSTAY_ID,
    a.STARTDATE
  FROM
    firstDataBroad AS a
  WHERE
    a.pres_seq = 1
  ORDER BY
    SUBJECT_ID )
SELECT
  a.SUBJECT_ID,
  a.HADM_ID,
  a.ICUSTAY_ID,
  a.STARTDATE,
  chart.Chartdate
FROM
  firstABXpre AS a
INNER JOIN
  firstDate AS chart
ON
  a.Subject_id = chart.Subject_id
  AND a.HADM_ID = chart.HADM_ID
  AND a.ICUSTAY_ID = chart.ICUSTAY_ID
WHERE
  a.STARTDATE <=DATETIME_ADD(chart.chartdate,
    INTERVAL 1 day)
  AND a.SUBJECT_ID != 26671