SELECT 
            '@cdmTableName.@cdmFieldName' AS violating_field, 
            cdmTable.*
        FROM @schema.@cdmTableName cdmTable
            {@cohort & '@runForCohort' == 'Yes'}?{
                JOIN @cohortDatabaseSchema.@cohortTableName c
                    ON cdmTable.person_id = c.subject_id
                    AND c.cohort_definition_id = @cohortDefinitionId
            }
            LEFT JOIN 
                {'@fkTableName' IN ('CONCEPT','DOMAIN','CONCEPT_CLASS','VOCABULARY','RELATIONSHIP')}?{@vocabDatabaseSchema.@fkTableName fkTable}
                {'@fkTableName' == 'COHORT'}?{@cohortDatabaseSchema.@fkTableName fkTable}
                {'@fkTableName' IN ('LOCATION','PERSON','PROVIDER','VISIT_DETAIL','VISIT_OCCURRENCE','PAYER_PLAN_PERIOD','NOTE','CARE_SITE','EPISODE')}?{@cdmDatabaseSchema.@fkTableName fkTable} 
                ON cdmTable.@cdmFieldName = fkTable.@fkFieldName
        WHERE fkTable.@fkFieldName IS NULL 
            AND cdmTable.@cdmFieldName IS NOT NULL
;
