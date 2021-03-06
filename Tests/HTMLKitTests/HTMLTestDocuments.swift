
@testable import HTMLKit
import Foundation

protocol HTMLTestable: TemplateBuilder {
    static var expextedOutput: String { get }
}


struct SimpleData {
    let string: String
    let int: Int?
}


struct SimpleView: StaticView, HTMLTestable {

    static var expextedOutput: String = "<div><p>Text</p></div>"

    func build() -> CompiledTemplate {
        return
            div.child(
                p.child("Text")
        )
    }
}

struct StaticEmbedView: ContextualTemplate {

    typealias Context = SimpleData

    func build() -> CompiledTemplate {
        return
            div.child(
                SimpleView() +
                p.child(
                    variable(\.string)
                ) +

                renderIf(
                    \.int != nil,

                    small.child(
                        variable(\.int)
                    )
                )
        )
    }
}

struct BaseView: ContextualTemplate {

    struct Context {
        let title: String
    }

    let body: CompiledTemplate

    func build() -> CompiledTemplate {
        return
            html.child(
                head.child(
                    title.child( variable(\.title)),
                    link.href("some url").rel("stylesheet"),
                    meta.name("viewport").content("width=device-width, initial-scale=1.0")
                ),
                body.child(
                    body
                ),

                // Used to check for an error ocurring when embedding two different `ContextualTemplate`s and a `localFormula` is involved
                renderIf(\.title == "May Cause an error when embedding multiple views", div)
        )
    }
}

struct StringView: ContextualTemplate {

    struct Context {
        let string: String
    }

    func build() -> CompiledTemplate {
        return p.child( variable(\.string))
    }
}

struct SomeView: ContextualTemplate {

    struct Context {
        let name: String
        let baseContext: BaseView.Context

        static func contentWith(name: String, title: String) -> Context {
            return .init(name: name, baseContext: .init(title: title))
        }
    }

    func build() -> CompiledTemplate {
        return
            embed(
                BaseView(
                    body: p.child("Hello ", variable(\.name), "!")
                ),
                withPath: \.baseContext)
    }
}

struct ForEachView: ContextualTemplate {

    struct Context {
        let array: [StringView.Context]

        static func content(from array: [String]) -> Context {
            return .init(array: array.map { .init(string: $0) })
        }
    }

    func build() -> CompiledTemplate {
        return
            div.id("array").child(
                forEach(in: \.array, render: StringView())
        )
    }
}


struct IFView: ContextualTemplate {

    struct Context {
        let name: String
        let age: Int
        let nullable: String?
        let bool: Bool
    }

    func build() -> CompiledTemplate {
        return
            div.child(
                renderIf(
                    \.name == "Mats",

                    p.child(
                        "My name is: " + variable(\.name) + "!"
                    )
                ),

                renderIf(\.age < 20,
                    "I am a child"
                ).elseIf(\.age > 20,
                    "I am older"
                ).else(
                    "I am growing"
                ),

                renderIf(\.nullable != nil,
                    b.child( variable(\.nullable))
                ).elseIf(\.bool,
                    p.child("Simple bool")
                ),

                renderIf(
                    \.nullable == "Some" && \.name == "Per",

                    div.child("And")
                )

        )
    }
}

class FormInput: StaticView {

    enum FormType: String {
        case email
        case text
        case number
        case password
    }

    let id: String
    let type: FormType
    let isRequired: Bool
    let placeholder: String?
    let label: String

    init(label: String, type: FormType, id: String? = nil, isRequired: Bool = false, placeholder: String? = nil) {
        self.label = label
        if let id = id {
            self.id = id
        } else {
            self.id = label.replacingOccurrences(of: " ", with: "-").lowercased()
        }
        self.type = type
        self.isRequired = isRequired
        self.placeholder = placeholder
    }

    func build() -> CompiledTemplate {

        var inputTag = input.id(id).class("form-controll").type(type.rawValue).name(id).placeholder(placeholder)
        if isRequired {
            inputTag = inputTag.required
        }

        return
            div.class("form-group").child(
                label.for(id).child(label),
                inputTag
        )
    }
}

struct UsingComponent: StaticView {

    func build() -> CompiledTemplate {
        return
            div.id("Test").child(
                FormInput(label: "Email", type: .email)
        )
    }
}

struct ChainedEqualAttributes: StaticView {

    func build() -> CompiledTemplate {
        return div.class("foo").class("bar").id("id")
    }
}

struct ChainedEqualAttributesDataNode: StaticView {

    func build() -> CompiledTemplate {
        return img.class("foo").class("bar").id("id")
    }
}

struct VariableView: ContextualTemplate {

    struct Context {
        let string: String
    }

    func build() -> CompiledTemplate {
        return div.child(
            p.child(
                variable(\.string)
            ),
            p.child(
                variable(\.string, escaping: .unsafeNone)
            )
        )
    }
}

struct MultipleContextualEmbed: ContextualTemplate {

    struct Context {
        let base: BaseView.Context
        let variable: VariableView.Context

        init(title: String, string: String) {
            base = .init(title: title)
            variable = .init(string: string)
        }
    }

    func build() -> CompiledTemplate {
        return
            embed(
                BaseView(
                    body: [
                        span.child("Some text"),
                        embed(VariableView(),   withPath: \.variable),
                        embed(UnsafeVariable(), withPath: \.variable)
                    ]),
                withPath: \.base)

    }
}

struct DynamicAttribute: ContextualTemplate {

    struct Context {
        let isChecked: Bool
        let isActive: Bool
        let isOptional: Bool?
    }

    func build() -> CompiledTemplate {
        return div.class("foo")
            .if(\.isChecked, add: .class("checked"))
            .if(\.isActive, add: .init(attribute: "active", value: nil))
            .if(isNil: \.isOptional, add: .selected)
            .if(isNotNil: \.isOptional, add: .class("not-nil"))
    }
}

struct SelfContextPassing: ContextualTemplate {

    typealias Context = VariableView.Context

    func build() -> CompiledTemplate {
        return div.child(
            embed(
                VariableView()
            )
        )
    }
}


struct SelfLoopingView: ContextualTemplate {

    typealias Context = [SimpleData]

    func build() -> CompiledTemplate {
        return div.class("list").child(
            forEach(render: StaticEmbedView())
        )
    }
}

struct UnsafeVariable: ContextualTemplate {

    typealias Context = VariableView.Context

    func build() -> CompiledTemplate {
        return div.child(
            p.child(
                variable(\.string)
            ),
            p.child(
               unsafeVariable(in: MultipleContextualEmbed.self, for: \.base.title)
            )
        )
    }
}

struct MarkdownView: ContextualTemplate {

    struct Context {
        let title: String
        let description: String
    }

    func build() -> CompiledTemplate {
        return div.child(
            markdown(
                "# Title: ", variable(\.title),
                "\n## Description here:\n", variable(\.description)
            )
        )
    }
}

struct LocalizedView: LocalizedTemplate {

    static let localePath: KeyPath<LocalizedView.Context, String>? = \.locale

    enum LocalizationKeys: String {
        case helloWorld = "hello.world"
        case unreadMessages = "unread.messages"
    }

    /// The content needed to render StringKeys.unreadMessages
    struct DescriptionContent: Codable {
        let numberTest: Int
    }

    struct Context: Codable {
        let locale: String
        let description: DescriptionContent
        let numberTest: Int
    }

    func build() -> CompiledTemplate {
        return div.child(
            h1.child(
                localize(.helloWorld)
            ),
            p.child(
                localize(.unreadMessages, with: \.description)
            ),
            p.child(
                localize(.unreadMessages, with: ["numberTest" : 1])
            ),
            p.child(
                localizeWithContext(.unreadMessages)
            )
        )
    }
}


struct DateView: ContextualTemplate {

    struct Context {
        let date: Date
    }

    func build() -> CompiledTemplate {
        return div.child(
            p.child(
                date(\.date, dateStyle: .short, timeStyle: .short)
            ),
            p.child(
                date(\.date, format: "MM/dd/yyyy")
            )
        )
    }
}


struct LocalizedDateView: LocalizedTemplate {

    enum LocalizationKeys: String {
        case none
    }

    static let localePath: KeyPath<LocalizedDateView.Context, String>? = \.locale

    struct Context {
        let date: Date
        let locale: String
    }

    func build() -> CompiledTemplate {
        return div.child(
            p.child(
                date(\.date, dateStyle: .short, timeStyle: .short)
            ),
            p.child(
                date(\.date, format: "MM/dd/yyyy")
            )
        )
    }
}
