SELECT 
            '@cdmTableName.@cdmFieldName' AS violating_field, 
            cdmTable.* 
        FROM @schema.@cdmTableName cdmTable
        {@cohort & '@runForCohort' == 'Yes'}?{
            JOIN @cohortDatabaseSchema.@cohortTableName c
                ON cdmTable.person_id = c.subject_id
                AND c.cohort_definition_id = @cohortDefinitionId
        }
        /* Violates if 0, or, for non-required fields, if empty and respective source value non-empty. For example, this resolves to the following for death.cause_concept_id:
        WHERE death.cause_concept_id = 0 OR (death.cause_concept_id IS NULL AND death.cause_source_value IS NOT NULL)
        */
        WHERE cdmTable.@cdmFieldName = 0
        {@cdmTableName != 'DOSE_ERA' & (@cdmFieldName == 'UNIT_CONCEPT_ID' | @cdmFieldName == 'UNIT_SOURCE_CONCEPT_ID')}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.unit_source_value IS NOT NULL)}
        {@cdmFieldName == 'ADMITTED_FROM_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.admitted_from_source_value IS NOT NULL)}
        {@cdmFieldName == 'ADMITTING_SOURCE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.admitting_source_value IS NOT NULL)}
        {@cdmFieldName == 'DISCHARGED_TO_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.discharged_to_source_value IS NOT NULL)}
        {@cdmFieldName == 'DISCHARGE_TO_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.discharge_to_source_value IS NOT NULL)}
        {@cdmFieldName == 'CONDITION_STATUS_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.condition_status_source_value IS NOT NULL)}
        {@cdmFieldName == 'ROUTE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.route_source_value IS NOT NULL)}
        {@cdmFieldName == 'MODIFIER_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.modifier_source_value IS NOT NULL)}
        {@cdmFieldName == 'QUALIFIER_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.qualifier_source_value IS NOT NULL)}
        {@cdmFieldName == 'CAUSE_CONCEPT_ID' | @cdmFieldName == 'CAUSE_SOURCE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.cause_source_value IS NOT NULL)}
        {@cdmFieldName == 'ANATOMIC_SITE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.anatomic_site_source_value IS NOT NULL)}
        {@cdmFieldName == 'DISEASE_STATUS_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.disease_status_source_value IS NOT NULL)}
        {@cdmFieldName == 'COUNTRY_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.country_source_value IS NOT NULL)}
        {@cdmFieldName == 'PLACE_OF_SERVICE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.place_of_service_source_value IS NOT NULL)}
        {@cdmFieldName == 'SPECIALTY_CONCEPT_ID' | @cdmFieldName == 'SPECIALTY_SOURCE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.specialty_source_value IS NOT NULL)}
        {@cdmTableName == 'PROVIDER' & (@cdmFieldName == 'GENDER_CONCEPT_ID' | @cdmFieldName == 'GENDER_SOURCE_CONCEPT_ID')}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.gender_source_value IS NOT NULL)}
        {@cdmFieldName == 'PAYER_CONCEPT_ID' | @cdmFieldName == 'PAYER_SOURCE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.payer_source_value IS NOT NULL)}
        {@cdmFieldName == 'PLAN_CONCEPT_ID' | @cdmFieldName == 'PLAN_SOURCE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.plan_source_value IS NOT NULL)}
        {@cdmFieldName == 'SPONSOR_CONCEPT_ID' | @cdmFieldName == 'SPONSOR_SOURCE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.sponsor_source_value IS NOT NULL)}
        {@cdmFieldName == 'STOP_REASON_CONCEPT_ID' | @cdmFieldName == 'STOP_REASON_SOURCE_CONCEPT_ID'}?{OR (cdmTable.@cdmFieldName IS NULL AND cdmTable.stop_reason_source_value IS NOT NULL)}
;
