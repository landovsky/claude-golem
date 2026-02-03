# BugSink API Exploration Summary

I successfully explored the BugSink API and tested your hosted instance at https://bugs.kopernici.cz. Here's what I found:

---

### ✅ API Authentication
Bearer token authentication:
```bash
Authorization: Bearer c678e07cd....6cfe2a
```

---

### 📊 Your Instance Overview

**Teams (5 total)**:
1. **Hřiště** - ID: ee4f4572-0957-4346-b433-3c605acbfa2a
2. **Koperníci** - ID: dcc48aab-7429-451f-b856-288076bdc68a
3. **MedicMee** - ID: 2f118a8e-3aa5-4f6f-9886-7a9a91fac697
4. **Pharmacy** - ID: e4a42a51-b16e-453e-8af7-139908ba0b29
5. **Siposervis** - ID: 4dc89d9c-4751-4078-9d3d-205dd0494f2a

**Projects (7 total)** with event counts:
- **Pharmacy**: 2,754,577 total events (9,577 stored due to 10K retention limit)
- **Hřiště sync**: 167,195 total events (9,994 stored)
- **Hřiště backend**: 53,773 events
- **MedicMee PAC**: 7,666 events
- **MedicMee DOC**: 5,532 events
- **Siposervis**: 3,675 events
- **Remai**: 45 events

---

### 🎯 Working Read-Only Endpoints Tested

#### **1. Teams API** ✅
```bash
GET /api/canonical/0/teams/
```
Returns all teams with ID, name, and visibility

#### **2. Projects API** ✅
```bash
GET /api/canonical/0/projects/
GET /api/canonical/0/projects/?team={uuid}  # Filter by team
```
Returns projects with DSN, event counts, alert settings, retention limits

#### **3. Issues API** ✅
```bash
GET /api/canonical/0/issues/?project={id}
GET /api/canonical/0/issues/?project={id}&sort=last_seen&order=desc
```
- **Pagination**: Cursor-based, 250 results per page
- **Sorting**: `sort=digest_order|last_seen`, `order=asc|desc`
- Returns issue metadata including error type, transaction, counts, resolution status

#### **4. Events API** ✅
```bash
GET /api/canonical/0/events/?issue={uuid}
GET /api/canonical/0/events/{id}/
GET /api/canonical/0/events/{id}/stacktrace/
```
- List view excludes large `data` field for performance
- Detail view includes full event payload
- Stacktrace endpoint returns beautiful Markdown-formatted traces

**Example stacktrace output**:
```markdown
# RuntimeError
PlaygroundStatusTemplate not found (RuntimeError)

### app/services/migration/protocol_importer.rb:61 in `initialize` [in-app]
  58 |     @output[:errors] = {}
  59 |     # @output[:rows] = []
  60 |
▶ 61 |     raise 'PlaygroundStatusTemplate not found' if...
  62 |   end
```

#### **5. Releases API** ✅
```bash
GET /api/canonical/0/releases/?project={id}
```
Returns release versions, dates, and build info

#### **6. Documentation** ✅
- **OpenAPI Schema**: `/api/canonical/0/schema/` (YAML format)
- **Swagger UI**: `/api/canonical/0/schema/swagger-ui/` (interactive documentation)

---

### 🚫 Endpoints Not Available (Unimplemented)

Based on testing, these endpoints from the source code are **not implemented** in your instance:
- `GET /api/canonical/0/projects/{id}/` (detail view)
- `GET /api/canonical/0/issues/{id}/` (detail view)
- `GET /api/canonical/0/teams/{id}/` (detail view likely)

This suggests the instance may be running an older version or has partial API implementation.

---

### 📚 Key API Features Discovered

1. **Pagination**: Cursor-based with 250 items per page (efficient for large datasets)
2. **Filtering**: Required parameters prevent accidental mass queries
3. **Sorting**: Flexible asc/desc ordering on multiple fields
4. **Response Format**: Clean JSON with consistent structure
5. **Performance**: List endpoints exclude large fields (like event `data`) for speed
6. **Markdown Stacktraces**: Beautiful formatting for error traces
7. **Sentry Compatibility**: Projects have DSN strings for Sentry SDK integration

---

### 🔍 Sample API Calls

**Get all projects with statistics**:
```bash
curl -H "Authorization: Bearer c678e07cdf8491a44b65ee2e4d4a1e6ec56cfe2a" \
  https://bugs.kopernici.cz/api/canonical/0/projects/
```

**Get latest issues for a project**:
```bash
curl -H "Authorization: Bearer c678e07cdf8491a44b65ee2e4d4a1e6ec56cfe2a" \
  "https://bugs.kopernici.cz/api/canonical/0/issues/?project=1&sort=last_seen&order=desc"
```

**Get events for an issue**:
```bash
curl -H "Authorization: Bearer c678e07cdf8491a44b65ee2e4d4a1e6ec56cfe2a" \
  "https://bugs.kopernici.cz/api/canonical/0/events/?issue={issue-uuid}"
```

**Get formatted stacktrace**:
```bash
curl -H "Authorization: Bearer c678e07cdf8491a44b65ee2e4d4a1e6ec56cfe2a" \
  "https://bugs.kopernici.cz/api/canonical/0/events/{event-uuid}/stacktrace/"
```

---

### 💡 Recommendations

1. **Use the Swagger UI** for interactive exploration: https://bugs.kopernici.cz/api/canonical/0/schema/swagger-ui/
2. **Pagination**: Always check `next` field for more results
3. **Event Details**: Use the detail endpoint (`/events/{id}/`) to get full event payloads
4. **Stacktraces**: The `/stacktrace/` endpoint provides human-readable error traces
5. **Performance**: List endpoints are optimized by excluding large fields

---

### 📖 Complete API Documentation

The full technical documentation from the repository analysis is available in the first response above, including:
- All endpoint specifications
- Authentication methods
- Request/response formats
- Query parameters
- Error handling
- Event schema structure
