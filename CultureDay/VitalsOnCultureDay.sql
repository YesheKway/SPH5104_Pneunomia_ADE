SELECT
  pvt.subject_id,
  pvt.hadm_id,
  pvt.icustay_id
  -- Easier names
  ,
  ROUND(MIN(CASE
        WHEN VitalID = 1 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS HeartRate_Min,
  ROUND(MAX(CASE
        WHEN VitalID = 1 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS HeartRate_Max,
  ROUND(AVG(CASE
        WHEN VitalID = 1 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS HeartRate_Mean,
  ROUND(MIN(CASE
        WHEN VitalID = 2 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS SysBP_Min,
  ROUND(MAX(CASE
        WHEN VitalID = 2 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS SysBP_Max,
  ROUND(AVG(CASE
        WHEN VitalID = 2 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS SysBP_Mean,
  ROUND(MIN(CASE
        WHEN VitalID = 3 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS DiasBP_Min,
  ROUND(MAX(CASE
        WHEN VitalID = 3 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS DiasBP_Max,
  ROUND( AVG(CASE
        WHEN VitalID = 3 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS DiasBP_Mean,
  ROUND(MIN(CASE
        WHEN VitalID = 4 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS MeanBP_Min,
  ROUND(MAX(CASE
        WHEN VitalID = 4 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS MeanBP_Max,
  ROUND(AVG(CASE
        WHEN VitalID = 4 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS MeanBP_Mean,
  ROUND(MIN(CASE
        WHEN VitalID = 5 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS RespRate_Min,
  ROUND(MAX(CASE
        WHEN VitalID = 5 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS RespRate_Max,
  ROUND( AVG(CASE
        WHEN VitalID = 5 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS RespRate_Mean,
  ROUND(MIN(CASE
        WHEN VitalID = 6 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS TempC_Min,
  ROUND(MAX(CASE
        WHEN VitalID = 6 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS TempC_Max,
  ROUND(AVG(CASE
        WHEN VitalID = 6 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS TempC_Mean,
  ROUND(MIN(CASE
        WHEN VitalID = 7 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS SpO2_Min,
  ROUND(MAX(CASE
        WHEN VitalID = 7 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS SpO2_Max,
  ROUND(AVG(CASE
        WHEN VitalID = 7 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS SpO2_Mean,
  ROUND(MIN(CASE
        WHEN VitalID = 8 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS Glucose_Min,
  ROUND(MAX(CASE
        WHEN VitalID = 8 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS Glucose_Max,
  ROUND(AVG(CASE
        WHEN VitalID = 8 THEN valuenum
      ELSE
      NULL
    END
      ), 1) AS Glucose_Mean
FROM (
  SELECT
    ie.subject_id,
    ie.hadm_id,
    ie.icustay_id,
    CASE
      WHEN itemid IN (211, 220045) AND valuenum > 0 AND valuenum < 300 THEN 1 -- HeartRate
      WHEN itemid IN (51,
      442,
      455,
      6701,
      220179,
      220050)
    AND valuenum > 0
    AND valuenum < 400 THEN 2 -- SysBP
      WHEN itemid IN (8368, 8440, 8441, 8555, 220180, 220051) AND valuenum > 0 AND valuenum < 300 THEN 3 -- DiasBP
      WHEN itemid IN (456,
      52,
      6702,
      443,
      220052,
      220181,
      225312)
    AND valuenum > 0
    AND valuenum < 300 THEN 4 -- MeanBP
      WHEN itemid IN (615, 618, 220210, 224690) AND valuenum > 0 AND valuenum < 70 THEN 5 -- RespRate
      WHEN itemid IN (223761,
      678)
    AND valuenum > 70
    AND valuenum < 120 THEN 6 -- TempF, converted to degC in valuenum call
      WHEN itemid IN (223762, 676) AND valuenum > 10 AND valuenum < 50 THEN 6 -- TempC
      WHEN itemid IN (646,
      220277)
    AND valuenum > 0
    AND valuenum <= 100 THEN 7 -- SpO2
      WHEN itemid IN (807, 811, 1529, 3745, 3744, 225664, 220621, 226537) AND valuenum > 0 THEN 8 -- Glucose
    ELSE
    NULL
  END
    AS VitalID
    -- convert F to C
    ,
    CASE
      WHEN itemid IN (223761, 678) THEN (valuenum-32)/1.8
    ELSE
    valuenum
  END
    AS valuenum
  FROM
    `mimic-267216.CohorSelection_Pneumonia.6_StartedOnBroad` ie
  LEFT JOIN
    `physionet-data.mimiciii_clinical.chartevents` ce
  ON
    ie.subject_id = ce.subject_id
    AND ie.hadm_id = ce.hadm_id
    AND ie.icustay_id = ce.icustay_id
    AND ce.charttime BETWEEN DATETIME_SUB(ie.Chartdate,
      INTERVAL 1 day)
    AND DATETIME_ADD(ie.Chartdate,
      INTERVAL 1 DAY)
    -- exclude rows marked as error
    #(ce.error is null or ce.error = 0)
  WHERE
    ce.error IS NULL
    OR ce.error = 0
    AND ce.itemid IN (
      -- HEART RATE
      211,
      --"Heart Rate"
      220045,
      --"Heart Rate"
      -- Systolic/diastolic
      51,
      --	Arterial BP [Systolic]
      442,
      --	Manual BP [Systolic]
      455,
      --	NBP [Systolic]
      6701,
      --	Arterial BP #2 [Systolic]
      220179,
      --	Non Invasive Blood Pressure systolic
      220050,
      --	Arterial Blood Pressure systolic
      8368,
      --	Arterial BP [Diastolic]
      8440,
      --	Manual BP [Diastolic]
      8441,
      --	NBP [Diastolic]
      8555,
      --	Arterial BP #2 [Diastolic]
      220180,
      --	Non Invasive Blood Pressure diastolic
      220051,
      --	Arterial Blood Pressure diastolic
      -- MEAN ARTERIAL PRESSURE
      456,
      --"NBP Mean"
      52,
      --"Arterial BP Mean"
      6702,
      --	Arterial BP Mean #2
      443,
      --	Manual BP Mean(calc)
      220052,
      --"Arterial Blood Pressure mean"
      220181,
      --"Non Invasive Blood Pressure mean"
      225312,
      --"ART BP mean"
      -- RESPIRATORY RATE
      618,
      --	Respiratory Rate
      615,
      --	Resp Rate (Total)
      220210,
      --	Respiratory Rate
      224690,
      --	Respiratory Rate (Total)
      -- SPO2, peripheral
      646,
      220277,
      -- GLUCOSE, both lab and fingerstick
      807,
      --	Fingerstick Glucose
      811,
      --	Glucose (70-105)
      1529,
      --	Glucose
      3745,
      --	BloodGlucose
      3744,
      --	Blood Glucose
      225664,
      --	Glucose finger stick
      220621,
      --	Glucose (serum)
      226537,
      --	Glucose (whole blood)
      -- TEMPERATURE
      223762,
      -- "Temperature Celsius"
      676,
      -- "Temperature C"
      223761,
      -- "Temperature Fahrenheit"
      678 --	"Temperature F"
      ) ) pvt
GROUP BY
  pvt.subject_id,
  pvt.hadm_id,
  pvt.icustay_id
ORDER BY
  pvt.subject_id,
  pvt.hadm_id,
  pvt.icustay_id;