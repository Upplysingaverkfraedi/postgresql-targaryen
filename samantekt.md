# Game of Thrones með PostgreSQL

## Hluti 1: Ættir og landsvæði í Norður konungsríkinu

Það má sjá ítarlegri lýsingu inni á lidur1.sql, þar sem farið er betur yfir hvert skref fyrir sig. En hér má sjá stutta samantekt á hvað kóðinn er að gera og hvaða tilgangi hann gegnir. 

### 1. Liður 
#### Hvað er gert?
-	Fyrsta fyrirspurnin tengir saman hús úr töflunni got.houses við konungsríki úr töflunni atlas.kingdoms. 
-	Ef samsvörun finnst, er hún sett í töfluna targaryen.tables_mapping þar sem tengingin milli húss og konungsríkis er skráð (með house_id og kingdom_id). 
#### Hvernig gerum við þetta? 
-	Þetta gerum við með INSERT INTO ... ON CONFLICT, þar sem gögnin eru sett inn í töfluna og ef villa kemur upp, þá er tilraun gerð til að uppfæra gögnin með ON CONFLICT. 
### 2. Liður: Finna samsvörun á milli staða og húsa 

#### Hvað er gert? 
-	Með CTE (Common Table Expressions) er reynt að finna samsvörun á milli húsa úr got.houses og staða úr atlas.locations. Markmiðið er að finna nákvæma vörpun þar sem hvert hús er tengt einum stað.
-	Ef húsið inniheldur "of" í nafninu (t.d. "House of Harrenhall"), þá er orðið á eftir "of" notað til að finna samsvarandi stað. Ef það er ekki "of", þá er síðasta orðið í nafni hússins notað (t.d. "House Blackmont").
-	Ef fleiri en eitt hús mappast á sama stað, þá er textinn í dálknum location.summary notaður og húsið er valið eftir því hvort það kemur fram í lýsingunni á staðnum.
#### Hvernig er það gert? 
-	Fyrst er samsvörun fundin með því að bera saman húsa- og locationa nöfn. Síðan er ROW_NUMBER() notað til að forgangsraða húsi eftir því hvort það kemur fram í lýsingu staðarins. Fyrsta húsið (með hæstu röðun) er valið og sett í töfluna targaryen.tables_mapping.

## 3. Liður: Finna stærstu ættir norðanmanna
#### Hvað er gert? 
-	Fyrst er fundið hvaða hús eru í Norðrinu með því að velja þau hús sem eru með svæði "The North" í dálknum region. Þá er unnið með sworn_members (hliðhollir meðlimir) með því að sundurliða þá með unnest().
-	Meðlimir þessara húsa eru síðan tengdir við töfluna got.characters til að fá nöfn persónanna. Ættarnafnið er síðan fundið með því að taka síðasta orðið úr nafni persónunnar.
-	Að lokum er fjöldi meðlima í hverri ætt talinn, og ættir sem hafa fleiri en 5 hliðholla meðlimi eru valdar. Úttakið er raðað eftir fjölda meðlima og stafrófsröð.
#### Hvernig er það gert? 
-	Fyrst er unnest() notað til að sundurliða sworn_members lista. Síðan er nafnið á hverjum meðlim tengt við got.characers, og ættarnafnið er fundið með split_part(). Loks er fjöldi meðlima talinn með GROUP BY, og aðeins ættir með fleiri en 5 meðlimi eru valdar með HAVING COUNT(*) > 5. 

## Hluti 2: Aðalpersónur í Krúnuleikum

Kóðann er að finna í lidur2.sql og hægt að copy pastea  inn í datagrip. Mögulega virkar bara að keyra frá ** WITH pov_characters AS **

Þessi kóði fjarlægir eldri útgáfu af v_pov_characters_human_readable (DROP VIEW IF EXISTS) og býr til nýtt view með sama nafni.

**pov_characters:**Velur grunnupplýsingar um pov persónur.

**character_details : **Tengir nöfn foreldra og maka, býr til full nafn og einfaldar kyn (M/F).

**character_years: ** Dregur út fæðingar- og dánarár úr texta og umbreytir AC/BC í heiltölur.

**character_age: **  Reiknar aldur ef upplýsingar um fæðingu og dánarár eru til staðar og athugar hvort persónan sé á lífi.

**books_list: ** Sækir lista af bókum sem hver persóna birtist í.

**books_aggregated: ** Hópar bækurnar saman í lista fyrir hverja persónu.

Í lokin er SELECT notað til að taka saman allar upplýsingar fyrir hverja persónu; nafn, kyn, foreldra, maka, fæðingar- og dánarár, aldur, alive stöðu og lista yfir bækur. 


## Hluti 3: PostGIS og föll í PostgreSQL


**Spurning 1**

*CREATE OR REPLACE FUNCTION targaryen.get_kingdom_size(kingdom_id INT)*
*RETURNS NUMERIC AS $$*
*DECLARE area_km2 NUMERIC;*
*BEGIN*

Fallið *get_kingdom_size* er búið til eða endurskrifað í targaryen schema.
Það tekur eitt inntak *kingdom_id* sem er heiltala (INT) og skilar gildi af gerð NUMERIC. 

*area_km2* er breyta af gerð NUMERIC sem verður notuð til að geyma flatarmál konungsríkjanna. 

**Tryggja að kingdom id sé til/gilt**
*IF NOT EXISTS (SELECT 1 FROM atlas.kingdoms WHERE gid = kingdom_id) THEN*
*RAISE EXCEPTION 'Invalid kingdom_id: %', kingdom_id;*
*END IF;*

Ef *kingdom_id* er ekki til í töflunni *atlas.kingdoms*, þá fer kóðinn í gegnum IF NOT EXISTS aðgerðina.
Ef svo er, kastar kóðinn villu með tilkynningu um að *kingdom_id* sé ógilt.


**Reikna stærðina af konungsríkjunum**
*SELECT ST_Area(geog) / 1000000 -- Umbreyta úr m² í km²*
*INTO area_km2*
*FROM atlas.kingdoms*
*WHERE gid = kingdom_id;*
*RETURN TRUNC(area_km2);*
*END;*
*$$ LANGUAGE plpgsql;*

Nota *ST_Area(geog)* til að reikna flatarmál konungsríkjanna úr geog (geografíu) og deilir því með 1,000,000 til að breyta úr fermetrum í ferkílómetra.
RETURN TRUNC(area_km2); skilar flatarmálinu en notar TRUNC til að fjarlægja aukastafi í niðurstöðunni. 

**Raða konungsríkjunum eftir stærðum (CTE)**
*WITH RankedKingdoms AS (*
*SELECT gid AS kingdom_id, name, targaryen.get_kingdom_size(gid) AS area_km2,*
*RANK() OVER (ORDER BY targaryen.get_kingdom_size(gid) DESC) AS rank*
*FROM atlas.kingdoms)*

RankedKingdoms býr til tímabundna töflu sem inniheldur *kingdom_id*, nafn konungsríkjanna, flatarmál þess með því að kalla á *get_kingdom_size*, og rank eftir flatarmáli í fallandi röð. 

*SELECT name AS kingdom_name, area_km2*
*FROM RankedKingdoms*
*WHERE rank = 3;*

Þessi seinni partur sækir kingdom_name og area_km2 úr RankedKingdoms CTE þar sem rank er 3 (þ.e. þriðja stærsta konungsdæmið).


**Spurning 2** 

CREATE TABLE if not exists targaryen.locations_not_in_kingdoms AS
SELECT l.*
FROM atlas.locations l
WHERE NOT EXISTS (
SELECT 1
FROM atlas.kingdoms k
WHERE ST_Within(l.geog::geometry, k.geog::geometry));

Þetta býr til nýja töflu *locations_not_in_kingdoms* í targaryen schema ef hún er ekki þegar til.
Fyrirspurnin sækir svo öll gögnin úr *atlas.locations* þar sem þær staðsetningarnar eru ekki innan neins konungsríkis (NOT EXISTS).
ST_Within aðgerðin athugar hvort staðsetningin l.geog sé innan k.geog (konungsríkis).

**CTE fyrir sjaldgæfustu tegund af location type**
*WITH RarestType AS (*
*SELECT type, COUNT(*) AS type_count*
*FROM targaryen.locations_not_in_kingdoms*
*GROUP BY type*
*ORDER BY type_count ASC*
*LIMIT 1)*

RarestType býr til tímabundna töflu sem inniheldur tegundir staðsetninga úr locations_not_in_kingdoms og telur fjölda þeirra.
GROUP BY safnar saman eftir tegund og ORDER BY raðar eftir fjölda í vaxandi röð.
LIMIT 1 skilar aðeins þeirri tegund sem kemur sjaldnast fyrir.

**Skila gögnunum/svörum** 
*SELECT type, array_agg(name) AS names*
*FROM targaryen.locations_not_in_kingdoms*
*WHERE type = (SELECT type FROM RarestType)*
*GROUP BY type;*

Þessi seinni fyrirspurnin sækir type og allar nafngiftir (array_agg(name)) úr locations_not_in_kingdoms þar sem tegundin er sú sama og sú sjaldgæfasta.
GROUP BY type sameinar niðurstöðurnar eftir tegund og svarið kemur í einni línu. 

