import 'dotenv/config';
import bcrypt from 'bcrypt';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

if (!process.env.DATABASE_URL) {
  throw new Error('Brak DATABASE_URL w pliku .env');
}

const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL,
});

const prisma = new PrismaClient({ adapter });

const PASSWORD = 'test1234';

function toDate(value) {
  return new Date(value);
}

function roundMoney(value) {
  return Math.round(value * 100) / 100;
}

async function clearDatabase() {
  await prisma.googleCalendarEventSync.deleteMany();
  await prisma.googleCalendarConnection.deleteMany();
  await prisma.dateVote.deleteMany();
  await prisma.dateOption.deleteMany();
  await prisma.chatMessage.deleteMany();
  await prisma.settlement.deleteMany();
  await prisma.expense.deleteMany();
  await prisma.task.deleteMany();
  await prisma.eventParticipant.deleteMany();
  await prisma.event.deleteMany();
  await prisma.user.deleteMany();
}

async function main() {
  console.log('Czyszczenie bazy...');
  await clearDatabase();

  const password = await bcrypt.hash(PASSWORD, 10);

  const usersData = [
    {
      key: 'kacper',
      name: 'Kacper Biszczak',
      email: 'kacper@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
      phone: '+48 500 100 200',
      bio: 'Główny organizator wydarzeń. Najczęściej zakłada eventy i pilnuje budżetu.',
    },
    {
      key: 'ola',
      name: 'Ola Nowak',
      email: 'ola@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=47',
      phone: '+48 501 222 333',
      bio: 'Odpowiada za dekoracje, listy zakupów i kontakt z uczestnikami.',
    },
    {
      key: 'michal',
      name: 'Michał Zieliński',
      email: 'michal@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=33',
      phone: '+48 502 444 555',
      bio: 'Pomaga przy transporcie, sprawach technicznych i rozliczeniach.',
    },
    {
      key: 'natalia',
      name: 'Natalia Wiśniewska',
      email: 'natalia@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=25',
      phone: '+48 503 666 777',
      bio: 'Koordynuje harmonogram, zadania i komunikację w większych wydarzeniach.',
    },
    {
      key: 'piotr',
      name: 'Piotr Kamiński',
      email: 'piotr@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=60',
      phone: '+48 504 888 999',
      bio: 'Uczestnik testowy zapraszany do wydarzeń prywatnych i integracyjnych.',
    },
    {
      key: 'ania',
      name: 'Ania Lewandowska',
      email: 'ania@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
      phone: '+48 505 111 222',
      bio: 'Lubi planować listy zakupów, atrakcje i szczegóły organizacyjne.',
    },
    {
      key: 'bartek',
      name: 'Bartek Mazur',
      email: 'bartek@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=18',
      phone: '+48 506 333 444',
      bio: 'Pomaga przy sprzęcie, nagłośnieniu i transporcie większych rzeczy.',
    },
    {
      key: 'karolina',
      name: 'Karolina Wójcik',
      email: 'karolina@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=44',
      phone: '+48 507 555 666',
      bio: 'Testowa użytkowniczka odpowiedzialna za gości i zaproszenia.',
    },
    {
      key: 'tomek',
      name: 'Tomek Dąbrowski',
      email: 'tomek@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=52',
      phone: '+48 508 777 888',
      bio: 'Często oznaczany przy zadaniach technicznych oraz logistycznych.',
    },
    {
      key: 'magda',
      name: 'Magda Król',
      email: 'magda@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=9',
      phone: '+48 509 999 111',
      bio: 'Pomaga przy materiałach promocyjnych, dekoracjach i grafice.',
    },
    {
      key: 'pawel',
      name: 'Paweł Szymański',
      email: 'pawel@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=65',
      phone: '+48 510 222 333',
      bio: 'Uczestnik testowy z różnymi statusami zaproszeń.',
    },
    {
      key: 'ewa',
      name: 'Ewa Malinowska',
      email: 'ewa@test.pl',
      avatarUrl: 'https://i.pravatar.cc/150?img=32',
      phone: '+48 511 444 555',
      bio: 'Testowa osoba do głosowań nad terminami i czatu wydarzeń.',
    },
  ];

  console.log('Tworzenie użytkowników...');
  const users = {};

  for (const user of usersData) {
    const createdUser = await prisma.user.create({
      data: {
        name: user.name,
        email: user.email,
        password,
        avatarUrl: user.avatarUrl,
        phone: user.phone,
        bio: user.bio,
      },
    });

    users[user.key] = createdUser;
  }

  const eventsData = [
    {
      key: 'birthday',
      title: 'Urodziny Oli',
      description:
        'Impreza urodzinowa ze znajomymi. Do ogarnięcia lokal, jedzenie, muzyka, dekoracje i wspólne rozliczenie kosztów.',
      date: '2026-07-18T17:00:00.000Z',
      budgetMode: 'SHARED',
      locationName: 'Klub Loft',
      locationAddress: 'Rynek 12, 35-064 Rzeszów',
      latitude: 50.0413,
      longitude: 21.999,
      creatorKey: 'kacper',
    },
    {
      key: 'trip',
      title: 'Wyjazd w Bieszczady',
      description:
        'Weekendowy wyjazd integracyjny. Plan obejmuje nocleg, transport, zakupy, trasę spacerową i głosowanie nad najlepszym terminem.',
      date: '2026-08-07T07:00:00.000Z',
      budgetMode: 'MIXED',
      locationName: 'Solina',
      locationAddress: 'Solina, woj. podkarpackie',
      latitude: 49.4009,
      longitude: 22.4509,
      creatorKey: 'kacper',
    },
    {
      key: 'conference',
      title: 'Konferencja IT Student',
      description:
        'Mała konferencja technologiczna dla studentów. Agenda, prelegenci, sala, obsługa uczestników i materiały promocyjne.',
      date: '2026-09-15T08:00:00.000Z',
      budgetMode: 'PRIVATE',
      locationName: 'Politechnika Rzeszowska',
      locationAddress: 'al. Powstańców Warszawy 12, Rzeszów',
      latitude: 50.0209,
      longitude: 22.0007,
      creatorKey: 'natalia',
    },
    {
      key: 'grill',
      title: 'Grill integracyjny',
      description:
        'Luźne spotkanie organizacyjne połączone z grillem. Test wydarzenia z częścią zaproszonych i odrzuconych uczestników.',
      date: '2026-07-26T14:00:00.000Z',
      budgetMode: 'SHARED',
      locationName: 'Park Papieski',
      locationAddress: 'Park Papieski, Rzeszów',
      latitude: 50.0263,
      longitude: 22.0185,
      creatorKey: 'michal',
    },
    {
      key: 'wedding',
      title: 'Wieczór panieński Karoliny',
      description:
        'Organizacja wieczoru panieńskiego: rezerwacja apartamentu, atrakcje, prezent, dekoracje i plan wieczoru.',
      date: '2026-08-22T16:00:00.000Z',
      budgetMode: 'SHARED',
      locationName: 'Apartament City View',
      locationAddress: 'ul. Kopisto 8, Rzeszów',
      latitude: 50.0419,
      longitude: 22.0165,
      creatorKey: 'ola',
    },
    {
      key: 'hackathon',
      title: 'Hackathon ChronoPlan',
      description:
        'Wewnętrzny hackathon projektowy. Celem jest dopracowanie modułu budżetu, powiadomień i widoku wydarzenia.',
      date: '2026-10-03T09:00:00.000Z',
      budgetMode: 'MIXED',
      locationName: 'Coworking Space Rzeszów',
      locationAddress: 'ul. Rejtana 20, Rzeszów',
      latitude: 50.0377,
      longitude: 22.0137,
      creatorKey: 'kacper',
    },
    {
      key: 'housewarming',
      title: 'Parapetówka u Michała',
      description:
        'Domowe spotkanie po przeprowadzce. Do ustalenia lista gości, zakupy, muzyka i wspólne koszty.',
      date: '2026-07-31T18:30:00.000Z',
      budgetMode: 'SHARED',
      locationName: 'Mieszkanie Michała',
      locationAddress: 'ul. Hetmańska 45, Rzeszów',
      latitude: 50.0269,
      longitude: 22.0012,
      creatorKey: 'michal',
    },
    {
      key: 'boardgames',
      title: 'Wieczór planszówek',
      description:
        'Spotkanie planszówkowe z przekąskami. Małe wydarzenie testujące proste zadania i wydatki.',
      date: '2026-07-12T17:00:00.000Z',
      budgetMode: 'SHARED',
      locationName: 'Pub GameRoom',
      locationAddress: 'ul. 3 Maja 6, Rzeszów',
      latitude: 50.0386,
      longitude: 22.0042,
      creatorKey: 'piotr',
    },
    {
      key: 'productDemo',
      title: 'Demo aplikacji ChronoPlan',
      description:
        'Spotkanie demonstracyjne aplikacji. Pokaz tworzenia wydarzenia, zadań, budżetu, czatu i głosowań terminów.',
      date: '2026-09-28T11:00:00.000Z',
      budgetMode: 'PRIVATE',
      locationName: 'Online / Google Meet',
      locationAddress: 'Spotkanie zdalne',
      latitude: null,
      longitude: null,
      creatorKey: 'kacper',
    },
    {
      key: 'examStudy',
      title: 'Wspólna nauka do egzaminu',
      description:
        'Spotkanie organizacyjne do nauki. Podział tematów, harmonogram powtórek i materiały do przygotowania.',
      date: '2026-07-09T15:00:00.000Z',
      budgetMode: 'PRIVATE',
      locationName: 'Biblioteka',
      locationAddress: 'ul. Dąbrowskiego 33, Rzeszów',
      latitude: 50.0318,
      longitude: 21.9952,
      creatorKey: 'natalia',
    },
  ];

  console.log('Tworzenie wydarzeń...');
  const events = {};

  for (const event of eventsData) {
    const createdEvent = await prisma.event.create({
      data: {
        title: event.title,
        description: event.description,
        date: toDate(event.date),
        budgetMode: event.budgetMode,
        locationName: event.locationName,
        locationAddress: event.locationAddress,
        latitude: event.latitude,
        longitude: event.longitude,
        creatorId: users[event.creatorKey].id,
      },
    });

    events[event.key] = createdEvent;
  }

  const participantsData = [
    // Urodziny Oli
    ['birthday', 'kacper', 'ORGANIZER', 'ACCEPTED'],
    ['birthday', 'ola', 'PARTICIPANT', 'ACCEPTED'],
    ['birthday', 'michal', 'PARTICIPANT', 'ACCEPTED'],
    ['birthday', 'natalia', 'PARTICIPANT', 'ACCEPTED'],
    ['birthday', 'ania', 'PARTICIPANT', 'INVITED'],
    ['birthday', 'bartek', 'PARTICIPANT', 'DECLINED'],

    // Bieszczady
    ['trip', 'kacper', 'ORGANIZER', 'ACCEPTED'],
    ['trip', 'ola', 'PARTICIPANT', 'ACCEPTED'],
    ['trip', 'michal', 'PARTICIPANT', 'ACCEPTED'],
    ['trip', 'piotr', 'PARTICIPANT', 'INVITED'],
    ['trip', 'ania', 'PARTICIPANT', 'ACCEPTED'],
    ['trip', 'bartek', 'PARTICIPANT', 'ACCEPTED'],

    // Konferencja
    ['conference', 'natalia', 'ORGANIZER', 'ACCEPTED'],
    ['conference', 'kacper', 'PARTICIPANT', 'ACCEPTED'],
    ['conference', 'michal', 'PARTICIPANT', 'ACCEPTED'],
    ['conference', 'magda', 'PARTICIPANT', 'ACCEPTED'],
    ['conference', 'tomek', 'PARTICIPANT', 'INVITED'],
    ['conference', 'ola', 'PARTICIPANT', 'DECLINED'],

    // Grill
    ['grill', 'michal', 'ORGANIZER', 'ACCEPTED'],
    ['grill', 'kacper', 'PARTICIPANT', 'ACCEPTED'],
    ['grill', 'ola', 'PARTICIPANT', 'INVITED'],
    ['grill', 'piotr', 'PARTICIPANT', 'DECLINED'],
    ['grill', 'ania', 'PARTICIPANT', 'ACCEPTED'],
    ['grill', 'bartek', 'PARTICIPANT', 'ACCEPTED'],

    // Wieczór panieński
    ['wedding', 'ola', 'ORGANIZER', 'ACCEPTED'],
    ['wedding', 'karolina', 'PARTICIPANT', 'ACCEPTED'],
    ['wedding', 'natalia', 'PARTICIPANT', 'ACCEPTED'],
    ['wedding', 'ania', 'PARTICIPANT', 'ACCEPTED'],
    ['wedding', 'magda', 'PARTICIPANT', 'ACCEPTED'],
    ['wedding', 'ewa', 'PARTICIPANT', 'INVITED'],

    // Hackathon
    ['hackathon', 'kacper', 'ORGANIZER', 'ACCEPTED'],
    ['hackathon', 'michal', 'PARTICIPANT', 'ACCEPTED'],
    ['hackathon', 'natalia', 'PARTICIPANT', 'ACCEPTED'],
    ['hackathon', 'tomek', 'PARTICIPANT', 'ACCEPTED'],
    ['hackathon', 'bartek', 'PARTICIPANT', 'ACCEPTED'],
    ['hackathon', 'magda', 'PARTICIPANT', 'INVITED'],

    // Parapetówka
    ['housewarming', 'michal', 'ORGANIZER', 'ACCEPTED'],
    ['housewarming', 'kacper', 'PARTICIPANT', 'ACCEPTED'],
    ['housewarming', 'ola', 'PARTICIPANT', 'ACCEPTED'],
    ['housewarming', 'piotr', 'PARTICIPANT', 'ACCEPTED'],
    ['housewarming', 'pawel', 'PARTICIPANT', 'INVITED'],
    ['housewarming', 'ewa', 'PARTICIPANT', 'DECLINED'],

    // Planszówki
    ['boardgames', 'piotr', 'ORGANIZER', 'ACCEPTED'],
    ['boardgames', 'kacper', 'PARTICIPANT', 'ACCEPTED'],
    ['boardgames', 'ola', 'PARTICIPANT', 'ACCEPTED'],
    ['boardgames', 'ewa', 'PARTICIPANT', 'ACCEPTED'],
    ['boardgames', 'pawel', 'PARTICIPANT', 'INVITED'],

    // Demo
    ['productDemo', 'kacper', 'ORGANIZER', 'ACCEPTED'],
    ['productDemo', 'natalia', 'PARTICIPANT', 'ACCEPTED'],
    ['productDemo', 'michal', 'PARTICIPANT', 'ACCEPTED'],
    ['productDemo', 'magda', 'PARTICIPANT', 'ACCEPTED'],
    ['productDemo', 'bartek', 'PARTICIPANT', 'INVITED'],

    // Nauka
    ['examStudy', 'natalia', 'ORGANIZER', 'ACCEPTED'],
    ['examStudy', 'kacper', 'PARTICIPANT', 'ACCEPTED'],
    ['examStudy', 'ola', 'PARTICIPANT', 'ACCEPTED'],
    ['examStudy', 'tomek', 'PARTICIPANT', 'ACCEPTED'],
    ['examStudy', 'ewa', 'PARTICIPANT', 'INVITED'],
  ];

  console.log('Dodawanie uczestników...');
  await prisma.eventParticipant.createMany({
    data: participantsData.map(([eventKey, userKey, role, status]) => ({
      eventId: events[eventKey].id,
      userId: users[userKey].id,
      role,
      status,
    })),
  });

  const tasksData = [
    // Urodziny
    ['birthday', 'kacper', 'Zarezerwować lokal', 'Potwierdzić rezerwację klubu i zapłacić zaliczkę.', 'DONE'],
    ['birthday', 'ola', 'Kupić dekoracje', 'Balony, świeczki, girlandy i napis urodzinowy.', 'IN_PROGRESS'],
    ['birthday', 'michal', 'Przygotować playlistę', 'Playlista na start imprezy, część główną i zakończenie.', 'TODO'],
    ['birthday', 'natalia', 'Potwierdzić listę gości', 'Sprawdzić kto faktycznie przyjdzie i dopisać osoby towarzyszące.', 'TODO'],
    ['birthday', 'ania', 'Zrobić listę zakupów', 'Przekąski, napoje, tort i rzeczy jednorazowe.', 'TODO'],
    ['birthday', null, 'Odebrać tort', 'Tort do odbioru w dniu wydarzenia po godzinie 13:00.', 'TODO'],

    // Bieszczady
    ['trip', 'kacper', 'Zarezerwować nocleg', 'Wybrać domek i potwierdzić termin u właściciela.', 'IN_PROGRESS'],
    ['trip', 'michal', 'Ustalić transport', 'Sprawdzić kto jedzie autem i podzielić miejsca.', 'TODO'],
    ['trip', 'ola', 'Lista zakupów', 'Jedzenie, napoje, rzeczy na grilla i środki czystości.', 'TODO'],
    ['trip', 'ania', 'Sprawdzić atrakcje', 'Przygotować listę miejsc do odwiedzenia w okolicy Soliny.', 'TODO'],
    ['trip', 'bartek', 'Przygotować trasę', 'Zaproponować trasę spacerową na sobotę.', 'IN_PROGRESS'],
    ['trip', null, 'Potwierdzić godzinę wyjazdu', 'Ustalić wspólną godzinę startu z Rzeszowa.', 'TODO'],

    // Konferencja
    ['conference', 'natalia', 'Przygotować agendę', 'Rozpisać bloki godzinowe, przerwy i kolejność prelekcji.', 'IN_PROGRESS'],
    ['conference', 'kacper', 'Skonfigurować sprzęt', 'Projektor, mikrofony, laptop prowadzącego i internet.', 'TODO'],
    ['conference', 'michal', 'Sprawdzić nagłośnienie', 'Przetestować mikrofony i ustawienie sali.', 'TODO'],
    ['conference', 'magda', 'Materiały promocyjne', 'Przygotować plakaty, identyfikatory i grafiki do social mediów.', 'DONE'],
    ['conference', 'tomek', 'Lista uczestników', 'Przygotować listę obecności i formularz rejestracyjny.', 'TODO'],
    ['conference', null, 'Kontakt z prelegentami', 'Potwierdzić godziny i tematy wystąpień.', 'IN_PROGRESS'],

    // Grill
    ['grill', 'michal', 'Kupić węgiel i tacki', 'Węgiel, rozpałka, tacki, kubki i talerzyki.', 'TODO'],
    ['grill', 'kacper', 'Sprawdzić pogodę', 'Dzień przed wydarzeniem sprawdzić prognozę i ewentualnie zmienić miejsce.', 'TODO'],
    ['grill', 'ania', 'Przygotować sałatki', 'Ustalić składniki i przygotować dwie sałatki.', 'IN_PROGRESS'],
    ['grill', 'bartek', 'Zabrać grill elektryczny', 'Wziąć awaryjny grill elektryczny i przedłużacz.', 'TODO'],
    ['grill', null, 'Ustalić miejsce spotkania', 'Wysłać pinezkę wszystkim uczestnikom.', 'DONE'],

    // Wieczór panieński
    ['wedding', 'ola', 'Zarezerwować apartament', 'Potwierdzić rezerwację i godzinę zameldowania.', 'DONE'],
    ['wedding', 'natalia', 'Plan wieczoru', 'Rozpisać kolejność atrakcji i przerw.', 'IN_PROGRESS'],
    ['wedding', 'ania', 'Kupić dekoracje', 'Balony, serpentyny, napis i drobne dodatki.', 'TODO'],
    ['wedding', 'magda', 'Przygotować zaproszenia', 'Grafika zaproszenia i wiadomość do uczestniczek.', 'DONE'],
    ['wedding', 'karolina', 'Lista muzyki', 'Przygotować playlistę na wieczór.', 'TODO'],
    ['wedding', null, 'Zamówić przekąski', 'Wybrać catering lub zrobić listę zakupów.', 'TODO'],

    // Hackathon
    ['hackathon', 'kacper', 'Przygotować backlog', 'Lista funkcji do poprawy podczas hackathonu.', 'IN_PROGRESS'],
    ['hackathon', 'michal', 'Sprawdzić backend', 'Zweryfikować endpointy do budżetu i rozliczeń.', 'TODO'],
    ['hackathon', 'natalia', 'Przygotować scenariusz testów', 'Scenariusze przejścia po aplikacji i przypadki brzegowe.', 'TODO'],
    ['hackathon', 'tomek', 'Naprawić widok zadań', 'Poprawić puste stany, loading i błędy walidacji.', 'TODO'],
    ['hackathon', 'bartek', 'Przygotować środowisko', 'Sprawdzić Docker, bazę danych i konfigurację .env.', 'DONE'],
    ['hackathon', 'magda', 'UI ekranu szczegółów', 'Przygotować propozycję wyglądu szczegółów wydarzenia.', 'TODO'],

    // Parapetówka
    ['housewarming', 'michal', 'Lista gości', 'Potwierdzić kto przychodzi i czy ktoś bierze osobę towarzyszącą.', 'IN_PROGRESS'],
    ['housewarming', 'ola', 'Przekąski', 'Przygotować listę jedzenia i napojów.', 'TODO'],
    ['housewarming', 'kacper', 'Muzyka', 'Przygotować playlistę do salonu.', 'TODO'],
    ['housewarming', 'piotr', 'Gry imprezowe', 'Zabrać planszówki i karty.', 'DONE'],
    ['housewarming', null, 'Sprzątanie przed spotkaniem', 'Ogarnąć salon i kuchnię przed przyjściem gości.', 'TODO'],

    // Planszówki
    ['boardgames', 'piotr', 'Wybrać gry', 'Przygotować 4 gry na różną liczbę osób.', 'DONE'],
    ['boardgames', 'kacper', 'Zarezerwować stolik', 'Zadzwonić do pubu i potwierdzić rezerwację.', 'DONE'],
    ['boardgames', 'ola', 'Kupić przekąski', 'Chipsy, paluszki, napoje.', 'TODO'],
    ['boardgames', 'ewa', 'Ankieta gier', 'Zapytać uczestników, w co chcą zagrać.', 'IN_PROGRESS'],

    // Demo
    ['productDemo', 'kacper', 'Przygotować demo', 'Scenariusz prezentacji aplikacji krok po kroku.', 'IN_PROGRESS'],
    ['productDemo', 'natalia', 'Przygotować opis problemu', 'Krótko opisać brak centralizacji i chaos organizacyjny.', 'DONE'],
    ['productDemo', 'michal', 'Przetestować moduł budżetu', 'Dodać przykładowe wydatki i rozliczenia.', 'TODO'],
    ['productDemo', 'magda', 'Zrzuty ekranu', 'Przygotować grafiki z aplikacji do prezentacji.', 'TODO'],
    ['productDemo', 'bartek', 'Backup bazy', 'Przygotować kopię danych przed pokazem.', 'TODO'],

    // Nauka
    ['examStudy', 'natalia', 'Podzielić tematy', 'Rozdzielić tematy do opracowania między uczestników.', 'DONE'],
    ['examStudy', 'kacper', 'Przygotować notatki', 'Opracować najważniejsze definicje i przykłady.', 'IN_PROGRESS'],
    ['examStudy', 'ola', 'Zebrać materiały', 'Linki, prezentacje, PDF-y i stare pytania.', 'TODO'],
    ['examStudy', 'tomek', 'Quiz próbny', 'Przygotować krótkie pytania kontrolne.', 'TODO'],
    ['examStudy', null, 'Ustalić drugie spotkanie', 'Dodać propozycje terminów i zebrać głosy.', 'TODO'],
  ];

  console.log('Dodawanie zadań...');
  await prisma.task.createMany({
    data: tasksData.map(([eventKey, userKey, title, description, status]) => ({
      eventId: events[eventKey].id,
      assigneeId: userKey ? users[userKey].id : null,
      title,
      description,
      status,
    })),
  });

  const expensesData = [
    // Urodziny
    ['birthday', 'kacper', 'Zaliczka za lokal', 800, 'Lokal', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['birthday', 'ola', 'Dekoracje', 186.5, 'Dekoracje', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['birthday', 'natalia', 'Przekąski i napoje', 462.99, 'Jedzenie', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['birthday', 'michal', 'Prezent niespodzianka', 320, 'Prezent', 'ORGANIZER_ONLY', 'NONE'],
    ['birthday', 'kacper', 'Tort', 240, 'Jedzenie', 'PARTICIPANTS', 'SPLIT_EQUALLY'],

    // Bieszczady
    ['trip', 'kacper', 'Rezerwacja domku', 1500, 'Nocleg', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['trip', 'michal', 'Paliwo', 360, 'Transport', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['trip', 'ola', 'Zakupy spożywcze', 740.25, 'Jedzenie', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['trip', 'bartek', 'Bilety na atrakcję', 280, 'Atrakcje', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['trip', 'ania', 'Apteczka i drobiazgi', 96.8, 'Inne', 'PARTICIPANTS', 'SPLIT_EQUALLY'],

    // Konferencja
    ['conference', 'natalia', 'Materiały promocyjne', 720, 'Marketing', 'PARTICIPANTS', 'NONE'],
    ['conference', 'kacper', 'Wynajem sali', 1200, 'Sala', 'ORGANIZER_ONLY', 'NONE'],
    ['conference', 'magda', 'Identyfikatory', 180, 'Materiały', 'PARTICIPANTS', 'NONE'],
    ['conference', 'michal', 'Przedłużacze i adaptery', 145.5, 'Techniczne', 'PARTICIPANTS', 'NONE'],

    // Grill
    ['grill', 'michal', 'Produkty na grilla', 390.75, 'Jedzenie', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['grill', 'kacper', 'Akcesoria jednorazowe', 95.4, 'Akcesoria', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['grill', 'ania', 'Sałatki', 120.3, 'Jedzenie', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['grill', 'bartek', 'Napoje', 160, 'Napoje', 'PARTICIPANTS', 'SPLIT_EQUALLY'],

    // Wieczór panieński
    ['wedding', 'ola', 'Apartament', 1100, 'Nocleg', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['wedding', 'ania', 'Dekoracje', 260, 'Dekoracje', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['wedding', 'magda', 'Zaproszenia i grafiki', 90, 'Materiały', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['wedding', 'natalia', 'Atrakcja wieczoru', 650, 'Atrakcje', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['wedding', 'ola', 'Prezent', 480, 'Prezent', 'ORGANIZER_ONLY', 'NONE'],

    // Hackathon
    ['hackathon', 'kacper', 'Pizza dla zespołu', 310, 'Jedzenie', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['hackathon', 'bartek', 'Napoje energetyczne', 155.4, 'Napoje', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['hackathon', 'natalia', 'Materiały do testów', 80, 'Materiały', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['hackathon', 'michal', 'Domena testowa', 55, 'Techniczne', 'ORGANIZER_ONLY', 'NONE'],

    // Parapetówka
    ['housewarming', 'michal', 'Przekąski', 260.3, 'Jedzenie', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['housewarming', 'ola', 'Napoje', 210.5, 'Napoje', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['housewarming', 'piotr', 'Gry i dodatki', 120, 'Rozrywka', 'PARTICIPANTS', 'SPLIT_EQUALLY'],

    // Planszówki
    ['boardgames', 'piotr', 'Rezerwacja stolika', 80, 'Lokal', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['boardgames', 'ola', 'Przekąski', 65.7, 'Jedzenie', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['boardgames', 'ewa', 'Napoje', 48.9, 'Napoje', 'PARTICIPANTS', 'SPLIT_EQUALLY'],

    // Demo
    ['productDemo', 'kacper', 'Materiały do prezentacji', 130, 'Materiały', 'ORGANIZER_ONLY', 'NONE'],
    ['productDemo', 'magda', 'Grafiki promocyjne', 220, 'Marketing', 'ORGANIZER_ONLY', 'NONE'],
    ['productDemo', 'michal', 'Środowisko testowe', 75, 'Techniczne', 'PARTICIPANTS', 'NONE'],

    // Nauka
    ['examStudy', 'natalia', 'Druk notatek', 45.5, 'Materiały', 'PARTICIPANTS', 'NONE'],
    ['examStudy', 'kacper', 'Kawa i przekąski', 72.3, 'Jedzenie', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
    ['examStudy', 'ola', 'Zakreślacze i karteczki', 38.9, 'Materiały', 'PARTICIPANTS', 'SPLIT_EQUALLY'],
  ];

  console.log('Dodawanie wydatków...');
  await prisma.expense.createMany({
    data: expensesData.map(
      ([eventKey, paidByKey, title, amount, category, visibility, settlementType]) => ({
        eventId: events[eventKey].id,
        paidById: paidByKey ? users[paidByKey].id : null,
        title,
        amount,
        category,
        visibility,
        settlementType,
      }),
    ),
  });

  function getAcceptedParticipantKeys(eventKey) {
    return participantsData
      .filter(([participantEventKey, , , status]) => {
        return participantEventKey === eventKey && status === 'ACCEPTED';
      })
      .map(([, userKey]) => userKey);
  }

  function generateSettlements() {
    const settlementRows = [];
    const statuses = ['PENDING', 'PENDING', 'MARKED_AS_PAID', 'CONFIRMED'];

    for (const event of eventsData) {
      const eventKey = event.key;
      const acceptedUsers = getAcceptedParticipantKeys(eventKey);

      if (acceptedUsers.length < 2) {
        continue;
      }

      const balances = new Map();

      for (const userKey of acceptedUsers) {
        balances.set(userKey, 0);
      }

      const sharedExpenses = expensesData.filter(
        ([expenseEventKey, paidByKey, , , , visibility, settlementType]) =>
          expenseEventKey === eventKey &&
          paidByKey &&
          visibility === 'PARTICIPANTS' &&
          settlementType === 'SPLIT_EQUALLY' &&
          acceptedUsers.includes(paidByKey),
      );

      for (const [, paidByKey, , amount] of sharedExpenses) {
        const share = amount / acceptedUsers.length;

        for (const userKey of acceptedUsers) {
          balances.set(userKey, balances.get(userKey) - share);
        }

        balances.set(paidByKey, balances.get(paidByKey) + amount);
      }

      const debtors = [];
      const creditors = [];

      for (const [userKey, balance] of balances.entries()) {
        const roundedBalance = roundMoney(balance);

        if (roundedBalance < -0.01) {
          debtors.push({
            userKey,
            amount: Math.abs(roundedBalance),
          });
        }

        if (roundedBalance > 0.01) {
          creditors.push({
            userKey,
            amount: roundedBalance,
          });
        }
      }

      let debtorIndex = 0;
      let creditorIndex = 0;

      while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
        const debtor = debtors[debtorIndex];
        const creditor = creditors[creditorIndex];

        const amount = roundMoney(Math.min(debtor.amount, creditor.amount));

        if (amount > 0.01 && debtor.userKey !== creditor.userKey) {
          const status = statuses[settlementRows.length % statuses.length];

          settlementRows.push({
            eventId: events[eventKey].id,
            fromUserId: users[debtor.userKey].id,
            toUserId: users[creditor.userKey].id,
            amount,
            status,
            paidAt:
              status === 'MARKED_AS_PAID' || status === 'CONFIRMED'
                ? toDate('2026-08-01T12:00:00.000Z')
                : null,
            confirmedAt: status === 'CONFIRMED' ? toDate('2026-08-01T16:30:00.000Z') : null,
          });
        }

        debtor.amount = roundMoney(debtor.amount - amount);
        creditor.amount = roundMoney(creditor.amount - amount);

        if (debtor.amount <= 0.01) {
          debtorIndex++;
        }

        if (creditor.amount <= 0.01) {
          creditorIndex++;
        }
      }
    }

    return settlementRows;
  }

  console.log('Generowanie rozliczeń z wydatków...');
  const settlementsData = generateSettlements();

  if (settlementsData.length > 0) {
    await prisma.settlement.createMany({
      data: settlementsData,
    });
  }

  const dateOptionsData = [
    {
      eventKey: 'trip',
      proposedDate: '2026-08-07T07:00:00.000Z',
      votes: [
        ['kacper', 'YES'],
        ['ola', 'YES'],
        ['michal', 'YES'],
        ['ania', 'YES'],
        ['bartek', 'MAYBE'],
        ['piotr', 'MAYBE'],
      ],
    },
    {
      eventKey: 'trip',
      proposedDate: '2026-08-14T07:00:00.000Z',
      votes: [
        ['kacper', 'YES'],
        ['ola', 'MAYBE'],
        ['michal', 'NO'],
        ['ania', 'YES'],
        ['bartek', 'YES'],
        ['piotr', 'YES'],
      ],
    },
    {
      eventKey: 'trip',
      proposedDate: '2026-08-21T07:00:00.000Z',
      votes: [
        ['kacper', 'MAYBE'],
        ['ola', 'NO'],
        ['michal', 'YES'],
        ['ania', 'MAYBE'],
        ['bartek', 'YES'],
        ['piotr', 'NO'],
      ],
    },
    {
      eventKey: 'birthday',
      proposedDate: '2026-07-18T17:00:00.000Z',
      votes: [
        ['kacper', 'YES'],
        ['ola', 'YES'],
        ['michal', 'MAYBE'],
        ['natalia', 'YES'],
        ['ania', 'YES'],
      ],
    },
    {
      eventKey: 'wedding',
      proposedDate: '2026-08-22T16:00:00.000Z',
      votes: [
        ['ola', 'YES'],
        ['karolina', 'YES'],
        ['natalia', 'YES'],
        ['ania', 'YES'],
        ['magda', 'MAYBE'],
        ['ewa', 'MAYBE'],
      ],
    },
    {
      eventKey: 'wedding',
      proposedDate: '2026-08-29T16:00:00.000Z',
      votes: [
        ['ola', 'MAYBE'],
        ['karolina', 'NO'],
        ['natalia', 'YES'],
        ['ania', 'MAYBE'],
        ['magda', 'YES'],
        ['ewa', 'YES'],
      ],
    },
    {
      eventKey: 'hackathon',
      proposedDate: '2026-10-03T09:00:00.000Z',
      votes: [
        ['kacper', 'YES'],
        ['michal', 'YES'],
        ['natalia', 'YES'],
        ['tomek', 'YES'],
        ['bartek', 'YES'],
        ['magda', 'MAYBE'],
      ],
    },
    {
      eventKey: 'hackathon',
      proposedDate: '2026-10-10T09:00:00.000Z',
      votes: [
        ['kacper', 'NO'],
        ['michal', 'MAYBE'],
        ['natalia', 'YES'],
        ['tomek', 'MAYBE'],
        ['bartek', 'YES'],
        ['magda', 'YES'],
      ],
    },
    {
      eventKey: 'examStudy',
      proposedDate: '2026-07-09T15:00:00.000Z',
      votes: [
        ['natalia', 'YES'],
        ['kacper', 'YES'],
        ['ola', 'YES'],
        ['tomek', 'MAYBE'],
        ['ewa', 'MAYBE'],
      ],
    },
    {
      eventKey: 'examStudy',
      proposedDate: '2026-07-10T13:00:00.000Z',
      votes: [
        ['natalia', 'MAYBE'],
        ['kacper', 'NO'],
        ['ola', 'YES'],
        ['tomek', 'YES'],
        ['ewa', 'YES'],
      ],
    },
  ];

  console.log('Dodawanie propozycji terminów i głosów...');
  for (const option of dateOptionsData) {
    await prisma.dateOption.create({
      data: {
        eventId: events[option.eventKey].id,
        proposedDate: toDate(option.proposedDate),
        votes: {
          create: option.votes.map(([userKey, status]) => ({
            userId: users[userKey].id,
            status,
          })),
        },
      },
    });
  }

  const chatMessagesData = [
    ['birthday', 'kacper', 'Hej, lokal jest już zarezerwowany. Zostały dekoracje i playlista.'],
    ['birthday', 'ola', 'Dekoracje zamówiłam, powinny przyjść w środę.'],
    ['birthday', 'michal', 'Playlistę wrzucę jutro, dorzucę też spokojniejsze kawałki na początek.'],
    ['birthday', 'natalia', 'Potwierdzę listę gości i dam znać, kto jeszcze nie odpisał.'],
    ['birthday', 'ania', 'Mogę pomóc przy zakupach, tylko podeślijcie finalną listę.'],

    ['trip', 'kacper', 'Dodałem trzy propozycje terminu. Zagłosujcie, który weekend pasuje najlepiej.'],
    ['trip', 'ola', 'Mi najbardziej pasuje pierwszy termin, ale drugi też dam radę.'],
    ['trip', 'michal', 'Ja mogę jechać autem, mam 3 wolne miejsca.'],
    ['trip', 'ania', 'Sprawdziłam atrakcje, można zrobić trasę przy zaporze i później ognisko.'],
    ['trip', 'bartek', 'Wezmę apteczkę i powerbanki, przydadzą się na trasę.'],
    ['trip', 'piotr', 'Jeszcze nie wiem, czy dam radę, dlatego zaznaczyłem może.'],

    ['conference', 'natalia', 'Agenda jest prawie gotowa, brakuje tylko potwierdzenia jednej prelekcji.'],
    ['conference', 'kacper', 'Sprzęt sprawdzę dzień przed wydarzeniem.'],
    ['conference', 'michal', 'Dobrze byłoby mieć zapasowy kabel HDMI i listwę zasilającą.'],
    ['conference', 'magda', 'Identyfikatory są gotowe, jutro wyślę projekt do druku.'],
    ['conference', 'tomek', 'Czy lista uczestników ma być drukowana, czy tylko online?'],

    ['grill', 'michal', 'Jak będzie padać, przenosimy spotkanie pod wiatę.'],
    ['grill', 'kacper', 'Sprawdzę pogodę dzień wcześniej i dam znać na czacie.'],
    ['grill', 'ania', 'Sałatki zrobię wcześniej, tylko muszę wiedzieć ile osób finalnie będzie.'],
    ['grill', 'bartek', 'Wezmę grill elektryczny jako awaryjną opcję.'],

    ['wedding', 'ola', 'Apartament jest już potwierdzony. Możemy wejść od 16:00.'],
    ['wedding', 'natalia', 'Plan wieczoru mam rozpisany, wyślę szczegóły wieczorem.'],
    ['wedding', 'ania', 'Dekoracje zamówię dzisiaj, żeby doszły na czas.'],
    ['wedding', 'magda', 'Zaproszenie graficzne jest gotowe, mogę wrzucić wersję finalną.'],
    ['wedding', 'karolina', 'Super, dzięki za organizację!'],

    ['hackathon', 'kacper', 'Na hackathonie skupiamy się na budżecie, zadaniach i szczegółach wydarzenia.'],
    ['hackathon', 'michal', 'Sprawdzę endpointy i przygotuję przykładowe requesty.'],
    ['hackathon', 'natalia', 'Ja przygotuję scenariusze testów aplikacji.'],
    ['hackathon', 'tomek', 'Mogę poprawić widok pustych stanów i loadingi.'],
    ['hackathon', 'bartek', 'Środowisko działa, Docker i baza wstają poprawnie.'],
    ['hackathon', 'magda', 'Mogę przygotować propozycję UI pod szczegóły wydarzenia.'],

    ['housewarming', 'michal', 'Lista gości jest prawie gotowa, czekam jeszcze na dwie odpowiedzi.'],
    ['housewarming', 'ola', 'Ja ogarnę przekąski i napoje.'],
    ['housewarming', 'piotr', 'Wezmę planszówki, żeby było co robić po jedzeniu.'],
    ['housewarming', 'kacper', 'Playlistę przygotuję w Spotify i podeślę link.'],

    ['boardgames', 'piotr', 'Zarezerwowałem stolik na 17:00.'],
    ['boardgames', 'ewa', 'Zrobiłam ankietę gier, większość chce coś krótkiego na start.'],
    ['boardgames', 'ola', 'Kupię przekąski przed spotkaniem.'],
    ['boardgames', 'kacper', 'Będę chwilę wcześniej, żeby sprawdzić miejsce.'],

    ['productDemo', 'kacper', 'Demo zaczynamy od problemu rozproszonych narzędzi, potem pokazujemy funkcje.'],
    ['productDemo', 'natalia', 'Opis problemu mam gotowy, dorzuciłam też przykład z budżetem.'],
    ['productDemo', 'michal', 'Moduł budżetu warto pokazać na wydarzeniu z kilkoma wydatkami.'],
    ['productDemo', 'magda', 'Przygotuję kilka zrzutów ekranu do prezentacji.'],

    ['examStudy', 'natalia', 'Podzieliłam tematy, każdy ma swoje zagadnienia do opracowania.'],
    ['examStudy', 'kacper', 'Ja przygotuję notatki z pierwszej części.'],
    ['examStudy', 'ola', 'Zebrałam materiały i stare pytania.'],
    ['examStudy', 'tomek', 'Zrobię quiz próbny na koniec spotkania.'],
  ];

  console.log('Dodawanie wiadomości czatu...');
  await prisma.chatMessage.createMany({
    data: chatMessagesData.map(([eventKey, authorKey, content], index) => ({
      eventId: events[eventKey].id,
      authorId: users[authorKey].id,
      content,
      createdAt: toDate(`2026-07-${String(1 + (index % 20)).padStart(2, '0')}T12:${String(
        10 + (index % 45),
      ).padStart(2, '0')}:00.000Z`),
    })),
  });

  console.log('Dodawanie przykładowych integracji Google Calendar...');
  await prisma.googleCalendarConnection.createMany({
    data: [
      {
        userId: users.kacper.id,
        accessToken: 'mock_access_token_kacper',
        refreshToken: 'mock_refresh_token_kacper',
        scope: 'https://www.googleapis.com/auth/calendar.events',
        tokenType: 'Bearer',
        expiryDate: toDate('2026-12-31T23:59:59.000Z'),
      },
      {
        userId: users.natalia.id,
        accessToken: 'mock_access_token_natalia',
        refreshToken: 'mock_refresh_token_natalia',
        scope: 'https://www.googleapis.com/auth/calendar.events',
        tokenType: 'Bearer',
        expiryDate: toDate('2026-12-31T23:59:59.000Z'),
      },
      {
        userId: users.michal.id,
        accessToken: 'mock_access_token_michal',
        refreshToken: 'mock_refresh_token_michal',
        scope: 'https://www.googleapis.com/auth/calendar.events',
        tokenType: 'Bearer',
        expiryDate: toDate('2026-12-31T23:59:59.000Z'),
      },
    ],
  });

  await prisma.googleCalendarEventSync.createMany({
    data: [
      {
        eventId: events.birthday.id,
        userId: users.kacper.id,
        googleCalendarEventId: 'mock-google-event-birthday-001',
      },
      {
        eventId: events.trip.id,
        userId: users.kacper.id,
        googleCalendarEventId: 'mock-google-event-trip-001',
      },
      {
        eventId: events.conference.id,
        userId: users.natalia.id,
        googleCalendarEventId: 'mock-google-event-conference-001',
      },
      {
        eventId: events.grill.id,
        userId: users.michal.id,
        googleCalendarEventId: 'mock-google-event-grill-001',
      },
      {
        eventId: events.hackathon.id,
        userId: users.kacper.id,
        googleCalendarEventId: 'mock-google-event-hackathon-001',
      },
      {
        eventId: events.productDemo.id,
        userId: users.kacper.id,
        googleCalendarEventId: 'mock-google-event-demo-001',
      },
    ],
  });

  const counts = {
    users: await prisma.user.count(),
    events: await prisma.event.count(),
    participants: await prisma.eventParticipant.count(),
    tasks: await prisma.task.count(),
    expenses: await prisma.expense.count(),
    settlements: await prisma.settlement.count(),
    dateOptions: await prisma.dateOption.count(),
    dateVotes: await prisma.dateVote.count(),
    chatMessages: await prisma.chatMessage.count(),
    googleConnections: await prisma.googleCalendarConnection.count(),
    googleSyncs: await prisma.googleCalendarEventSync.count(),
  };

  console.log('Seed zakończony.');
  console.table(counts);
  console.log(`Hasło do wszystkich kont testowych: ${PASSWORD}`);
  console.log('Przykładowe konto: kacper@test.pl / test1234');
}

main()
  .catch((error) => {
    console.error('Seed nie powiódł się:');
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });