#!/usr/bin/perl

# perl scripts/build.pl

use strict;
use warnings;
use File::Find;
use File::Slurp;
use HTML::Entities;

# Initialize variables to store book details
my %books;
my %authors;
my %genres;
my %bookshelves;

# Read files from the books directory
find(\&read_book, "./books");

# Clear output directory
system("rm -rf ./output/*");

# Create output directory if not exists
mkdir "./output" unless -d "./output";

# Create genre directory if not exists
mkdir "./output/genre" unless -d "./output/genre";

# Create author directory if not exists
mkdir "./output/author" unless -d "./output/author";

# Create bookshelves directory if not exists
mkdir "./output/bookshelves" unless -d "./output/bookshelves";

# Create individual book pages
for my $file (keys %books) {
    my $content = read_file("./books/$file");
    write_file("./output/$file", $content);
}

# Create author pages
for my $author (keys %authors) {
    my $filename = $author;
    $filename =~ s/\s/_/g;
    $filename = "./output/author/$filename.html";
    # Create a list of books by the author with links
    # my $content = join("<br>", @{$authors{$author}});
    my $content = "<ul>";
    foreach my $file (@{$authors{$author}}) {
        $content .= sprintf("<li><a href='%s'>%s</a></li>", $file, $file);
    }
    $content .= "</ul>";
    write_file($filename, $content);
}

# Create genre pages
for my $genre (keys %genres) {
    my $filename = $genre;
    $filename =~ s/\s/_/g;
    $filename = "./output/genre/$filename.html";
    # my $content = join("<br>", @{$genres{$genre}});
    # Create a list of books by the genre with links
    my $content = "<ul>";
    foreach my $file (@{$genres{$genre}}) {
        # Constructing the list item
        $content .= render_book_list_item($books{$file}, $file);
    }
    $content .= "</ul>";
    write_file($filename, $content);
}

# Create genre index page
my $genre_index_content = "<ul>";
foreach my $genre (sort keys %genres) {
    my $filename = $genre;
    $filename =~ s/\s/_/g;
    $filename = "genre/$filename.html";
    # get book count for the genre
    my $book_count = scalar @{$genres{$genre}};

    $genre_index_content .= sprintf("<li><a href='%s'>%s</a> (%s)</li>",
                                    $filename,
                                    $genre,
                                    $book_count);
}
$genre_index_content .= "</ul>";
write_file("./output/genres.html", $genre_index_content);

# Create bookshelves pages
for my $bookshelf (keys %bookshelves) {
    my $filename = $bookshelf;
    $filename =~ s/\s/_/g;
    $filename = "./output/bookshelves/$filename.html";
    # Create a list of books by the bookshelf with links, sorted by date
    my $content = "<ul>";
    # foreach my $file (@{$bookshelves{$bookshelf}}) {
    foreach my $file (sort { $books{$a}->{date} cmp $books{$b}->{date} } @{$bookshelves{$bookshelf}}) {
        # Constructing the list item
        $content .= render_book_list_item($books{$file}, $file);
    }
    $content .= "</ul>";
    write_file($filename, $content);
}

# Create bookshelves index page
my $bookshelves_index_content = "<ul>";
foreach my $bookshelf (sort keys %bookshelves) {
    my $filename = $bookshelf;
    $filename =~ s/\s/_/g;
    $filename = "bookshelves/$filename.html";
    # get book count for the bookshelf
    my $book_count = scalar @{$bookshelves{$bookshelf}};

    $bookshelves_index_content .= sprintf("<li><a href='%s'>%s</a> (%s)</li>",
                                    $filename,
                                    $bookshelf,
                                    $book_count);
}
$bookshelves_index_content .= "</ul>";
write_file("./output/bookshelves.html", $bookshelves_index_content);

# Create a sorted books page with links and data-genres attribute
my $sorted_content = "<ul>";
foreach my $file (sort { $books{$a}->{date} cmp $books{$b}->{date} } keys %books) {
    $sorted_content .= render_book_list_item($books{$file}, $file);
}
$sorted_content .= "</ul>";
write_file("./output/sorted_books.html", $sorted_content);

# Create an index page to links to sorted, genre, author, and bookshelves pages
my $index_content = "<ul>";
$index_content .= "<li><a href='sorted_books.html'>Sorted Books</a></li>";
$index_content .= "<li><a href='genres.html'>Genres</a></li>";
$index_content .= "<li><a href='bookshelves.html'>Bookshelves</a></li>";
$index_content .= "<li><a href='author.html'>Authors</a></li>";
$index_content .= "</ul>";
write_file("./output/index.html", $index_content);

# Function to read and extract book data
sub read_book {
    my $filename = $_;

    return unless -f $filename;
    return unless $filename =~ /\.html$/;

    my $content = read_file($filename);
    my (
        $date,
        $name,
        @authors,
        @genres,
        @bookshelves,
        $pages
        ) = ('N/A', 'N/A');

    # Extract book properties
    if ($content =~ /<dd property="name">([^<]+)<\/dd>/) {
        $name = decode_entities($1);
    }

    if ($content =~ /<dd property="datePublished">([^<]+)<\/dd>/) {
        $date = decode_entities($1);
    }
    while ($content =~ /<dd property="author">([^<]+)<\/dd>/g) {
        push @authors, decode_entities($1);
    }
    while ($content =~ /<dd property="bookshelf">([^<]+)<\/dd>/g) {
        push @bookshelves, decode_entities($1);
    }
    # if no bookshelves, add 'Uncategorized'
    if (scalar @bookshelves == 0) {
        push @bookshelves, 'Uncategorized';
    }
    while ($content =~ /<dd property="genre">([^<]+)<\/dd>/g) {
        push @genres, decode_entities($1);
    }

    if ($content =~ /<dd property="numberOfPages">([^<]+)<\/dd>/) {
        $pages = decode_entities($1);
    }


    # Store book details
    $books{$filename} = {
        date => $date,
        name => $name,
        authors => \@authors,
        genres => \@genres,
        bookshelves => \@bookshelves,
        pages => $pages
        };

    # Store author and genre details
    for my $author (@authors) {
        push @{$authors{$author}}, $filename;
    }
    for my $genre (@genres) {
        push @{$genres{$genre}}, $filename;
    }
    for my $bookshelf (@bookshelves) {
        push @{$bookshelves{$bookshelf}}, $filename;
    }
}

# Example usage:
# Assuming you have a %books hash with book data
# foreach my $file (keys %books) {
#     $content .= render_book_list_item($books{$file}, $file);
# }
sub render_book_list_item {
    # TODO: pass in relative link to book page
    my ($book_info, $file) = @_;

    # Extract book data
    my $date = $book_info->{date} // 'N/A';
    my $name = $book_info->{name} // 'N/A';
    my $pages = $book_info->{pages} // 'N/A';
    my $genres = $book_info->{genres} // [];

    # Constructing author links and names
    my @author_links;
    foreach my $author_name (@{$book_info->{authors}}) {
        my $author_display;

        # Check if the author has more than one book
        if (scalar @{$authors{$author_name}} > 1) {
            my $author_filename = $author_name;
            $author_filename =~ s/\s/_/g;  # Replace spaces with underscores for the filename
            $author_display = sprintf("<a href='author_%s.html'>%s</a>",
                                    encode_entities($author_filename),
                                    encode_entities($author_name));
        } else {
            $author_display = encode_entities($author_name);
        }

        push @author_links, $author_display;
    }
    my $authors_str = join(", ", @author_links);

    my $genres_attr = join(", ", @{$book_info->{genres}});

    my $bookshelves = $book_info->{bookshelves} // [];

    # Constructing the list item
    return sprintf("<li>%s <a href='%s' data-genres='%s' data-bookshelves='%s'>%s</a> by %s (%s pages)</li>",
                   encode_entities($date),
                   encode_entities($file),
                   encode_entities($genres_attr),
                   encode_entities(join(", ", @{$book_info->{bookshelves}})),
                   encode_entities($name),
                   $authors_str,
                   encode_entities($pages));
}

1;
