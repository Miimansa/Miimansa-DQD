SELECT 
        COUNT_BIG(DISTINCT cdmTable.@cdmFieldName) + COUNT(DISTINCT CASE WHEN cdmTable.@cdmFieldName IS NULL THEN 1 END) AS num_rows
    FROM @cdmDatabaseSchema.@cdmTableName cdmTable
    {@cohort & '@runForCohort' == 'Yes'}?{
        JOIN @cohortDatabaseSchema.@cohortTableName c
            ON cdmTable.person_id = c.subject_id
            AND c.cohort_definition_id = @cohortDefinitionId
    }
;
