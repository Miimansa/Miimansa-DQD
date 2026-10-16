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
      	    WHERE cast(cdmTable.@cdmFieldName as date) > cast(@plausibleValueHigh as date)
    	}:{
      	    WHERE cdmTable.@cdmFieldName > @plausibleValueHigh
		}
;
