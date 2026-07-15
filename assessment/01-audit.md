\# Draft Audit Log — ai-interview-platform



> Working notes. Nanti dirapikan jadi `/assessment/01-audit.md` sesuai format:

> Severity (P0-P3), impact, cara nemuinnya (repro steps/evidence), dan kategori (missing/ambiguous spec vs built wrong).



\---



\## BUG-001: Frontend memanggil port API yang salah (login gagal total)



\- \*\*Severity:\*\* P0 (Blocker)

\- \*\*Kategori:\*\* Built wrong (bukan missing spec — backend \& frontend sama-sama ada, tapi tidak konsisten)

\- \*\*Impact:\*\* Tidak ada satupun user yang bisa login lewat UI. Fungsi utama aplikasi lumpuh sejak langkah pertama.

\- \*\*Repro steps:\*\*

&#x20; 1. Jalankan backend (`rails server`, port 3001) dan frontend (`npm run dev`, port 5173) sesuai README.

&#x20; 2. Buat user manual via Rails console (karena `db:seed` tidak membuat user — lihat BUG-002).

&#x20; 3. Coba login lewat `localhost:5173/login` dengan kredensial user yang baru dibuat.

&#x20; 4. Hasil: "Invalid email or password" walau kredensial benar.

\- \*\*Evidence:\*\*

&#x20; - Test langsung ke API pakai `Invoke-RestMethod` ke `http://localhost:3001/api/v1/auth/login` → \*\*berhasil\*\*, dapat token.

&#x20; - Cek DevTools Network tab: frontend memanggil `http://localhost:3000/api/v1/auth/login` (port \*\*3000\*\*), padahal backend jalan di port \*\*3001\*\*.

&#x20; - Endpoint path-nya benar (`/api/v1/auth/login`), yang salah cuma port di base URL frontend.

\- \*\*Root cause (confirmed):\*\* File `web/.env.example` sendiri berisi default `VITE\_API\_BASE\_URL=http://localhost:3000/api/v1` dan `VITE\_WS\_BASE\_URL=ws://localhost:3000` — mismatch dengan README backend (`api/README.md`) yang jelas bilang Rails server jalan di \*\*port 3001\*\*. Ini bug di sumber template config repo, bukan salah setup developer. Siapapun yang setup project persis sesuai kedua README (backend + frontend) akan otomatis kena bug ini.

\- \*\*Status:\*\* ✅ FIXED. Ubah `VITE\_API\_BASE\_URL` → `http://localhost:3001/api/v1` dan `VITE\_WS\_BASE\_URL` → `ws://localhost:3001` di `web/.env`, restart `npm run dev`. Login berhasil setelah fix. (Untuk case study nanti: fix idealnya juga menyentuh default di `.env.example` biar tidak menjebak orang lain — ini bisa jadi bagian dari PR fix kamu.)



\---



\## BUG-002: `db:seed` tidak membuat user login sama sekali



\- \*\*Severity:\*\* P1 (Major) — sementara, perlu dikonfirmasi apakah ini "by design" (out of scope) atau memang defect

\- \*\*Kategori:\*\* Missing/ambiguous spec — tidak ada dokumentasi yang bilang cara bikin user pertama kali

\- \*\*Impact:\*\* Siapapun yang setup project dari nol (sesuai README) tidak akan punya cara masuk ke aplikasi tanpa tahu harus create user manual lewat Rails console. README tidak menyebutkan langkah ini.

\- \*\*Repro steps:\*\*

&#x20; 1. Jalankan `rails db:seed` sesuai README.

&#x20; 2. Buka halaman login.

&#x20; 3. Tidak ada kredensial yang valid untuk dicoba — `User.count` di Rails console menunjukkan `0`.

\- \*\*Evidence:\*\* Isi `db/seeds.rb` hanya membuat data `organizations` dan `SkillTaxonomy` (22 skill), tidak ada `User.create`.

\- \*\*Status:\*\* ✅ FIXED. Ditambahkan blok pembuatan default user (idempotent, cek `User.exists?` dulu) di `db/seeds.rb`, sebelum blok organization. Diverifikasi manual: run pertama "Created", run kedua "already exists (skipped)". Ditambahkan regression test di `spec/lib/tasks/seed\_spec.rb` (lihat BUG-007) — 2 examples, 0 failures. Kredensial default: `admin@test-corp.local` / `password123`.



\---



\## BUG-003: Link invite kandidat menunjuk ke backend (port API), bukan frontend



\- \*\*Severity:\*\* P0 (Blocker)

\- \*\*Kategori:\*\* Built wrong / config salah (mirip pola BUG-001 — salah base URL antar servis)

\- \*\*Impact:\*\* Kandidat yang menerima link invite interview (dari fitur "Invite Candidate") tidak bisa mengakses halaman interview sama sekali — link mengarah ke Rails API (yang tidak punya route untuk itu), bukan ke frontend React. Ini blocker total untuk fungsi inti aplikasi: kandidat tidak bisa memulai sesi interview.

\- \*\*Repro steps:\*\*

&#x20; 1. Buat Assessment lewat UI, klik "Invite Candidate".

&#x20; 2. Aplikasi generate link: `http://localhost:3001/interview/<token>`.

&#x20; 3. Buka link tersebut → error `ActionController::RoutingError: No route matches \[GET] "/interview/<token>"`.

\- \*\*Evidence:\*\* Screenshot error Rails routing, `Rails.root: .../api`. Port di link (3001) = port backend, bukan port frontend (5173).

\- \*\*Root cause (confirmed):\*\* `web/src/App.tsx` punya route publik `/interview/:token` → `InterviewPage.tsx` yang valid (tidak perlu login, di luar `ProtectedRoute`). Jadi halaman kandidat memang ada dan benar di frontend. Masalahnya murni di backend: `APP\_BASE\_URL` di `api/config/application.yml` diisi `http://localhost:3001` (port backend), sehingga link yang di-generate untuk kandidat salah menunjuk ke Rails API, bukan ke frontend React (`http://localhost:5173`) tempat route `/interview/:token` sebenarnya berada.

\- \*\*Status:\*\* ✅ Root cause dikonfirmasi lewat kode, dan fix (`APP\_BASE\_URL` → `http://localhost:5173` + restart Rails) sudah diverifikasi — link invite sekarang mengarah ke frontend dengan benar. Masih perlu diverifikasi apakah halaman interview beneran terbuka \& berfungsi (session flow) — lanjut ke eksplorasi berikutnya.



\## BUG-004: Internet speed check memblokir interview meski koneksi terlihat wajar



\- \*\*Severity:\*\* P1 (Major) — dikonfirmasi memblokir kandidat, bukan sekadar indikator visual

\- \*\*Kategori:\*\* Built wrong (logic threshold berjalan sesuai kode, tapi desain pengukuran \& thresholdnya berpotensi false-negative)

\- \*\*Impact:\*\* Kandidat dengan koneksi yang subjektif terlihat baik (55.75 Mbps download, 33ms ping) \*\*tidak bisa memulai interview sama sekali\*\* — tombol "Start Interview" ter-disable — karena upload speed test terukur 1.04–1.86 Mbps, di bawah threshold `minUploadMbps: 4`. Ini bisa memblokir kandidat yang koneksinya sebenarnya cukup untuk voice interview, karena:

&#x20; 1. Upload diukur dengan POST 0.5MB ke server pihak ketiga (`httpbin.org`), yang latency/kecepatannya dipengaruhi kondisi server itu sendiri, bukan murni bandwidth kandidat.

&#x20; 2. Threshold 4 Mbps upload cukup tinggi untuk kondisi internet rumahan rata-rata, sementara voice interview (audio saja) kemungkinan tidak butuh upload sebesar itu.

\- \*\*Repro steps:\*\*

&#x20; 1. Buka link interview kandidat, tunggu hardware check jalan otomatis.

&#x20; 2. Lihat hasil: Download tinggi (42-55 Mbps), tapi Upload rendah (1-1.8 Mbps) → status "Internet: Failed".

&#x20; 3. Tombol "Start Interview" dikonfirmasi disabled — kandidat mentok, tidak ada jalan lanjut meski OS/browser dan koneksi lain oke.

\- \*\*Evidence:\*\* Kode `web/src/utils/internetSpeedTest.ts` — `DEFAULT\_THRESHOLDS.minUploadMbps = 4`, upload diukur via `fetch(POST)` ke `httpbin.org/post` atau `postman-echo.com/post` (dependency eksternal, bukan diukur terhadap server sendiri). Dikonfirmasi manual: tombol disabled saat status Failed.

\- \*\*Status:\*\* Root cause \& impact terkonfirmasi. Field `camera` ada di type `HardwareCheckingProgress` (`hardwareUtils.ts`) tapi tidak muncul di UI checklist — perlu dicek terpisah.

\- \*\*Status:\*\* ✅ Fix diterapkan: threshold `minUploadMbps` diturunkan dari `4` → `1` di `DEFAULT\_THRESHOLDS`. Logic pass/fail diekstrak jadi function terpisah `evaluateSpeedResult()` agar testable. Regression test ditambahkan (`internetSpeedTest.test.ts`, 6 test, semua lolos) mencakup kasus asli dari audit (upload 1.04 Mbps) dan mendokumentasikan bahwa kasus itu dulu gagal di threshold lama (4 Mbps). Belum diterapkan: Opsi 2 (ukur ke endpoint sendiri `POST /api/v1/speed\_test`) dan Opsi 3 (non-blocking warning) — dicatat sebagai rekomendasi lanjutan, bukan blocker untuk case study ini.



\## BUG-005: Koneksi WebSocket audio gagal (connection refused), sesi berakhir prematur dengan status "Complete" yang menyesatkan



\- \*\*Severity:\*\* P0 (Blocker) + kemungkinan data integrity issue

\- \*\*Kategori:\*\* Built wrong — kemungkinan backend tidak menyediakan endpoint WebSocket yang berfungsi, ATAU frontend salah alamat

\- \*\*Impact:\*\* Fitur inti aplikasi (voice interview real-time) sama sekali tidak berfungsi. Kandidat klik "Start Interview", browser mencoba konek WebSocket untuk streaming audio, gagal berulang kali ("Briefly reconnecting..."), lalu dalam \~5 detik sesi otomatis ditutup dengan pesan \*\*"Interview Complete — Thank you, the interview has been recorded"\*\* — padahal tidak ada percakapan/rekaman apapun yang terjadi. Ini menyesatkan: dari sisi hiring team, sesi akan terlihat "selesai normal" padahal sebenarnya gagal total sejak awal.

\- \*\*Repro steps:\*\*

&#x20; 1. Buat assessment, invite candidate, buka link interview, lewati hardware check.

&#x20; 2. Klik "Start Interview".

&#x20; 3. Muncul badge "Reconnecting...", pesan "Briefly reconnecting — please wait a moment", status "Listening...".

&#x20; 4. Setelah \~5 detik, otomatis pindah ke halaman "Interview Complete" tanpa interaksi apapun.

\- \*\*Evidence (Console browser):\*\*

&#x20; ```

&#x20; WebSocket connection to 'ws://localhost:3001/ws/sessions/1/audio?token=...' failed:

&#x20; Error in connection establishment: net::ERR\_CONNECTION\_REFUSED

&#x20; ```

&#x20; (muncul berulang kali — retry gagal terus)

\- \*\*Root cause (REVISED — temuan awal kurang akurat):\*\* WebSocket-nya TIDAK di-mount lewat `routes.rb` biasa (makanya tidak kelihatan di `rails routes`), melainkan lewat custom Rack middleware (`app/channels/audio\_websocket\_middleware.rb`, \~450 baris) yang menggunakan gem `faye-websocket` + `EventMachine`. Implementasinya ternyata SANGAT lengkap dan matang: proxy audio real-time ke Gemini Live API, reconnect logic dengan backoff, proactive reconnect sebelum limit 10 menit Gemini, audio ring buffer untuk replay setelah reconnect, time-ceiling enforcement, coverage-based auto-end, dll.



&#x20; Masalah sebenarnya: EventMachine di lingkungan Windows (development environment case study ini) CRASH FATAL saat dijalankan, dengan pesan `terminate called after throwing an instance of 'std::runtime\_error' — what(): Encryption not available on this event-machine`. Ini crash level C++ (bukan Ruby exception biasa), yang mematikan seluruh proses Rails server. Ini adalah masalah kompatibilitas gem native EventMachine dengan SSL di platform Windows yang sudah lama dikenal di komunitas Ruby — terutama untuk koneksi outbound (dibutuhkan di sini untuk connect ke Gemini Live via wss://).

\- \*\*Perlu dicek juga (data integrity):\*\* Sudah dikonfirmasi lewat BUG-006 — sebelum fix, sesi tetap "active" selamanya di database meski WebSocket gagal; setelah fix BUG-006, sesi kini ditandai jujur sebagai `status: ended, end\_reason: error` saat koneksi gagal.

\- \*\*Status:\*\* Root cause direvisi dan dikonfirmasi lewat kode — BUKAN "fitur belum dibangun", melainkan implementasi lengkap yang crash karena keterbatasan EventMachine+SSL di Windows. Dikonfirmasi lebih spesifik: crash terjadi tepat saat backend mencoba membuka koneksi SSL keluar ke Gemini Live API (`connect\_to\_gemini`), yang mematikan seluruh proses Rails secara fatal. \*\*Keputusan engineering:\*\* tidak mencoba memperbaiki EventMachine di level native/C extension (di luar scope waktu case study dan berisiko tinggi). \*\*Rekomendasi untuk Task 4 (release decision):\*\* fitur voice-interview real-time berisiko TIDAK BERFUNGSI di lingkungan development Windows, tapi kemungkinan berfungsi normal di server produksi berbasis Linux (di mana EventMachine+SSL jauh lebih stabil) — ini TIDAK bisa diverifikasi dalam case study ini karena hanya ada lingkungan Windows. Rekomendasi: \*\*block release untuk deployment ke Windows\*\*, dan \*\*wajib verifikasi end-to-end di lingkungan Linux/staging yang merepresentasikan produksi\*\* sebelum rilis final diputuskan.

\- \*\*Catatan penting terkait BUG-006:\*\* karena crash ini mematikan seluruh proses server (bukan sekadar menutup koneksi WS), verifikasi end-to-end penuh dari fix BUG-006 (browser benar-benar menerima respons dari `audio\_complete`) tidak bisa dilakukan di lingkungan ini — begitu server crash, tidak ada proses yang bisa menjawab permintaan apapun, termasuk `audio\_complete`. Namun kebenaran LOGIC fix BUG-006 sudah dibuktikan independen lewat automated test (backend request spec 5/5 lolos, frontend vitest 8/8 lolos) yang tidak bergantung pada EventMachine/koneksi WS sungguhan. Begitu BUG-005 teratasi di lingkungan yang mendukung (Linux), fix BUG-006 seharusnya langsung berfungsi end-to-end tanpa perubahan tambahan.



\*\*Bonus temuan terkait:\*\* `routes.rb` ternyata punya endpoint `POST /api/v1/speed\_test` yang sudah dirancang khusus untuk internet speed test (terima payload, balas jumlah bytes diterima) — ini adalah fix yang tepat untuk BUG-004: arahkan `VITE\_SPEED\_TEST\_UPLOAD\_URL` ke endpoint ini (`http://localhost:3001/api/v1/speed\_test`) alih-alih ke `httpbin.org`/`postman-echo.com` pihak ketiga.



\## BUG-006: Data integrity — sesi tersimpan sebagai "active" selamanya, padahal UI kandidat menampilkan "Interview Complete"



\- \*\*Severity:\*\* P0/P1 (data-integrity — sesuai bar kualitas brief, "any data-integrity issue is at least P1", dan ini berdampak langsung ke kepercayaan seluruh sistem pelaporan)

\- \*\*Kategori:\*\* Built wrong — data integrity, bukan cosmetic. Persis contoh "seam bug" yang diminta brief: UI menampilkan sukses, data tersimpan berbeda.

\- \*\*Impact:\*\* Setiap kali WebSocket audio gagal konek (lihat BUG-005) dan sesi "auto-close" setelah beberapa detik, kandidat melihat pesan positif meyakinkan ("Thank you, the interview has been recorded — the hiring team will review your results"), padahal:

&#x20; - `status` di database tetap `"active"` (bukan `"completed"` atau status gagal apapun)

&#x20; - `ended\_at`, `duration\_seconds` = `nil` (tidak pernah tercatat kapan/berapa lama sesi berjalan)

&#x20; - `end\_reason` = `nil` (tidak ada jejak kenapa sesi berhenti)

&#x20; - Tidak ada transcript/recording yang tersimpan (karena WebSocket gagal total, tidak ada audio yang pernah masuk)

&#x20; Dari sisi hiring team (assessor), sesi ini akan terlihat "masih berlangsung" tanpa akhir yang jelas di dashboard — padahal kandidatnya sudah keluar dan yakin sudah menyelesaikan interview. Ini bisa menyesatkan kandidat (mengira sudah submit) dan membingungkan hiring team (data sesi tidak lengkap, tidak jelas apakah masih berjalan atau gagal).

\- \*\*Repro steps:\*\*

&#x20; 1. Ikuti repro BUG-005 (interview auto-close \~5 detik karena WebSocket gagal).

&#x20; 2. Di Rails console: `Session.last.inspect`.

&#x20; 3. Bandingkan: UI kandidat = "Interview Complete" (positif), DB = `status: "active"`, `ended\_at: nil` (belum pernah ditutup).

\- \*\*Evidence:\*\*

&#x20; ```

&#x20; #<Session id: 1, status: "active", end\_reason: nil, started\_at: "2026-07-15 03:20:56...",

&#x20;  ended\_at: nil, duration\_seconds: nil, ...>

&#x20; ```

\- \*\*Root cause (CONFIRMED via kode):\*\* Di `web/src/hooks/useAudioWebSocket.ts`, handler `ws.onclose`:

&#x20; ```ts

&#x20; if (attempt < RECONNECT\_DELAYS.length) {

&#x20;   // retry...

&#x20; } else {

&#x20;   onStateChange("complete");  // state lokal browser, TIDAK ada API call ke backend

&#x20; }

&#x20; ```

&#x20; Setelah 3x percobaan reconnect gagal, frontend mengubah state ke "complete" murni di sisi client — tidak pernah memanggil endpoint POST /sessions/:id/end\_session yang sudah tersedia di backend. Backend sama sekali tidak tahu sesi ini berakhir, apalagi kenapa.

\- \*\*Rencana fix:\*\* Saat exhaust reconnect attempts, panggil end\_session dengan reason yang jujur (misal connection\_failed), dan ubah pesan UI agar tidak menampilkan pesan sukses palsu saat gagal.

\- \*\*Status:\*\* Sedang dikerjakan.



\## BUG-007 (Finding, bukan bug kode): Tidak ada test sama sekali di backend



\- \*\*Severity:\*\* P1 (Major) — bukan defect fungsional, tapi risiko kualitas sistemik yang menjelaskan kenapa BUG-001, 003, 005, 006 semua lolos tanpa terdeteksi

\- \*\*Kategori:\*\* Missing spec/infrastructure

\- \*\*Impact:\*\* Gem `rspec-rails` sudah ada di `Gemfile`, tapi RSpec belum pernah di-inisialisasi — folder `spec/` sama sekali tidak ada. Artinya tidak ada satupun automated test yang melindungi backend ini. Ini konsisten dengan pola bug yang ditemukan (salah port, WebSocket tidak ada, data integrity salah) — semuanya kemungkinan besar akan tertangkap lebih awal kalau ada test dasar (routing test, request spec).

\- \*\*Evidence:\*\* `dir spec` → "Cannot find path ...\\api\\spec" — direktori tidak ada.

\- \*\*Status:\*\* ✅ Fixed. RSpec di-inisialisasi (`rails generate rspec:install`), test database di-migrate. Ditambahkan `spec/lib/tasks/seed\_spec.rb` sebagai test pertama di project ini, meng-cover regression untuk BUG-002 (2 examples, 0 failures).



\*(Bug berikutnya akan ditambahkan di sini seiring eksplorasi)\*



\## BUG-008: Kesalahan penamaan class bikin aplikasi gagal boot total di production (Zeitwerk eager-load mismatch)



\- \*\*Severity:\*\* P0 (Blocker) — berpotensi lebih kritis dari BUG-005, karena ini bukan "satu fitur gagal", tapi "seluruh aplikasi gagal start"

\- \*\*Kategori:\*\* Built wrong — kesalahan penamaan file/class yang melanggar konvensi Rails Zeitwerk autoloading

\- \*\*Impact:\*\* File `app/channels/audio\_websocket\_middleware.rb` mendefinisikan class `AudioWebSocketMiddleware` (S besar di "Socket", sesuai ejaan resmi "WebSocket"), tapi Zeitwerk (sistem autoload Rails) meng-inflect nama file itu menjadi `AudioWebsocketMiddleware` (S kecil). Ini menyebabkan `NameError: uninitialized constant AudioWebsocketMiddleware` saat Rails melakukan eager load — yang aktif secara default di environment \*\*production\*\* dan (dalam kasus ini) di CI/test. Development lokal tidak pernah menampakkan bug ini karena `eager\_load` defaultnya `false` di situ.

\- \*\*Repro steps:\*\*

&#x20; 1. Jalankan `RAILS\_ENV=production` atau environment apapun dengan `eager\_load: true`, atau jalankan test suite yang memicu full Rails boot (seperti CI kita).

&#x20; 2. Rails gagal boot dengan `NameError: uninitialized constant AudioWebsocketMiddleware`.

\- \*\*Evidence:\*\* Ditemukan lewat CI job `backend-tests` pada release gate v1.0.0 — job gagal total, 3 spec file error saat load `config/environment.rb`.

\- \*\*Efek sekunder ditemukan:\*\* Setelah error pertama, spec file berikutnya mencoba re-require `config/environment.rb` (karena Ruby tidak menandai file sebagai "loaded" saat exception terjadi di tengah require), memicu `FrozenError` kedua akibat percobaan re-inisialisasi Rails app di proses yang sama. Ini gejala sekunder, bukan bug terpisah — akan hilang begitu root cause diperbaiki.

\- \*\*Root cause:\*\* Konvensi penamaan Zeitwerk tidak otomatis mengenali "WebSocket" sebagai satu kata dengan kapitalisasi khusus (mirip "iPhone" atau "GitHub") — perlu didaftarkan manual lewat `ActiveSupport::Inflector.inflections`.

\- \*\*Status:\*\* ✅ FIXED. Ditambahkan `config/initializers/inflections.rb` yang mendaftarkan "WebSocket" sebagai acronym. Diverifikasi: release gate CI untuk tag v1.0.0 gagal (menemukan bug ini), fix di-commit, tag v1.0.1 dibuat, dan release gate v1.0.1 lolos hijau penuh — bukti nyata "red to green" di level release, dan bukti bahwa quality gate yang dibangun di Task 2 benar-benar bekerja menangkap masalah nyata sebelum rilis.



