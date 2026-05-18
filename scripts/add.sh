#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BOOKS_DIR="$REPO_ROOT/books"
API_URL="${LIBRARY_GOOGLE_BOOKS_API_URL:-https://www.googleapis.com/books/v1/volumes}"
DEFAULT_API_KEY_REF="op://Personal/Books API/credential"
DEFAULT_KEYCHAIN_SERVICE="Google Books API"
DEFAULT_LIMIT=5

query=""
limit="$DEFAULT_LIMIT"
open_editor=true
dry_run=false

usage() {
  cat <<EOF
Search Google Books and add a selected book to the local library.

USAGE
  $SCRIPT_NAME [options]

EXAMPLES
  $SCRIPT_NAME
  $SCRIPT_NAME --query "designing data-intensive applications"
  $SCRIPT_NAME --query "the pragmatic programmer" --no-open

OPTIONS
  -q, --query <text>   Search query. If omitted, you will be prompted.
  -n, --limit <count>  Number of search results to show. Default: $DEFAULT_LIMIT.
  --dry-run           Preview the generated book file without writing it.
  --no-open           Do not open the generated file in VS Code.
  -h, --help          Show this help.

ENVIRONMENT
  GOOGLE_BOOKS_API_KEY          API key for Google Books requests. Overrides secret stores.
  GOOGLE_BOOKS_API_KEY_REF      1Password secret reference. Default: $DEFAULT_API_KEY_REF
  GOOGLE_BOOKS_KEYCHAIN_SERVICE macOS Keychain service. Default: $DEFAULT_KEYCHAIN_SERVICE
  GOOGLE_BOOKS_KEYCHAIN_ACCOUNT macOS Keychain account. Default: current macOS user.
  LIBRARY_GOOGLE_BOOKS_API_URL  Override the API URL for testing.

Docs: https://developers.google.com/books/docs/v1/using
EOF
}

info() {
  printf '%s\n' "$*" >&2
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "$1 is not installed. $2"
  fi
}

load_api_key() {
  local key_ref=${GOOGLE_BOOKS_API_KEY_REF:-$DEFAULT_API_KEY_REF}
  local keychain_service=${GOOGLE_BOOKS_KEYCHAIN_SERVICE:-$DEFAULT_KEYCHAIN_SERVICE}
  local keychain_account=${GOOGLE_BOOKS_KEYCHAIN_ACCOUNT:-${USER:-}}

  if [[ -n "${GOOGLE_BOOKS_API_KEY:-}" ]]; then
    return 0
  fi

  if command -v security >/dev/null 2>&1; then
    if [[ -n "$keychain_account" ]]; then
      if GOOGLE_BOOKS_API_KEY=$(security find-generic-password -a "$keychain_account" -s "$keychain_service" -w 2>/dev/null); then
        export GOOGLE_BOOKS_API_KEY
        return 0
      fi
    elif GOOGLE_BOOKS_API_KEY=$(security find-generic-password -s "$keychain_service" -w 2>/dev/null); then
      export GOOGLE_BOOKS_API_KEY
      return 0
    fi
  fi

  if command -v op >/dev/null 2>&1; then
    if GOOGLE_BOOKS_API_KEY=$(op read "$key_ref" 2>/dev/null); then
      export GOOGLE_BOOKS_API_KEY
      return 0
    fi
  fi
}

prompt() {
  local message=$1
  local value

  printf '%s' "$message" >&2
  if ! IFS= read -r value; then
    die "could not read input"
  fi

  printf '%s' "$value"
}

confirm() {
  local message=$1
  local answer

  while true; do
    answer=$(prompt "$message [y/n]: ")
    case "$answer" in
      [Yy]) return 0 ;;
      [Nn]) return 1 ;;
      *) info "Please answer y or n." ;;
    esac
  done
}

slugify() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

sanitize_filename() {
  local filename=$1

  filename=$(printf '%s' "$filename" | sed -E 's/[^a-zA-Z0-9._-]+/-/g; s/^-+//; s/-+$//')
  [[ -n "$filename" ]] || die "file name cannot be empty"
  [[ "$filename" == *.html ]] || filename="$filename.html"

  case "$filename" in
    .* | */* | *..*) die "file name must be a simple .html file name" ;;
  esac

  printf '%s' "$filename"
}

html_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -q | --query)
        [[ $# -ge 2 ]] || die "$1 requires a search query"
        query=$2
        shift 2
        ;;
      --query=*)
        query=${1#*=}
        shift
        ;;
      -n | --limit)
        [[ $# -ge 2 ]] || die "$1 requires a count"
        limit=$2
        shift 2
        ;;
      --limit=*)
        limit=${1#*=}
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --no-open)
        open_editor=false
        shift
        ;;
      *)
        die "unknown option: $1. Run $SCRIPT_NAME --help for usage."
        ;;
    esac
  done
}

fetch_books() {
  local query_text=$1
  local response_file=$2
  local http_code
  local curl_args

  curl_args=(
    -sS
    --get "$API_URL"
    --data-urlencode "q=$query_text"
    --data-urlencode "maxResults=$limit"
  )

  if [[ -n "${GOOGLE_BOOKS_API_KEY:-}" ]]; then
    curl_args+=(--data-urlencode "key=$GOOGLE_BOOKS_API_KEY")
  fi

  http_code=$(curl "${curl_args[@]}" \
    -w '%{http_code}' \
    -o "$response_file") || die "Google Books request failed"

  if [[ "$http_code" == "429" ]]; then
    die "Google Books rate limit exceeded. Try again later or set GOOGLE_BOOKS_API_KEY."
  fi

  [[ "$http_code" == "200" ]] || die "Google Books returned HTTP $http_code"
  jq -e . "$response_file" >/dev/null || die "Google Books returned invalid JSON"
}

print_result() {
  local response_file=$1
  local index=$2
  local title authors year

  title=$(jq -r ".items[$index].volumeInfo.title // \"Unknown Title\"" "$response_file")
  authors=$(jq -r ".items[$index].volumeInfo.authors // [] | join(\", \")" "$response_file")
  year=$(jq -r ".items[$index].volumeInfo.publishedDate // \"Unknown\"" "$response_file" | cut -c 1-4)

  [[ -n "$authors" ]] || authors="Unknown Author"
  [[ -n "$year" ]] || year="Unknown"

  printf '%s. %s by %s (%s)\n' "$((index + 1))" "$title" "$authors" "$year"
}

write_book_file() {
  local response_file=$1
  local selected_index=$2
  local output_file=$3
  local title published_date page_count

  title=$(jq -r ".items[$selected_index].volumeInfo.title // \"Unknown Title\"" "$response_file")
  published_date=$(jq -r ".items[$selected_index].volumeInfo.publishedDate // \"\"" "$response_file")
  page_count=$(jq -r ".items[$selected_index].volumeInfo.pageCount // \"\"" "$response_file")

  {
    printf '<dl vocab="https://schema.org/" typeof="Book">\n'
    printf '<dt>Name</dt>\n'
    printf '<dd property="name">%s</dd>\n' "$(html_escape "$title")"
    printf '<dt>Author</dt>\n'
    jq -r ".items[$selected_index].volumeInfo.authors // [] | .[]" "$response_file" |
      while IFS= read -r author; do
        printf '<dd property="author">%s</dd>\n' "$(html_escape "$author")"
      done
    printf '<dt>Pages</dt>\n'
    printf '<dd property="numberOfPages">%s</dd>\n' "$(html_escape "$page_count")"
    printf '<dt>Date Published</dt>\n'
    printf '<dd property="datePublished">%s</dd>\n' "$(html_escape "$published_date")"
    printf '<dt>Bookshelves</dt>\n'
    printf '<dd property="bookshelf">Uncategorized</dd>\n'
    printf '<dt>Genres</dt>\n'
    jq -r ".items[$selected_index].volumeInfo.categories // [] | .[]" "$response_file" |
      while IFS= read -r category; do
        printf '<dd property="genre">%s</dd>\n' "$(html_escape "$category")"
      done
    printf '</dl>\n'
  } >"$output_file"
}

parse_args "$@"

[[ "$limit" =~ ^[1-9][0-9]*$ ]] || die "--limit must be a positive integer"
[[ "$limit" -le 40 ]] || die "--limit must be 40 or less"

need_command jq "Install jq from https://jqlang.github.io/jq/."
need_command curl "Install curl from https://curl.se/."
[[ -d "$BOOKS_DIR" ]] || die "books directory not found: $BOOKS_DIR"
load_api_key

if [[ -z "$query" ]]; then
  if [[ ! -t 0 ]]; then
    usage >&2
    exit 2
  fi
  query=$(prompt "Search query: ")
fi

[[ -n "$query" ]] || die "search query cannot be empty"

tmp_file=$(mktemp "${TMPDIR:-/tmp}/library-books.XXXXXX.json")
trap 'rm -f "$tmp_file"' EXIT

info "Searching Google Books for \"$query\"..."
fetch_books "$query" "$tmp_file"

total_items=$(jq -r '.totalItems // 0' "$tmp_file")
result_count=$(jq -r '.items | length // 0' "$tmp_file")

if [[ "$total_items" -eq 0 || "$result_count" -eq 0 ]]; then
  die "no books found for \"$query\". Try different keywords or check spelling."
fi

if [[ "$result_count" -lt "$limit" ]]; then
  limit=$result_count
fi

info "Found $total_items results. Showing $limit."
info "---"

for ((i = 0; i < limit; i++)); do
  print_result "$tmp_file" "$i" >&2
done

info "---"
choice=$(prompt "Select a book [1-$limit] or q to quit: ")

if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
  info "Search cancelled."
  exit 0
fi

if ! [[ "$choice" =~ ^[1-9][0-9]*$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$limit" ]]; then
  die "invalid selection: $choice"
fi

selected_index=$((choice - 1))
title=$(jq -r ".items[$selected_index].volumeInfo.title // \"Unknown Title\"" "$tmp_file")
authors=$(jq -r ".items[$selected_index].volumeInfo.authors // [] | join(\", \")" "$tmp_file")
published_date=$(jq -r ".items[$selected_index].volumeInfo.publishedDate // \"\"" "$tmp_file")
page_count=$(jq -r ".items[$selected_index].volumeInfo.pageCount // \"\"" "$tmp_file")
categories=$(jq -r ".items[$selected_index].volumeInfo.categories // [] | join(\", \")" "$tmp_file")

[[ -n "$authors" ]] || authors="Unknown Author"
[[ -n "$page_count" ]] || page_count="Unknown"
[[ -n "$categories" ]] || categories="Uncategorized"

info "---"
info "Title: $title"
info "Author(s): $authors"
info "Published Date: ${published_date:-Unknown}"
info "Page Count: $page_count"
info "Categories: $categories"
info "---"

if ! confirm "Add this book to the library?"; then
  info "Book not added. Refine your search and try again."
  exit 0
fi

first_author=$(jq -r ".items[$selected_index].volumeInfo.authors // [] | .[0] // \"unknown-author\"" "$tmp_file")
year=$(printf '%s' "$published_date" | sed -E 's/[^0-9]//g' | cut -c 1-4)
[[ -n "$year" ]] || year="unknown-year"

author_slug=$(slugify "$first_author")
title_slug=$(slugify "$title")
[[ -n "$author_slug" ]] || author_slug="unknown-author"
[[ -n "$title_slug" ]] || title_slug="unknown-title"

book_file_name=$(sanitize_filename "$year-$author_slug-$title_slug.html")

info "---"
info "Suggested file name: $book_file_name"
if ! confirm "Use this file name?"; then
  book_file_name=$(sanitize_filename "$(prompt "File name: ")")
fi

book_path="$BOOKS_DIR/$book_file_name"

if [[ -e "$book_path" ]]; then
  if ! confirm "Book file already exists. Overwrite $book_file_name?"; then
    book_file_name=$(sanitize_filename "$(prompt "New file name: ")")
    book_path="$BOOKS_DIR/$book_file_name"
    [[ ! -e "$book_path" ]] || die "file already exists: $book_file_name"
  fi
fi

if [[ "$dry_run" == true ]]; then
  preview_file=$(mktemp "${TMPDIR:-/tmp}/library-book-preview.XXXXXX.html")
  trap 'rm -f "$tmp_file" "$preview_file"' EXIT
  write_book_file "$tmp_file" "$selected_index" "$preview_file"
  info "---"
  info "Dry run. Would write: $book_path"
  cat "$preview_file"
  exit 0
fi

write_book_file "$tmp_file" "$selected_index" "$book_path"
info "Book added: $book_path"

if [[ "$open_editor" == true ]]; then
  if command -v code >/dev/null 2>&1; then
    code "$book_path"
  else
    info "VS Code command not found. Open the file manually to edit it."
  fi
fi
