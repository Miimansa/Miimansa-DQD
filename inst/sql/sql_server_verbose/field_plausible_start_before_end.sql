SELECT 
            '@cdmTableName.@cdmFieldName' AS violating_field, 
            cdmTable.*
        FROM @schema.@cdmTableName cdmTable
        {@cohort & '@runForCohort' == 'Yes'} ? {
        JOIN @cohortDatabaseSchema.@cohortTableName c 
            ON cdmTable.person_id = c.subject_id
            AND c.cohort_definition_id = @cohortDefinitionId
        }
        WHERE cdmTable.@cdmFieldName IS NOT NULL 
            AND cdmTable.@plausibleStartBeforeEndFieldName IS NOT NULL 
            AND CAST(cdmTable.@cdmFieldName AS DATE) > CAST(cdmTable.@plausibleStartBeforeEndFieldName AS DATE)
;
