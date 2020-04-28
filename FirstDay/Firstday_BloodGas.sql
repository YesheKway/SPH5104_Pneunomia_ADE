WITH
  pvt AS ( -- begin query that extracts the data
  SELECT
    ie.subject_id,
    ie.hadm_id,
    ie.icustay_id
    -- here we assign labels to ITEMIDs
    -- this also fuses together multiple ITEMIDs containing the same data
    ,
    CASE
      WHEN itemid = 50800 THEN 'SPECIMEN'
      WHEN itemid = 50801 THEN 'AADO2'
      WHEN itemid = 50802 THEN 'BASEEXCESS'
      WHEN itemid = 50803 THEN 'BICARBONATE'
      WHEN itemid = 50804 THEN 'TOTALCO2'
      WHEN itemid = 50805 THEN 'CARBOXYHEMOGLOBIN'
      WHEN itemid = 50806 THEN 'CHLORIDE'
      WHEN itemid = 50808 THEN 'CALCIUM'
      WHEN itemid = 50809 THEN 'GLUCOSE'
      WHEN itemid = 50810 THEN 'HEMATOCRIT'
      WHEN itemid = 50811 THEN 'HEMOGLOBIN'
      WHEN itemid = 50812 THEN 'INTUBATED'
      WHEN itemid = 50813 THEN 'LACTATE'
      WHEN itemid = 50814 THEN 'METHEMOGLOBIN'
      WHEN itemid = 50815 THEN 'O2FLOW'
      WHEN itemid = 50816 THEN 'FIO2'
      WHEN itemid = 50817 THEN 'SO2' -- OXYGENSATURATION
      WHEN itemid = 50818 THEN 'PCO2'
      WHEN itemid = 50819 THEN 'PEEP'
      WHEN itemid = 50820 THEN 'PH'
      WHEN itemid = 50821 THEN 'PO2'
      WHEN itemid = 50822 THEN 'POTASSIUM'
      WHEN itemid = 50823 THEN 'REQUIREDO2'
      WHEN itemid = 50824 THEN 'SODIUM'
      WHEN itemid = 50825 THEN 'TEMPERATURE'
      WHEN itemid = 50826 THEN 'TIDALVOLUME'
      WHEN itemid = 50827 THEN 'VENTILATIONRATE'
      WHEN itemid = 50828 THEN 'VENTILATOR'
    ELSE
    NULL
  END
    AS label,
    charttime,
    value
    -- add in some sanity checks on the values
    ,
    CASE
      WHEN valuenum <= 0 AND itemid != 50802 THEN NULL -- allow negative baseexcess
      WHEN itemid = 50810
    AND valuenum > 100 THEN NULL -- hematocrit
    -- ensure FiO2 is a valid number between 21-100
    -- mistakes are rare (<100 obs out of ~100,000)
    -- there are 862 obs of valuenum == 20 - some people round down!
    -- rather than risk imputing garbage data for FiO2, we simply NULL invalid values
      WHEN itemid = 50816 AND valuenum < 20 THEN NULL
      WHEN itemid = 50816
    AND valuenum > 100 THEN NULL
      WHEN itemid = 50817 AND valuenum > 100 THEN NULL -- O2 sat
      WHEN itemid = 50815
    AND valuenum > 70 THEN NULL -- O2 flow
      WHEN itemid = 50821 AND valuenum > 800 THEN NULL -- PO2
    -- conservative upper limit
    ELSE
    valuenum
  END
    AS valuenum
  FROM
    `physionet-data.mimiciii_clinical.icustays` ie
  LEFT JOIN
    `physionet-data.mimiciii_clinical.labevents` le
  ON
    le.subject_id = ie.subject_id
    AND le.hadm_id = ie.hadm_id
    AND le.charttime BETWEEN DATETIME_SUB(ie.intime,
      INTERVAL 6 hour)
    AND DATETIME_ADD(ie.intime,
      INTERVAL 1 day)
    AND le.ITEMID IN
    -- blood gases
    ( 50800,
      50801,
      50802,
      50803,
      50804,
      50805,
      50806,
      50807,
      50808,
      50809,
      50810,
      50811,
      50812,
      50813,
      50814,
      50815,
      50816,
      50817,
      50818,
      50819,
      50820,
      50821,
      50822,
      50823,
      50824,
      50825,
      50826,
      50827,
      50828,
      51545 ) )
SELECT
  pvt.SUBJECT_ID,
  pvt.HADM_ID,
  pvt.ICUSTAY_ID,
  pvt.CHARTTIME,
  MAX(CASE
      WHEN label = 'SPECIMEN' THEN value
    ELSE
    NULL
  END
    ) AS SPECIMEN,
  MAX(CASE
      WHEN label = 'AADO2' THEN valuenum
    ELSE
    NULL
  END
    ) AS AADO2,
  MAX(CASE
      WHEN label = 'BASEEXCESS' THEN valuenum
    ELSE
    NULL
  END
    ) AS BASEEXCESS,
  MAX(CASE
      WHEN label = 'BICARBONATE' THEN valuenum
    ELSE
    NULL
  END
    ) AS BICARBONATE,
  MAX(CASE
      WHEN label = 'TOTALCO2' THEN valuenum
    ELSE
    NULL
  END
    ) AS TOTALCO2,
  MAX(CASE
      WHEN label = 'CARBOXYHEMOGLOBIN' THEN valuenum
    ELSE
    NULL
  END
    ) AS CARBOXYHEMOGLOBIN,
  MAX(CASE
      WHEN label = 'CHLORIDE' THEN valuenum
    ELSE
    NULL
  END
    ) AS CHLORIDE,
  MAX(CASE
      WHEN label = 'CALCIUM' THEN valuenum
    ELSE
    NULL
  END
    ) AS CALCIUM,
  MAX(CASE
      WHEN label = 'GLUCOSE' THEN valuenum
    ELSE
    NULL
  END
    ) AS GLUCOSE,
  MAX(CASE
      WHEN label = 'HEMATOCRIT' THEN valuenum
    ELSE
    NULL
  END
    ) AS HEMATOCRIT,
  MAX(CASE
      WHEN label = 'HEMOGLOBIN' THEN valuenum
    ELSE
    NULL
  END
    ) AS HEMOGLOBIN,
  MAX(CASE
      WHEN label = 'INTUBATED' THEN valuenum
    ELSE
    NULL
  END
    ) AS INTUBATED,
  MAX(CASE
      WHEN label = 'LACTATE' THEN valuenum
    ELSE
    NULL
  END
    ) AS LACTATE,
  MAX(CASE
      WHEN label = 'METHEMOGLOBIN' THEN valuenum
    ELSE
    NULL
  END
    ) AS METHEMOGLOBIN,
  MAX(CASE
      WHEN label = 'O2FLOW' THEN valuenum
    ELSE
    NULL
  END
    ) AS O2FLOW,
  MAX(CASE
      WHEN label = 'FIO2' THEN valuenum
    ELSE
    NULL
  END
    ) AS FIO2,
  MAX(CASE
      WHEN label = 'SO2' THEN valuenum
    ELSE
    NULL
  END
    ) AS SO2 -- OXYGENSATURATION
  ,
  MAX(CASE
      WHEN label = 'PCO2' THEN valuenum
    ELSE
    NULL
  END
    ) AS PCO2,
  MAX(CASE
      WHEN label = 'PEEP' THEN valuenum
    ELSE
    NULL
  END
    ) AS PEEP,
  MAX(CASE
      WHEN label = 'PH' THEN valuenum
    ELSE
    NULL
  END
    ) AS PH,
  MAX(CASE
      WHEN label = 'PO2' THEN valuenum
    ELSE
    NULL
  END
    ) AS PO2,
  MAX(CASE
      WHEN label = 'POTASSIUM' THEN valuenum
    ELSE
    NULL
  END
    ) AS POTASSIUM,
  MAX(CASE
      WHEN label = 'REQUIREDO2' THEN valuenum
    ELSE
    NULL
  END
    ) AS REQUIREDO2,
  MAX(CASE
      WHEN label = 'SODIUM' THEN valuenum
    ELSE
    NULL
  END
    ) AS SODIUM,
  MAX(CASE
      WHEN label = 'TEMPERATURE' THEN valuenum
    ELSE
    NULL
  END
    ) AS TEMPERATURE,
  MAX(CASE
      WHEN label = 'TIDALVOLUME' THEN valuenum
    ELSE
    NULL
  END
    ) AS TIDALVOLUME,
  MAX(CASE
      WHEN label = 'VENTILATIONRATE' THEN valuenum
    ELSE
    NULL
  END
    ) AS VENTILATIONRATE,
  MAX(CASE
      WHEN label = 'VENTILATOR' THEN valuenum
    ELSE
    NULL
  END
    ) AS VENTILATOR
FROM
  pvt
GROUP BY
  pvt.subject_id,
  pvt.hadm_id,
  pvt.icustay_id,
  pvt.CHARTTIME
ORDER BY
  pvt.subject_id,
  pvt.hadm_id,
  pvt.icustay_id,
  pvt.CHARTTIME;