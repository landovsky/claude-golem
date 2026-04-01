---
name: freepik
description: Search and download digital assets (images, vectors, icons, videos) from Freepik. Use when the user needs stock photos, vectors, icons, PSD templates, or video clips.
user-invocable: true
argument-hint: [search query]
allowed-tools: Bash, Read, Write
---

# Freepik Asset Procurement

Search and download digital assets from Freepik using their API.

## Authentication

All requests require the header `x-freepik-api-key` with the value from env var `FREEPIK_API_KEY`.

```bash
curl -s -H "x-freepik-api-key: $FREEPIK_API_KEY" ...
```

## Workflow

1. **Clarify needs** — Ask the user what they're looking for if `$ARGUMENTS` is vague. Determine: search terms, asset type (photo, vector, icon, video), quantity, and preferred format.
2. **Search** — Use the appropriate endpoint below.
3. **Present results** — Show thumbnails/previews, titles, IDs, license type (freemium vs premium), and stats.
4. **Download** — Once the user picks assets, download them to the project (default: `assets/` directory, or wherever the user specifies).

## API Endpoints

### 1. Resources (Photos, Vectors, PSD templates)

```
GET https://api.freepik.com/v1/resources
```

**Query parameters:**
| Param | Description |
|-------|-------------|
| `term` | Search query (required). Use `+` for spaces. |
| `limit` | Results per page (default: 10, max varies) |
| `page` | Page number for pagination |
| `order` | Sort order: `latest` or default relevance |

**Response structure:**
```json
{
  "data": [{
    "id": 25668196,
    "title": "Set of animal cartoon character",
    "url": "http://www.freepik.com/free-vector/...",
    "filename": "set-of-animal-cartoon-character.zip",
    "licenses": [{ "type": "freemium"|"premium" }],
    "meta": {
      "available_formats": { "eps": {...}, "jpg": {...} }
    },
    "image": {
      "type": "photo"|"vector"|"psd",
      "orientation": "horizontal"|"vertical"|"square",
      "source": { "url": "...", "size": "626x511" }
    },
    "stats": { "downloads": 2398, "likes": 55 },
    "author": { "name": "brgfx" }
  }],
  "meta": { "current_page": 1, "per_page": 10, "last_page": 100, "total": 1000 }
}
```

**Download a resource:**
```
GET https://api.freepik.com/v1/resources/{id}/download
```
Returns `{ "data": { "filename": "...", "url": "https://..." } }` — use the URL to download the file with curl.

### 2. Icons

```
GET https://api.freepik.com/v1/icons
```

**Query parameters:**
| Param | Description |
|-------|-------------|
| `term` | Search query (required) |
| `limit` | Results per page (default: 100) |
| `page` | Page number |

**Response structure:**
```json
{
  "data": [{
    "id": 1046290,
    "name": "Apple",
    "style": { "name": "Kawaii Lineal color" },
    "family": { "name": "Kawaii Lineal color", "total": 69062 },
    "free_svg": false,
    "thumbnails": [{ "width": 128, "height": 128, "url": "https://cdn-icons-png.freepik.com/128/..." }],
    "tags": [{ "name": "food" }, { "name": "fruit" }]
  }],
  "meta": { "pagination": { "total": 10000, "last_page": 100, "per_page": 100, "current_page": 1 } }
}
```

**Download an icon (PNG):**
```
GET https://api.freepik.com/v1/icons/{id}/download
```
Returns `{ "data": { "filename": "...", "url": "https://cdn-icons-png.freepik.com/512/..." } }`.

Note: SVG download (`?format=svg`) requires a premium plan. PNG is always available.

### 3. Videos

```
GET https://api.freepik.com/v1/videos
```

**Query parameters:**
| Param | Description |
|-------|-------------|
| `term` | Search query (required) |
| `limit` | Results per page |
| `page` | Page number |

**Response structure:**
```json
{
  "data": [{
    "id": 6401552,
    "name": "A Cute Cat Looking Up...",
    "aspect_ratio": "16:9",
    "quality": "1080p",
    "premium": 1,
    "duration": "00:00:13",
    "thumbnails": [{ "url": "...", "width": 460, "height": 264 }],
    "previews": [{ "url": "..." }]
  }]
}
```

## Download Procedure

```bash
# 1. Get the download URL
DOWNLOAD_INFO=$(curl -s -H "x-freepik-api-key: $FREEPIK_API_KEY" "https://api.freepik.com/v1/resources/{id}/download")

# 2. Extract URL and filename
URL=$(echo "$DOWNLOAD_INFO" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['url'])")
FILENAME=$(echo "$DOWNLOAD_INFO" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['filename'])")

# 3. Download the file
curl -sL "$URL" -o "assets/$FILENAME"
```

For icons (PNG direct download):
```bash
curl -sL -H "x-freepik-api-key: $FREEPIK_API_KEY" "https://api.freepik.com/v1/icons/{id}/download" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['url'])" | xargs -I{} curl -sL {} -o "assets/icon_name.png"
```

## Guidelines

- Always show the user search results before downloading so they can pick what they want.
- Note license types: `freemium` assets are free to use with attribution, `premium` requires a paid plan.
- When downloading multiple assets, create a clear directory structure.
- For icons, prefer PNG format (universally available). SVG requires premium access.
- Use `image.source.url` from search results as a quick preview URL to show the user.
