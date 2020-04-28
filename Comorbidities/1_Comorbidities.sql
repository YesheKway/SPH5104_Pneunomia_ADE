-- get the comorbidities for this studies based on ICD-9 codes 
WITH
  icd AS (
  SELECT
    hadm_id,
    seq_num,
    icd9_code
  FROM
    `physionet-data.mimiciii_clinical.diagnoses_icd`
  WHERE
    seq_num != 1 -- we do not include the primary icd-9 code
    ),
  eliflg AS (
  SELECT
    hadm_id,
    seq_num,
    icd9_code,
    CASE
      WHEN SUBSTR(icd9_code, 1, 3) IN ('042', '043', '044') THEN 1
    ELSE
    0
  END
    AS AIDS /* HIV and AIDS */,
    CASE
      WHEN icd9_code IN ('39891', '40201', '40211', '40291', '40401', '40403', '40411', '40413', '40491', '40493') THEN 1
      WHEN SUBSTR(icd9_code, 1, 4) IN ('4254',
      '4255',
      '4257',
      '4258',
      '4259') THEN 1
      WHEN SUBSTR(icd9_code, 1, 3) IN ('428') THEN 1
    ELSE
    0
  END
    AS CHF /* Congestive heart failure */,
    CASE
      WHEN SUBSTR(icd9_code, 1, 4) IN ('2780') THEN 1
    ELSE
    0
  END
    AS OBESE /* Obesity*/,
    CASE
      WHEN icd9_code LIKE '491%' THEN 1
      WHEN icd9_code LIKE '492%' THEN 1
      WHEN icd9_code LIKE '496%' THEN 1
    ELSE
    0
  END
    AS CHRONIC_OBSTRUCTIVE_PULMONARY_DISEASE /* CHRONIC OBSTRUCTIVE PULMONARY DISEASE */,
    CASE
      WHEN icd9_code IN ('2386', '13733') THEN 1
    --140.x-176.x
      WHEN SUBSTR(icd9_code, 1, 3) IN ( '140',
      '141',
      '142',
      '143',
      '144',
      '145',
      '146',
      '147',
      '148',
      '149',
      '150',
      '151',
      '152',
      '153',
      '154',
      '155',
      '156',
      '157',
      '158',
      '159',
      '160',
      '161',
      '162',
      '163',
      '164',
      '165',
      '166',
      '167',
      '168',
      '169',
      '170',
      '171',
      '172',
      '173',
      '174',
      '175',
      '176') THEN 1
    --179.x-199.x
      WHEN SUBSTR(icd9_code, 1, 3) IN ( '179', '180', '181', '182', '183', '184', '185', '186', '187', '188', '189', '190', '191', '192', '193', '194', '195', '196', '197', '198') THEN 1
      WHEN SUBSTR(icd9_code, 1, 3) IN ('V10') THEN 1
      WHEN icd9_code IN ('V10.71', 'V10.72', 'V10.79') THEN 1
      WHEN SUBSTR(icd9_code, 1, 3) IN ('200',
      '201',
      '202',
      '203',
      '204',
      '205',
      '206',
      '207') THEN 1
      WHEN SUBSTR(icd9_code, 1, 3) IN ('2090', '2091', '2092', '2093') THEN 1
    ELSE
    0
  END
    AS CANCER_AND_MALIGNANCY /*CANCER AND MALIGNANCY*/,
    CASE
      WHEN icd9_code IN ('07022', '07023', '07032', '07033', '07044', '07054') THEN 1
      WHEN SUBSTR(icd9_code, 1, 4) IN ('0706',
      '0709',
      '4560',
      '4561',
      '4562',
      '5722',
      '5723',
      '5724',
      '5728',
      '5733',
      '5734',
      '5738',
      '5739',
      'V427') THEN 1
      WHEN SUBSTR(icd9_code, 1, 3) IN ('570', '571') THEN 1
    ELSE
    0
  END
    AS LIVER /* Liver disease */,
    CASE
      WHEN icd9_code LIKE '332%' THEN 1
    ELSE
    0
  END
    AS PARKINSONS /*PARKINSONS*/,
    CASE
      WHEN icd9_code LIKE '209%' THEN 1
      WHEN icd9_code IN ('2941',
      '2942',
      '3310',
      '3311',
      '3312',
      '3314',
      '33182') THEN 1
    ELSE
    0
  END
    AS DEMENTIA /*DEMENTIA*/,
    CASE
    --Hypertension, uncomplicated
      WHEN SUBSTR(icd9_code, 1, 3) IN ('401') THEN 1
    -- Hypertension, complicated
      WHEN SUBSTR(icd9_code, 1, 3) IN ('402',
      '403',
      '404',
      '405') THEN 1
    ELSE
    0
  END
    AS HTN,
    CASE
      WHEN icd9_code IN ('2720', '2721', '2722', '2723', '2724') THEN 1
    ELSE
    0
  END
    AS HYPERLIPIDAEMIA /*HYPERLIPIDAEMIA */,
    CASE
      WHEN SUBSTR(icd9_code, 1, 4) IN ('4168', '4169', '5064', '5081', '5088') THEN 1
      WHEN SUBSTR(icd9_code,1, 3) IN ('490',
      '491',
      '492',
      '493',
      '494',
      '495',
      '496',
      '500',
      '501',
      '502',
      '503',
      '504',
      '505') THEN 1
    ELSE
    0
  END
    AS CHRNLUNG /* Chronic pulmonary disease */,
    CASE
      WHEN SUBSTR(icd9_code, 1, 4) IN ('2500', '2501', '2502', '2503') THEN 1
      WHEN SUBSTR(icd9_code,1, 4) IN ('2504',
      '2505',
      '2506',
      '2507',
      '2508',
      '2509') THEN 1
    ELSE
    0
  END
    AS DIABETES /* Diabetes w/o chronic complications*/,
    CASE
      WHEN icd9_code LIKE '410%' THEN 1
      WHEN icd9_code LIKE '411%' THEN 1
      WHEN icd9_code LIKE '412%' THEN 1
      WHEN icd9_code LIKE '413%' THEN 1
      WHEN icd9_code LIKE '414%' THEN 1
    ELSE
    0
  END
    AS ISCHAEMIC_HEART_DISEASE /* Ischaemic Heart Disease */,
    CASE
      WHEN SUBSTR(icd9_code,1, 3) IN ('430', '431', '436') THEN 1
      WHEN icd9_code IN ( '43301',
      '43310',
      '43311',
      '43321',
      '43331',
      '43381',
      '43391',
      '43400',
      '43401',
      '43411',
      '43491' ) THEN 1
    ELSE
    0
  END
    AS STROKE /* Stroke */,
    CASE
      WHEN icd9_code LIKE '585%' THEN 1
      WHEN icd9_code LIKE '586%' THEN 1
      WHEN icd9_code IN ('40311', '40391', '40412', '40492', 'V420', 'V451', 'V560', 'V568' ) THEN 1
    ELSE
    0
  END
    AS CHRONICAL_KIDNEY_DISEASE /* CHRONICAL_KIDNEY_DISEASE */,
    CASE
      WHEN icd9_code IN ('570', '5728', '573', '5710', '5711', '5712', '5713', '5714', '5715', '5716', '5717', '5718', '5719', '5720', '5721', '5722', '5723', '5724') THEN 1
    ELSE
    0
  END
    AS LIVER_DISEASE /* LIVER_DISEASE */,
    CASE
      WHEN SUBSTR(icd9_code, 1, 4) IN ('2652', '2911', '2912', '2913', '2915', '2918', '2919', '3030', '3039', '3050', '3575', '4255', '5353', '5710', '5711', '5712', '5713', 'V113') THEN 1
      WHEN SUBSTR(icd9_code, 1, 3) IN ('980') THEN 1
    ELSE
    0
  END
    AS ALCOHOL /* Alcohol abuse */,
    CASE
      WHEN icd9_code IN ('V6542') THEN 1
      WHEN SUBSTR(icd9_code,1, 4) IN ('3052',
      '3053',
      '3054',
      '3055',
      '3056',
      '3057',
      '3058',
      '3059') THEN 1
      WHEN SUBSTR(icd9_code, 1, 3) IN ('292', '304') THEN 1
    ELSE
    0
  END
    AS DRUG /* Drug abuse */
  FROM
    icd )
  -- collapse the icd9_code specific flags into hadm_id specific flags
  -- this groups comorbidities together for a single patient admission
  ,
  eligrp AS (
  SELECT
    hadm_id,
    MAX(liver) AS liver,
    MAX(aids) AS aids
    -- addded
    ,
    MAX(CHRONIC_OBSTRUCTIVE_PULMONARY_DISEASE) AS CHRONIC_OBSTRUCTIVE_PULMONARY_DISEASE,
    MAX(ISCHAEMIC_HEART_DISEASE) AS ISCHAEMIC_Heart_DISEASE,
    MAX(CHRONICAL_KIDNEY_DISEASE) AS CHRONICAL_KIDNEY_DISEASE,
    MAX(LIVER_DISEASE) AS LIVER_DISEASE,
    MAX(CANCER_AND_MALIGNANCY) AS CANCER_AND_MALIGNANCY,
    MAX(STROKE) AS STROKE,
    MAX(PARKINSONS) AS PARKINSONS,
    MAX(DEMENTIA) AS DEMENTIA,
    MAX(HYPERLIPIDAEMIA) AS HYPERLIPIDAEMIA,
    MAX(DIABETES) AS DIABETES,
    MAX(htn) AS HYPERTENSION,
    MAX(obese) AS obese,
    MAX(alcohol) AS alcohol,
    MAX(drug) AS drug,
    MAX(chf) AS chf,
    MAX(chrnlung) AS chrnlung
  FROM
    eliflg
  GROUP BY
    hadm_id )
  -- now merge these flags together to define elixhauser
  -- most are straightforward.. but hypertension flags are a bit more complicated
SELECT
  adm.hadm_id,
  ISCHAEMIC_HEART_DISEASE,
  chf AS CONGESTIVE_HEART_FAILURE,
  CHRONICAL_KIDNEY_DISEASE,
  chrnlung AS CHRONIC_PULMONARY_DISEASE,
  CHRONIC_OBSTRUCTIVE_PULMONARY_DISEASE,
  LIVER_DISEASE,
  CANCER_AND_MALIGNANCY,
  STROKE,
  PARKINSONS,
  DEMENTIA,
  HYPERTENSION,
  HYPERLIPIDAEMIA,
  DIABETES,
  aids AS AIDS,
  obese AS OBESITY,
  alcohol AS ALCOHOL_ABUSE,
  drug AS DRUG_ABUSE
FROM
  `physionet-data.mimiciii_clinical.admissions` adm
LEFT JOIN
  eligrp eli
ON
  adm.hadm_id = eli.hadm_id
ORDER BY
  adm.hadm_id;