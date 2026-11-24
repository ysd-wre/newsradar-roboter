// ===== Modelle.swift =====
import Foundation

/// Eine Nachrichtenquelle (RSS-, Atom- oder RDF-Feed).
struct Quelle: Codable, Identifiable, Hashable {
    var id: String { url }
    var name: String
    var url: String
    var aktiv: Bool = true
    var gruppe: String = "Eigene"
    var ressort: Ressort? = nil
}

enum Ressort: String, Codable, CaseIterable, Identifiable {
    case politik = "Politik", welt = "Welt", wirtschaft = "Wirtschaft", technik = "Technik"
    case wissen = "Wissen", sport = "Sport", kultur = "Kultur", panorama = "Panorama"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .politik: return "building.columns"
        case .welt: return "globe.europe.africa"
        case .wirtschaft: return "chart.line.uptrend.xyaxis"
        case .technik: return "cpu"
        case .wissen: return "atom"
        case .sport: return "figure.run"
        case .kultur: return "theatermasks"
        case .panorama: return "newspaper"
        }
    }
}

/// Eine einzelne Schlagzeile aus einem Feed.
struct Schlagzeile: Codable, Identifiable, Hashable {
    var id: String            // Link
    var titel: String
    var anriss: String
    var quelle: String
    var link: String
    var datum: Date
    var ressort: Ressort?
    var suchthema: String?
    var zeitUnsicher: Bool?   // Feed gibt allen Meldungen dieselbe Uhrzeit
}

/// Ein Ereignis, über das eine oder mehrere Quellen berichten, plus die daraus geschriebene Meldung.
struct Thema: Codable, Identifiable, Hashable {
    var id: String
    var angelegt: Date
    var aktualisiert: Date
    var ressort: Ressort
    var suchthema: String?
    var meldungen: [Schlagzeile]
    var artikel: Artikel?
    var gelesen: Bool = false

    var quellen: [String] {
        var gesehen = Set<String>()
        return meldungen.map(\.quelle).filter { gesehen.insert($0).inserted }
    }
    /// Wie viele Redaktionen unabhängig berichten: wortgleiche Agenturmeldungen zählen nur einmal.
    var unabhaengig: Int {
        var gruppen: [(woerter: Set<String>, quellen: Set<String>)] = []
        for m in meldungen {
            let w = Set(Text.woerter(Text.dachzeile(m.titel).1))
            if let i = gruppen.firstIndex(where: { g in
                g.quellen.contains(m.quelle) || Double(g.woerter.intersection(w).count) / Double(max(1, g.woerter.union(w).count)) >= 0.8
            }) { gruppen[i].quellen.insert(m.quelle); gruppen[i].woerter.formUnion(w.count < 3 ? [] : w) }
            else { gruppen.append((w, [m.quelle])) }
        }
        return gruppen.count
    }
    var titel: String { artikel?.titel ?? meldungen.first?.titel ?? "" }
    var letzteMeldung: Date { (meldungen.filter { $0.zeitUnsicher != true }.map(\.datum).max() ?? meldungen.map(\.datum).max()) ?? angelegt }

    /// Wie wichtig: viele Quellen nach oben, Älteres sinkt ab.
    func gewicht(jetzt: Date = Date()) -> Double {
        let alter = max(0, jetzt.timeIntervalSince(letzteMeldung)) / 3600
        return (Double(unabhaengig) + 0.25 * Double(quellen.count)) * pow(0.5, alter / 10)
    }
}

struct Artikel: Codable, Hashable {
    var titel: String
    var absaetze: [String]
    var geschrieben: Date
    var quellenAnzahl: Int
    var ausKI: Bool
    var ueberarbeitet: Bool = false
}

struct Einstellungen: Codable {
    var minuten: Int = 10
    var mindestQuellen: Int = 2
    var mitteilungen: Bool = false
    var eilAb: Int = 6
    var suchthemen: [String] = []
    var quellen: [Quelle] = Quelle.vorgabe
}

extension Quelle {
    static let vorgabe: [Quelle] = [
        .init(name: "Tagesschau", url: "https://www.tagesschau.de/index~rss2.xml", gruppe: "Deutschland"),
        .init(name: "ZDFheute", url: "https://www.zdfheute.de/rss/zdf/nachrichten", gruppe: "Deutschland"),
        .init(name: "Deutschlandfunk", url: "https://www.deutschlandfunk.de/nachrichten-100.rss", gruppe: "Deutschland"),
        .init(name: "Deutsche Welle", url: "https://rss.dw.com/rdf/rss-de-all", gruppe: "Deutschland"),
        .init(name: "Spiegel", url: "https://www.spiegel.de/schlagzeilen/index.rss", gruppe: "Deutschland"),
        .init(name: "Zeit", url: "https://newsfeed.zeit.de/index", gruppe: "Deutschland"),
        .init(name: "FAZ", url: "https://www.faz.net/rss/aktuell/", gruppe: "Deutschland"),
        .init(name: "Süddeutsche", url: "https://rss.sueddeutsche.de/rss/Topthemen", gruppe: "Deutschland"),
        .init(name: "Welt", url: "https://www.welt.de/feeds/topnews.rss", gruppe: "Deutschland"),
        .init(name: "n-tv", url: "https://www.n-tv.de/rss", gruppe: "Deutschland"),
        .init(name: "Bild", url: "https://www.bild.de/feed/home.xml", gruppe: "Deutschland"),
        .init(name: "Bild", url: "https://www.bild.de/feed/news.xml", gruppe: "Deutschland"),   // Blaulicht und Inland; gleicher Name = zählt als eine Redaktion
        .init(name: "Stern", url: "https://www.stern.de/feed/standard/all/", gruppe: "Deutschland"),
        .init(name: "taz", url: "https://taz.de/!p4608;rss/", gruppe: "Deutschland"),
        .init(name: "Tagesspiegel", url: "https://www.tagesspiegel.de/contentexport/feed/home", gruppe: "Deutschland"),
        .init(name: "Der Standard", url: "https://www.derstandard.at/rss", gruppe: "Österreich und Schweiz"),
        .init(name: "ORF", url: "https://rss.orf.at/news.xml", gruppe: "Österreich und Schweiz"),
        .init(name: "NZZ", url: "https://www.nzz.ch/recent.rss", gruppe: "Österreich und Schweiz"),
        .init(name: "SRF", url: "https://www.srf.ch/news/bnf/rss/1646", gruppe: "Österreich und Schweiz"),
        .init(name: "Handelsblatt", url: "https://www.handelsblatt.com/contentexport/feed/top-themen", gruppe: "Fachmedien", ressort: .wirtschaft),
        .init(name: "manager magazin", url: "https://www.manager-magazin.de/news/index.rss", gruppe: "Fachmedien", ressort: .wirtschaft),
        .init(name: "heise", url: "https://www.heise.de/rss/heise-atom.xml", gruppe: "Fachmedien", ressort: .technik),
        .init(name: "Golem", url: "https://rss.golem.de/rss.php?feed=RSS2.0", gruppe: "Fachmedien", ressort: .technik),
        .init(name: "t3n", url: "https://t3n.de/rss.xml", gruppe: "Fachmedien", ressort: .technik),
        .init(name: "Spektrum", url: "https://www.spektrum.de/alias/rss/spektrum-de-rss-feed/996406", gruppe: "Fachmedien", ressort: .wissen),
        .init(name: "Sportschau", url: "https://www.sportschau.de/index~rss2.xml", gruppe: "Fachmedien", ressort: .sport),
        .init(name: "kicker", url: "https://newsfeed.kicker.de/news/aktuell", gruppe: "Fachmedien", ressort: .sport),
        .init(name: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml", aktiv: false, gruppe: "International (Englisch)", ressort: .welt),
        .init(name: "The Guardian", url: "https://www.theguardian.com/world/rss", aktiv: false, gruppe: "International (Englisch)", ressort: .welt),
        .init(name: "New York Times", url: "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml", aktiv: false, gruppe: "International (Englisch)", ressort: .welt),
        .init(name: "Al Jazeera", url: "https://www.aljazeera.com/xml/rss/all.xml", aktiv: false, gruppe: "International (Englisch)", ressort: .welt),
    ]
}

// ===== Feeds.swift =====
import Foundation

/// Holt Feeds ab und macht daraus Schlagzeilen.
enum Feeds {
    static let sitzung: URLSession = {
        let k = URLSessionConfiguration.ephemeral
        k.timeoutIntervalForRequest = 20
        k.timeoutIntervalForResource = 40
        k.httpShouldSetCookies = false
        k.httpCookieAcceptPolicy = .never
        k.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: k)
    }()

    struct Ergebnis { var quelle: Quelle; var meldungen: [Schlagzeile]; var fehler: String?; var unveraendert = false }

    static func suchQuelle(_ thema: String) -> Quelle {
        var k = URLComponents(string: "https://news.google.com/rss/search")!
        k.queryItems = [.init(name: "q", value: thema + " when:2d"), .init(name: "hl", value: "de"),
                        .init(name: "gl", value: "DE"), .init(name: "ceid", value: "DE:de")]
        return Quelle(name: "Suche: " + thema, url: k.url!.absoluteString, gruppe: "Suche")
    }

    /// `marken` merkt sich ETag/Last-Modified je Feed, damit Unverändertes nicht erneut geladen wird.
    static func hole(_ q: Quelle, suchthema: String? = nil, marken: Marken) async -> Ergebnis {
        guard let url = URL(string: q.url), ["http", "https"].contains(url.scheme ?? "") else {
            return .init(quelle: q, meldungen: [], fehler: "Ungültige Adresse")
        }
        var anfrage = URLRequest(url: url)
        anfrage.setValue("NewsRadar/1.0 (RSS-Reader)", forHTTPHeaderField: "User-Agent")
        anfrage.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        if let m = await marken.lies(q.url) {
            if let e = m.etag { anfrage.setValue(e, forHTTPHeaderField: "If-None-Match") }
            if let g = m.geaendert { anfrage.setValue(g, forHTTPHeaderField: "If-Modified-Since") }
        }
        do {
            let (daten, antwort) = try await sitzung.data(for: anfrage)
            let http = antwort as? HTTPURLResponse
            let code = http?.statusCode ?? 0
            if code == 304 { return .init(quelle: q, meldungen: [], fehler: nil, unveraendert: true) }
            guard (200..<300).contains(code) else { return .init(quelle: q, meldungen: [], fehler: "Server meldet \(code)") }
            guard daten.count < 8_000_000 else { return .init(quelle: q, meldungen: [], fehler: "Feed zu groß") }
            let leser = FeedLeser(quelle: q, suchthema: suchthema)
            var m = leser.lies(daten)
            if m.count >= 8, Set(m.map(\.datum)).count == 1 { for i in m.indices { m[i].zeitUnsicher = true } }
            if m.isEmpty && leser.eintraege == 0 { return .init(quelle: q, meldungen: [], fehler: "Kein lesbarer Feed") }
            await marken.setze(q.url, etag: http?.value(forHTTPHeaderField: "Etag"), geaendert: http?.value(forHTTPHeaderField: "Last-Modified"))
            return .init(quelle: q, meldungen: m, fehler: nil)
        } catch let f as URLError where f.code == .notConnectedToInternet {
            return .init(quelle: q, meldungen: [], fehler: "Kein Internet")
        } catch let f as URLError where f.code == .timedOut {
            return .init(quelle: q, meldungen: [], fehler: "Keine Antwort")
        } catch {
            return .init(quelle: q, meldungen: [], fehler: "Nicht erreichbar")
        }
    }

    static func holeAlle(_ quellen: [Quelle], suchthemen: [String], marken: Marken) async -> [Ergebnis] {
        await withTaskGroup(of: Ergebnis.self) { g in
            for q in quellen where q.aktiv { g.addTask { await hole(q, marken: marken) } }
            for s in suchthemen { g.addTask { await hole(suchQuelle(s), suchthema: s, marken: marken) } }
            var alle: [Ergebnis] = []
            for await e in g { alle.append(e) }
            return alle
        }
    }
}

actor Marken {
    private var werte: [String: (etag: String?, geaendert: String?)] = [:]
    func lies(_ u: String) -> (etag: String?, geaendert: String?)? { werte[u] }
    func setze(_ u: String, etag: String?, geaendert: String?) { werte[u] = (etag, geaendert) }
}

/// Liest RSS 2.0, RDF (RSS 1.0) und Atom.
final class FeedLeser: NSObject, XMLParserDelegate {
    let quelle: Quelle, suchthema: String?
    private(set) var eintraege = 0
    private var fertig: [Schlagzeile] = []
    private var imEintrag = false, tiefe = 0
    private var text = "", titel = "", anriss = "", link = "", datum = "", herkunft = "", kategorien: [String] = []

    init(quelle: Quelle, suchthema: String?) { self.quelle = quelle; self.suchthema = suchthema }

    func lies(_ d: Data) -> [Schlagzeile] {
        let p = XMLParser(data: d)
        p.shouldResolveExternalEntities = false
        p.shouldProcessNamespaces = true
        p.delegate = self
        p.parse()
        return fertig
    }

    func parser(_ p: XMLParser, didStartElement e: String, namespaceURI ns: String?, qualifiedName q: String?, attributes a: [String: String]) {
        text = ""
        if e == "item" || e == "entry" {
            imEintrag = true; tiefe = 0
            titel = ""; anriss = ""; link = ""; datum = ""; herkunft = ""; kategorien = []
            return
        }
        guard imEintrag else { return }
        tiefe += 1
        if e == "link", let h = a["href"], tiefe == 1, link.isEmpty || a["rel"] == "alternate" { link = h }
        if e == "category", let t = a["term"] { kategorien.append(t) }
    }
    func parser(_ p: XMLParser, foundCharacters s: String) { text += s }
    func parser(_ p: XMLParser, foundCDATA d: Data) { text += String(data: d, encoding: .utf8) ?? "" }

    func parser(_ p: XMLParser, didEndElement e: String, namespaceURI ns: String?, qualifiedName q: String?) {
        if e == "item" || e == "entry" { abschluss(); imEintrag = false; return }
        guard imEintrag else { return }
        defer { tiefe -= 1; text = "" }
        guard tiefe == 1, !(q ?? "").hasPrefix("media:") else { return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch e {
        case "title": if titel.isEmpty { titel = t }
        case "description", "summary", "abstract": if anriss.isEmpty { anriss = t }
        case "link": if link.isEmpty { link = t }
        case "pubDate", "date", "published": if datum.isEmpty { datum = t }
        case "updated": if datum.isEmpty { datum = t }
        case "source": herkunft = t
        case "category", "subject": kategorien.append(t)
        default: break
        }
    }

    private func abschluss() {
        eintraege += 1
        var ti = Text.sauber(titel)
        var an = Text.sauber(anriss)
        var name = quelle.name
        if suchthema != nil {                       // Suchtreffer: „Titel - Medium“
            if !herkunft.isEmpty {
                name = Text.sauber(herkunft)
                if ti.hasSuffix(" - " + name) { ti = String(ti.dropLast(name.count + 3)) }
            }
            an = ""
        }
        for vorsatz in ["heise+ | ", "(g+) ", "(S+) ", "SZ Plus: ", "F+ "] where ti.hasPrefix(vorsatz) { ti.removeFirst(vorsatz.count) }
        // Autorenzeile/Weiterlesen-Reste aus Anrissen entfernen
        if let r = an.range(of: #"\s*\(?(Weiterlesen|mehr\s*…|\[mehr\]|Lesen Sie mehr|\(Foto:).*$"#, options: .regularExpression) { an.removeSubrange(r) }
        an = an.replacingOccurrences(of: #"\s*mehr\s*\.\.\.$|\s*\(\s[^)]{1,60}\)\s*$"#, with: "", options: .regularExpression)
        guard let l = Text.link(link), ti.count > 12, !Text.aussortieren(ti, l) else { return }
        let jetzt = Date()
        var d = Text.datum(datum) ?? jetzt
        if d > jetzt { d = jetzt }
        guard jetzt.timeIntervalSince(d) < 36 * 3600 else { return }
        let r = Text.ressort(link: l, kategorien: kategorien, titel: ti) ?? quelle.ressort
        fertig.append(.init(id: l, titel: ti, anriss: String(an.prefix(700)), quelle: name, link: l, datum: d, ressort: r, suchthema: suchthema, zeitUnsicher: nil))
    }
}

/// Textwerkzeuge: säubern, Datum, Ressort, Wörter.
enum Text {
    static func sauber(_ s: String) -> String {
        var t = s
        for _ in 0..<2 {            // manche Feeds sind doppelt kodiert
            t = t.replacingOccurrences(of: "<[^>]{1,2000}>", with: " ", options: .regularExpression)
            t = entitaeten(t)
        }
        t = t.replacingOccurrences(of: "\u{00AD}", with: "").replacingOccurrences(of: "\u{200B}", with: "")
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static let namen = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "auml": "ä", "ouml": "ö", "uuml": "ü",
                                "Auml": "Ä", "Ouml": "Ö", "Uuml": "Ü", "szlig": "ß", "ndash": "–", "mdash": "—", "bdquo": "„", "ldquo": "“",
                                "rdquo": "”", "lsquo": "‘", "rsquo": "’", "sbquo": "‚", "laquo": "«", "raquo": "»", "hellip": "…", "euro": "€",
                                "eacute": "é", "egrave": "è", "agrave": "à", "ccedil": "ç", "shy": ""]
    private static let entRegel = try! NSRegularExpression(pattern: "&(#x?[0-9A-Fa-f]{1,6}|[A-Za-z]{2,8});")
    static func entitaeten(_ s: String) -> String {
        guard s.contains("&") else { return s }
        let ns = s as NSString
        var aus = "", pos = 0
        for m in entRegel.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            aus += ns.substring(with: NSRange(location: pos, length: m.range.location - pos))
            let k = ns.substring(with: m.range(at: 1))
            var ersatz = ns.substring(with: m.range)
            if k.hasPrefix("#") {
                let n = k.hasPrefix("#x") || k.hasPrefix("#X") ? UInt32(k.dropFirst(2), radix: 16) : UInt32(k.dropFirst())
                if let n, let u = Unicode.Scalar(n) { ersatz = String(Character(u)) }
            } else if let w = namen[k] { ersatz = w }
            aus += ersatz
            pos = m.range.location + m.range.length
        }
        return aus + ns.substring(from: pos)
    }

    static func link(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var k = URLComponents(string: t), ["http", "https"].contains(k.scheme ?? ""), k.host != nil else { return nil }
        k.fragment = nil
        k.queryItems = k.queryItems?.filter { i in !["utm_", "wt_", "ref", "xtor", "cmp", "at_"].contains { i.name.lowercased().hasPrefix($0) } }
        if k.queryItems?.isEmpty == true { k.query = nil }
        return k.string
    }

    private static let formate: [DateFormatter] = ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, d MMM yyyy HH:mm Z",
                                                  "dd MMM yyyy HH:mm:ss Z", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mmZ"].map {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = $0; return f
    }
    static func datum(_ s: String) -> Date? {
        var s = s       // deutsche Zeitzonen-Kürzel (z. B. Bild: „19:22:51 CET“) kennt DateFormatter hier nicht
        for (k, z) in [(" CEST", " +0200"), (" MESZ", " +0200"), (" CET", " +0100"), (" MEZ", " +0100")] where s.hasSuffix(k) {
            s = String(s.dropLast(k.count)) + z
        }
        for f in formate { if let d = f.date(from: s) { return d } }
        return nil
    }

    // Rätsel, Werbung, Podcasts, Ticker usw. ergeben keine Meldungen.
    private static let muell = ["anzeige:", "quiz", "podcast", "newsletter", "liveblog", "newsblog", "live-ticker", "liveticker", "newsticker", "livestream",
                                "horoskop", "lottozahlen", "gewinnzahlen", "rätsel", "sudoku", "black friday", "black week", "cyber monday", "schnäppchen", "gutschein", "rabatt",
                                "die lage am", "die bilder des tages", "was jetzt?", "im video:", "tv-programm", "die wichtigsten nachrichten", "news des tages",
                                "kolumne", "rezept", "im test:", "nachrichten am", "++ ", "ratgeber", "kommentar:", "kommentar - ", "das wetter", "tagesschau in 100", "pressestimmen",
                                "börse am", "wochenrückblick", "leserbrief", "lesetipp"]
    static func aussortieren(_ t: String, _ link: String) -> Bool {
        let k = t.lowercased(), l = link.lowercased()
        if muell.contains(where: { k.contains($0) }) { return true }
        return ["/podcast", "/quiz", "/audio/", "/video/", "/videos/", "/ratgeber/", "/anzeige", "/deals/", "/kommentar/", "/meinung/", "/live/"].contains { l.contains($0) }
    }

    private static let pfad: [(Ressort, [String])] = [
        (.sport, ["sport", "fussball", "bundesliga", "formel-1", "wintersport", "tennis", "handball"]),
        (.wirtschaft, ["wirtschaft", "finanzen", "boerse", "unternehmen", "economy", "business", "geld", "karriere", "immobilien"]),
        (.technik, ["digital", "netzwelt", "technik", "tech", "computer", "netzpolitik", "ki", "web"]),
        (.wissen, ["wissen", "wissenschaft", "gesundheit", "klima", "umwelt", "science", "natur", "medizin", "weltraum", "forschung", "oeko"]),
        (.kultur, ["kultur", "feuilleton", "unterhaltung", "leute", "lifestyle", "stil", "musik", "kino", "literatur", "medien", "film"]),
        (.welt, ["ausland", "international", "europa", "asien", "amerika", "nahost", "ukraine", "usa", "krieg-in-der-ukraine", "afrika", "welt", "world"]),
        (.politik, ["politik", "inland", "deutschland", "innenpolitik", "bundestag", "schweiz"]),
        (.panorama, ["panorama", "gesellschaft", "vermischtes", "kriminalitaet", "justiz", "regional", "chronik", "berlin", "hamburg", "unfall"]),
    ]
    static func ressort(link: String, kategorien: [String], titel: String) -> Ressort? {
        let teile = (URL(string: link)?.path ?? "").lowercased().split(whereSeparator: { "/_.".contains($0) }).map(String.init).prefix(4)
        // Innerhalb von Politik zählt der genauere Teilpfad (…/politik/ausland/… → Welt)
        var treffer: [Ressort] = []
        for t in teile { for (r, w) in pfad where w.contains(t) { treffer.append(r) } }
        if treffer.contains(.politik), treffer.contains(.welt) { return .welt }
        if let r = treffer.first { return r }
        for k in kategorien.map({ $0.lowercased() }) { for (r, w) in pfad where w.contains(k) { return r } }
        return nil
    }

    // Wörter für den Ähnlichkeitsvergleich
    static let stopp: Set<String> = Set("""
    aber alle allem allen aller alles als also am an ander andere anderem anderen anderer anderes auch auf aus bei beim bin bis bist da damit dann das dass daß dein dem den denn der des dessen deshalb dich die dies diese diesem diesen dieser dieses dir doch dort du durch ein eine einem einen einer eines einig einige er es etwas euch euer für gegen gewesen gibt hab habe haben hat hatte hatten her hier hin hinter ich ihm ihn ihnen ihr ihre ihrem ihren ihrer ihres im in indem ins ist ja jede jedem jeden jeder jedes jene jetzt kann kein keine keinem keinen können könnte machen man manche mehr mein mich mir mit muss musste müssen nach nicht nichts noch nun nur ob oder ohne sehr sein seine seinem seinen seiner seines seit selbst sich sie sind so solche soll sollen sollte sondern sonst über um und uns unser unter viel viele vom von vor während war waren warum was weg weil weiter weitere welche welchem welchen welcher wenn wer werde werden wie wieder will wir wird wirst wo wollen wollte würde würden zu zum zur zwar zwischen
    neue neuen neuer neues erste ersten erster zwei drei vier fünf jahr jahre jahren tag tage tagen heute gestern morgen woche uhr prozent mal gut groß große großen laut sagt sagte sagen geht kommt macht steht bleibt lässt sieht wegen trotz nahe rund etwa bereits kurz lang lange ab je mehrere millionen milliarden euro dollar mensch menschen dienstag montag mittwoch donnerstag freitag samstag sonntag november dezember januar februar märz april mai juni juli august september oktober
    the and for with from that this are was has have its his her after over into says said will new who why how what not but out about more than
    """.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init))

    static func woerter(_ s: String) -> [String] {
        s.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }).compactMap { w in
            let t = String(w)
            guard t.count >= 3, !stopp.contains(t) else { return nil }
            return stamm(t)
        }
    }
    /// Titelwörter mit Gewicht – die Dachzeile („Justiz:“, „Elternbefragung:“) zählt weniger als die eigentliche Überschrift.
    static func titelwoerter(_ t: String) -> [(String, Double)] {
        let (dach, rest) = dachzeile(t)
        return woerter(dach).map { ($0, 0.8) } + woerter(rest).map { ($0, 2.2) }
    }
    static func dachzeile(_ t: String) -> (String, String) {
        for trenner in [": ", " – ", " - "] {
            if let r = t.range(of: trenner), t.distance(from: t.startIndex, to: r.lowerBound) <= 38, t.distance(from: r.upperBound, to: t.endIndex) > 18 {
                return (String(t[..<r.lowerBound]), String(t[r.upperBound...]))
            }
        }
        return ("", t)
    }
    static func stamm(_ w: String) -> String {
        guard w.count > 4 else { return w }
        for e in ["ern", "em", "en", "er", "es", "e", "s", "n"] where w.hasSuffix(e) && w.count - e.count >= 4 { return String(w.dropLast(e.count)) }
        return w
    }
    static func zahlen(_ s: String) -> Set<String> {
        let r = try! NSRegularExpression(pattern: #"\d+(?:[.,:]\d+)*"#)
        let ns = s as NSString
        return Set(r.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range).replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "") })
    }
    /// Zerlegt in Sätze, ohne bei „8. Januar“, „1. FC“ oder „Dr. Meier“ zu trennen.
    static func saetze(_ s: String) -> [String] {
        var aus: [String] = []
        s.enumerateSubstrings(in: s.startIndex..., options: [.bySentences, .localized]) { t, _, _, _ in
            guard let t = t?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return }
            if let letzter = aus.last, letzter.range(of: #"\b(\d{1,2}|Mr|Mrs|Dr|Prof|Nr|St|ca|bzw|u\.a|z\.B)\.$"#, options: .regularExpression) != nil {
                aus[aus.count - 1] = letzter + " " + t
            } else { aus.append(t) }
        }
        return aus
    }
}

// ===== Buendler.swift =====
import Foundation

/// Ordnet neue Schlagzeilen bestehenden Themen zu oder eröffnet neue.
/// Verglichen werden gewichtete Wörter (seltene Wörter zählen mehr, Titelwörter doppelt).
struct Buendler {
    static let schwelle = 0.30

    private var idf: [String: Double] = [:]
    private var vektoren: [String: [String: Double]] = [:]   // Thema → Summenvektor
    private var laengen: [String: Double] = [:]
    private var kerne: [String: [Set<String>]] = [:]         // Thema → Titelwörter je Meldung
    private var verzeichnis: [String: Set<String>] = [:]     // Wort → Themen

    init(themen: [Thema], neue: [Schlagzeile]) {
        var df: [String: Int] = [:]
        let alle = themen.flatMap(\.meldungen) + neue
        for m in alle { for w in Set(Text.woerter(m.titel + " " + m.anriss)) { df[w, default: 0] += 1 } }
        let n = Double(max(alle.count, 50))
        for (w, d) in df { idf[w] = log(n / Double(d) + 1) }
        for t in themen { for m in t.meldungen { nimmAuf(m, in: t.id) } }
    }

    private func vektor(_ m: Schlagzeile) -> [String: Double] {
        var v: [String: Double] = [:]
        for (w, g) in Text.titelwoerter(m.titel) { v[w, default: 0] += g }
        for w in Text.woerter(m.anriss).prefix(40) { v[w, default: 0] += 1 }
        for (w, x) in v { v[w] = (1 + log(x)) * (idf[w] ?? 1) }
        let l = sqrt(v.values.reduce(0) { $0 + $1 * $1 })
        return l > 0 ? v.mapValues { $0 / l } : v
    }

    private mutating func nimmAuf(_ m: Schlagzeile, in id: String) {
        let v = vektor(m)
        var s = vektoren[id] ?? [:]
        for (w, x) in v { s[w, default: 0] += x; verzeichnis[w, default: []].insert(id) }
        vektoren[id] = s
        laengen[id] = sqrt(s.values.reduce(0) { $0 + $1 * $1 })
        kerne[id, default: []].append(Set(Text.woerter(m.titel)))
    }

    /// Liefert die Themen-ID oder nil, wenn das Ereignis neu ist.
    mutating func ordneZu(_ m: Schlagzeile) -> String? {
        let v = vektor(m)
        let kern = Set(Text.woerter(m.titel))
        var punkte: [String: Double] = [:]
        for (w, x) in v { for id in verzeichnis[w] ?? [] { punkte[id, default: 0] += x * (vektoren[id]?[w] ?? 0) } }
        var bester: (String, Double)?
        for (id, p) in punkte {
            let aehnlich = p / max(laengen[id] ?? 1, 0.0001)
            guard aehnlich >= Self.schwelle, aehnlich > (bester?.1 ?? 0) else { continue }
            // Mindestens zwei gemeinsame Titelwörter mit einer Meldung, oder sehr hohe Gesamtähnlichkeit
            let gemeinsam = (kerne[id] ?? []).map { $0.intersection(kern).count }.max() ?? 0
            // Bei nur einer bisherigen Meldung strenger sein, damit nichts Fremdes zusammenrutscht
            let plus = (kerne[id]?.count ?? 0) < 2 ? 0.05 : 0.0
            let reicht = (gemeinsam >= 2 && aehnlich >= Self.schwelle + plus) || aehnlich >= 0.47 + plus || (gemeinsam == 1 && aehnlich >= 0.40 + plus)
            if reicht { bester = (id, aehnlich) }
        }
        if let b = bester { nimmAuf(m, in: b.0); return b.0 }
        return nil
    }

    /// Findet Themenpaare, die sich inzwischen als dasselbe Ereignis herausgestellt haben.
    func zusammenlegen(_ ids: [String]) -> [(behalten: String, aufloesen: String)] {
        var paare: [(String, String)] = []
        var weg = Set<String>()
        for (i, a) in ids.enumerated() where !weg.contains(a) {
            for b in ids[(i + 1)...] where !weg.contains(b) {
                guard let va = vektoren[a], let vb = vektoren[b] else { continue }
                let (kl, gr) = va.count < vb.count ? (va, vb) : (vb, va)
                let p = kl.reduce(0.0) { $0 + $1.value * (gr[$1.key] ?? 0) } / max((laengen[a] ?? 1) * (laengen[b] ?? 1), 0.0001)
                guard p >= 0.40 else { continue }
                let gemeinsam = (kerne[a] ?? []).flatMap { x in (kerne[b] ?? []).map { x.intersection($0).count } }.max() ?? 0
                if gemeinsam >= 2 || p >= 0.5 { paare.append((a, b)); weg.insert(b) }
            }
        }
        return paare
    }

    mutating func eroeffne(_ m: Schlagzeile, id: String) { nimmAuf(m, in: id) }

    static func ressort(_ meldungen: [Schlagzeile]) -> Ressort {
        var stimmen: [Ressort: Double] = [:]
        for m in meldungen { if let r = m.ressort { stimmen[r, default: 0] += 1 } }
        return stimmen.max { ($0.value, $1.key.rawValue) < ($1.value, $0.key.rawValue) }?.key ?? .panorama
    }

    /// Verteilt neue Schlagzeilen auf alte und neue Themen. Nutzen die Mac-App und der Roboter.
    static func gruppiere(_ alt: [Thema], _ neu: [Schlagzeile]) -> [Thema] {
        var b = Buendler(themen: alt, neue: neu)
        var nach = Dictionary(alt.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for m in neu {
            if let id = b.ordneZu(m), nach[id] != nil {
                nach[id]!.meldungen.append(m)
                nach[id]!.aktualisiert = Date()
                if let s = m.suchthema { nach[id]!.suchthema = s }
            } else {
                let id = UUID().uuidString
                b.eroeffne(m, id: id)
                nach[id] = Thema(id: id, angelegt: Date(), aktualisiert: Date(), ressort: .panorama, suchthema: m.suchthema, meldungen: [m])
            }
        }
        // Größere Themen behalten; Themen mit fertigem Text zuerst
        let reihe = nach.values.sorted { ($0.artikel != nil ? 1 : 0, $0.meldungen.count) > ($1.artikel != nil ? 1 : 0, $1.meldungen.count) }.map(\.id)
        for p in b.zusammenlegen(reihe) {
            guard let weg = nach[p.aufloesen], nach[p.behalten] != nil else { continue }
            nach[p.behalten]!.meldungen += weg.meldungen
            if nach[p.behalten]!.suchthema == nil { nach[p.behalten]!.suchthema = weg.suchthema }
            nach[p.aufloesen] = nil
        }
        return nach.values.map { t in var t = t; t.ressort = Buendler.ressort(t.meldungen); return t }
    }
}

// ===== Online.swift =====
import CommonCrypto
import CryptoKit
import Foundation
import Security

/// Verbindung zur Online-App (GitHub Pages). Zugangsschlüssel und Passwort liegen im Schlüsselbund, nicht hier.
struct OnlineStand: Codable {
    var besitzer = ""
    var projekt = "newsradar"
    var zweig = "main"
    var aktiv = false
    var salz = Data()
    var pruefsumme = ""              // zuletzt hochgeladener Inhalt
    var letzterUpload: Date?

    var adresse: String { projekt.lowercased() == "\(besitzer).github.io".lowercased() ? "https://\(besitzer.lowercased()).github.io/" : "https://\(besitzer.lowercased()).github.io/\(projekt)/" }
}

enum Online {
    struct Fehler: Error { let text: String }
    private static let basis = ProcessInfo.processInfo.environment["NEWSRADAR_API"] ?? "https://api.github.com"

    // MARK: Inhalt

    struct Paket: Codable {
        struct M: Codable { let q: String, t: String, l: String, z: Date?, a: String? }
        struct A: Codable { let id: String, titel: String, absaetze: [String], ressort: String, signal: Int, zeit: Date, geschrieben: Date, meldungen: [M] }
        let stand: Date, artikel: [A], schlagzeilen: [M]
    }
    static func inhalt(_ themen: [Thema], jetzt: Date = Date()) -> (daten: Data, pruefsumme: String, anzahl: Int) {
        func m(_ s: Schlagzeile, _ anriss: Bool) -> Paket.M { .init(q: s.quelle, t: s.titel, l: s.link, z: s.zeitUnsicher == true ? nil : s.datum, a: anriss && !s.anriss.isEmpty ? String(s.anriss.prefix(260)) : nil) }
        let auswahl = themen.filter { $0.artikel != nil && jetzt.timeIntervalSince($0.letzteMeldung) < 48 * 3600 }
            .sorted { $0.gewicht(jetzt: jetzt) > $1.gewicht(jetzt: jetzt) }.prefix(80)
        let artikel = auswahl.map { t -> Paket.A in
            let a = t.artikel!
            return .init(id: t.id, titel: a.titel, absaetze: a.absaetze, ressort: t.ressort.rawValue, signal: t.unabhaengig, zeit: t.letzteMeldung, geschrieben: a.geschrieben,
                         meldungen: t.meldungen.filter { $0.suchthema == nil }.sorted { $0.datum > $1.datum }.prefix(25).map { m($0, !a.ausKI) })
        }
        let zeilen = themen.flatMap(\.meldungen).filter { $0.suchthema == nil }.sorted { $0.datum > $1.datum }.prefix(300).map { m($0, false) }
        let k = JSONEncoder()
        k.dateEncodingStrategy = .iso8601
        k.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let summe = summe(((try? k.encode(artikel)) ?? Data()) + ((try? k.encode(Array(zeilen))) ?? Data()))
        return ((try? k.encode(Paket(stand: jetzt, artikel: artikel, schlagzeilen: Array(zeilen)))) ?? Data(), summe, artikel.count)
    }
    static func summe(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }

    /// Die festen Dateien der Online-App aus dem App-Paket. Sie enthalten keine Nachrichten.
    static func huelle() -> [String: Data] {
        let ordner = ProcessInfo.processInfo.environment["NEWSRADAR_WEBSEITE"].map { URL(fileURLWithPath: $0) } ?? Bundle.main.resourceURL!.appendingPathComponent("Webseite")
        var d: [String: Data] = [".nojekyll": Data("\n".utf8)]
        for f in (try? FileManager.default.contentsOfDirectory(at: ordner, includingPropertiesForKeys: nil)) ?? [] where !f.lastPathComponent.hasPrefix(".") { d[f.lastPathComponent] = try? Data(contentsOf: f) }
        return d
    }

    // MARK: Verschlüsseln

    static let runden = 600_000
    static let absender = ["name": "NewsRadar", "email": "newsradar@example.invalid"]     // sonst zeigt GitHub öffentlich die E-Mail-Adresse des Nutzers
    static func zufall(_ n: Int) -> Data { var b = [UInt8](repeating: 0, count: n); _ = SecRandomCopyBytes(kSecRandomDefault, n, &b); return Data(b) }

    /// 16 gut lesbare Zeichen in Vierergruppen (rund 78 Bit): zu viel zum Durchprobieren.
    static func neuesPasswort() -> String {
        let z = Array("abcdefghjkmnpqrstuvwxyz23456789")
        var g = SystemRandomNumberGenerator()
        return (0..<4).map { _ in String((0..<4).map { _ in z.randomElement(using: &g)! }) }.joined(separator: "-")
    }
    static func schluessel(_ passwort: String, _ salz: Data) -> SymmetricKey {
        var k = [UInt8](repeating: 0, count: 32)
        let p = Array(passwort.precomposedStringWithCanonicalMapping.utf8).map { Int8(bitPattern: $0) }, s = [UInt8](salz)
        CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), p, p.count, s, s.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(runden), &k, k.count)
        return SymmetricKey(data: k)
    }
    /// Erst packen, dann mit AES-256-GCM verschlüsseln. Ohne Passwort ist die Datei nur Zufall.
    static func verschluesselt(_ d: Data, passwort: String, salz: Data) throws -> Data {
        let gepackt = try (d as NSData).compressed(using: .zlib) as Data
        let kiste = try AES.GCM.seal(gepackt, using: schluessel(passwort, salz))
        return try JSONSerialization.data(withJSONObject: ["v": 1, "runden": runden, "salz": salz.base64EncodedString(),
            "iv": Data(kiste.nonce).base64EncodedString(), "daten": (kiste.ciphertext + kiste.tag).base64EncodedString()], options: [.sortedKeys])
    }

    /// Gegenstück zu `verschluesselt`: liest einen hochgeladenen Stand zurück (für den Roboter).
    static func entschluesselt(_ d: Data, passwort: String) throws -> (paket: Paket, salz: Data) {
        func feld(_ j: [String: Any], _ n: String) -> Data? { (j[n] as? String).flatMap { Data(base64Encoded: $0) } }
        guard let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], j["runden"] as? Int == runden,
              let salz = feld(j, "salz"), let iv = feld(j, "iv"), let daten = feld(j, "daten"),
              let kiste = try? AES.GCM.SealedBox(combined: iv + daten) else { throw Fehler(text: "Der gespeicherte Stand ist unlesbar.") }
        guard let gepackt = try? AES.GCM.open(kiste, using: schluessel(passwort, salz)) else { throw Fehler(text: "Das Lesepasswort passt nicht.") }
        let l = JSONDecoder()
        l.dateDecodingStrategy = .iso8601
        return (try l.decode(Paket.self, from: try (gepackt as NSData).decompressed(using: .zlib) as Data), salz)
    }

    // MARK: Hochladen

    static func anfrage(_ art: String, _ pfad: String, _ token: String, _ inhalt: [String: Any]? = nil) async throws -> (Int, [String: Any]) {
        guard let u = URL(string: basis + pfad) else { throw Fehler(text: "Benutzername oder Projektname enthält ungültige Zeichen.") }
        var a = URLRequest(url: u, timeoutInterval: 30)
        a.httpMethod = art
        a.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        a.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        a.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        a.setValue("NewsRadar/1.0", forHTTPHeaderField: "User-Agent")
        if let inhalt { a.httpBody = try JSONSerialization.data(withJSONObject: inhalt); a.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let d: Data, r: URLResponse
        do { (d, r) = try await Feeds.sitzung.data(for: a) } catch { throw Fehler(text: "GitHub ist gerade nicht erreichbar. Prüfe deine Internetverbindung.") }
        let code = (r as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw Fehler(text: "Der Zugangsschlüssel ist ungültig oder abgelaufen.") }
        if code == 403 || code == 429 { throw Fehler(text: "Der Zugangsschlüssel darf nicht schreiben. Gib ihm bei „Contents“ das Recht „Read and write“.") }
        return (code, (try? JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? [:])
    }
    static func verlange(_ art: String, _ pfad: String, _ token: String, _ inhalt: [String: Any], _ feld: String) async throws -> String {
        let (c, a) = try await anfrage(art, pfad, token, inhalt)
        guard (200..<300).contains(c), let w = a[feld] as? String else { throw Fehler(text: "Hochladen fehlgeschlagen (Fehler \(c)).") }
        return w
    }

    /// Prüft Namen und Schlüssel und liefert den Hauptzweig des Projekts.
    static func pruefe(_ s: OnlineStand, token: String) async throws -> String {
        let erlaubt = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard !s.besitzer.isEmpty, !s.projekt.isEmpty, (s.besitzer + s.projekt).unicodeScalars.allSatisfy(erlaubt.contains) else { throw Fehler(text: "Trage Benutzername und Projekt ohne Leerzeichen ein.") }
        let (code, a) = try await anfrage("GET", "/repos/\(s.besitzer)/\(s.projekt)", token)
        if code == 404 { throw Fehler(text: "Das Projekt „\(s.besitzer)/\(s.projekt)“ wurde nicht gefunden. Prüfe die Namen und ob der Schlüssel für dieses Projekt gilt.") }
        guard code == 200 else { throw Fehler(text: "GitHub antwortet mit Fehler \(code).") }
        return a["default_branch"] as? String ?? "main"
    }

    /// Ersetzt den kompletten Inhalt durch einen einzigen neuen Stand. Es bleibt kein Verlauf alter Meldungen.
    static func ladeHoch(_ themen: [Thema], _ stand: OnlineStand, token: String, passwort: String) async throws -> OnlineStand {
        var s = stand
        let n = inhalt(themen)
        let feste = huelle()
        let gesamt = summe(Data((n.pruefsumme + s.salz.base64EncodedString() + feste.keys.sorted().map { summe(feste[$0]!) }.joined()).utf8))
        guard gesamt != s.pruefsumme else { s.letzterUpload = Date(); return s }
        let p = "/repos/\(s.besitzer)/\(s.projekt)"
        let salz = s.salz
        let geheim = try await Task.detached { try verschluesselt(n.daten, passwort: passwort, salz: salz) }.value

        // Ein ganz leeres Projekt braucht zuerst irgendeine Datei
        let (da, _) = try await anfrage("GET", p + "/git/ref/heads/\(s.zweig)", token)
        if da == 404 || da == 409 {
            let (c, _) = try await anfrage("PUT", p + "/contents/.nojekyll", token, ["message": "Start", "content": Data("\n".utf8).base64EncodedString(), "branch": s.zweig])
            guard c == 200 || c == 201 || c == 422 else { throw Fehler(text: "Das Projekt ließ sich nicht vorbereiten (Fehler \(c)).") }
        }
        var baum: [[String: Any]] = []
        for (name, d) in feste.merging(["news.json": geheim], uniquingKeysWith: { _, b in b }).sorted(by: { $0.key < $1.key }) {
            let sha = try await verlange("POST", p + "/git/blobs", token, ["content": d.base64EncodedString(), "encoding": "base64"], "sha")
            baum.append(["path": name, "mode": "100644", "type": "blob", "sha": sha])
        }
        let tree = try await verlange("POST", p + "/git/trees", token, ["tree": baum], "sha")
        let commit = try await verlange("POST", p + "/git/commits", token, ["message": "Aktueller Stand", "tree": tree, "parents": [String](), "author": absender, "committer": absender], "sha")
        _ = try await verlange("PATCH", p + "/git/refs/heads/\(s.zweig)", token, ["sha": commit, "force": true], "ref")
        s.pruefsumme = gesamt
        s.letzterUpload = Date()
        return s
    }
}

enum Schluesselbund {
    enum Was: String { case token = "github", passwort = "lesepasswort" }
    private static func suche(_ w: Was) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "NewsRadar Online", kSecAttrAccount as String: w.rawValue] }
    static func lies(_ w: Was) -> String? {
        var q = suche(w)
        q[kSecReturnData as String] = true
        var r: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func setze(_ t: String, _ w: Was) -> Bool {
        SecItemDelete(suche(w) as CFDictionary)
        var q = suche(w)
        q[kSecValueData as String] = Data(t.utf8)
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }
    static func loesche() { for w in [Was.token, .passwort] { SecItemDelete(suche(w) as CFDictionary) } }
}

// ===== Roboter.swift =====
import Foundation

/// Läuft bei GitHub und hält die Online-App aktuell, solange der Mac nichts schickt.
/// Schreibt keine eigenen Texte. Das Protokoll ist öffentlich: hier nie Meldungen oder Zugangsdaten ausgeben.
@main
enum Roboter {
    static let kennung = "Roboter"
    static let ruhe: TimeInterval = 60 * 60      // so lange gilt der Mac nach seinem letzten Upload als aktiv

    static func main() async {
        do { print(try await lauf()) }
        catch { print("Fehler: " + ((error as? Online.Fehler)?.text ?? "Unerwarteter Fehler.")); exit(1) }
    }

    static func lauf() async throws -> String {
        func wert(_ n: String) -> String { (ProcessInfo.processInfo.environment[n] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        let token = wert("ZIEL_SCHLUESSEL"), passwort = wert("LESEPASSWORT").lowercased(), ziel = wert("ZIEL_PROJEKT")
        guard !token.isEmpty, !passwort.isEmpty, !ziel.isEmpty else { throw Online.Fehler(text: "ZIEL_SCHLUESSEL oder LESEPASSWORT fehlt in den Einstellungen dieses Projekts.") }
        let p = "/repos/\(ziel)", zweig = "main", jetzt = Date()

        // Wer hat zuletzt hochgeladen, und wann?
        let (c, kopf) = try await Online.anfrage("GET", p + "/branches/\(zweig)", token)
        guard c == 200, let commit = kopf["commit"] as? [String: Any], let sha = commit["sha"] as? String, let i = commit["commit"] as? [String: Any],
              let baum = (i["tree"] as? [String: Any])?["sha"] as? String,
              let zeit = ((i["committer"] as? [String: Any])?["date"] as? String).flatMap({ ISO8601DateFormatter().date(from: $0) })
        else { throw Online.Fehler(text: "Die Online-App wurde nicht gefunden (Fehler \(c)).") }
        if wert("GITHUB_EVENT_NAME") != "workflow_dispatch", i["message"] as? String != kennung, jetzt.timeIntervalSince(zeit) < ruhe { return "Der Mac ist aktiv. Nichts zu tun." }

        let alt = try Online.entschluesselt(try await holeNachrichten(p, baum, token), passwort: passwort)
        let ergebnisse = await Feeds.holeAlle(Quelle.vorgabe, suchthemen: [], marken: Marken())
        guard ergebnisse.contains(where: { $0.fehler == nil }) else { throw Online.Fehler(text: "Keine Quelle erreichbar.") }
        let themen = neuerStand(alt.paket, ergebnisse.flatMap(\.meldungen), jetzt: jetzt)
        let n = Online.inhalt(themen, jetzt: jetzt)
        let geheim = try Online.verschluesselt(n.daten, passwort: passwort, salz: alt.salz)

        // Nur die Nachrichten ersetzen; die übrigen Dateien der Online-App bleiben, wie der Mac sie hochgeladen hat.
        let blob = try await Online.verlange("POST", p + "/git/blobs", token, ["content": geheim.base64EncodedString(), "encoding": "base64"], "sha")
        let tree = try await Online.verlange("POST", p + "/git/trees", token, ["base_tree": baum, "tree": [["path": "news.json", "mode": "100644", "type": "blob", "sha": blob]]], "sha")
        let neu = try await Online.verlange("POST", p + "/git/commits", token, ["message": kennung, "tree": tree, "parents": [String](), "author": Online.absender, "committer": Online.absender], "sha")
        let (_, danach) = try await Online.anfrage("GET", p + "/branches/\(zweig)", token)
        guard (danach["commit"] as? [String: Any])?["sha"] as? String == sha else { return "Der Mac war schneller. Sein Stand bleibt." }
        _ = try await Online.verlange("PATCH", p + "/git/refs/heads/\(zweig)", token, ["sha": neu, "force": true], "ref")
        let aus = ergebnisse.filter { $0.fehler != nil }.map { "\($0.quelle.name) (\($0.fehler!))" }
        return "Fertig: \(n.anzahl) Meldungen." + (aus.isEmpty ? "" : " Nicht erreichbar: " + aus.joined(separator: ", "))
    }

    private static func holeNachrichten(_ p: String, _ baum: String, _ token: String) async throws -> Data {
        let (_, b) = try await Online.anfrage("GET", p + "/git/trees/\(baum)", token)
        guard let e = (b["tree"] as? [[String: Any]])?.first(where: { $0["path"] as? String == "news.json" }), let sha = e["sha"] as? String else { throw Online.Fehler(text: "Die Online-App enthält noch keine Nachrichten.") }
        let (_, d) = try await Online.anfrage("GET", p + "/git/blobs/\(sha)", token)
        guard let t = d["content"] as? String, let daten = Data(base64Encoded: t, options: .ignoreUnknownCharacters) else { throw Online.Fehler(text: "Die Nachrichten ließen sich nicht laden.") }
        return daten
    }

    /// Baut aus dem bisherigen Stand und den frischen Schlagzeilen den neuen Stand. Texte vom Mac bleiben erhalten.
    static func neuerStand(_ p: Online.Paket, _ frische: [Schlagzeile], jetzt: Date) -> [Thema] {
        func s(_ m: Online.Paket.M, _ zeit: Date, _ r: Ressort?) -> Schlagzeile {
            .init(id: m.l, titel: m.t, anriss: m.a ?? "", quelle: m.q, link: m.l, datum: m.z ?? zeit, ressort: r, suchthema: nil, zeitUnsicher: m.z == nil ? true : nil)
        }
        let alt = p.artikel.map { a -> Thema in
            let r = Ressort(rawValue: a.ressort)
            return Thema(id: a.id, angelegt: a.geschrieben, aktualisiert: a.zeit, ressort: r ?? .panorama, suchthema: nil, meldungen: a.meldungen.map { s($0, a.zeit, r) },
                         artikel: Artikel(titel: a.titel, absaetze: a.absaetze, geschrieben: a.geschrieben, quellenAnzahl: a.signal, ausKI: !a.absaetze.isEmpty))
        }
        let grenze = jetzt.addingTimeInterval(-36 * 3600)
        var links = Set(alt.flatMap(\.meldungen).map(\.link)), titel = Set(alt.flatMap(\.meldungen).map { $0.quelle + "|" + $0.titel })
        // Frische zuerst, sie haben auch Anriss und Ressort
        let neu = (frische + p.schlagzeilen.map { s($0, p.stand, nil) })
            .filter { $0.datum > grenze && links.insert($0.link).inserted && titel.insert($0.quelle + "|" + $0.titel).inserted }
            .sorted { $0.datum < $1.datum }
        let ruhend = alt.filter { $0.letzteMeldung <= grenze }
        return ruhend + Buendler.gruppiere(alt.filter { $0.letzteMeldung > grenze }, neu).map { t in
            var t = t
            let n = t.unabhaengig
            if t.artikel?.ausKI == true { t.artikel!.quellenAnzahl = n }
            else if n >= Einstellungen().mindestQuellen {
                t.artikel = Artikel(titel: t.meldungen.max { $0.datum < $1.datum }?.titel ?? "", absaetze: [], geschrieben: jetzt, quellenAnzahl: n, ausKI: false)
            }
            return t
        }
    }
}

