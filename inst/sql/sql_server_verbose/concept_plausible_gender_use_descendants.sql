SELECT cdmTable.* 
		FROM @cdmDatabaseSchema.@cdmTableName cdmTable
			JOIN @cdmDatabaseSchema.person p
				ON cdmTable.person_id = p.person_id
			JOIN @vocabDatabaseSchema.concept_ancestor ca
				ON ca.descendant_concept_id = cdmTable.@cdmFieldName
			{@cohort}?{
			JOIN @cohortDatabaseSchema.@cohortTableName c
				ON cdmTable.person_id = c.subject_id
				AND c.cohort_definition_id = @cohortDefinitionId
			}
		WHERE ca.ancestor_concept_id IN (@conceptId)
		AND p.gender_concept_id <> {@plausibleGenderUseDescendants == 'Male'} ? {8507} : {8532}
;
