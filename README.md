# Library

## Bookshelves

- 🏆 Favorites
- 📚 To Read
- Reading Now
- 📘 Have Read

## Scripts

### Open Local Library in Browser

```
./scripts/open.sh
```

### Search Google Books API to add book to library

```
./scripts/add.sh
```

`scripts/add.sh` can use a Google Books API key from `GOOGLE_BOOKS_API_KEY`,
macOS Keychain, or 1Password. The explicit environment variable takes
precedence, followed by Keychain, then 1Password.

To store the API key in macOS Keychain:

```
security add-generic-password \
  -a "$USER" \
  -s "Google Books API" \
  -w "your-api-key-here" \
  -U
```

To verify the saved key:

```
security find-generic-password \
  -a "$USER" \
  -s "Google Books API" \
  -w
```

After that, run the script normally:

```
./scripts/add.sh
```

Use `GOOGLE_BOOKS_KEYCHAIN_SERVICE` or `GOOGLE_BOOKS_KEYCHAIN_ACCOUNT` if your
Keychain item uses a different service name or account.

### Build library

```
perl scripts/build.pl
```

### Deploy library

Install project dependencies once:

```
pnpm install
```

Deploy using the locally installed Wrangler:

```
pnpm run deploy
```

Alternatively:

```
./scripts/deploy.sh
```

## Inspirational References

- [Schema.org: Book](https://schema.org/Book)
- [Google Books API](https://developers.google.com/books/docs/v1/getting_started)
