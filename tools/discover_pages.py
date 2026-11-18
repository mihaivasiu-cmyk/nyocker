"""Writes Nyocker/discover.json: the Discover page for every spot.

Facts were checked against the sources named on each page in November 2026.
Edit the text here, then run: python3 tools/discover_pages.py
"""
import json
from pathlib import Path

# Page colours per category: background, highlight. Paper and ink are shared.
PALETTE = {
    "bar": ("#6B4A00", "#F8B800"),
    "club": ("#6E1F47", "#FF5FA2"),
    "art": ("#0F4D63", "#4CC9F0"),
    "eat": ("#7A2E1A", "#FF7A59"),
    "thrift": ("#1D5B2E", "#5BE37D"),
    "local": ("#34305E", "#E6E3F6"),
    "lore": ("#3A0F0A", "#E8341C"),
}
PAPER, DEEP = "#F3EBD8", "#1A1530"


def L(text, english=None):
    line = {"text": text}
    if english:
        line["english"] = english
    return line


def link(title, url):
    assert url.startswith("https://"), url
    return {"title": title, "url": url}


def page(cat, place, title, subtitle, intro, lines, links=(), sources=None, note=None, list_title="Good to know"):
    brick, gold = PALETTE[cat]
    out = {
        "place": place, "title": title, "subtitle": subtitle, "intro": L(intro),
        "listTitle": list_title, "numbered": False, "lines": [L(x) for x in lines],
        "colors": {"paper": PAPER, "brick": brick, "deep": DEEP, "gold": gold},
    }
    if links:
        out["links"] = list(links)
    if sources:
        out["sources"] = sources
    if note:
        out["note"] = note
    return out


WLB = "https://welovebudapest.com"
pages = {}

pages["kerge"] = {
    "place": "ALFÖLDI UTCA 2 · JÓZSEFVÁROS",
    "title": "Kerge Egylet Rendelete",
    "subtitle": "The Kerge Society's decree",
    "note": "Written in eszperente, the Hungarian word game where every single vowel is an e.",
    "hero": "kerge-hero",
    "intro": L("Mekkmester! Gyere beljebb, leld kedved eme helyen mely nem egy szeszlegelde, de Kerge Egylet kegyhelye.",
               "Goat master! Come on in and make yourself at home. This is no booze pasture: it's the Kerge Society's sanctuary."),
    "numbered": True,
    "lines": [
        L("Rengeteg szervezett estben s reggelben lelheted kedved, de ehhez neked Kerge Egylet feljegyzett egyede kell lenned, nevedet jegyeztesd fel, s mehetsz befele.",
          "Plenty of organised nights and mornings to enjoy, but you need to be a registered member. Put your name down and walk right in."),
        L("Ne feledd, fejed felett egy emelettel rendes emberek eme percekben szenderedhetnek el. Nem kellene ezek feljelentsenek… Ne fenegyerekeskedj, zeneszerkezetedet tekerd lejjebb, de elmehetsz egy cseppet messzebre mely esetben neked bent nem tetszene.",
          "One floor above you, decent folk may be drifting off to sleep right now. Let's not get reported. No hooliganism, turn your music down, or wander a little further off if inside isn't your thing."),
        L("Megtekergetett dekkel kezedben lelj egy helyet mely erre rendeltetett.",
          "Rolled one up? Find the spot that's meant for it."),
        L("Tetszenek eme csecse szekreterek? Esetleg eme fellengetett leplek? Ne cseszd el ezeket, szeretgesd meg ezeket, mert ezek szerepe elengedhetetlen (nem egy eszetlen kecske rendezte ezt be).",
          "Like the cute cabinets? The billowing curtains? Don't wreck them, love them. They matter. (No mindless goat arranged all this.)"),
        L("Kedves emberek lesznek bent, neked sem kellene kellemetlenkedned. Ne Betmenkedj, elehelyett elegyedj el.",
          "There'll be nice people inside, so don't be unpleasant either. No playing Batman. Blend in instead."),
        L("Kellene neked esetleg segedelem? Keress keserveddel egy Kerge-bennfentest!",
          "Need a hand? Seek out a Kerge insider."),
    ],
    "closing": {"text": "Mely esetben eme szent rendelet egyetlen eleme meg lenne szege, el leszel kergettetve!",
                "english": "Break a single line of this sacred decree and you'll be chased out.",
                "note": "Kergettetve: chased off, the Kerge way."},
    "art": [
        {"image": "underbar", "afterLine": 1, "leading": False, "tilt": 7},
        {"image": "so", "afterLine": 4, "leading": True, "tilt": -6},
    ],
    "colors": {"paper": "#E8DCC0", "brick": "#9E3B1A", "deep": "#2B140D", "gold": "#E0A030"},
}

# Bars
pages["lumen"] = page("bar", "HORÁNSZKY UTCA 5 · PALOTANEGYED", "Lumen", "Café, bar and a tiny gig room",
    "The big Lumen: coffee and breakfast by day, Hungarian craft beer and wine by night, and live music in the back room.",
    ["The Lumen story started on Mikszáth tér. This bigger room opened in 2017, when the square got too small for its crowd.",
     "Jazz is a regular guest: free-improvisation nights and Budapest Jazzfest gigs have both played here.",
     "A full kitchen, so the plants aren't the only thing being fed."],
    [link("Read more", f"{WLB}/en/article/2018/03/21/big-new-lumen-lures-with-fine-coffee-and-live-music/")],
    "We Love Budapest, Offbeat Budapest, JazzNearYou")
pages["kislumen"] = page("bar", "MIKSZÁTH KÁLMÁN TÉR 2", "Kis Lumen", "Where the Lumen story began",
    "The original Lumen: a small café and photo gallery with one of the most fought-over terraces in the district.",
    ["It began as a café-gallery promoting contemporary photography, with a new exhibition every month.",
     "Students by day. On summer evenings the terrace is close to impossible to get a seat on.",
     "The square is named after writer Kálmán Mikszáth, who lived here. His limestone statue went up in 1960."],
    [link("Read more", f"{WLB}/en/venue/kis-lumen-1/")],
    "We Love Budapest, Just Budapest")
pages["brody"] = page("bar", "BRÓDY SÁNDOR UTCA 2", "Bródy Italintézet", "A beer institute by the Museum Garden",
    "Several taps and a terrace at the very start of Bródy Sándor utca, with the National Museum across the road.",
    ["The street started out as gardens outside the old city walls and was once called Brick Street.",
     "It has carried writer Sándor Bródy's name since 1949.",
     "Full of students doing important research into the taps."],
    (), "Audiala")
pages["kk"] = page("bar", "MÚZEUM KÖRÚT 4 · TREFORT KERT", "Könyvtár Klub", "University cellar pub, open to all",
    "The cellar pub students just call KK, inside ELTE's humanities campus. You don't need a student card, just the stairs.",
    ["Open to everyone, whether you study humanities, law or nothing at all.",
     "Live music turns up regularly, alongside DJ nights.",
     "In summer its little sibling, the TreffOrt Kert terrace, opens in the courtyard. Heavy rain sends everyone back down to the cellar."],
    (), "We Love Budapest, Eduline, Funzine")
pages["hintalo"] = page("bar", "BACSÓ BÉLA UTCA 15", "Hintaló Iszoda", "The rocking-horse bar",
    "Hintaló means rocking horse, and yes, there are rocking horses among the ruin-pub junk-shop decor. Five minutes from Blaha.",
    ["Two floors, Czech beer on tap and DJs on some nights, Wednesdays especially (says Lonely Planet).",
     "Bacsó Béla utca became a pedestrian street in 2022 and was fully renewed in 2024, so there's room outside.",
     "A crowd of locals and expats in roughly equal measure."],
    [link("Read more", f"{WLB}/en/venue/hintalo-iszoda-1")],
    "We Love Budapest, Lonely Planet, jozsefvaros.hu")
pages["kraken"] = page("bar", "JÓZSEF KÖRÚT 31/A", "Krak'n Town", "Budapest's first steampunk saloon",
    "Step inside and it's the year 2316: a rebel saloon where the staff play characters and the beer list is Hungarian craft.",
    ["Opened in autumn 2016 as the city's first steampunk pub.",
     "Most of the interior was made by hand. Cogwheels over circuit boards.",
     "The kitchen leans British Isles: black pudding, haggis and pâté.",
     "Runs craft beer tastings with a live blues show."],
    [link("Read the review", "https://xpatloop.com/channels/2017/01/restaurant-review--krak-n-town-steampunk-saloon-budapest.html")],
    "XpatLoop, Daily News Hungary, Budapest by Locals")
pages["zsir"] = page("bar", "KISS JÓZSEF UTCA · NÉPSZÍNHÁZ UTCA", "Zsír", "Fővárosi Kulipintyó: the capital's shack",
    "A basement pub on the corner of Kiss József utca and Népszínház utca. Spot the big ZSÍR sign in the gloom, then go down.",
    ["New owners opened it in 2022, in the space that used to be Hordo.",
     "Cheap drinks, a properly mixed crowd and zero interest in pretending.",
     "The heart of the Népszínház utca sidewalk festival, with bands playing right outside the door."],
    [link("Read more", f"{WLB}/cikk/2024/06/17/ejszakai-elet-zsir-kocsma-fovarosi-kulipintyo-nepszinhaz-utca-jozsefvaros/")],
    "We Love Budapest, HVG, Wanderlog")
pages["susuka"] = page("bar", "NAGY FUVAROS UTCA 12", "Susuka", "The dorm club that forgot to close",
    "It looks puritan when it opens in the early afternoon. As the evening goes on, the sobriety wears off and the place fills up.",
    ["A student favourite with reasonable prices.",
     "Openly LGBTQ-friendly.",
     "Deep in the Magdolna Quarter, a short walk from Teleki tér."],
    [link("Read more", f"{WLB}/hely/susuka/")],
    "We Love Budapest, Intravel")

# Clubs
pages["golya"] = page("club", "ORCZY ÚT 46-48", "Gólya", "Cooperative pub, gig venue, community house",
    "Budapest's cooperative presszó: the people pouring your beer own the place. Bar, concert hall, rooftop and community house in one old industrial building.",
    ["It started in 2013 on Bókay János utca and moved here in 2019, after the old landlord sold up.",
     "The new home is about 1,200 m², renovated DIY style by a crowd of volunteers.",
     "The programme runs from gigs and drag shows to board-game nights and conferences.",
     "It shares the building with its sibling, Kazán Community House."],
    [link("Read more", f"{WLB}/en/venue/golya-presszo-1")],
    "We Love Budapest, Spotted by Locals, Cooperative City")
pages["grund"] = page("club", "NAGY TEMPLOM UTCA 30 · CORVIN", "A Grund", "A huge pub with a tree inside",
    "A sprawling, many-roomed pub around a courtyard with a tree. It works for daytime family drinks as much as late nights.",
    ["Kid-friendly by day, with a playground in the courtyard.",
     "The building turned 150 in 2023, the same year as Budapest itself.",
     "Hosts the Grund Piac producers' and craft market."],
    [link("About the market", f"{WLB}/cikk/2023/3/23/gasztro-shopping-grund-termeloi-kezmuves-piac")],
    "We Love Budapest, Budapest by Locals")

# Art
pages["fofoto"] = page("art", "BAROSS UTCA · ABOVE FECSKE", "Főfoto", "Café, gallery, lab and photo shop",
    "A former private flat behind Kálvin tér, turned into a refuge for analogue photography. Ring the bell like you're visiting a friend.",
    ["Opened in 2020 by János Krasznai and Gábor Zsigmond.",
     "Sells film, slide projectors, photo books and cameras, and develops your rolls.",
     "Shows Hungarian contemporary and classic photography.",
     "The café side does sandwiches, pastries, coffee, beer and wine."],
    [link("Read more", f"{WLB}/en/article/2020/02/24/fofoto-transforms-a-flat-into-a-gallery-cafe-museum-and-analogue-lab-in-one/")],
    "We Love Budapest")
pages["isbn"] = page("art", "BAROSS UTCA 42", "ISBN+", "Art bookshop, gallery and video room",
    "The art bookshop that started on Víg utca outgrew its room after six and a half years, moved to Baross utca and gained a plus sign.",
    ["Founded by Beáta Istvánkó, who began it as a one-woman company.",
     "Stocks the art books, catalogues and zines ordinary bookshops never get.",
     "Has a screening room dedicated only to video works.",
     "In autumn 2026 it showed ten years of Budapest Zines' riso printing."],
    [link("Website", "https://www.isbnbooks.hu/en/")],
    "Lampoon, YKRA, Exindex, We Love Budapest, Telekom Spots")
pages["kupsus"] = page("art", "BRÓDY SÁNDOR UTCA 23/B", "Ari Kupsus Galéria", "New paintings, old furniture",
    "Finnish entrepreneur Ari Kupsus opened this gallery in 2009: contemporary art hung among early 19th-century antiques.",
    ["A new exhibition roughly every month.",
     "Funds scholarships for Academy of Fine Arts students, and one each year gets a debut solo show.",
     "Neighbours on the street include Ani Molnár Gallery and Doxa."],
    (), "XpatLoop, Rolling in Budapest, HVG")
pages["cozy"] = page("art", "VAS UTCA · NEXT TO BIHARY WATCHES", "Cozy Studio & Café", "Ceramics workshop and specialty café",
    "Three old friends opened this café-meets-pottery studio in March 2025. Drink your coffee, then come back to make the cup.",
    ["Coffee from early morning until 2pm. Workshops take over after that.",
     "Fresh mugs and bowls dry at the back before going into the in-house kiln.",
     "A minute from Blaha Lujza tér."],
    [link("Read more", f"{WLB}/en/article/2025/07/18/where-to-make-pottery-and-drink-specialty-coffee-in-budapest-cozy-studio/")],
    "We Love Budapest")
pages["museum"] = page("art", "JÓZSEF KÖRÚT 70", "Józsefvárosi Múzeum", "The district finally has a museum",
    "Józsefváros never had a local history collection of its own until this museum opened in 2024, in the old Józsefvárosi Galéria rooms.",
    ["The permanent show tells the district through objects and personal stories, not a timeline.",
     "Its 38 topics were built from items and memories donated by residents.",
     "Now and then it turns back into the old Jókai Café for Gypsy Music Café evenings.",
     "Open Tue–Wed and Sat 10–18, Thu–Fri 13–19. Check before you go."],
    [link("Read more", f"{WLB}/hely/jozsefvarosi-muzeum/")],
    "We Love Budapest, Budapest Times, jozsefvaros.hu")
pages["kazan"] = page("art", "ORCZY ÚT 46-48", "Kazán Közösségi Ház", "Community house with its own power",
    "Gólya's sibling next door, run by SZAKI, the Alliance for Community Property Development. Kazán means boiler house.",
    ["The building is a formerly abandoned transport manufacturing site, renovated with volunteers.",
     "Social and cultural organisations share the space, and the rent stays affordable thanks to community ownership.",
     "Runs the Kazán Energy Community, a co-owned local energy project."],
    [link("Read more", "https://cooperativecity.org/kazan-energy-community-budapest-community-energy-rooted-in-solidarity-and-co-ownership/")],
    "Cooperative City, Eastern Daze")

# Eats
pages["kv"] = page("eat", "VAS UTCA & KŐFARAGÓ UTCA", "kv the coffee shop", "Coffee by day, bar by night",
    "Barbi and Marci opened it in autumn 2025 on a corner Barbi spotted in an ad. The name was decided long before the place was.",
    ["Fresh sandwiches, cinnamon and cardamom buns, and pastries from Ide Süss.",
     "Evenings bring longer hours, mood lighting, short drinks and wine.",
     "A small terrace on the Kőfaragó utca side."],
    [link("Read more", f"{WLB}/hely/kv-the-coffee-shop/")],
    "We Love Budapest")
pages["apricot"] = page("eat", "BRÓDY SÁNDOR UTCA 17", "Apricot Coffee", "Specialty coffee, house blend",
    "A small specialty café in the Palace Quarter with its own Apricot Blend of Guatemalan, Colombian and Ethiopian beans.",
    ["Getting the blend right took almost half a year and 40 kg of coffee.",
     "Espresso drinks, plus V60, Aeropress and cold brew.",
     "Open Mon–Fri 7–17, Sat 8–16, closed Sunday."],
    [link("Read more", f"{WLB}/hely/apricot-coffee/")],
    "We Love Budapest, Offbeat Budapest, Go Specialty Coffee")
pages["anton"] = page("eat", "BRÓDY SÁNDOR UTCA 23/A", "Anton Coffee & Bakery", "Coffee and its own sourdough",
    "László and Ilona opened Anton in February 2020 and got famous for their baking before they even had a Facebook page.",
    ["Additive-free sourdough, laminated pastries and sweet and savoury buns.",
     "Most cakes are made without sugar, except where the recipe can't do without.",
     "Try the kanelbullar, the Swedish cinnamon buns.",
     "Same owner as the Bageri micro-bakery near Parliament."],
    [link("Read more", f"{WLB}/hely/anton-coffee-bakery/")],
    "We Love Budapest, Wanderlog")
pages["fecske"] = page("eat", "MIKSZÁTH KÁLMÁN TÉR · BAROSS UTCA", "Fecske", "Student HQ with a lunch menu",
    "A cheap, laid-back presszó with a retro look and a terrace, a stone's throw from the Szabó Ervin Library.",
    ["Weekday lunch menu at student prices.",
     "Főfoto, the analogue photo café, lives upstairs."],
    [link("Read more", "https://www.offbeatbudapest.com/places/fecske-presszo")],
    "Offbeat Budapest, We Love Budapest")
pages["csarnok"] = page("eat", "RÁKÓCZI TÉR 7-9", "Rákóczi téri vásárcsarnok", "Market hall since 1897",
    "One of five market halls opened together in 1897, the year the city shut its street markets and moved the traders indoors.",
    ["It's the everyday local market, not a show for tourists.",
     "In 2012 the district named a whole new quarter after it: Csarnoknegyed.",
     "Open Mon 6–16, Tue–Fri 6–18, Sat 6–13. Closed Sunday."],
    [link("Market website", "https://piaconline.hu/")],
    "HVG, piaconline.hu, OpenStreetMap, Time Out")
pages["kiskina"] = page("eat", "KŐBÁNYAI ÚT · GANZ-MÁVAG SITE", "Kiskína", "Little China",
    "Before the Four Tigers market was cleared, traders had already started moving across the road into the old Ganz-MÁVAG factory halls. They're still there.",
    ["A maze of shops in huge former heavy-industry halls.",
     "Small kitchens hide between the shops. Ask the people who work there where to eat.",
     "Tram 28 from Blaha Lujza tér runs along Kőbányai út."],
    [link("Read more", f"{WLB}/cikk/2023/04/19/latnivalok-es-kultura-pesten-innen-budan-tul-podcast-kinai-negyed-kiskina/")],
    "We Love Budapest, Budapest Times")

# Second hand
pages["humana"] = page("thrift", "JÓZSEF KÖRÚT 74", "Humana Vintage", "Vintage on a five-week clock",
    "One of the biggest vintage floors in the country. The entire stock is swapped every five weeks, with big sales before each change.",
    ["Near the end of a cycle, pieces can drop to a few hundred forints.",
     "There's a sister shop at Astoria, on Károly körút.",
     "Open daily 11–20, Sundays from 12."],
    [link("Read more", f"{WLB}/en/venue/humana-vintage-butik-jozsef-korut-1/")],
    "We Love Budapest, XpatLoop")
pages["prater"] = page("thrift", "PRÁTER UTCA 9", "Vintage Shop Práter", "Two shops, one owner",
    "A jumble of decades: old theatre gowns hang next to belts and scarves, with a second room full of everyday dresses.",
    ["The owner, Ibolya Blázsev, has dealt in unusual clothes for decades.",
     "Film and costume people shop here.",
     "Good hunting ground for jewellery and 50s and 60s dresses."],
    (), "XpatLoop, We Love Budapest, Lufthansa, Wanderlog")
pages["konfekcio"] = page("thrift", "JÓZSEF UTCA 16", "Konfekció", "Trash is high fashion",
    "Art historian and curator Kata Oltai's shop behind the Rákóczi tér market: animal prints, statement pieces and gloriously aimless clothes.",
    ["It started in 2016 in a 16 m² room on Víg utca.",
     "Every piece is one of a kind, so the stock changes daily.",
     "Open Wed–Fri 15–19 and Sat 14–17. Plan ahead.",
     "They often sell straight from Instagram and Facebook messages."],
    [link("Read more", f"{WLB}/en/article/2016/3/25/trash-is-high-fashion-at-budapest-s-tiny-konfekcio-boutique")],
    "We Love Budapest, Time Out")
pages["typo"] = page("thrift", "KRÚDY GYULA UTCA", "Momoko Vintage", "Formerly Typo Showroom",
    "Typo began on a gallery level under the old Corvin department store, sold from a warehouse for a while, then settled on Krúdy utca. Since winter 2025 it's called Momoko Vintage.",
    ["Curated second hand with structure, for people who find chaotic thrift shops overwhelming.",
     "Men's and women's collections with good labels.",
     "Seasonal sales are worth watching for."],
    [link("Read more", f"{WLB}/hely/typo-showroom/")],
    "We Love Budapest, Time Out")
pages["gizmo"] = page("thrift", "SOMOGYI BÉLA UTCA", "Gizmo Vintage", "Small shop, big rack",
    "A small shop with a big rack of women's clothing.",
    ["We couldn't confirm recent opening hours, so check it's open before you make the trip.",
     "Do not feed after midnight."],
    (), None)
pages["teleki"] = page("thrift", "TELEKI LÁSZLÓ TÉR 11", "Teleki téri piac + Zsibi", "Market hall and community flea market",
    "Teleki tér held the city's official junk market from 1897 to 1950. Today a renewed market hall runs the Teleki Zsibi community flea market.",
    ["Zsibi days bring clothes, homeware, electronics, books and records, with music and food stalls.",
     "2026 editions so far: 16 May and 4 July.",
     "Market hall open Mon 7–16, Tue–Fri 7–17, Sat 6–14.",
     "The park on the square was renovated together with residents, who formed an association to look after it."],
    [link("Latest Zsibi", "https://jozsefvaros.hu/english/news-in-the-district/2026/06/summer-treasure-hunt-at-teleki-market/")],
    "jozsefvaros.hu, We Love Budapest, UNA")

# Local
pages["szabo"] = page("local", "SZABÓ ERVIN TÉR 1", "Szabó Ervin Library", "A library in a palace",
    "The central branch of Budapest's biggest library network sits in the neo-baroque Wenckheim Palace, finished in 1889.",
    ["The city bought the palace in 1927. After four years of conversion, the library opened here on 21 April 1931.",
     "The reading rooms keep the palace's character, from a gold room to an old smoking room with a spiral staircase.",
     "János Fadrusz's sculpted miners hold up the entrance."],
    [link("Wikipedia", "https://en.wikipedia.org/wiki/Metropolitan_Ervin_Szab%C3%B3_Library")],
    "Wikipedia, We Love Budapest")
pages["horvath"] = page("local", "HORVÁTH MIHÁLY TÉR", "Horváth Mihály tér", "The district's party square",
    "Baross utca splits it into a church side and a school side. This is where Józsefváros does its seasonal celebrations.",
    ["Advent means Térvarázs: weekend concerts and family programmes.",
     "A free 300 m² ice rink usually runs for about two months over winter.",
     "In spring there's a craft and plant market.",
     "The southern side is being redesigned after a resident survey that closed in January 2026."],
    [link("Térvarázs", "https://jozsefvaros.hu/?p=185911")],
    "jozsefvaros.hu")
pages["matyas"] = page("local", "MÁTYÁS TÉR · MAGDOLNA QUARTER", "Mátyás tér", "Heart of the Magdolna Quarter",
    "Once home to Jewish craftsmen and Roma musician families, the square went from run-down to lively after a renewal.",
    ["First marked on an 1830 map as Frühlingsfeld (Tavaszmező). It has been Mátyás tér since 1874.",
     "In the 1838 flood it stood under as much as three metres of water.",
     "Writer Iván Mándy loved it, and film crews still come to shoot.",
     "Stage of the Night of Gypsy Musicians."],
    [link("The square's story", f"{WLB}/cikk/2024/02/08/latnivalok-es-kultura-matyas-ter-tortenete-jozsefvaros-viii-kerulet/")],
    "We Love Budapest, Kristin Faurest: Ten Spaces, jozsefvaros.hu")
pages["fuvesz"] = page("local", "ILLÉS UTCA 25", "Füvészkert", "The country's oldest botanic garden",
    "Founded in 1771 and on this spot since 1847: 3.5 hectares of garden and 2,000 m² of greenhouses hidden behind the blocks.",
    ["More than 8,000 plant species.",
     "It's the garden from The Paul Street Boys. The novel is why the old name Füvészkert stuck.",
     "Ticketed. Roughly 9–17 in summer and 9–16 in winter.",
     "Look out for the spring sakura festival and the rare Victoria water-lily night openings."],
    [link("Website", "https://www.fuveszkert.org/"), link("ELTE page", "https://www.elte.hu/fuveszkert")],
    "ELTE, Time Out, Wikipedia")
pages["kerepesi"] = page("local", "FIUMEI ÚT 16-18", "Fiumei úti sírkert", "National graveyard, 56 hectares",
    "The Fiumei Road cemetery, once called Kerepesi, covers 56 hectares and is known for its plants and wildlife as much as its tombs.",
    ["Run by the National Heritage Institute (NÖRI) since 2016. Burials still take place here.",
     "QR codes on the major sculptures and the FiumeiGuide app tell you whose grave you're looking at.",
     "Mausoleums can only be visited by appointment, with a guide."],
    [link("Official site", "https://fiumeiutisirkert.nori.gov.hu/en/home")],
    "Nemzeti Örökség Intézete, VG, We Love Budapest")

# Lore: the story, from the sources already on each spot.
def lore(place, title, when, intro, lines, sources, links=()):
    return page("lore", place, title, when, intro, lines, links, sources, list_title="What happened")

pages["sinkhole"] = lore("KARÁCSONY SÁNDOR UTCA", "The Street That Ate A Car", "18 NOV 2013",
    "A parked car dropped into a pit in the road about 2.5 m wide and 6–7 m long.",
    ["The street had already been dug up again and again for utility works.",
     "By 2016, residents described it as a street under siege.",
     "Advice still stands: do not park on this tile."], "HVG, Index")
pages["raid"] = lore("AURÓRA UTCA 11", "The 14-Hour Boss Fight", "JUNE 2017",
    "Police searched Auróra for 14 hours and detained 15 people.",
    ["They also seized industrial hemp grown for a sustainability programme.",
     "A closure order followed in 2018. The place opened the next day anyway.",
     "In 2019 the police turned up again, as surprise guests at a fundraiser."], "444.hu, Global Voices")
pages["aurora"] = lore("AURÓRA UTCA 11", "R.I.P. Auróra", "2014–2026",
    "A self-governing community house, gig room and pub that gave a home to dozens of civil groups. It closed on 29 March 2026, when the owner didn't renew the lease.",
    ["Opened in 2014 by the Marom Club Association, as a revival of the Sirály community space.",
     "Housed groups such as the Roma Press Centre, Budapest Pride and the School of Public Life.",
     "In 2017 the district withdrew its licence. The government office overturned that decision and Auróra reopened.",
     "Its community built the Auróra Climate Garden on an old gravel car park, using only the city's green waste.",
     "It said goodbye with a week-long farewell called Zárva Fesztivál, the Closed Festival, from 23 to 29 March 2026."],
    "We Love Budapest, HVG, XpatLoop, Front Line Defenders",
    [link("The farewell", f"{WLB}/cikk/2026/03/21/aurora-bezaras-zarva-fesztival/")])
pages["tigris"] = lore("KŐBÁNYAI ÚT", "Level Cleared: Négy Tigris", "16 JUNE 2014",
    "A 39,000 m² container market, running since 1993, with more than 2,000 stall tenants at its peak.",
    ["Bailiffs and police cleared it.",
     "Traders crossed the road into the old Ganz-MÁVAG halls, and the game carried on. See Kiskína."],
    "444.hu, Index, Pénzcentrum")
pages["corvinrip"] = lore("BLAHA LUJZA TÉR · DEPARTMENT STORE ROOF", "R.I.P. Corvin Club", "2007–2018",
    "A rooftop terrace on the fifth floor of the old Corvin department store, open from May 2007.",
    ["The district closed it in 2018.",
     "Game over, no continues."], "Wikipedia HU, We Love Budapest")
pages["blaha"] = lore("BLAHA LUJZA TÉR", "Blaha Speedrun: 505 Days", "10 DEC 2022",
    "Rebuilding the square took 505 days and 3.68 billion forints.",
    ["It added 80 trees to the ten already there.",
     "On opening day people took the square back with tea and frantic dancing."], "BKK, Telex")
pages["oldgolya"] = lore("BÓKAY JÁNOS UTCA", "The Great Stork Migration", "2018–2019",
    "Rising rents pushed Gólya out of its old pub on Bókay János utca.",
    ["It crowdfunded a building of its own on Orczy út.",
     "Volunteers did much of the renovation.",
     "Gentrification: 1. Storks: still flying."], "HVG, Index, Wikipedia HU, We Love Budapest")
pages["grundkert"] = lore("BÓKAY UTCA", "The Vanishing Garden", "JAN 2014",
    "The Grund Kert community garden was cleared to make way for new Corvin Sétány housing.",
    ["HVG reported a huge hole where one of the district's most colourful corners had been."], "HVG")
pages["keleti"] = lore("BAROSS TÉR · KELETI", "Keleti, September 2015", "4 SEPT 2015",
    "No joke on this one.",
    ["After days stranded outside a closed station, about a thousand people, most of them Syrian, set off from here on foot for Vienna."],
    "Euronews, Middle East Eye")


# Each page's own look, taken from the venue's own branding where it has one
# (website, sign, logo; checked November 2026). Colours:
#   brick: page background   text: words on the page   paper: cards
#   deep: words on cards     gold: stamp/closing fill (deep text sits on it)
#   mark: bullets on cards (defaults to gold)
# Style keys (all optional; the defaults are the Kerge look):
#   font serif|rounded|mono|default · caps · corner · shadow hard|soft|none · frame
#   pattern none|dots|stripes|grid|rays|waves|diamonds · ornament · tilt
#   logo: mirrored logo file (docs/logos/<id>.png, from LOGO_SOURCES) · logoBg · logoShape circle|square|wide
LOGO_BASE = "https://mihaivasiu-cmyk.github.io/nyocker/logos/"


def S(brick, text, paper, deep, gold, mark=None, logo=None, logo_bg=None, logo_shape="circle", **style):
    colors = {"brick": brick, "text": text, "paper": paper, "deep": deep, "gold": gold}
    if mark:
        colors["mark"] = mark
    if logo:
        style.update(logo=LOGO_BASE + logo + ".png", logoShape=logo_shape)
        if logo_bg:
            style["logoBg"] = logo_bg
    return colors, style


GAME = dict(font="mono", caps=True, corner=0, shadow="hard", frame=False, pattern="grid", ornament="▶", tilt=0)

STYLES = {
    # Bars
    "lumen": S("#EDEBE4", "#111111", "#FFFFFF", "#111111", "#FF6868", "#C62F2F", "lumen", "#FFFFFF", "square",
               font="mono", caps=True, corner=0, shadow="hard", frame=False, pattern="grid", ornament="■", tilt=0),
    "kislumen": S("#111111", "#FFFFFF", "#FFFFFF", "#111111", "#FF6868", "#111111", "lumen", "#FFFFFF", "square",
                  font="mono", caps=True, corner=0, shadow="hard", frame=False, pattern="dots", ornament="□", tilt=0),
    "brody": S("#2E3B2C", "#F4E9C8", "#F4E9C8", "#1E2A1C", "#E8B04A", None,
               font="serif", caps=True, corner=2, shadow="hard", frame=True, pattern="stripes", ornament="◆", tilt=-1),
    "kk": S("#3F4596", "#FCF2EC", "#FCF2EC", "#2A2F6B", "#FAA61A", "#C23D7A", "kk", "#2A2F6B", "wide",
            font="rounded", caps=False, corner=22, shadow="soft", frame=False, pattern="waves", ornament="●", tilt=-3),
    "hintalo": S("#16271E", "#F3EFE7", "#F3EFE7", "#2A1A12", "#E0A93A", "#AA3D1D", "hintalo", "#000000", "square",
                 font="serif", caps=True, corner=0, shadow="hard", frame=True, pattern="diamonds", ornament="❦", tilt=0),
    "kraken": S("#3B2A1A", "#E9D8B4", "#E9D8B4", "#2A1C10", "#C88B3A", None,
                font="serif", caps=True, corner=4, shadow="hard", frame=True, pattern="rays", ornament="⚙", tilt=-1),
    "zsir": S("#1C1C1C", "#FFE8C2", "#FFE8C2", "#1C1C1C", "#FF5A4E", None,
              font="default", caps=True, corner=0, shadow="hard", frame=False, pattern="stripes", ornament="★", tilt=2),
    "susuka": S("#5B3A8C", "#FFF4E0", "#FFF4E0", "#2B1A44", "#FFC94D", "#5B3A8C",
                font="rounded", caps=False, corner=14, shadow="soft", frame=False, pattern="dots", ornament="✿", tilt=-2),
    # Clubs
    "golya": S("#F2EEE6", "#111111", "#FFFFFF", "#111111", "#E10600", "#E10600", "golya", "#FFFFFF", "circle",
               font="default", caps=True, corner=0, shadow="hard", frame=False, pattern="stripes", ornament="★", tilt=-2),
    "grund": S("#121212", "#FFE9A8", "#FFF6DA", "#1A1A1A", "#F5C542", "#8A6510", "grund", "#F5C542", "circle",
               font="default", caps=False, corner=10, shadow="soft", frame=False, pattern="dots", ornament="✺", tilt=-1),
    # Art
    "fofoto": S("#0A0A0A", "#FFFFFF", "#F2F2F2", "#111111", "#B24BF3", "#9B0DD7", "fofoto", "#000000", "wide",
                font="default", caps=False, corner=12, shadow="soft", frame=False, pattern="rays", ornament="⬡", tilt=0),
    "isbn": S("#F8F8F8", "#1A1A1A", "#FFFFFF", "#1A1A1A", "#A9C8EC", "#4686CC", "isbn", "#FFFFFF", "square",
              font="serif", caps=False, corner=0, shadow="none", frame=True, pattern="stripes", ornament="+", tilt=0),
    "kupsus": S("#7A1F2B", "#F6EEDF", "#F6EEDF", "#2B1416", "#D9A441", None,
                font="serif", caps=False, corner=4, shadow="hard", frame=True, pattern="none", ornament="❧", tilt=-1),
    "cozy": S("#C9A88A", "#2E211A", "#FBF6EE", "#2E211A", "#E8C9A0", "#8C5A3C",
              font="rounded", caps=False, corner=24, shadow="soft", frame=False, pattern="dots", ornament="◍", tilt=0),
    "museum": S("#003141", "#FFFFFF", "#FFFFFF", "#22262A", "#F4A6A0", "#003141", "museum", "#FFFFFF", "wide",
                font="default", caps=False, corner=4, shadow="none", frame=False, pattern="none", ornament="◆", tilt=0),
    "kazan": S("#1F1F1F", "#FFFFFF", "#F0EEE9", "#111111", "#FF5A1F", "#D9400B",
               font="default", caps=True, corner=0, shadow="hard", frame=False, pattern="stripes", ornament="▲", tilt=-1),
    # Eats
    "kv": S("#3A2E26", "#F3E7D7", "#F3E7D7", "#241A14", "#D98E4A", None,
            font="default", caps=False, corner=8, shadow="soft", frame=False, pattern="none", ornament="•", tilt=0),
    "apricot": S("#30271C", "#F5EDE3", "#FFFFFF", "#212121", "#C7A17A", "#8A6A44", "apricot", "#FFFFFF", "wide",
                 font="default", caps=True, corner=2, shadow="none", frame=False, pattern="none", ornament="◆", tilt=0),
    "anton": S("#E9D9BF", "#3B2A1A", "#FFFBF3", "#3B2A1A", "#E0A458", "#A8692A",
               font="serif", caps=False, corner=18, shadow="soft", frame=False, pattern="dots", ornament="❀", tilt=-1),
    "fecske": S("#200F01", "#FFFFFF", "#FFF8EE", "#200F01", "#E8D3A8", "#8A6A3C", "fecske", "#3A2412", "circle",
                font="default", caps=False, corner=20, shadow="soft", frame=False, pattern="none", ornament="❦", tilt=0),
    "csarnok": S("#1E4E3F", "#F5EBD6", "#F5EBD6", "#1E2A24", "#D4A017", None,
                 font="serif", caps=True, corner=0, shadow="hard", frame=True, pattern="grid", ornament="◆", tilt=0),
    "kiskina": S("#B3121B", "#FFE9B0", "#FFF4DC", "#3A0A0C", "#F2C14E", "#B3121B",
                 font="default", caps=True, corner=6, shadow="hard", frame=False, pattern="stripes", ornament="◆", tilt=-1),
    # Second hand
    "humana": S("#FFF200", "#1D2E7A", "#FFFFFF", "#1D2E7A", "#FFF200", "#1D2E7A", "humana", "#FFFFFF", "wide",
                font="default", caps=True, corner=0, shadow="hard", frame=False, pattern="none", ornament="●", tilt=0),
    "prater": S("#4E6B59", "#FFFFFF", "#F7F2E8", "#24302A", "#E9B44C", None,
                font="serif", caps=False, corner=6, shadow="hard", frame=True, pattern="stripes", ornament="✂", tilt=-1),
    "konfekcio": S("#FF3EA5", "#111111", "#FFFFFF", "#111111", "#C6FF00", "#FF3EA5",
                   font="mono", caps=True, corner=0, shadow="hard", frame=False, pattern="dots", ornament="✕", tilt=3),
    "typo": S("#F7D6E0", "#4A2335", "#FFFFFF", "#4A2335", "#F0A3BA", "#D9577F",
              font="rounded", caps=False, corner=20, shadow="soft", frame=False, pattern="dots", ornament="✿", tilt=-2),
    "gizmo": S("#2D2A6E", "#F2EFE6", "#F2EFE6", "#1A1840", "#FF8A3D", None,
               font="default", caps=False, corner=4, shadow="hard", frame=False, pattern="grid", ornament="✦", tilt=-1),
    "teleki": S("#8A4B2A", "#FFF3E0", "#FFF3E0", "#2E1A10", "#F2B544", None,
                font="rounded", caps=False, corner=8, shadow="hard", frame=False, pattern="stripes", ornament="✺", tilt=-2),
    # Local
    "szabo": S("#042F4D", "#FFFBE7", "#FFFBE7", "#042F4D", "#D8B25A", None, "szabo", "#FFFFFF", "circle",
               font="serif", caps=False, corner=2, shadow="hard", frame=True, pattern="none", ornament="❦", tilt=0),
    "horvath": S("#2F2A6B", "#FFFFFF", "#F4F1FF", "#1E1A4A", "#FF7AC6", "#2F2A6B",
                 font="default", caps=False, corner=12, shadow="soft", frame=False, pattern="dots", ornament="✺", tilt=-2),
    "matyas": S("#3D6B4F", "#FFFFFF", "#F3F7EE", "#1F3326", "#F2C14E", "#3D6B4F",
                font="rounded", caps=False, corner=16, shadow="soft", frame=False, pattern="waves", ornament="❀", tilt=-1),
    "fuvesz": S("#066C3A", "#FFFFFF", "#F4F8EF", "#12321F", "#C8E06B", "#066C3A", "fuvesz", "#FFFFFF", "wide",
                font="serif", caps=False, corner=10, shadow="soft", frame=True, pattern="none", ornament="❦", tilt=0),
    "kerepesi": S("#282725", "#E8E2D2", "#EFEBE1", "#282725", "#C9AD55", None,
                  font="serif", caps=True, corner=0, shadow="none", frame=True, pattern="none", ornament="✦", tilt=0),
}
for lid in ("sinkhole", "raid", "aurora", "tigris", "corvinrip", "blaha", "oldgolya", "grundkert"):
    STYLES[lid] = S("#1A0B08", "#F3EBD8", "#F3EBD8", "#1A0B08", "#E8341C", None, **GAME)
STYLES["keleti"] = S("#2B2B2B", "#EDEDED", "#F4F4F4", "#1E1E1E", "#BDBDBD", "#6B6B6B",
                     font="serif", caps=False, corner=2, shadow="none", frame=False, pattern="none", ornament="—", tilt=0)

# Logos published on each venue's own website. The logos workflow mirrors them to docs/logos/<id>.png.
LOGO_SOURCES = {
    "golya": "https://golyaszovetkezet.hu/templates/g5_helium/custom/images/00%20golyaszovetkezet%20logo%20szines.png",
    "lumen": "https://static.wixstatic.com/media/df24a0_f6d14de2c7a64a998b45290080e7be7a~mv2.png",
    "kk": "https://treffort.hu/wp-content/themes/treffort/assets/treffort_kk_logo_beige.svg",
    "hintalo": "https://static.wixstatic.com/media/6c5eab_651206920e214ae0acb14df20255facf~mv2.jpg",
    "grund": "https://agrund.hu/wp-content/uploads/2017/09/grund-logo-black.png",
    "fofoto": "https://fofoto.hu/wp-content/uploads/2026/05/Fofotolognewffheadermasolat.png",
    "isbn": "https://www.isbnbooks.hu/wp-content/uploads/2024/11/cropped-IG_logo_1-180x180.png",
    "museum": "https://jozsefvarosimuzeum.hu/wp-content/uploads/2023/07/logo.svg",
    "apricot": "https://www.apricotcoffee.hu/wp-content/uploads/2026/10/logo_vegleges_1_png-600x194.webp",
    "fecske": "https://fecskepresszo.hu/fecske_logo_full.png",
    "humana": "https://humanahasznaltruha.hu/wp-content/uploads/2020/11/humana-logo-1.png",
    "szabo": "https://fszek.hu/img/logo2.png",
    "fuvesz": "https://www.fuveszkert.org/images/web/fuveszkert_logo_150.jpg",
}

# Venues with a Kerge-style page: their logo big at the top, the facts numbered, a closing stamp.
# Heroes are built by tools/make_heroes.py from the venues' own logos.
FEATURED = {
    "hintalo": dict(site=("hintalobar.com", "https://www.hintalobar.com/"),
                    closing={"text": "Luxus Putri.", "english": "Luxury hovel: the bar's own motto.",
                             "note": "Putri: a shack, said fondly."}),
    "lumen": dict(site=("lumen.hu", "https://www.lumen.hu/"),
                  closing={"text": "Két tér, egy Lumen.",
                           "english": "Two squares, one Lumen: the big one here, the small one on Mikszáth tér."}),
    "golya": dict(site=("golyaszovetkezet.hu", "https://golyaszovetkezet.hu/"),
                  closing={"text": "A Gólya mindenkié.", "english": "Gólya belongs to everyone. It's a cooperative.",
                           "note": "Szövetkezet: cooperative."}),
    "grund": dict(site=("agrund.hu", "https://agrund.hu/"),
                  closing={"text": "A grund a miénk!",
                           "english": "The grund is ours! The rallying cry of The Paul Street Boys, the 1906 novel the pub is named after.",
                           "note": "Grund: an empty lot, the boys' playground."}),
    "fecske": dict(site=("fecskepresszo.hu", "https://fecskepresszo.hu/"),
                   closing={"text": "Fecske lent, Főfoto fent.", "english": "Fecske downstairs, Főfoto upstairs.",
                            "note": "Fecske: swallow, the bird."}),
}


def contrast(a, b):
    def lum(h):
        r, g, b_ = (int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))
        f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b_)
    x, y = sorted((lum(a), lum(b)), reverse=True)
    return (x + 0.05) / (y + 0.05)


for pid, (colors, style) in STYLES.items():
    if "mark" not in colors and contrast(colors["gold"], colors["paper"]) < 3:
        # Bullets must show on the cards: the page colour if it stands out, else the ink.
        colors["mark"] = colors["brick"] if contrast(colors["brick"], colors["paper"]) >= 3 else colors["deep"]
    pages[pid]["colors"] = colors
    pages[pid]["style"] = style
STREET_WORDS = {"utca", "tér", "út", "körút", "kert", "negyed", "sétány", "site", "and", "above", "next", "to", "the", "of"}


def address(place):
    """ "BRÓDY SÁNDOR UTCA 2" -> "Bródy Sándor utca 2" """
    words = place.lower().split(" ")
    out = " ".join(w if w in STREET_WORDS or not w[:1].isalpha() else w[:1].upper() + w[1:] for w in words)
    return out.replace("Ganz-mávag", "Ganz-MÁVAG")


# Every other page gets the same build: a hero from tools/make_heroes.py, numbered facts
# and a closing stamp with the spot's name and address.
LORE_IDS = {"sinkhole", "raid", "aurora", "tigris", "corvinrip", "blaha", "oldgolya", "grundkert", "keleti"}
for pid, page_ in pages.items():
    if pid == "kerge":
        continue
    page_["hero"] = f"{pid}-hero"
    page_["numbered"] = True
    page_["style"].pop("logo", None)
    page_["style"]["pattern"] = "none"  # the hero runs straight into a plain page
    extra = FEATURED.get(pid)
    if extra:
        page_["closing"] = extra["closing"]
        title, url = extra["site"]
        page_["links"] = [link(title, url)] + page_.get("links", [])
    elif pid == "keleti":
        page_["closing"] = {"text": "Keleti, 4 September 2015."}
    elif pid in LORE_IDS:
        page_["closing"] = {"text": "Legend logged.", "english": page_["subtitle"],
                            "note": "Józsefváros lore, from the sources below."}
    else:
        page_["closing"] = {"text": page_["title"], "english": address(page_["place"]),
                            "note": "Found it? Mark it on the map."}
kerge = pages["kerge"]
kerge["colors"].update(text=kerge["colors"]["paper"])

root = Path(__file__).resolve().parent.parent
content = json.loads((root / "Nyocker/content.json").read_text(encoding="utf-8"))
ids = {s["id"] for s in content["spots"]}
missing = ids - pages.keys()
assert not missing, f"no page for {missing}"
extra = pages.keys() - ids
assert not extra, f"page without a spot: {extra}"
missing_style = pages.keys() - STYLES.keys() - {"kerge"}
assert not missing_style, f"no style for {missing_style}"
(root / "pipeline/logos.json").write_text(json.dumps(LOGO_SOURCES, indent=1, sort_keys=True) + "\n", encoding="utf-8")
(root / "Nyocker/discover.json").write_text(json.dumps(pages, ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
print(f"wrote {len(pages)} pages")
