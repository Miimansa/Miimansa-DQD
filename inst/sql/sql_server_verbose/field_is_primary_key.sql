SELECT 
            '@cdmTableName.@cdmFieldName' AS violating_field, 
            cdmTable.* 
        FROM @schema.@cdmTableName cdmTable
            {@cohort & '@runForCohort' == 'Yes'}?{
                JOIN @cohortDatabaseSchema.@cohortTableName c 
                    ON cdmTable.person_id = c.subject_id
                    AND c.cohort_definition_id = @cohortDefinitionId
            }
        WHERE cdmTable.@cdmFieldName IN ( 
            SELECT 
                @cdmFieldName 
            FROM @schema.@cdmTableName
            GROUP BY @cdmFieldName
            HAVING COUNT_BIG(*) > 1 
        )
;
