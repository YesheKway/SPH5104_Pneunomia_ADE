WITH
  vd0 AS (
  SELECT
    icustay_id
    -- this carries over the previous charttime which had a mechanical ventilation event
    ,
    CASE
      WHEN MechVent=1 THEN LAG(CHARTTIME, 1) OVER (PARTITION BY icustay_id, MechVent ORDER BY charttime)
    ELSE
    NULL
  END
    AS charttime_lag,
    charttime,
    MechVent,
    OxygenTherapy,
    Extubated,
    SelfExtubated
  FROM
    `mimic-267216.CohorSelection_Pneumonia.ventSettings`),
  vd1 AS (
  SELECT
    icustay_id,
    charttime_lag,
    charttime,
    MechVent,
    OxygenTherapy,
    Extubated,
    SelfExtubated
    -- if this is a mechanical ventilation event, we calculate the time since the last event
    ,
    CASE
    -- if the current observation indicates mechanical ventilation is present
    -- calculate the time since the last vent event
      WHEN MechVent=1 THEN DATETIME_DIFF(charttime_lag, CHARTTIME, Minute)
    ELSE
    NULL
  END
    AS ventduration,
    LAG(Extubated,1) OVER (PARTITION BY icustay_id, CASE WHEN MechVent=1 OR Extubated=1 THEN 1 ELSE 0 END ORDER BY charttime ) AS ExtubatedLag
    -- now we determine if the current mech vent event is a "new", i.e. they've just been intubated
    , CASE
    -- if there is an extubation flag, we mark any subsequent ventilation as a new ventilation event
    --when Extubated = 1 then 0 -- extubation is *not* a new ventilation event, the *subsequent* row is
      WHEN LAG(Extubated,1) OVER (PARTITION BY icustay_id, CASE WHEN MechVent=1 OR Extubated=1 THEN 1 ELSE 0 END ORDER BY charttime ) = 1 THEN 1
    -- if patient has initiated oxygen therapy, and is not currently vented, start a newvent
      WHEN MechVent = 0
    AND OxygenTherapy = 1 THEN 1
    -- if there is less than 8 hours between vent settings, we do not treat this as a new ventilation event
      WHEN ROUND(DATETIME_DIFF(charttime_lag, CHARTTIME, hour),0) > 8 THEN 1
    ELSE
    0
  END
    AS newvent
    -- use the staging table with only vent settings from chart events
  FROM
    vd0 ventsettings ),
  vd2 AS (
  SELECT
    vd1.*
    -- create a cumulative sum of the instances of new ventilation
    -- this results in a monotonic integer assigned to each instance of ventilation
    ,
    CASE
      WHEN MechVent=1 OR Extubated = 1 THEN SUM( newvent ) OVER (PARTITION BY icustay_id ORDER BY charttime )
    ELSE
    NULL
  END
    AS ventnum
    --- now we convert CHARTTIME of ventilator settings into durations
  FROM
    vd1 )
  -- create the durations for each mechanical ventilation instance
SELECT
  icustay_id
  -- regenerate ventnum so it's sequential
  ,
  ROW_NUMBER() OVER (PARTITION BY icustay_id ORDER BY ventnum) AS ventnum,
  MIN(charttime) AS starttime,
  MAX(charttime) AS endtime,
  DATETIME_DIFF(MAX(charttime),
    MIN(charttime),
    hour) AS duration_hours
FROM
  vd2
GROUP BY
  icustay_id,
  vd2.ventnum
HAVING
  MIN(charttime) != MAX(charttime)
  -- patient had to be mechanically ventilated at least once
  -- i.e. max(mechvent) should be 1
  -- this excludes a frequent situation of NIV/oxygen before intub
  -- in these cases, ventnum=0 and max(mechvent)=0, so they are ignored
  AND MAX(mechvent) = 1
ORDER BY
  icustay_id
  #ventnum;