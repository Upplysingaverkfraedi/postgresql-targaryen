-- Eyðum eldri skoðun ef hún er til
DROP VIEW IF EXISTS targaryen.v_pov_characters_human_readable;

-- Búum til nýja skoðun
CREATE VIEW targaryen.v_pov_characters_human_readable AS

-- Skref 1: Finna allar POV-persónur með grunnupplýsingum
WITH pov_characters AS (
    SELECT
        c.id AS character_id,
        c.titles,
        c.name,
        c.gender,
        c.born,
        c.died,
        c.father,
        c.mother,
        c.spouse
    FROM
        got.characters c
    JOIN got.character_books cb ON cb.character_id = c.id
    WHERE
        cb.pov = TRUE
    GROUP BY
        c.id, c.titles, c.name, c.gender, c.born, c.died, c.father, c.mother, c.spouse
),

-- Skref 2: Tengja nöfn foreldra og maka, búa til full_name og einfaldara gender
character_details AS (
    SELECT
        pc.character_id,
        -- Búa til full_name með fyrsta titlinum ef til er, annars nota bara nafn
        CASE
            WHEN array_length(pc.titles, 1) > 0 AND pc.titles[1] IS NOT NULL AND pc.titles[1] <> ''
                THEN pc.titles[1] || ' ' || pc.name
            ELSE pc.name
        END AS full_name,
        -- Einfalda kyn í 'M' eða 'F'
        CASE
            WHEN pc.gender ILIKE 'male' THEN 'M'
            WHEN pc.gender ILIKE 'female' THEN 'F'
            ELSE NULL
        END AS gender,
        father.name AS father,
        mother.name AS mother,
        spouse.name AS spouse,
        pc.born,
        pc.died
    FROM
        pov_characters pc
    LEFT JOIN got.characters father ON pc.father = father.id
    LEFT JOIN got.characters mother ON pc.mother = mother.id
    LEFT JOIN got.characters spouse ON pc.spouse = spouse.id
),

-- Skref 3: Útdráttur á fæðingar- og dánarári og umbreyting á AC/BC í heiltölur
character_years AS (
    SELECT
        cd.*,
        -- Útdráttur á fæðingarári
        CASE
            WHEN cd.born ~ '\d' THEN
                CASE
                    WHEN cd.born ILIKE '%AC%' THEN
                        CAST((regexp_match(cd.born, '(\d{1,4})'))[1] AS INTEGER)
                    WHEN cd.born ILIKE '%BC%' THEN
                        -1 * CAST((regexp_match(cd.born, '(\d{1,4})'))[1] AS INTEGER)
                    ELSE NULL
                END
            ELSE NULL
        END AS born_year,
        -- Útdráttur á dánarári
        CASE
            WHEN cd.died ~ '\d' THEN
                CASE
                    WHEN cd.died ILIKE '%AC%' THEN
                        CAST((regexp_match(cd.died, '(\d{1,4})'))[1] AS INTEGER)
                    WHEN cd.died ILIKE '%BC%' THEN
                        -1 * CAST((regexp_match(cd.died, '(\d{1,4})'))[1] AS INTEGER)
                    ELSE NULL
                END
            ELSE NULL
        END AS died_year
    FROM
        character_details cd
),

-- Skref 4: Reikna aldur og ákvarða hvort persónan sé á lífi
character_age AS (
    SELECT
        cy.*,
        -- Reikna aldur
        CASE
            WHEN cy.born_year IS NOT NULL THEN
                COALESCE(cy.died_year, 300) - cy.born_year
            ELSE NULL
        END AS age,
        -- Ákvarða hvort persónan sé á lífi
        cy.died_year IS NULL AS alive
    FROM
        character_years cy
),

-- Skref 5: Fá lista yfir bækur sem persónan kemur fyrir í
books_list AS (
    SELECT
        cb.character_id,
        b.name AS book_name,
        b.released
    FROM
        got.character_books cb
    JOIN got.books b ON cb.book_id = b.id
    WHERE
        cb.character_id IN (SELECT character_id FROM pov_characters)
),

-- Skref 6: Hópa bækur í lista
books_aggregated AS (
    SELECT
        bl.character_id,
        ARRAY_AGG(bl.book_name ORDER BY bl.released) AS booklist
    FROM
        books_list bl
    GROUP BY
        bl.character_id
)

-- Loka SELECT til að búa til skoðunina
SELECT
    ca.full_name,
    ca.gender,
    ca.father,
    ca.mother,
    ca.spouse,
    ca.born_year AS born,
    ca.died_year AS died,
    ca.age,
    ca.alive,
    ba.booklist
FROM
    character_age ca
LEFT JOIN books_aggregated ba ON ca.character_id = ba.character_id
ORDER BY
    ca.alive DESC, ca.age DESC;
c.id