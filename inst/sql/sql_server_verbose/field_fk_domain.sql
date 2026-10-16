SELECT 
            '@cdmTableName.@cdmFieldName' AS violating_field, 
            cdmTable.* 
        FROM @schema.@cdmTableName cdmTable
            LEFT JOIN @vocabDatabaseSchema.concept co
            ON cdmTable.@cdmFieldName = co.concept_id
            {@cohort & '@runForCohort' == 'Yes'}?{
            JOIN @cohortDatabaseSchema.@cohortTableName c 
                ON cdmTable.person_id = c.subject_id
                AND c.cohort_definition_id = @cohortDefinitionId
        }
        WHERE co.concept_id != 0 
            AND co.domain_id NOT IN ('@fkDomain')
;
