# Minaret — luisterapp van Het Rechte Pad

Native app voor iOS en Android, gebouwd in Flutter met één codebase. De app toont de artikelen van hetrechtepad.nl om te lezen en te beluisteren. Alle content komt uit de publieke API van de website (`/api/v1`, zie `docs/api/openapi.yaml` in de websiterepo). De app past teksten nooit aan.

## Wat zit erin (v0.1)

- **Home**: uitgelichte carrousel, "Verder luisteren", rijen "Om naar te luisteren", "Nieuw" en een rij per hoofdonderwerp, plus filterchips.
- **Ontdek**: tegels per onderwerp met het aantal artikelen, plus subonderwerpen.
- **Mijn lijst**: verder luisteren, bewaard en beluisterd. In v1 staat dit alleen op het toestel, er zijn nog geen accounts.
- **Zoeken**: doorzoekt alle artikelen via de zoekindex van de site.
- **Artikel**: cover, auteur(s), luister- en leesduur, de knop Luister / Verder luisteren, bewaren en de volledige tekst.
- **Speler**:
  - afspelen op de achtergrond en bediening vanaf het vergrendelscherm;
  - 10 seconden terug en 30 seconden vooruit;
  - snelheid van 0,75× tot 2×;
  - slaaptimer;
  - "Lees mee";
  - verder luisteren waar je gebleven was.
- **Profiel**: licht, donker of systeemthema, standaard afspeelsnelheid en lokale gegevens wissen.
- **Gegenereerde covers** in HRP-stijl (rood #dc143c plus palette) als een artikel geen foto heeft.

Komt later: accounts met synchronisatie, betaalde content, CarPlay/Android Auto en meelezen per zin.

## Starten

Je hebt de Flutter SDK nodig (3.27 of nieuwer) en daarnaast Xcode voor iOS en/of Android Studio voor Android.

```bash
cd minaret
bash tool/setup_platforms.sh   # eenmalig: maakt ios/ en android/ en zet achtergrondaudio aan
```

Daarna start je de app tegen de lokale site (MAMP).

iOS-simulator:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8888/hetrechtepad/api/v1
```

Android-emulator (10.0.2.2 is daar je Mac):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8888/hetrechtepad/api/v1
```

Zonder `API_BASE_URL` gebruikt de app `https://www.hetrechtepad.nl/api/v1`. Dat werkt pas als de nieuwe site live staat.

Tests draaien:

```bash
flutter analyze
flutter test
```

## Audio

Audio wordt op de website gemaakt met ElevenLabs (TTS-pijplijn, backlog B10). Zet `ELEVENLABS_API_KEY` en `ELEVENLABS_VOICE_ID` in de `.env` van de site en laat de queue de audio genereren. Artikelen zonder audio tonen in de app "Audio volgt nog". De API geeft alleen audio terug die precies bij de gepubliceerde tekst hoort.

## Structuur

```
lib/
  api/        models + client (ETag-caching, nette foutmeldingen)
  state/      instellingen, mijn lijst (lokaal), speler
  theme/      tokens en thema (licht/donker)
  widgets/    covers, kaarten, rijen, carrousel, tegels, minispeler
  screens/    home, ontdek, lijst, mijn lijst, zoeken, artikel, speler, profiel
tool/         platform-setup voor achtergrondaudio
test/         unit-tests voor modellen, opmaak en mijn lijst
```

Het ontwerp is geïnspireerd op de indeling van de voorbeeldschermen in `schermen/`. Kleuren, logo en vormen zijn eigen HRP-huisstijl; er zijn geen merk-assets van de referentie overgenomen.
