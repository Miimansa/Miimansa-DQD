SELECT 
		COUNT_BIG(DISTINCT person_id) AS num_rows
	FROM @cdmDatabaseSchema.condition_occurrence co
	{@cohort & '@runForCohort' == 'Yes'}?{
    	JOIN @cohortDatabaseSchema.@cohortTableName c 
    	    ON co.person_id = c.subject_id
    	    AND c.cohort_definition_id = @cohortDefinitionId
    }
    WHERE co.condition_concept_id != 0
;
