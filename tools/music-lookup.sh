#!/bin/bash
# music-lookup.sh — Find Apple Music catalog IDs for songs
# Usage: ./tools/music-lookup.sh "Crazy Train" "Ozzy Osbourne"
#        ./tools/music-lookup.sh "Faith" "Ghost"
#        ./tools/music-lookup.sh "Sweet Child O Mine"
#
# Uses the iTunes Search API (no auth required)
# Output: Top results with catalog ID, title, artist, album, duration

TERM="$1"
ARTIST="$2"

if [ -z "$TERM" ]; then
    echo "Usage: $0 \"song title\" [\"artist\"]"
    echo "Example: $0 \"Crazy Train\" \"Ozzy Osbourne\""
    exit 1
fi

SEARCH="$TERM"
if [ -n "$ARTIST" ]; then
    SEARCH="$TERM $ARTIST"
fi

ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SEARCH'))")

RESPONSE=$(curl -s "https://itunes.apple.com/search?term=${ENCODED}&media=music&entity=song&limit=10")

python3 << PYEOF
import json, sys

data = json.loads('''$(echo "$RESPONSE" | sed "s/'''/\\'\\'\\'/" )''')
results = data.get('results', [])

if not results:
    print('No results found.')
    sys.exit(0)

print(f'Results for: "$SEARCH"')
print('─' * 100)
print(f'{"ID":<12} {"Title":<35} {"Artist":<25} {"Album":<30} {"Time"}')
print('─' * 100)

for r in results:
    sid = str(r.get('trackId', '?'))
    title = r.get('trackName', '?')[:34]
    artist = r.get('artistName', '?')[:24]
    album = r.get('collectionName', '?')[:29]
    ms = r.get('trackTimeMillis', 0)
    mins = ms // 60000
    secs = (ms % 60000) // 1000
    print(f'{sid:<12} {title:<35} {artist:<25} {album:<30} {mins}:{secs:02d}')

artist_filter = "$ARTIST"
if artist_filter:
    matches = [r for r in results if artist_filter.lower() in r.get('artistName', '').lower()]
    if matches:
        best = matches[0]
        print()
        print(f'Best match for "{artist_filter}":')
        print(f'  {best["trackName"]} — {best["artistName"]}')
        print(f'  Album: {best.get("collectionName", "?")}')
        print(f'  ID: {best["trackId"]}')
        print()
        print(f'Add to your setlist JSON:')
        print(f'  "appleMusicID": "{best["trackId"]}"')
PYEOF
