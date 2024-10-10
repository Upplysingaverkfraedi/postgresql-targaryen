-- Spurning 1
CREATE OR REPLACE FUNCTION targaryen.get_kingdom_size(kingdom_id INT)
    RETURNS NUMERIC AS $$
DECLARE area_km2 NUMERIC;
BEGIN

    -- Gá hvort að kingdom_id sé til
    IF NOT EXISTS (SELECT 1 FROM atlas.kingdoms WHERE gid = kingdom_id) THEN
        RAISE EXCEPTION 'Invalid kingdom_id: %', kingdom_id;
    END IF;

    -- Reikna stærðina með því að nota geography type til að fá km²
    SELECT ST_Area(geog) / 1000000 -- Umbreyta úr m² í km²
    INTO area_km2
    FROM atlas.kingdoms
    WHERE gid = kingdom_id;
    RETURN TRUNC(area_km2);  -- Truncate til að fjarlægja aukastafi
END;
$$ LANGUAGE plpgsql;

WITH RankedKingdoms AS (
    SELECT gid AS kingdom_id, name, targaryen.get_kingdom_size(gid) AS area_km2,
           RANK() OVER (ORDER BY targaryen.get_kingdom_size(gid) DESC) AS rank
    FROM atlas.kingdoms
)

SELECT
    name AS kingdom_name,
    area_km2
FROM
    RankedKingdoms
WHERE
    rank = 3;

-- Spurning 2

-- Búum til nýja töflu
CREATE TABLE if not exists targaryen.locations_not_in_kingdoms AS
SELECT l.*
FROM atlas.locations l
WHERE NOT EXISTS (
    SELECT 1
    FROM atlas.kingdoms k
    WHERE ST_Within(l.geog::geometry, k.geog::geometry)
);

-- targaryen.locations_not_in_kingdoms
SELECT * FROM targaryen.locations_not_in_kingdoms;

WITH RarestType AS (
    SELECT
        type,
        COUNT(*) AS type_count
    FROM
        targaryen.locations_not_in_kingdoms
    GROUP BY
        type
    ORDER BY
        type_count ASC
    LIMIT 1
)

SELECT
    type,
    array_agg(name) AS names
FROM
    targaryen.locations_not_in_kingdoms
WHERE
    type = (SELECT type FROM RarestType)
GROUP BY
    type;