SELECT 
		COUNT_BIG(*) AS num_rows
	FROM @cdmDatabaseSchema.@cdmTableName cdmTable
		JOIN @vocabDatabaseSchema.concept_ancestor ca
			ON ca.descendant_concept_id = cdmTable.@cdmFieldName
		{@cohort}?{
		JOIN @cohortDatabaseSchema.@cohortTableName c
			ON cdmTable.person_id = c.subject_id
			AND c.cohort_definition_id = @cohortDefinitionId
		}
	WHERE ca.ancestor_concept_id IN (@conceptId)
;
