import Foundation

struct VariantFlavor {
    let label: String
    let instruction: String

    static let single = VariantFlavor(label: "Polished", instruction: "Balanced: correct and natural with light touch edits.")

    static let set: [VariantFlavor] = [
        VariantFlavor(label: "Minimal", instruction: "Stay as close to the original wording as possible. Change only what is needed to be correct and polite."),
        VariantFlavor(label: "Smoother", instruction: "Slightly smoother and warmer phrasing while keeping the same length and content."),
        VariantFlavor(label: "Concise", instruction: "Slightly more concise and direct. Trim filler, keep every point."),
        VariantFlavor(label: "Clearer", instruction: "Prioritise clarity: simpler sentence structure and plainer words, same content."),
        VariantFlavor(label: "Softer", instruction: "Gentler and more considerate wording, same content and length."),
    ]

    static func flavors(count: Int) -> [VariantFlavor] {
        count <= 1 ? [single] : Array(set.prefix(count))
    }
}

enum RewriteEngine {
    static func systemPrompt(flavor: VariantFlavor, tweaks: [String], appName: String) -> String {
        var s = Prefs.systemPrompt
        if !appName.isEmpty {
            s += "\n\nThe text comes from the app \"\(appName)\". Match the register people use there."
        }
        s += "\n\nVariant style: \(flavor.instruction)"
        if !tweaks.isEmpty {
            s += "\n\nThe user also asked for these adjustments. Apply all of them, in order:\n"
            s += tweaks.map { "- \($0)" }.joined(separator: "\n")
        }
        s += "\n\nThe text to rewrite is inside <text> tags in the user message. Reply with the rewritten text only, without tags."
        return s
    }

    static func userMessage(_ original: String) -> String {
        "<text>\n\(original)\n</text>"
    }

    /// Strips wrapper tags or quotes the model may add despite instructions.
    static func clean(_ output: String) -> String {
        var t = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("<text>") { t = String(t.dropFirst(6)) }
        if t.hasSuffix("</text>") { t = String(t.dropLast(7)) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
