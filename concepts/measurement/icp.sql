WITH ce AS (
    SELECT
        ce.subject_id
        , ce.stay_id
        , ce.charttime
        -- TODO: handle high ICPs when monitoring two ICPs
        , CASE
            WHEN valuenum > 0 AND valuenum < 100 THEN valuenum ELSE null
        END AS icp
    FROM `physionet-data.mimiciv_3_1_icu.chartevents` ce
    -- exclude rows marked as error
    WHERE ce.itemid IN
        (
            220765 -- Intra Cranial Pressure -- 92306
            , 227989 -- Intra Cranial Pressure #2 -- 1052
        )
)

SELECT
    ce.subject_id
    , ce.stay_id
    , ce.charttime
    , MAX(icp) AS icp
FROM ce
GROUP BY ce.subject_id, ce.stay_id, ce.charttime
;