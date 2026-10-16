SELECT 
		COUNT_BIG(DISTINCT cdmTable.person_id) AS num_rows
	FROM @cdmDatabaseSchema.observation_period cdmTable
	{@cohort & '@runForCohort' == 'Yes'}?{
    	JOIN @cohortDatabaseSchema.@cohortTableName c 
    	    ON cdmTable.person_id = c.subject_id
    	    AND c.cohort_definition_id = @cohortDefinitionId
    }
;
