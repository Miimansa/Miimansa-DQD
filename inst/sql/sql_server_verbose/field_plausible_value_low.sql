SELECT 
            '@cdmTableName.@cdmFieldName' AS violating_field, 
            cdmTable.*
        FROM @schema.@cdmTableName cdmTable
        {@cohort & '@runForCohort' == 'Yes'}?{
            JOIN @cohortDatabaseSchema.@cohortTableName c
                ON cdmTable.person_id = c.subject_id
                AND c.cohort_definition_id = @cohortDefinitionId
        }
        {@cdmDatatype == "datetime" | @cdmDatatype == "date"}?{
            WHERE CAST(cdmTable.@cdmFieldName AS DATE) < CAST(@plausibleValueLow AS DATE)
        }:{
            WHERE cdmTable.@cdmFieldName < @plausibleValueLow
        }
;
