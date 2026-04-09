# Οδηγός Ρύθμισης για Web (Gemma AI)

Αυτό το έγγραφο περιγράφει τις απαραίτητες ρυθμίσεις και διορθώσεις που απαιτούνται για τη σωστή λειτουργία του project **Notes Gemma** σε περιβάλλον προγράμματος περιήγησης (Browser).

## Προκλήσεις και Επιλύσεις

Κατά την εκτέλεση της εφαρμογής στον Chrome, εντοπίστηκαν δύο βασικά ζητήματα που αφορούν τη χρήση τοπικών μοντέλων LLM μέσω του πακέτου `flutter_gemma`.

### 1. Σφάλμα JavaScript Interop (`cacheHas`)
Το σύστημα απέτυχε αρχικά με το σφάλμα `NoSuchMethodError: 'dart.global.cacheHas'`. Αυτό οφείλεται στο ότι η Flutter προσπάθησε να καλέσει μια συνάρτηση JavaScript η οποία δεν είχε οριστεί στο παγκόσμιο (global) επίπεδο του browser.

**Λύση:** 
Προστέθηκαν τα απαραίτητα scripts στο αρχείο `web/index.html` μέσω του CDN JSDelivr:
- **MediaPipe GenAI**: Η βασική βιβλιοθήκη για την εκτέλεση AI μοντέλων.
- **`cache_api.js`**: Παρέχει τη συνάρτηση `cacheHas` για τον έλεγχο ύπαρξης του μοντέλου στην προσωρινή μνήμη.

### 2. Όριο Μνήμης 2GB και Μεγάλα Μοντέλα
Τα προγράμματα περιήγησης έχουν συχνά περιορισμούς στη διαχείριση αρχείων μεγαλύτερων των 2GB στη μνήμη RAM. Επειδή το μοντέλο Gemma (π.χ. `gemma-4-E2B-it.litertlm`) έχει μέγεθος περίπου **2.5GB**, η απλή λήψη μπορεί να αποτύχει.

**Λύση:**
- Ενεργοποιήθηκε η λειτουργία **Streaming Mode** στο `lib/main.dart` και προστέθηκε το script **`opfs_helper.js`**.
- Με τη χρήση του **Origin Private File System (OPFS)**, το μοντέλο "ρέει" απευθείας στον χώρο αποθήκευσης χωρίς να δεσμεύει τεράστιο όγκο μνήμης RAM κατά τη λήψη.

## Απαραίτητες Προσθήκες στο index.html

Πρέπει πάντα να περιλαμβάνονται τα παρακάτω scripts πριν από το `flutter_bootstrap.js`:

```html
<script type="module">
  import { FilesetResolver, LlmInference } from 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-genai@0.10.16';
  window.FilesetResolver = FilesetResolver;
  window.LlmInference = LlmInference;
</script>
<script src="https://cdn.jsdelivr.net/gh/DenisovAV/flutter_gemma@v0.13.1/web/cache_api.js"></script>
<script src="https://cdn.jsdelivr.net/gh/DenisovAV/flutter_gemma@v0.13.1/web/opfs_helper.js"></script>
```

## Αρχικοποίηση στο Main

Η αρχικοποίηση πρέπει να γίνεται ρητά για υποστήριξη streaming:

```dart
await FlutterGemma.initialize(webStorageMode: WebStorageMode.streaming);
```

## Αντιμετώπιση Προβλημάτων WebGPU

Αν ο Chrome αναφέρει σφάλμα "Failed to request adapter" ή η εφαρμογή δεν μπορεί να χρησιμοποιήσει την κάρτα γραφικών, ακολουθήστε τα παρακάτω βήματα για να ρυθμίσετε σωστά το περιβάλλον σας:

### 1. Ενεργοποίηση Hardware Acceleration (Το πιο πιθανό)
Πολλές φορές το WebGPU απενεργοποιείται αν η επιτάχυνση υλικού είναι κλειστή:
- Πηγαίνετε στις ρυθμίσεις: `chrome://settings/system`
- Βεβαιωθείτε ότι το **"Use hardware acceleration when available"** είναι **ON**.
- Πατήστε **Relaunch** για επανεκκίνηση του προγράμματος περιήγησης.

### 2. Ρύθμιση μέσω Flags
Αν το Hardware Acceleration είναι ήδη ON, δοκιμάστε να αναγκάσετε τον Chrome να ενεργοποιήσει το WebGPU μέσω της σελίδας `chrome://flags`.

| Flag (Αναζήτηση) | Ρύθμιση | Γιατί χρειάζεται; |
| :--- | :---: | :--- |
| **Override software rendering list** | `Enabled` | **Το πιο σημαντικό.** Αν η κάρτα γραφικών σας είναι "μαυρισμένη" (blocklisted) από την Google λόγω παλαιότητας, αυτό το flag την ενεργοποιεί αναγκαστικά. |
| **Enabling WebGPU Support** | `Enabled` | Ενεργοποιεί τις βασικές λειτουργίες του WebGPU για το πρόγραμμα περιήγησης. |
| **Unsafe WebGPU Support** | `Enabled` | Απαραίτητο για κάρτες γραφικών που δεν υποστηρίζουν πλήρως τα τελευταία πρότυπα ασφαλείας, επιτρέποντας την εκτέλεση LLM. |
| **GPU rasterization** | `Enabled` | Βοηθά στη γενική επιτάχυνση υλικού και τη σωστή απόδοση γραφικών μέσω της GPU. |

> [!IMPORTANT]
> Μετά την αλλαγή των παραπάνω, πατήστε το κουμπί **Relaunch** στο κάτω μέρος της σελίδας των flags.

### 3. Έλεγχος Κατάστασης (chrome://gpu)
Μπορείτε να δείτε την ακριβή αιτία του προβλήματος πληκτρολογώντας: `chrome://gpu` στην μπάρα διευθύνσεων.
- Αναζητήστε τη γραμμή **WebGPU**. 
- Αν αναφέρει "Disabled" ή "Software only", τότε ο Chrome μπλοκάρει την πρόσβαση για λόγους ασφαλείας, ασυμβατότητας drivers ή έλλειψης hardware acceleration.

### 4. Ασφαλές Περιβάλλον (Secure Context)
Το WebGPU απαιτεί η εφαρμογή να εκτελείται σε ασφαλές περιβάλλον. Αυτό σημαίνει είτε σε `localhost` (για development) είτε μέσω **HTTPS** (για production).

> [!TIP]
> Το σύστημα πλέον διαθέτει αυτόματη μετάπτωση σε **CPU (XNNPACK)** αν η κάρτα γραφικών δεν είναι διαθέσιμη. Αν δείτε το μήνυμα `GPU ENGAGEMENT FAILED`, η εφαρμογή θα συνεχίσει να λειτουργεί χρησιμοποιώντας τον επεξεργαστή, αν και η ταχύτητα απόκρισης του AI θα είναι χαμηλότερη.
