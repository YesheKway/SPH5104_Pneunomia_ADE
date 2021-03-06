WITH
  stg_spo2 AS (
  SELECT
    SUBJECT_ID,
    HADM_ID,
    ICUSTAY_ID,
    CHARTTIME
    -- max here is just used to group SpO2 by charttime
    ,
    MAX(CASE
        WHEN valuenum <= 0 OR valuenum > 100 THEN NULL
      ELSE
      valuenum
    END
      ) AS SpO2
  FROM
    `physionet-data.mimiciii_clinical.chartevents`
    -- o2 sat
  WHERE
    ITEMID IN ( 646 -- SpO2
      ,
      220277 -- O2 saturation pulseoxymetry
      )
  GROUP BY
    SUBJECT_ID,
    HADM_ID,
    ICUSTAY_ID,
    CHARTTIME ),
  stg_fio2 AS (
  SELECT
    SUBJECT_ID,
    HADM_ID,
    ICUSTAY_ID,
    CHARTTIME
    -- pre-process the FiO2s to ensure they are between 21-100%
    ,
    MAX(
      CASE
        WHEN itemid = 223835 THEN CASE
        WHEN valuenum > 0
      AND valuenum <= 1 THEN valuenum * 100
      -- improperly input data - looks like O2 flow in litres
        WHEN valuenum > 1 AND valuenum < 21 THEN NULL
        WHEN valuenum >= 21
      AND valuenum <= 100 THEN valuenum
      ELSE
      NULL
    END
      -- unphysiological
        WHEN itemid IN (3420, 3422)
      -- all these values are well formatted
      THEN valuenum
        WHEN itemid = 190
      AND valuenum > 0.20
      AND valuenum < 1
      -- well formatted but not in %
      THEN valuenum * 100
      ELSE
      NULL
    END
      ) AS fio2_chartevents
  FROM
    `physionet-data.mimiciii_clinical.chartevents`
  WHERE
    ITEMID IN ( 3420 -- FiO2
      ,
      190 -- FiO2 set
      ,
      223835 -- Inspired O2 Fraction (FiO2)
      ,
      3422 -- FiO2 [measured]
      )
    -- exclude rows marked as error
    AND error != 1
  GROUP BY
    SUBJECT_ID,
    HADM_ID,
    ICUSTAY_ID,
    CHARTTIME ),
  stg2 AS (
  SELECT
    bg.*,
    ROW_NUMBER() OVER (PARTITION BY bg.icustay_id, bg.charttime ORDER BY s1.charttime DESC) AS lastRowSpO2,
    s1.spo2
  FROM
    `mimic-267216.Generals.bloodgas_firstday` bg
  LEFT JOIN
    stg_spo2 s1
    -- same patient
  ON
    bg.icustay_id = s1.icustay_id
    -- spo2 occurred at most 2 hours before this blood gas
    AND s1.charttime BETWEEN DATETIME_SUB(bg.charttime,
      INTERVAL 2 hour)
    AND bg.charttime
  WHERE
    bg.po2 IS NOT NULL ),
  stg3 AS (
  SELECT
    bg.*,
    ROW_NUMBER() OVER (PARTITION BY bg.icustay_id, bg.charttime ORDER BY s2.charttime DESC) AS lastRowFiO2,
    s2.fio2_chartevents
    -- create our specimen prediction
    ,
    1/(1+EXP(-(-0.02544 + 0.04598 * po2 + coalesce(-0.15356 * spo2,
            -0.15356 * 97.49420 + 0.13429) + coalesce( 0.00621 * fio2_chartevents,
            0.00621 * 51.49550 + -0.24958) + coalesce( 0.10559 * hemoglobin,
            0.10559 * 10.32307 + 0.05954) + coalesce( 0.13251 * so2,
            0.13251 * 93.66539 + -0.23172) + coalesce(-0.01511 * pco2,
            -0.01511 * 42.08866 + -0.01630) + coalesce( 0.01480 * fio2,
            0.01480 * 63.97836 + -0.31142) + coalesce(-0.00200 * aado2,
            -0.00200 * 442.21186 + -0.01328) + coalesce(-0.03220 * bicarbonate,
            -0.03220 * 22.96894 + -0.06535) + coalesce( 0.05384 * totalco2,
            0.05384 * 24.72632 + -0.01405) + coalesce( 0.08202 * lactate,
            0.08202 * 3.06436 + 0.06038) + coalesce( 0.10956 * ph,
            0.10956 * 7.36233 + -0.00617) + coalesce( 0.00848 * o2flow,
            0.00848 * 7.59362 + -0.35803) ))) AS SPECIMEN_PROB
  FROM
    stg2 bg
  LEFT JOIN
    stg_fio2 s2
    -- same patient
  ON
    bg.icustay_id = s2.icustay_id
    -- fio2 occurred at most 4 hours before this blood gas
    AND s2.charttime BETWEEN DATETIME_SUB(bg.charttime,
      INTERVAL 4 hour)
    AND bg.charttime
  WHERE
    bg.lastRowSpO2 = 1 -- only the row with the most recent SpO2 (if no SpO2 found lastRowSpO2 = 1)
    )
SELECT
  subject_id,
  hadm_id,
  icustay_id,
  charttime,
  SPECIMEN -- raw data indicating sample type, only present 80% of the time
  -- prediction of specimen for missing data
  ,
  CASE
    WHEN SPECIMEN IS NOT NULL THEN SPECIMEN
    WHEN SPECIMEN_PROB > 0.75 THEN 'ART'
  ELSE
  NULL
END
  AS SPECIMEN_PRED,
  SPECIMEN_PROB
  -- oxygen related parameters
  ,
  SO2,
  spo2 -- note spo2 is from chartevents
  ,
  PO2,
  PCO2,
  fio2_chartevents,
  FIO2,
  AADO2
  -- also calculate AADO2
  ,
  CASE
    WHEN PO2 IS NOT NULL AND pco2 IS NOT NULL AND coalesce(FIO2, fio2_chartevents) IS NOT NULL
  -- multiple by 100 because FiO2 is in a % but should be a fraction
  THEN (coalesce(FIO2, fio2_chartevents)/100) * (760 - 47) - (pco2/0.8) - po2
  ELSE
  NULL
END
  AS AADO2_calc,
  CASE
    WHEN PO2 IS NOT NULL AND coalesce(FIO2, fio2_chartevents) IS NOT NULL
  -- multiply by 100 because FiO2 is in a % but should be a fraction
  THEN 100*PO2/(coalesce(FIO2, fio2_chartevents))
  ELSE
  NULL
END
  AS PaO2FiO2
  -- acid-base parameters
  ,
  PH,
  BASEEXCESS,
  BICARBONATE,
  TOTALCO2
  -- blood count parameters
  ,
  HEMATOCRIT,
  HEMOGLOBIN,
  CARBOXYHEMOGLOBIN,
  METHEMOGLOBIN
  -- chemistry
  ,
  CHLORIDE,
  CALCIUM,
  TEMPERATURE,
  POTASSIUM,
  SODIUM,
  LACTATE,
  GLUCOSE
  -- ventilation stuff that's sometimes input
  ,
  INTUBATED,
  TIDALVOLUME,
  VENTILATIONRATE,
  VENTILATOR,
  PEEP,
  O2Flow,
  REQUIREDO2
FROM
  stg3
WHERE
  lastRowFiO2 = 1 -- only the most recent FiO2
  -- restrict it to *only* arterial samples
  AND (SPECIMEN = 'ART'
    OR SPECIMEN_PROB > 0.75)
ORDER BY
  icustay_id,
  charttime;