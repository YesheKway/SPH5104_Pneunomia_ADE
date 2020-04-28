SELECT
  #count(distinct(f.SUBJECT_ID))
  f.SUBJECT_ID,
  f.HADM_ID,
  f.ICUSTAY_ID,
  --- admission info
  i.GENDER,
  i.AGE_ADMISSION,
  i.ETHNICITY,
  i.INSURANCE,
  i.ADMISSION_LOCATION,
  i.ADMITTIME,
  i.DISCHTIME,
  i.dod AS DOD,
  i.LOS_HOSP,
  i.mortality30 AS MORTALITY30
  --- icu info
  ,
  i.FIRST_CAREUNIT,
  i.INTIME,
  i.OUTTIME,
  i.LOS_ICU
  --- vital info
  ,
  v.SysBP_Max,
  SysBP_Mean,
  v.SysBP_Min,
  v.DiasBP_Max,
  DiasBP_Mean,
  v.DiasBP_Min,
  v.HeartRate_Max,
  HeartRate_Mean,
  v.HeartRate_Min,
  TempC_Max,
  TempC_Mean,
  TempC_Min,
  v.RespRate_Max,
  RespRate_Mean,
  v.RespRate_Min,
  v.SpO2_Max,
  SpO2_Mean,
  v.SpO2_Min,
  v.Glucose_Max,
  Glucose_Mean,
  v.Glucose_Min
  --- lab values
  ,
  l.ABSOLUTE_LYMPHOCYTE_COUNT_min,
  l.ABSOLUTE_LYMPHOCYTE_COUNT_max,
  l.ABSOLUTE_LYMPHOCYTE_COUNT_avg,
  l.LACTATE_min,
  l.LACTATE_max,
  l.LACTATE_avg,
  l.WBC_max,
  l.WBC_min,
  l.WBC_avg,
  l.CREATININE_max,
  l.CREATININE_min,
  l.CREATININE_avg,
  l.HEMOGLOBIN_max,
  l.HEMOGLOBIN_min,
  l.HEMOGLOBIN_avg,
  l.CHLORIDE_max,
  l.CHLORIDE_min,
  l.CHLORIDE_avg,
  l.BANDS_max,
  l.BANDS_min,
  l.BANDS_avg,
  l.Neutrophils_pct_max,
  l.Neutrophils_pct_min,
  l.Neutrophils_pct_avg,
  l.C_Reactive_Protein_max,
  l.C_Reactive_Protein_min,
  l.C_Reactive_Protein_avg,
  l.Urea_Nitrogen_max,
  l.Urea_Nitrogen_min,
  l.Urea_Nitrogen_avg,
  l.ALT_max,
  l.ALT_min,
  l.ALT_avg,
  l.AST_max,
  l.AST_min,
  l.AST_avg,
  l.ALP_max,
  l.ALP_min,
  l.ALP_avg,
  l.pH_max,
  l.pH_min,
  l.pH_avg,
  l.Creatinine_Serum_max,
  l.Creatinine_Serum_min,
  l.Creatinine_Serum_avg
  --- ventialtion infromation
  ,
  vs.vent AS VENT
  #, vs.OxygenTherapy
  --- comorbidities
  ,
  cb.ISCHAEMIC_HEART_DISEASE,
  cb.CONGESTIVE_HEART_FAILURE,
  cb.CHRONICAL_KIDNEY_DISEASE,
  cb.CHRONIC_PULMONARY,
  cb.LIVER_DISEASE,
  cb.CANCER_AND_MALIGNANCY,
  cb.STROKE,
  es.elixhauser_SID29,
  es.elixhauser_SID30,
  es.elixhauser_vanwalraven
FROM
  `mimic-267216.CohorSelection_Pneumonia.6_StartedOnBroad` AS f
INNER JOIN
  `mimic-267216.CohorSelection_Pneumonia.1_First_query` AS i
ON
  i.SUBJECT_ID = f.SUBJECT_ID
  AND i.HADM_ID = f.HADM_ID
  AND i.ICUSTAY_ID = f.ICUSTAY_ID
LEFT JOIN
  `mimic-267216.CohorSelection_Pneumonia.VitalsOnCultureDay` AS v
ON
  f.SUBJECT_ID = v.subject_id
  AND f.HADM_ID = v.hadm_id
  AND f.ICUSTAY_ID = v.icustay_id
INNER JOIN
  `mimic-267216.CohorSelection_Pneumonia.LabOnCultureDay` AS l
ON
  f.SUBJECT_ID = l.subject_id
  AND f.HADM_ID = l.hadm_id
  AND f.ICUSTAY_ID = l.icustay_id
INNER JOIN
  `mimic-267216.base_data.myComorbidities` AS cb
ON
  f.HADM_ID = cb.hadm_id
INNER JOIN
  `mimic-267216.base_data.Ventfirstday` AS vs
ON
  f.ICUSTAY_ID = vs.icustay_id
INNER JOIN
  `mimic-267216.Generals.elixhauser_score` AS es
ON
  f.HADM_ID = es.hadm_id
ORDER BY
  SUBJECT_ID,
  hadm_id