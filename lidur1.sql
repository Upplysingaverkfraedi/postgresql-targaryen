-- 1. liður: Finna samsvörun á milli húsa og ríkja í töfluna targaryen.tables_mapping
-- Við setjum inn gögn í töfluna targaryen.tables_mapping með samsvörun á milli húsa og ríkja.
-- Ef til er villa vegna þess að sami house_id er þegar til, þá uppfærum við kingdom_id.

INSERT INTO targaryen.tables_mapping(house_id, kingdom_id)
SELECT houses.id, kingdoms.gid
FROM got.houses
INNER JOIN atlas.kingdoms ON houses.region = kingdoms.name
ON CONFLICT (house_id) DO UPDATE
SET kingdom_id = excluded.kingdom_id;

-- Hér eru gögnin skoðuð til að athuga breytingar eftir að samsvörunin hefur verið framkvæmd.
SELECT * FROM targaryen.tables_mapping;
SELECT * FROM got.houses;
SELECT * FROM atlas.kingdoms;
SELECT * FROM atlas.locations;

-- Spurning 2
-- Inná töflunni atlas.locations er dálkur sem heitir name. Við erum að reyna að finna match við house.
-- Inná töflunni railway.got.houses er dálkur sem heitir name.
-- ég er að reyna að matcha þetta saman, inni atlas.locations er kannski nafn á location: Harrenhall.
-- Og svo er house_name: House of Harrenhall.
-- Getum fundið match þarna á milli ef orðið sem kemur eftir "of" er það sama og location nafnið
-- Ef það er ekki "of" í house name þá er það seinasta orðið í titlinum. Dæmi: House Blackmont og location: Blackmont

WITH HouseLocationCTE AS (
    SELECT
        location.gid AS location_id,
        house.id AS house_id,
        location.name AS location_name,
        location.summary AS location_summary,
        house.name AS house_name,
        -- Notum CASE til að fá match_name
        -- Ef húsið hefur "of", náum við orðinu eftir "of", annars síðasta orðinu í nafninu.
        CASE
            WHEN house.name LIKE '%of%' THEN TRIM(SUBSTRING(house.name FROM 'of (.*)'))
            ELSE TRIM(SPLIT_PART(house.name, ' ', 2))
        END AS match_name,
        -- Athugum hvort house.name sé í location.summary (þetta er til að bæta nákvæmni samsvörunar)
        -- Þetta gerum við þegar það eru nokkur house match fyrir einn location.
        CASE
            WHEN position(house.name IN location.summary) > 0 THEN 1
            ELSE 0
        END AS house_in_summary
    FROM atlas.locations location
    INNER JOIN got.houses house
        ON location.name = CASE
            WHEN house.name LIKE '%of%' THEN TRIM(SUBSTRING(house.name FROM 'of (.*)'))
            ELSE TRIM(SPLIT_PART(house.name, ' ', 2))
        END
),

    -- Við röðum mötchunum eftir því hvort húsið sé í house_summary og notum ROW_NUMBER til
    -- að velja forgangs húsið fyrir hvern location.
RankedMatches AS (
    SELECT
        *,
        -- Notum ROW_NUMBER til að raða húsum eftir hvort þau séu í location_summary og síðan eftir house_id.
        ROW_NUMBER() OVER (
            PARTITION BY location_id
            ORDER BY house_in_summary DESC, house_id
        ) AS rn
    FROM HouseLocationCTE
)
-- Setjum inn forgangs matchið í töfluna targaryen.tables_mapping og uppfærum ef house_id er til.
INSERT INTO targaryen.tables_mapping (house_id, location_id)
SELECT house_id, location_id
FROM RankedMatches
WHERE rn = 1
ON CONFLICT (house_id) DO UPDATE
SET location_id = excluded.location_id;


-- Niðurstöðurnar fyrir Norðrið
SELECT tm.house_id, tm.location_id
FROM targaryen.tables_mapping tm
INNER JOIN atlas.locations location ON tm.location_id = location.gid
INNER JOIN atlas.kingdoms kingdom ON tm.kingdom_id = kingdom.gid
WHERE kingdom.name = 'The North';

-- spurning 3

-- Finna hús sem eru í The North og sundurliða sworn_members með því að nota unnest.
WITH houses_in_north AS (
    SELECT
        h.id AS house_id,
        unnest(h.sworn_members) AS member_id
    FROM got.houses h
    WHERE h.region = 'The North'
),


-- Tengjum sworn_members við töfluna got.characters til að fá nöfn persónanna og finna ættarnöfnin
    -- (síðasta orðið í name dálkinum).

characters_family_names AS (
    SELECT
        ch.id AS char_id,
        ch.name AS char_name,
        split_part(ch.name, ' ', array_length(string_to_array(ch.name, ' '), 1)) AS family -- Finnum ættarnafn (síðasta orðið)
    FROM houses_in_north hn
    JOIN got.characters ch
        ON ch.id = hn.member_id
    WHERE ch.name IS NOT NULL
)

-- Telja meðlimi í hverri ætt og velja aðeins ættir sem hafa fleiri en 5 hliðholla meðlimi.
SELECT
    cf.family, -- Ættarnafn
    COUNT(*) AS total_members --Fjöldi meðlima í ættinni
FROM characters_family_names cf
GROUP BY cf.family
HAVING COUNT(*) > 5 -- Veljum aðeins ættir með fleiri en 5 meðlimi
ORDER BY total_members DESC, cf.family ASC; -- Raða eftir fjölda og ættarnafni