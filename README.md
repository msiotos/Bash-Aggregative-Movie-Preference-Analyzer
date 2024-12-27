# Bash-Aggregative-Movie-Preference-Analyzer

This project provides a command-line interface (CLI) for analyzing a large movie ratings dataset, which includes:

~10 million ratings
~100,000 tags
~10,000 movies rated by ~72,000 users

Features

The CLI supports the following commands:

rating T1 T2

Lists all movies with an average rating greater than T1 and up to T2.

Example: rating 3 3.5

top_movies K

Shows the K highest-rated movies.

Example: top_movies 5

dominance

Lists movies that are not dominated by others based on average rating and number of reviews.

iceberg K T

Retrieves movies that have at least K reviews and average rating above T.

Example: iceberg 100 4

top_user K

Finds the K users who have rated the most movies.

Example: top_user 5


