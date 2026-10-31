# Text::Xslate Format

Optional LMS plugin exposing Text::Xslate rendering for MusicArtistInfo.

Requires the Perl module `Text::Xslate`.

Templates use Text::Xslate's Kolon syntax, for example:

```text
<: $directory :>/<: $artist :> - <: $title :>.lrc
```

Fields include `title`, `artist`, `album`, `tracknumber`, `discnumber`,
`year`, `genre`, `path`, `filename`, `directory`, and `url`.
