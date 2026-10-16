SELECT 
		COUNT_BIG(*) AS num_rows
	FROM @cdmDatabaseSchema.@cdmTableName cdmTable
	{@cohort}?{
		JOIN @cohortDatabaseSchema.@cohortTableName c
		  	ON cdmTable.person_id = c.subject_id
		  	AND c.cohort_definition_id = @cohortDefinitionId
	}
	WHERE @cdmFieldName = @conceptId
;
