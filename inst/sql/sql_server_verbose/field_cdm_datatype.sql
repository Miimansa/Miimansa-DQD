SELECT 
			'@cdmTableName.@cdmFieldName' AS violating_field, 
			cdmTable.* 
		FROM @schema.@cdmTableName cdmTable
		WHERE 
			(ISNUMERIC(cdmTable.@cdmFieldName) = 0 
			OR (ISNUMERIC(cdmTable.@cdmFieldName) = 1 
				AND CHARINDEX('.', CAST(ABS(cdmTable.@cdmFieldName) AS varchar)) != 0))
			AND cdmTable.@cdmFieldName IS NOT NULL
;
