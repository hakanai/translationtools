translationtools
================

Tools for or related to software translation

proptool
--------

When you're sending out all the files for a translation:

    proptool split [--locales=de,ja] \
             [--destination-encoding=<encoding>] \
             <srcdir> <destdir>

This will create a directory structure with each locale's files under a directory
for that locale. The root locale's files are put under a directory called "root",
but since this tool matches all .properties files, it is likely to find files you
don't want to translate.

When you're sending out files for a new translation job, you can dump just the files
which have untranslated strings:

    proptool prepare-job --locales=ja,zh_CN \
             [--include=<pathglob> ...] \
             [--exclude=<pathglob> ...] \
             [--destination-encoding=<encoding>] \
             <srcdir> <destdir>

This will create a similar directory structure to `split`, but with each file only
containing the strings which are untranslated.

Include and exclude patterns are file globs matched on the relative path to the top
source directory. If both are specified, an exclusion takes priority over an
inclusion. If no inclusions are specified, everything is included by default.

When files come back from a translator and you're merging them back in:

    proptool merge [--source-encoding=<encoding>] <srcdir> <destdir>

(This is run once per locale, rather than over the whole structure output by split.)

Source encodings are ISO-8859-1 not because I like it but because .properties
files require it.

If you have a bunch of properties files with inconsistent formatting, there is
a tool to clean that up:

    proptool normalise <dir>


Building
--------

```
rake install
```
