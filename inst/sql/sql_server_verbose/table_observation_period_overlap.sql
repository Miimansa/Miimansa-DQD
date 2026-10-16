SELECT DISTINCT
			cdmTable.person_id 
		FROM @cdmDatabaseSchema.observation_period cdmTable
		{@cohort & '@runForCohort' == 'Yes'}?{
    		JOIN @cohortDatabaseSchema.@cohortTableName c 
    		    ON cdmTable.person_id = c.subject_id
    		    AND c.cohort_definition_id = @cohortDefinitionId
    	}
		JOIN @cdmDatabaseSchema.observation_period cdmTable2 
		    ON cdmTable.person_id = cdmTable2.person_id
		    AND cdmTable.observation_period_id != cdmTable2.observation_period_id
		WHERE (cdmTable.observation_period_start_date <= cdmTable2.observation_period_end_date 
		    AND cdmTable.observation_period_end_date >= cdmTable2.observation_period_start_date)
		    OR (DATEADD(day, 1, cdmTable.observation_period_end_date) = cdmTable2.observation_period_start_date)
		    OR (DATEADD(day, 1, cdmTable2.observation_period_end_date) = cdmTable.observation_period_start_date)
;
