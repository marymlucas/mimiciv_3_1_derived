WITH acei_drug AS (
    SELECT DISTINCT
        drug
        , CASE
            WHEN UPPER(drug) LIKE '%BENAZEPRIL%' THEN 1
            WHEN UPPER(drug) LIKE '%CAPTOPRIL%' THEN 1
            WHEN UPPER(drug) LIKE '%ENALAPRIL%' THEN 1
            WHEN UPPER(drug) LIKE '%FOSINOPRIL%' THEN 1
            WHEN UPPER(drug) LIKE '%LISINOPRIL%' THEN 1
            WHEN UPPER(drug) LIKE '%MOEXIPRIL%' THEN 1
            WHEN UPPER(drug) LIKE '%PERINDOPRIL%' THEN 1
            WHEN UPPER(drug) LIKE '%QUINAPRIL%' THEN 1
            WHEN UPPER(drug) LIKE '%RAMIPRIL%' THEN 1
            WHEN UPPER(drug) LIKE '%TRANDOLAPRIL%' THEN 1
            ELSE 0
        END AS acei
    FROM `physionet-data.mimiciv_3_1_hosp.prescriptions`
)

SELECT
    pr.subject_id
    , pr.hadm_id
    , pr.drug AS acei
    , pr.starttime
    , pr.stoptime
FROM
    `physionet-data.mimiciv_3_1_hosp.prescriptions` pr
INNER JOIN acei_drug
    ON
        pr.drug = acei_drug.drug
WHERE
    acei_drug.acei = 1
;