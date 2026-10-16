SELECT 
		  m.* 
		FROM @cdmDatabaseSchema.@cdmTableName m
  		{@cohort}?{
        JOIN @cohortDatabaseSchema.@cohortTableName c
    		ON m.person_id = c.subject_id
    		AND c.cohort_definition_id = @cohortDefinitionId
    	}
		WHERE m.@cdmFieldName = @conceptId
			AND m.unit_concept_id IS NOT NULL
			/* '-1' stands for the cases when the only plausible unit_concept_id is no unit; 0 prevents flagging rows with a unit_concept_id of 0, which are checked in standardConceptRecordCompleteness */
		  	AND (
				('@plausibleUnitConceptIds' = '-1' AND m.unit_concept_id != 0) 
    			OR m.unit_concept_id NOT IN (@plausibleUnitConceptIds, 0)
			)
;
