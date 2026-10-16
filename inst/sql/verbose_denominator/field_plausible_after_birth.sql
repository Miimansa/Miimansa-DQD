SELECT 
        COUNT_BIG(*) AS num_rows
    FROM @schema.@cdmTableName cdmTable
    {@cohort & '@runForCohort' == 'Yes'} ? {
    JOIN @cohortDatabaseSchema.@cohortTableName c 
        ON cdmTable.person_id = c.subject_id
        AND c.cohort_definition_id = @cohortDefinitionId
    }
    WHERE cdmTable.@cdmFieldName IS NOT NULL
;
