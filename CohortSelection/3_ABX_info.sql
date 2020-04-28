  # select all patinets that go ABX prescribed during their entire stay
WITH
  before AS (
  SELECT
    co.SUBJECT_ID,
    co.HADM_ID,
    co.ICUSTAY_ID,
    co.SPEC_TYPE_DESC,
    co.ORG_NAME,
    co.Classified,
    m.CHARTDATE,
    m.CHARTTIME
    -- prescription (drug) info
    ,
    p.DRUG,
    p.DOSE_VAL_RX,
    p.DOSE_UNIT_RX,
    p.STARTDATE,
    p.ENDDATE
    ---  ABX classification
    ,
    CASE
      WHEN p.DRUG IN ( 'Amikacin', 'Amoxicillin', 'Amoxicillin-Clavulanic Acid', 'Ampicillin', 'Ampicillin-Sulbactam', 'Aztreonam', 'Cefepime', 'Cefpodoxime Proxetil', 'Ceftazidime', 'Ceftriaxone', 'Ciprofloxacin', 'Daptomycin', 'Doxycycline', 'Doxycycline', 'Ertapenem', 'Erythromycin', 'Gentamicin', 'Imipenem-Cilastatin', 'Levofloxacin', 'Meropenem', 'Moxifloxacin', 'Piperacillin-Tazobactam', 'SulfADIAzine', 'Tigecycline', '*NF* Ertapenem Sodium', 'Ampicillin Sodium', 'CefePIME', 'CeftazIDIME', 'CefTAZidime', 'CeftazIDIME ', 'CeftriaXONE', 'CefTRIAXone', 'Ciprofloxacin HCl', 'Ciprofloxacin IV', 'Linezolid', 'Metronidazole', 'MetRONIDAZOLE (FLagyl)', 'Piperacillin-Tazobactam Na', 'Azithromycin', 'Azithromycin' ) THEN 'Broad'
      WHEN p.Drug IN ( 'Cefazolin',
      'Cephalexin',
      'Clarithromycin',
      'Clindamycin',
      'Oxacillin',
      'Penicillin G Potassium',
      'Penicillin V Potassium',
      'Sulfamethoxazole-Trimethoprim',
      'Tobramycin Sulfate',
      'Vancomycin',
      'Sulfameth/Trimethoprim',
      'Sulfameth/Trimethoprim DS',
      'Sulfameth/Trimethoprim SS',
      'Vancomycin HCl',
      'Vancomycin Oral Liquid' ) THEN 'Narrow'
    ELSE
    'None'
  END
    AS AbxClass
  FROM
    `mimic-267216.CohorSelection_Pneumonia.3_SelectCultureNegative` AS co
  INNER JOIN
    `physionet-data.mimiciii_clinical.microbiologyevents` AS m
  ON
    co.Subject_id = m.SUBJECT_ID
    AND co.HADM_ID = m.HADM_ID
  INNER JOIN
    `physionet-data.mimiciii_clinical.prescriptions` AS p
  ON
    co.SUBJECT_ID = p.SUBJECT_ID
    AND co.HADM_ID = p.HADM_ID
    AND co.ICUSTAY_ID = p.ICUSTAY_ID )
SELECT
  #count(distinct(SUBJECT_ID))
  co.SUBJECT_ID,
  co.HADM_ID,
  co.ICUSTAY_ID
  #, co.SPEC_TYPE_DESC, co.ORG_NAME
  #, co.CHARTDATE, co.CHARTTIME
  ,
  co.DRUG,
  co.AbxClass,
  co.DOSE_VAL_RX,
  co.DOSE_UNIT_RX,
  co.STARTDATE,
  co.ENDDATE
FROM
  before AS co
  #where co.Classified = 'Negative'
WHERE
  AbxClass != 'None'
  #and co.STARTDATE < co.CHARTDATE
GROUP BY
  co.SUBJECT_ID,
  co.HADM_ID,
  co.ICUSTAY_ID
  #, co.SPEC_TYPE_DESC, co.ORG_NAME
  #, co.CHARTDATE, co.CHARTTIME
  ,
  co.DRUG,
  co.AbxClass,
  co.DOSE_VAL_RX,
  co.DOSE_UNIT_RX,
  co.STARTDATE,
  co.ENDDATE