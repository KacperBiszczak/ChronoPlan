# ChronoPlan

**ChronoPlan** to aplikacja mobilna do kompleksowego planowania i koordynacji wydarzeń. Projekt ma na celu ułatwienie organizacji eventów poprzez połączenie harmonogramu, listy zadań, uczestników, budżetu oraz komunikacji w jednym miejscu.

Aplikacja może być wykorzystywana do organizacji m.in. imprez prywatnych, spotkań, wyjazdów, konferencji, wydarzeń firmowych oraz innych przedsięwzięć wymagających współpracy wielu osób.

---

## 📌 Główne założenia projektu

Organizacja wydarzenia często wymaga korzystania z wielu osobnych narzędzi: komunikatorów, arkuszy kalkulacyjnych, kalendarzy oraz list zadań. ChronoPlan rozwiązuje ten problem, udostępniając jedno centralne miejsce do zarządzania wszystkimi elementami eventu.

Najważniejsze cele aplikacji:

* centralizacja informacji o wydarzeniu,
* łatwiejsza koordynacja uczestników,
* zarządzanie zadaniami i odpowiedzialnościami,
* kontrola terminów oraz harmonogramu,
* planowanie budżetu i śledzenie wydatków,
* ograniczenie chaosu komunikacyjnego podczas organizacji wydarzeń.

---

## ✨ Funkcjonalności

### 🗓️ Zarządzanie wydarzeniami

* tworzenie wydarzeń,
* edycja podstawowych informacji o wydarzeniu,
* określanie daty, godziny i miejsca,
* podgląd szczegółów wydarzenia,
* zarządzanie listą uczestników.

### ✅ Zadania i harmonogram

* tworzenie zadań przypisanych do wydarzenia,
* przypisywanie zadań konkretnym uczestnikom,
* ustawianie terminów wykonania,
* oznaczanie statusów zadań,
* kontrola postępów przygotowań.

### 👥 Koordynacja uczestników

* zapraszanie osób do wydarzenia,
* określanie odpowiedzialności użytkowników,
* wspólna organizacja eventu,
* przejrzysty podział obowiązków.

### 💬 Komunikacja

* komentarze lub wiadomości związane z wydarzeniem lub zadaniami,
* możliwość wymiany informacji w kontekście konkretnego eventu,
* ograniczenie potrzeby korzystania z wielu osobnych komunikatorów.

### 💰 Budżet i wydatki

* planowanie budżetu wydarzenia,
* dodawanie wydatków,
* kontrolowanie kosztów,
* podsumowanie finansów wydarzenia.

### 🔔 Powiadomienia

* przypomnienia o zadaniach,
* przypomnienia o zbliżających się terminach,
* powiadomienia związane ze zmianami w wydarzeniu.

---

## 🛠️ Technologie

### Frontend

* **Flutter**
* **Dart**
* responsywny interfejs użytkownika,
* obsługa widoków mobilnych,
* komunikacja z API backendowym.

### Backend

* **Node.js**
* **Express.js**
* **TypeScript**
* REST API
* obsługa logiki biznesowej aplikacji.

### Baza danych

* **PostgreSQL**
* relacyjne przechowywanie danych,
* obsługa wydarzeń, użytkowników, zadań, budżetów i powiązań między nimi.

### ORM

* **Prisma**
* modelowanie struktury bazy danych,
* łatwiejsza komunikacja backendu z PostgreSQL.

### Możliwe integracje

* Google Calendar API,
* Firebase Cloud Messaging lub inne narzędzie do powiadomień push,
* integracje płatności, np. Stripe lub PayPal.

---

## 🧱 Przykładowa struktura projektu

```bash
ChronoPlan/
├── frontend/
│   ├── lib/
│   ├── assets/
│   ├── pubspec.yaml
│   └── README.md
│
├── backend/
│   ├── src/
│   ├── prisma/
│   ├── package.json
│   └── README.md
│
├── README.md
└── .gitignore
```

---

## 🚀 Uruchomienie projektu

### Wymagania

Przed uruchomieniem projektu upewnij się, że masz zainstalowane:

* Flutter SDK,
* Dart,
* Node.js,
* npm lub yarn,
* PostgreSQL,
* Git.

---

## 📱 Uruchomienie frontendu

```bash
cd frontend
flutter pub get
flutter run
```

---

## 🌐 Uruchomienie backendu

```bash
cd backend
npm install
```

Skonfiguruj plik `.env`:

```env
DATABASE_URL="postgresql://user:password@localhost:5432/chronoplan"
JWT_SECRET="your_secret_key"
PORT=3000
```

Uruchom migracje Prisma:

```bash
npx prisma migrate dev
```

Uruchom serwer developerski:

```bash
npm run dev
```

---

## 🔐 Autoryzacja

Aplikacja może wykorzystywać autoryzację użytkowników opartą o tokeny JWT. Dzięki temu możliwe jest zabezpieczenie endpointów oraz przypisywanie wydarzeń, zadań i budżetów do konkretnych kont użytkowników.

Przykładowe funkcje związane z kontem użytkownika:

* rejestracja,
* logowanie,
* przechowywanie tokenu,
* autoryzacja zapytań do API,
* dostęp do wydarzeń użytkownika.

---

## 📊 Porównanie z innymi rozwiązaniami

| Funkcja                  | Google Calendar | Trello | Eventbrite | ChronoPlan |
| ------------------------ | --------------- | ------ | ---------- | ---------- |
| Planowanie wydarzeń      | ✅               | ❌      | ✅          | ✅          |
| Zadania i harmonogram    | ❌               | ✅      | ❌          | ✅          |
| Powiadomienia            | ✅               | ✅      | ✅          | ✅          |
| Komunikacja wewnętrzna   | ❌               | ❌      | ✅          | ✅          |
| Budżet i wydatki         | ❌               | ❌      | ❌          | ✅          |
| Koordynacja uczestników  | ❌               | ❌      | ✅          | ✅          |
| Głosowanie nad terminami | ❌               | ❌      | ❌          | ✅          |

---

## 🧭 Roadmap

* [ ] rejestracja i logowanie użytkowników,
* [ ] tworzenie oraz edycja wydarzeń,
* [ ] zapraszanie uczestników,
* [ ] moduł zadań,
* [ ] przypisywanie zadań do użytkowników,
* [ ] moduł budżetu,
* [ ] komentarze przy zadaniach,
* [ ] powiadomienia push,
* [ ] integracja z Google Calendar,
* [ ] głosowanie nad terminami wydarzenia,
* [ ] panel administratora wydarzenia,
* [ ] wersja webowa aplikacji.

---

## 📱 Zastosowanie aplikacji

ChronoPlan może sprawdzić się przy organizacji:

* imprez rodzinnych,
* spotkań ze znajomymi,
* wyjazdów grupowych,
* konferencji,
* warsztatów,
* wydarzeń firmowych,
* projektów wymagających koordynacji wielu osób.

---

## 🎯 Przewaga projektu

Największą zaletą ChronoPlan jest połączenie kilku obszarów organizacji wydarzeń w jednej aplikacji:

* planowanie terminów,
* zarządzanie zadaniami,
* komunikacja,
* kontrola budżetu,
* koordynacja uczestników,
* możliwość integracji z zewnętrznymi narzędziami.

Dzięki temu użytkownik nie musi przełączać się między wieloma aplikacjami, a wszystkie najważniejsze informacje dotyczące wydarzenia znajdują się w jednym miejscu.

---

## 👨‍💻 Autor

Projekt tworzony w ramach pracy inżynierskiej / projektu zaliczeniowego.

**Autor:** Kacper Biszczak
**Nazwa projektu:** ChronoPlan
**Organizacja:** KBLabs

---

## 📄 Licencja

Ten projekt jest przeznaczony do celów edukacyjnych.
Informacje o licencji można uzupełnić w późniejszym etapie rozwoju repozytorium.

Przykład:

```text
MIT License
```

---

## 📌 Status projektu

Projekt znajduje się w fazie rozwoju. Poszczególne funkcjonalności mogą być stopniowo dodawane, modyfikowane oraz rozbudowywane.
::: 
