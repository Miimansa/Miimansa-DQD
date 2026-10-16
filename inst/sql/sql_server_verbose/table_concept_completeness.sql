SELECT 
			cdmTable.* 
		FROM @cdmDatabaseSchema.@cdmTableName cdmTable
		{@cohort & '@runForCohort' == 'Yes'}?{
    		JOIN @cohortDatabaseSchema.@cohortTableName c 
    		    ON cdmTable.person_id = c.subject_id
    		    AND c.cohort_definition_id = @cohortDefinitionId
    	}
		WHERE (cdmTable.@cdmFieldName = 0 OR cdmTable.@cdmFieldName IS NULL)
			AND (cdmTable.@cdmSourceFieldName = 0 OR cdmTable.@cdmSourceFieldName IS NULL)
;
