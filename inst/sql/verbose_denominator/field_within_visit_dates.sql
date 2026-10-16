SELECT 
        COUNT_BIG(*) AS num_rows
    FROM @cdmDatabaseSchema.@cdmTableName cdmTable
    {@cohort & '@runForCohort' == 'Yes'}?{
        JOIN @cohortDatabaseSchema.@cohortTableName c
            ON cdmTable.person_id = c.subject_id
            AND c.cohort_definition_id = @cohortDefinitionId
    }
    JOIN @cdmDatabaseSchema.visit_occurrence vo
        ON cdmTable.visit_occurrence_id = vo.visit_occurrence_id
;
