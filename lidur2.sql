DROP VIEW IF EXISTS targaryen.v_pov_characters_human_readable;
-- Búa til nýtt view
CREATE VIEW targaryen.v_pov_characters_human_readable AS
WITH pov_characters AS (
    SELECT
        c.titles,
        c.name,
        c.gender,
        c.born,
        c.died,
        father.name as father,
        mother.name as mother,
        spouse.name as spouse,

        -- Reikna aldur
        COALESCE(
            CAST(CASE WHEN c.died ~ '^[0-9]+$' THEN c.died ELSE NULL END AS INTEGER), 300) -
        CASE
            WHEN (regexp_match(c.born, '([0-9]+) (AC|BC)'))[2] = 'AC' THEN (regexp_match(c.born, '([0-9]+) (AC|BC)'))[1]::int
            WHEN (regexp_match(c.born, '([0-9]+) (AC|BC)'))[2] = 'BC' THEN -(regexp_match(c.born, '([0-9]+) (AC|BC)'))[1]::int
            ELSE NULL
        END AS age,

        -- Meta hvort persóna sé á lífi
        c.died IS NULL AS alive,

        -- Fá lista af bókum þar sem persóna er POV
        ARRAY_AGG(b.name ORDER BY b.released) AS booklist
    FROM
        got.characters c
    left join got.characters father on c.father = father.id
    left join got.characters mother on c.mother = mother.id
    left join got.characters spouse on c.spouse = spouse.id
    left join got.character_books cb on cb.character_id = c.id
    left join got.books b on b.id = cb.book_id
    WHERE
        cb.pov = TRUE
    GROUP BY
        c.id, c.titles, c.name, c.gender, c.born, c.died, father.name, mother.name, spouse.name
)

-- Sækja niðurstöðurnar í 'pov_characters' viewið
SELECT
    titles,
    name,
    gender,
    father,
    mother,
    spouse,
    CASE
        WHEN born IS NOT NULL AND (regexp_match(born, '([0-9]+) (AC|BC)'))[2] = 'AC' THEN (regexp_match(born, '([0-9]+) (AC|BC)'))[1]::int
        WHEN born IS NOT NULL AND (regexp_match(born, '([0-9]+) (AC|BC)'))[2] = 'BC' THEN -(regexp_match(born, '([0-9]+) (AC|BC)'))[1]::int
        ELSE NULL
    END AS born,
    died,
    age,
    alive,
    booklist
FROM
    pov_characters
ORDER BY
    alive DESC, age DESC;