# Total number of users
SELECT COUNT(*)
FROM Profiles;

SET @allprofiles = (SELECT COUNT(*) FROM Profiles);
# 25784

SELECT @allprofiles;

# Break down the user by sex
SELECT Sex,COUNT(*)
FROM Profiles
GROUP BY Sex;

# Female	12311
# Male	8975
# NULL	4498


# Instead of counting all users, lets focus only on users
# that have listed books they like in their profiles
SELECT P.Sex, COUNT(DISTINCT B.ProfileID) AS num_profiles
FROM FavoriteBooks B JOIN Profiles P ON P.ProfileID = B.ProfileID
GROUP BY P.Sex;

# 	643
# Female	8753
# Male	5974

SET @males = (SELECT COUNT(DISTINCT B.ProfileID) FROM FavoriteBooks B JOIN Profiles P ON P.ProfileID = B.ProfileID AND P.Sex='Male');
SET @females = (SELECT COUNT(DISTINCT B.ProfileID) FROM FavoriteBooks B JOIN Profiles P ON P.ProfileID = B.ProfileID AND P.Sex='Female');
SET @everyone = (SELECT COUNT(DISTINCT B.ProfileID) FROM FavoriteBooks B JOIN Profiles P ON P.ProfileID = B.ProfileID);


# We will only consider books that are liked by a reasonable number
# of users. We will put the threshold at 10, but we we change it
# We will also save the results in a temporary table.
# We divide with the total number of people that like books
DROP TABLE IF EXISTS popular_books;
CREATE TEMPORARY TABLE popular_books AS 
	SELECT Book, COUNT(*) AS cnt, COUNT(*)/@everyone AS perc
	FROM FavoriteBooks B JOIN Profiles P ON P.ProfileID = B.ProfileID
	GROUP BY Book
    HAVING cnt >= 10
	ORDER BY cnt DESC;
    
SELECT * FROM popular_books;

# We now calculate the number of men / women that like each of the popular books
# It is absolutely crucial here to use a LEFT JOIN so that we can keep
# the list of all popular books, even if no men / no women liked that book.
# 
# *** There are a lot of nuanced things in this join. ***
#
# a. Notice that we have the condition P.Sex = 'Male' in the JOIN condition
#    If we put the condition in the WHERE clause, the WHERE clause is 
#    executed after the LEFT JOIN, and eliminates all the non-matched Books
#
# b. Notice that we do a COUNT of the P.ProfileID. If we do a count of B.ProfileID
#    the results will be completely different (and wrong). That may seem as a 
#    headscratcher, but you need to remember the behavior of LEFT JOINS for 
#    unmatched rows. Try executing the LEFT JOIN without the GROUP BY / aggregations
#    to understand what is going on before the GROUP BY aggregation. Select both
#    the B.ProfileID and the P.ProfileID, which superficially seem to be the same
#    as we have the equality condition P.ProfileID = B.ProfileID in the JOIN clause
#
# c. We use a bit of "smoothing" and add 0.5 to the nominator and 1 to the denominator
#    when we calculation the percentage. That is to avoid zeros, as we
#    will be dividing with perc_men and perc_women in the next query
#
DROP TABLE IF EXISTS book_men ;
CREATE TEMPORARY TABLE book_men AS 
	SELECT B.Book, 
			COUNT(DISTINCT P.ProfileID) AS cnt_men, 
            (COUNT(DISTINCT P.ProfileID)+0.5)/(@males+1) AS perc_men
	FROM  popular_books B
		LEFT JOIN FavoriteBooks F ON B.Book = F.Book
        LEFT JOIN Profiles P ON P.ProfileID = F.ProfileID AND P.Sex = 'Male'
	GROUP BY B.Book
	ORDER BY perc_men DESC;




# We repeat the process for women. Same nuances apply here as in the join just above.
DROP TABLE IF EXISTS book_women;
CREATE TEMPORARY TABLE book_women AS 
	SELECT B.Book, 
			COUNT(DISTINCT P.ProfileID) AS cnt_women, 
            (COUNT(DISTINCT P.ProfileID)+0.5)/(@females+1) AS perc_women
	FROM  popular_books B
		LEFT JOIN FavoriteBooks F ON B.Book = F.Book
        LEFT JOIN Profiles P ON P.ProfileID = F.ProfileID AND P.Sex = 'Female'
	GROUP BY B.Book
	ORDER BY perc_women DESC;




# Once we have our subqueries in place, we join the two tables and calculate the 
# "lift". The lift is defined as the "probability of seeing something in one population" 
# divided by the "probability of seeing something in a contrasting population".
# In this case, we compare percentages (~probabilities) in the populations of men vs women
#
# Notice here that we calculate the lift by dividing with perc_men (or perc_women later)
# hence the need to have a non-zero value for perc_men when creating the book_men table.
# 
# We could have done it with women vs the overall population as well, but the "overall" 
# population includes women as well, so the contrast is not great.
# 
# Alternatively, we could have done women vs rest; and men vs rest. We leave that 
# calculation as an exercise for the interested reader.
SELECT B.Book, B.cnt, B.perc, 
		M.cnt_men, M.perc_men, 
		F.cnt_women, F.perc_women, 
        perc_men /perc_women AS lift_men_vs_women, 
        perc_women / perc_men AS lift_women_vs_men
FROM popular_books B
	LEFT JOIN book_men M ON M.Book = B.Book 
    LEFT JOIN book_women F ON F.Book = B.Book 
ORDER BY lift_women_vs_men DESC, cnt_women DESC;

