SELECT 
            '@cdmTableName.@cdmFieldName' AS violating_field, 
            cdmTable.*
        FROM @schema.@cdmTableName cdmTable
        {@cohort & '@runForCohort' == 'Yes'} ? {
        JOIN @cohortDatabaseSchema.@cohortTableName c 
            ON cdmTable.person_id = c.subject_id
            AND c.COHORT_DEFINITION_ID = @cohortDefinitionId
        }
        JOIN @cdmDatabaseSchema.person p 
            ON cdmTable.person_id = p.person_id
        WHERE cdmTable.@cdmFieldName IS NOT NULL AND 
            CAST(cdmTable.@cdmFieldName AS DATE) < COALESCE(
                CAST(p.birth_datetime AS DATE), 
                CAST(CONCAT(
                    p.year_of_birth,
                    COALESCE(
                        RIGHT('0' + CAST(p.month_of_birth AS VARCHAR), 2),
                        '01'
                    ),
                    COALESCE(
                        RIGHT('0' + CAST(p.day_of_birth AS VARCHAR), 2),
                        '01'
                    )
                ) AS DATE)
            )
;
