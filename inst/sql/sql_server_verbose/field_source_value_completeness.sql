SELECT DISTINCT 
            '@cdmTableName.@cdmFieldName' AS violating_field, 
            cdmTable.@cdmFieldName
        FROM @cdmDatabaseSchema.@cdmTableName cdmTable
        {@cohort & '@runForCohort' == 'Yes'}?{
            JOIN @cohortDatabaseSchema.@cohortTableName c
                ON cdmTable.PERSON_ID = c.subject_id
                AND c.cohort_definition_id = @cohortDefinitionId
        }
        WHERE cdmTable.@standardConceptFieldName = 0
;
