SELECT 
			cdmTable.* 
		FROM @cdmDatabaseSchema.person cdmTable
		{@cohort & '@runForCohort' == 'Yes'}?{
    		JOIN @cohortDatabaseSchema.@cohortTableName c 
    		    ON cdmTable.person_id = c.subject_id
    		    AND c.cohort_definition_id = @cohortDefinitionId
    	}
			LEFT JOIN @schema.@cdmTableName cdmTable2 
			    ON cdmTable.person_id = cdmTable2.person_id
		WHERE cdmTable2.person_id IS NULL
;
