SELECT 
            '@cdmTableName.@cdmFieldName' AS violating_field, 
            cdmTable.*
        FROM @schema.@cdmTableName cdmTable
            {@cohort & '@runForCohort' == 'Yes'}?{
                JOIN @cohortDatabaseSchema.@cohortTableName c 
                    ON cdmTable.person_id = c.subject_id
                    AND c.COHORT_DEFINITION_ID = @cohortDefinitionId
            }
        JOIN @cdmDatabaseSchema.death de 
            ON cdmTable.person_id = de.person_id
        WHERE CAST(cdmTable.@cdmFieldName AS DATE) > DATEADD(day, 60, CAST(de.death_date AS DATE))
;
