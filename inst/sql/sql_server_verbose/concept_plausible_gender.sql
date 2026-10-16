SELECT cdmTable.* 
		FROM @cdmDatabaseSchema.@cdmTableName cdmTable
			JOIN @cdmDatabaseSchema.person p
				ON cdmTable.person_id = p.person_id
			{@cohort}?{
			JOIN @cohortDatabaseSchema.@cohortTableName c
				ON cdmTable.person_id = c.subject_id
				AND c.cohort_definition_id = @cohortDefinitionId
			}
		WHERE cdmTable.@cdmFieldName = @conceptId
		  	AND p.gender_concept_id <> {@plausibleGender == 'Male'} ? {8507} : {8532}
;
