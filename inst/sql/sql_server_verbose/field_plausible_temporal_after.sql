SELECT 
			'@cdmTableName.@cdmFieldName' AS violating_field, 
			cdmTable.*
    	FROM @schema.@cdmTableName cdmTable
    		{@schema.@cdmTableName != @schema.@plausibleTemporalAfterTableName}?{
				JOIN @schema.@plausibleTemporalAfterTableName plausibleTable 
                    ON cdmTable.person_id = plausibleTable.person_id}
			{@cohort & '@runForCohort' == 'Yes'}?{
    			JOIN @cohortDatabaseSchema.@cohortTableName c 
                    ON cdmTable.person_id = c.subject_id
    				AND c.cohort_definition_id = @cohortDefinitionId
			}
    WHERE 
    	{'@plausibleTemporalAfterTableName' == 'PERSON'}?{
			COALESCE(
				CAST(plausibleTable.@plausibleTemporalAfterFieldName AS DATE),
				CAST(CONCAT(plausibleTable.year_of_birth,'0601') AS DATE)
			) 
		}:{
			CAST(cdmTable.@plausibleTemporalAfterFieldName AS DATE)
		} > CAST(cdmTable.@cdmFieldName AS DATE)
;
