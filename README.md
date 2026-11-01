# Text::Xslate Format

Optional LMS plugin exposing Text::Xslate rendering for MusicArtistInfo.

Requires the Perl module `Text::Xslate`.

Templates use Text::Xslate's Kolon syntax, for example:

```text
<: $directory :>/<: $artist :> - <: $title :>.lrc
```

Fields include `title`, `artist`, `album`, `tracknumber`, `discnumber`,
`year`, `genre`, `path`, `filename`, `directory`, and `url`.  Every database
column and every tag found in the file is exposed as an additional field, so
`bitrate`, `bpm`, `musicbrainz_id` or a custom `mood` tag work as well.
`origartist` is provided when the track carries an original-artist tag.

## Template functions

`functions.pl` defines the template functions: 56 short, unprefixed helpers in
the spirit of foobar2000 title formatting.  If a function name would be
ambiguous next to a Perl built-in, it is spelled out
(`hexadecimal`, `character`, `subtract`, `negate`, ...).

* Numbers and padding: `number`, `pad`, `pad_cut`, `hexadecimal`, `roman`,
  `character`
* Slicing: `prefix`, `suffix`, `substring`, `insert`, `position`,
  `last_position`
* Strings: `len`, `lower`, `upper`, `title_case`, `trim`, `replace`, `repeat`,
  `abbreviate`, `first_line`
* Selection and comparison: `choose`, `first_value`, `if_greater`, `if_longer`,
  `greater`, `longer`, `compare`, `compare_ignore_case`, `longest`, `shortest`
* Arithmetic: `sum`, `subtract`, `multiply`, `divide`, `modulo`,
  `multiply_divide`, `min`, `max`
* Logic: `negate`, `all`, `any`, `exactly_one`
* Metadata: `meta`, `has_meta`
* Per-render variables: `set`, `get`
* Paths: `directory`, `filename`, `ext`
* Output helpers: `crlf`, `tab`, `identity`, `color`
* Miscellany: `progress`, `random`

Where two old functions only differed by one option they were merged:

* `pad($value, $width, $char, $align)` and `pad_cut(...)` take an optional
  alignment (`'right'` by default, or `'left'`) instead of separate left/right
  variants.
* `title_case($value, $keep_existing)` lowercases the rest of the text unless
  the second argument is true.
* `set($name, $value, $quiet)` stores a value and returns it, or returns an
  empty string when `$quiet` is true.
* `progress(...)` has a single fill-character default (`'#'`).
* `identity(...)` returns its argument unchanged; `color(...)` returns an
  empty string.  They replace the old no-op foobar2000 visual helpers.

## Editing the function table

`functions.pl` is the one file to edit, and the settings page shows it in the
web UI.  A saved version is stored in the LMS preferences directory as
`textxslate_functions.pl` and is loaded instead of the shipped one.  The file
is an ordinary Perl module:

* write the sub that implements the function,
* list it in `build($fields)`, which returns the table of template functions,
* use the `_text()`, `_integer()` and `_truthy()` helpers to normalise
  arguments.

```perl
sub album {
	my ($value) = @_;
	return _text($value) || 'Unknown';
}

sub build {
	my ( $class, $fields ) = @_;
	return {
		album => \&album,
	};
}
```

The file is loaded once with `require()`, so changes take effect after
restarting LMS.

## Development

The Perl code follows *Perl Best Practices* and is checked with Perl::Critic at
severity 3 (see `.perlcriticrc`).  The test suite uses only the LMS stubs under
`t/lib`, so it runs without an LMS installation:

```sh
perlcritic --quiet API.pm functions.pl Plugin.pm Settings.pm
prove -I t/lib t/
```

`t/tools/generate-oracle.pl` rebuilds the behaviour fixtures in `t/fixtures`
from a pristine `git HEAD` tree; the tests replay those fixtures to prove the
rewrite did not change any observable behaviour.  `t/lib/TXCases.pm` records,
for every renamed or merged function, which old function produces its expected
value.  To regenerate the fixtures:

```sh
rm -rf /tmp/tx-head && mkdir -p /tmp/tx-head/t
git archive HEAD | tar -x -C /tmp/tx-head
cp -a t/lib /tmp/tx-head/t/
perl t/tools/generate-oracle.pl --tree=/tmp/tx-head
```

The suite covers every function over a matrix of arguments, every function end
to end through Text::Xslate, track field extraction, the settings page
round-trip (including UTF-8), a custom function table, a broken custom table
falling back to the shipped one, and the Perl::Critic gate itself.
