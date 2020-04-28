  # this query gets ventilaton flag for blood culture day +- 1 days
SELECT
  ie.subject_id,
  ie.hadm_id,
  ie.icustay_id
  -- if vd.icustay_id is not null, then they have a valid ventilation event
  -- in this case, we say they are ventilated
  -- otherwise, they are not
  ,
  MAX(CASE
      WHEN vd.icustay_id IS NOT NULL THEN 1
    ELSE
    0
  END
    ) AS vent
FROM
  `mimic-267216.CohorSelection_Pneumonia.6_StartedOnBroad` ie
LEFT JOIN
  `mimic-267216.CohorSelection_Pneumonia.ventDurations` vd
ON
  ie.icustay_id = vd.icustay_id
  AND (
    -- ventilation duration overlaps with ICU admission -> vented on admission
    (vd.starttime <= Datetime_sub(ie.Chartdate,
        INTERVAL 1 day)
      AND vd.endtime >= Datetime_add(ie.Chartdate,
        INTERVAL 1 day))
    -- ventilation started during +- one day of blood culture drw
    OR (vd.starttime >= Datetime_sub(ie.Chartdate,
        INTERVAL 1 day)
      AND vd.starttime <= DATETIME_ADD(ie.Chartdate,
        INTERVAL 1 day)) )
GROUP BY
  ie.subject_id,
  ie.hadm_id,
  ie.icustay_id
ORDER BY
  ie.subject_id,
  ie.hadm_id,
  ie.icustay_id;