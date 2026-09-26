# Aasha — Technical Approach (Complete)

> Covers: Spring Boot backend, Flutter/Dart app, website, matching AI, **NDMA SACHET API**, IMD API (planned), maps, n8n WhatsApp, sync, images, security, ops.

---

## 1. System Architecture

```
┌─────────────────┐   ┌──────────────────┐   ┌────────────────────┐
│  Flutter App     │   │  Thymeleaf Web   │   │  n8n (port 5678)   │
│  (Android/Web)   │   │  localhost:8080  │   │  WhatsApp outbound │
└───────┬─────────┘   └────────┬─────────┘   └─────────▲──────────┘
        │ JWT /api/**          │ session /pages        │ HTTP POST
        ▼                      ▼                       │
┌──────────────────────────────────────────┐    ┌──────┴───────────┐
│  Spring Boot 3.5  :8080                  │───►│ N8nService /      │
│  Security · JPA · Flyway · Thymeleaf     │    │ NotificationSvc   │
└───┬──────────┬──────────┬──────────┬─────┘    └──────────────────┘
    │          │          │          │
    ▼          ▼          ▼          ▼
 MySQL      MinIO      AI Match    NDMA SACHET API
 :3306      :9000      :8000       (external, polled every 2 min)
 (aasha)  (aasha-photos) (rank)    sachet.ndma.gov.in
```

- One Spring Boot process serves both the REST API and the rendered website.
- External systems: MySQL, MinIO (photo object storage), AI match service (Python, `:8000`), n8n (`:5678`), NDMA SACHET (public feed).

---

## 2. Spring Boot Backend

### 2.1 Stack & configuration
- Spring Boot **3.5.4**, Java 17, starters: `web`, `security`, `data-jpa`, `thymeleaf`, `validation`.
- `application.properties` essentials:
  - `server.port=8080`, `spring.thymeleaf.cache=false` (live template/CSS reload), multipart max **50MB**.
  - MySQL: `jdbc:mysql://localhost:3306/aasha?createDatabaseIfNotExist=true&serverTimezone=UTC`, user `root`, pass `${DB_PASSWORD:...}`.
  - `spring.jpa.hibernate.ddl-auto=validate` — schema owned by Flyway; Hibernate only validates.
  - Flyway: `locations=classpath:db/migration`, `validate-on-migrate=false`, `ignore-migration-patterns=*:missing` (V6–V15 were applied from files later removed from the repo).
  - JWT: `jwt.secret` (HS256, ≥256-bit), `jwt.expiration=86400000` (24 h).
  - Matching: `matching.ai-url=http://localhost:8000/api/v1/match`, `matching.candidate-pool-size=100`, `matching.age-tolerance=5`.
  - MinIO: `minio.endpoint=http://127.0.0.1:9000`, bucket `aasha-photos`, keys from env.
  - n8n: `n8n.webhook-url=${N8N_WEBHOOK_URL:http://localhost:5678/webhook/aasha-whatsapp}` (+ alias `n8n.webhook.url`).

### 2.2 Package layout (`com.aasha.web`)
| Layer | Contents |
|---|---|
| `config/` | `SecurityConfig`, `JwtAuthFilter`, `MinioConfig`, `WebConfig` |
| `controller/` | `SearchController`, `ApiController`, `AuthController`, `WebAuthController`, `MatchController`, `ImageController`, `SavedSearchController`, `AlertController`, `UserSosController`, `PublicController` |
| `service/` | `RecordService`, `CandidateRetrievalService`, `AiMatchingClient`, `JwtService`, `PhotoService`, `N8nService`, `NotificationService`, `SachetPollerService`, `AlertService`, `UserSosService` |
| `repository/` | JPA repos: camps, normal/critical records, saved searches, users, alerts, user_sos |
| `entity/` | `Camp`, `NormalRecord`, `CriticalRecord`, `AppUser`, `SavedSearch`, `Alert`, `UserSos` |
| `dto/` | `SearchRequest`, `MatchAiRequest/Response`, `MatchCandidate`, `AuthRequest/Response`, `SosRequest/Response`, `AlertRequest/Response`, `DashboardStats` |

### 2.3 Security (dual-mode auth)
- **Website pages** → cookie session + form login (`/login` → `defaultSuccessUrl("/")`); CSRF via `CookieCsrfTokenRepository` (token auto-injected into `th:action` forms; ignored on `/api/**` for the app).
- **App APIs** → JWT bearer (`JwtAuthFilter` before `UsernamePasswordAuthenticationFilter`; token from `POST /api/auth/login`, 24 h expiry).
- Route rules (in order):
  - public: `/`, `/camps`, `/about`, `/health`, `/login`, `/register`, `/api/auth/**`, GET `/api/stats|camps|normal-records|critical-records|alerts/active`, `/api/v1/images/**`, `/api/v1/match/**`, `/api/saved-searches/**`, `/api/webhook/**`;
  - **authenticated**: `/search`, `/critical` pages + all remaining `/api/**`.
- CORS: all origins, credentials on, max-age 3600.
- Roles: `ROLE_USER` / `ROLE_OFFICIAL`, enforced with `@EnableMethodSecurity`.

### 2.4 Database (MySQL `aasha`, Flyway migrations)
- `V1` camps / normal_records / critical_records (name, age, gender, last_known_location, photo, status, camp_id, officer_name/contact, created_at, indexes on name/age/status).
- `V2` users, `V3` alerts, `V4` saved_searches, `V5` user_sos.
- `V6–V15` applied historically (files removed → ignored in validation).
- `V16__fix_camp_contacts.sql` — data repair for test phone values.

---

## 3. Matching Pipeline (core feature)

1. `GET /search` form (photoFile, name, age, gender, lastKnownLocation, additionalDetails) → `POST /search`.
2. **Candidate retrieval (in-process)** — `CandidateRetrievalService.retrieve()`:
   - baseline latest 20 normal + 20 critical;
   - name → `findByNameContainingLimited` + token split (`\s+`, tokens ≥2 chars → `findByToken`);
   - age → `findByAgeBetween(age ± matching.age-tolerance=5)`;
   - location → `findByLocationContaining`;
   - dedup (`LinkedHashMap`) → cap `matching.candidate-pool-size=100`.
3. **AI ranking** — `AiMatchingClient.rank()` POSTs `MatchAiRequest` to `matching.ai-url` (`http://localhost:8000/api/v1/match`); returns scored `MatchCandidate[]` (score, camp, officer, officer_contact). `/more` variant for pagination. On failure → `MatchingServiceException` → graceful fallback message (step-2 candidates still usable).
4. **Render** — `search.html` result cards: match % pill (Strong / Possible / Weak bands), photo bytes via `/api/v1/images/bytes/{assetId}`, officer `tel:` link.
5. **Saved search / alerts** — "Notify me of new matches" modal → `POST /api/saved-searches` {params, phone} → later record creation triggers `NotificationService.onNewRecordCreated` → `findMatchingByName` → n8n (§6).

Photo path: `POST /api/v1/match-input` → embedding by AI service → similarity vs record photos.

---

## 3A. AI Matching Algorithms (Complete Deep-Dive)

> Every algorithm in the Python AI Service (`ai-service/`) + the Java retrieval layer. Files: `CandidateRetrievalService.java` (Stage 1) · `text_similarity.py`, `scoring.py` (Stage 2) · `image_similarity.py`, `face_similarity.py`, `main.py:_rank_candidates` (Stage 3) · `scoring.py:explain`, `main.py:_page` (Stage 4).

### 3A.1 The 4-Stage Matching Pipeline

```
User Query (name, age, location, details, photo?)
        ↓
┌─ STAGE 1: RECALL (Java/Spring) ─────────────────────────────┐
│ Multi-query SQL union → dedup → ≤100 candidates             │
└─────────────────────────────────────────────────────────────┘
        ↓
┌─ STAGE 2: METADATA RANKING (Python/FastAPI) ────────────────┐
│ Name + Age + Location + Details scorers → weighted fusion   │
└─────────────────────────────────────────────────────────────┘
        ↓
┌─ STAGE 3: VISUAL RERANK (only if photo given) ──────────────┐
│ Shortlist top-30 → CLIP + ArcFace cosine → re-fusion        │
└─────────────────────────────────────────────────────────────┘
        ↓
┌─ STAGE 4: LABEL + PAGINATE ─────────────────────────────────┐
│ Strong/Possible/Weak thresholds → explain → session → pages │
└─────────────────────────────────────────────────────────────┘
```

### 3A.2 STAGE 1 — Candidate Retrieval (High-Recall, Java)

**Algorithm: multi-query union with ordered deduplication** — deliberately biased toward *recall* over precision (a missed candidate can never be recovered downstream).

| # | Query | Purpose |
|---|-------|---------|
| 1 | Top-20 newest normal + critical records | Freshness baseline — newly rescued people |
| 2 | `findByNameContainingLimited(name, 100)` | Full-name substring match |
| 3 | **Per-token queries** — name split on whitespace, tokens ≥2 chars (`findByToken`) | Partial names: *"Rahul Kumar"* → also searches *"Rahul"*, *"Kumar"* independently |
| 4 | `findByAgeBetween(age±5)` | **Age tolerance band = ±5 years** (`matching.age-tolerance`) |
| 5 | `findByLocationContaining(location)` | Location substring recall |

- **Dedup:** `LinkedHashMap<"normal:{id}"|"critical:{id}", Candidate>` + `putIfAbsent` → insertion order preserved, cross-query duplicates removed.
- **Cap:** `PageRequest.of(0, 100)` per query + final `limit(maxCandidates)` → **pool ≤ 100** (`matching.candidate-pool-size`).

### 3A.3 STAGE 2 — Text Similarity Engine

**Model: `all-MiniLM-L6-v2`** (Sentence-Transformers) — 384-dim, loaded **once per process** (singleton, reused for lifetime).

- Encoding: `model.encode(text, normalize_embeddings=True)` → unit vector.
- Similarity: **manual cosine**, clamped to [0,1]:

```
sim(A,B) = (A·B) / (‖A‖·‖B‖)
```

- Guards: empty → 0.0 · dimension mismatch → 0.0 · zero magnitude → 0.0.

**Text normalization (`normalize_text`)** applied before every comparison:
1. Lowercase → 2. replace non-`[a-z0-9 ]` with space (strips punctuation/symbols/Devanagari) → 3. collapse whitespace runs → trim.

### 3A.4 STAGE 2 — Component Scorers (`scoring.py`)

**A. Name Score (hybrid — best-of-two)**
```
normalize both names
if exact equal                          → 1.0 (instant)
token_overlap = |A∩B| / max(|A|,|B|)    ← set-based, order-independent
semantic      = MiniLM cosine
return max(token_overlap, semantic)
```
- *Why hybrid:* token overlap catches exact spellings cheaply; semantic catches transliteration variants (*"Rehan"/"Rihan"*) and typos — **max** ensures either path can win. Set-based → *"Kumar Rahul"* ≡ *"Rahul Kumar"*.

**B. Age Score (linear decay)**
```
age_score = max(0, 1 - |query_age - candidate_age| / 10)
```
- ±0 → 1.0 · ±5 → 0.5 · ±10+ → 0.0. Computed only if **both** sides have age (`candidate.age > 0`).

**C. Location Score** — query `last_known_location` vs candidate `found_location ∪ camp_name`.
**D. Details Score** — query `additional_details` vs candidate `last_known_clothing ∪ additional_details`.

Both: normalize → exact = 1.0 → else **MiniLM cosine**. Either may be absent → *skipped, not zeroed*.

### 3A.5 Weighted Fusion with Weight Renormalization ⭐ (core innovation)

Absent data is **excluded and weights renormalized** — never penalized.

| Signal | Weight |
|--------|--------|
| **Face (ArcFace)** | **0.30** (primary identity) |
| **Name** | **0.25** |
| Age | 0.15 |
| Details (clothing/description) | 0.15 |
| Location | 0.10 |
| CLIP visual anchor | 0.05 (secondary) |

```
final = 100 × Σ(scoreᵢ × weightᵢ) / Σ(weightᵢ)   over PRESENT components only
```

- **Example:** candidate with no location & no photo → denominator = 0.25+0.15+0.15 = **0.55** (not 1.0). Missing fields cost nothing.
- All image scores clamped to [0,1] before weighting; output rounded to 2 decimals.

### 3A.6 STAGE 3 — Visual Rerank (only when query has a photo)

**Photo ingestion guard:** base64-decode attempt → **magic-byte validation** (`FF D8 FF` JPEG · `89 PNG` · `RIFF` WEBP, length >100) → real bytes else UTF-8 fallback. Prevents garbage reaching the models.

**Two parallel visual embeddings:**

| | CLIP (`image_similarity.py`) | ArcFace (`face_similarity.py`) |
|---|---|---|
| Model | `openai/clip-vit-base-patch32` (ViT-B/32) | **InsightFace `buffalo_l`**, CPU, `det_size=(640,640)` |
| Role | Broad visual anchor (clothing, scene) | **Identity** — 512-dim face embedding |
| Pipeline | PIL→RGB→`CLIPImageProcessor`→vision tower→`image_embeds`→L2 norm | detect → exactly-one-face rule → `normed_embedding` |
| Similarity | `(cos+1)/2` clamped [0,1] | `(cos+1)/2` clamped [0,1] |
| Failure | `0 faces → error` · `>1 faces → error` (group photos rejected) | thread-safe in-memory embedding cache |

- CLIP is explicitly **not** identity verification — the face signal is (weight 0.30 vs 0.05).
- **Shortlist trick:** all 100 scored on metadata → sort → **top 30** (`image_shortlist_size`) get CLIP+ArcFace; rest keep metadata score (renormalization makes it fair) → bounds inference at ≤30 images/request.
- **Re-fusion (`add_image_scores`):** reuses existing component scores (no text re-embedding), appends `clip×0.05 + face×0.30` only if computed → renormalized → final re-sort.
- **Failure handling:** every image step try/except → score set to `None` → weight renormalized → ranking **never crashes**.

### 3A.7 STAGE 4 — Labels, Explainability, Pagination

**Thresholds (`MatchScoringConfig`):**

| Score | Label |
|-------|-------|
| **≥ 90.0** | **Strong Match** |
| **≥ 75.0** | **Possible Match** |
| **≥ 60.0** | **Weak Match** |
| < 60.0 | filtered out |

**Rule-based explainability (`explain`)** — signals above gates: `face>0.8` · `clip>0.85` (only if face absent/weak) · `name>0.8` · `age>0.9` · `location>0.8` · `details>0.8` → natural-language sentence:

> *"Strong similarity in face, name and age."*

- Grammar handled for 1 / 2 / ≥3 signals; CLIP never mentioned when face is strong → **no identity confusion in user-facing text**.

**Session bounding & pagination (`main.py`):**
- Ranking stored in `_ranked_sessions[uuid4.hex]` → `PAGE_SIZE = 3` → `next_page_token = offset+3` → `/api/v1/match/more`.
- **`MAX_SESSIONS = 100`** → `_clean_sessions()` evicts **oldest 20** (LRU-like) → bounded memory under bursts; expired session → HTTP 404.

**Privacy guarantees enforced in the algorithm layer:**
- `photo_url` returned **only for `record_type == "normal"`** — critical records never emit photos.
- `image_storage_id` backend-opaque — never serialized to clients.
- Candidate photos fetched only via `get_private_image()` **server-side**; match-input photo stored with **private** visibility.

**Graceful degradation matrix:**

| Failure | Behavior |
|---------|----------|
| CLIP load fails | `image_similarity=None` → CLIP weight never enters → renormalized |
| ArcFace load fails | same — face weight absent |
| No/multiple faces in query photo | face score skipped, others renormalized |
| Corrupt candidate image | that candidate gets metadata-only score |
| MiniLM unavailable | embed → [] → 0.0, token overlap still works |

### 3A.8 Full Request Flow (numbers)

```
POST /api/v1/match {name, age, location, details, photo?, candidates[≤100]}
 1. _clean_sessions()                       # evict if >100 sessions
 2. Java retrieval: 7 SQL queries → LinkedHashMap → ≤100 unique
 3. metadata_scored = [score(c) for c in candidates]
 4. if photo: encode CLIP(1) + ArcFace(1)
 5. sort → shortlist top-30
 6. per candidate: embedding_for_storage (cached) → cos → add_image_scores
 7. final sort desc
 8. session_id = uuid4; store; page[0:3] → response
 9. /match/more with page_token → slices same session
```

### 3A.9 Algorithm Inventory (18 algorithms)

| # | Algorithm | Location | Type |
|---|-----------|----------|------|
| 1 | Multi-query union retrieval + LinkedHashMap dedup | `CandidateRetrievalService.java` | Information retrieval |
| 2 | Age-tolerance band filtering (±5) | same | Range query |
| 3 | Text normalization pipeline | `scoring.py:normalize_text` | Preprocessing |
| 4 | Sentence embedding + cosine (`all-MiniLM-L6-v2`) | `text_similarity.py` | Semantic similarity |
| 5 | Token-set overlap (Jaccard-style) | `scoring.py:_name_score` | Lexical similarity |
| 6 | Hybrid best-of (max of lexical+semantic) | `_name_score` | Ensemble scoring |
| 7 | Linear age decay (`1 - Δ/10`) | `_age_score` | Distance decay |
| 8 | **Weight-renormalized late fusion** | `scoring.score` | Multi-criteria fusion |
| 9 | Metadata shortlist (top-30) cascade ranking | `main.py:_rank_candidates` | Cascade ranking |
| 10 | CLIP ViT-B/32 image embedding + cosine | `image_similarity.py` | Vision transformer |
| 11 | ArcFace buffalo_l 512-dim face embedding + cosine | `face_similarity.py` | Face recognition |
| 12 | `(cos+1)/2` cosine rescaling to [0,1] | both similarity services | Score calibration |
| 13 | Magic-byte file-type sniffing | `main.py` / `image_storage.validate_image` | Input validation |
| 14 | Threshold bucketing (90/75/60) | `scoring.explain` | Classification |
| 15 | Rule-based NL explanation generation | `explain` | Explainable AI |
| 16 | LRU-style session eviction (100 cap, evict 20) | `main.py:_clean_sessions` | Memory bounding |
| 17 | Embedding memoization caches (thread-safe) | face/image caches | Caching |
| 18 | Fail-open degradation (try/except per signal) | all stages | Fault tolerance |

**Summary: 4 pipeline stages · 18 named algorithms · 3 ML models (MiniLM, CLIP, ArcFace) · 1 fusion innovation (weight renormalization).**

---

## 4. API Surface

- **Auth (app):** `POST /api/auth/register`, `POST /api/auth/login` (→JWT), `GET /api/auth/profile`.
- **Auth (web):** GET/POST `/register`, POST `/login`, GET `/logout`.
- **Public:** `GET /api/stats`, `GET /api/camps`.
- **Records:** `/api/camps`, `/api/normal-records`, `/api/critical-records` — `GET /list`, `GET/{id}`, POST, `PUT/{id}`, `PATCH/{id}/status`, DELETE.
- **Sync:** `POST /api/sync/camps|normal-records|critical-records`.
- **Images (MinIO):** `POST /api/v1/images/normal|critical|critical-clothing|match-input`, `GET /url`, `GET /bytes/{assetId}`, `GET /file/{path}`, `DELETE /temporary/{assetId}`.
- **Match:** `POST /api/v1/match`, `POST /api/v1/match/more`.
- **Saved searches:** POST, GET, DELETE `/{id}`.
- **Alerts:** `GET /api/alerts/active`, GET, POST, `PATCH /{id}/active`.
- **SOS:** `POST /api/sos`, GET, `GET /{id}`, `PATCH /{id}/status`.
- **Webhook (n8n→backend):** `/api/webhook/**` (permitAll).
- **Pages:** `/`, `/search` (GET/POST), `/critical` (GET/POST), `/camps`, `/about`, `/health`.

---

## 5. Maps Integration

### 5.1 Flutter (in-app map)
- **`flutter_map: ^8.2.2`** + **`latlong2: ^0.9.1`** — OpenStreetMap raster tiles, no API key.
- `TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png')` (`safety_map_screen.dart:350`).
- Layers: user marker (**`geolocator: ^14.0.3`** GPS → `_mapController.move(LatLng, 11)`), disaster zone markers (red/orange/green + legend), camp markers (`camp.latitude/lng`), safety zone circles/polygons.
- **`geocoding: ^5.0.0`** — text location → lat/lng when creating records/camps; reverse geocode for "last known location".
- Android permission: `ACCESS_FINE_LOCATION` + runtime request.

### 5.2 Website
- Home embed: OpenStreetMap iframe `https://www.openstreetmap.org/export/embed.html?bbox=...&layer=mapnik&marker=lat,lon` (no key, no JS library).
- Camp cards show text location + `tel:` phone.

### 5.3 Coordinate storage
- `camps.latitude/longitude/accuracy`, records lat/lng, `alerts.latitude/longitude` (SACHET centroid parsed as **"longitude,latitude"** order), `user_sos` geo.
- Range validation (lat −90..90, lon −180..180) before save.

---

## 6. n8n / WhatsApp Notifications

- Config: `n8n.webhook-url=${N8N_WEBHOOK_URL:http://localhost:5678/webhook/aasha-whatsapp}` (+ `n8n.webhook.url` alias).
- **`N8nService.sendToN8n(Map)`** — Spring `RestClient` POST, fire-and-forget.
- **`NotificationService.onNewRecordCreated(recordId, recordType, name, age, campName, officerName, officerContact)`**:
  1. skip if webhook URL empty;
  2. `savedSearchRepo.findMatchingByName(name)` → all saved citizen searches matching the new record;
  3. per search POST JSON `{recordId, recordType, name, age, campName, officerName, officerContact, savedSearchId, userPhone, searchName}`;
  4. try/catch per phone (one failure never blocks others) → logged.
- n8n workflow: Webhook → Set/Code (map fields) → IF (+91 formatting) → **WhatsApp node** (Meta Cloud API / Twilio, pre-approved HSM template "Aasha Match Alert") → respond 200. Optional second workflow calls back `/api/webhook/**` (permitAll) to mark delivered.
- Security: `/api/webhook/**` is permitAll (n8n → backend); backend → n8n is outbound POST.

---

## 7. External Data Feeds

### 7.1 NDMA SACHET API (integrated)
Implementation: `spring-boot-backend/src/main/java/com/aasha/web/service/SachetPollerService.java`

- **Feed:** `GET https://sachet.ndma.gov.in/cap_public_website/FetchAllAlertDetails`
- **Schedule:** `@Scheduled(initialDelay = 15_000, fixedDelay = 120_000)` → polls every **2 minutes** (first poll 15 s after boot).
- **Toggle:** `aasha.sachet.enabled=true` (`@Value`).
- **HTTP:** Java 11 `HttpClient` (connect timeout 10 s, request timeout 20 s), `Accept: application/json`; non-200 → warn and skip.
- **Payload:** flat JSON **array** of active alerts; identifiers discovered dynamically (no hard-coded alert IDs).
- **Per item fields used:** `identifier` (dedup key → `existsByExternalId`), `effective_end_time` (parsed `"EEE MMM dd HH:mm:ss yyyy"` after dropping ` IST` token; expired alerts skipped), `disaster_type`, `area_description` (district), `warning_message`, `severity_color` (red→`critical`, orange→`severe`, yellow→`moderate`, else `low`), `alert_source` (state, `" SDMA"` suffix stripped), `centroid` (**"longitude,latitude"** → validated → `alert.longitude/latitude`).
- **Storage:** new rows in `alerts` table (`source='NDMA'`, `active=true`, truncated to 255 chars); duplicate `identifier` skipped → idempotent.
- **Consumption:** `GET /api/alerts/active` → website active-alerts strip + app `EmergencyAlertsScreen` / `emergency_center_screen`.
- **Logging:** `[SACHET] poll complete — N new alert(s) ingested` / `poll failed: ...`.

### 7.2 IMD API (NOT yet integrated — proposed design)
- **Sources:** `https://mausam.imd.gov.in/api/` (city current weather `api/currentCity/city.json?cityid=`, district warnings `api/warningDistrict/district.json`, CAP `CapApiV2`) and newer open API `api.weather.gov.in`.
- **Proposed implementation (mirrors SACHET pattern):**
  1. `ImdPollerService` — `@Scheduled(fixedDelay = 300_000)` (5 min) GET district-warning feed; `@Value("${imd.api.url:...}")`, optional `${imd.api.key}` header.
  2. Flyway `V17__imd_alerts.sql` (or reuse `alerts` with `source='IMD'` + `feed` column).
  3. Map IMD district colours RED/ORANGE/YELLOW/GREEN → existing severity enum so app + site render without client changes.
  4. Expose via existing `GET /api/alerts/active?source=IMD`.
  5. Trigger: IMD **RED** warning in a camp's district → n8n push to camp officer (`officer_uid` phone).
  6. App home: weather tile via `geolocator` city → IMD city API; map overlays district warnings.
- **Effort:** 1 service class + 1 migration + 2 config keys; zero client changes.

---

## 8. Flutter App (Dart)

### 8.1 Dependencies (`pubspec.yaml`)
- SDK Dart `^3.12.2`; **`provider ^6.1.5`** (state), **`drift ^2.28.1`** + `sqlite3_flutter_libs` + `path_provider` + dev `build_runner`/`drift_dev` (local SQL, WASM on web), **`cloud_firestore ^6.8.0`** (optional Firebase path), **`connectivity_plus ^6.1.4`** (offline gate), **`geolocator ^14.0.3`**, **`geocoding ^5.0.0`**, **`flutter_map ^8.2.2`**, **`latlong2 ^0.9.1`**, **`http ^1.2.2`** + `http_parser`, **`image ^4.5.4`** (client compression), **`image_picker ^1.1.2`**, **`shared_preferences ^2.2.2`** (JWT storage), `cupertino_icons`.

### 8.2 Architecture (feature-first)
```
lib/
├── app.dart                    # MaterialApp + named routes
├── core/
│   ├── config/api_config.dart  # base URLs
│   ├── theme/app_theme.dart    # palette / typography / components
│   └── constants/app_strings.dart
├── data/
│   ├── models/                 # NormalRecord, CriticalRecord, Camp, DisasterRecord, EmergencyAlert...
│   ├── local/                  # drift DB + local repositories (offline-first)
│   ├── repositories/           # official_*_repository → REST CRUD
│   └── sync/sync_service.dart  # pull/push reconciliation
└── features/
    ├── auth/       # welcome, login, register, forgot_password
    ├── user/       # home, search_form, results, critical_results, add_record
    ├── official/   # dashboard, manage_camps, records lists/details, SOS, pending_sync
    └── emergency/  # safety_map, sos_screen, emergency_center, alerts list/detail
```

### 8.3 Data & offline sync
- **Models:** immutable Dart classes with `toMap`/`fromMap`; JSON fields mirror API (`officerName`, `officerContact`, ...).
- **Local store:** drift tables → generated `*.g.dart`; e.g. `LocalCriticalRecordRepository.insertOrUpdate` scoped by `ownerUid`.
- **`SyncService`:** `pullLatestData()` upserts by remote `updatedAt`; `pushLocal()` builds payloads (`_criticalPayload` etc.) → `POST /api/sync/*`; `connectivity_plus` decides direction; offline writes queued → shown in `pending_sync_screen` with online/offline indicator.
- Auth: JWT from login stored in `shared_preferences` → `Authorization: Bearer` header on every API call.

### 8.4 Base URLs (`core/config/api_config.dart`)
```dart
androidEmulatorBaseUrl = 'http://10.0.2.2:8080'      // emulator → host loopback
physicalAndroidBaseUrl = 'http://192.168.1.33:8080'   // LAN dev machine
matchingBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: physicalAndroidBaseUrl)
```
Override per run: `flutter run --dart-define=API_BASE_URL=http://<host>:8080`. Web build (served :3000) calls :8080 — allowed by backend CORS.

### 8.5 Key screens
- **welcome:** brand header, 3 login rows (Citizen / Official / Camp Officer), download dialog.
- **home:** search entry (photo/name/age/location), SOS button (`POST /api/sos`), camps, emergency center.
- **results:** ranked cards (avatar, `Age • camp`, **match % pill** — Strong/Possible/Weak bands, officer contact actions, "Alert me on WhatsApp" → `POST /api/saved-searches`).
- **official:** dashboard (`GET /api/stats`), camp CRUD, record CRUD + status (`PATCH /{id}/status`), SOS triage.
- **safety_map:** OSM layers (§5.1).

### 8.6 Build
- APK: `flutter build apk --debug` → adb install (device `192.168.1.32:43935` when online).
- Web: `flutter build web` → **copy `web/sqlite3.wasm` → `build/web/`** → static server `serve_web.py` on :3000.

---

## 9. Website (Thymeleaf)

- **Templates:** `home`, `search`, `critical`, `camps`, `about`, `login`, `register` (shared header/footer fragments).
- **CSS:** `static/css/aasha-design-system.css` — `:root` design tokens (Plus Jakarta Sans + JetBrains Mono via Google Fonts, palette incl. `--navy #0B2E4F`, accent token, status strip, `.glass` cards, forms, badges, hero, footer); legacy `style.css` for auth pages.
- **Header:** fixed white bar + navy "RESPONSE ACTIVE" strip + nav (Home / Find a Loved One / Camps / About).
- **Forms:** server-rendered; Thymeleaf `th:action` auto-injects CSRF hidden field (verified `POST /search` → 200).
- **JS:** vanilla only — match-alert modal + mobile nav toggle.
- **Live reload:** `spring.thymeleaf.cache=false` (no restart for HTML/CSS edits).

---

## 10. Notifications Matrix

| Path | Trigger | Transport |
|---|---|---|
| Saved-search match | new record + `findMatchingByName` | backend → n8n → WhatsApp |
| NDMA disaster alert | **SACHET poll every 2 min (§7.1)** | stored → app/site pull |
| Citizen SOS | SOS button | `POST /api/sos` → official dashboard |
| IMD district warning | ImdPoller (proposed §7.2) | stored + optional officer push |

---

## 11. Build / Run / Deploy (current: local)

| Piece | Command | Port |
|---|---|---|
| Backend | `gradlew bootRun` (JAVA_HOME=Android Studio `\jbr`), log `backend.log` | 8080 |
| MySQL | local service, DB `aasha` (`createDatabaseIfNotExist`) | 3306 |
| MinIO | local server, bucket `aasha-photos` | 9000 |
| n8n | `npx n8n` or Docker `n8nio/n8n` | 5678 |
| AI match | separate Python service (own repo) | 8000 |
| Flutter web | `serve_web.py` serving `flutter-app/build/web` | 3000 |

Env overrides: `DB_PASSWORD`, `JWT_SECRET`, `N8N_WEBHOOK_URL`, `MATCHING_AI_URL`, `API_BASE_URL`, `MINIO_*`, `aasha.sachet.enabled`.
Production path: nginx/HTTPS in front, Docker Compose (mysql, minio, n8n, aasha, match-ai), secrets via env only.

---

## 12. Known Gaps / Risks
1. **IMD API not implemented yet** — design ready in §7.2 (SACHET is the only live feed).
2. n8n fire-and-forget — no retry queue/DLQ; webhook unsigned (add HMAC or IP allowlist).
3. Default JWT secret + DB password fallbacks in repo — must be overridden in prod.
4. Two webhook property keys (`n8n.webhook-url` / `n8n.webhook.url`) — consolidate to one.
5. No rate limiting on `/api/auth/login`; no refresh token (fixed 24 h JWT).
6. Matching candidate pool is heuristic SQL; photo embeddings need a vector store (pgvector/FAISS) to scale.
7. Critical-record isolation is table-level + access logging, not row-level encryption.
