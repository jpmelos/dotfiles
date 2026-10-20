---
description: Manage a Plex Media Server library.
disable-model-invocation: true
---

Run all scripts from the media root. The media root is the directory that
contains `library/` and `torrents/`. The mount path varies. Do not hardcode
`/external`. Use relative paths with `ROOT="."`.

Original files can be found in `torrents/`. Media files must be organized
inside `library/`, either inside `library/movies` for movies, or `library/tv`
for TV shows, with symbolic links (relative symbolic links) pointing to the
original files.

If a file in `library/` is not a symbolic link but matches a torrent file, keep
that library file. Treat that torrent file as complete. Do not replace that
library file with a symbolic link.

Movies must be placed inside `library/movies/Movie Name (Year)/` named by the
template `Name (Year).extension`. For example:

```
library/movies/The Lion King (1994)/The Lion King (1994).mp4
```

TV shows must be placed inside `library/tv`, in a directory named by the same
template as movies, and individual episodes must be placed inside a directory
named by the template `Season XX`, and episodes named by the template
`Name (Year) - sXXeYY`. For example:

```
library/tv/Band of Brothers (2001)/Season 01/Band of Brothers (2001) - s01e01.mkv
```

For more information:

- https://support.plex.tv/articles/naming-and-organizing-your-movie-media-files/
- https://support.plex.tv/articles/naming-and-organizing-your-tv-show-files/
