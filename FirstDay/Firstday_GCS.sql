WITH
  base AS (
  SELECT
    pvt.ICUSTAY_ID,
    pvt.charttime
    -- Easier names - note we coalesced Metavision and CareVue IDs below
    ,
    MAX(CASE
        WHEN pvt.itemid = 454 THEN pvt.valuenum
      ELSE
      NULL
    END
      ) AS GCSMotor,
    MAX(CASE
        WHEN pvt.itemid = 723 THEN pvt.valuenum
      ELSE
      NULL
    END
      ) AS GCSVerbal,
    MAX(CASE
        WHEN pvt.itemid = 184 THEN pvt.valuenum
      ELSE
      NULL
    END
      ) AS GCSEyes
    -- If verbal was set to 0 in the below select, then this is an intubated patient
    ,
    CASE
      WHEN MAX(CASE
        WHEN pvt.itemid = 723 THEN pvt.valuenum
      ELSE
      NULL
    END
      ) = 0 THEN 1
    ELSE
    0
  END
    AS EndoTrachFlag,
    ROW_NUMBER () OVER (PARTITION BY pvt.ICUSTAY_ID ORDER BY pvt.charttime ASC) AS rn
  FROM (
    SELECT
      l.ICUSTAY_ID
      -- merge the ITEMIDs so that the pivot applies to both metavision/carevue data
      ,
      CASE
        WHEN l.ITEMID IN (723, 223900) THEN 723
        WHEN l.ITEMID IN (454,
        223901) THEN 454
        WHEN l.ITEMID IN (184, 220739) THEN 184
      ELSE
      l.ITEMID
    END
      AS ITEMID
      -- convert the data into a number, reserving a value of 0 for ET/Trach
      ,
      CASE
      -- endotrach/vent is assigned a value of 0, later parsed specially
        WHEN l.ITEMID = 723 AND l.VALUE = '1.0 ET/Trach' THEN 0 -- carevue
        WHEN l.ITEMID = 223900
      AND l.VALUE = 'No Response-ETT' THEN 0 -- metavision
      ELSE
      VALUENUM
    END
      AS VALUENUM,
      l.CHARTTIME
    FROM
      `physionet-data.mimiciii_clinical.chartevents` l
      -- get intime for charttime subselection
    INNER JOIN
      `physionet-data.mimiciii_clinical.icustays` b
    ON
      l.icustay_id = b.icustay_id
      -- Isolate the desired GCS variables
    WHERE
      l.ITEMID IN (
        -- 198 -- GCS
        -- GCS components, CareVue
        184,
        454,
        723
        -- GCS components, Metavision
        ,
        223900,
        223901,
        220739 )
      -- Only get data for the first 24 hours
      AND l.charttime BETWEEN b.intime
      AND DATETIME_ADD(b.intime,
        INTERVAL 1 day)
      -- exclude rows marked as error
      AND l.error != 1 ) pvt
  GROUP BY
    pvt.ICUSTAY_ID,
    pvt.charttime ),
  gcs AS (
  SELECT
    b.*,
    b2.GCSVerbal AS GCSVerbalPrev,
    b2.GCSMotor AS GCSMotorPrev,
    b2.GCSEyes AS GCSEyesPrev
    -- Calculate GCS, factoring in special case when they are intubated and prev vals
    -- note that the coalesce are used to implement the following if:
    --  if current value exists, use it
    --  if previous value exists, use it
    --  otherwise, default to normal
    ,
    CASE
    -- replace GCS during sedation with 15
      WHEN b.GCSVerbal = 0 THEN 15
      WHEN b.GCSVerbal IS NULL
    AND b2.GCSVerbal = 0 THEN 15
    -- if previously they were intub, but they aren't now, do not use previous GCS values
      WHEN b2.GCSVerbal = 0 THEN coalesce(b.GCSMotor, 6) + coalesce(b.GCSVerbal, 5) + coalesce(b.GCSEyes, 4)
    -- otherwise, add up score normally, imputing previous value if none available at current time
    ELSE
    coalesce(b.GCSMotor,
      coalesce(b2.GCSMotor,
        6)) + coalesce(b.GCSVerbal,
      coalesce(b2.GCSVerbal,
        5)) + coalesce(b.GCSEyes,
      coalesce(b2.GCSEyes,
        4))
  END
    AS GCS
  FROM
    base b
    -- join to itself within 6 hours to get previous value
  LEFT JOIN
    base b2
  ON
    b.ICUSTAY_ID = b2.ICUSTAY_ID
    AND b.rn = b2.rn+1
    AND b2.charttime > DATETIME_SUB(b.charttime,
      INTERVAL 6 hour) ),
  gcs_final AS (
  SELECT
    gcs.*
    -- This sorts the data by GCS, so rn=1 is the the lowest GCS values to keep
    ,
    ROW_NUMBER () OVER (PARTITION BY gcs.ICUSTAY_ID ORDER BY gcs.GCS ) AS IsMinGCS
  FROM
    gcs )
SELECT
  ie.SUBJECT_ID,
  ie.HADM_ID,
  ie.ICUSTAY_ID
  -- The minimum GCS is determined by the above row partition, we only join if IsMinGCS=1
  ,
  GCS AS MinGCS,
  coalesce(GCSMotor,
    GCSMotorPrev) AS GCSMotor,
  coalesce(GCSVerbal,
    GCSVerbalPrev) AS GCSVerbal,
  coalesce(GCSEyes,
    GCSEyesPrev) AS GCSEyes,
  EndoTrachFlag AS EndoTrachFlag
  -- subselect down to the cohort of eligible patients
FROM
  `physionet-data.mimiciii_clinical.icustays` ie
LEFT JOIN
  gcs_final gs
ON
  ie.ICUSTAY_ID = gs.ICUSTAY_ID
  AND gs.IsMinGCS = 1
ORDER BY
  ie.ICUSTAY_ID;