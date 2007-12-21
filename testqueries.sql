--CREATE OR REPLACE FUNCTION strjoin(text, text) RETURNS text AS $$ 
--  SELECT 
--    CASE WHEN LENGTH($1) > 0 THEN $1 || ', ' || $2 
--    ELSE $2
--    END
--$$ LANGUAGE SQL;
--  
--CREATE AGGREGATE agg_concat (
--  stype = text,
--  initcond = '',
--  basetype = text,
--  sfunc = strjoin
--);

SELECT 
  ap.applied_protocol_id AS applied_protocol
  , p.name AS protocol
  , inp.heading || '[' || inp.name || ']' AS inputheading, inp.value AS inputvalue
  , a.name || '=' || a.value AS inpattribute
  , outp.heading || '[' || outp.name || ']' AS outputheading, outp.value AS outputvalue
  , p2.name AS protocol2
  , inp2.heading || '[' || inp2.name || ']' AS inputheading2, inp2.value AS inputvalue2
--  , outp2.heading || '[' || outp.name || ']=' || outp.value AS output2
FROM experiment e 
  INNER JOIN experiment_applied_protocol eap ON e.experiment_id = eap.experiment_id
  INNER JOIN applied_protocol ap ON eap.first_applied_protocol_id = ap.applied_protocol_id
  INNER JOIN protocol p ON ap.protocol_id = p.protocol_id
  INNER JOIN applied_protocol_data apdinp ON ap.applied_protocol_id = apdinp.applied_protocol_id
  INNER JOIN data inp ON apdinp.data_id = inp.data_id AND apdinp.direction = 'input'
  INNER JOIN applied_protocol_data apdoutp ON ap.applied_protocol_id = apdoutp.applied_protocol_id
  INNER JOIN data outp ON apdoutp.data_id = outp.data_id AND apdoutp.direction = 'output'
  -- Next protocol
  INNER JOIN applied_protocol_data apdinp2 ON apdinp2.data_id = outp.data_id AND apdinp2.direction = 'input'
  INNER JOIN applied_protocol ap2 ON apdinp2.applied_protocol_id = ap2.applied_protocol_id
  INNER JOIN protocol p2 ON ap2.protocol_id = p2.protocol_id
  INNER JOIN applied_protocol_data apdinp3 ON ap2.applied_protocol_id = apdinp3.applied_protocol_id
  INNER JOIN data inp2 ON apdinp3.data_id = inp2.data_id AND apdinp3.direction = 'input'
--  INNER JOIN data outp2 ON apd3.data_id = outp2.data_id AND apd3.direction = 'output'
  LEFT JOIN data_attribute da ON inp.data_id = da.data_id
  LEFT JOIN attribute a ON da.attribute_id = a.attribute_id
ORDER BY ap.applied_protocol_id
;
