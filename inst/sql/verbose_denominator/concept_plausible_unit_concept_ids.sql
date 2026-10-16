SELECT 
	  COUNT_BIG(*) AS num_rows
	FROM @cdmDatabaseSchema.@cdmTableName m
  	{@cohort}?{
    	JOIN @cohortDatabaseSchema.@cohortTableName c
    		ON m.person_id = c.subject_id
    		AND c.cohort_definition_id = @cohortDefinitionId
  	}
	WHERE m.@cdmFieldName = @conceptId
	AND (unit_concept_id != 0 OR unit_concept_id IS NULL)
;
