#!/bin/bash

# chmod +x ./scripts/q-g-api.sh
# ./scripts/q-g-api.sh

# check if jq is installed
if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed. Please install jq (https://jqlang.github.io/jq/).' >&2
  exit 1
fi

# ask user for search query
echo "Enter search query (spaces will be replaced with +, no special characters):"
read query

# replace spaces with + for url
query=${query// /+}

# remove special characters (except +)
query=$(echo $query | sed 's/[^a-zA-Z0-9+]//g')

echo "---"

echo "Searching for https://www.googleapis.com/books/v1/volumes?q=$query..."

# create tmp directory if it doesn't exist
mkdir -p tmp

# save json response to tmp file with query name as filename
curl -s "https://www.googleapis.com/books/v1/volumes?q=$query" > tmp/q-g-api.json

# check if API returned any results
totalItems=$(jq -r '.totalItems' tmp/q-g-api.json)
if [[ "$totalItems" == "0" ]] || [[ "$totalItems" == "null" ]]; then
    echo "No books found for query: $query"
    echo "Try different keywords or check spelling."
    exit 1
fi

# show multiple results (up to 5)
echo "Found $totalItems results. Select a book:"
echo "---"

maxResults=5
if [[ $totalItems -lt $maxResults ]]; then
    maxResults=$totalItems
fi

for ((i=0; i<$maxResults; i++)); do
    resultTitle=$(jq -r ".items[$i].volumeInfo.title // \"Unknown Title\"" tmp/q-g-api.json)
    resultAuthors=$(jq -r ".items[$i].volumeInfo.authors[]?" tmp/q-g-api.json | tr '\n' ', ' | sed 's/,$//')
    resultYear=$(jq -r ".items[$i].volumeInfo.publishedDate // \"Unknown\"" tmp/q-g-api.json | cut -c 1-4)
    
    if [[ -z "$resultAuthors" ]]; then
        resultAuthors="Unknown Author"
    fi
    
    echo "$((i+1)). $resultTitle by $resultAuthors ($resultYear)"
done

echo "---"
echo "Enter number (1-$maxResults) or 'q' to quit:"
read choice

# validate choice
if [[ "$choice" == "q" ]]; then
    echo "Search cancelled."
    exit 0
fi

if ! [[ "$choice" =~ ^[1-9][0-9]*$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt $maxResults ]]; then
    echo "Invalid selection. Please run the script again."
    exit 1
fi

# get selected book data (convert to 0-based index)
selectedIndex=$((choice-1))
publishedDate=$(jq -r ".items[$selectedIndex].volumeInfo.publishedDate" tmp/q-g-api.json)
IFS=$'\n' read -r -d '' -a authors < <(jq -r ".items[$selectedIndex].volumeInfo.authors[]?" tmp/q-g-api.json)
title=$(jq -r ".items[$selectedIndex].volumeInfo.title" tmp/q-g-api.json)
subtitle=$(jq ".items[$selectedIndex].volumeInfo.subtitle" tmp/q-g-api.json)
pageCount=$(jq ".items[$selectedIndex].volumeInfo.pageCount" tmp/q-g-api.json)
IFS=$'\n' read -r -d '' -a categories < <(jq -r ".items[$selectedIndex].volumeInfo.categories[]?" tmp/q-g-api.json)

echo "---"

echo "Title: $title"
echo "Subtitle: $subtitle"
echo "Author(s): ${authors[*]}"
echo "Published Date: $publishedDate"
echo "Page Count: $pageCount"
echo "Categories: ${categories[*]}"

echo "---"

# ask user if the book is correct
echo "Is this the correct book? (y/n)"
read correct

# if the book is correct, add it to the library
if [ "$correct" == "y" ]; then
    echo "Adding book to library..."
    # slugify title and author, makes spaces -, removes special characters, and makes lowercase
    firstAuthor="${authors[0]}"
    authorSlug=$(echo $firstAuthor | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g' | tr '[:upper:]' '[:lower:]')
    titleSlug=$(echo $title | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g' | tr '[:upper:]' '[:lower:]')
    year=$(echo $publishedDate | sed 's/[^0-9]//g' | cut -c 1-4)
    bookFileName="$year-$authorSlug-$titleSlug.html"

    # check if book file already exists
    if [ -f books/$bookFileName ]; then
        echo "---"
        echo "Book already exists in library with file name $bookFileName."
        echo "Would you like to overwrite this file? (y/n)"
        read overwrite
        # if user doesn't want to overwrite, prompt for new file name
        if [ "$overwrite" == "n" ]; then
          echo "Enter file name (no spaces, no special characters):"
          read bookFileName
        else
          # delete existing book file
          rm books/$bookFileName
        fi
    fi

    # prompt for book file name
    echo "---"
    echo $bookFileName
    echo "Would you like to use this file name? (y/n)"
    read useFileName

    if [ "$useFileName" == "n" ]; then
      echo "Enter file name (no spaces, no special characters):"
      read bookFileName
    fi

    # create book file
    touch books/$bookFileName

    # write book info to book file in html

    echo "<dl vocab=\"https://schema.org/\" typeof=\"Book\">" >> books/$bookFileName

    echo "<dt>Name</dt>" >> books/$bookFileName
    echo "<dd property=\"name\">$title</dd>" >> books/$bookFileName
    echo "<dt>Author</dt>" >> books/$bookFileName
    for author in "${authors[@]}"; do
        echo "<dd property=\"author\">$author</dd>" >> "books/$bookFileName"
    done
    echo "<dt>Pages</dt>" >> books/$bookFileName
    echo "<dd property=\"numberOfPages\">$pageCount</dd>" >> books/$bookFileName
    echo "<dt>Date Published</dt>" >> books/$bookFileName
    echo "<dd property=\"datePublished\">$publishedDate</dd>" >> books/$bookFileName
    echo "<dt>Bookshelves</dt>" >> books/$bookFileName
    echo "<dd property=\"bookshelf\">Uncategorized</dd>" >> books/$bookFileName
    echo "<dt>Genres</dt>" >> books/$bookFileName
    for category in "${categories[@]}"; do
        echo "<dd property=\"genre\">$category</dd>" >> "books/$bookFileName"
    done
    echo "</dl>" >> books/$bookFileName

    echo "Book added to library!"

    # open book file in editor
    code books/$bookFileName
else
  echo "Book not added to library. Please refine your search."
fi
