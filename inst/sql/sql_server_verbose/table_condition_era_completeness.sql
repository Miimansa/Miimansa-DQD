SELECT DISTINCT 
		    co.person_id
		FROM @cdmDatabaseSchema.condition_occurrence co
		{@cohort & '@runForCohort' == 'Yes'}?{
    		JOIN @cohortDatabaseSchema.@cohortTableName c 
    		    ON co.person_id = c.subject_id
    		    AND c.cohort_definition_id = @cohortDefinitionId
    	}
		LEFT JOIN @cdmDatabaseSchema.@cdmTableName cdmTable 
		    ON co.person_id = cdmTable.person_id
  	    WHERE cdmTable.person_id IS NULL
  	    AND co.condition_concept_id != 0
;
