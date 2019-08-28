WITH
 unidad_area_terreno AS (
	 SELECT ' [' || setting || ']' FROM operacion.t_ili2db_column_prop WHERE tablename = 'op_terreno' AND columnname = 'area_terreno' LIMIT 1
 ),
 unidad_area_construida_uc AS (
	 SELECT ' [' || setting || ']' FROM operacion.t_ili2db_column_prop WHERE tablename = 'op_unidadconstruccion' AND columnname = 'area_construida' LIMIT 1
 ),
 terrenos_seleccionados AS (
	SELECT 764 AS ue_op_terreno WHERE '764' <> 'NULL'
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
 construcciones_seleccionadas AS (
	 SELECT ue_op_construccion FROM operacion.uebaunit WHERE uebaunit.baunit IN (SELECT predios_seleccionados.t_id FROM predios_seleccionados WHERE predios_seleccionados.t_id IS NOT NULL) AND ue_op_construccion IS NOT NULL
 ),
 unidadesconstruccion_seleccionadas AS (
	 SELECT op_unidadconstruccion.t_id FROM operacion.op_unidadconstruccion WHERE op_unidadconstruccion.construccion IN (SELECT ue_op_construccion FROM construcciones_seleccionadas)
 ),
 uc_extdireccion AS (
	SELECT extdireccion.op_unidadconstruccion_ext_direccion_id,
		json_agg(
				json_build_object('id', extdireccion.t_id,
									   'attributes', json_build_object('País', extdireccion.pais,
																	   'Departamento', extdireccion.departamento,
																	   'Ciudad', extdireccion.ciudad,
																	   'Código postal', extdireccion.codigo_postal,
																	   'Apartado correo', extdireccion.apartado_correo,
																	   'Nombre calle', extdireccion.nombre_calle))
		ORDER BY extdireccion.t_id) FILTER(WHERE extdireccion.t_id IS NOT NULL) AS extdireccion
	FROM operacion.extdireccion WHERE op_unidadconstruccion_ext_direccion_id IN (SELECT * FROM unidadesconstruccion_seleccionadas)
	GROUP BY extdireccion.op_unidadconstruccion_ext_direccion_id
 ),
 uc_componentes as (
	 select av_unidad_construccion.op_unidad_construccion,
	 json_agg(
				json_build_object('id', av_componente_construccion.t_id,
									   'attributes', json_build_object('Tipo componente', av_componente_construccion.tipo_componente,
																	   'Cantidad', av_componente_construccion.cantidad))
		ORDER BY av_unidad_construccion.t_id) FILTER(WHERE av_unidad_construccion.t_id IS NOT NULL) AS componentes
	 from operacion.av_unidad_construccion LEFT JOIN operacion.av_componente_construccion
	 ON av_unidad_construccion.t_id = av_componente_construccion.unidad_construccion
	 WHERE av_unidad_construccion.op_unidad_construccion IN (SELECT * FROM unidadesconstruccion_seleccionadas)
	 GROUP BY av_unidad_construccion.op_unidad_construccion
 ),
 info_uc AS (
	 SELECT op_unidadconstruccion.construccion,
			json_agg(json_build_object('id', op_unidadconstruccion.t_id,
							  'attributes', json_build_object('Número de pisos', op_unidadconstruccion.numero_pisos,
															  CONCAT('Área construida' , (SELECT * FROM unidad_area_construida_uc)), op_unidadconstruccion.area_construida,
															  'av_componente_construccion', COALESCE(uc_componentes.componentes, '[]'),
															  'Uso', op_unidadconstruccion.uso,
															  'Puntuación', av_unidad_construccion.puntuacion,
															  'extdireccion', COALESCE(uc_extdireccion.extdireccion, '[]')
															 )) ORDER BY op_unidadconstruccion.t_id) FILTER(WHERE op_unidadconstruccion.t_id IS NOT NULL)  as unidadconstruccion
	 FROM operacion.op_unidadconstruccion
	 LEFT JOIN operacion.av_unidad_construccion ON av_unidad_construccion.op_unidad_construccion = op_unidadconstruccion.t_id
	 LEFT JOIN uc_componentes ON uc_componentes.op_unidad_construccion = op_unidadconstruccion.t_id
	 LEFT JOIN uc_extdireccion ON op_unidadconstruccion.t_id = uc_extdireccion.op_unidadconstruccion_ext_direccion_id
	 WHERE op_unidadconstruccion.t_id IN (SELECT * FROM unidadesconstruccion_seleccionadas)
	 GROUP BY op_unidadconstruccion.construccion
 ),
 c_extdireccion AS (
	SELECT extdireccion.op_construccion_ext_direccion_id,
		json_agg(
				json_build_object('id', extdireccion.t_id,
									   'attributes', json_build_object('País', extdireccion.pais,
																	   'Departamento', extdireccion.departamento,
																	   'Ciudad', extdireccion.ciudad,
																	   'Código postal', extdireccion.codigo_postal,
																	   'Apartado correo', extdireccion.apartado_correo,
																	   'Nombre calle', extdireccion.nombre_calle))
		ORDER BY extdireccion.t_id) FILTER(WHERE extdireccion.t_id IS NOT NULL) AS extdireccion
	FROM operacion.extdireccion WHERE op_construccion_ext_direccion_id IN (SELECT * FROM construcciones_seleccionadas)
	GROUP BY extdireccion.op_construccion_ext_direccion_id
 ),
 info_construccion as (
	 SELECT uebaunit.baunit,
			json_agg(json_build_object('id', op_construccion.t_id,
							  'attributes', json_build_object('Área construcción', op_construccion.area_construccion,
															  'extdireccion', COALESCE(c_extdireccion.extdireccion, '[]'),
															  'op_unidadconstruccion', COALESCE(info_uc.unidadconstruccion, '[]')
															 )) ORDER BY op_construccion.t_id) FILTER(WHERE op_construccion.t_id IS NOT NULL) as construccion
	 FROM operacion.op_construccion LEFT JOIN c_extdireccion ON op_construccion.t_id = c_extdireccion.op_construccion_ext_direccion_id
	 LEFT JOIN info_uc ON op_construccion.t_id = info_uc.construccion
     LEFT JOIN operacion.uebaunit ON uebaunit.ue_op_construccion = op_construccion.t_id
	 WHERE op_construccion.t_id IN (SELECT * FROM construcciones_seleccionadas)
	 GROUP BY uebaunit.baunit
 ),
 info_predio AS (
	 SELECT uebaunit.ue_op_terreno,
			json_agg(json_build_object('id', op_predio.t_id,
							  'attributes', json_build_object('Nombre', op_predio.nombre,
															  'Departamento', op_predio.departamento,
															  'Municipio', op_predio.municipio,
															  'NUPRE', op_predio.nupre,
															  'FMI', (op_predio.codigo_orip || '-'|| op_predio.matricula_inmobiliaria),
															  'Número predial', op_predio.numero_predial,
															  'Número predial anterior', op_predio.numero_predial_anterior,
															  'Tipo', op_predio.tipo,
															  'Destinación económica', fcm_formulario_unico_cm.destinacion_economica,
															  'op_construccion', COALESCE(info_construccion.construccion, '[]')
															 )) ORDER BY op_predio.t_id) FILTER(WHERE op_predio.t_id IS NOT NULL) as predio
	 FROM operacion.op_predio LEFT JOIN operacion.uebaunit ON uebaunit.baunit = op_predio.t_id
	 LEFT JOIN info_construccion ON op_predio.t_id = info_construccion.baunit
	 LEFT JOIN operacion.fcm_formulario_unico_cm ON fcm_formulario_unico_cm.op_predio = op_predio.t_id
	 WHERE op_predio.t_id IN (SELECT * FROM predios_seleccionados)
		AND uebaunit.ue_op_terreno IS NOT NULL
		AND uebaunit.ue_op_construccion IS NULL
		AND uebaunit.ue_op_unidadconstruccion IS NULL
		GROUP BY uebaunit.ue_op_terreno
 ),
 t_extdireccion AS (
	SELECT extdireccion.op_terreno_ext_direccion_id,
		json_agg(
				json_build_object('id', extdireccion.t_id,
									   'attributes', json_build_object('País', extdireccion.pais,
																	   'Departamento', extdireccion.departamento,
																	   'Ciudad', extdireccion.ciudad,
																	   'Código postal', extdireccion.codigo_postal,
																	   'Apartado correo', extdireccion.apartado_correo,
																	   'Nombre calle', extdireccion.nombre_calle))
		ORDER BY extdireccion.t_id) FILTER(WHERE extdireccion.t_id IS NOT NULL) AS extdireccion
	FROM operacion.extdireccion WHERE op_terreno_ext_direccion_id IN (SELECT * FROM terrenos_seleccionados)
	GROUP BY extdireccion.op_terreno_ext_direccion_id
 ),
 info_terreno AS (
	SELECT op_terreno.t_id,
      json_build_object('id', op_terreno.t_id,
						'attributes', json_build_object(CONCAT('Área de terreno' , (SELECT * FROM unidad_area_terreno)), op_terreno.area_terreno,
														'extdireccion', COALESCE(t_extdireccion.extdireccion, '[]'),
														'op_predio', COALESCE(info_predio.predio, '[]')
													   )) as terreno
    FROM operacion.op_terreno LEFT JOIN info_predio ON info_predio.ue_op_terreno = op_terreno.t_id
	LEFT JOIN t_extdireccion ON op_terreno.t_id = t_extdireccion.op_terreno_ext_direccion_id
	WHERE op_terreno.t_id IN (SELECT * FROM terrenos_seleccionados)
	ORDER BY op_terreno.t_id
 )
 SELECT json_agg(info_terreno.terreno) AS terreno FROM info_terreno
