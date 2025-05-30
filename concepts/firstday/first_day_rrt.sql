-- flag indicating if patients received dialysis during 
-- the first day of their ICU stay
SELECT
    ie.subject_id
    , ie.stay_id
    , MAX(dialysis_present) AS dialysis_present
    , MAX(dialysis_active) AS dialysis_active
    , STRING_AGG(DISTINCT dialysis_type, ', ') AS dialysis_type
FROM `physionet-data.mimiciv_3_1_icu.icustays` ie
LEFT JOIN `mymimiciv.mimiciv_3_1_derived.rrt` rrt
    ON ie.stay_id = rrt.stay_id
        AND rrt.charttime >= DATETIME_SUB(ie.intime, INTERVAL '6' HOUR)
        AND rrt.charttime <= DATETIME_ADD(ie.intime, INTERVAL '1' DAY)
GROUP BY ie.subject_id, ie.stay_id
