import Foundation

/// Hiragana/katakana -> Hepburn romaji, a port of src/lib/romaji.ts used for
/// romaji vocab search ("taberu" finds 食べる / たべる).
enum Romaji {
    private static let digraphs: [String: String] = [
        "きゃ": "kya", "きゅ": "kyu", "きょ": "kyo",
        "ぎゃ": "gya", "ぎゅ": "gyu", "ぎょ": "gyo",
        "しゃ": "sha", "しゅ": "shu", "しょ": "sho",
        "じゃ": "ja", "じゅ": "ju", "じょ": "jo",
        "ちゃ": "cha", "ちゅ": "chu", "ちょ": "cho",
        "ぢゃ": "ja", "ぢゅ": "ju", "ぢょ": "jo",
        "にゃ": "nya", "にゅ": "nyu", "にょ": "nyo",
        "ひゃ": "hya", "ひゅ": "hyu", "ひょ": "hyo",
        "びゃ": "bya", "びゅ": "byu", "びょ": "byo",
        "ぴゃ": "pya", "ぴゅ": "pyu", "ぴょ": "pyo",
        "みゃ": "mya", "みゅ": "myu", "みょ": "myo",
        "りゃ": "rya", "りゅ": "ryu", "りょ": "ryo",
        "キャ": "kya", "キュ": "kyu", "キョ": "kyo",
        "ギャ": "gya", "ギュ": "gyu", "ギョ": "gyo",
        "シャ": "sha", "シュ": "shu", "ショ": "sho",
        "ジャ": "ja", "ジュ": "ju", "ジョ": "jo",
        "チャ": "cha", "チュ": "chu", "チョ": "cho",
        "ヂャ": "ja", "ヂュ": "ju", "ヂョ": "jo",
        "ニャ": "nya", "ニュ": "nyu", "ニョ": "nyo",
        "ヒャ": "hya", "ヒュ": "hyu", "ヒョ": "hyo",
        "ビャ": "bya", "ビュ": "byu", "ビョ": "byo",
        "ピャ": "pya", "ピュ": "pyu", "ピョ": "pyo",
        "ミャ": "mya", "ミュ": "myu", "ミョ": "myo",
        "リャ": "rya", "リュ": "ryu", "リョ": "ryo",
        "ファ": "fa", "フィ": "fi", "フェ": "fe", "フォ": "fo", "フュ": "fyu",
        "ウィ": "wi", "ウェ": "we", "ウォ": "wo",
        "ヴァ": "va", "ヴィ": "vi", "ヴェ": "ve", "ヴォ": "vo", "ヴュ": "vyu",
        "ティ": "ti", "ディ": "di", "トゥ": "tu", "ドゥ": "du",
        "チェ": "che", "シェ": "she", "ジェ": "je",
        "ツァ": "tsa", "ツィ": "tsi", "ツェ": "tse", "ツォ": "tso",
        "イェ": "ye",
    ]

    private static let singles: [Character: String] = {
        let table: [(String, [String])] = [
            ("あいうえお", ["a", "i", "u", "e", "o"]),
            ("かきくけこ", ["ka", "ki", "ku", "ke", "ko"]),
            ("がぎぐげご", ["ga", "gi", "gu", "ge", "go"]),
            ("さしすせそ", ["sa", "shi", "su", "se", "so"]),
            ("ざじずぜぞ", ["za", "ji", "zu", "ze", "zo"]),
            ("たちつてと", ["ta", "chi", "tsu", "te", "to"]),
            ("だぢづでど", ["da", "ji", "zu", "de", "do"]),
            ("なにぬねの", ["na", "ni", "nu", "ne", "no"]),
            ("はひふへほ", ["ha", "hi", "fu", "he", "ho"]),
            ("ばびぶべぼ", ["ba", "bi", "bu", "be", "bo"]),
            ("ぱぴぷぺぽ", ["pa", "pi", "pu", "pe", "po"]),
            ("まみむめも", ["ma", "mi", "mu", "me", "mo"]),
            ("やゆよ", ["ya", "yu", "yo"]),
            ("らりるれろ", ["ra", "ri", "ru", "re", "ro"]),
            ("わゐゑをん", ["wa", "i", "e", "o", "n"]),
            ("ぁぃぅぇぉ", ["a", "i", "u", "e", "o"]),
            ("ゃゅょゎ", ["ya", "yu", "yo", "wa"]),
            ("アイウエオ", ["a", "i", "u", "e", "o"]),
            ("カキクケコ", ["ka", "ki", "ku", "ke", "ko"]),
            ("ガギグゲゴ", ["ga", "gi", "gu", "ge", "go"]),
            ("サシスセソ", ["sa", "shi", "su", "se", "so"]),
            ("ザジズゼゾ", ["za", "ji", "zu", "ze", "zo"]),
            ("タチツテト", ["ta", "chi", "tsu", "te", "to"]),
            ("ダヂヅデド", ["da", "ji", "zu", "de", "do"]),
            ("ナニヌネノ", ["na", "ni", "nu", "ne", "no"]),
            ("ハヒフヘホ", ["ha", "hi", "fu", "he", "ho"]),
            ("バビブベボ", ["ba", "bi", "bu", "be", "bo"]),
            ("パピプペポ", ["pa", "pi", "pu", "pe", "po"]),
            ("マミムメモ", ["ma", "mi", "mu", "me", "mo"]),
            ("ヤユヨ", ["ya", "yu", "yo"]),
            ("ラリルレロ", ["ra", "ri", "ru", "re", "ro"]),
            ("ワヰヱヲン", ["wa", "i", "e", "o", "n"]),
            ("ヴ", ["vu"]),
            ("ァィゥェォ", ["a", "i", "u", "e", "o"]),
            ("ャュョヮ", ["ya", "yu", "yo", "wa"]),
        ]
        var map: [Character: String] = [:]
        for (kana, romaji) in table {
            for (ch, r) in zip(kana, romaji) { map[ch] = r }
        }
        return map
    }()

    private static func lookupMora(_ chars: [Character], _ i: Int) -> (romaji: String, length: Int)? {
        if i + 1 < chars.count {
            let pair = String([chars[i], chars[i + 1]])
            if let d = digraphs[pair] { return (d, 2) }
        }
        if i < chars.count, let s = singles[chars[i]] { return (s, 1) }
        return nil
    }

    static func fromKana(_ kana: String) -> String {
        let chars = Array(kana)
        var result = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "っ" || c == "ッ" {
                if let next = lookupMora(chars, i + 1), let first = next.romaji.first {
                    // Traditional Hepburn doubles "t" (not "c") before "ch".
                    result += next.romaji.hasPrefix("ch") ? "t" + next.romaji : String(first) + next.romaji
                    i += 1 + next.length
                } else {
                    i += 1
                }
                continue
            }
            if c == "ー" {
                if let last = result.last, "aiueo".contains(last) { result.append(last) }
                i += 1
                continue
            }
            if let mora = lookupMora(chars, i) {
                result += mora.romaji
                i += mora.length
            } else {
                result.append(c)
                i += 1
            }
        }
        return result
    }
}
