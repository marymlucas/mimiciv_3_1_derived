-- ------------------------------------------------------------------
-- Title: Sequential Organ Failure Assessment (SOFA)
-- This query extracts the sequential organ failure assessment
-- (formerly: sepsis-related organ failure assessment).
-- This score is a measure of organ failure for patients in the ICU.
-- The score is calculated on the first day of each ICU patients' stay.
-- ------------------------------------------------------------------

-- Reference for SOFA:
--    Jean-Louis Vincent, Rui Moreno, Jukka Takala, Sheila Willatts,
--    Arnaldo De Mendonça, Hajo Bruining, C. K. Reinhart, Peter M Suter,
--    and L. G. Thijs.
--    "The SOFA (Sepsis-related Organ Failure Assessment) score to describe
--     organ dysfunction/failure."
--    Intensive care medicine 22, no. 7 (1996): 707-710.

-- Variables used in SOFA:
--  GCS, MAP, FiO2, Ventilation status (sourced from CHARTEVENTS)
--  Creatinine, Bilirubin, FiO2, PaO2, Platelets (sourced from LABEVENTS)
--  Dopamine, Dobutamine, Epinephrine, Norepinephrine (sourced from INPUTEVENTS)
--  Urine output (sourced from OUTPUTEVENTS)

-- The following views required to run this query:
--  1) first_day_urine_output
--  2) first_day_vitalsign
--  3) first_day_gcs
--  4) first_day_lab
--  5) first_day_bg_art
--  6) ventdurations

-- extract drug rates from derived vasopressor tables
WITH vaso_stg AS (
    SELECT ie.stay_id, 'norepinephrine' AS treatment, vaso_rate AS rate
    FROM `physionet-data.mimiciv_3_1_icu.icustays` ie
    INNER JOIN `mymimiciv.mimiciv_3_1_derived.norepinephrine` mv
        ON ie.stay_id = mv.stay_id
            AND mv.starttime >= DATETIME_SUB(ie.intime, INTERVAL '6' HOUR)
            AND mv.starttime <= DATETIME_ADD(ie.intime, INTERVAL '1' DAY)
    UNION ALL
    SELECT ie.stay_id, 'epinephrine' AS treatment, vaso_rate AS rate
    FROM `physionet-data.mimiciv_3_1_icu.icustays` ie
    INNER JOIN `mymimiciv.mimiciv_3_1_derived.epinephrine` mv
        ON ie.stay_id = mv.stay_id
            AND mv.starttime >= DATETIME_SUB(ie.intime, INTERVAL '6' HOUR)
            AND mv.starttime <= DATETIME_ADD(ie.intime, INTERVAL '1' DAY)
    UNION ALL
    SELECT ie.stay_id, 'dobutamine' AS treatment, vaso_rate AS rate
    FROM `physionet-data.mimiciv_3_1_icu.icustays` ie
    INNER JOIN `mymimiciv.mimiciv_3_1_derived.dobutamine` mv
        ON ie.stay_id = mv.stay_id
            AND mv.starttime >= DATETIME_SUB(ie.intime, INTERVAL '6' HOUR)
            AND mv.starttime <= DATETIME_ADD(ie.intime, INTERVAL '1' DAY)
    UNION ALL
    SELECT ie.stay_id, 'dopamine' AS treatment, vaso_rate AS rate
    FROM `physionet-data.mimiciv_3_1_icu.icustays` ie
    INNER JOIN `mymimiciv.mimiciv_3_1_derived.dopamine` mv
        ON ie.stay_id = mv.stay_id
            AND mv.starttime >= DATETIME_SUB(ie.intime, INTERVAL '6' HOUR)
            AND mv.starttime <= DATETIME_ADD(ie.intime, INTERVAL '1' DAY)
)

, vaso_mv AS (
    SELECT
        ie.stay_id
        , MAX(
            CASE WHEN treatment = 'norepinephrine' THEN rate ELSE NULL END
        ) AS rate_norepinephrine
        , MAX(
            CASE WHEN treatment = 'epinephrine' THEN rate ELSE NULL END
        ) AS rate_epinephrine
        , MAX(
            CASE WHEN treatment = 'dopamine' THEN rate ELSE NULL END
        ) AS rate_dopamine
        , MAX(
            CASE WHEN treatment = 'dobutamine' THEN rate ELSE NULL END
        ) AS rate_dobutamine
    FROM `physionet-data.mimiciv_3_1_icu.icustays` ie
    LEFT JOIN vaso_stg v
        ON ie.stay_id = v.stay_id
    GROUP BY ie.stay_id
)

, pafi1 AS (
    -- join blood gas to ventilation durations to determine if patient was vent
    SELECT ie.stay_id, bg.charttime
        , bg.pao2fio2ratio
        , CASE WHEN vd.stay_id IS NOT NULL THEN 1 ELSE 0 END AS isvent
    FROM `physionet-data.mimiciv_3_1_icu.icustays` ie
    LEFT JOIN `mymimiciv.mimiciv_3_1_derived.bg` bg
        ON ie.subject_id = bg.subject_id
            AND bg.charttime >= DATETIME_SUB(ie.intime, INTERVAL '6' HOUR)
            AND bg.charttime <= DATETIME_ADD(ie.intime, INTERVAL '1' DAY)
    LEFT JOIN `mymimiciv.mimiciv_3_1_derived.ventilation` vd
        ON ie.stay_id = vd.stay_id
            AND bg.charttime >= vd.starttime
            AND bg.charttime <= vd.endtime
            AND vd.ventilation_status = 'InvasiveVent'
)

, pafi2 AS (
    -- because pafi has an interaction between vent/PaO2:FiO2,
    -- we need two columns for the score
    -- it can happen that the lowest unventilated PaO2/FiO2 is 68, 
    -- but the lowest ventilated PaO2/FiO2 is 120
    -- in this case, the SOFA score is 3, *not* 4.
    SELECT stay_id
        , MIN(
            CASE WHEN isvent = 0 THEN pao2fio2ratio ELSE NULL END
        ) AS pao2fio2_novent_min
        , MIN(
            CASE WHEN isvent = 1 THEN pao2fio2ratio ELSE NULL END
        ) AS pao2fio2_vent_min
    FROM pafi1
    GROUP BY stay_id
)

-- Aggregate the components for the score
, scorecomp AS (
    SELECT ie.stay_id
        , v.mbp_min
        , mv.rate_norepinephrine
        , mv.rate_epinephrine
        , mv.rate_dopamine
        , mv.rate_dobutamine

        , l.creatinine_max
        , l.bilirubin_total_max AS bilirubin_max
        , l.platelets_min AS platelet_min

        , pf.pao2fio2_novent_min
        , pf.pao2fio2_vent_min

        , uo.urineoutput

        , gcs.gcs_min
    FROM `physionet-data.mimiciv_3_1_icu.icustays` ie
    LEFT JOIN vaso_mv mv
        ON ie.stay_id = mv.stay_id
    LEFT JOIN pafi2 pf
        ON ie.stay_id = pf.stay_id
    LEFT JOIN `mymimiciv.mimiciv_3_1_derived.first_day_vitalsign` v
        ON ie.stay_id = v.stay_id
    LEFT JOIN `mymimiciv.mimiciv_3_1_derived.first_day_lab` l
        ON ie.stay_id = l.stay_id
    LEFT JOIN `mymimiciv.mimiciv_3_1_derived.first_day_urine_output` uo
        ON ie.stay_id = uo.stay_id
    LEFT JOIN `mymimiciv.mimiciv_3_1_derived.first_day_gcs` gcs
        ON ie.stay_id = gcs.stay_id
)

, scorecalc AS (
    -- Calculate the final score
    -- note that if the underlying data is missing, the component is null
    -- eventually these are treated as 0 (normal), but knowing when data
    -- is missing is useful for debugging
    SELECT stay_id
        -- Respiration
        , CASE
            WHEN pao2fio2_vent_min < 100 THEN 4
            WHEN pao2fio2_vent_min < 200 THEN 3
            WHEN pao2fio2_novent_min < 300 THEN 2
            WHEN pao2fio2_novent_min < 400 THEN 1
            WHEN
                COALESCE(
                    pao2fio2_vent_min, pao2fio2_novent_min
                ) IS NULL THEN NULL
            ELSE 0
        END AS respiration

        -- Coagulation
        , CASE
            WHEN platelet_min < 20 THEN 4
            WHEN platelet_min < 50 THEN 3
            WHEN platelet_min < 100 THEN 2
            WHEN platelet_min < 150 THEN 1
            WHEN platelet_min IS NULL THEN NULL
            ELSE 0
        END AS coagulation

        -- Liver
        , CASE
            -- Bilirubin checks in mg/dL
            WHEN bilirubin_max >= 12.0 THEN 4
            WHEN bilirubin_max >= 6.0 THEN 3
            WHEN bilirubin_max >= 2.0 THEN 2
            WHEN bilirubin_max >= 1.2 THEN 1
            WHEN bilirubin_max IS NULL THEN NULL
            ELSE 0
        END AS liver

        -- Cardiovascular
        , CASE
            WHEN rate_dopamine > 15
                OR rate_epinephrine > 0.1
                OR rate_norepinephrine > 0.1
                THEN 4
            WHEN rate_dopamine > 5
                OR rate_epinephrine <= 0.1
                OR rate_norepinephrine <= 0.1
                THEN 3
            WHEN rate_dopamine > 0 OR rate_dobutamine > 0 THEN 2
            WHEN mbp_min < 70 THEN 1
            WHEN
                COALESCE(
                    mbp_min
                    , rate_dopamine
                    , rate_dobutamine
                    , rate_epinephrine
                    , rate_norepinephrine
                ) IS NULL THEN NULL
            ELSE 0
        END AS cardiovascular

        -- Neurological failure (GCS)
        , CASE
            WHEN (gcs_min >= 13 AND gcs_min <= 14) THEN 1
            WHEN (gcs_min >= 10 AND gcs_min <= 12) THEN 2
            WHEN (gcs_min >= 6 AND gcs_min <= 9) THEN 3
            WHEN gcs_min < 6 THEN 4
            WHEN gcs_min IS NULL THEN NULL
            ELSE 0 END
        AS cns

        -- Renal failure - high creatinine or low urine output
        , CASE
            WHEN (creatinine_max >= 5.0) THEN 4
            WHEN urineoutput < 200 THEN 4
            WHEN (creatinine_max >= 3.5 AND creatinine_max < 5.0) THEN 3
            WHEN urineoutput < 500 THEN 3
            WHEN (creatinine_max >= 2.0 AND creatinine_max < 3.5) THEN 2
            WHEN (creatinine_max >= 1.2 AND creatinine_max < 2.0) THEN 1
            WHEN COALESCE(urineoutput, creatinine_max) IS NULL THEN NULL
            ELSE 0 END
        AS renal
    FROM scorecomp
)

SELECT ie.subject_id, ie.hadm_id, ie.stay_id
  -- Combine all the scores to get SOFA
  -- Impute 0 if the score is missing
       , COALESCE(respiration, 0)
       + COALESCE(coagulation, 0)
       + COALESCE(liver, 0)
       + COALESCE(cardiovascular, 0)
       + COALESCE(cns, 0)
       + COALESCE(renal, 0)
       AS sofa
    , respiration
    , coagulation
    , liver
    , cardiovascular
    , cns
    , renal
FROM `physionet-data.mimiciv_3_1_icu.icustays` ie
LEFT JOIN scorecalc s
          ON ie.stay_id = s.stay_id
;
