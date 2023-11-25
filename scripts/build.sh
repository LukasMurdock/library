#!/bin/bash

# chmod +x ./scripts/build.sh
# ./scripts/build.sh

# for every .html file in ./books, collect
# property="datePublished"
# property="author"
# property="numberOfPages"
# property="genre"

# Create a page for every book, with the raw html from the book file
# Create a page for every author and genre, with links to all books in that genre or by that author
# Create a page with every book, sorted by date published

#!/bin/bash

# Directory containing the books
BOOKS_DIR="./books"

# Temporary associative arrays for authors and genres
# declare -A authors genres
authors=()
genres=()

# create output directory if it doesn't exist
mkdir -p output/books

# Process each HTML file
for book in "$BOOKS_DIR"/*.html; do
    # Extract properties from the HTML file
    datePublished=$(ggrep -oP 'property="datePublished" content="\K[^"]*' "$book")
    author=$(ggrep -oP 'property="author" content="\K[^"]*' "$book")
    numberOfPages=$(ggrep -oP 'property="numberOfPages" content="\K[^"]*' "$book")
    genre=$(ggrep -oP 'property="genre" content="\K[^"]*' "$book")

    # Create a page for the book with its raw HTML
    cp "$book" "output/books/$(basename "$book")"

    # Update authors and genres associative arrays
    authors["$author"]+="$book "
    genres["$genre"]+="$book "
done

# Create pages for each author
for author in "${!authors[@]}"; do
    echo "Books by $author:"
    # echo "Books by $author:" > "output/authors/$author.html"
    # for book in ${authors[$author]}; do
    #     echo "<a href='../books/$(basename "$book")'>$(basename "$book")</a><br>" >> "output/authors/$author.html"
    # done
done

# # Create pages for each genre
# for genre in "${!genres[@]}"; do
#     echo "Books in $genre genre:" > "output/genres/$genre.html"
#     for book in ${genres[$genre]}; do
#         echo "<a href='../books/$(basename "$book")'>$(basename "$book")</a><br>" >> "output/genres/$genre.html"
#     done
# done

# # Create a page with all books sorted by date
# echo "All books sorted by date:" > "output/sorted_books.html"
# for book in $(ls -1 "$BOOKS_DIR"/*.html | xargs -I {} grep -H 'property="datePublished"' {} | sort -t '"' -k4,4 | cut -d ':' -f1); do
#     echo "<a href='books/$(basename "$book")'>$(basename "$book")</a><br>" >> "output/sorted_books.html"
# done
