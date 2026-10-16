SELECT COUNT_BIG(*) AS num_rows
    FROM @schema.@cdmTableName cdmTable
    {@cohort & '@runForCohort' == 'Yes'}?{
        JOIN @cohortDatabaseSchema.@cohortTableName c
            ON cdmTable.person_id = c.subject_id
            AND c.cohort_definition_id = @cohortDefinitionId
    }
    WHERE (cdmTable.@cdmFieldName IS NOT NULL
    {@cdmTableName != 'DOSE_ERA' & (@cdmFieldName == 'UNIT_CONCEPT_ID' | @cdmFieldName == 'UNIT_SOURCE_CONCEPT_ID')}?{OR cdmTable.unit_source_value IS NOT NULL}
    {@cdmFieldName == 'ADMITTED_FROM_CONCEPT_ID'}?{OR cdmTable.admitted_from_source_value IS NOT NULL}
    {@cdmFieldName == 'ADMITTING_SOURCE_CONCEPT_ID'}?{OR cdmTable.admitting_source_value IS NOT NULL}
    {@cdmFieldName == 'DISCHARGED_TO_CONCEPT_ID'}?{OR cdmTable.discharged_to_source_value IS NOT NULL}
    {@cdmFieldName == 'DISCHARGE_TO_CONCEPT_ID'}?{OR cdmTable.discharge_to_source_value IS NOT NULL}
    {@cdmFieldName == 'CONDITION_STATUS_CONCEPT_ID'}?{OR cdmTable.condition_status_source_value IS NOT NULL}
    {@cdmFieldName == 'ROUTE_CONCEPT_ID'}?{OR cdmTable.route_source_value IS NOT NULL}
    {@cdmFieldName == 'MODIFIER_CONCEPT_ID'}?{OR cdmTable.modifier_source_value IS NOT NULL}
    {@cdmFieldName == 'QUALIFIER_CONCEPT_ID'}?{OR cdmTable.qualifier_source_value IS NOT NULL}
    {@cdmFieldName == 'CAUSE_CONCEPT_ID' | @cdmFieldName == 'CAUSE_SOURCE_CONCEPT_ID'}?{OR cdmTable.cause_source_value IS NOT NULL}
    {@cdmFieldName == 'ANATOMIC_SITE_CONCEPT_ID'}?{OR cdmTable.anatomic_site_source_value IS NOT NULL}
    {@cdmFieldName == 'DISEASE_STATUS_CONCEPT_ID'}?{OR cdmTable.disease_status_source_value IS NOT NULL}
    {@cdmFieldName == 'COUNTRY_CONCEPT_ID'}?{OR cdmTable.country_source_value IS NOT NULL}
    {@cdmFieldName == 'PLACE_OF_SERVICE_CONCEPT_ID'}?{OR cdmTable.place_of_service_source_value IS NOT NULL}
    {@cdmFieldName == 'SPECIALTY_CONCEPT_ID' | @cdmFieldName == 'SPECIALTY_SOURCE_CONCEPT_ID'}?{OR cdmTable.specialty_source_value IS NOT NULL}
    {@cdmTableName == 'PROVIDER' & (@cdmFieldName == 'GENDER_CONCEPT_ID' | @cdmFieldName == 'GENDER_SOURCE_CONCEPT_ID')}?{OR cdmTable.gender_source_value IS NOT NULL}
    {@cdmFieldName == 'PAYER_CONCEPT_ID' | @cdmFieldName == 'PAYER_SOURCE_CONCEPT_ID'}?{OR cdmTable.payer_source_value IS NOT NULL}
    {@cdmFieldName == 'PLAN_CONCEPT_ID' | @cdmFieldName == 'PLAN_SOURCE_CONCEPT_ID'}?{OR cdmTable.plan_source_value IS NOT NULL}
    {@cdmFieldName == 'SPONSOR_CONCEPT_ID' | @cdmFieldName == 'SPONSOR_SOURCE_CONCEPT_ID'}?{OR cdmTable.sponsor_source_value IS NOT NULL}
    {@cdmFieldName == 'STOP_REASON_CONCEPT_ID' | @cdmFieldName == 'STOP_REASON_SOURCE_CONCEPT_ID'}?{OR cdmTable.stop_reason_source_value IS NOT NULL})
;
