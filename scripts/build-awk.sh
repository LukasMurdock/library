#!/bin/zsh

# Define the output directory
outputDir="./output"

# clear output directory
rm -rf "$outputDir"

mkdir -p "$outputDir"
# mkdir -p "$outputDir/authors"
# mkdir -p "$outputDir/genres"

# Initialize associative arrays
typeset -A authorPages
typeset -A genrePages
typeset -A books

# Function to extract property from HTML file
extract_property() {
    # Extract the contents of <dd> tags following the specified property
    ggrep -oP "(?<=<dd property=\"$1\">).*?(?=</dd>)" "$2"
}


# Process each HTML file
for file in ./books/*.html; do
   # Extract properties
    datePublished=$(extract_property "datePublished" "$file")
    numberOfPages=$(extract_property "numberOfPages" "$file")

    # Handle multiple authors
    authors=($(extract_property "author" "$file"))
    authorString=$(printf ", %s" "${authors[@]}")
    authorString=${authorString:2} # remove leading comma and space

    # Handle multiple genres
    genres=($(extract_property "genre" "$file"))
    genreString=$(printf ", %s" "${genres[@]}")
    genreString=${genreString:2} # remove leading comma and space

    echo "Processing $file..."
    echo "Date published: $datePublished"
    echo "Authors: $authorString"
    echo "Number of pages: $numberOfPages"
    echo "Genres: $genreString"

    # Create individual book page
    bookTitle=$(basename "$file" .html)
    cp "$file" "$outputDir/$bookTitle.html"

    # Prepare data for sorted books page
    books["$datePublished"]="$bookTitle::${genreString}"

    # # Author page
    # authorFile="$outputDir/authors/$author.html"
    # echo "<a href=\"../$bookTitle.html\">$bookTitle</a><br>" >> "$authorFile"
    # authorPages[$author]=$authorFile

    # # Genre page
    # genreFile="$outputDir/genres/$genre.html"
    # echo "<a href=\"../$bookTitle.html\">$bookTitle</a><br>" >> "$genreFile"
    # genrePages[$genre]=$genreFile
done

# Create sorted books page
sortedBooksPage="$outputDir/sorted_books.html"
echo "<h1>All books</h1>" > "$sortedBooksPage"
for date in ${(ok)books}; do
    for bookInfo in ${(f)books[$date]}; do
        bookTitle=${bookInfo%%::*}
        bookGenres=${bookInfo#*::}
        echo "<a href=\"$bookTitle.html\" data-genres=\"$bookGenres\">$bookTitle</a><br>" >> "$sortedBooksPage"
    done
done
# for date in ${(ok)books}; do
#     echo "<a href=\"${books[$date]}.html\">${books[$date]}</a><br>" >> "$sortedBooksPage"
# done

# Generate index pages for authors and genres
# for authorPage in ${(kv)authorPages}; do
#     echo "<h1>$authorPage</h1>" > "$authorPages[$authorPage]"
# done
# for genrePage in ${(kv)genrePages}; do
#     echo "<h1>$genrePage</h1>" > "$genrePages[$genrePage]"
# done

echo "Processing complete. Pages created in $outputDir."
