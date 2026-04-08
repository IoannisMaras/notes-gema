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
  import { FilesetResolver, LlmInference } from 'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-genai@0.10.27';
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

Αν λάβετε σφάλμα σχετικά με τον "GPU Adapter", ακολουθήστε τα εξής βήματα:

1.  **Chrome Flags**: Ανοίξτε το `chrome://flags` και ενεργοποιήστε τα:
    *   `#enable-unsafe-webgpu` -> **Enabled**
    *   `#ignore-gpu-blocklist` -> **Enabled**
2.  **Hardware Acceleration**: Στις ρυθμίσεις του Chrome (`chrome://settings/system`), βεβαιωθείτε ότι το **"Use graphics acceleration when available"** είναι ενεργό.
3.  **Secure Context**: Η εφαρμογή απαιτεί `localhost` ή `https://`.

Το σύστημα πλέον διαθέτει αυτόματη μετάπτωση σε **CPU (XNNPACK)** αν η κάρτα γραφικών δεν είναι διαθέσιμη, ώστε να αποφεύγεται η κατάρρευση της εφαρμογής, αν και η ταχύτητα θα είναι σημαντικά χαμηλότερη.
