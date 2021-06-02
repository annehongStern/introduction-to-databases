USE facebook;

# Store the number of people that have liked (any) music
SET @allmusicfans = (SELECT COUNT(DISTINCT ProfileID) FROM FavoriteMusic);

# Create a table/view that stores the preferences across all the population
# We store the band and the percentage of people that liked it
DROP TEMPORARY TABLE IF EXISTS MusicPreferences;
CREATE TEMPORARY TABLE MusicPreferences AS
	SELECT Music, 
		ROUND(COUNT(DISTINCT ProfileID)/@allmusicfans,4) AS perc, 
        COUNT(DISTINCT ProfileID) AS cnt
	FROM FavoriteMusic
	GROUP BY Music
	ORDER BY perc DESC;


# Set the band that we are analyzing
SET @band =  'Bon Jovi';

# Store the number of people that like the specific band
SET @bandfans = (SELECT cnt FROM MusicPreferences WHERE Music = @band);


# Create a table with the percentages across only people that like the band 
# that we specified in the variable @band
DROP TEMPORARY TABLE IF EXISTS BandFans;
CREATE TEMPORARY TABLE BandFans AS
	SELECT Music, 
		ROUND(COUNT(DISTINCT ProfileID)/@bandfans,4) AS perc, 
		COUNT(DISTINCT ProfileID) AS cnt
	FROM FavoriteMusic
	WHERE ProfileID  IN (
		SELECT ProfileID 
		FROM FavoriteMusic
		WHERE Music = @band
	)
	GROUP BY Music
	ORDER BY perc DESC;

# The minimum number of fans required, for a band to be analyzed
# To avoid noise, we keep only bands  that have at least 100 
# likes in the overall population.
SET @min_fans = 100;

# Join the two tables above to compare the percentages of likes 
# in the overall population (T.perc) vs the percentage of likes
# across the population of people that like the @band (R.perc)
# We use an OUTER join to keep all the bands from the overall 
# population, even if they do not appear in the likes of the 
# fans of the target artist. 
# We calculate the lift by dividing the two percentages
SELECT T.Music, 
	COALESCE(R.perc,0.0) AS perc_focus, COALESCE(R.cnt,0) AS cnt_focus, 
        T.perc AS perc_total, T.cnt AS cnt_total,
        COALESCE(R.perc/T.perc,0) AS lift_ratio
FROM BandFans R RIGHT JOIN MusicPreferences T ON R.Music = T.Music
WHERE T.cnt>@min_fans AND (R.Music IS NULL OR R.Music != @band)
ORDER BY lift_ratio DESC
