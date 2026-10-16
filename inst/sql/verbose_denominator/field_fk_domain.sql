SELECT 
        COUNT_BIG(*) AS num_rows
    FROM @schema.@cdmTableName cdmTable
    {@cohort & '@runForCohort' == 'Yes'}?{
    JOIN @cohortDatabaseSchema.@cohortTableName c 
        ON cdmTable.PERSON_ID = c.SUBJECT_ID
        AND c.COHORT_DEFINITION_ID = @cohortDefinitionId
    }
;
