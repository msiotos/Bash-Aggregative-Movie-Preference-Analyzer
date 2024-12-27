%%file aggregative_movie_preference_analyzer.sh
#!/bin/bash

#We create an array to store the ratings data from the file given
#We create associative arrays that correspond to the dictionaries we used in python

ratings_data=()
declare -A movie_names
declare -A movie_ratings
declare -A average_ratings
declare -A avg_rating_and_count
declare -A user_ratings

#We read the ratings file using the while loop with the read -r command.
#We set the delimiter IFS = ':' because it can't handle the '::' and add some
#empty spots, so that we have results of the form: userID,movieID,rating,timestamp
#We use OLDIFS="$IFS" and IFS="$OLDIFS" to store and then restore the delimiter
#We used the first 10000 of the entries of our file, after we had shuffled them
#and we append the results to the array ratings_data()
#We also created the associative array user_ratings to use for command 5

function read_ratings(){
    OLDIFS="$IFS"
    IFS=$':'
    while read -r userID empty movieID empty rating empty timestamp
    do
      ratings_data+=("$userID,$movieID,$rating,$timestamp")
      if [[ "${user_ratings[$userID]}" ]]
      then
          user_ratings["$userID"]="${user_ratings[$userID]},$movieID"
      else
          user_ratings["$userID"]="$movieID"
      fi
    done < <(shuf "/content/drive/My Drive/ratings.dat" | head -n 10000)
    IFS="$OLDIFS"
}

#We create this function to link the movieIDs with their titles, again using the
#delimiter and empty spaces between the values we want to store to the associative array

function link_movieID_to_title(){
    OLDIFS="$IFS"
    IFS=$':'
    while read -r movieID empty title empty genres
    do
        movie_names["$movieID"]="$title"
    done < "/content/drive/My Drive/movies.dat"
    IFS="$OLDIFS"
}


#With this function we parse the ratings_data array and by using "," as the delimiter
#we create a new associative array with movieID as key and rating as value.

function link_movieID_to_rating(){
    OLDIFS="$IFS"
    for entry in "${ratings_data[@]}"
    do
      IFS=',' read -r userID movieID rating timestamp <<< "$entry"
      if [[ "${movie_ratings[$movieID]}" ]]
      then
          movie_ratings["$movieID"]="${movie_ratings[$movieID]},$rating"
      else
          movie_ratings["$movieID"]="$rating"
      fi
    done
    IFS="$OLDIFS"
}

#We parse the associative array that contains the movieIDs and ratings
#We get the total ratings for each movie and we transform the ',' that separated
#them with a space. To get the sum we had to transform the space with a '\n'
#because the addition would not work and then we use paste.
#We use the wc -w to get the number of words, in our case the count of ratings
#To get the average we used scale=2 to have 2 decimal places
#We added an extra check, because the average ratings below 1.00 where printing
#like .50 so we transform them to 0.50, etc.
#Finally we create a new associative aray with movieIDs as keys and average
#ratings as values and a new associative arrat with movieIDs as keys and the pair
#of average ratings-ratings count as values, for commands 3 & 4.

function get_avg_ratings(){
    for movieID in "${!movie_ratings[@]}"
    do
        ratings=$(echo "${movie_ratings[$movieID]}" | tr ',' ' ')
        get_sum=$(echo "$ratings" | tr ' ' '\n' | paste -sd+ - | bc)
        get_count=$(echo "$ratings" | wc -w)
        get_avg=$(echo "scale=2; $get_sum / $get_count" | bc)
        if [[ "$get_avg" == .* ]]
        then
            get_avg="0$get_avg"
        fi
        average_ratings["$movieID"]="$get_avg"
        avg_rating_and_count["$movieID"]="$get_avg","$get_count"
    done
}

#We assign the positional parameters $1,$2 to the user input arguments $t1,$t2
#We initialize the number of movies as 0 and then after parsing the associative
#array average_ratings we print the results that are between our boundaries
#We invert the printing order so that we don't have a problem with the space,
#because of the different movie title length

function rating(){

    t1="$1"
    t2="$2"

    echo -e "Μέσο Rating\tΤίτλος Ταινίας"
    echo -e "__________________________________"

    num=0
    for movieID in "${!average_ratings[@]}"
    do
        avg="${average_ratings[$movieID]}"
        if (( $(echo "$avg > $t1" | bc) && $(echo "$avg <= $t2" | bc) ))
        then
            echo -e "$avg\t\t${movie_names[$movieID]}"
            num=1
        fi
    done
    if [ $num -eq 0 ]
    then
        echo "No movies found with average rating between the given values."
    fi
}

#We assign the positional parameter $1 to the user input argument $k
#We parse the associative array average_ratings and we print the results after
#sorting them by descending order and choosing the first k lines.

function top_movies(){

    k="$1"
    if [ $k -eq 0 ]
    then
        echo -e "You chose 0 movies to be printed.\n"
    fi
        echo -e "Μέσο Rating\tΤίτλος Ταινίας"
        echo -e "__________________________________"
        for movieID in "${!average_ratings[@]}"
        do
            echo -e "${average_ratings[$movieID]}\t\t${movie_names[$movieID]}"
        done | sort -r | head -"$k"
}

#We tried to follow the same logic as we did with the python code
#We parse the avg_rating_and_count associative array for the movieID1, we split
#the avg ratings with the count and we do the same for a movieID2. If the two movies
#have the same ID meaning they are the same movies we continue the first loop and
#try a different movieID. Then we do the check for the dominance and print results.

function dominance(){

    echo -e "This takes ~12 minutes..\n"
    echo -e "Μέσο Rating\tΑριθμός κριτικών\tΤίτλος Ταινίας"
    echo -e "________________________________________________________"
    for movieID1 in "${!avg_rating_and_count[@]}"
    do
        dominated=0
        IFS=',' read -r get_avg1 get_count1 <<< "${avg_rating_and_count[$movieID1]}"
        for movieID2 in "${!avg_rating_and_count[@]}"
        do
            IFS=',' read -r get_avg2 get_count2 <<< "${avg_rating_and_count[$movieID2]}"
            if [[ "$movieID1" == "$movieID2" ]]
            then
                continue
            fi
            if (( $(echo "$get_avg1 <= $get_avg2" | bc) && $(echo "$get_count1 <= $get_count2" | bc) ))
            then
                dominated=1
                break
            fi
        done
        if [ $dominated -eq 0 ]
        then
            echo -e "$get_avg1\t\t$get_count1\t\t${movie_names[$movieID1]}"
        fi
    done
}

#Just like the previous function we follow the same procedure, but we only use
#one loop and do the comparisons for the given arguments

function iceberg(){
    k="$1"
    t="$2"
    echo -e "Μέσο Rating\tΑριθμός κριτικών\tΤίτλος Ταινίας"
    echo -e "________________________________________________________"
    num=0
    for movieID in "${!avg_rating_and_count[@]}"
    do
        IFS=',' read -r get_avg get_count <<< "${avg_rating_and_count[$movieID]}"
        if (( $(echo "$get_avg > $t" | bc) && $(echo "$get_count >= $k" | bc) ))
        then
            echo -e "$get_avg\t\t$get_count\t\t${movie_names[$movieID]}"
            num=1
        fi
    done
    if [ $num -eq 0 ]
    then
        echo "No movies found for the given values."
    fi
}

#With one for loop we parse the associative array that contains the userIDs as
#keys and the movieIDs as values. We use -tr to transform the ',' to ' ' and we
#get the count with the wc -w command (word count). Finally we sort by descending
#order and we pick the first $k lines.

function top_user(){
   k="$1"
   if [ $k -eq 0 ]
   then
      echo -e "You chose 0 users to be printed.\n"
   fi
   echo -e "Χρήστης\t\tΑριθμός ταινιών"
   echo -e "___________________________________"
   for userID in "${!user_ratings[@]}"
   do
      movies=$(echo "${user_ratings[$userID]}" | tr ',' ' ')
      get_count=$(echo "$movies}" | wc -w)
      echo -e "$userID\t\t$get_count"
   done | sort -r +1 | head -"$k"

}

#main function

function main() {
    echo "Loading data from files & some necessary functions. Please wait ~1 minute..."
    #We handle the .dat files and call some common functions here so that we don't
    #have to wait later
    read_ratings
    link_movieID_to_rating
    link_movieID_to_title
    get_avg_ratings
    echo "Data loaded successfully! Now showing the menu:"

    while true
    do
      menu
      read -p "Enter your option: " user_input
      IFS=' ' read -a input <<< "$user_input"
      #We split the user input to the command(1st element) and the arguments
      #(rest of the elements minus the 1st by using unset)
      #We get the arguments length so that we can throw errors later if needed
      command="${input[0]}"
      args=("${input[@]}")
      unset args[0]
      args_length=${#args[@]}

      case "$command" in
      "rating")
      if [ $args_length -eq 2 ]
             then
             t1="${args[1]}"
             t2="${args[2]}"
                if ! [[ $t1 =~ ^[+-]?[0-9]+[.]?([0-9]+)?$ && $t2 =~ ^[+-]?[0-9]+[.]?([0-9]+)?$ ]]
                #Regular expressions inspired from lecture 7 - isReal function
                then
                  echo "Invalid value type. Please enter float numbers only. "
                else
                    rating "$t1" "$t2"
                fi
      else
             echo "Please enter 2 arguments for this command. "
      fi
      ;;
      "top_movies")
      if [ $args_length -eq 1 ]
            then
            k="${args[1]}"
              if ! [[ $k =~ ^[+-]?[0-9]+$ ]]
              #Regular expression inspired from lecture 7 - isInt function
              then
                  echo "Invalid value type. Please enter integer number only. "
              else
                    top_movies "$k"
              fi
      else
             echo "Please enter 1 argument for this command. "
      fi
      ;;
      "dominance")
      if [ $args_length -eq 0 ]
                    then
                    dominance
      else
             echo "Please don't enter arguments for this command. "
      fi
      ;;
      "iceberg")
      if [ $args_length -eq 2 ]
        then
             k="${args[1]}"
             t="${args[2]}"
                if ! [[ $k =~ ^[+-]?[0-9]+$ && $t =~ ^[+-]?[0-9]+[.]?([0-9]+)?$ ]]
                #Regular expressions inspired from lecture 7 - isInt + isReal functions
                    then
                    echo "Invalid value types. Please enter an integer and a float number in that order. "
                    else
                    iceberg "$k" "$t"
                    fi
      else
             echo "Please enter 2 arguments for this command. "
      fi
      ;;
      "top_user")
      if [ $args_length -eq 1 ]
            then
            k="${args[1]}"
              if ! [[ $k =~ ^[+-]?[0-9]+$ ]]
              #Regular expression inspired from lecture 7 - isInt function
                  then
                  echo "Invalid value type. Please enter integer number only. "
                else
                  top_user "$k"
                fi
        else
             echo "Please enter 1 argument for this command. "
        fi
      ;;
      "exit")
      echo "Exiting the program."
      exit
      ;;
      #We use this for exit
      *)
      echo -e "\nInvalid option! Try again.\n"
      ;;
      esac

    done
}
menu(){
        echo -e "\n|~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~Aggregative Movie Preference Analyzer~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|"
        echo "|                                                                                                        |"
        echo "|[rating T1 T2]    Print all movies with an average rating greater than T1 and less than or equal to T2  |"
        echo "|[top_movies K]    Print the K number of movies with the highest average rating score                    |"
        echo "|[dominance]       Print the movies that are not dominated by other movies                               |"
        echo "|[iceberg K T]     Print movies with at least K number of reviews and average rating greater than T      |"
        echo "|[top_user K]      Print the K number of users with the highest number of movie ratings                  |"
        echo "|[exit]            Exit the program                                                                      |"
        echo -e "|________________________________________________________________________________________________________|\n"

}
main