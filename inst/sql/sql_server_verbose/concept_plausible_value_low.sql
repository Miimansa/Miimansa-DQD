SELECT 
			m.* 
		FROM @schema.@cdmTableName m
		{@cohort}?{
			JOIN @cohortDatabaseSchema.@cohortTableName c
				ON m.person_id = c.subject_id
				AND c.cohort_definition_id = @cohortDefinitionId
		}
		WHERE m.@cdmFieldName = @conceptId
			AND m.unit_concept_id = @unitConceptId
			AND m.value_as_number IS NOT NULL
			AND m.value_as_number < @plausibleValueLow
;
