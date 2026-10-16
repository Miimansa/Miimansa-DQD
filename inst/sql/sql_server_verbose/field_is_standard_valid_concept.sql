SELECT 
			'@cdmTableName.@cdmFieldName' AS violating_field, 
			cdmTable.* 
		FROM @schema.@cdmTableName cdmTable
			{@cohort & '@runForCohort' == 'Yes'}?{
  			JOIN @cohortDatabaseSchema.@cohortTableName c 
  			    ON cdmTable.person_id = c.subject_id
  			    AND c.cohort_definition_id = @cohortDefinitionId
    	}
	  	JOIN @vocabDatabaseSchema.concept co 
	  	    ON cdmTable.@cdmFieldName = co.concept_id
		WHERE co.concept_id != 0 
			AND (
				co.standard_concept != 'S' 
				OR co.invalid_reason IS NOT NULL
				OR co.standard_concept IS NULL
			)
;
