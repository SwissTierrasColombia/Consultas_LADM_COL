WITH
 unidad_area_terreno AS (
	 SELECT ' [' || setting || ']' FROM operacion.t_ili2db_column_prop WHERE tablename = 'op_terreno' AND columnname = 'area_terreno' LIMIT 1
 ),
 terrenos_seleccionados AS (
	SELECT 764 AS ue_terreno WHERE '764' <> 'NULL'
		UNION
	SELECT uebaunit.ue_op_terreno FROM operacion.op_predio LEFT JOIN operacion.uebaunit ON op_predio.t_id = uebaunit.baunit  WHERE uebaunit.ue_op_terreno IS NOT NULL AND CASE WHEN 'NULL' = 'NULL' THEN  1 = 2 ELSE (op_predio.codigo_orip || '-'|| op_predio.matricula_inmobiliaria) = 'NULL' END
		UNION
	SELECT uebaunit.ue_op_terreno FROM operacion.op_predio LEFT JOIN operacion.uebaunit ON op_predio.t_id = uebaunit.baunit  WHERE uebaunit.ue_op_terreno IS NOT NULL AND CASE WHEN 'NULL' = 'NULL' THEN  1 = 2 ELSE op_predio.numero_predial = 'NULL' END
		UNION
	SELECT uebaunit.ue_op_terreno FROM operacion.op_predio LEFT JOIN operacion.uebaunit ON op_predio.t_id = uebaunit.baunit  WHERE uebaunit.ue_op_terreno IS NOT NULL AND CASE WHEN 'NULL' = 'NULL' THEN  1 = 2 ELSE op_predio.numero_predial_anterior = 'NULL' END
 ),
 predios_seleccionados AS (
	SELECT uebaunit.baunit as t_id FROM operacion.uebaunit WHERE uebaunit.ue_op_terreno = 764 AND '764' <> 'NULL'
		UNION
	SELECT t_id FROM operacion.op_predio WHERE CASE WHEN 'NULL' = 'NULL' THEN  1 = 2 ELSE (op_predio.codigo_orip || '-'|| op_predio.matricula_inmobiliaria) = 'NULL' END
		UNION
	SELECT t_id FROM operacion.op_predio WHERE CASE WHEN 'NULL' = 'NULL' THEN  1 = 2 ELSE op_predio.numero_predial = 'NULL' END
		UNION
	SELECT t_id FROM operacion.op_predio WHERE CASE WHEN 'NULL' = 'NULL' THEN  1 = 2 ELSE op_predio.numero_predial_anterior = 'NULL' END
 ),
 derechos_seleccionados AS (
	 SELECT DISTINCT op_derecho.t_id FROM operacion.op_derecho WHERE op_derecho.unidad IN (SELECT * FROM predios_seleccionados)
 ),
 derecho_interesados AS (
	 SELECT DISTINCT op_derecho.interesado_op_interesado, op_derecho.t_id FROM operacion.op_derecho WHERE op_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND op_derecho.interesado_op_interesado IS NOT NULL
 ),
 derecho_agrupacion_interesados AS (
	 SELECT DISTINCT op_derecho.interesado_op_agrupacion_interesados, miembros.interesados_op_interesado
	 FROM operacion.op_derecho LEFT JOIN operacion.miembros ON op_derecho.interesado_op_agrupacion_interesados = miembros.agrupacion
	 WHERE op_derecho.t_id IN (SELECT * FROM derechos_seleccionados) AND op_derecho.interesado_op_agrupacion_interesados IS NOT NULL
 ),
  restricciones_seleccionadas AS (
	 SELECT DISTINCT op_restriccion.t_id FROM operacion.op_restriccion WHERE op_restriccion.unidad IN (SELECT * FROM predios_seleccionados)
 ),
 restriccion_interesados AS (
	 SELECT DISTINCT op_restriccion.interesado_op_interesado, op_restriccion.t_id FROM operacion.op_restriccion WHERE op_restriccion.t_id IN (SELECT * FROM restricciones_seleccionadas) AND op_restriccion.interesado_op_interesado IS NOT NULL
 ),
 restriccion_agrupacion_interesados AS (
	 SELECT DISTINCT op_restriccion.interesado_op_agrupacion_interesados, miembros.interesados_op_interesado
	 FROM operacion.op_restriccion LEFT JOIN operacion.miembros ON op_restriccion.interesado_op_agrupacion_interesados = miembros.agrupacion
	 WHERE op_restriccion.t_id IN (SELECT * FROM restricciones_seleccionadas) AND op_restriccion.interesado_op_agrupacion_interesados IS NOT NULL
 ),
 info_contacto_interesados_derecho AS (
		SELECT op_interesado_contacto.interesado,
		  json_agg(
				json_build_object('id', op_interesado_contacto.t_id,
									   'attributes', json_build_object('Teléfono 1', op_interesado_contacto.telefono1,
																	   'Teléfono 2', op_interesado_contacto.telefono2,
																	   'Domicilio notificación', op_interesado_contacto.domicilio_notificacion,
																	   'Correo_Electrónico', op_interesado_contacto.correo_electronico,
																	   'Origen_de_datos', op_interesado_contacto.origen_datos)) ORDER BY op_interesado_contacto.t_id)
		FILTER(WHERE op_interesado_contacto.t_id IS NOT NULL) AS interesado_contacto
		FROM operacion.op_interesado_contacto
		WHERE op_interesado_contacto.interesado IN (SELECT derecho_interesados.interesado_op_interesado FROM derecho_interesados)
		GROUP BY op_interesado_contacto.interesado
 ),
 info_interesados_derecho AS (
	 SELECT derecho_interesados.t_id,
	  json_agg(
		json_build_object('id', op_interesado.t_id,
						  'attributes', json_build_object('Tipo', op_interesado.tipo,
														  op_interesadodocumentotipo.dispname, op_interesado.documento_identidad,
														  'Nombre', op_interesado.nombre,
														  CASE WHEN op_interesado.tipo = 'Persona_No_Natural' THEN 'Tipo interesado jurídico' ELSE 'Género' END, CASE WHEN op_interesado.tipo = 'Persona_No_Natural' THEN op_interesado.tipo ELSE op_interesado.sexo END,
														  'interesado_contacto', COALESCE(info_contacto_interesados_derecho.interesado_contacto, '[]')))
	 ORDER BY op_interesado.t_id) FILTER (WHERE op_interesado.t_id IS NOT NULL) AS op_interesado
	 FROM derecho_interesados LEFT JOIN operacion.op_interesado ON op_interesado.t_id = derecho_interesados.interesado_op_interesado
   LEFT JOIN operacion.op_interesadodocumentotipo ON op_interesadodocumentotipo.ilicode = op_interesado.tipo_documento
	 LEFT JOIN info_contacto_interesados_derecho ON info_contacto_interesados_derecho.interesado = op_interesado.t_id
	 GROUP BY derecho_interesados.t_id
 ),
 info_contacto_interesado_agrupacion_interesados_derecho AS (
		SELECT op_interesado_contacto.interesado,
		  json_agg(
				json_build_object('id', op_interesado_contacto.t_id,
									   'attributes', json_build_object('Teléfono 1', op_interesado_contacto.telefono1,
																	   'Teléfono 2', op_interesado_contacto.telefono2,
																	   'Domicilio notificación', op_interesado_contacto.domicilio_notificacion,
																	   'Correo_Electrónico', op_interesado_contacto.correo_electronico,
																	   'Origen_de_datos', op_interesado_contacto.origen_datos)) ORDER BY op_interesado_contacto.t_id)
		FILTER(WHERE op_interesado_contacto.t_id IS NOT NULL) AS interesado_contacto
		FROM operacion.op_interesado_contacto LEFT JOIN derecho_interesados ON derecho_interesados.interesado_op_interesado = op_interesado_contacto.interesado
		WHERE op_interesado_contacto.interesado IN (SELECT DISTINCT derecho_agrupacion_interesados.interesados_op_interesado FROM derecho_agrupacion_interesados)
		GROUP BY op_interesado_contacto.interesado
 ),
 info_interesados_agrupacion_interesados_derecho AS (
	 SELECT derecho_agrupacion_interesados.interesado_op_agrupacion_interesados,
	  json_agg(
		json_build_object('id', op_interesado.t_id,
						  'attributes', json_build_object(op_interesadodocumentotipo.dispname, op_interesado.documento_identidad,
														  'Nombre', op_interesado.nombre,
														  CASE WHEN op_interesado.tipo = 'Persona_No_Natural' THEN 'Tipo interesado jurídico' ELSE 'Género' END, CASE WHEN op_interesado.tipo = 'Persona_No_Natural' THEN op_interesado.tipo ELSE op_interesado.sexo END,
														  'interesado_contacto', COALESCE(info_contacto_interesado_agrupacion_interesados_derecho.interesado_contacto, '[]'),
														  'fraccion', ROUND((fraccion.numerador::numeric/fraccion.denominador::numeric)*100,2) ))
	 ORDER BY op_interesado.t_id) FILTER (WHERE op_interesado.t_id IS NOT NULL) AS op_interesado
	 FROM derecho_agrupacion_interesados LEFT JOIN operacion.op_interesado ON op_interesado.t_id = derecho_agrupacion_interesados.interesados_op_interesado
   LEFT JOIN operacion.op_interesadodocumentotipo ON op_interesadodocumentotipo.ilicode = op_interesado.tipo_documento
	 LEFT JOIN info_contacto_interesado_agrupacion_interesados_derecho ON info_contacto_interesado_agrupacion_interesados_derecho.interesado = op_interesado.t_id
	 LEFT JOIN operacion.miembros ON (miembros.agrupacion::text || miembros.interesados_op_interesado::text) = (derecho_agrupacion_interesados.interesado_op_agrupacion_interesados::text|| op_interesado.t_id::text)
	 LEFT JOIN operacion.fraccion ON miembros.t_id = fraccion.miembros_participacion
	 GROUP BY derecho_agrupacion_interesados.interesado_op_agrupacion_interesados
 ),
 info_agrupacion_interesados AS (
	 SELECT op_derecho.t_id,
	 json_agg(
		json_build_object('id', op_agrupacion_interesados.t_id,
						  'attributes', json_build_object('Tipo de agrupación de interesados', op_agrupacion_interesados.tipo,
														  'Nombre', op_agrupacion_interesados.nombre,
														  'op_interesado', COALESCE(info_interesados_agrupacion_interesados_derecho.op_interesado, '[]')))
	 ORDER BY op_agrupacion_interesados.t_id) FILTER (WHERE op_agrupacion_interesados.t_id IS NOT NULL) AS op_agrupacion_interesados
	 FROM operacion.op_agrupacion_interesados LEFT JOIN operacion.op_derecho ON op_agrupacion_interesados.t_id = op_derecho.interesado_op_agrupacion_interesados
	 LEFT JOIN info_interesados_agrupacion_interesados_derecho ON info_interesados_agrupacion_interesados_derecho.interesado_op_agrupacion_interesados = op_agrupacion_interesados.t_id
	 WHERE op_agrupacion_interesados.t_id IN (SELECT DISTINCT derecho_agrupacion_interesados.interesado_op_agrupacion_interesados FROM derecho_agrupacion_interesados)
	 AND op_derecho.t_id IN (SELECT derechos_seleccionados.t_id FROM derechos_seleccionados)
	 GROUP BY op_derecho.t_id
 ),
 info_fuentes_administrativas_derecho AS (
	SELECT op_derecho.t_id,
	 json_agg(
		json_build_object('id', op_fuenteadministrativa.t_id,
						  'attributes', json_build_object('Tipo de fuente administrativa', op_fuenteadministrativa.tipo,
														  'Nombre', op_fuenteadministrativa.ente_emisor,
														  'Estado disponibilidad', op_fuenteadministrativa.estado_disponibilidad,
														  'Archivo fuente', extarchivo.datos))
	 ORDER BY op_fuenteadministrativa.t_id) FILTER (WHERE op_fuenteadministrativa.t_id IS NOT NULL) AS op_fuenteadministrativa
	FROM operacion.op_derecho
	LEFT JOIN operacion.rrrfuente ON op_derecho.t_id = rrrfuente.rrr_op_derecho
	LEFT JOIN operacion.op_fuenteadministrativa ON rrrfuente.rfuente = op_fuenteadministrativa.t_id
	LEFT JOIN operacion.extarchivo ON extarchivo.op_fuenteadministrtiva_ext_archivo_id = op_fuenteadministrativa.t_id
	WHERE op_derecho.t_id IN (SELECT derechos_seleccionados.t_id FROM derechos_seleccionados)
    GROUP BY op_derecho.t_id
 ),
info_derecho AS (
  SELECT op_derecho.unidad,
	json_agg(
		json_build_object('id', op_derecho.t_id,
						  'attributes', json_build_object('Tipo de derecho', op_derecho.tipo,
														  'Descripción', op_derecho.descripcion,
														  'op_fuenteadministrativa', COALESCE(info_fuentes_administrativas_derecho.op_fuenteadministrativa, '[]'),
														  CASE WHEN info_agrupacion_interesados.op_agrupacion_interesados IS NOT NULL THEN 'op_agrupacion_interesados' ELSE 'op_interesado' END, CASE WHEN info_agrupacion_interesados.op_agrupacion_interesados IS NOT NULL THEN COALESCE(info_agrupacion_interesados.op_agrupacion_interesados, '[]') ELSE COALESCE(info_interesados_derecho.op_interesado, '[]') END))
	 ORDER BY op_derecho.t_id) FILTER (WHERE op_derecho.t_id IS NOT NULL) AS op_derecho
  FROM operacion.op_derecho LEFT JOIN info_fuentes_administrativas_derecho ON op_derecho.t_id = info_fuentes_administrativas_derecho.t_id
  LEFT JOIN info_interesados_derecho ON op_derecho.t_id = info_interesados_derecho.t_id
  LEFT JOIN info_agrupacion_interesados ON op_derecho.t_id = info_agrupacion_interesados.t_id
  WHERE op_derecho.t_id IN (SELECT * FROM derechos_seleccionados)
  GROUP BY op_derecho.unidad
),
 info_contacto_interesados_restriccion AS (
		SELECT op_interesado_contacto.interesado,
		  json_agg(
				json_build_object('id', op_interesado_contacto.t_id,
									   'attributes', json_build_object('Teléfono 1', op_interesado_contacto.telefono1,
																	   'Teléfono 2', op_interesado_contacto.telefono2,
																	   'Domicilio notificación', op_interesado_contacto.domicilio_notificacion,
																	   'Correo_Electrónico', op_interesado_contacto.correo_electronico,
																	   'Origen_de_datos', op_interesado_contacto.origen_datos)) ORDER BY op_interesado_contacto.t_id)
		FILTER(WHERE op_interesado_contacto.t_id IS NOT NULL) AS interesado_contacto
		FROM operacion.op_interesado_contacto
		WHERE op_interesado_contacto.interesado IN (SELECT restriccion_interesados.interesado_op_interesado FROM restriccion_interesados)
		GROUP BY op_interesado_contacto.interesado
 ),
 info_interesados_restriccion AS (
	 SELECT restriccion_interesados.t_id,
	  json_agg(
		json_build_object('id', op_interesado.t_id,
						  'attributes', json_build_object('Tipo', op_interesado.tipo,
														  op_interesadodocumentotipo.dispname, op_interesado.documento_identidad,
														  'Nombre', op_interesado.nombre,
														  CASE WHEN op_interesado.tipo = 'Persona_No_Natural' THEN 'Tipo interesado jurídico' ELSE 'Género' END, CASE WHEN op_interesado.tipo = 'Persona_No_Natural' THEN op_interesado.tipo ELSE op_interesado.sexo END,
														  'interesado_contacto', COALESCE(info_contacto_interesados_restriccion.interesado_contacto, '[]')))
	 ORDER BY op_interesado.t_id) FILTER (WHERE op_interesado.t_id IS NOT NULL) AS op_interesado
	 FROM restriccion_interesados LEFT JOIN operacion.op_interesado ON op_interesado.t_id = restriccion_interesados.interesado_op_interesado
	 LEFT JOIN operacion.op_interesadodocumentotipo ON op_interesadodocumentotipo.ilicode = op_interesado.tipo_documento
	 LEFT JOIN info_contacto_interesados_restriccion ON info_contacto_interesados_restriccion.interesado = op_interesado.t_id
	 GROUP BY restriccion_interesados.t_id
 ),
 info_contacto_interesado_agrupacion_interesados_restriccion AS (
		SELECT op_interesado_contacto.interesado,
		  json_agg(
				json_build_object('id', op_interesado_contacto.t_id,
									   'attributes', json_build_object('Teléfono 1', op_interesado_contacto.telefono1,
																	   'Teléfono 2', op_interesado_contacto.telefono2,
																	   'Domicilio notificación', op_interesado_contacto.domicilio_notificacion,
																	   'Correo_Electrónico', op_interesado_contacto.correo_electronico,
																	   'Origen_de_datos', op_interesado_contacto.origen_datos)) ORDER BY op_interesado_contacto.t_id)
		FILTER(WHERE op_interesado_contacto.t_id IS NOT NULL) AS interesado_contacto
		FROM operacion.op_interesado_contacto LEFT JOIN restriccion_interesados ON restriccion_interesados.interesado_op_interesado = op_interesado_contacto.interesado
		WHERE op_interesado_contacto.interesado IN (SELECT DISTINCT restriccion_agrupacion_interesados.interesados_op_interesado FROM restriccion_agrupacion_interesados)
		GROUP BY op_interesado_contacto.interesado
 ),
 info_interesados_agrupacion_interesados_restriccion AS (
	 SELECT restriccion_agrupacion_interesados.interesado_op_agrupacion_interesados,
	  json_agg(
		json_build_object('id', op_interesado.t_id,
						  'attributes', json_build_object(op_interesadodocumentotipo.dispname, op_interesado.documento_identidad,
														  'Nombre', op_interesado.nombre,
														  CASE WHEN op_interesado.tipo = 'Persona_No_Natural' THEN 'Tipo interesado jurídico' ELSE 'Género' END, CASE WHEN op_interesado.tipo = 'Persona_No_Natural' THEN op_interesado.tipo ELSE op_interesado.sexo END,
														  'interesado_contacto', COALESCE(info_contacto_interesado_agrupacion_interesados_restriccion.interesado_contacto, '[]'),
														  'fraccion', ROUND((fraccion.numerador::numeric/fraccion.denominador::numeric)*100,2) ))
	 ORDER BY op_interesado.t_id) FILTER (WHERE op_interesado.t_id IS NOT NULL) AS op_interesado
	 FROM restriccion_agrupacion_interesados LEFT JOIN operacion.op_interesado ON op_interesado.t_id = restriccion_agrupacion_interesados.interesados_op_interesado
   LEFT JOIN operacion.op_interesadodocumentotipo ON op_interesadodocumentotipo.ilicode = op_interesado.tipo_documento
	 LEFT JOIN info_contacto_interesado_agrupacion_interesados_restriccion ON info_contacto_interesado_agrupacion_interesados_restriccion.interesado = op_interesado.t_id
	 LEFT JOIN operacion.miembros ON (miembros.agrupacion::text || miembros.interesados_op_interesado::text) = (restriccion_agrupacion_interesados.interesado_op_agrupacion_interesados::text|| op_interesado.t_id::text)
	 LEFT JOIN operacion.fraccion ON miembros.t_id = fraccion.miembros_participacion
	 GROUP BY restriccion_agrupacion_interesados.interesado_op_agrupacion_interesados
 ),
 info_agrupacion_interesados_restriccion AS (
	 SELECT op_restriccion.t_id,
	 json_agg(
		json_build_object('id', op_agrupacion_interesados.t_id,
						  'attributes', json_build_object('Tipo de agrupación de interesados', op_agrupacion_interesados.tipo,
														  'Nombre', op_agrupacion_interesados.nombre,
														  'op_interesado', COALESCE(info_interesados_agrupacion_interesados_restriccion.op_interesado, '[]')))
	 ORDER BY op_agrupacion_interesados.t_id) FILTER (WHERE op_agrupacion_interesados.t_id IS NOT NULL) AS op_agrupacion_interesados
	 FROM operacion.op_agrupacion_interesados LEFT JOIN operacion.op_restriccion ON op_agrupacion_interesados.t_id = op_restriccion.interesado_op_agrupacion_interesados
	 LEFT JOIN info_interesados_agrupacion_interesados_restriccion ON info_interesados_agrupacion_interesados_restriccion.interesado_op_agrupacion_interesados = op_agrupacion_interesados.t_id
	 WHERE op_agrupacion_interesados.t_id IN (SELECT DISTINCT restriccion_agrupacion_interesados.interesado_op_agrupacion_interesados FROM restriccion_agrupacion_interesados)
	 AND op_restriccion.t_id IN (SELECT restricciones_seleccionadas.t_id FROM restricciones_seleccionadas)
	 GROUP BY op_restriccion.t_id
 ),
 info_fuentes_administrativas_restriccion AS (
	SELECT op_restriccion.t_id,
	 json_agg(
		json_build_object('id', op_fuenteadministrativa.t_id,
						  'attributes', json_build_object('Tipo de fuente administrativa', op_fuenteadministrativa.tipo,
														  'Nombre', op_fuenteadministrativa.ente_emisor,
														  'Estado disponibilidad', op_fuenteadministrativa.estado_disponibilidad,
														  'Archivo fuente', extarchivo.datos))
	 ORDER BY op_fuenteadministrativa.t_id) FILTER (WHERE op_fuenteadministrativa.t_id IS NOT NULL) AS op_fuenteadministrativa
	FROM operacion.op_restriccion
	LEFT JOIN operacion.rrrfuente ON op_restriccion.t_id = rrrfuente.rrr_op_restriccion
	LEFT JOIN operacion.op_fuenteadministrativa ON rrrfuente.rfuente = op_fuenteadministrativa.t_id
	LEFT JOIN operacion.extarchivo ON extarchivo.op_fuenteadministrtiva_ext_archivo_id = op_fuenteadministrativa.t_id
	WHERE op_restriccion.t_id IN (SELECT restricciones_seleccionadas.t_id FROM restricciones_seleccionadas)
    GROUP BY op_restriccion.t_id
 ),
info_restriccion AS (
  SELECT op_restriccion.unidad,
	json_agg(
		json_build_object('id', op_restriccion.t_id,
						  'attributes', json_build_object('Tipo de restricción', op_restriccion.tipo,
														  'Descripción', op_restriccion.descripcion,
														  'op_fuenteadministrativa', COALESCE(info_fuentes_administrativas_restriccion.op_fuenteadministrativa, '[]'),
														  CASE WHEN info_agrupacion_interesados_restriccion.op_agrupacion_interesados IS NOT NULL THEN 'op_agrupacion_interesados' ELSE 'op_interesado' END, CASE WHEN info_agrupacion_interesados_restriccion.op_agrupacion_interesados IS NOT NULL THEN COALESCE(info_agrupacion_interesados_restriccion.op_agrupacion_interesados, '[]') ELSE COALESCE(info_interesados_restriccion.op_interesado, '[]') END))
	 ORDER BY op_restriccion.t_id) FILTER (WHERE op_restriccion.t_id IS NOT NULL) AS op_restriccion
  FROM operacion.op_restriccion LEFT JOIN info_fuentes_administrativas_restriccion ON op_restriccion.t_id = info_fuentes_administrativas_restriccion.t_id
  LEFT JOIN info_interesados_restriccion ON op_restriccion.t_id = info_interesados_restriccion.t_id
  LEFT JOIN info_agrupacion_interesados_restriccion ON op_restriccion.t_id = info_agrupacion_interesados_restriccion.t_id
  WHERE op_restriccion.t_id IN (SELECT * FROM restricciones_seleccionadas)
  GROUP BY op_restriccion.unidad
),
 info_predio AS (
	 SELECT uebaunit.ue_op_terreno,
			json_agg(json_build_object('id', op_predio.t_id,
							  'attributes', json_build_object('Nombre', op_predio.nombre,
															  'NUPRE', op_predio.nupre,
															  'FMI', (op_predio.codigo_orip || '-'|| op_predio.matricula_inmobiliaria),
															  'Número predial', op_predio.numero_predial,
															  'Número predial anterior', op_predio.numero_predial_anterior,
															  'op_derecho', COALESCE(info_derecho.op_derecho, '[]'),
															  'op_restriccion', COALESCE(info_restriccion.op_restriccion, '[]')
															 )) ORDER BY op_predio.t_id) FILTER(WHERE op_predio.t_id IS NOT NULL) as predio
	 FROM operacion.op_predio LEFT JOIN operacion.uebaunit ON uebaunit.baunit = op_predio.t_id
     LEFT JOIN info_derecho ON info_derecho.unidad = op_predio.t_id
	 LEFT JOIN info_restriccion ON info_restriccion.unidad = op_predio.t_id
	 WHERE op_predio.t_id IN (SELECT * FROM predios_seleccionados)
		AND uebaunit.ue_op_terreno IS NOT NULL
		AND uebaunit.ue_op_construccion IS NULL
		AND uebaunit.ue_op_unidadconstruccion IS NULL
     GROUP BY uebaunit.ue_op_terreno
 ),
 info_terreno AS (
	 SELECT op_terreno.t_id,
	 json_build_object('id', op_terreno.t_id,
						'attributes', json_build_object(CONCAT('Área de terreno' , (SELECT * FROM unidad_area_terreno)), op_terreno.area_terreno,
														'predio', COALESCE(info_predio.predio, '[]')
													   )) as terreno
	 FROM operacion.op_terreno LEFT JOIN info_predio ON op_terreno.t_id = info_predio.ue_op_terreno
	 WHERE op_terreno.t_id IN (SELECT * FROM terrenos_seleccionados)
	 ORDER BY op_terreno.t_id
 )
SELECT json_agg(info_terreno.terreno) AS terreno FROM info_terreno