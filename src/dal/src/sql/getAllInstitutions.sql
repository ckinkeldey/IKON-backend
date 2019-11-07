SELECT DISTINCT i.id, i.name, i.address, i3.lat, i3.lon
FROM projectsinstitutions
LEFT JOIN institutions i on projectsinstitutions.institution_id = i.id
LEFT JOIN institutionsgeolocations i3 on i.id = i3.institution_id

ORDER BY id;
